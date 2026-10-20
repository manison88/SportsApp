import Foundation

/// Albums whose title names a game ("BiH v Qatar", "Bosnia vs Qatar 2026", "Cubs - Cardinals"). The title names both sides, so
/// the schedules are asked for a game between those two teams while the album's photos were taken, in every competition they
/// play in (the World Cup included), and the stadium comes from the schedule: no photo needs a location. Each day found is only
/// a possible game; the fan confirms it.
enum MatchupAlbums {
    /// What a title says.
    struct Parsed: Equatable {
        /// The words read as each side, after the filler ("World Cup", "2026", an emoji) is dropped.
        var sides: [String]
        /// The teams each side could be, best first (empty when a side names no team the app knows).
        var home: [Team]
        var away: [Team]
        var isMatchup: Bool { !home.isEmpty && !away.isEmpty }
    }

    /// The separator between the two sides ("v", "vs", "vs.", "x", "versus", "against", "at", "@", "-", "–", "—", ":", "|", "/"),
    /// the filler words that are not a side, and the other names a national side goes by (the native name, the short name) all
    /// come from `ScanSettings` (`matchupSeparator`, `matchupFiller`, `nationalNames`). The full names, codes and the first word
    /// of a long name ("Bosnia") are read from the teams themselves.
    static func separator(_ settings: ScanSettings) -> NSRegularExpression {
        (try? NSRegularExpression(pattern: settings.matchupSeparator))
            ?? (try! NSRegularExpression(pattern: ScanSettings.defaults.matchupSeparator))
    }

    /// Every name a team goes by, folded, with how sure a match on it is (a full name beats a code beats a first word).
    fileprivate static func index(_ teams: [Team], settings: ScanSettings) -> [String: [(Team, Int)]] {
        var out: [String: [(Team, Int)]] = [:]
        func add(_ key: String, _ team: Team, _ score: Int) {
            let k = words(key, settings: settings).joined(separator: " ")
            guard !k.isEmpty else { return }
            if let at = out[k]?.firstIndex(where: { $0.0.id == team.id }) {
                out[k]![at].1 = max(out[k]![at].1, score)
            } else {
                out[k, default: []].append((team, score))
            }
        }
        for team in teams {
            let national = team.league == "National teams"
            add(team.teamName, team, 4)
            add(team.locationName, team, national ? 4 : 2)
            add(team.locationName + " " + team.teamName, team, 5)
            for old in team.formerNames ?? [] { add(old, team, 3) }
            if team.abbreviation.count >= 3 { add(team.abbreviation, team, 3) }
            if national {
                for alias in settings.nationalNames[team.abbreviation.uppercased()] ?? [] { add(alias, team, 4) }
                // "Bosnia" for Bosnia-Herzegovina, "Trinidad" for Trinidad and Tobago.
                let location = words(team.locationName, settings: settings)
                if let first = location.first, first.count >= 5, location.count > 1 { add(first, team, 2) }
            }
        }
        return out
    }

    /// Folded words with the filler, the years and the bare numbers dropped.
    static func words(_ s: String, settings: ScanSettings = .current) -> [String] {
        let filler = Set(settings.matchupFiller)
        // An emoji's variation selector survives the fold as a "word": only letters and digits are kept.
        return GameSuggester.fold(s).split(separator: " ")
            .map { String(String.UnicodeScalarView($0.unicodeScalars.filter { $0.properties.isAlphabetic || $0.properties.numericType != nil })) }
            .filter { !$0.isEmpty && !filler.contains($0) && !$0.allSatisfy(\.isNumber) }
    }

    /// The teams a side's words name: the longest run of words that is a team's name, the surest first. Up to three.
    private static func teams(in side: [String], index: [String: [(Team, Int)]]) -> [Team] {
        guard !side.isEmpty else { return [] }
        for length in stride(from: min(side.count, 5), through: 1, by: -1) {
            var found: [(Team, Int)] = []
            for start in 0...(side.count - length) {
                found += index[side[start..<start + length].joined(separator: " ")] ?? []
            }
            guard !found.isEmpty else { continue }
            // National sides first among equals: a matchup album is far more often an international than a namesake club.
            let sorted = found.sorted { a, b in
                a.1 != b.1 ? a.1 > b.1 : (a.0.league == "National teams" && b.0.league != "National teams")
            }
            var seen = Set<String>()
            return Array(sorted.map(\.0).filter { seen.insert($0.id).inserted }.prefix(3))
        }
        return []
    }

