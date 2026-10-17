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
                ShareCardSheetLink(
                    title: venue.name,
                    format: .story,
                    key: "\(venue.id)-\(games.count)",
                    variants: { await shareVariants(venue, games: games) }
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: .circle)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
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
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 56)
                    .contentShape(.rect)
                    .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func shareVariants(_ venue: Venue, games: [GameEntry]) async -> [ShareCardVariant] {
        let r = games.reduce(into: Stats.Record()) { $0.add(library.outcome($1)) }
        var photo: UIImage?
        if let ref = games.reversed().compactMap({ $0.photos.first }).first {
            photo = await PhotoLoader.load(ref)
        }
        var place = venue.cityLine
        if let capacity = venue.capacity, capacity > 0 {
            place += (place.isEmpty ? "" : " · ") + capacity.formatted() + " seats"
        }
        let record: String? = r.decided > 0 ? r.text : nil
        let first: String? = games.first.map { Fmt.day($0.date, in: venue.tz) }
        let last: String? = games.last.map { Fmt.day($0.date, in: venue.tz) }
        let count = games.count
        let name = venue.name
        let image = photo
        func card(_ style: VenueShareCard.Style) -> VenueShareCard {
            VenueShareCard(style: style, name: name, place: place, visits: count, record: record,
                           first: first, last: last, photo: image)
        }
        return [
            ShareCardVariant("Photo") { card(.photo) },
            ShareCardVariant("Number") { card(.type) },
            ShareCardVariant("Amber") { card(.color) },
            ShareCardVariant("Paper") { card(.paper) },
            ShareCardVariant("Stats") { card(.grid) },
        ]
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

/// 1080x1920 story card in five looks. Plain values only, so it renders the same anywhere.
private struct VenueShareCard: View {
    enum Style { case photo, type, color, paper, grid }

    let style: Style
    let name: String
    let place: String
    let visits: Int
    let record: String?
    let first: String?
    let last: String?
    let photo: UIImage?

    private static let paperColor = Color(red: 0.96, green: 0.95, blue: 0.92)

    private var visitsWord: String { visits == 1 ? "VISIT" : "VISITS" }

    private func label(_ text: String, _ color: Color, size: CGFloat = 40) -> some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .bold).width(.condensed))
            .tracking(5)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func mark(_ color: Color) -> some View {
        Text("WITNESS")
            .font(.system(size: 40, weight: .heavy).width(.compressed))
            .tracking(10)
            .foregroundStyle(color)
    }

    private func stat(_ value: String, _ title: String, value valueColor: Color, title titleColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.display(64))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            label(title, titleColor, size: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        switch style {
        case .photo: photoCard
        case .type: typeCard
        case .color: colorCard
        case .paper: paperCard
        case .grid: gridCard
        }
    }

    // 1. Full-bleed photo with big type at the bottom.
    private var photoCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color.signal.opacity(0.5), Color.ink], startPoint: .top, endPoint: .bottom)
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 1080, height: 1920)
                    .clipped()
            }
            LinearGradient(stops: [
                .init(color: .black.opacity(0.55), location: 0),
                .init(color: .black.opacity(0.1), location: 0.3),
                .init(color: .black.opacity(0.85), location: 0.65),
                .init(color: .black, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 28) {
                label(place, .white.opacity(0.8))
                Spacer(minLength: 40)
                Text(name.uppercased())
                    .font(.display(210))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.4)
                label("\(visits) \(visitsWord)" + (record.map { " · " + $0 } ?? ""), Color.signal, size: 52)
                mark(.white.opacity(0.9)).padding(.top, 24)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(width: 1080, height: 1920, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    // 2. Pure typographic: giant visit count on ink.
    private var typeCard: some View {
        ShareCardFrame(format: .story) {
            VStack(alignment: .leading, spacing: 24) {
                label(visitsWord, .white.opacity(0.6), size: 48)
                Text("\(visits)")
                    .font(.display(720))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .frame(height: 620, alignment: .topLeading)
                Text(name.uppercased())
                    .font(.display(110))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.4)
                if !place.isEmpty { label(place, .white.opacity(0.6)) }
                if let record {
                    Text(record)
                        .font(.display(120))
                        .foregroundStyle(Color.signal)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .padding(.top, 30)
                }
            }
        }
    }

    // 3. Solid accent field, black type, name as the hero.
    private var colorCard: some View {
        ZStack(alignment: .topLeading) {
            Color.signal
            VStack(alignment: .leading, spacing: 28) {
                label(place, .black.opacity(0.7))
                Text(name.uppercased())
                    .font(.display(190))
                    .foregroundStyle(.black)
                    .lineLimit(4)
                    .minimumScaleFactor(0.4)
                Spacer(minLength: 40)
                Text("\(visits)")
                    .font(.display(460))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                label(visitsWord + (record.map { " · " + $0 } ?? ""), .black.opacity(0.75), size: 52)
                mark(.black).padding(.top, 24)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(width: 1080, height: 1920, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
    }

    // 4. Light paper inverse.
    private var paperCard: some View {
        ZStack(alignment: .topLeading) {
            Self.paperColor
            VStack(alignment: .leading, spacing: 28) {
                label("Venue", .black.opacity(0.5))
                Text(name.uppercased())
                    .font(.display(150))
                    .foregroundStyle(.black)
                    .lineLimit(3)
                    .minimumScaleFactor(0.4)
                if !place.isEmpty { label(place, .black.opacity(0.55)) }
                Rectangle().fill(Color.black.opacity(0.85)).frame(height: 4).padding(.vertical, 24)
                HStack(alignment: .lastTextBaseline, spacing: 24) {
                    Text("\(visits)")
                        .font(.display(380))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                    label(visitsWord, .black.opacity(0.55), size: 52)
                }
                HStack(alignment: .top, spacing: 32) {
                    if let record { stat(record, "Record", value: .black, title: .black.opacity(0.55)) }
                    if let first { stat(first, "First", value: .black, title: .black.opacity(0.55)) }
                    if let last, last != first { stat(last, "Last", value: .black, title: .black.opacity(0.55)) }
                }
                Spacer(minLength: 40)
                mark(.black)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(width: 1080, height: 1920, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .light)
    }

    // 5. Data-forward ruled rows.
    private var gridCard: some View {
        let rows: [(String, String)] = [
            ("Visits", "\(visits)"),
            ("Record", record ?? "-"),
            ("First visit", first ?? "-"),
            ("Last visit", last ?? "-"),
        ]
        return ShareCardFrame(format: .story) {
            VStack(alignment: .leading, spacing: 20) {
                Text(name.uppercased())
                    .font(.display(120))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.4)
                if !place.isEmpty { label(place, .white.opacity(0.6)) }
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { i in
                        HStack(alignment: .center, spacing: 24) {
                            label(rows[i].0, .white.opacity(0.6), size: 44)
                            Spacer(minLength: 16)
                            Text(rows[i].1)
                                .font(.display(110))
                                .foregroundStyle(i == 1 ? Color.signal : Color.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                        }
                        .frame(height: 190)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color.white.opacity(0.25)).frame(height: 2)
                        }
                    }
                }
                .padding(.top, 50)
            }
        }
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
                let point = CGPoint(x: center.x + r * CGFloat(cos(mid.radians)), y: center.y + r * CGFloat(sin(mid.radians)))
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
