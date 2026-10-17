import SwiftUI

// MARK: - Motion
//
// Physical, never decorative: things have mass and settle. Default to springs;
// linear timing is reserved for ambient loops (camera pans, film grain).

enum Motion {
    /// Card to detail, sheet presentation. Slightly underdamped so it lands.
    static let hero = Animation.spring(response: 0.55, dampingFraction: 0.82)
    /// Taps, toggles, selection changes.
    static let snappy = Animation.snappy(duration: 0.32)
    /// Content arriving on screen (stats counting in, cards materializing).
    static let reveal = Animation.spring(response: 0.8, dampingFraction: 0.9)
    /// Staggered list entrances.
    static func stagger(_ index: Int, base: Double = 0.06) -> Animation {
        reveal.delay(Double(index) * base)
    }
    /// Slow ambient camera drift, e.g. the welcome stadium pan.
    static let ambientPan = Animation.easeInOut(duration: 16).repeatForever(autoreverses: true)
    /// Globe settle-in when the home screen appears.
    static let globeSettle = Animation.easeOut(duration: 2.6)

    /// Photo parallax: header content moves at this fraction of scroll speed.
    static let parallax: CGFloat = 0.42
    /// Scale applied to a pressed card.
    static let pressScale: CGFloat = 0.97
}

/// Press feedback that compresses a card like a physical object.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Motion.pressScale : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}
