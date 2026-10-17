import Foundation

/// A real game found on a league schedule.
struct FoundGame: Identifiable, Hashable {
    struct Side: Hashable {
        var espnId: String
        var abbreviation: String
        var location: String
        var name: String
        var color: String?
        var altColor: String?
        var score: Int?
        var line: [Int]
    }

    var id: String { "\(league)#\(eventId)" }
    let league: String
    let leagueName: String
    let eventId: String
    let sport: Sport
    let start: Date
    let venueName: String
    let venueCity: String?
    let home: Side
    let away: Side
    let completed: Bool
    /// e.g. "World Series - Game 5", when the league gives one.
    let note: String?
}

/// Box-score detail for a found game.
struct FoundDetail: Hashable {
    var plays: [Play]
    var winProbability: [ProbPoint]
    var attendance: Int?
}

/// Checks a game against real league schedules and pulls its stats.
///
/// Uses ESPN's public site API (no key, no cost; unofficial, so every call
/// fails soft to nil/[] and the app keeps working without it).
enum GameLookup {
    static let base = "https://site.api.espn.com/apis/site/v2/sports/"

    // MARK: Finding the game

    /// Games on the venue's league schedules that started in the window and were played at this venue.
    static func games(at venue: Venue, from: Date, to: Date) async -> [FoundGame] {
        let leagues = leagues(for: venue)
        guard !leagues.isEmpty else { return [] }
        let windowStart = from.addingTimeInterval(-5 * 3600)
        let windowEnd = to.addingTimeInterval(1 * 3600)
        let days = dayStrings(from: windowStart, to: windowEnd, tz: venue.tz)

        var found: [FoundGame] = []
        await withTaskGroup(of: [FoundGame].self) { group in
            for league in leagues {
                for day in days {
                    group.addTask {
                        guard let data = await fetch(scoreboardURL(league: league, day: day)) else { return [] }
                        return parseScoreboard(data, league: league)
                    }
                }
            }
            for await batch in group { found.append(contentsOf: batch) }
        }
        var seen = Set<String>()
        return found
            .filter { $0.start >= windowStart && $0.start <= windowEnd }
            .filter { venueMatches($0, venue: venue) }
            .filter { seen.insert($0.id).inserted }
            .sorted { abs($0.start.timeIntervalSince(from)) < abs($1.start.timeIntervalSince(from)) }
    }

    /// Plays, win probability and attendance for a found game.
    static func detail(_ game: FoundGame) async -> FoundDetail? {
        guard let url = URL(string: "\(base)\(game.league)/summary?event=\(game.eventId)"),
              let data = await fetch(url) else { return nil }
        return parseDetail(data, game: game)
    }

    /// Leagues to check for a venue: what the catalog says, else a best guess from sport and country.
    static func leagues(for venue: Venue) -> [String] {
        if let l = venue.leagues, !l.isEmpty { return l }
        var out: [String] = []
        let us = venue.countryCode == "US" || venue.countryCode == "CA"
        for sport in venue.sports {
            switch sport {
            case .baseball where us: out.append("baseball/mlb")
            case .football where venue.countryCode == "CA": out.append("football/cfl")
            case .football where us: out += ["football/nfl", "football/college-football"]
            case .basketball where us: out += ["basketball/nba", "basketball/mens-college-basketball"]
            case .basketball: out.append("basketball/euroleague")
            case .hockey where us: out.append("hockey/nhl")
            case .soccer: if let l = soccerLeague[venue.countryCode] { out.append(l) }
            default: break
            }
        }
        return out
    }

    private static let soccerLeague: [String: String] = [
        "US": "soccer/usa.1", "CA": "soccer/usa.1", "MX": "soccer/mex.1", "GB": "soccer/eng.1", "ES": "soccer/esp.1",
        "DE": "soccer/ger.1", "IT": "soccer/ita.1", "FR": "soccer/fra.1", "NL": "soccer/ned.1", "PT": "soccer/por.1",
        "BE": "soccer/bel.1", "TR": "soccer/tur.1", "AT": "soccer/aut.1", "CH": "soccer/sui.1", "GR": "soccer/gre.1",
        "DK": "soccer/den.1", "NO": "soccer/nor.1", "SE": "soccer/swe.1", "BR": "soccer/bra.1", "AR": "soccer/arg.1",
        "CL": "soccer/chi.1", "CO": "soccer/col.1", "UY": "soccer/uru.1", "PE": "soccer/per.1", "EC": "soccer/ecu.1",
        "PY": "soccer/par.1", "VE": "soccer/ven.1", "BO": "soccer/bol.1",
    ]

