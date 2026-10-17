import SwiftUI

// MARK: - Type
//
// Three voices, all built into iOS so nothing has to be licensed or bundled:
//   Display: New York (SF's serif design) for editorial headlines and pull quotes.
//   Score:   SF Compressed, heavy, monospaced digits for scoreboards and big numbers.
//   UI:      SF Pro for everything functional.
// Eyebrows use SF Expanded in caps with wide tracking, like a broadcast lower third.

enum WType {
    // Display serif
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let heroTitle = display(44, weight: .regular)    // "You were there."
    static let screenTitle = display(34, weight: .regular)
    static let sectionTitle = display(24, weight: .regular)
    static let pullQuote = display(21, weight: .regular).italic()

    // Scoreboard numerals
    static func score(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        Font.system(size: size, weight: weight).width(.compressed).monospacedDigit()
    }

    static let scoreHero = score(108)
    static let scoreLarge = score(64)
    static let scoreCard = score(40)
    static let statNumber = score(56, weight: .bold)

    // UI
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let callout = Font.system(size: 15, weight: .regular)
    static let subhead = Font.system(size: 14, weight: .medium)
    static let footnote = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .medium)
    static let micro = Font.system(size: 10, weight: .semibold)

    // Eyebrow / label caps
    static let eyebrow = Font.system(size: 11, weight: .semibold).width(.expanded)
    static let eyebrowSmall = Font.system(size: 9.5, weight: .semibold).width(.expanded)
    static let monogram = Font.system(size: 15, weight: .black).width(.compressed)
}

enum Tracking {
    static let eyebrow: CGFloat = 1.8
    static let display: CGFloat = -0.6
    static let score: CGFloat = -1.5
}

// MARK: - Modifiers

struct EyebrowStyle: ViewModifier {
    var color: Color = Palette.textTertiary
    var small = false
    func body(content: Content) -> some View {
        content
            .font(small ? WType.eyebrowSmall : WType.eyebrow)
            .tracking(Tracking.eyebrow)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    func eyebrow(_ color: Color = Palette.textTertiary, small: Bool = false) -> some View {
        modifier(EyebrowStyle(color: color, small: small))
    }

    func displayTitle(_ font: Font = WType.screenTitle) -> some View {
        self.font(font).tracking(Tracking.display).foregroundStyle(Palette.textPrimary)
    }
}