    /// Reads many titles against one index of the teams' names (building it is the slow part), with the separator and the word
    /// tables of one set of settings.
    struct Reader {
        fileprivate let index: [String: [(Team, Int)]]
        fileprivate let separator: NSRegularExpression
        fileprivate let settings: ScanSettings
        init(teams: [Team], settings: ScanSettings = .current) {
            self.settings = settings
            index = MatchupAlbums.index(teams, settings: settings)
            separator = MatchupAlbums.separator(settings)
        }
        func parse(_ title: String) -> Parsed { MatchupAlbums.parse(title, reader: self) }
    }

    /// Pure: what a title says. Every separator is tried in turn ("Bosnia-Herzegovina v Qatar" splits at the "v", not the
    /// hyphen) and the first split where both sides name a team wins.
    static func parse(_ title: String, teams: [Team], settings: ScanSettings = .current) -> Parsed {
        parse(title, reader: Reader(teams: teams, settings: settings))
    }

    fileprivate static func parse(_ title: String, reader: Reader) -> Parsed {
        let ns = title as NSString
        let index = reader.index
        let cuts = reader.separator.matches(in: title, range: NSRange(location: 0, length: ns.length))
        var first: Parsed?
        for cut in cuts {
            let left = words(ns.substring(to: cut.range.location), settings: reader.settings)
            let right = words(ns.substring(from: cut.range.location + cut.range.length), settings: reader.settings)
            // A side ends at the next separator: "World Cup: BiH v Qatar" reads "BiH" on the left of the "v".
            let parsed = Parsed(sides: [left.joined(separator: " "), right.joined(separator: " ")],
                                home: teams(in: left, index: index), away: teams(in: right, index: index))
            if parsed.isMatchup { return parsed }
            if first == nil { first = parsed }
        }
        return first ?? Parsed(sides: [], home: [], away: [])
    }

    /// The competitions a team's games are on: its own league, and for a national side every one it plays in; a soccer club
    /// also plays the continental cups and friendlies.
    static func leagues(for team: Team) -> [String] {
        var out: [String] = []
        func add(_ l: String?) { if let l, !l.isEmpty, !out.contains(l) { out.append(l) } }
        add(team.leagueKey)
        add(team.externalIds?.espnLeague)
        if team.league == "National teams" {
            GameLookup.nationalCompetitions.forEach { add($0) }
        } else if team.sport == .soccer {
            ["soccer/uefa.champions", "soccer/uefa.europa", "soccer/uefa.europa.conf", "soccer/fifa.cwc", "soccer/club.friendly",
             "soccer/concacaf.champions", "soccer/conmebol.libertadores"].forEach { add($0) }
        }
        return out
    }

    /// Whether a schedule's side is this team: the same ESPN id in the same sport, or the same name.
    static func side(_ side: FoundGame.Side, is team: Team, sport: Sport) -> Bool {
        if sport == team.sport, let id = team.externalIds?.espn, id == side.espnId { return true }
        let named = GameLookup.tokens("\(side.location) \(side.name)")
        return !named.isEmpty && (named == GameLookup.tokens("\(team.locationName) \(team.teamName)") || named == GameLookup.tokens(team.locationName))
    }

    /// Games between a team on one side and a team on the other that started in the window, at any ground, soonest to `around` first.
    static func games(between home: [Team], and away: [Team], from: Date, to: Date, around: Date) async -> [FoundGame] {
        var leagues: [String] = []
        for team in home + away { for l in self.leagues(for: team) where !leagues.contains(l) { leagues.append(l) } }
        // Schedules file a game under the US day it starts on, so ask every day the window touches in UTC and the day either side.
        let days = GameLookup.dayStrings(from: from.addingTimeInterval(-12 * 3600), to: to.addingTimeInterval(12 * 3600), tz: .gmt)
        var found: [FoundGame] = []
        await withTaskGroup(of: [FoundGame].self) { group in
            for league in leagues {
                for day in days {
                    group.addTask { await GameLookup.scoreboard(league: league, day: day) }
                }
            }
            for await batch in group { found += batch }
        }
        var seen = Set<String>()
        return found.filter { g in
            g.start >= from && g.start <= to && seen.insert(g.id).inserted
                && (home.contains { side(g.home, is: $0, sport: g.sport) } && away.contains { side(g.away, is: $0, sport: g.sport) }
                    || home.contains { side(g.away, is: $0, sport: g.sport) } && away.contains { side(g.home, is: $0, sport: g.sport) })
        }
        .sorted { abs($0.start.timeIntervalSince(around)) < abs($1.start.timeIntervalSince(around)) }
    }