    // MARK: Applying

    /// Fills a game with what the schedule knows, learning any teams the app hasn't seen.
    @MainActor
    static func apply(_ game: FoundGame, detail: FoundDetail?, to entry: inout GameEntry, library: Library) {
        let home = library.addTeam(team(from: game.home, game: game))
        let away = library.addTeam(team(from: game.away, game: game))
        entry.sport = game.sport
        entry.homeTeamId = home.id
        entry.awayTeamId = away.id
        if game.completed {
            entry.homeScore = game.home.score
            entry.awayScore = game.away.score
        }
        entry.lineHome = game.home.line
        entry.lineAway = game.away.line
        if entry.competition == nil, let note = game.note { entry.competition = note }
        if entry.rootingForTeamId == nil {
            let favorites = Set(library.profile.favoriteTeamIds)
            entry.rootingForTeamId = favorites.contains(away.id) ? away.id : nil
        }
        entry.source = GameEntry.Source(provider: "espn", league: game.league, eventId: game.eventId)
        if let detail {
            if !detail.plays.isEmpty { entry.plays = detail.plays }
            if !detail.winProbability.isEmpty { entry.winProbability = detail.winProbability }
            if let a = detail.attendance { entry.attendance = a }
        }
    }

    static func team(from side: FoundGame.Side, game: FoundGame) -> Team {
        let slug = game.league.replacingOccurrences(of: "/", with: "-")
        let primary = side.color ?? "3A4150"
        // Very dark brand colors vanish on the ink background; use the alternate then.
        let accent = luminance(primary) < 0.04 ? (side.altColor ?? primary) : primary
        return Team(id: "espn-\(slug)-\(side.espnId)", sport: game.sport, league: game.leagueName,
                    abbreviation: side.abbreviation, locationName: side.location, teamName: side.name,
                    monogram: String(side.abbreviation.prefix(1)),
                    colors: .init(primary: primary, secondary: side.altColor ?? primary, accent: accent),
                    externalIds: .init(mlbStatsApi: nil, theSportsDb: nil, espn: side.espnId))
    }

    // MARK: Parsing (pure; unit tested with saved responses)

