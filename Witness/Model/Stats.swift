import Foundation
import CoreLocation

/// Lifetime numbers, computed from whatever games are in the library.
struct Stats {
    struct Record: Hashable {
        var wins = 0, losses = 0, draws = 0
        var decided: Int { wins + losses + draws }
        /// Win rate with draws as half a win, 0...1. Nil when nothing is decided.
        var rate: Double? { decided == 0 ? nil : (Double(wins) + Double(draws) / 2) / Double(decided) }
        var text: String { draws > 0 ? "\(wins)–\(losses)–\(draws)" : "\(wins)–\(losses)" }

        mutating func add(_ o: Outcome) {
            switch o {
            case .win: wins += 1
            case .loss: losses += 1
            case .draw: draws += 1
            case .none: break
            }
        }
    }

    struct Companion: Identifiable, Hashable {
        let person: Person
        let games: Int
        let record: Record
        var id: String { person.id }
    }

    let games: Int
    let venues: Int
    let countries: Int
    let miles: Int
    let record: Record
    /// Average pre-game win probability of the side you were there for, 0...1.
    let expectedRate: Double?
    let runs: Int
    let coldestF: Double?
    let farthestVenue: Venue?
    let mlbParks: Set<String>
    let companions: [Companion]
    let years: [Int]

    @MainActor
    init(library: Library, games subset: [GameEntry]? = nil) {
        let list = subset ?? library.games
        games = list.count
        let venueIds = Set(list.map(\.venueId))
        let venueList = venueIds.compactMap { library.venue($0) }
        venues = venueIds.count
        countries = Set(venueList.map(\.countryCode)).count

        let home = library.profile.homeLocation
        var meters = 0.0
        var tripsCounted = Set<String>()
        for g in list {
            if let tid = g.tripId, let trip = library.trip(tid) {
                guard tripsCounted.insert(tid).inserted else { continue }
                meters += Stats.length(of: trip.stops.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) })
            } else if let v = library.venue(g.venueId) {
                meters += 2 * home.distance(from: v.location)
            }
        }
        miles = Int((meters / 1609.344 / 100).rounded()) * 100

        var r = Record()
        var expected: [Double] = []
        for g in list {
            r.add(library.outcome(g))
            if let first = g.winProbability.first, let side = library.rootingTeam(g) {
                expected.append(side == g.homeTeamId ? first.home : 1 - first.home)
            }
        }
        record = r
        expectedRate = expected.isEmpty ? nil : expected.reduce(0, +) / Double(expected.count)

        runs = list.filter { $0.sport == .baseball }.reduce(0) { $0 + ($1.homeScore ?? 0) + ($1.awayScore ?? 0) }
        coldestF = list.compactMap { $0.weather?.temperatureF }.min()
        farthestVenue = venueList.max { home.distance(from: $0.location) < home.distance(from: $1.location) }
        let parkIds = Set(library.ballparks.map(\.venueId))
        // Ballparks visited for baseball only. Wrigley for a hockey game doesn't count.
        mlbParks = Set(list.filter { $0.sport == .baseball }.map(\.venueId)).intersection(parkIds)

        var byPerson: [String: (Int, Record)] = [:]
        for g in list {
            let o = library.outcome(g)
            for id in g.companionIds {
                var entry = byPerson[id] ?? (0, Record())
                entry.0 += 1
                entry.1.add(o)
                byPerson[id] = entry
            }
        }
        companions = byPerson.compactMap { id, v in
            library.person(id).map { Companion(person: $0, games: v.0, record: v.1) }
        }.sorted { $0.games > $1.games }

        let cal = Calendar.current
        years = Array(Set(list.map { cal.component(.year, from: $0.date) })).sorted()
    }

    /// Win-rate difference to the odds, in percentage points.
    var pointsAboveOdds: Int? {
        guard let rate = record.rate, let expectedRate else { return nil }
        return Int(((rate - expectedRate) * 100).rounded())
    }

    static func length(of points: [CLLocation]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + $1.0.distance(from: $1.1) }
    }
}

extension Int {
    var percent: String { "\(self)%" }
}

extension Double {
    /// 0.613 -> "61%"
    var percentText: String { "\(Int((self * 100).rounded()))%" }
}
