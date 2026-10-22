import AVFoundation
import Foundation

/// The MOUTH's voice source — a pluggable protocol on purpose.
///
/// Phase-2 placeholder: `DeviceSpeechTTSProvider` (the iPhone's built-in
/// speech synthesis). It is NOT Nova's voice and the app says so wherever
/// the provider is named.
///
/// Production: `NovaServerTTSProvider` will speak in Nova's own voice,
/// `avocado_v2:vdc_5723` ("Solen Pillar"). That engine is SERVER-SIDE
/// (today it runs box-local on the team's VM; production placement is an
/// open infra decision in ARCHITECTURE.md) — it is never a device voice,
/// and no provider in this app may silently pretend otherwise. If the
/// Nova-voice service is unreachable, the honest state is "voice
/// unavailable", never a silent substitution.
protocol TTSProvider: AnyObject {
    /// Human-honest name shown in the UI, e.g. "Device voice (placeholder)".
    var displayName: String { get }
    /// True only for the real Nova voice. The UI badges anything else.
    var isNovaVoice: Bool { get }
    var isSpeaking: Bool { get }
    /// Called on the main actor with a 0...1 amplitude envelope while
    /// speaking, so the avatar's lips track the outgoing speech.
    var onAmplitude: ((Double) -> Void)? { get set }
    var onSpeakingChanged: ((Bool) -> Void)? { get set }
    func speak(_ text: String)
    func stop()
}

/// Phase-2 placeholder voice: AVSpeechSynthesizer (device voice).
///
/// HONEST LIMIT: the synthesizer exposes no audio stream to tap, so the
/// amplitude envelope here is SIMULATED from utterance timing — the same
/// stand-in the Phase-1 prototype used and labeled. The production
/// provider taps real PCM samples (RMS -> mouth openness) instead.
final class DeviceSpeechTTSProvider: NSObject, TTSProvider {
    let displayName = "Device voice (Phase-2 placeholder — not Nova's voice)"
    let isNovaVoice = false

    private(set) var isSpeaking = false {
        didSet { onSpeakingChanged?(isSpeaking) }
    }
    var onAmplitude: ((Double) -> Void)?
    var onSpeakingChanged: ((Bool) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var envelopeTimer: Timer?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.05
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func startEnvelope() {
        envelopeTimer?.invalidate()
        // Simulated envelope (see class note): varied pulses while speaking.
        envelopeTimer = Timer.scheduledTimer(withTimeInterval: 0.055, repeats: true) { [weak self] _ in
            guard let self, self.isSpeaking else { return }
            let t = Date().timeIntervalSinceReferenceDate / 0.09
            let level = 0.25 + abs(sin(t)) * 0.55 + Double.random(in: 0...0.2)
            self.onAmplitude?(min(level, 1.0))
        }
    }

    private func stopEnvelope() {
        envelopeTimer?.invalidate()
        envelopeTimer = nil
        onAmplitude?(0)
    }
}

extension DeviceSpeechTTSProvider: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
        startEnvelope()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        stopEnvelope()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        stopEnvelope()
    }
}

/// Production voice — boundary only in Phase 2.
///
/// When wired, this provider will POST text to the Nova TTS service
/// (voice `avocado_v2:vdc_5723`), stream back PCM, play it, hand the same
/// samples to the Zoom raw-audio sender, and compute the lip-sync
/// envelope from the real samples. Until the service endpoint exists and
/// is configured, `speak` reports unavailability instead of faking a voice.
final class NovaServerTTSProvider: NSObject, TTSProvider {
    let displayName = "Nova's voice avocado_v2:vdc_5723 (not configured yet)"
    let isNovaVoice = true

    private(set) var isSpeaking = false
    var onAmplitude: ((Double) -> Void)?
    var onSpeakingChanged: ((Bool) -> Void)?

    /// Service endpoint, injected at app start when it exists. Nil in Phase 2.
    var endpoint: URL?

    func speak(_ text: String) {
        guard endpoint != nil else {
            // Honest failure: never fall back silently to a substitute voice.
            onSpeakingChanged?(false)
            onAmplitude?(0)
            return
        }
        // TODO(Phase 3): stream PCM from the Nova TTS service, play it,
        // tap RMS for onAmplitude, and feed the Zoom audio sender.
    }

    func stop() {
        // TODO(Phase 3): cancel the stream and flush playback.
    }
}
