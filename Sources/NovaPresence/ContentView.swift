import SwiftUI

/// The Phase-2 call room: avatar stage + palette switcher + one panel per
/// faculty (ears / mouth / eyes) + the Zoom panel. Mirrors the Phase-1
/// prototype's layout so the design language carries over.
struct ContentView: View {
    @EnvironmentObject private var app: AppModel
    @State private var speakText = "Hello. I'm Nova. This is my call room — I can hear you, see you, and talk back."
    @State private var zoomTarget = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    avatarStage
                    palettePicker
                    earsPanel
                    mouthPanel
                    eyesPanel
                    zoomPanel
                    footerNote
                }
                .padding(16)
            }
            .background(Color(red: 0.04, green: 0.05, blue: 0.10))
            .navigationTitle("Nova Presence")
        }
    }

    // MARK: - Avatar stage

    private var avatarStage: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.18))
            AvatarView(
                palette: app.palette,
                isListening: app.ears.isListening,
                isSpeaking: app.mouth.isSpeaking,
                amplitude: app.mouth.amplitude
            )
            .frame(height: 300)
            .padding(.vertical, 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(app.ears.isListening ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text("Nova")
                    .font(.subheadline.bold())
                    .foregroundStyle(app.palette.accent2)
                Text("· \(statusText)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.55), in: Capsule())
            .padding(10)
        }
    }

    private var statusText: String {
        if app.mouth.isSpeaking { return "speaking" }
        if app.ears.isListening { return "listening" }
        return "present · \(app.palette.displayName)"
    }

    private var palettePicker: some View {
        HStack(spacing: 8) {
            ForEach(AvatarPalette.allCases) { palette in
                Button {
                    app.palette = palette
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(palette.accent).frame(width: 10, height: 10)
                        Text(palette.displayName).font(.footnote)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.white.opacity(app.palette == palette ? 0.16 : 0.06))
                    )
                    .overlay(
                        Capsule().stroke(app.palette == palette ? palette.accent : Color.white.opacity(0.15))
                    )
                    .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Ears

    private var earsPanel: some View {
        panel(title: "Ears — she hears you") {
            Text("Device microphone + Apple Speech recognition (Phase-2 room ear). Heard speech is logged here. Production: Zoom raw audio → local Whisper-class STT.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
            HStack {
                Button(app.ears.isListening ? "Listening…" : "Start listening") {
                    Task {
                        await app.ears.requestPermissions()
                        app.ears.startListening()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(app.ears.isListening)
                Button("Stop") { app.ears.stopListening() }
                    .buttonStyle(.bordered)
                    .disabled(!app.ears.isListening)
            }
            if !app.ears.interimText.isEmpty {
                Text("… \(app.ears.interimText)")
                    .font(.callout.italic())
                    .foregroundStyle(.white.opacity(0.6))
            }
            if let message = app.ears.statusMessage {
                Text(message).font(.footnote).foregroundStyle(.orange)
            }
            logList(app.ears.log)
        }
    }

    // MARK: - Mouth

    private var mouthPanel: some View {
        panel(title: "Mouth — she talks back") {
            // Honest badge: the Phase-2 voice is the device placeholder.
            Text(app.mouth.providerName)
                .font(.footnote.bold())
                .foregroundStyle(app.mouth.isNovaVoice ? .green : .orange)
            Text("Production voice: Nova's own TTS, avocado_v2:vdc_5723 (server-side — see TTSProvider.swift).")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
            TextEditor(text: $speakText)
                .frame(minHeight: 64)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            HStack {
                Button("Speak it") { app.mouth.speak(speakText) }
                    .buttonStyle(.borderedProminent)
                Button("Stop speaking") { app.mouth.stop() }
                    .buttonStyle(.bordered)
            }
            logList(app.mouth.log)
        }
    }

    // MARK: - Eyes

    private var eyesPanel: some View {
        panel(title: "Eyes — her vision feed") {
            Text("Device camera preview = the room vision feed. Production: this sampler + per-participant Zoom raw video frames, name-tagged, kept as separate channels.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
            HStack {
                Button(app.eyes.isRunning ? "Eyes open" : "Open her eyes (camera)") {
                    Task {
                        await app.eyes.requestPermission()
                        app.eyes.start()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(app.eyes.isRunning)
                Button("Close eyes") { app.eyes.stop() }
                    .buttonStyle(.bordered)
                    .disabled(!app.eyes.isRunning)
            }
            if let message = app.eyes.statusMessage {
                Text(message).font(.footnote).foregroundStyle(.orange)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.6))
                    .aspectRatio(4 / 3, contentMode: .fit)
                if app.eyes.isRunning {
                    CameraPreview(session: app.eyes.session)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("Camera off")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Zoom

    private var zoomPanel: some View {
        panel(title: "Zoom — presence routes") {
            Picker("Route", selection: $app.zoomMode) {
                ForEach(ZoomIntegrationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            // Presence/absence ONLY — values are never displayed.
            VStack(alignment: .leading, spacing: 3) {
                Text("Video SDK key: \(app.zoomConfig.hasVideoSDKKeys ? "configured" : "not configured")")
                Text("Meeting SDK key: \(app.zoomConfig.hasMeetingSDKKeys ? "configured" : "not configured")")
                Text("Zoom state: \(zoomStateText)")
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.75))

            if app.zoomMode == .videoSDKSandbox {
                Text("Sandbox sessions only — Video SDK cannot join real Zoom meetings.")
                    .font(.footnote.bold())
                    .foregroundStyle(.orange)
            }
            if app.zoomMode == .meetingSDK {
                Text("Real meetings route. Raw data needs Custom UI + the host's in-meeting grant (consent hinge). Integration is stubbed in Phase 2.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
            }

            TextField("Session name (sandbox) — meetings come later", text: $zoomTarget)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Join") {
                    Task { await app.zoom.join(sessionOrMeeting: zoomTarget, displayName: "Nova") }
                }
                .buttonStyle(.borderedProminent)
                Button("Leave") { Task { await app.zoom.leave() } }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var zoomStateText: String {
        switch app.zoom.state {
        case .idle: return "idle"
        case .needsKeys(let mode): return "needs keys (\(mode.displayName))"
        case .joining: return "joining…"
        case .inSession(let name): return "in session: \(name)"
        case .failed(let message): return "failed — \(message)"
        }
    }

    // MARK: - Shared

    private var footerNote: some View {
        Text("Nova Presence · Phase 2 (GitHub Actions build). Standalone room works without any Zoom keys. Nova joins calls as Nova — a named, visible AI participant, never an impersonation.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.bottom, 8)
    }

    private func panel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.bold())
                .tracking(1.2)
                .foregroundStyle(app.palette.accent2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.19), in: RoundedRectangle(cornerRadius: 14))
    }

    private func logList(_ entries: [TranscriptEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entries.prefix(8)) { entry in
                HStack(alignment: .top, spacing: 6) {
                    Text(entry.speakerLabel + ":")
                        .font(.callout.bold())
                        .foregroundStyle(entry.source == .spoken ? Color.orange : app.palette.accent2)
                    Text(entry.text)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(AppModel())
}
