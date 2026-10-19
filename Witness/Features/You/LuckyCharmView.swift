import SwiftUI

/// 10 · Your win rate against what the odds expected.
struct LuckyCharmView: View {
    @Environment(Library.self) private var library

    var body: some View {
        let stats = Stats(library: library)
        let rate = stats.record.rate
        let odds = stats.expectedRate ?? 0.5
        let usesOdds = stats.expectedRate != nil
        let delta = rate.map { Int((($0 - odds) * 100).rounded()) }
        let accent = favoriteAccent

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                Text("You vs. the odds")
                    .displayFont(40)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("lucky-title")

                Dial(rate: rate ?? 0.5, delta: delta, caption: usesOdds ? "Points above the odds" : "Points above a coin flip")
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)

                HStack(spacing: Spacing.inner) {
                    tile(value: rate?.percentText ?? "–", label: "With you", background: accent)
                    tile(value: odds.percentText, label: usesOdds ? "The odds" : "Coin flip", background: Color.panelRaised)
                }

                if let best = bestCompanion(stats) {
                    NavigationLink(value: Route.person(best.person.id)) {
                        HStack(spacing: Spacing.inner) {
                            Avatar(person: best.person, size: 32).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("With \(best.person.name)")
                                    .font(.condensed(.headline, weight: .heavy))
                                    .textCase(.uppercase)
                                Text("\(best.record.text) in \(best.games) games")
                                    .font(.footnote)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Text(best.record.rate?.percentText ?? "–")
                                .displayFont(30, relativeTo: .title2)
                                .foregroundStyle(best.person.color)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Color.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 56)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lucky-companion")
                }

                shareLink(rate: rate, odds: odds, delta: delta, usesOdds: usesOdds, accent: accent)
                .accessibilityIdentifier("lucky-share")
            }
            .gutter()
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .inkBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private var favoriteAccent: Color {
        library.profile.favoriteTeamIds.compactMap { library.team($0) }.first?.accent ?? Color(hex: "2F6BFF")
    }

