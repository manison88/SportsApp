import Foundation

/// One downloaded season of one league. The rows follow Tools/schedules/SPEC.md:
/// `[eventId, startUTC, homeId, awayId, homeScore, awayScore, venueId, status, note]`.
struct SchedulePack: Decodable, Sendable {
    let league: String
    let season: Int
    let teams: [String: String]
    let venues: [String: [String?]]
    let games: [ScheduleRow]
}

struct ScheduleRow: Decodable, Sendable {
    let eventId: String
    let start: String
    let home: String
    let away: String
    let homeScore: Int?
    let awayScore: Int?
    let venueId: String?
    let status: String
    let note: String

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        eventId = try Self.text(&c)
        start = try c.decode(String.self)
        home = try Self.text(&c)
        away = try Self.text(&c)
        homeScore = try Self.number(&c)
        awayScore = try Self.number(&c)
        venueId = try Self.optionalText(&c)
        status = try c.decode(String.self)
        note = (try? c.decode(String.self)) ?? ""
    }

    /// Ids are strings in the spec, but a source that hands out numbers is still read.
    private static func text(_ c: inout UnkeyedDecodingContainer) throws -> String {
        if let s = try? c.decode(String.self) { return s }
        return String(try c.decode(Int.self))
    }

    private static func optionalText(_ c: inout UnkeyedDecodingContainer) throws -> String? {
        if try c.decodeNil() { return nil }
        return try text(&c)
    }

    private static func number(_ c: inout UnkeyedDecodingContainer) throws -> Int? {
        if try c.decodeNil() { return nil }
        return try c.decode(Int.self)
    }
}

/// How the app names a team it only knows from a schedule: from the downloaded teams pack when it is there.
struct TeamBrief: Sendable {
    let league: String
    let location: String
    let name: String
    let color: String?
    let altColor: String?
}

private struct PackTeamFile: Decodable {
    struct Entry: Decodable {
        struct Ids: Decodable { var espn: String?; var espnLeague: String? }
        struct Colors: Decodable { var primary: String; var secondary: String }
        let league: String
        let locationName: String
        let teamName: String
        let colors: Colors
        var leagueKey: String?
        var externalIds: Ids?
    }
    let teams: [Entry]
}

/// Parsed packs and team names kept in memory, so a scan that asks about hundreds of visits decodes each season once.
actor ScheduleCache {
    static let shared = ScheduleCache()

    private var packs: [String: SchedulePack] = [:]
    private var order: [String] = []
    private var briefs: [String: TeamBrief]?

    func pack(_ pack: PackManifest.Pack) async -> SchedulePack? {
        let key = pack.id + "." + pack.version
        if let hit = packs[key] { return hit }
        guard let data = await PackStore.shared.data(pack.id),
              let decoded = try? JSONDecoder().decode(SchedulePack.self, from: data) else { return nil }
        packs[key] = decoded
        order.append(key)
        if order.count > 6 { packs[order.removeFirst()] = nil }
        return decoded
    }

    /// "league#espnId" -> names and colors, from the catalog teams pack.
    func teamBriefs() async -> [String: TeamBrief] {
        if let briefs { return briefs }
        var out: [String: TeamBrief] = [:]
        if let data = await PackStore.shared.data("catalog/teams"),
           let file = try? JSONDecoder().decode(PackTeamFile.self, from: data) {
            for t in file.teams {
                guard let espn = t.externalIds?.espn, let league = t.externalIds?.espnLeague ?? t.leagueKey else { continue }
                out["\(league)#\(espn)"] = TeamBrief(league: t.league, location: t.locationName, name: t.teamName,
                                                     color: t.colors.primary, altColor: t.colors.secondary)
            }
        }
        briefs = out
        return out
    }

    /// Forget what was parsed, after new packs arrive.
    func reset() {
        packs = [:]
        order = []
        briefs = nil
    }
}

