import AVFoundation
import Combine
import Foundation
import Speech

/// EARS — Phase-2 implementation: the device microphone heard through
/// Apple's Speech framework, with an explicit permission flow.
///
/// Production path (ARCHITECTURE.md): Zoom Meeting SDK raw audio
/// (per-participant where the SDK surface allows) -> streaming
/// Whisper-class STT. This service sits behind the same shape — a live
/// stream of partial + final transcripts — so swapping the source later
/// does not change the rest of the app. Two sense channels are kept
/// separate by design: this service is the ROOM ear (the phone's mic);
/// call audio will arrive through the Zoom layer, clearly labeled.
@MainActor
final class SpeechRecognitionService: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var interimText = ""
    @Published private(set) var log: [TranscriptEntry] = []
    @Published private(set) var statusMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Permissions

    /// Requests speech-recognition and microphone permission, reporting the
    /// outcome into `statusMessage` instead of failing silently.
    func requestPermissions() async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            statusMessage = "Speech recognition permission is \(speechStatus.description). Enable it in Settings > Nova Presence to give Nova ears."
            return
        }
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        statusMessage = micGranted
            ? "Ears permitted. Tap Start Listening when ready."
            : "Microphone permission was denied. Enable it in Settings > Nova Presence to give Nova ears."
    }

    // MARK: - Listening

    func startListening() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            statusMessage = "Speech recognizer is not available right now."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusMessage = "Audio session failed: \(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on-device recognition where the locale supports it:
        // free, private, and the Phase-2 stand-in closest to the local
        // Whisper-class production design.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            self.log.insert(TranscriptEntry(source: .heard(speaker: "Room"), text: trimmed), at: 0)
                        }
                        self.interimText = ""
                    } else {
                        self.interimText = text
                    }
                }
                if error != nil {
                    self.stopListening()
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            statusMessage = nil
        } catch {
            statusMessage = "Microphone failed to start: \(error.localizedDescription)"
            stopListening()
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        interimText = ""
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private extension SFSpeechRecognizerAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "not determined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }
}
