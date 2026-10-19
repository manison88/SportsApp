import SwiftUI

/// 03 · Passport. A stamp for every park you've been to.
struct PassportView: View {
    @Environment(Library.self) private var library
    @State private var sport: Sport = .baseball
    /// "soccer" or "football", once the fan has said which; empty until then.
    @AppStorage("soccerWord") private var soccerWord = ""

    struct Stamp: Identifiable {
        let venueId: String
        let code: String
        let color: Color
        let date: Date?
        /// Title games seen here; earns the stamp a gold star.
        var titles = 0
        var id: String { venueId }
        /// The plan a dashed stamp stands for.
        var planId = ""
    }

    private var sports: [Sport] {
        let present = Set(library.games.map(\.sport))
        let shown = Sport.allCases.filter { present.contains($0) }
        return shown.isEmpty ? [.baseball] : shown
    }

    var body: some View {
        let earned = earnedStamps(sport)
        let latest = earned.max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                filter
                if sport == .soccer && soccerWord.isEmpty { wordPrompt }

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 14) {
                        Text("\(earned.count)")
                            .displayFont(150)
                            .accessibilityIdentifier("passport-count")
                        Text(heroLabel(earned: earned.count, sport: sport))
                            .displayFont(40, relativeTo: .title)
                            .textCase(.uppercase)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(.white)
                    .accessibilityElement(children: .combine)

                    if let next = plannedStamps(excluding: Set(earned.map(\.venueId)), sport: sport).first, let date = next.date {
                        Text("+ \(library.venue(next.venueId)?.name ?? next.code) planned for \(Fmt.day(date).capitalized)")
                            .font(.subheadline).foregroundStyle(Color.signal)
                            .accessibilityIdentifier("passport-planned-caption")
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(earned) { stamp in
                        NavigationLink(value: Route.venue(stamp.venueId)) {
                            StampTile(stamp: stamp, isLatest: stamp.id == latest?.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("stamp-\(stamp.venueId)")
                    }
                    ForEach(plannedStamps(excluding: Set(earned.map(\.venueId)), sport: sport)) { stamp in
                        NavigationLink(value: Route.plan(stamp.planId)) {
                            PlannedStampTile(stamp: stamp)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("planned-stamp-\(stamp.venueId)")
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
                ShareCardSheetLink(kind: "passport", title: "Share passport", format: .story, key: "\(sport.rawValue)-\(earned.count)", variants: {
                    // This sport's page, then every sport together: the same tiles, each with its ground from above, sized to fit.
                    let page = await shareTiles(earned)
                    let planned = plannedStamps(excluding: Set(earned.map(\.venueId)), sport: sport)
                    var everyEarned: [Stamp] = [], everyPlanned: [Stamp] = []
                    var seen = Set<String>()
                    for s in sports {
                        for stamp in earnedStamps(s) where seen.insert(stamp.venueId).inserted { everyEarned.append(stamp) }
                    }
                    everyEarned.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
                    for s in sports {
                        for stamp in plannedStamps(excluding: seen, sport: s) where seen.insert(stamp.venueId).inserted { everyPlanned.append(stamp) }
                    }
                    let full = sports.count > 1 ? await shareTiles(everyEarned) : []
                    let label = heroLabel(earned: earned.count, sport: sport)
                    let league = Self.league(sport)
                    var variants = [ShareCardVariant("\(league) passport") {
                        PassportPageCard(count: page.count, label: label, league: league, tiles: page, planned: planned)
                    }]
                    if sports.count > 1 {
                        variants.append(ShareCardVariant("Full passport") {
                            PassportPageCard(count: full.count, label: full.count == 1 ? "venue\nvisited" : "venues\nvisited",
                                             league: "FULL", tiles: full, planned: everyPlanned)
                        })
                    }
                    return variants
                }, label: {
                    Image(systemName: "square.and.arrow.up").fontWeight(.bold)
                })
                .accessibilityLabel("Share passport")
            }
        }
    }

    /// Asked once, the first time the fan opens the soccer passport: it names the passport, its share card and the sport everywhere.
    private var wordPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Soccer or football?").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
            Text("What do you call it? We\u{2019}ll use your word on your passport and when you share it.")
                .font(.footnote).foregroundStyle(Color.textSecondary)
            HStack(spacing: 10) {
                Button("Soccer") { soccerWord = "soccer" }
                    .buttonStyle(PrimaryButtonStyle(fill: SoccerWord.usesFootball ? .white : .signal))
                    .accessibilityIdentifier("soccer-word-soccer")
                Button("Football") { soccerWord = "football" }
                    .buttonStyle(PrimaryButtonStyle(fill: SoccerWord.usesFootball ? .signal : .white))
                    .accessibilityIdentifier("soccer-word-football")
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(Color.panel, in: .rect(cornerRadius: 16))
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
        case .soccer: SoccerWord.usesFootball ? "FOOTBALL" : "SOCCER"
        case .motorsport: "MOTOR"
        case .handball: "HANDBALL"
        }
    }

    private func heroLabel(earned: Int, sport: Sport) -> String {
        switch sport {
        case .baseball: earned == 1 ? "MLB\npark" : "MLB\nparks"
        case .soccer: SoccerWord.usesFootball ? (earned == 1 ? "football\nground" : "football\ngrounds")
                                              : (earned == 1 ? "soccer\nstadium" : "soccer\nstadiums")
        case .motorsport: earned == 1 ? "circuit" : "circuits"
        case .handball: earned == 1 ? "handball\narena" : "handball\narenas"
        case .basketball, .hockey: earned == 1 ? "\(Self.league(sport))\narena" : "\(Self.league(sport))\narenas"
        case .football: earned == 1 ? "NFL\nstadium" : "NFL\nstadiums"
        }
    }

    /// Earned stamps, oldest first, with their title-game stars.
    private func earnedStamps(_ sport: Sport) -> [Stamp] {
        let titleVenues = Dictionary(grouping: library.games.filter { $0.sport == sport && $0.bigGame?.kind == .championship },
                                     by: \.venueId).mapValues(\.count)
        return stamps(sport).0.map { s -> Stamp in var s = s; s.titles = titleVenues[s.venueId] ?? 0; return s }
    }

    /// Share tiles with each ground from above, loaded before drawing.
    private func shareTiles(_ stamps: [Stamp]) async -> [PassportShareTile] {
        var out: [PassportShareTile] = []
        for stamp in stamps {
            let venue = library.venue(stamp.venueId)
            let aerial: UIImage? = if let venue { await AerialCache.shared.image(for: venue, points: 120) } else { nil }
            out.append(PassportShareTile(code: stamp.code, color: stamp.color, name: venue?.name, date: stamp.date,
                                         titles: stamp.titles, aerial: aerial))
        }
        return out
    }

    /// Earned stamps (oldest first) and the parks still to visit.
    private func stamps(_ sport: Sport) -> ([Stamp], [Stamp]) {
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

    /// Dashed stamps for grounds you plan to visit and haven't yet, soonest first.
    private func plannedStamps(excluding earnedVenues: Set<String>, sport: Sport) -> [Stamp] {
        var seen = Set<String>()
        return PlanText.coming(library).filter { $0.sport == sport && !earnedVenues.contains($0.venueId) && seen.insert($0.venueId).inserted }
            .compactMap { plan in
                guard var made = stamp(for: plan.venueId, games: [plan], date: plan.date) else { return nil }
                made.planId = plan.id
                return made
            }
    }

    /// A venue's stamp wears the color of the team that plays there most.
    private func stamp(for venueId: String, games: [GameEntry], date: Date?) -> Stamp? {
        guard let venue = library.venue(venueId) else { return nil }
        // The tenant that played here most. A "home" side at a neutral ground (a World Cup game in Seattle) is not
        // the venue's team, so that stamp wears the country instead.
        let homes = games.filter { $0.venueId == venueId }.compactMap(\.homeTeamId).compactMap { library.team($0) }
            .filter { Self.isTenant($0, of: venue) }.map(\.id)
        let top = Dictionary(grouping: homes, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        // No tenant in the games seen here (a national side at a club's ground, Netherlands at the Philips Stadion): the stamp
        // still wears the colors of the club that calls it home, under the city's code. A ground with no club of its own (a World Cup venue) stays neutral.
        let neutral = games.contains { $0.venueId == venueId && (BigGame.tournamentLeagues[$0.source?.league ?? ""] != nil || Self.isNeutralTournament($0.competition)) }
        let club = neutral ? nil : library.allTeams.first { $0.homeVenueId == venueId && $0.sport == venue.sports.first && Self.isTenant($0, of: venue) }
            ?? library.allTeams.first { $0.homeVenueId == venueId && Self.isTenant($0, of: venue) }
        let team = library.team(top) ?? club
        // A circuit wears its country (USA, ITA); any other neutral ground wears its city (SEA, SF, KC).
        let fallback = venue.sports.contains(.motorsport)
            ? (CountryCodes.iso3(venue.countryCode) ?? Self.cityCode(venue.city))
            : Self.cityCode(venue.city.isEmpty ? venue.name : venue.city)
        return Stamp(venueId: venueId, code: library.team(top)?.abbreviation ?? fallback, color: team?.accent ?? Color(hex: "3A4150"), date: date)
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
    /// A tournament played on neutral grounds (a World Cup, a Euro, a Copa América), not its qualifiers.
    static func isNeutralTournament(_ competition: String?) -> Bool {
        guard let c = competition?.lowercased(), !c.contains("qualif") else { return false }
        return ["world cup", "european championship", "euro 20", "copa am", "gold cup"].contains { c.contains($0) }
    }

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
        let venue = library.venue(stamp.venueId)
        StampFace(code: stamp.code, name: venue?.name, date: stamp.date, color: stamp.color, titles: stamp.titles, venue: venue)
    }
}

/// A stamp as drawn: the code, the ground's name and the date over the ground from above in the team's color.
/// Plain values only, so the share card draws the very same tile. `aerial` is given when the snapshot is already loaded
/// (the share card); otherwise the tile loads it.
struct StampFace: View {
    let code: String
    let name: String?
    let date: Date?
    let color: Color
    var titles = 0
    var venue: Venue?
    var aerial: UIImage?

    var body: some View {
        let ink = color.readableInk
        VStack(alignment: .leading, spacing: 6) {
            Text(code)
                .displayFont(34, relativeTo: .title)
                .foregroundStyle(ink)
            // The code is the team's; the stadium is the stamp's real name.
            if let name {
                Text(name)
                    .font(.condensed(.caption, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(date.map { Fmt.day($0) } ?? "")
                .font(.condensed(.caption2, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(ink.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(12)
        .background { StampBackdrop(venue: venue, color: color, given: aerial) }
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ink.opacity(0.22), lineWidth: 1.5).padding(5))
        .overlay(alignment: .topTrailing) {
            if titles > 0 {
                Image(systemName: "star.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.trophy)
                    .padding(6)
                    .background(Color.ink.opacity(0.85), in: .circle)
                    .padding(8)
                    .accessibilityLabel(titles == 1 ? "Title game seen here" : "\(titles) title games seen here")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Share card

private struct PassportShareTile {
    let code: String
    let color: Color
    var name: String? = nil
    var date: Date? = nil
    var titles = 0
    var aerial: UIImage? = nil
}

/// The passport page itself, as a story: the same count, the same tiles with the grounds from above. Laid out at
/// phone size (390 points wide) and scaled up to the story's pixels, so every tile is exactly the one on screen.
private struct PassportPageCard: View {
    let count: Int
    let label: String
    let league: String
    let tiles: [PassportShareTile]
    /// Grounds still to come, drawn as on the page: dashed and amber, after the earned ones.
    var planned: [PassportView.Stamp] = []

    private static let width: CGFloat = 390
    private var scale: CGFloat { ShareCardFormat.story.size.width / Self.width }
    private var height: CGFloat { ShareCardFormat.story.size.height / scale }
    private static let pad: CGFloat = 18
    private static let gap: CGFloat = 10
    /// A tile as drawn on the Passport page (three to a row on a phone); the card scales it to fit.
    private static let tileW: CGFloat = (width - 2 * pad - 2 * gap) / 3
    private static let tileH: CGFloat = 148
    /// Room for the grid: the card less its margins, the count and the footer.
    private var gridH: CGFloat { height - 36 - 30 - 110 - 24 - 2 * 14 }
    private var all: Int { tiles.count + planned.count }

    /// The fewest columns that fit every tile, so tiles stay as large as they can.
    private var columns: Int {
        let w = Self.width - 2 * Self.pad
        for c in 3...12 {
            let cell = (w - CGFloat(c - 1) * Self.gap) / CGFloat(c)
            let rows = (all + c - 1) / c
            let h = CGFloat(rows) * Self.tileH * cell / Self.tileW + CGFloat(max(rows - 1, 0)) * Self.gap
            if h <= gridH { return c }
        }
        return 12
    }
    private var tileScale: CGFloat {
        let c = CGFloat(columns)
        return ((Self.width - 2 * Self.pad - (c - 1) * Self.gap) / c) / Self.tileW
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(count)").font(.display(100)).lineLimit(1).fixedSize()
                Text(label.uppercased()).font(.display(32)).lineLimit(2).fixedSize()
            }
            .foregroundStyle(.white)
            .frame(height: 110, alignment: .leading)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.tileW * tileScale), spacing: Self.gap), count: columns),
                      alignment: .leading, spacing: Self.gap) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { _, t in
                    fitted(StampFace(code: t.code, name: t.name, date: t.date, color: t.color, titles: t.titles, aerial: t.aerial))
                }
                ForEach(planned) { fitted(PlannedStampTile(stamp: $0)) }
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                // The wordmark with "SPORTS" in yellow tucked under it, nudged aside so the two overlap a little.
                ZStack(alignment: .topLeading) {
                    Text("SPORTS")
                        .font(.system(size: 16, weight: .heavy).width(.compressed))
                        .tracking(5)
                        .foregroundStyle(Color.signal)
                        .offset(x: 16, y: 12)
                    Text("WITNESS")
                        .font(.system(size: 16, weight: .heavy).width(.compressed))
                        .tracking(5)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Text("\(league) PASSPORT")
                    .font(.system(size: 12, weight: .heavy).width(.condensed))
                    .tracking(3)
                    .foregroundStyle(Color.signal)
            }
        }
        .padding(.horizontal, Self.pad)
        .padding(.top, 36)
        .padding(.bottom, 30)
        .frame(width: Self.width, height: height, alignment: .topLeading)
        .background(Color.ink)
        .environment(\.dynamicTypeSize, .large)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: ShareCardFormat.story.size.width, height: ShareCardFormat.story.size.height, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
    }

    /// A tile drawn at its page size, then scaled down to its cell.
    private func fitted<V: View>(_ tile: V) -> some View {
        tile.frame(width: Self.tileW, height: Self.tileH)
            .scaleEffect(tileScale, anchor: .topLeading)
            .frame(width: Self.tileW * tileScale, height: Self.tileH * tileScale, alignment: .topLeading)
    }
}

/// The stamp's team color over a faded satellite view of its ground.
private struct StampBackdrop: View {
    let venue: Venue?
    let color: Color
    var given: UIImage?
    @State private var loaded: UIImage?
    private var image: UIImage? { given ?? loaded }

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
            if given == nil, let venue { loaded = await AerialCache.shared.image(for: venue, points: 120) }
        }
    }
}


/// A ground you plan to visit: dashed, amber, with the date it is planned for.
private struct PlannedStampTile: View {
    let stamp: PassportView.Stamp

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stamp.code).displayFont(34, relativeTo: .title).foregroundStyle(Color.signal)
            Spacer(minLength: 0)
            Text("Planned" + (stamp.date.map { " \u{00B7} " + Fmt.day($0) } ?? ""))
                .font(.condensed(.caption2, weight: .heavy)).tracking(1.2).foregroundStyle(Color.signal)
                .lineLimit(2).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(12)
        .background(Color.signal.opacity(0.08), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.signal, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        .accessibilityElement(children: .combine)
    }
}
