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
        let card = LuckyShareCard(
            heroText: heroText,
            heroLabel: usesOdds ? "Points above the odds" : "Points above a coin flip",
            withMe: rate,
            withMeText: rate?.percentText ?? "\u{2013}",
            baseline: odds,
            baselineText: odds.percentText,
            baselineLabel: usesOdds ? "The odds" : "Coin flip",
            verdict: verdict,
            accent: accent
        )
        let key = "\(heroText)|\(rate?.percentText ?? "-")|\(odds.percentText)|\(usesOdds)"
        return ShareCardLink(title: "Lucky charm", format: .story, key: key, card: { card }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.primary)
    }
}

/// 1080x1920 story card: the points-above-the-odds number, then two bars (with me, the odds) and one line.
/// Story format: giant hero plus stacked bars use the full height.
private struct LuckyShareCard: View {
    let heroText: String
    let heroLabel: String
    let withMe: Double?
    let withMeText: String
    let baseline: Double
    let baselineText: String
    let baselineLabel: String
    let verdict: String
    let accent: Color

    private let barWidth: CGFloat = 912

    var body: some View {
        ShareCardFrame(format: .story, accent: accent) {
            VStack(alignment: .leading, spacing: 0) {
                Text("LUCKY CHARM")
                    .font(.system(size: 44, weight: .bold).width(.condensed))
                    .tracking(8)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(heroText)
                    .font(.display(420))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .padding(.top, 40)
                Text(heroLabel.uppercased())
                    .font(.system(size: 56, weight: .bold).width(.condensed))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 44) {
                    bar(label: "With me", valueText: withMeText, value: withMe ?? 0, fill: Color.signal)
                    bar(label: baselineLabel, valueText: baselineText, value: baseline, fill: Color.white.opacity(0.5))
                }
                .padding(.top, 90)
                Text(verdict)
                    .font(.system(size: 52, weight: .bold).width(.condensed))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 70)
            }
        }
    }

    private func bar(label: String, valueText: String, value: Double, fill: Color) -> some View {
        let clamped = CGFloat(min(max(value, 0), 1))
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                Text(label.uppercased())
                    .font(.system(size: 44, weight: .bold).width(.condensed))
                    .tracking(6)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 24)
                Text(valueText)
                    .font(.display(110))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.12))
                Rectangle().fill(fill).frame(width: barWidth * clamped)
            }
            .frame(width: barWidth, height: 24)
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