/// Past games from the packs on the phone: no network, and nothing leaves the device.
enum LocalSchedule {
    /// Leagues whose downloaded seasons cover the whole window, so the live source need not be asked.
    /// Recent and upcoming games still change, so those always go to the live source.
    static func covered(_ leagues: [String], from: Date, to: Date, now: Date = .now) async -> Set<String> {
        guard to < now.addingTimeInterval(-7 * 86_400) else { return [] }
        let range = seasons(from: from, to: to)
        var out = Set<String>()
        for league in leagues {
            await PackStore.shared.ensure(league: league, seasons: range)
            let have = await PackStore.shared.schedulePacks(league: league, seasons: range)
            if Set(have.compactMap(\.season)).isSuperset(of: Set(range)) { out.insert(league) }
        }
        return out
    }

    /// Games at this venue that started in the window, nearest the window's start first.
    static func games(at venue: Venue, leagues: [String], from: Date, to: Date) async -> [FoundGame] {
        let range = seasons(from: from, to: to)
        let names = await ScheduleCache.shared.teamBriefs()
        var found: [FoundGame] = []
        for league in leagues {
            for pack in await PackStore.shared.schedulePacks(league: league, seasons: range) {
                guard let schedule = await ScheduleCache.shared.pack(pack) else { continue }
                found += games(in: schedule, at: venue, from: from, to: to, names: names)
            }
        }
        return found.sorted { abs($0.start.timeIntervalSince(from)) < abs($1.start.timeIntervalSince(from)) }
    }

    /// The pure part: which rows of one season were at this venue inside the window.
    static func games(in pack: SchedulePack, at venue: Venue, from: Date, to: Date, names: [String: TeamBrief]) -> [FoundGame] {
        guard let sport = Sport(rawValue: String(pack.league.split(separator: "/").first ?? "")) else { return [] }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        let low = formatter.string(from: from)
        let high = formatter.string(from: to)

        var out: [FoundGame] = []
        for row in pack.games where row.start >= low && row.start <= high && row.status != "C" && row.status != "P" {
            guard let start = formatter.date(from: row.start) else { continue }
            let info: [String?] = row.venueId.flatMap { pack.venues[$0] } ?? []
            let venueName = (info.count > 0 ? info[0] : nil) ?? ""
            let city: String? = info.count > 1 ? info[1] : nil
            let game = FoundGame(
                league: pack.league,
                leagueName: names["\(pack.league)#\(row.home)"]?.league ?? pack.league,
                eventId: row.eventId,
                sport: sport,
                start: start,
                venueName: venueName,
                venueCity: (city?.isEmpty == false) ? city : nil,
                home: side(row.home, score: row.homeScore, league: pack.league, abbreviations: pack.teams, names: names),
                away: side(row.away, score: row.awayScore, league: pack.league, abbreviations: pack.teams, names: names),
                completed: row.status == "F",
                note: row.note.isEmpty ? nil : row.note,
                seasonSlug: row.note.isEmpty ? nil : row.note.lowercased().replacingOccurrences(of: " ", with: "-"),
                seasonType: nil)
            if GameLookup.venueMatches(game, venue: venue) { out.append(game) }
        }
        return out
    }

    private static func side(_ id: String, score: Int?, league: String, abbreviations: [String: String],
                             names: [String: TeamBrief]) -> FoundGame.Side {
        let abbreviation = abbreviations[id] ?? id
        let brief = names["\(league)#\(id)"]
        return FoundGame.Side(espnId: id, abbreviation: abbreviation, location: brief?.location ?? abbreviation,
                              name: brief?.name ?? abbreviation, color: brief?.color, altColor: brief?.altColor,
                              score: score, line: [])
    }

    /// Season years a window can fall in: a split season starts the year before the new year.
    static func seasons(from: Date, to: Date) -> ClosedRange<Int> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let first = calendar.component(.year, from: from) - 1
        let last = calendar.component(.year, from: to)
        return first...max(first, last)
    }
}
