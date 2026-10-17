import SwiftUI
import MapKit

/// 14 · Trip. The place in giant type, the route on a quiet map, and the legs
/// and games in order.
struct TripView: View {
    let tripId: String

    @Environment(Library.self) private var library

    var body: some View {
        if let trip = library.trip(tripId) {
            content(trip)
        } else {
            ContentUnavailableView("Trip not found", systemImage: "airplane")
                .inkBackground()
        }
    }

    private func content(_ trip: Trip) -> some View {
        let games = library.games(in: trip)
        let people = Array(Set(games.flatMap(\.companionIds))).sorted().compactMap { library.person($0) }
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title(trip, games: games))
                        .displayFont(88)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .accessibilityIdentifier("trip-title")
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 10) {
                        Text(dates(trip))
                            .font(.condensed(.subheadline, weight: .heavy))
                            .foregroundStyle(Color.textSecondary)
                        if !people.isEmpty { AvatarStack(people: people) }
                    }
                    .accessibilityElement(children: .combine)
                }
                .gutter()

                if trip.stops.count > 1 {
                    TripMap(stops: trip.stops)
                        .frame(height: 260)
                        .accessibilityLabel("Route map")
                }

                legs(trip, games: games).gutter()

                if let note = closingNote(games) {
                    Text("“\(note)”")
                        .font(.body.italic())
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(3)
                        .gutter()
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .inkBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareCardSheetLink(title: trip.title, format: .story, key: "\(trip.id)-\(games.count)",
                                   variants: { shareVariants(trip, games: games) }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
    }

    // MARK: Share card

    private func shareVariants(_ trip: Trip, games: [GameEntry]) -> [ShareCardVariant] {
        let sorted = games.sorted { $0.date < $1.date }
        // Route between the game cities only; depart/return are the fan's home.
        var cities: [String] = []
        for stop in trip.stops where stop.kind == .game || stop.kind == .city {
            if cities.last != stop.city { cities.append(stop.city) }
        }
        if cities.isEmpty {
            for g in sorted {
                if let c = library.venue(g.venueId)?.city, cities.last != c { cities.append(c) }
            }
        }
        let rows: [TripShareCard.GameRow] = sorted.enumerated().map { index, g in
            let home = library.team(g.homeTeamId)?.abbreviation
            let away = library.team(g.awayTeamId)?.abbreviation
            let matchup: String
            if let home, let away {
                matchup = "\(home) VS \(away)"
            } else {
                matchup = RecapFilmView.shortName(library.venue(g.venueId)?.name ?? "").uppercased()
            }
            return TripShareCard.GameRow(id: index, matchup: matchup, date: Fmt.short(g.date))
        }
        let base = TripShareCard(title: title(trip, games: games), dates: dates(trip),
                                 gameCount: sorted.count, cities: cities, games: rows)
        return [
            ShareCardVariant("Route") { base.styled(.route) },
            ShareCardVariant("Count") { base.styled(.count) },
            ShareCardVariant("Field") { base.styled(.field) },
            ShareCardVariant("Paper") { base.styled(.paper) },
            ShareCardVariant("Stub") { base.styled(.stub) },
        ]
    }

    // MARK: Text

    /// The country, or the city for a trip inside the home country.
    private func title(_ trip: Trip, games: [GameEntry]) -> String {
        let venues = games.compactMap { library.venue($0.venueId) }
        guard let first = venues.first else { return trip.title.uppercased() }
        let home = library.profile.homeLocation
        let homeCountry = library.venues.min { $0.location.distance(from: home) < $1.location.distance(from: home) }?.countryCode ?? "US"
        if venues.allSatisfy({ $0.countryCode == homeCountry }) {
            return first.city.uppercased()
        }
        var counts: [String: Int] = [:]
        for v in venues { counts[v.country, default: 0] += 1 }
        return (counts.max { $0.value < $1.value }?.key ?? first.country).uppercased()
    }

    private func dates(_ trip: Trip) -> String {
        let cal = Calendar.current
        if cal.isDate(trip.startDate, inSameDayAs: trip.endDate) { return Fmt.day(trip.startDate) }
        return "\(Fmt.short(trip.startDate)) – \(Fmt.day(trip.endDate))"
    }

    private func closingNote(_ games: [GameEntry]) -> String? {
        games.reversed().compactMap { g -> String? in
            let n = g.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return n.isEmpty ? nil : n
        }.first
    }

    // MARK: Legs

    private enum Leg: Identifiable {
        case travel(id: Int, from: String, to: String, symbol: String, date: Date)
        case game(id: Int, game: GameEntry)

        var id: Int {
            switch self {
            case .travel(let id, _, _, _, _): id
            case .game(let id, _): id
            }
        }
    }

    private static let iata: [String: String] = [
        "Chicago": "ORD", "Barcelona": "BCN", "Valencia": "VLC", "Madrid": "MAD",
        "Green Bay": "GRB", "Dortmund": "DTM", "Austin": "AUS",
    ]

    private static func code(_ city: String) -> String {
        iata[city] ?? String(city.filter(\.isLetter).prefix(3)).uppercased()
    }

    private func buildLegs(_ trip: Trip, games: [GameEntry]) -> [Leg] {
        var legs: [Leg] = []
        var used = Set<String>()
        var lastCity: Trip.Stop?
        var n = 0
        for stop in trip.stops {
            if stop.kind == .game {
                let match = games.first { !used.contains($0.id) && $0.venueId == stop.venueId }
                    ?? games.first { !used.contains($0.id) }
                if let match {
                    used.insert(match.id)
                    legs.append(.game(id: n, game: match)); n += 1
                }
                continue
            }
            if let from = lastCity, from.city != stop.city {
                let meters = CLLocation(latitude: from.latitude, longitude: from.longitude)
                    .distance(from: CLLocation(latitude: stop.latitude, longitude: stop.longitude))
                legs.append(.travel(id: n, from: Self.code(from.city), to: Self.code(stop.city),
                                    symbol: meters > 300_000 ? "airplane" : "tram.fill", date: stop.date))
                n += 1
            }
            lastCity = stop
        }
        for g in games where !used.contains(g.id) {
            legs.append(.game(id: n, game: g)); n += 1
        }
        return legs
    }

    private func legs(_ trip: Trip, games: [GameEntry]) -> some View {
        VStack(spacing: 0) {
            ForEach(buildLegs(trip, games: games)) { leg in
                switch leg {
                case let .travel(_, from, to, symbol, date):
                    row(symbol: symbol, date: date) {
                        Text("\(from) → \(to)")
                            .font(.condensed(.headline, weight: .heavy))
                    }
                    .accessibilityElement(children: .combine)
                case let .game(_, game):
                    NavigationLink(value: Route.game(game.id)) {
                        row(symbol: game.sport.symbol, date: game.date, chevron: true) {
                            HStack(spacing: 10) {
                                ScoreBug(game: game)
                                Text(RecapFilmView.shortName(library.venue(game.venueId)?.name ?? "").uppercased())
                                    .font(.condensed(.subheadline, weight: .heavy))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row<Content: View>(symbol: String, date: Date, chevron: Bool = false,
                                    @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            content()
            Spacer(minLength: 8)
            Text(Fmt.short(date))
                .font(.condensed(.subheadline, weight: .bold))
                .foregroundStyle(Color.textSecondary)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 56)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
    }
}

/// A quiet, non-interactive map of the trip's route.
private struct TripMap: View {
    let stops: [Trip.Stop]

    private var coordinates: [CLLocationCoordinate2D] {
        stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var gameStops: [EnumeratedSequence<[Trip.Stop]>.Element] {
        Array(stops.enumerated()).filter { $0.element.kind == .game }
    }

    /// Frame the stops abroad, not the flight from home.
    private var region: MapCameraPosition {
        let focus = stops.filter { $0.kind == .game || $0.kind == .city }
        let pts = (focus.isEmpty ? stops : focus).map {
            MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))
        }
        guard let firstPoint = pts.first else { return .automatic }
        var rect = MKMapRect(origin: firstPoint, size: MKMapSize(width: 0, height: 0))
        for p in pts.dropFirst() {
            rect = rect.union(MKMapRect(origin: p, size: MKMapSize(width: 0, height: 0)))
        }
        let padX = max(rect.size.width * 0.35, 250_000)
        let padY = max(rect.size.height * 0.35, 250_000)
        return .rect(rect.insetBy(dx: -padX, dy: -padY))
    }

    var body: some View {
        Map(initialPosition: region, interactionModes: []) {
            MapPolyline(coordinates: coordinates, contourStyle: .geodesic)
                .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            ForEach(gameStops, id: \.offset) { item in
                Annotation(item.element.city,
                           coordinate: CLLocationCoordinate2D(latitude: item.element.latitude, longitude: item.element.longitude)) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.signal, lineWidth: 3))
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
    }
}

/// 1080x1920 story card in five looks: Route, Count, Field, Paper, Stub. Plain values only, no environment.
private struct TripShareCard: View {
    enum Style { case route, count, field, paper, stub }

    struct GameRow: Identifiable {
        let id: Int
        let matchup: String
        let date: String
    }

    struct CityRow: Identifiable {
        let id: Int
        let name: String
    }

    let title: String
    let dates: String
    let gameCount: Int
    let cities: [String]
    let games: [GameRow]
    var style: Style = .route

    private let maxCities = 5
    private let maxGames = 5
    private let paperColor = Color(red: 0.96, green: 0.95, blue: 0.92)

    func styled(_ s: Style) -> TripShareCard {
        var copy = self
        copy.style = s
        return copy
    }

    private var cityRows: [CityRow] {
        Array(cities.prefix(maxCities)).enumerated().map { CityRow(id: $0.offset, name: $0.element) }
    }

    private var gamesLabel: String { gameCount == 1 ? "1 GAME" : "\(gameCount) GAMES" }

    private var cityLine: String {
        cities.map { $0.uppercased() }.joined(separator: "  /  ")
    }

    var body: some View {
        switch style {
        case .route: routeCard
        case .count: countCard
        case .field: fieldCard
        case .paper: paperCard
        case .stub: stubCard
        }
    }

    // MARK: Styles

    /// Ink: place in giant type, vertical route, game list.
    private var routeCard: some View {
        ShareCardFrame(format: .story) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.display(300))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                Text(gamesLabel)
                    .font(.system(size: 52, weight: .heavy).width(.condensed))
                    .tracking(6)
                    .foregroundStyle(Color.signal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 8)
                Text(dates)
                    .font(.system(size: 40, weight: .bold).width(.condensed))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 10)
                if cities.count > 1 {
                    route(fg: .white).padding(.top, 70)
                }
                if !games.isEmpty {
                    gameList(fg: .white).padding(.top, 70)
                }
            }
        }
    }

    /// Ink: the number of games as a giant numeral.
    private var countCard: some View {
        ShareCardFrame(format: .story) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(gameCount)")
                    .font(.display(820))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                Text(gameCount == 1 ? "GAME" : "GAMES")
                    .font(.display(150))
                    .foregroundStyle(Color.signal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(title)
                    .font(.display(120))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .padding(.top, 50)
                Text(dates)
                    .font(.system(size: 40, weight: .bold).width(.condensed))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 10)
                Text(cityLine)
                    .font(.system(size: 40, weight: .bold).width(.condensed))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 30)
            }
        }
    }

    /// Solid amber field with black type, title at the bottom.
    private var fieldCard: some View {
        flatCard(background: Color.signal, fg: .black) {
            VStack(alignment: .leading, spacing: 0) {
                Text(dates)
                    .font(.system(size: 44, weight: .heavy).width(.condensed))
                    .tracking(5)
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 40)
                Text(cityLine)
                    .font(.system(size: 52, weight: .heavy).width(.condensed))
                    .tracking(3)
                    .foregroundStyle(Color.black.opacity(0.75))
                    .lineLimit(4)
                    .minimumScaleFactor(0.5)
                    .padding(.bottom, 40)
                Text(title)
                    .font(.display(360))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                Text(gamesLabel)
                    .font(.system(size: 60, weight: .heavy).width(.condensed))
                    .tracking(6)
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 6)
            }
        }
    }

    /// Off-white paper, black type, the game list as the hero.
    private var paperCard: some View {
        flatCard(background: paperColor, fg: .black) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.display(260))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                Text("\(gamesLabel)  /  \(dates)")
                    .font(.system(size: 40, weight: .bold).width(.condensed))
                    .tracking(4)
                    .foregroundStyle(Color.black.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 10)
                if !games.isEmpty {
                    gameList(fg: .black).padding(.top, 80)
                }
                if cities.count > 1 {
                    Text(cityLine)
                        .font(.system(size: 40, weight: .bold).width(.condensed))
                        .tracking(3)
                        .foregroundStyle(Color.black.opacity(0.55))
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .padding(.top, 60)
                }
            }
        }
    }

    /// Ink with a bordered data grid, like a ticket stub.
    private var stubCard: some View {
        ShareCardFrame(format: .story) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.display(180))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                HStack(spacing: 0) {
                    cell(label: "GAMES", value: "\(gameCount)", valueColor: Color.signal)
                    cell(label: "CITIES", value: "\(cities.count)", valueColor: .white)
                }
                .padding(.top, 50)
                cell(label: "DATES", value: dates, valueColor: .white, size: 64)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(games.prefix(maxGames))) { game in
                        HStack(spacing: 24) {
                            Text(String(format: "%02d", game.id + 1))
                                .font(.system(size: 40, weight: .bold).width(.condensed))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(game.matchup)
                                .font(.system(size: 44, weight: .heavy).width(.condensed))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Spacer(minLength: 16)
                            Text(game.date)
                                .font(.system(size: 38, weight: .bold).width(.condensed))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(height: 80)
                        .padding(.horizontal, 28)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(.white.opacity(0.25)).frame(height: 2)
                        }
                    }
                    if games.count > maxGames {
                        Text("+\(games.count - maxGames) MORE")
                            .font(.system(size: 36, weight: .bold).width(.condensed))
                            .tracking(4)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(28)
                    }
                }
                .overlay(Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 2))
            }
        }
    }

    // MARK: Pieces

    private func cell(label: String, value: String, valueColor: Color, size: CGFloat = 150) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 34, weight: .bold).width(.condensed))
                .tracking(5)
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.display(size))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 2))
    }

    /// A full-bleed card with its own background, for the looks that are not on ink.
    private func flatCard<Content: View>(background: Color, fg: Color,
                                         @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 0) {
                content()
                Spacer(minLength: 40)
                Text("WITNESS")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .tracking(10)
                    .foregroundStyle(fg)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .light)
    }

    private func route(fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(cityRows) { row in
                HStack(spacing: 28) {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(fg.opacity(row.id == 0 ? 0 : 0.3))
                            .frame(width: 3, height: 22)
                        Circle()
                            .fill(fg)
                            .frame(width: 20, height: 20)
                        Rectangle()
                            .fill(fg.opacity(row.id == cityRows.count - 1 && cities.count <= maxCities ? 0 : 0.3))
                            .frame(width: 3, height: 22)
                    }
                    .frame(width: 20)
                    Text(row.name.uppercased())
                        .font(.system(size: 54, weight: .heavy).width(.condensed))
                        .foregroundStyle(fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(height: 64)
            }
            if cities.count > maxCities {
                Text("+\(cities.count - maxCities) MORE")
                    .font(.system(size: 36, weight: .bold).width(.condensed))
                    .tracking(4)
                    .foregroundStyle(fg.opacity(0.6))
                    .padding(.leading, 48)
                    .padding(.top, 6)
            }
        }
    }

    private func gameList(fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(games.prefix(maxGames))) { game in
                HStack(spacing: 24) {
                    Text(game.matchup)
                        .font(.system(size: 46, weight: .heavy).width(.condensed))
                        .foregroundStyle(fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer(minLength: 16)
                    Text(game.date)
                        .font(.system(size: 40, weight: .bold).width(.condensed))
                        .tracking(3)
                        .foregroundStyle(fg.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(height: 86)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(fg.opacity(0.18)).frame(height: 2)
                }
            }
            if games.count > maxGames {
                Text("+\(games.count - maxGames) MORE")
                    .font(.system(size: 36, weight: .bold).width(.condensed))
                    .tracking(4)
                    .foregroundStyle(fg.opacity(0.6))
                    .padding(.top, 20)
            }
        }
    }
}
