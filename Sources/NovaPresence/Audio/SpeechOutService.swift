import Combine
import Foundation

/// MOUTH — the app-facing speech-out service. Owns the active TTSProvider
/// so the provider can be swapped (device placeholder -> Nova's real
/// voice) without touching the UI or the avatar.
@MainActor
final class SpeechOutService: ObservableObject {
    @Published private(set) var isSpeaking = false
    /// 0...1 envelope feeding the avatar's mouth (see AvatarView).
    @Published private(set) var amplitude: Double = 0
    @Published private(set) var log: [TranscriptEntry] = []

    private(set) var provider: TTSProvider

    init(provider: TTSProvider = DeviceSpeechTTSProvider()) {
        self.provider = provider
        provider.onAmplitude = { [weak self] level in
            Task { @MainActor in self?.amplitude = level }
        }
        provider.onSpeakingChanged = { [weak self] speaking in
            Task { @MainActor in self?.isSpeaking = speaking }
        }
    }

    var providerName: String { provider.displayName }
    var isNovaVoice: Bool { provider.isNovaVoice }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        log.insert(TranscriptEntry(source: .spoken, text: trimmed), at: 0)
        provider.speak(trimmed)
    }

    func stop() {
        provider.stop()
    }

    /// Swap the voice source at runtime (Phase 3: when the Nova TTS
    /// service endpoint is configured, the app installs
    /// NovaServerTTSProvider here and the UI badge updates itself).
    func install(provider newProvider: TTSProvider) {
        provider.stop()
        provider = newProvider
        newProvider.onAmplitude = { [weak self] level in
            Task { @MainActor in self?.amplitude = level }
        }
        newProvider.onSpeakingChanged = { [weak self] speaking in
            Task { @MainActor in self?.isSpeaking = speaking }
        }
        objectWillChange.send()
    }
}
