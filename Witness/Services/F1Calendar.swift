import Foundation

/// A Formula 1 race weekend from the bundled calendar (2018 to today): the circuit, the dates and, once it has run, the result.
struct F1Race: Codable, Hashable, Identifiable {
    struct Driver: Codable, Hashable { var code: String?; var name: String?; var constructor: String? }
    struct FastestLap: Codable, Hashable { var name: String?; var time: String?; var lap: Int? }
    struct Results: Codable, Hashable {
        var winner: Driver?
        var podium: [String]?
        var podiumNames: [String]?
        var pole: Driver?
        var fastestLap: FastestLap?
        var laps: Int?
        var winnerTime: String?
    }

    let id: String
    let season: Int
    let round: Int
    let name: String
    let shortName: String
    let circuitId: String
    let status: String
    let raceStartUtc: String
    let raceLocalDate: String
    let weekendStartLocalDate: String
    var sprintWeekend: Bool?
    var espnEventId: String?
    var results: Results?
    var notes: [String]?

    var completed: Bool { status == "completed" }
    var start: Date { GameLookup.date(raceStartUtc) ?? .distantPast }
    /// "2024 Monaco Grand Prix"
    var title: String { "\(season) \(shortName)" }

    /// "P1 VER \u{00B7} Max Verstappen", one line per podium place; the first two words are the compact form.
    var podiumLines: [String] {
        let codes = results?.podium ?? []
        let names = results?.podiumNames ?? []
        return codes.enumerated().map { i, code in names.indices.contains(i) ? "\(code) \u{00B7} \(names[i])" : code }
    }
}

/// The circuit facts that go with a race: length, turns, the lap record.
struct F1Circuit: Codable, Hashable, Identifiable {
    struct LapRecord: Codable, Hashable { var time: String?; var driver: String?; var year: Int? }
    let id: String
    var lengthKm: Double?
    var turns: Int?
    var lapRecord: LapRecord?
    var firstGrandPrix: Int?
    var direction: String?
    var street: Bool?
}

enum F1Calendar {
    static let leagueKey = "racing/f1"

    static let races: [F1Race] = load("f1-calendar")
    static let circuits: [String: F1Circuit] = Dictionary(
        (load("f1-circuits") as [F1Circuit]).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    private static func load<T: Decodable>(_ name: String) -> [T] {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Catalog")
                ?? bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Lossy<T>].self, from: data) else { return [] }
        return list.compactMap(\.value)
    }

    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    static func races(at venueId: String) -> [F1Race] { races.filter { $0.circuitId == venueId } }

    /// Newest season first, rounds in order.
    static func seasons() -> [(season: Int, races: [F1Race])] {
        Dictionary(grouping: races, by: \.season).map { ($0.key, $0.value.sorted { $0.round < $1.round }) }
            .sorted { $0.season > $1.season }
    }

    /// The window a race weekend covers at its circuit: first practice day to the night after the race.
    static func weekend(of race: F1Race, in tz: TimeZone) -> (Date, Date)? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd"
        guard let first = f.date(from: race.weekendStartLocalDate), let last = f.date(from: race.raceLocalDate) else { return nil }
        return (first, last.addingTimeInterval(29 * 3600))   // into the early hours after race day
    }

    /// Races at this circuit whose weekend overlaps the window.
    static func races(at venue: Venue, from: Date, to: Date) -> [F1Race] {
        races(at: venue.id).filter { race in
            guard let w = weekend(of: race, in: venue.tz) else { return false }
            return w.0 <= to && w.1 >= from
        }
    }

    /// A race as a found game, so the review, add-game and scan screens treat it like any other schedule match.
    static func found(_ race: F1Race, venue: Venue?) -> FoundGame {
        let winner = race.results?.winner
        let side = FoundGame.Side(espnId: "", abbreviation: winner?.code ?? "", location: winner?.name ?? "",
                                  name: winner?.constructor ?? "", color: nil, altColor: nil, score: nil, line: [])
        return FoundGame(league: leagueKey, leagueName: "Formula 1", eventId: race.espnEventId ?? race.id, sport: .motorsport,
                         start: race.start, venueName: venue?.name ?? "", venueCity: venue?.city, home: side, away: side,
                         completed: race.completed, note: race.title, race: race)
    }

    /// Fills a game entry from the race: its name, date, podium and where it came from.
    static func apply(_ race: F1Race, to entry: inout GameEntry) {
        entry.sport = .motorsport
        entry.venueId = race.circuitId
        entry.competition = race.title
        entry.homeTeamId = nil
        entry.awayTeamId = nil
        entry.homeScore = nil
        entry.awayScore = nil
        if race.completed {
            entry.podium = race.podiumLines
            if race.start > entry.date.addingTimeInterval(-2 * 86_400), entry.date < race.start { entry.date = race.start }
        }
        entry.source = GameEntry.Source(provider: "espn", league: leagueKey, eventId: race.espnEventId ?? race.id)
    }
}
