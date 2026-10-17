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
                            Avatar(person: best.person, size: 32)
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
                        }
                        .frame(minHeight: 56)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lucky-companion")
                }

                ShareLink(item: shareText(rate: rate, odds: odds, delta: delta, usesOdds: usesOdds)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.primary)
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
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(background, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func bestCompanion(_ stats: Stats) -> Stats.Companion? {
        let qualified = stats.companions.filter { $0.games >= 3 && $0.record.rate != nil }
        return qualified.max { ($0.record.rate ?? 0) < ($1.record.rate ?? 0) } ?? stats.companions.first
    }

    private func shareText(rate: Double?, odds: Double, delta: Int?, usesOdds: Bool) -> String {
        guard let rate, let delta else { return "My games on Witness." }
        let sign = delta >= 0 ? "+" : ""
        return "My teams win \(rate.percentText) of the games I'm at, against \(odds.percentText) \(usesOdds ? "expected" : "for a coin flip"). That's \(sign)\(delta) points. Witness."
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
