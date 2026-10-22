import Foundation

/// Zoom configuration, read from the app's Info.plist, whose values are
/// injected at build time from xcconfig variables (see Config/).
///
/// SECURITY RULES (binding, from research-zoom-sdk.md §1.5 / §2):
///   * Only key NAMES and presence flags live in the repository.
///   * Client keys may reach the app via xcconfig / GitHub Secrets at
///     build time. SDK SECRETS never ship inside the app bundle: they are
///     used server-side (or in a later token step) to sign join tokens.
///     That is why this struct carries `secretPresent` booleans, not secrets.
///   * An empty value means "not configured" and the app runs in
///     no-Zoom-keys mode. Nothing here invents or defaults a real key.
struct ZoomConfig: Equatable {
    var videoSDKKey: String
    var videoSDKSecretPresent: Bool
    var meetingSDKKey: String
    var meetingSDKSecretPresent: Bool

    var hasVideoSDKKeys: Bool { !videoSDKKey.isEmpty }
    var hasMeetingSDKKeys: Bool { !meetingSDKKey.isEmpty }
    var hasAnyKeys: Bool { hasVideoSDKKeys || hasMeetingSDKKeys }

    static func fromBundle(_ bundle: Bundle = .main) -> ZoomConfig {
        func string(_ key: String) -> String {
            (bundle.object(forInfoDictionaryKey: key) as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        func flag(_ key: String) -> Bool {
            string(key).uppercased() == "YES"
        }
        return ZoomConfig(
            videoSDKKey: string("VideoSDKKey"),
            videoSDKSecretPresent: flag("VideoSDKSecretPresent"),
            meetingSDKKey: string("MeetingSDKKey"),
            meetingSDKSecretPresent: flag("MeetingSDKSecretPresent")
        )
    }

    static let unconfigured = ZoomConfig(
        videoSDKKey: "", videoSDKSecretPresent: false,
        meetingSDKKey: "", meetingSDKSecretPresent: false
    )
}
