import Foundation
import os

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
    /// Season phase: "post-season", "final", "semifinals", "group-stage"...
    var seasonSlug: String? = nil
    var seasonType: Int? = nil
    /// Set when this "game" is a Formula 1 race weekend.
    var race: F1Race? = nil
    /// What the source says about the ground, when it gives coordinates: enough to add a stadium the catalog lacks.
    var venueLatitude: Double? = nil
    var venueLongitude: Double? = nil
    var venueCapacity: Int? = nil
    var venueCountryCode: String? = nil
    var utcOffsetSeconds: Int? = nil

    /// Finals, playoffs, tournaments: what makes this one a big game.
    var stage: GameEntry.Stage? {
        BigGame.classify(league: league, seasonSlug: seasonSlug, seasonType: seasonType, notes: note.map { [$0] } ?? [])
    }
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

    /// Games on the venue's league schedules that started in the window (`scheduleBeforeHours` before `from` to
    /// `scheduleAfterHours` after `to`) and were played at this venue.
    static func games(at venue: Venue, from: Date, to: Date, settings: ScanSettings = .current) async -> [FoundGame] {
        await gamesChecked(at: venue, from: from, to: to, settings: settings).games
    }

    /// `games`, and whether every schedule it needed answered. A lookup that could not run (offline, throttled past its retries)
    /// is incomplete: "no games" from it means "not checked", not "no game that day".
    static func gamesChecked(at venue: Venue, from: Date, to: Date, settings: ScanSettings = .current) async -> (games: [FoundGame], complete: Bool) {
        let leagues = leagues(for: venue).filter { !$0.hasPrefix("racing/") }
        let windowStart = from.addingTimeInterval(-settings.scheduleBeforeHours * 3600)
        let windowEnd = to.addingTimeInterval(settings.scheduleAfterHours * 3600)
        // A circuit's race weekends come from the bundled calendar, with no network call.
        let races = venue.sports.contains(.motorsport)
            ? F1Calendar.races(at: venue, from: from, to: to).map { F1Calendar.found($0, venue: venue) } : []
        guard !leagues.isEmpty else { return (races, true) }
        let days = dayStrings(from: windowStart, to: windowEnd, tz: venue.tz)

        // Past games of a league whose seasons are downloaded come from the phone: no network, nothing leaves the device.
        let covered = await LocalSchedule.covered(leagues, from: windowStart, to: windowEnd)
        var found: [FoundGame] = []
        if !covered.isEmpty {
            found = await LocalSchedule.games(at: venue, leagues: leagues.filter { covered.contains($0) },
                                              from: windowStart, to: windowEnd)
        }
        var complete = true
        await withTaskGroup(of: (games: [FoundGame], answered: Bool).self) { group in
            for league in leagues where !covered.contains(league) {
                for day in days {
                    group.addTask {
                        switch await fetchResult(scoreboardURL(league: league, day: day)) {
                        case .data(let data): return (parseScoreboard(data, league: league), true)
                        case .none: return ([], true)
                        case .failed: return ([], false)
                        }
                    }
                }
            }
            for await batch in group {
                found.append(contentsOf: batch.games)
                if !batch.answered { complete = false }
            }
        }
        var seen = Set<String>()
        let games = (races + found
            .filter { $0.start >= windowStart && $0.start <= windowEnd }
            .filter { venueMatches($0, venue: venue) })
            .filter { seen.insert($0.id).inserted }
            .sorted { abs($0.start.timeIntervalSince(from)) < abs($1.start.timeIntervalSince(from)) }
        return (games, complete)
    }

    /// Every game on one league's schedule that started in the window, at any venue.
    static func schedule(league: String, from: Date, to: Date, tz: TimeZone = .current) async -> [FoundGame] {
        var out: [FoundGame] = []
        for day in dayStrings(from: from, to: to, tz: tz) {
            if let data = await fetch(scoreboardURL(league: league, day: day)) {
                out += parseScoreboard(data, league: league)
            }
        }
        return out.filter { $0.start >= from.addingTimeInterval(-6 * 3600) && $0.start <= to }
    }

    /// One league's scoreboard for one day ("20260624"), at every ground.
    static func scoreboard(league: String, day: String) async -> [FoundGame] {
        guard let data = await fetch(scoreboardURL(league: league, day: day)) else { return [] }
        return parseScoreboard(data, league: league)
    }

    /// The catalog venue a schedule's game was played at, by name, alias, or city plus home team.
    static func venue(of game: FoundGame, in venues: [Venue]) -> Venue? {
        let matches = venues.filter { venueMatches(game, venue: $0) }
        // An exact name and city beats a looser match ("United Center" is not "Cambrian United Ground").
        let name = tokens(game.venueName)
        return matches.first { tokens($0.name) == name && sameCity(game, $0) } ?? matches.first { sameCity(game, $0) } ?? matches.first
    }

    /// The schedule's city ("Chicago, Illinois") holds the venue's city ("Chicago"), or either is unknown.
    private static func sameCity(_ game: FoundGame, _ venue: Venue) -> Bool {
        guard let city = game.venueCity else { return true }
        let a = tokens(city), b = tokens(venue.city)
        return a.isEmpty || b.isEmpty || !a.isDisjoint(with: b)
    }

    /// Plays, win probability and attendance for a found game.
    static func detail(_ game: FoundGame) async -> FoundDetail? {
        if game.race != nil { return nil }
        guard let url = URL(string: "\(base)\(game.league)/summary?event=\(game.eventId)"),
              let data = await fetch(url) else { return nil }
        return parseDetail(data, game: game)
    }

    /// Leagues to check for a venue: what the catalog says, else a best guess from sport and country.
    static func leagues(for venue: Venue) -> [String] {
        var base = clubLeagues(for: venue)
        // Any soccer ground can host a World Cup, Euro, Copa América or continental final.
        if venue.sports.contains(.soccer) {
            for l in ["soccer/fifa.world", "soccer/uefa.euro", "soccer/conmebol.america", "soccer/concacaf.gold",
                      "soccer/fifa.cwc", "soccer/uefa.champions", "soccer/uefa.europa", "soccer/conmebol.libertadores",
                      "soccer/fifa.friendly"] + nationalLeagues(for: venue)
            where !base.contains(l) { base.append(l) }
        } else if canHostSoccer(venue) {
            // Football bowls only host the neutral-ground tournaments; keep the lookup short.
            for l in neutralTournaments.sorted() where !base.contains(l) { base.append(l) }
        }
        return base
    }

    /// Soccer grounds, plus the big football bowls (Levi's Stadium, MetLife, SoFi...) and any venue
    /// without a known capacity, which all host World Cup and Gold Cup games.
    private static func canHostSoccer(_ venue: Venue) -> Bool {
        if venue.sports.contains(.soccer) { return true }
        guard venue.sports.contains(where: { $0 == .football }) else { return venue.isCustom == true }
        return (venue.capacity ?? 30_000) >= 30_000
    }

    private static let neutralTournaments: Set<String> = [
        "soccer/fifa.world", "soccer/uefa.euro", "soccer/conmebol.america", "soccer/concacaf.gold", "soccer/fifa.cwc",
    ]

    /// Qualifiers and the Nations League, by the venue's confederation.
    private static func nationalLeagues(for venue: Venue) -> [String] {
        let c = venue.countryCode
        if ["AR", "BO", "BR", "CL", "CO", "EC", "PE", "PY", "UY", "VE"].contains(c) { return ["soccer/fifa.worldq.conmebol"] }
        if ["US", "CA", "MX", "BS", "CR", "JM", "PA", "HN"].contains(c) { return ["soccer/fifa.worldq.concacaf"] }
        if soccerLeague[c] != nil || europe.contains(c) { return ["soccer/fifa.worldq.uefa", "soccer/uefa.euroq", "soccer/uefa.nations"] }
        return []
    }

    private static let europe: Set<String> = [
        "AL", "AM", "AZ", "BA", "BG", "CY", "CZ", "EE", "FI", "GE", "HR", "HU", "IE", "IL", "IS", "KZ", "LT", "LU",
        "LV", "MC", "ME", "MK", "MT", "PL", "RO", "RS", "RU", "SI", "SK", "UA", "XK",
    ]

    private static func clubLeagues(for venue: Venue) -> [String] {
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
        if let race = game.race { F1Calendar.apply(race, to: &entry); return }
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
        if let stage = game.stage {
            entry.stage = stage
            if entry.competition == nil { entry.competition = stage.label }
        } else if entry.competition == nil, let note = game.note {
            entry.competition = note
        }
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
                    externalIds: .init(mlbStatsApi: nil, theSportsDb: nil, espn: side.espnId, espnLeague: game.league),
                    leagueKey: game.league)
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
            let season = event["season"] as? [String: Any]
            return FoundGame(league: league, leagueName: leagueName, eventId: id, sport: sport(of: league),
                             start: start, venueName: venue?["fullName"] as? String ?? "",
                             venueCity: address?["city"] as? String, home: home, away: away,
                             completed: completed, note: note,
                             seasonSlug: season?["slug"] as? String, seasonType: int(season?["type"]))
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
                let text = e["text"] as? String ?? "Goal."
                // ESPN credits an own goal to the side that gains the goal, so the event's team is who scores, own goal or not.
                if teamId == game.home.espnId { h += 1 } else { a += 1 }
                // The goal text carries the running score ("Goal! Bosnia and Herzegovina 2, Qatar 1."): it wins over counting.
                if let running = runningScore(in: text, game: game) { h = running.home; a = running.away }
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

    /// The score a goal's text states, as (home, away): "Goal! Bosnia and Herzegovina 2, Qatar 1. ..." or
    /// "Own Goal by A, Qatar. Bosnia and Herzegovina 2, Qatar 0." Nil when the text has none or the names fit neither side.
    static func runningScore(in text: String, game: FoundGame) -> (home: Int, away: Int)? {
        guard let regex = try? NSRegularExpression(pattern: #"([^\d,.!]+?)\s+(\d+),\s+([^\d,.!]+?)\s+(\d+)"#) else { return nil }
        let whole = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, range: whole), m.numberOfRanges == 5,
              let nameRange = Range(m.range(at: 1), in: text), let firstRange = Range(m.range(at: 2), in: text),
              let secondRange = Range(m.range(at: 4), in: text),
              let first = Int(text[firstRange]), let second = Int(text[secondRange]) else { return nil }
        let named = tokens(String(text[nameRange]))
        let home = tokens("\(game.home.location) \(game.home.name)").intersection(named).count
        let away = tokens("\(game.away.location) \(game.away.name)").intersection(named).count
        guard home != away else { return nil }
        return home > away ? (first, second) : (second, first)
    }

    /// True when the event's venue is this venue, by name or alias, or by city plus home team.
    static func venueMatches(_ game: FoundGame, venue: Venue) -> Bool {
        let eventName = tokens(game.venueName)
        if !eventName.isEmpty {
            for candidate in [venue.name] + (venue.aliases ?? []) {
                let c = tokens(candidate)
                guard !c.isEmpty else { continue }
                if c == eventName { return true }
                // A partial name ("United" for "United Center") only counts in the same city.
                if (c.isSubset(of: eventName) || eventName.isSubset(of: c)) && sameCity(game, venue) { return true }
            }
        }
        // Tournaments use neutral grounds, often under a tournament name ("San Francisco Bay Area Stadium"),
        // so the city is enough, for a ground that can host the game (Lumen Field's World Cup games were not at T-Mobile Park).
        if neutralTournaments.contains(game.league), canHostSoccer(venue), let city = game.venueCity, !tokens(city).isEmpty,
           !tokens(venue.city).isEmpty, tokens(venue.city).isSubset(of: tokens(city)) { return true }
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

    /// Schedule pages for days already over don't change, so each is fetched once per launch.
    nonisolated(unsafe) private static let pages = NSCache<NSURL, NSData>()

    /// Tests answer schedule requests from saved responses instead of the network.
    nonisolated(unsafe) static var responder: (@Sendable (URL) -> Data?)?

    /// A scan matches dozens of visits, each asking several competitions about two days. Fired all at once, the schedule
    /// server throttles or times out some of them, and a game that was there reads as "no game". So requests wait their
    /// turn (`lookupConcurrency` at once), a failure is tried again (`lookupAttempts` tries, `lookupBackoffMilliseconds` × the
    /// attempt squared between them, `lookupTimeoutSeconds` each), and a finished day is kept.
    private static func fetch(_ url: URL) async -> Data? {
        if case .data(let data) = await fetchResult(url) { return data }
        return nil
    }

    /// What a schedule request came to: the page, nothing there (the server answered, there is no such page), or no answer at all.
    enum Fetched { case data(Data), none, failed }

    /// Tests make a request fail with this error instead of answering from `responder`.
    nonisolated(unsafe) static var simulatedFailure: (@Sendable (URL) -> URLError.Code?)?

    /// Like `fetch`, but says "failed" apart from "nothing there". A device that is offline fails at once, without retries, and
    /// every later request of the scan (`LookupOutage`) fails at once with it, so a scan without a connection finishes promptly.
    static func fetchResult(_ url: URL) async -> Fetched {
        if LookupOutage.isOffline { return .failed }
        if let responder {
            if let code = simulatedFailure?(url) {
                if LookupOutage.isOfflineError(code) { LookupOutage.markOffline() }
                return .failed
            }
            return responder(url).map(Fetched.data) ?? .none
        }
        if let hit = pages.object(forKey: url as NSURL) { return .data(hit as Data) }
        let settings = ScanSettings.current
        await RequestGate.shared.enter()
        defer { Task { await RequestGate.shared.leave() } }
        for attempt in 0..<settings.lookupAttempts {
            if LookupOutage.isOffline { return .failed }
            var request = URLRequest(url: url)
            request.timeoutInterval = settings.lookupTimeoutSeconds
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        if url.absoluteString.contains("dates="), isPastDay(url) { pages.setObject(data as NSData, forKey: url as NSURL) }
                        return .data(data)
                    }
                    // Not throttled and not a server hiccup: asking again won't help.
                    if http.statusCode != 429 && http.statusCode < 500 { return .none }
                }
            } catch let error as URLError where LookupOutage.isOfflineError(error.code) {
                LookupOutage.markOffline()
                return .failed
            } catch {}
            if Task.isCancelled { return .failed }
            try? await Task.sleep(for: .milliseconds(settings.lookupBackoffMilliseconds * (attempt + 1) * (attempt + 1)))
        }
        return .failed
    }

    /// Whether a scoreboard URL's `dates=yyyyMMdd` is at least two days ago, so its results are final.
    private static func isPastDay(_ url: URL) -> Bool {
        guard let item = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "dates" })?.value,
              item.count >= 8, let day = Int(item.prefix(8)) else { return false }
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = .gmt
        let twoDaysAgo = Int(f.string(from: Date().addingTimeInterval(-2 * 86_400))) ?? 0
        return day <= twoDaysAgo
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


