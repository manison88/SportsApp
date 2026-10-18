import SwiftUI

/// 03 · Passport. A stamp for every park you've been to.
struct PassportView: View {
    @Environment(Library.self) private var library
    @State private var sport: Sport = .baseball

    struct Stamp: Identifiable {
        let venueId: String
        let code: String
        let color: Color
        let date: Date?
        /// Title games seen here; earns the stamp a gold star.
        var titles = 0
        var id: String { venueId }
    }

    private var sports: [Sport] {
        let present = Set(library.games.map(\.sport))
        let shown = Sport.allCases.filter { present.contains($0) }
        return shown.isEmpty ? [.baseball] : shown
    }

    var body: some View {
        let all = stamps()
        let titleVenues = Dictionary(grouping: library.games.filter { $0.sport == sport && $0.bigGame?.kind == .championship },
                                     by: \.venueId).mapValues(\.count)
        let earned = all.0.map { s -> Stamp in var s = s; s.titles = titleVenues[s.venueId] ?? 0; return s }
        let latest = earned.max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                filter

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 14) {
                        Text("\(earned.count)")
                            .displayFont(150)
                            .accessibilityIdentifier("passport-count")
                        Text(heroLabel(earned: earned.count))
                            .displayFont(40, relativeTo: .title)
                            .textCase(.uppercase)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(.white)
                    .accessibilityElement(children: .combine)

                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(earned) { stamp in
                        NavigationLink(value: Route.venue(stamp.venueId)) {
                            StampTile(stamp: stamp, isLatest: stamp.id == latest?.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("stamp-\(stamp.venueId)")
                    }
                }
            }
            .gutter()
            .padding(.bottom, Spacing.block)
        }
        .inkBackground()
        .onAppear { if !sports.contains(sport), let first = sports.first { sport = first } }
        .tabTitle("Passport")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareCardSheetLink(title: "My \(Self.league(sport)) passport", format: .story, key: "\(sport.rawValue)-\(earned.count)", variants: {
                    let tiles = earned.map { PassportShareTile(code: $0.code, color: $0.color) }
                    let label = heroLabel(earned: earned.count)
                    let league = Self.league(sport)
                    let count = earned.count
                    let styles: [(String, PassportShareCard.Style)] = [
                        ("Giant", .giant), ("Stamps", .stamps), ("Color", .color), ("Paper", .paper), ("Ledger", .ledger),
                    ]
                    return styles.map { entry in
                        ShareCardVariant(entry.0) {
                            PassportShareCard(style: entry.1, count: count, label: label, league: league, tiles: tiles)
                        }
                    }
                }, label: {
                    Image(systemName: "square.and.arrow.up").fontWeight(.bold)
                })
                .accessibilityLabel("Share passport")
            }
        }
    }

    private var filter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sports) { s in
                    Button {
                        sport = s
                    } label: {
                        Text(Self.league(s))
                            .font(.condensed(.subheadline, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(sport == s ? Color.black : Color.textSecondary)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(sport == s ? Color.white : Color.panelRaised, in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(sport == s ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    static func league(_ s: Sport) -> String {
        switch s {
        case .baseball: "MLB"
        case .football: "NFL"
        case .basketball: "NBA"
        case .hockey: "NHL"
        case .soccer: "SOCCER"
        case .motorsport: "MOTOR"
        case .handball: "HANDBALL"
        }
    }

    private func heroLabel(earned: Int) -> String {
        switch sport {
        case .baseball: earned == 1 ? "MLB\npark" : "MLB\nparks"
        case .soccer: earned == 1 ? "football\nground" : "football\ngrounds"
        case .motorsport: earned == 1 ? "circuit" : "circuits"
        case .handball: earned == 1 ? "handball\narena" : "handball\narenas"
        case .basketball, .hockey: earned == 1 ? "\(Self.league(sport))\narena" : "\(Self.league(sport))\narenas"
        case .football: earned == 1 ? "NFL\nstadium" : "NFL\nstadiums"
        }
    }

    /// Earned stamps (oldest first) and the parks still to visit.
    private func stamps() -> ([Stamp], [Stamp]) {
        let games = library.games.filter { $0.sport == sport }
        var firstVisit: [String: Date] = [:]
        for g in games { firstVisit[g.venueId] = min(firstVisit[g.venueId] ?? g.date, g.date) }

        if sport == .baseball {
            let all = library.ballparks.map { bp -> Stamp in
                let team = library.allTeams.first { $0.league == "MLB" && $0.abbreviation == bp.code }
                return Stamp(venueId: bp.venueId, code: bp.code, color: team?.accent ?? Color.panelRaised, date: firstVisit[bp.venueId])
            }
            let earned = all.filter { $0.date != nil }.sorted { $0.date! < $1.date! }
            let missing = all.filter { $0.date == nil }
            // Ballpark-less venues (spring training, minor league) still earn a stamp.
            let extra = firstVisit.keys.filter { id in !all.contains { $0.venueId == id } }.compactMap { stamp(for: $0, games: games, date: firstVisit[$0]) }
            return ((earned + extra).sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }, missing)
        }

        let earned = firstVisit.keys.compactMap { stamp(for: $0, games: games, date: firstVisit[$0]) }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        return (earned, [])
    }

    /// A venue's stamp wears the color of the team that plays there most.
    private func stamp(for venueId: String, games: [GameEntry], date: Date?) -> Stamp? {
        guard let venue = library.venue(venueId) else { return nil }
        // The tenant that played here most. A "home" side at a neutral ground (a World Cup game in Seattle) is not
        // the venue's team, so that stamp wears the country instead.
        let homes = games.filter { $0.venueId == venueId }.compactMap(\.homeTeamId).compactMap { library.team($0) }
            .filter { Self.isTenant($0, of: venue) }.map(\.id)
        let top = Dictionary(grouping: homes, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        let team = library.team(top)
        // A circuit wears its country (USA, ITA); any other neutral ground wears its city (SEA, SF, KC).
        let fallback = venue.sports.contains(.motorsport)
            ? (CountryCodes.iso3(venue.countryCode) ?? Self.cityCode(venue.city))
            : Self.cityCode(venue.city.isEmpty ? venue.name : venue.city)
        return Stamp(venueId: venueId, code: team?.abbreviation ?? fallback, color: team?.accent ?? Color(hex: "3A4150"), date: date)
    }

    /// A short code for a city: the first three letters of one word ("Seattle" is SEA), else the initials ("San Francisco" is SF).
    static func cityCode(_ city: String) -> String {
        let folded = city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let words = folded.split { !$0.isLetter }.map(String.init)
        guard let first = words.first else { return "" }
        let code = words.count == 1 ? String(first.prefix(3)) : String(words.compactMap(\.first).prefix(3))
        return code.uppercased()
    }

    /// True when the venue is the team's own ground: the catalog says so, or the venue lists the team as a tenant.
    static func isTenant(_ team: Team, of venue: Venue) -> Bool {
        if team.homeVenueId == venue.id { return true }
        // Tenants unknown: any club counts, but a national side never owns a club's ground.
        if (venue.homeTeams ?? []).isEmpty { return team.league != "National teams" && !team.id.hasPrefix("nat-") }
        let name = TicketParser.normalize(team.teamName), place = TicketParser.normalize(team.locationName)
        return (venue.homeTeams ?? []).contains { tenant in
            let t = TicketParser.normalize(tenant)
            return (!name.isEmpty && t.contains(name)) || (!place.isEmpty && !name.isEmpty && t.contains(place) && t.contains(name))
        }
    }
}

private struct StampTile: View {
    @Environment(Library.self) private var library
    let stamp: PassportView.Stamp
    let isLatest: Bool

    var body: some View {
        let ink = stamp.color.readableInk
        VStack(alignment: .leading, spacing: 6) {
            Text(stamp.code)
                .displayFont(34, relativeTo: .title)
                .foregroundStyle(ink)
            // The code is the team's; the stadium is the stamp's real name.
            if let name = library.venue(stamp.venueId)?.name {
                Text(name)
                    .font(.condensed(.caption, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(stamp.date.map { Fmt.day($0) } ?? "")
                .font(.condensed(.caption2, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(ink.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(12)
        .background { StampBackdrop(venue: library.venue(stamp.venueId), color: stamp.color) }
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ink.opacity(0.22), lineWidth: 1.5).padding(5))
        .overlay(alignment: .topTrailing) {
            if stamp.titles > 0 {
                Image(systemName: "star.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.trophy)
                    .padding(6)
                    .background(Color.ink.opacity(0.85), in: .circle)
                    .padding(8)
                    .accessibilityLabel(stamp.titles == 1 ? "Title game seen here" : "\(stamp.titles) title games seen here")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Share card

private struct PassportShareTile {
    let code: String
    let color: Color
}

/// 1080x1920 story card in five looks. Plain values only, no @Environment.
private struct PassportShareCard: View {
    enum Style { case giant, stamps, color, paper, ledger }

    let style: Style
    let count: Int
    let label: String
    let league: String
    let tiles: [PassportShareTile]

    private let gap: CGFloat = 16
    private let paperBg = Color(hex: "F4F1EA")

    var body: some View {
        switch style {
        case .giant: giant
        case .stamps: stamps
        case .color: colorField
        case .paper: paper
        case .ledger: ledger
        }
    }

    // MARK: Styles

    /// Pure type: an enormous count on ink.
    private var giant: some View {
        ShareCardFrame(format: .story) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.display(760))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                Text(label.uppercased())
                    .font(.system(size: 88, weight: .heavy).width(.compressed))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                Text("\(league) PASSPORT")
                    .font(.system(size: 40, weight: .bold).width(.condensed))
                    .tracking(8)
                    .foregroundStyle(Color.signal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 36)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// Hero count over a grid of stamp tiles.
    private var stamps: some View {
        ShareCardFrame(format: .story) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(league) PASSPORT")
                    .font(.system(size: 40, weight: .bold).width(.condensed))
                    .tracking(8)
                    .foregroundStyle(Color.signal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("\(count)")
                    .font(.display(420))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.top, 8)
                Text(label.uppercased())
                    .font(.system(size: 64, weight: .heavy).width(.compressed))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 40)
                stampGrid(tileText: nil, moreFill: Color.panelRaised, moreInk: .white)
                    .padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// A solid field in the color of the latest stamp.
    private var colorField: some View {
        let bg = tiles.last?.color ?? Color.signal
        let ink = bg.readableInk
        return ZStack(alignment: .topLeading) {
            bg
            VStack(alignment: .leading, spacing: 0) {
                Text("\(league) PASSPORT")
                    .font(.system(size: 40, weight: .bold).width(.condensed))
                    .tracking(8)
                    .foregroundStyle(ink.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.display(560))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                Text(label.uppercased())
                    .font(.system(size: 72, weight: .heavy).width(.compressed))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                Text(tiles.suffix(12).map { $0.code }.joined(separator: "  "))
                    .font(.system(size: 40, weight: .bold).width(.condensed))
                    .tracking(4)
                    .foregroundStyle(ink.opacity(0.75))
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 40)
                Spacer(minLength: 0)
                Text("WITNESS")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .tracking(10)
                    .foregroundStyle(ink)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    /// Light inverse: off-white paper, black type, colored stamps.
    private var paper: some View {
        ZStack(alignment: .topLeading) {
            paperBg
            VStack(alignment: .leading, spacing: 0) {
                Text("\(league) PASSPORT")
                    .font(.system(size: 40, weight: .bold).width(.condensed))
                    .tracking(8)
                    .foregroundStyle(Color.black.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("\(count)")
                    .font(.display(420))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.top, 8)
                Text(label.uppercased())
                    .font(.system(size: 64, weight: .heavy).width(.compressed))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 40)
                stampGrid(tileText: nil, moreFill: Color.black.opacity(0.08), moreInk: .black)
                    .padding(.bottom, 60)
                Text("WITNESS")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .tracking(10)
                    .foregroundStyle(Color.black)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .light)
    }

    /// Data-forward list: numbered rows, latest first, each with a bar of the stamp's color.
    private var ledger: some View {
        let rows: [PassportShareTile] = Array(tiles.suffix(9).reversed())
        return ShareCardFrame(format: .story) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    Text("\(count)")
                        .font(.display(240))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text(label.uppercased())
                        .font(.system(size: 52, weight: .heavy).width(.compressed))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }
                Text("LATEST STAMPS")
                    .font(.system(size: 36, weight: .bold).width(.condensed))
                    .tracking(8)
                    .foregroundStyle(Color.signal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<rows.count, id: \.self) { k in
                        HStack(spacing: 28) {
                            Text(String(format: "%02d", tiles.count - k))
                                .font(.system(size: 40, weight: .bold).width(.condensed))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 70, alignment: .leading)
                            Text(rows[k].code)
                                .font(.display(84))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: 220, alignment: .leading)
                            Capsule()
                                .fill(rows[k].color)
                                .frame(height: 18)
                        }
                        .frame(height: 112)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Pieces

    /// Up to 20 tiles, 5 columns; the latest 19 plus a "+N" tile when there are more.
    private func stampGrid(tileText: String?, moreFill: Color, moreInk: Color) -> some View {
        let columns = 5
        let maxTiles = 20
        let overflow = tiles.count > maxTiles
        let shown: [PassportShareTile] = overflow ? Array(tiles.suffix(maxTiles - 1)) : tiles
        let extra = tiles.count - shown.count
        let slots = shown.count + (overflow ? 1 : 0)
        let rowCount = (slots + columns - 1) / columns
        let side = (912 - gap * CGFloat(columns - 1)) / CGFloat(columns)
        return VStack(alignment: .leading, spacing: gap) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<columns, id: \.self) { col in
                        let i = row * columns + col
                        if i < shown.count {
                            tile(shown[i].code, fill: shown[i].color, ink: shown[i].color.readableInk, side: side)
                        } else if i == shown.count && overflow {
                            tile("+\(extra)", fill: moreFill, ink: moreInk, side: side)
                        } else {
                            Color.clear.frame(width: side, height: side)
                        }
                    }
                }
            }
        }
    }

    private func tile(_ text: String, fill: Color, ink: Color, side: CGFloat) -> some View {
        Text(text)
            .font(.display(64))
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 8)
            .frame(width: side, height: side)
            .background(fill, in: .rect(cornerRadius: 22))
    }
}


/// The stamp's team color over a faded satellite view of its ground.
private struct StampBackdrop: View {
    let venue: Venue?
    let color: Color
    @State private var image: UIImage?

    var body: some View {
        // Overlays, so the photo's fill size can never grow the tile past its grid cell.
        color
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .saturation(0).opacity(0.55).blendMode(.luminosity)
                }
            }
            .overlay {
                LinearGradient(colors: [color, color.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .opacity(0.92)
            }
            .clipShape(.rect(cornerRadius: 16))
        .task(id: venue?.id) {
            if let venue { image = await AerialCache.shared.image(for: venue, points: 120) }
        }
    }
}
