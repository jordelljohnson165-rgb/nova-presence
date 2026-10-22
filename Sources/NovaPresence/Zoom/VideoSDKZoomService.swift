import Foundation

/// Zoom Video SDK route — DEVELOPMENT SANDBOX ONLY.
///
/// What this route IS (research-zoom-sdk.md §1): a way to build and prove
/// the avatar / ears / mouth / eyes pipeline inside sessions our own app
/// creates, with raw audio/video as included features and a 10,000
/// free-minutes/month pool (hard-stop at the boundary — $0 law).
///
/// What it is NOT: it cannot join a real Zoom meeting. Zoom's own words:
/// the Video SDK "cannot be connected to via the Zoom Clients or Zoom
/// Meetings." Any UI or doc that implies otherwise is wrong; this class
/// exists to develop against, and MeetingSDKZoomService is the route to
/// real meetings.
///
/// INTEGRATION BOUNDARY (Phase 2): the Video SDK binary
/// (ZoomVideoSDK.xcframework) is distributed through the Zoom Marketplace
/// to a Video SDK account holder — it cannot be fetched without that
/// account, which is the Emperor's to create. So:
///
///   * This class compiles WITHOUT the SDK and reports
///     `sdkIntegrated == false`; the app builds green in no-Zoom-keys
///     mode and stays honest about the boundary.
///   * In CI, the workflow's optional "Zoom SDK (activates when secrets
///     exist)" step checks for the ZOOM_VIDEO_SDK_* secrets. When an SDK
///     vendoring step is added (SDK dropped into Frameworks/ via a
///     secrets-authenticated download), flip `sdkIntegrated` and
///     implement the marked points below.
///
/// Integration points when the SDK arrives (from Zoom's iOS reference):
///   1. Initialize: ZoomVideoSDK.shareInstance().initialize with the
///      config's VideoSDKKey and a JWT signed SERVER-SIDE from the SDK
///      secret (the secret itself never ships in the app).
///   2. Join: joinSession(sessionName, token, userName: "Nova",
///      audio/video options with raw-data senders attached).
///   3. Ears: subscribe the audio raw-data pipe -> SpeechRecognitionService
///      equivalent fed by SDK audio (per-participant separation on iOS
///      audio was UNVERIFIED in the Phase-1 research — verify at this step).
///   4. Mouth: ZoomVideoSDKAudioSender via the virtual-mic protocol —
///      feed it PCM from the active TTSProvider.
///   5. Face: ZoomVideoSDKVideoSender — render AvatarView frames
///      (ImageRenderer / CVPixelBuffer pipeline) as Nova's video.
///   6. Eyes: ZoomVideoSDKRawDataPipe per user -> Vision sampler.
@MainActor
final class VideoSDKZoomService: BaseZoomService {
    init(config: ZoomConfig) {
        super.init(mode: .videoSDKSandbox, config: config)
    }

    // sdkIntegrated stays false until the XCFramework is vendored and the
    // integration points above are implemented. Do not flip this flag to
    // make a build "look" integrated.
}
