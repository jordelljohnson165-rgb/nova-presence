import Combine
import Foundation

/// The Zoom boundary — ONE interface for every Zoom route, so the rest of
/// the app (avatar, ears, mouth, eyes) never cares which SDK is behind it.
///
/// Routes behind this interface (ARCHITECTURE.md):
///   * `.standalone`       — no Zoom at all. The Phase-2 default and the
///                           no-Zoom-keys build mode: the avatar room with
///                           device ears / mouth / eyes works on its own.
///   * `.videoSDKSandbox`  — Zoom Video SDK. DEVELOPMENT ONLY: Video SDK
///                           creates its OWN sessions; it CANNOT join real
///                           Zoom meetings (Zoom's own pricing FAQ). Raw
///                           audio/video are headline features and there is
///                           a 10,000 free-minutes/month pool — the app must
///                           hard-stop at that pool boundary ($0 law).
///   * `.meetingSDK`       — Zoom Meeting SDK, Custom UI mode. THE
///                           production route: the only one that joins
///                           real Zoom meetings. iOS raw data is Custom-UI
///                           only and opens after the host grants raw
///                           live-streaming / local-recording privilege in
///                           the meeting — that grant is the consent hinge.
///                           From 2026-03-02, joining meetings outside the
///                           app owner's account needs ZAK/OBF token
///                           authorization (the session ends when the
///                           authorizing user leaves — no unaccompanied
///                           bots by design).
enum ZoomIntegrationMode: String, CaseIterable, Identifiable {
    case standalone
    case videoSDKSandbox
    case meetingSDK

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standalone: return "Standalone room (no Zoom)"
        case .videoSDKSandbox: return "Video SDK sandbox (dev sessions only)"
        case .meetingSDK: return "Meeting SDK (real meetings — later phase)"
        }
    }
}

enum ZoomSessionState: Equatable {
    case idle
    case needsKeys(ZoomIntegrationMode)
    case joining
    case inSession(name: String)
    case failed(message: String)
}

enum ZoomError: LocalizedError {
    case keysNotConfigured(ZoomIntegrationMode)
    case sdkNotIntegrated(ZoomIntegrationMode)

    var errorDescription: String? {
        switch self {
        case .keysNotConfigured(let mode):
            return "\(mode.displayName) keys are not configured. Add them via GitHub Secrets / Secrets.xcconfig (names only in the repo) — until then the app runs standalone."
        case .sdkNotIntegrated(let mode):
            return "\(mode.displayName) is stubbed at the integration boundary in Phase 2. The SDK binary is not vendored yet; see Zoom/VideoSDKZoomService.swift and MeetingSDKZoomService.swift for the exact integration points."
        }
    }
}

/// The interface every Zoom route implements.
@MainActor
protocol ZoomSessionService: ObservableObject {
    var mode: ZoomIntegrationMode { get }
    var state: ZoomSessionState { get }
    var config: ZoomConfig { get }
    func join(sessionOrMeeting: String, displayName: String) async
    func leave() async
}

/// Default implementation used in no-Zoom-keys mode AND whenever an SDK
/// is not integrated yet: joining honestly reports why it cannot proceed
/// (keys missing vs SDK stubbed) instead of pretending to connect.
@MainActor
class BaseZoomService: ObservableObject, ZoomSessionService {
    let mode: ZoomIntegrationMode
    let config: ZoomConfig
    @Published private(set) var state: ZoomSessionState = .idle

    init(mode: ZoomIntegrationMode, config: ZoomConfig) {
        self.mode = mode
        self.config = config
    }

    /// Subclasses override once their SDK is genuinely integrated.
    var sdkIntegrated: Bool { false }
    var keysPresent: Bool {
        switch mode {
        case .standalone: return true
        case .videoSDKSandbox: return config.hasVideoSDKKeys
        case .meetingSDK: return config.hasMeetingSDKKeys
        }
    }

    func join(sessionOrMeeting: String, displayName: String) async {
        guard mode != .standalone else {
            state = .inSession(name: "Standalone room")
            return
        }
        guard keysPresent else {
            state = .needsKeys(mode)
            return
        }
        guard sdkIntegrated else {
            state = .failed(message: (ZoomError.sdkNotIntegrated(mode).errorDescription ?? "SDK not integrated."))
            return
        }
        state = .joining
        // Real implementations take it from here.
    }

    func leave() async {
        state = .idle
    }
}
