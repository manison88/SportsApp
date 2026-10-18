import Foundation

/// UEFA's own match feed, for the competitions ESPN publishes late or not at all. Today: the UEFA Nations League,
/// every national team in Europe, the whole season at once (league phase to finals), with the stadium, its
/// coordinates and capacity, the kickoff in UTC with the local offset, the matchday and group, and the score once played.
///
/// It is the public JSON that uefa.com itself reads. Like the ESPN calls it fails soft: no answer means no games here,
/// and the app carries on with what ESPN knows.
enum UEFASchedule {
    static let nationsLeague = "2014"
    private static let base = "https://match.uefa.com/v5/matches"

    /// The Nations League season that is on or next: 2026-27 is "2027".
    static func seasonYear(for date: Date = .now) -> Int {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        return (c.year ?? 2026) + ((c.month ?? 1) >= 8 ? 1 : 0)
    }

    /// Games of one national team, soonest first, from now (plus a few hours for a game in progress).
    static func upcoming(for team: Team, limit: Int = 14) async -> [FoundGame] {
        guard team.sport == .soccer else { return [] }
        let code = team.abbreviation.uppercased()
        let cutoff = Date().addingTimeInterval(-3 * 3600)
        return await season().filter { $0.start >= cutoff && ($0.home.abbreviation == code || $0.away.abbreviation == code) }
            .sorted { $0.start < $1.start }.prefix(limit).map { $0 }
    }

    /// One match by its feed id, for filling in the score after it is played.
    static func match(eventId: String) async -> FoundGame? {
        await season().first { $0.eventId == eventId }
    }

    // MARK: Fetching

    private static let cache = Cache()

    private actor Cache {
        var games: [Int: (at: Date, list: [FoundGame])] = [:]
        func get(_ year: Int) -> [FoundGame]? {
            guard let hit = games[year], Date().timeIntervalSince(hit.at) < 3 * 3600 else { return nil }
            return hit.list
        }
        func put(_ year: Int, _ list: [FoundGame]) { games[year] = (Date(), list) }
    }

    /// The whole Nations League season, kept for three hours.
    static func season(year: Int = seasonYear()) async -> [FoundGame] {
        if let hit = await cache.get(year) { return hit }
        var all: [FoundGame] = []
        var offset = 0
        while offset < 600 {
            guard let url = URL(string: "\(base)?competitionId=\(nationsLeague)&seasonYear=\(year)&offset=\(offset)&limit=50"),
                  let page = await fetch(url) else { break }
            let games = parse(page)
            all += games
            if page.count < 50 { break }
            offset += 50
        }
        if !all.isEmpty { await cache.put(year, all) }
        return all
    }

    private static func fetch(_ url: URL) async -> [[String: Any]]? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("https://www.uefa.com", forHTTPHeaderField: "Origin")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
    }

    // MARK: Parsing (pure; unit tested with a saved response)

    static func parse(_ matches: [[String: Any]]) -> [FoundGame] {
        matches.compactMap { m -> FoundGame? in
            guard let id = m["id"] as? String,
                  let kick = (m["kickOffTime"] as? [String: Any])?["dateTime"] as? String,
                  let start = GameLookup.date(kick),
                  let home = side(m["homeTeam"] as? [String: Any], score: score(m, "home")),
                  let away = side(m["awayTeam"] as? [String: Any], score: score(m, "away")) else { return nil }
            let stadium = m["stadium"] as? [String: Any]
            let geo = stadium?["geolocation"] as? [String: Any]
            let offset = ((m["kickOffTime"] as? [String: Any])?["utcOffsetInHours"] as? NSNumber).map { Int(truncating: $0) * 3600 }
            var game = FoundGame(league: "soccer/uefa.nations", leagueName: "UEFA Nations League", eventId: "uefa-\(id)", sport: .soccer,
                                 start: start, venueName: name(stadium) ?? "", venueCity: name(stadium?["city"] as? [String: Any]),
                                 home: home, away: away, completed: (m["status"] as? String) == "FINISHED", note: note(m))
            game.venueLatitude = (geo?["latitude"] as? NSNumber)?.doubleValue
            game.venueLongitude = (geo?["longitude"] as? NSNumber)?.doubleValue
            game.venueCapacity = (stadium?["capacity"] as? NSNumber)?.intValue
            game.venueCountryCode = stadium?["countryCode"] as? String
            game.utcOffsetSeconds = offset
            return game
        }
    }

    /// "League B \u{00B7} Group B3 \u{00B7} Matchday 6": where this game sits in the competition.
    private static func note(_ m: [String: Any]) -> String? {
        let group = m["group"] as? [String: Any]
        let league = ((group?["league"] as? [String: Any])?["metaData"] as? [String: Any])?["leagueName"] as? String
        let groupName = (group?["metaData"] as? [String: Any])?["groupName"] as? String
        let day = (m["matchday"] as? [String: Any])?["longName"] as? String
        let round = ((m["round"] as? [String: Any])?["metaData"] as? [String: Any])?["name"] as? String
        let parts = [league, groupName, day ?? round].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private static func name(_ o: [String: Any]?) -> String? {
        let t = (o?["translations"] as? [String: Any])?["name"] as? [String: Any]
        return (t?["EN"] as? String) ?? (t?.values.first as? String)
    }

    private static func score(_ m: [String: Any], _ side: String) -> Int? {
        let total = (m["score"] as? [String: Any])?["total"] as? [String: Any]
        return (total?[side] as? NSNumber)?.intValue
    }

    private static func side(_ t: [String: Any]?, score: Int?) -> FoundGame.Side? {
        guard let t, let code = t["teamCode"] as? String ?? t["countryCode"] as? String else { return nil }
        let nameText = (t["internationalName"] as? String) ?? code
        // The feed's own team code is the FIFA code, which is what the app's national teams use as their abbreviation.
        return FoundGame.Side(espnId: "uefa-\(code)", abbreviation: code.uppercased(), location: nameText, name: nameText,
                              color: nil, altColor: nil, score: score, line: [])
    }
}
