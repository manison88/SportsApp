import Foundation

struct ScoreResult: Hashable {
    var homeTeamId: String?
    var awayTeamId: String?
    var homeScore: Int
    var awayScore: Int
    var lineHome: [Int]
    var lineAway: [Int]
    var venueName: String
}

/// Final scores from free, keyless public APIs. MLB today; the same shape fits
/// NHL (api-web.nhle.com) and F1 (Jolpica) later.
enum ScoreLookup {
    private struct Schedule: Decodable {
        struct DateEntry: Decodable { let games: [Game] }
        struct Game: Decodable {
            struct Teams: Decodable { let home: Side; let away: Side }
            struct Side: Decodable { let team: Ref; let score: Int? }
            struct Ref: Decodable { let id: Int; let name: String? }
            struct VenueRef: Decodable { let id: Int?; let name: String? }
            struct Linescore: Decodable { let innings: [Inning]? }
            struct Inning: Decodable { let home: Runs?; let away: Runs? }
            struct Runs: Decodable { let runs: Int? }
            let teams: Teams
            let venue: VenueRef?
            let linescore: Linescore?
        }
        let dates: [DateEntry]
    }

    static func mlb(on date: Date, venue: Venue?, teams: [Team], homeTeamId: String?) async -> ScoreResult? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = venue?.tz ?? .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        guard let url = URL(string: "https://statsapi.mlb.com/api/v1/schedule?sportId=1&date=\(day)&hydrate=linescore") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let result = try? await URLSession.shared.data(for: request),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let schedule = try? JSONDecoder().decode(Schedule.self, from: result.0) else { return nil }

        let byMlbId: [Int: Team] = Dictionary(
            teams.compactMap { t -> (Int, Team)? in t.externalIds?.mlbStatsApi.map { ($0, t) } },
            uniquingKeysWith: { a, _ in a })
        let homeMlbId = teams.first { $0.id == homeTeamId }?.externalIds?.mlbStatsApi
        let games = schedule.dates.flatMap(\.games).filter { $0.teams.home.score != nil }

        let match = games.first { g in homeMlbId != nil && g.teams.home.team.id == homeMlbId }
            ?? games.first { g in
                guard let v = venue, let name = g.venue?.name else { return false }
                return TicketParser.normalize(name) == TicketParser.normalize(v.name)
            }
        guard let g = match, let hs = g.teams.home.score, let aws = g.teams.away.score else { return nil }
        let innings = g.linescore?.innings ?? []
        return ScoreResult(
            homeTeamId: byMlbId[g.teams.home.team.id]?.id,
            awayTeamId: byMlbId[g.teams.away.team.id]?.id,
            homeScore: hs, awayScore: aws,
            lineHome: innings.map { $0.home?.runs ?? 0 },
            lineAway: innings.map { $0.away?.runs ?? 0 },
            venueName: g.venue?.name ?? venue?.name ?? "")
    }
}