extension GameLookup {
    /// A team's coming games, soonest first: its own schedule, else one range of the league scoreboard.
    static func upcoming(league: String, teamEspnId: String, limit: Int = 14) async -> [FoundGame] {
        let now = Date()
        func mine(_ list: [FoundGame]) -> [FoundGame] {
            list.filter { ($0.home.espnId == teamEspnId || $0.away.espnId == teamEspnId) && $0.start >= now.addingTimeInterval(-3 * 3600) }
        }
        var found: [FoundGame] = []
        if let url = URL(string: "\(base)\(league)/teams/\(teamEspnId)/schedule"), let data = await fetch(url) {
            found = mine(parseScoreboard(data, league: league))
        }
        if found.isEmpty {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "yyyyMMdd"
            let range = "\(f.string(from: now))-\(f.string(from: now.addingTimeInterval(75 * 86_400)))"
            if let url = URL(string: "\(base)\(league)/scoreboard?dates=\(range)&limit=1000"), let data = await fetch(url) {
                found = mine(parseScoreboard(data, league: league))
            }
        }
        var seen = Set<String>()
        return Array(found.filter { seen.insert($0.id).inserted }.sorted { $0.start < $1.start }.prefix(limit))
    }
}


/// ESPN's own list of teams per league, so a team the app ships without an ESPN id (the Bears, the Cubs) is still found.
actor TeamDirectory {
    static let shared = TeamDirectory()

    struct Entry: Sendable { let id: String; let abbreviation: String; let location: String; let name: String; let display: String }
    private var cache: [String: [Entry]] = [:]

    /// League paths for the leagues the app ships teams for.
    static let leagues: [String: String] = [
        "MLB": "baseball/mlb", "NFL": "football/nfl", "NBA": "basketball/nba", "WNBA": "basketball/wnba", "NHL": "hockey/nhl",
        "MLS": "soccer/usa.1", "NWSL": "soccer/usa.nwsl", "Premier League": "soccer/eng.1", "LaLiga": "soccer/esp.1",
        "Bundesliga": "soccer/ger.1", "Serie A": "soccer/ita.1", "Ligue 1": "soccer/fra.1",
    ]

    /// The league path and ESPN id for a team: what it already carries, else matched on ESPN's team list.
    func resolve(_ team: Team) async -> (league: String, id: String)? {
        if let id = team.externalIds?.espn, let league = team.externalIds?.espnLeague ?? team.leagueKey { return (league, id) }
        guard let league = Self.leagues[team.league] ?? team.leagueKey ?? team.externalIds?.espnLeague else { return nil }
        let entries = await teams(in: league)
        func fold(_ s: String) -> String { GameLookup.tokens(s).sorted().joined(separator: " ") }
        let location = fold(team.locationName), name = fold(team.teamName)
        let match = entries.first { fold($0.location) == location && fold($0.name) == name }
            ?? entries.first { fold($0.name) == name && !name.isEmpty && (fold($0.location).contains(location) || location.contains(fold($0.location))) }
            ?? entries.first { $0.abbreviation.caseInsensitiveCompare(team.abbreviation) == .orderedSame
                               && (fold($0.location).contains(location) || location.contains(fold($0.location))) }
            ?? entries.first { fold($0.display).contains(location) && fold($0.display).contains(name) && !name.isEmpty }
        return match.map { (league, $0.id) }
    }

    private func teams(in league: String) async -> [Entry] {
        if let hit = cache[league] { return hit }
        guard let url = URL(string: "\(GameLookup.base)\(league)/teams?limit=500"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var out: [Entry] = []
        for sport in root["sports"] as? [[String: Any]] ?? [] {
            for lg in sport["leagues"] as? [[String: Any]] ?? [] {
                for wrapper in lg["teams"] as? [[String: Any]] ?? [] {
                    guard let t = wrapper["team"] as? [String: Any], let id = t["id"] as? String else { continue }
                    out.append(Entry(id: id, abbreviation: t["abbreviation"] as? String ?? "", location: t["location"] as? String ?? "",
                                     name: t["name"] as? String ?? "", display: t["displayName"] as? String ?? ""))
                }
            }
        }
        if !out.isEmpty { cache[league] = out }
        return out
    }
}


extension GameLookup {
    /// Every competition a men's national soccer side plays in, ESPN league paths, from the competition catalog
    /// (`national: true` in Catalog/competitions.json): the World Cup and its qualifying by confederation, the Euros and their
    /// qualifying, the Nations Leagues, the continental cups and friendlies.
    static var nationalCompetitions: [String] { CompetitionCatalog.shared.nationalKeys(sport: .soccer, gender: "men") }

    /// Whether a league path is one of the competitions between countries (any sport, either gender), as against a club cup run
    /// by the same body (uefa.champions, uefa.europa, conmebol.libertadores, fifa.cwc).
    static func isNationalCompetition(_ league: String) -> Bool { CompetitionCatalog.shared.isNational(league) }

    /// A national team's coming games in every one of its competitions at once, soonest first. ESPN keeps one team id for a
    /// country across all of them.
    static func upcomingNational(espnId: String, leagues: [String]? = nil, limit: Int = 14) async -> [FoundGame] {
        let now = Date()
        var found: [FoundGame] = []
        await withTaskGroup(of: [FoundGame].self) { group in
            for league in leagues ?? nationalCompetitions {
                group.addTask {
                    guard let url = URL(string: "\(base)\(league)/teams/\(espnId)/schedule"), let data = await fetch(url) else { return [] }
                    return parseScoreboard(data, league: league)
                        .filter { ($0.home.espnId == espnId || $0.away.espnId == espnId) && $0.start >= now.addingTimeInterval(-3 * 3600) }
                }
            }
            for await batch in group { found += batch }
        }
        var seen = Set<String>()
        return Array(found.filter { seen.insert($0.id).inserted }.sorted { $0.start < $1.start }.prefix(limit))
    }
}

extension GameLookup {
    /// The game at a stadium on the calendar day the fan picked, whatever the sport or competition. The day is the stadium's own
    /// day, from midnight to midnight (a 5 pm kickoff is that day, wherever the phone is). When that day has no game, the day
    /// before and the day after are checked, since a remembered date is often a day off; the shift says which one matched.
    static func gameNear(_ date: Date, at venue: Venue) async -> (game: FoundGame?, shift: Int) {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = venue.tz
        guard let picked = cal.date(from: parts) else { return (nil, 0) }
        for shift in [0, -1, 1] {
            guard let start = cal.date(byAdding: .day, value: shift, to: picked),
                  let end = cal.date(byAdding: .day, value: 1, to: start) else { continue }
            let games = await GameLookup.games(at: venue, from: start, to: end).filter { $0.start >= start && $0.start < end }
            let evening = start.addingTimeInterval(19 * 3600)
            if let best = games.min(by: { abs($0.start.timeIntervalSince(evening)) < abs($1.start.timeIntervalSince(evening)) }) {
                return (best, shift)
            }
        }
        return (nil, 0)
    }
}

/// Whether the device has no connection, for the length of one scan. The first request to fail with an offline error (not
/// connected, connection lost, data not allowed) marks it, and every request after fails at once, so no scan sleeps through
/// retries it cannot win. Only a scan that called `begin()` is tracked; anything else just fails fast on its own request.
enum LookupOutage {
    private struct State { var tracking = false; var offline = false }
    private static let state = OSAllocatedUnfairLock(initialState: State())

    static func begin() { state.withLock { $0 = State(tracking: true) } }
    static func end() { state.withLock { $0 = State() } }
    static var isOffline: Bool { state.withLock { $0.offline } }
    static func markOffline() { state.withLock { if $0.tracking { $0.offline = true } } }

    static func isOfflineError(_ code: URLError.Code) -> Bool {
        code == .notConnectedToInternet || code == .networkConnectionLost || code == .dataNotAllowed
    }
}

/// At most a few schedule requests in flight at once (`lookupConcurrency`), the rest queued in order.
actor RequestGate {
    static let shared = RequestGate()
    private let fixed: Int?
    private var limit: Int { fixed ?? ScanSettings.current.lookupConcurrency }
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    /// A fixed limit, or (nil) the settings' limit, read each time a request asks to enter.
    init(limit: Int? = nil) { fixed = limit }

    func enter() async {
        if running < limit { running += 1; return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func leave() {
        if waiting.isEmpty { running -= 1 } else { waiting.removeFirst().resume() }
    }
}
