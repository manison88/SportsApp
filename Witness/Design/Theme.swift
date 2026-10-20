import SwiftUI

// MARK: - Witness design system: "Broadcast, cleaned"
//
// One hero per screen (a giant number, a score, or a full-bleed photo), at most
// three blocks under it, 20pt gutters, 28pt between blocks, nothing under 12pt.
// Color comes from teams; amber marks "you" once per screen; red means live.
// Type is SF Pro on its compressed width axis, so it stays Dynamic Type aware.

extension Color {
    static let ink = Color("Ink")
    static let panel = Color("Panel")
    static let panelRaised = Color("PanelRaised")
    static let hairline = Color("Hairline")
    static let signal = Color("Signal")
    static let live = Color("Live")
    /// Champagne gold, only for title games. Amber stays "you".
    static let trophy = Color("Trophy")
    /// Body text and icons: white in dark, ink in light. Plain `.white` stays only on photos, team colors and cards.
    static let primaryText = Color("PrimaryText")
    /// Ink that stays ink in light mode: the fade under text that sits on a photo or team color.
    static let photoInk = Color(hex: "07080A")
    /// The label on a primaryText fill: black in dark, white in light.
    static let onPrimary = Color("OnPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")

    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0xFFFFFF
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    /// White when it reaches 4.5:1 on this fill, otherwise black.
    var readableInk: Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let lum = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        return 1.05 / (lum + 0.05) >= 4.5 ? .white : .black
    }

    /// The same hue, darkened just enough for white text to reach 4.5:1.
    var deepenedForWhiteText: Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        var k: CGFloat = 1
        while k > 0.2 {
            let lum = 0.2126 * lin(r * k) + 0.7152 * lin(g * k) + 0.0722 * lin(b * k)
            if 1.05 / (lum + 0.05) >= 4.5 { break }
            k -= 0.02
        }
        return Color(.sRGB, red: Double(r * k), green: Double(g * k), blue: Double(b * k))
    }
}

enum Spacing {
    static let gutter: CGFloat = 20
    static let block: CGFloat = 28
    static let inner: CGFloat = 12
}

extension Font {
    /// Fixed-size display face. On screen, use `.displayFont(_:relativeTo:)`, which scales.
    static func display(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .heavy, design: .default).width(.compressed)
    }

    /// Condensed bold for row titles, labels and buttons.
    static func condensed(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        Font.system(style, design: .default, weight: weight).width(.condensed)
    }
}

/// Scales a fixed display size with the user's Dynamic Type setting.
struct ScaledDisplay: ViewModifier {
    @ScaledMetric private var size: CGFloat
    init(_ size: CGFloat, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
    }
    func body(content: Content) -> some View {
        content.font(.display(size)).monospacedDigit()
    }
}

extension View {
    func displayFont(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> some View {
        modifier(ScaledDisplay(size, relativeTo: style))
    }

    /// Uppercase condensed label used for units and functional state ("MILES", "FINAL").
    func unitLabel() -> some View {
        self.font(.condensed(.caption, weight: .bold))
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(Color.textSecondary)
    }
}

/// The single white primary action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = .primaryText
    /// Label color on the fill: black on amber, the inverse of the text color on the default fill.
    var onFill: Color = .onPrimary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.condensed(.headline, weight: .heavy))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(onFill)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(fill, in: .rect(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// Secondary action on a dark panel.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.condensed(.headline, weight: .heavy))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(Color.primaryText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.panelRaised, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hairline))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Applies the brand typeface to the system navigation bar so large titles,
/// back buttons and the tab bar stay system components.
enum Appearance {
    static func apply() {
        let large = UIFont.systemFont(ofSize: 34, weight: .heavy, width: .compressed)
        let inline = UIFont.systemFont(ofSize: 19, weight: .heavy, width: .condensed)
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large),
                                        .foregroundColor: UIColor(named: "PrimaryText") ?? .label]
        nav.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline),
                                   .foregroundColor: UIColor(named: "PrimaryText") ?? .label]
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        scrolled.largeTitleTextAttributes = nav.largeTitleTextAttributes
        scrolled.titleTextAttributes = nav.titleTextAttributes
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactScrollEdgeAppearance = nav
        UINavigationBar.appearance().largeTitleTextAttributes = nav.largeTitleTextAttributes
        UINavigationBar.appearance().titleTextAttributes = nav.titleTextAttributes

        // Tab labels stay one small, fixed size. They sit under an icon, and at large Dynamic Type sizes
        // scaled labels grew past the button and overlapped it.
        let tabFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        for state in [UIControl.State.normal, .selected, .highlighted] {
            UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: state)
        }
    }
}

/// The Appearance setting: follow the phone, or force light or dark. Stored under "appearance" as a plain string.
enum AppearanceChoice: String, CaseIterable {
    case auto, light, dark

    init(stored: String) { self = AppearanceChoice(rawValue: stored) ?? .auto }

    /// nil lets the system decide.
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
