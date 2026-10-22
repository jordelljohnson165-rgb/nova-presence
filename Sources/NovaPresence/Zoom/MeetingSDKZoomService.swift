import Foundation

/// Zoom Meeting SDK route — THE production route to real Zoom meetings,
/// stubbed behind the ZoomSessionService interface in Phase 2.
///
/// Non-negotiable platform facts (ARCHITECTURE.md + research-zoom-sdk.md §2):
///   * Custom UI mode ONLY for raw data on iOS. With the default Zoom UI,
///     raw-audio subscribe returns MobileRTCRawData_No_License.
///   * Raw streams open only after the flow:
///     requestRawLiveStreaming -> HOST GRANTS the privilege in-meeting ->
///     startRawLiveStreaming -> subscribe(). The host grant is a visible,
///     revocable consent act — we never route around it.
///   * The host is expected on a Pro-or-above plan for raw-data gates
///     (sources conflict on Pro vs Business+ — UNVERIFIED, Phase-1
///     research §2). Upgrading a plan is spending: the Emperor's word only.
///   * From 2026-03-02, joining meetings OUTSIDE the app owner's account
///     requires ZAK/OBF authorization; an OBF-authorized session ends
///     when the authorizing user leaves. Own-account meetings join with
///     an SDK JWT alone.
///   * External distribution needs Zoom Marketplace review + a
///     published/unlisted app; own-account use does not. We design for
///     own-account use.
///   * Custom UI must render Zoom's Active Apps Notifier and the SDK's
///     legal notices ourselves — a build checklist item, not optional.
///
/// INTEGRATION BOUNDARY (Phase 2): the Meeting SDK binary is obtained
/// from the Zoom Marketplace under the Emperor's Zoom account (SDK app
/// creation is his login, his act). Until then this class compiles
/// without the SDK, reports `sdkIntegrated == false`, and join attempts
/// fail honestly via BaseZoomService.
@MainActor
final class MeetingSDKZoomService: BaseZoomService {
    init(config: ZoomConfig) {
        super.init(mode: .meetingSDK, config: config)
    }

    // sdkIntegrated stays false until MobileRTC is vendored, Custom UI is
    // built (incl. Active Apps Notifier + legal notices), and the
    // privilege/token flows above are implemented and tested on device.
}
