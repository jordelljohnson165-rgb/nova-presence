import SwiftUI

/// Nova's switchable appearances.
///
/// Ported 1:1 from the Phase-1 prototype (`prototype/index.html`), which
/// shipped exactly these three palettes. An appearance is DATA, not assets:
/// switching appearance = swapping this value live, mid-call, no restart.
/// Production can add palettes by adding a case here — nothing else changes.
enum AvatarPalette: String, CaseIterable, Identifiable {
    case novaBlue
    case solarGold
    case violetDusk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .novaBlue: return "Nova Blue"
        case .solarGold: return "Solar Gold"
        case .violetDusk: return "Violet Dusk"
        }
    }

    /// Primary energy / accent color (prototype: --accent)
    var accentHex: String {
        switch self {
        case .novaBlue: return "#4DA3FF"
        case .solarGold: return "#FFB52E"
        case .violetDusk: return "#A06BFF"
        }
    }

    /// Light accent (prototype: --accent2)
    var accent2Hex: String {
        switch self {
        case .novaBlue: return "#9FD0FF"
        case .solarGold: return "#FFD479"
        case .violetDusk: return "#CDB2FF"
        }
    }

    /// Hair color (prototype: .hairFill)
    var hairHex: String {
        switch self {
        case .novaBlue: return "#2B5FB8"
        case .solarGold: return "#8A5A12"
        case .violetDusk: return "#4B2A86"
        }
    }

    /// Clothing trim color (prototype: .trimFill)
    var trimHex: String {
        switch self {
        case .novaBlue: return "#1D2C52"
        case .solarGold: return "#3A2C10"
        case .violetDusk: return "#241640"
        }
    }

    var accent: Color { Color(hex: accentHex) }
    var accent2: Color { Color(hex: accent2Hex) }
    var hair: Color { Color(hex: hairHex) }
    var trim: Color { Color(hex: trimHex) }
}

extension Color {
    /// Minimal hex initializer ("#RRGGBB" or "RRGGBB") for palette data.
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
