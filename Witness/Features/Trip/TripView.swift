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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(trip.title) · \(dates(trip)) · Witness") {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
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
