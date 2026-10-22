import Foundation

/// One line in Nova's hearing / speaking log, shown in-app.
/// In production, heard entries arrive tagged with the Zoom participant
/// who spoke (per-participant raw audio preserves speaker identity —
/// see ARCHITECTURE.md, "Audio pipeline").
struct TranscriptEntry: Identifiable, Equatable {
    enum Source: Equatable {
        /// Heard through the ears (device mic in Phase 2; Zoom raw audio later).
        case heard(speaker: String)
        /// Spoken through the mouth (TTS out).
        case spoken
        /// App/system note (permission state, Zoom status, errors).
        case system
    }

    let id = UUID()
    let source: Source
    let text: String
    let date: Date

    init(source: Source, text: String, date: Date = Date()) {
        self.source = source
        self.text = text
        self.date = date
    }

    var speakerLabel: String {
        switch source {
        case .heard(let speaker): return speaker
        case .spoken: return "Nova"
        case .system: return "System"
        }
    }
}
