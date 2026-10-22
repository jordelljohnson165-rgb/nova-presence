import XCTest
@testable import NovaPresence

/// Minimal unit tests — the avatar palettes and the Zoom config's
/// no-keys behavior are the two Phase-2 invariants that must never
/// regress silently (the palettes are Nova's appearances; the config
/// rules are the no-secrets-in-repo guarantee).
final class AvatarPaletteTests: XCTestCase {
    func testThreePrototypePalettesExist() {
        XCTAssertEqual(AvatarPalette.allCases.count, 3)
        XCTAssertEqual(AvatarPalette.novaBlue.displayName, "Nova Blue")
        XCTAssertEqual(AvatarPalette.solarGold.displayName, "Solar Gold")
        XCTAssertEqual(AvatarPalette.violetDusk.displayName, "Violet Dusk")
    }

    func testPaletteHexesMatchPrototype() {
        XCTAssertEqual(AvatarPalette.novaBlue.accentHex, "#4DA3FF")
        XCTAssertEqual(AvatarPalette.solarGold.accentHex, "#FFB52E")
        XCTAssertEqual(AvatarPalette.violetDusk.accentHex, "#A06BFF")
    }
}

final class ZoomConfigTests: XCTestCase {
    func testUnconfiguredHasNoKeys() {
        let config = ZoomConfig.unconfigured
        XCTAssertFalse(config.hasVideoSDKKeys)
        XCTAssertFalse(config.hasMeetingSDKKeys)
        XCTAssertFalse(config.hasAnyKeys)
    }

    func testEmptyStringsAreNotKeys() {
        // An xcconfig variable that expands to "" must read as
        // "not configured" — this is the no-Zoom-keys build mode.
        let config = ZoomConfig(videoSDKKey: "", videoSDKSecretPresent: false,
                                meetingSDKKey: "", meetingSDKSecretPresent: false)
        XCTAssertFalse(config.hasAnyKeys)
    }
}
