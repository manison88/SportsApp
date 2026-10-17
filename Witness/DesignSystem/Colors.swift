import SwiftUI

// MARK: - Palette
//
// Witness is dark-first. The neutral palette is deliberately warm (stadium
// sodium light, film stock) rather than the cool grays of stock iOS. All
// saturated color in the product comes from team pairs, never from chrome.

enum Palette {
    // Surfaces, darkest to lightest
    static let ink = Color(hex: "050506")            // app background, true near-black
    static let night = Color(hex: "0A0A0C")          // scroll content background
    static let surface = Color(hex: "121215")        // cards
    static let surfaceRaised = Color(hex: "1A1A1F")  // chips, raised controls
    static let surfaceHigh = Color(hex: "24242A")    // pressed / selected

    // Text, warm white at descending emphasis
    static let textPrimary = Color(hex: "F5F1EA")
    static let textSecondary = Color(hex: "F5F1EA").opacity(0.64)
    static let textTertiary = Color(hex: "F5F1EA").opacity(0.40)
    static let textQuaternary = Color(hex: "F5F1EA").opacity(0.22)

    // Lines
    static let hairline = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.16)

    // Signals
    static let signal = Color(hex: "FFB547")         // stadium-light amber: highlights, "you" markers
    static let signalSoft = Color(hex: "FFD9A0")
    static let live = Color(hex: "FF4D3D")           // live / recording only
    static let win = Color(hex: "7CE0A3")
    static let loss = Color(hex: "FF8A7A")

    // Globe
    static let arc = Color(hex: "FFC870")
    static let arcHot = Color(hex: "FFF1D6")
}

// MARK: - Team color pairs

struct TeamPair: Hashable {
    let home: Team
    let away: Team

    /// The accent gradient for a game: home accent bleeding into away accent.
    var gradient: LinearGradient {
        LinearGradient(colors: [home.accentColor, away.accentColor],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// A soft wash for backgrounds behind cards.
    var wash: LinearGradient {
        LinearGradient(colors: [home.accentColor.opacity(0.42), away.accentColor.opacity(0.12), .clear],
                       startPoint: .topLeading, endPoint: .bottom)
    }
}

extension Team {
    var primaryColor: Color { Color(hex: colors.primary) }
    var secondaryColor: Color { Color(hex: colors.secondary) }
    /// Screen-safe vivid color for strokes and gradients on black.
    var accentColor: Color { Color(hex: colors.accent) }
    /// Whether text placed on `primaryColor` should be dark.
    var primaryIsLight: Bool { Color.luminance(hex: colors.primary) > 0.6 }
}

// MARK: - Hex

extension Color {
    init(hex: String, opacity: Double = 1) {
        let rgb = Color.rgb(hex: hex)
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: opacity)
    }

    static func rgb(hex: String) -> (r: Double, g: Double, b: Double) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return (1, 1, 1) }
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    /// Relative luminance (sRGB approximation), 0...1.
    static func luminance(hex: String) -> Double {
        let c = rgb(hex: hex)
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }
}
