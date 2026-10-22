import AVFoundation
import Combine
import Foundation

/// EYES — Phase-2 implementation: the device camera as the vision feed.
///
/// ARCHITECTURE.md production mapping:
///   * THIS service is the ROOM eye: what the Emperor shows the phone is
///     what Nova sees of the physical room. It feeds a preview now; the
///     production perception sampler will take frames from this same
///     session (1–2 fps, downscaled, source-labeled "room").
///   * The CALL eyes are separate: Zoom SDK raw video frames arrive per
///     participant through the Zoom layer, sampled and name-tagged.
///   * The two channels are never silently mixed — every frame's source
///     (room vs named participant) travels with it.
@MainActor
final class CameraFeedService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage: String?

    /// The capture session the preview (and later, the frame sampler) reads.
    let session = AVCaptureSession()
    private var configured = false

    /// Requests camera permission, reporting the outcome honestly.
    func requestPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            statusMessage = "Eyes permitted. Tap Open Eyes when ready."
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            statusMessage = granted
                ? "Eyes permitted. Tap Open Eyes when ready."
                : "Camera permission was denied. Enable it in Settings > Nova Presence to give Nova eyes."
        default:
            statusMessage = "Camera permission is off. Enable it in Settings > Nova Presence to give Nova eyes."
        }
    }

    func start() {
        guard !isRunning else { return }
        // Session configuration mutates capture state; run it off the main
        // actor's critical path, then publish state back on the main actor.
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            if !self.configured {
                session.beginConfiguration()
                session.sessionPreset = .medium
                if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                   let input = try? AVCaptureDeviceInput(device: camera),
                   session.canAddInput(input) {
                    session.addInput(input)
                }
                session.commitConfiguration()
                self.configured = true
            }
            session.startRunning()
            Task { @MainActor in
                self.isRunning = session.isRunning
                if !session.isRunning {
                    self.statusMessage = "Camera could not start (no usable camera input on this device?)."
                }
            }
        }
    }

    func stop() {
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if session.isRunning { session.stopRunning() }
            Task { @MainActor in self?.isRunning = false }
        }
    }
}
