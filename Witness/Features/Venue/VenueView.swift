import SwiftUI

/// 08 · Venue. Photo hero with the venue name, your record there, the
/// sections you sat in, and first and last visit.
struct VenueView: View {
    let venueId: String

    @Environment(Library.self) private var library

    var body: some View {
        if let venue = library.venue(venueId) {
            content(venue)
        } else {
            ContentUnavailableView("Venue not found", systemImage: "building.columns")
                .inkBackground()
        }
    }

    private func content(_ venue: Venue) -> some View {
        let games = library.games(at: venue.id).sorted { $0.date < $1.date }
        let sections = Self.sections(in: games)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                hero(venue, games: games)
                record(venue, games: games).gutter()
                if venue.sports.contains(.baseball), !sections.isEmpty {
                    SeatMap(sections: Array(sections.prefix(3)))
                        .frame(height: 250)
                        .gutter()
                        .accessibilityElement()
                        .accessibilityLabel("Sections you sat in: " + sections.prefix(3).map { "\($0)" }.joined(separator: ", "))
                }
                if let first = games.first, let last = games.last {
                    StatRow(items: [
                        .init(value: Fmt.day(first.date, in: venue.tz), label: "First visit"),
                        .init(value: Fmt.day(last.date, in: venue.tz), label: "Last visit"),
                    ], size: 24)
                    .gutter()
                }
                if !games.isEmpty {
                    gameList(Array(games.reversed()), venue: venue).gutter()
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .inkBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText(venue, games: games)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: .circle)
                }
                .accessibilityLabel("Share")
            }
        }
    }

    // MARK: Hero

    private func hero(_ venue: Venue, games: [GameEntry]) -> some View {
        let photoGame = games.last { !$0.photos.isEmpty } ?? games.last
        return ZStack(alignment: .bottomLeading) {
            Group {
                if let photoGame {
                    GameBackdrop(game: photoGame)
                } else {
                    LinearGradient(colors: [Color.panelRaised, Color.ink], startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 400)
            .clipped()
            Scrim()
            VStack(alignment: .leading, spacing: 6) {
                Text(venue.name.uppercased())
                    .displayFont(48)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .accessibilityIdentifier("venue-title")
                    .accessibilityAddTraits(.isHeader)
                Text(venue.cityLine)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .gutter()
            .padding(.bottom, 4)
        }
        .frame(height: 400)
    }

    // MARK: Record

    @ViewBuilder
    private func record(_ venue: Venue, games: [GameEntry]) -> some View {
        let r = games.reduce(into: Stats.Record()) { $0.add(library.outcome($1)) }
        let nights = games.filter { g in
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = venue.tz
            return cal.component(.hour, from: g.date) >= 17
        }.count
        HStack(alignment: .lastTextBaseline, spacing: 14) {
            Text(r.decided > 0 ? r.text : "\(games.count)")
                .displayFont(96)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("venue-record")
            VStack(alignment: .leading, spacing: 4) {
                Text(r.decided > 0 ? "Your record" : (games.count == 1 ? "Game" : "Games")).unitLabel()
                if r.decided > 0 {
                    Text(nights > 0 ? "\(nights) \(nights == 1 ? "night" : "nights")" : "\(games.count) \(games.count == 1 ? "game" : "games")")
                        .font(.condensed(.headline, weight: .heavy))
                        .textCase(.uppercase)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Games

    private func gameList(_ games: [GameEntry], venue: Venue) -> some View {
        VStack(spacing: 0) {
            ForEach(games) { game in
                NavigationLink(value: Route.game(game.id)) {
                    HStack(spacing: 12) {
                        ScoreBug(game: game)
                        Spacer(minLength: 8)
                        Text(Fmt.day(game.date, in: venue.tz))
                            .font(.condensed(.subheadline, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(minHeight: 56)
                    .contentShape(.rect)
                    .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func shareText(_ venue: Venue, games: [GameEntry]) -> String {
        let r = games.reduce(into: Stats.Record()) { $0.add(library.outcome($1)) }
        return "\(venue.name): \(games.count) games, \(r.text). · Witness"
    }

    /// Section numbers from seat strings ("Bleachers · Section 314"), most frequent first.
    static func sections(in games: [GameEntry]) -> [Int] {
        var counts: [Int: Int] = [:]
        var order: [Int] = []
        for g in games {
            guard let seat = g.seat else { continue }
            var run = ""
            var found: Int?
            for ch in seat + " " {
                if ch.isASCII, ch.isNumber {
                    run.append(ch)
                } else {
                    if found == nil, run.count >= 2, run.count <= 3, let n = Int(run) { found = n }
                    run = ""
                }
            }
            if let n = found {
                if counts[n] == nil { order.append(n) }
                counts[n, default: 0] += 1
            }
        }
        return order.sorted { (counts[$0] ?? 0) > (counts[$1] ?? 0) }
    }
}

/// A simple ballpark seating fan: three tiers of wedges around a diamond.
/// The most frequent section glows amber; up to two more are lit dimmer.
private struct SeatMap: View {
    let sections: [Int]

    private static let wedgesPerTier = 11
    private static let tiers: [(CGFloat, CGFloat)] = [(0.40, 0.58), (0.62, 0.79), (0.83, 1.0)]

    private func slot(_ section: Int) -> (tier: Int, index: Int) {
        let tier = min(2, max(0, section / 100 - 1))
        return (tier, (section % 100) % Self.wedgesPerTier)
    }

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width / 1.8, size.height * 0.95)
            let center = CGPoint(x: size.width / 2, y: size.height * 0.97)
            let start = 210.0, end = 330.0
            let step = (end - start) / Double(Self.wedgesPerTier)
            let gap = 1.2

            var lit: [String: Int] = [:]
            for (rank, s) in sections.enumerated() {
                let sl = slot(s)
                lit["\(sl.tier)-\(sl.index)"] = rank
            }

            for (t, band) in Self.tiers.enumerated() {
                for i in 0..<Self.wedgesPerTier {
                    let a0 = Angle(degrees: start + Double(i) * step + gap / 2)
                    let a1 = Angle(degrees: start + Double(i + 1) * step - gap / 2)
                    let path = Self.wedge(center: center, r0: radius * band.0, r1: radius * band.1, a0: a0, a1: a1)
                    if let rank = lit["\(t)-\(i)"] {
                        let color: Color = rank == 0 ? .signal : Color.signal.opacity(rank == 1 ? 0.5 : 0.35)
                        context.fill(path, with: .color(color))
                    } else {
                        context.fill(path, with: .color(Color.panelRaised))
                    }
                }
            }

            // Labels on the lit sections.
            for (rank, s) in sections.enumerated() {
                let sl = slot(s)
                let band = Self.tiers[sl.tier]
                let mid = Angle(degrees: start + (Double(sl.index) + 0.5) * step)
                let r = radius * (band.0 + band.1) / 2
                let point = CGPoint(x: center.x + r * cos(mid.radians), y: center.y + r * sin(mid.radians))
                let label = Text("\(s)")
                    .font(.system(size: rank == 0 ? 15 : 13, weight: .heavy).width(.condensed))
                    .foregroundStyle(rank == 0 ? Color.black : Color.white)
                context.draw(label, at: point)
            }

            // The diamond.
            let d = radius * 0.17
            let home = CGPoint(x: center.x, y: center.y - radius * 0.05)
            var diamond = Path()
            diamond.move(to: home)
            diamond.addLine(to: CGPoint(x: home.x + d, y: home.y - d))
            diamond.addLine(to: CGPoint(x: home.x, y: home.y - 2 * d))
            diamond.addLine(to: CGPoint(x: home.x - d, y: home.y - d))
            diamond.closeSubpath()
            context.stroke(diamond, with: .color(Color.white.opacity(0.35)), lineWidth: 1.5)
        }
    }

    static func wedge(center: CGPoint, r0: CGFloat, r1: CGFloat, a0: Angle, a1: Angle) -> Path {
        var p = Path()
        p.addArc(center: center, radius: r1, startAngle: a0, endAngle: a1, clockwise: false)
        p.addArc(center: center, radius: r0, startAngle: a1, endAngle: a0, clockwise: true)
        p.closeSubpath()
        return p
    }
}