    static func parseScoreboard(_ data: Data, league: String) -> [FoundGame] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = root["events"] as? [[String: Any]] else { return [] }
        let leagueName = ((root["leagues"] as? [[String: Any]])?.first?["name"] as? String) ?? league
        return events.compactMap { event in
            guard let id = event["id"] as? String,
                  let comp = (event["competitions"] as? [[String: Any]])?.first,
                  let start = date(event["date"] as? String ?? comp["date"] as? String),
                  let competitors = comp["competitors"] as? [[String: Any]],
                  let home = side(competitors.first { $0["homeAway"] as? String == "home" }),
                  let away = side(competitors.first { $0["homeAway"] as? String == "away" }) else { return nil }
            let venue = comp["venue"] as? [String: Any]
            let address = venue?["address"] as? [String: Any]
            let status = (comp["status"] as? [String: Any]) ?? (event["status"] as? [String: Any])
            let completed = ((status?["type"] as? [String: Any])?["completed"] as? Bool) ?? false
            let note = ((comp["notes"] as? [[String: Any]])?.first?["headline"] as? String)
            return FoundGame(league: league, leagueName: leagueName, eventId: id, sport: sport(of: league),
                             start: start, venueName: venue?["fullName"] as? String ?? "",
                             venueCity: address?["city"] as? String, home: home, away: away,
                             completed: completed, note: note)
        }
    }

    static func parseDetail(_ data: Data, game: FoundGame) -> FoundDetail {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return FoundDetail(plays: [], winProbability: [], attendance: nil)
        }
        let attendance = (root["gameInfo"] as? [String: Any])?["attendance"] as? Int
        var raw: [(text: String, home: Int, away: Int, period: String, wall: Date?)] = []

        if let scoring = root["scoringPlays"] as? [[String: Any]], !scoring.isEmpty {
            for p in scoring {
                guard let text = p["text"] as? String else { continue }
                raw.append((text, int(p["homeScore"]) ?? 0, int(p["awayScore"]) ?? 0,
                            periodLabel(p, sport: game.sport), date(p["wallclock"] as? String)))
            }
        } else if let plays = root["plays"] as? [[String: Any]], !plays.isEmpty {
            var lastHome = 0, lastAway = 0
            for p in plays where (p["scoringPlay"] as? Bool) == true {
                guard let text = p["text"] as? String, !text.isEmpty else { continue }
                let h = int(p["homeScore"]) ?? lastHome, a = int(p["awayScore"]) ?? lastAway
                // Basketball scores every possession: keep only lead changes and ties.
                if game.sport == .basketball {
                    let leadChanged = (h > a) != (lastHome > lastAway) || h == a
                    lastHome = h; lastAway = a
                    guard leadChanged else { continue }
                }
                lastHome = h; lastAway = a
                raw.append((text, h, a, periodLabel(p, sport: game.sport), date(p["wallclock"] as? String)))
            }
        } else if let events = root["keyEvents"] as? [[String: Any]] {
            var h = 0, a = 0
            for e in events {
                let type = ((e["type"] as? [String: Any])?["text"] as? String ?? "").lowercased()
                guard type.contains("goal") || type.contains("penalty - scored") else { continue }
                let teamId = (e["team"] as? [String: Any])?["id"] as? String
                var scorer = teamId == game.home.espnId
                if type.contains("own goal") { scorer.toggle() }
                if scorer { h += 1 } else { a += 1 }
                let text = e["text"] as? String ?? "Goal."
                let clock = (e["clock"] as? [String: Any])?["displayValue"] as? String ?? ""
                raw.append((text, h, a, clock, date(e["wallclock"] as? String)))
            }
        }

        let end = raw.compactMap { $0.wall }.max() ?? game.start.addingTimeInterval(typicalLength(game.sport))
        let span = max(end.timeIntervalSince(game.start), 60)
        var plays: [Play] = raw.enumerated().map { i, r in
            let t = r.wall ?? game.start.addingTimeInterval(span * Double(i + 1) / Double(raw.count + 1))
            return Play(id: "\(game.eventId)-\(i)", time: t, period: r.period, text: r.text,
                        homeScore: r.home, awayScore: r.away, isKey: true)
        }
        if game.completed, let hs = game.home.score, let aws = game.away.score {
            plays.append(Play(id: "\(game.eventId)-final", time: end, period: "F",
                              text: "Final. \(game.away.location) \(aws), \(game.home.location) \(hs).",
                              homeScore: hs, awayScore: aws, isKey: false))
        }

        var probability: [ProbPoint] = []
        if let wp = root["winprobability"] as? [[String: Any]], wp.count > 1 {
            let step = max(1, wp.count / 200)
            let points = stride(from: 0, to: wp.count, by: step).map { wp[$0] } + [wp[wp.count - 1]]
            probability = points.enumerated().compactMap { i, p in
                guard let home = p["homeWinPercentage"] as? Double else { return nil }
                let t = game.start.addingTimeInterval(span * Double(i) / Double(max(points.count - 1, 1)))
                return ProbPoint(time: t, home: home)
            }
        }
        return FoundDetail(plays: plays, winProbability: probability, attendance: attendance)
    }

    /// True when the event's venue is this venue, by name or alias, or by city plus home team.
    static func venueMatches(_ game: FoundGame, venue: Venue) -> Bool {
        let eventName = tokens(game.venueName)
        if !eventName.isEmpty {
            for candidate in [venue.name] + (venue.aliases ?? []) {
                let c = tokens(candidate)
                guard !c.isEmpty else { continue }
                if c == eventName || c.isSubset(of: eventName) || eventName.isSubset(of: c) { return true }
            }
        }
        if let city = game.venueCity, tokens(city) == tokens(venue.city) {
            let homeName = tokens("\(game.home.location) \(game.home.name)")
            for tenant in venue.homeTeams ?? [] where !tokens(tenant).isEmpty && tokens(tenant).isSubset(of: homeName) {
                return true
            }
        }
        return false
    }

    // MARK: Helpers

    private static let stopwords: Set<String> = ["the", "stadium", "estadio", "stade", "stadio", "stadion", "field",
                                                 "arena", "park", "center", "centre", "de", "del", "la", "el", "at",
                                                 "do", "da", "di", "of", "and", "y", "e", "municipal"]

    static func tokens(_ s: String) -> Set<String> {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        let words = folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return Set(words.filter { !stopwords.contains($0) })
    }

    private static func side(_ c: [String: Any]?) -> FoundGame.Side? {
        guard let c, let team = c["team"] as? [String: Any], let id = team["id"] as? String else { return nil }
        let lines = (c["linescores"] as? [[String: Any]] ?? []).compactMap { l -> Int? in
            int(l["value"]) ?? int(l["displayValue"])
        }
        let location = team["location"] as? String ?? team["shortDisplayName"] as? String ?? ""
        let name = team["name"] as? String ?? team["displayName"] as? String ?? location
        let abbr = team["abbreviation"] as? String ?? String(location.prefix(3)).uppercased()
        return .init(espnId: id, abbreviation: abbr, location: location, name: name,
                     color: team["color"] as? String, altColor: team["alternateColor"] as? String,
                     score: int(c["score"]), line: lines)
    }

    private static func periodLabel(_ p: [String: Any], sport: Sport) -> String {
        let period = p["period"] as? [String: Any]
        let n = int(period?["number"]) ?? 0
        let clock = (p["clock"] as? [String: Any])?["displayValue"] as? String
        switch sport {
        case .baseball:
            let half = (period?["type"] as? String ?? "").lowercased()
            return (half.hasPrefix("bot") ? "B" : "T") + "\(n)"
        case .football, .basketball: return n > 4 ? "OT" : "Q\(n)"
        case .hockey: return n > 3 ? "OT" : "P\(n)"
        case .soccer, .handball: return clock ?? "\(n)H"
        case .motorsport: return "\(n)"
        }
    }

    private static func typicalLength(_ sport: Sport) -> TimeInterval {
        switch sport {
        case .baseball: 3 * 3600
        case .football: 3.25 * 3600
        case .basketball: 2.25 * 3600
        case .hockey: 2.5 * 3600
        case .soccer, .handball: 1.9 * 3600
        case .motorsport: 2 * 3600
        }
    }

    static func sport(of league: String) -> Sport {
        switch league.split(separator: "/").first.map(String.init) ?? "" {
        case "baseball": .baseball
        case "football": .football
        case "basketball": .basketball
        case "hockey": .hockey
        case "racing": .motorsport
        default: .soccer
        }
    }

    private static func scoreboardURL(league: String, day: String) -> URL {
        var s = "\(base)\(league)/scoreboard?dates=\(day)&limit=500"
        if league == "football/college-football" { s += "&groups=80" }
        if league.hasSuffix("college-basketball") { s += "&groups=50" }
        return URL(string: s)!
    }

    /// yyyyMMdd for each venue-local day the window touches.
    static func dayStrings(from: Date, to: Date, tz: TimeZone) -> [String] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyyMMdd"
        var days: [String] = []
        var t = from
        while t <= to {
            let d = f.string(from: t)
            if days.last != d { days.append(d) }
            t = t.addingTimeInterval(3600)
        }
        let last = f.string(from: to)
        if days.last != last { days.append(last) }
        return days
    }

    private static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mmX"
        return f.date(from: s)
    }

    private static func int(_ any: Any?) -> Int? {
        switch any {
        case let i as Int: return i
        case let d as Double: return Int(d)
        case let s as String: return Int(s) ?? Double(s).map { Int($0) }
        case let dict as [String: Any]: return int(dict["value"]) ?? int(dict["displayValue"])
        default: return nil
        }
    }

    private static func luminance(_ hex: String) -> Double {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let r = lin(Double((v >> 16) & 0xFF) / 255), g = lin(Double((v >> 8) & 0xFF) / 255), b = lin(Double(v & 0xFF) / 255)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