    private func tile(value: String, label: String, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).displayFont(44, relativeTo: .title)
            Text(label)
                .font(.condensed(.caption, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.6)
        }
        .foregroundStyle(background.readableInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(background, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func bestCompanion(_ stats: Stats) -> Stats.Companion? {
        let qualified = stats.companions.filter { $0.games >= 3 && $0.record.rate != nil }
        return qualified.max { ($0.record.rate ?? 0) < ($1.record.rate ?? 0) } ?? stats.companions.first
    }

    private func shareLink(rate: Double?, odds: Double, delta: Int?, usesOdds: Bool, accent: Color) -> some View {
        let heroText: String
        let verdict: String
        if let delta {
            heroText = delta > 0 ? "+\(delta)" : (delta < 0 ? "\u{2212}\(abs(delta))" : "0")
            if delta > 0 { verdict = "My teams win more when I show up." }
            else if delta == 0 { verdict = "Dead even when I show up." }
            else { verdict = "Not the lucky charm. Still showing up." }
        } else {
            heroText = "\u{2013}"
            verdict = "My games on Witness."
        }
        let heroLabel = usesOdds ? "Points above the odds" : "Points above a coin flip"
        let withMeText = rate?.percentText ?? "\u{2013}"
        let baselineText = odds.percentText
        let baselineLabel = usesOdds ? "The odds" : "Coin flip"
        let variants: [ShareCardVariant] = LuckyShareCard.Style.allCases.map { st in
            ShareCardVariant(st.name) {
                LuckyShareCard(
                    heroText: heroText, heroLabel: heroLabel,
                    withMe: rate, withMeText: withMeText,
                    baseline: odds, baselineText: baselineText, baselineLabel: baselineLabel,
                    verdict: verdict, accent: accent, style: st)
            }
        }
        let key = "\(heroText)|\(rate?.percentText ?? "-")|\(baselineText)|\(usesOdds)"
        return ShareCardSheetLink(kind: "lucky_charm", title: "Lucky charm", format: .story, key: key, variants: { variants }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.primary)
    }
}

/// 1080x1920 story cards, five looks. Story because the hero wants the height.
private struct LuckyShareCard: View {
    enum Style: CaseIterable {
        case number, color, paper, stub, split

        var name: String {
            switch self {
            case .number: return "Number"
            case .color: return "Color"
            case .paper: return "Versus"
            case .stub: return "Stub"
            case .split: return "Split"
            }
        }
    }

    let heroText: String
    let heroLabel: String
    let withMe: Double?
    let withMeText: String
    let baseline: Double
    let baselineText: String
    let baselineLabel: String
    let verdict: String
    let accent: Color
    let style: Style

    private let barWidth: CGFloat = 912

    private var fg: Color {
        switch style {
        case .paper: return Color.black
        case .color: return accent.readableInk
        default: return Color.white
        }
    }

    var body: some View {
        Group {
            if style == .split {
                splitBody
            } else {
                standardBody
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Pieces

    private func eyebrow(color: Color) -> some View {
        Text("LUCKY CHARM")
            .font(.system(size: 44, weight: .bold).width(.condensed))
            .tracking(8)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func hero(size: CGFloat, color: Color) -> some View {
        Text(heroText)
            .font(.display(size))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
    }

    private func caption(_ color: Color) -> some View {
        Text(heroLabel.uppercased())
            .font(.system(size: 56, weight: .bold).width(.condensed))
            .tracking(2)
            .foregroundStyle(color)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
    }

    private func label(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 44, weight: .bold).width(.condensed))
            .tracking(6)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func value(_ text: String, size: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.display(size))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    private func line(_ color: Color) -> some View {
        Text(verdict)
            .font(.system(size: 52, weight: .bold).width(.condensed))
            .textCase(.uppercase)
            .foregroundStyle(color)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
    }

    private func footer(_ color: Color) -> some View {
        Text("WITNESS")
            .font(.system(size: 40, weight: .heavy).width(.compressed))
            .tracking(10)
            .foregroundStyle(color)
    }

    private func bar(label text: String, valueText: String, value fraction: Double, fill: Color, track: Color, ink: Color) -> some View {
        let clamped = CGFloat(min(max(fraction, 0), 1))
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                label(text, color: ink.opacity(0.6))
                Spacer(minLength: 24)
                value(valueText, size: 110, color: ink)
            }
            ZStack(alignment: .leading) {
                Rectangle().fill(track)
                Rectangle().fill(fill).frame(width: barWidth * clamped)
            }
            .frame(width: barWidth, height: 24)
        }
    }

    // MARK: Standard layouts

    @ViewBuilder
    private var background: some View {
        switch style {
        case .color:
            accent
        case .paper:
            Color(hex: "F4F1EA")
        default:
            ZStack {
                Color.ink
                LinearGradient(colors: [accent.opacity(0.4), .clear], startPoint: .top, endPoint: .center)
            }
        }
    }

    private var standardBody: some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 0) {
                layout
                Spacer(minLength: 40)
                footer(fg.opacity(0.9))
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var layout: some View {
        switch style {
        case .number:
            numberLayout
        case .color:
            colorLayout
        case .paper:
            versusLayout
        default:
            stubLayout
        }
    }

    /// Giant delta on ink, two bars, one line. Amber marks "you" once.
    private var numberLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow(color: fg.opacity(0.7))
            hero(size: 420, color: fg).padding(.top, 40)
            caption(fg.opacity(0.85)).padding(.top, 8)
            VStack(alignment: .leading, spacing: 44) {
                bar(label: "With me", valueText: withMeText, value: withMe ?? 0,
                    fill: Color.signal, track: Color.white.opacity(0.12), ink: fg)
                bar(label: baselineLabel, valueText: baselineText, value: baseline,
                    fill: Color.white.opacity(0.5), track: Color.white.opacity(0.12), ink: fg)
            }
            .padding(.top, 90)
            line(fg.opacity(0.85)).padding(.top, 70)
        }
    }

    /// Team color field: the claim up top as big type, the delta low.
    private var colorLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow(color: fg.opacity(0.7))
            Text(verdict.uppercased())
                .font(.display(104))
                .foregroundStyle(fg)
                .lineLimit(3)
                .minimumScaleFactor(0.4)
                .padding(.top, 40)
            Spacer(minLength: 40)
            hero(size: 400, color: fg)
            caption(fg).padding(.top, 8)
            Rectangle().fill(fg).frame(height: 8).padding(.top, 50)
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    value(withMeText, size: 110, color: fg)
                    label("With me", color: fg.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    value(baselineText, size: 110, color: fg.opacity(0.75))
                    label(baselineLabel, color: fg.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 40)
        }
    }

