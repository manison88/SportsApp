import SwiftUI

/// What the Map's Venues, Countries and Games numbers open: every one of them as a compact tile. Tap a venue for its page,
/// a game for its page, a country for the games played there.
enum MapList: String, Identifiable {
    case venues, countries, games
    var id: String { rawValue }

    var title: String {
        switch self {
        case .venues: "Venues"
        case .countries: "Countries"
        case .games: "Games"
        }
    }
}

struct MapListSheet: View {
    let kind: MapList
    let games: [GameEntry]

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    switch kind {
                    case .venues: venueTiles
                    case .countries: countryTiles
                    case .games: gameTiles(games.sorted { $0.date > $1.date })
                    }
                }
                .gutter()
                .padding(.top, 8)
                .padding(.bottom, Spacing.block)
            }
            .inkBackground()
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CountryRoute.self) { route in CountryGames(code: route.code, games: games) }
            .routes()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("map-list-done")
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Venues

    private var venueTiles: some View {
        let grouped = Dictionary(grouping: games, by: \.venueId)
        let rows = grouped.compactMap { id, list in library.venue(id).map { VenueRow(venue: $0, games: list) } }
            .sorted { $0.games.count != $1.games.count ? $0.games.count > $1.games.count : $0.venue.name < $1.venue.name }
        return ForEach(rows) { row in
            let venue = row.venue, list = row.games
            NavigationLink(value: Route.venue(venue.id)) {
                tile(lead: AnyView(Image(systemName: "building.columns").font(.title3).foregroundStyle(Color.signal)),
                     title: venue.name,
                     detail: venue.cityLine + " \u{00B7} " + venue.country,
                     trailTop: "\(list.count) \(list.count == 1 ? "game" : "games")",
                     trailBottom: list.map(\.date).max().map { "Last " + Fmt.short($0, in: venue.tz) })
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map-venue-\(venue.id)")
        }
    }

    // MARK: Countries

    private var countryTiles: some View {
        let grouped = Dictionary(grouping: games) { library.venue($0.venueId)?.countryCode ?? "" }
        let rows = grouped.filter { !$0.key.isEmpty }.map { CountryRow(code: $0.key, games: $0.value) }
            .sorted { $0.games.count != $1.games.count ? $0.games.count > $1.games.count : $0.code < $1.code }
        return ForEach(rows) { row in
            let code = row.code, list = row.games
            let venues = Set(list.map(\.venueId))
            let name = venues.compactMap { library.venue($0)?.country }.first ?? code
            NavigationLink(value: CountryRoute(code: code)) {
                tile(lead: AnyView(Text(CountryCodes.iso3(code) ?? code)
                        .font(.condensed(.subheadline, weight: .heavy)).tracking(1)
                        .foregroundStyle(Color.signal)),
                     title: name,
                     detail: "\(venues.count) \(venues.count == 1 ? "venue" : "venues")",
                     trailTop: "\(list.count) \(list.count == 1 ? "game" : "games")",
                     trailBottom: list.map(\.date).max().map { "Last " + String(Fmt.year($0)) })
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map-country-\(code)")
        }
    }

    // MARK: Games

    private func gameTiles(_ list: [GameEntry]) -> some View {
        ForEach(list) { game in
            let venue = library.venue(game.venueId)
            NavigationLink(value: Route.game(game.id)) {
                tile(lead: AnyView(dateChip(game, tz: venue?.tz ?? .current)),
                     title: matchupText(game, library),
                     detail: [venue?.name, game.competition].compactMap { $0 }.joined(separator: " \u{00B7} "),
                     trailTop: nil, trailBottom: nil, trailing: AnyView(ScoreBug(game: game)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map-game-\(game.id)")
        }
    }

    private func dateChip(_ game: GameEntry, tz: TimeZone) -> some View {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.day, .month, .year], from: game.date)
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        return VStack(spacing: 0) {
            Text("\(c.day ?? 1)").font(.condensed(.title2, weight: .heavy)).monospacedDigit()
            Text(months[((c.month ?? 1) - 1) % 12]).font(.condensed(.caption2, weight: .heavy)).tracking(1.5)
                .foregroundStyle(Color.textSecondary)
        }
        .foregroundStyle(.white)
    }

    // MARK: Tile

    private func tile(lead: AnyView, title: String, detail: String, trailTop: String?, trailBottom: String?,
                      trailing: AnyView? = nil) -> some View {
        HStack(spacing: 12) {
            lead.frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).lineLimit(1).minimumScaleFactor(0.7)
                if !detail.isEmpty {
                    Text(detail).font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                trailing
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    if let trailTop { Text(trailTop).font(.condensed(.subheadline, weight: .heavy)) }
                    if let trailBottom { Text(trailBottom).font(.caption).foregroundStyle(Color.textSecondary) }
                }
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary).accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .background(Color.panel, in: .rect(cornerRadius: 14))
        .contentShape(.rect)
    }
}

private struct CountryRow: Identifiable {
    let code: String
    let games: [GameEntry]
    var id: String { code }
}

private struct VenueRow: Identifiable {
    let venue: Venue
    let games: [GameEntry]
    var id: String { venue.id }
}

/// A country picked from the list.
struct CountryRoute: Hashable { let code: String }

/// The games played in one country.
private struct CountryGames: View {
    let code: String
    let games: [GameEntry]
    @Environment(Library.self) private var library

    var body: some View {
        let list = games.filter { library.venue($0.venueId)?.countryCode == code }.sorted { $0.date > $1.date }
        let name = list.compactMap { library.venue($0.venueId)?.country }.first ?? code
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(list) { game in
                    let venue = library.venue(game.venueId)
                    NavigationLink(value: Route.game(game.id)) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(matchupText(game, library)).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text([venue?.name, Fmt.dayTitle(game.date, in: venue?.tz ?? .current)].compactMap { $0 }.joined(separator: " \u{00B7} "))
                                    .font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            ScoreBug(game: game)
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary).accessibilityHidden(true)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 64)
                        .background(Color.panel, in: .rect(cornerRadius: 14))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("map-country-game-\(game.id)")
                }
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, Spacing.block)
        }
        .inkBackground()
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