    /// A run of an album's photos with no gap of more than `matchupOutingGapHours` (six): one outing, whatever time zone the phone is in.
    static func outings(_ points: [PhotoPoint], settings: ScanSettings = .current) -> [[PhotoPoint]] {
        let dated = points.filter { $0.date != nil }.sorted { $0.date! < $1.date! }
        let gap = settings.matchupOutingGapHours * 3600
        var out: [[PhotoPoint]] = []
        for p in dated {
            if let last = out.last?.last?.date, p.date!.timeIntervalSince(last) <= gap { out[out.count - 1].append(p) } else { out.append([p]) }
        }
        return out
    }

    /// What one album makes of each outing in it, for the scan check too.
    struct Outcome {
        let album: PhotoAlbum
        let parsed: Parsed
        /// Each outing's first and last photo, how many photos, and the game found for it (nil: none between the two teams then).
        var outings: [(first: Date, last: Date, count: Int, game: FoundGame?)] = []
        var days: [PossibleDay] = []
    }

    /// A game between the title's teams that started while the outing's photos were taken: from `matchupWindowHours` (six)
    /// before the first (photos added after the game) to as long after the last (the march in, the morning of the match). The
    /// last `matchupMaxOutings` outings of `suggestMinPhotos`+ photos are looked up.
    static func check(_ album: PhotoAlbum, points: [PhotoPoint], parsed: Parsed, venues: [Venue], existing: [GameEntry],
                      settings: ScanSettings = .current) async -> Outcome {
        var outcome = Outcome(album: album, parsed: parsed)
        guard parsed.isMatchup else { return outcome }
        // Games the library already has are not asked about again.
        let saved = Set(existing.compactMap { $0.source?.eventId })
        let window = settings.matchupWindowHours * 3600
        for outing in outings(points, settings: settings).suffix(settings.matchupMaxOutings) {
            guard let first = outing.first?.date, let last = outing.last?.date, outing.count >= settings.suggestMinPhotos else { continue }
            let middle = outing[outing.count / 2].date ?? first
            let game = await games(between: parsed.home, and: parsed.away, from: first.addingTimeInterval(-window),
                                   to: last.addingTimeInterval(window), around: middle).first
            outcome.outings.append((first, last, outing.count, game))
            guard let game, !saved.contains(game.eventId) else { continue }
            let at = GameLookup.venue(of: game, in: venues)
            let named = at.map { GameSuggester.describe(game, at: $0) } ?? "\(game.away.name) at \(game.home.name), \(game.venueName), that day"
            outcome.days.append(PossibleDay(id: "possible-album-\(album.id)|\(game.id)", day: middle, assetIds: outing.map(\.id),
                                            times: outing.compactMap(\.date),
                                            reason: "In your album \u{201C}\(album.title)\u{201D} \u{00B7} \(named)",
                                            suggestions: at.map { [$0] + Array(PhotoMatcher.neighbors(of: $0, in: venues, settings: settings).prefix(1)) } ?? []))
        }
        return outcome
    }

    /// Possible games from every album whose title names a game, newest album first. Albums are read only when the title names
    /// two teams, so a library of hundreds of albums costs a title read each; at most `matchupMaxAlbums` are read.
    static func find(albums: [PhotoAlbum], points: (PhotoAlbum) -> [PhotoPoint], teams: [Team], venues: [Venue],
                     existing: [GameEntry], settings: ScanSettings = .current) async -> [PossibleDay] {
        let reader = Reader(teams: teams, settings: settings)
        var out: [PossibleDay] = []
        let titled = albums.filter { $0.count >= settings.suggestMinPhotos && $0.count <= settings.albumMaxPhotos && !GameSuggester.isAppAlbum($0.title, settings: settings) }
            .map { ($0, reader.parse($0.title)) }.filter { $0.1.isMatchup }.prefix(settings.matchupMaxAlbums)
        for (album, parsed) in titled {
            if Task.isCancelled { break }
            out += await check(album, points: points(album), parsed: parsed, venues: venues, existing: existing, settings: settings).days
        }
        return out
    }

    /// The photo library's albums, read off the main thread.
    static func inLibrary(teams: [Team], venues: [Venue], existing: [GameEntry]) async -> [PossibleDay] {
        guard PhotoMatcher.hasAccess else { return [] }
        let albums = await Task.detached(priority: .utility) { AlbumImporter.albums() }.value
        return await find(albums: albums, points: { AlbumImporter.points(in: $0) }, teams: teams, venues: venues, existing: existing)
    }
}