    /// Paper: the two win rates face off as big type, the delta closes it.
    private var versusLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow(color: fg.opacity(0.6))
            label("With me", color: fg.opacity(0.6)).padding(.top, 50)
            value(withMeText, size: 330, color: fg)
            label(baselineLabel, color: fg.opacity(0.6)).padding(.top, 10)
            value(baselineText, size: 330, color: fg.opacity(0.3))
            Rectangle().fill(fg).frame(height: 10).padding(.top, 40)
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                hero(size: 170, color: fg)
                Text(heroLabel.uppercased())
                    .font(.system(size: 44, weight: .bold).width(.condensed))
                    .tracking(2)
                    .foregroundStyle(fg.opacity(0.8))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
            .padding(.top, 30)
        }
    }

    /// Ticket stub: delta above a dashed tear line, the two rates below, the line last.
    private var stubLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow(color: fg.opacity(0.7))
            VStack(alignment: .leading, spacing: 0) {
                hero(size: 330, color: fg)
                caption(fg.opacity(0.85)).padding(.top, 8)
                Rectangle()
                    .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 3, dash: [16, 12]))
                    .frame(height: 3)
                    .padding(.vertical, 50)
                VStack(spacing: 30) {
                    HStack(alignment: .firstTextBaseline, spacing: 24) {
                        label("With me", color: fg.opacity(0.6))
                        Spacer(minLength: 24)
                        value(withMeText, size: 100, color: fg)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 24) {
                        label(baselineLabel, color: fg.opacity(0.6))
                        Spacer(minLength: 24)
                        value(baselineText, size: 100, color: fg)
                    }
                }
            }
            .padding(56)
            .background(Color.white.opacity(0.08), in: .rect(cornerRadius: 40))
            .overlay(RoundedRectangle(cornerRadius: 40).strokeBorder(Color.white.opacity(0.25), lineWidth: 2))
            .padding(.top, 50)
            line(fg.opacity(0.85)).padding(.top, 50)
        }
    }

    // MARK: Split

    /// Top half in team color is "with me", bottom half on ink is the odds, the delta sits on the seam.
    private var splitBody: some View {
        let top = accent.readableInk
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                eyebrow(color: top.opacity(0.7))
                Spacer(minLength: 20)
                label("With me", color: top.opacity(0.75))
                value(withMeText, size: 380, color: top)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 130)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 960)
            .background(accent)
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 16) {
                    Text(heroText)
                        .font(.display(120))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("PTS")
                        .font(.system(size: 44, weight: .bold).width(.condensed))
                        .tracking(4)
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 18)
                .background(Color.white, in: .capsule)
                .padding(.leading, 84)
                .offset(y: 70)
            }
            .zIndex(1)

            VStack(alignment: .leading, spacing: 0) {
                label(baselineLabel, color: Color.white.opacity(0.6)).padding(.top, 120)
                value(baselineText, size: 380, color: Color.white.opacity(0.5))
                Spacer(minLength: 20)
                footer(Color.white.opacity(0.9))
            }
            .padding(.horizontal, 84)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.ink)
        }
    }
}

/// A thin 270° arc with ticks, a needle dot at your win rate, and the delta in the middle.
private struct Dial: View {
    let rate: Double
    let delta: Int?
    let caption: String

    private let start = 135.0
    private let sweep = 270.0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 - 14
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let clamped = min(max(rate, 0), 1)
            let angle = Angle.degrees(start + sweep * clamped)

            ZStack {
                Path { p in
                    p.addArc(center: center, radius: radius, startAngle: .degrees(start),
                             endAngle: .degrees(start + sweep), clockwise: false)
                }
                .stroke(Color.hairline, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                Path { p in
                    p.addArc(center: center, radius: radius, startAngle: .degrees(start),
                             endAngle: angle, clockwise: false)
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                Path { p in
                    for i in 0...10 {
                        let a = Angle.degrees(start + sweep * Double(i) / 10).radians
                        let inner = radius - (i % 5 == 0 ? 14 : 8)
                        p.move(to: CGPoint(x: center.x + CGFloat(cos(a)) * (radius - 4), y: center.y + CGFloat(sin(a)) * (radius - 4)))
                        p.addLine(to: CGPoint(x: center.x + CGFloat(cos(a)) * inner, y: center.y + CGFloat(sin(a)) * inner))
                    }
                }
                .stroke(Color.textTertiary, lineWidth: 1.5)

                Circle()
                    .fill(Color.signal)
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.signal.opacity(0.8), radius: 8)
                    .position(x: center.x + CGFloat(cos(angle.radians)) * radius, y: center.y + CGFloat(sin(angle.radians)) * radius)

                VStack(spacing: 4) {
                    Text(deltaText)
                        .displayFont(96)
                        .accessibilityIdentifier("lucky-delta")
                    Text(caption).unitLabel()
                }
                .position(center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(deltaText) \(caption)")
    }

    private var deltaText: String {
        guard let delta else { return "–" }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }
}
