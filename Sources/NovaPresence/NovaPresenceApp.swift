import Combine
import SwiftUI

/// Nova Presence — Phase 2.
///
/// One app, two clearly separated sense systems (ARCHITECTURE.md, Route C):
///   * ROOM senses — this phone's mic / camera / speaker: Nova's ears, eyes
///     and mouth for the physical room she is carried into.
///   * CALL senses — the Zoom layer's streams: her ears, eyes and mouth
///     inside a call. Wired behind ZoomSessionService; standalone until
///     Zoom keys + SDK binaries exist (no-Zoom-keys mode).
@main
struct NovaPresenceApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
    }
}

/// App-wide state: owns the faculty services and keeps them wired
/// (e.g. the ears being live is what puts the avatar into listening pose).
@MainActor
final class AppModel: ObservableObject {
    let ears = SpeechRecognitionService()
    let mouth = SpeechOutService()
    let eyes = CameraFeedService()
    let zoomConfig = ZoomConfig.fromBundle()

    /// The active Zoom route. Standalone until the Emperor provides keys
    /// and the SDK binaries are vendored; switchable in the Zoom panel
    /// for development, always honest about its state.
    @Published var zoomMode: ZoomIntegrationMode = .standalone {
        didSet { rebuildZoomService() }
    }
    @Published private(set) var zoom: BaseZoomService

    @Published var palette: AvatarPalette = .novaBlue

    /// Forwards the active Zoom service's changes to the UI (the service
    /// is a child ObservableObject; SwiftUI does not nest-forward
    /// objectWillChange automatically).
    private var zoomForwarding: AnyCancellable?

    init() {
        zoom = BaseZoomService(mode: .standalone, config: zoomConfig)
        forwardZoomChanges()
    }

    private func rebuildZoomService() {
        switch zoomMode {
        case .standalone:
            zoom = BaseZoomService(mode: .standalone, config: zoomConfig)
        case .videoSDKSandbox:
            zoom = VideoSDKZoomService(config: zoomConfig)
        case .meetingSDK:
            zoom = MeetingSDKZoomService(config: zoomConfig)
        }
        forwardZoomChanges()
    }

    private func forwardZoomChanges() {
        zoomForwarding = zoom.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
