import Foundation

/// What we could read off a ticket, a ticket screenshot or a confirmation email.
struct TicketDraft: Hashable {
    var sport: Sport?
    var date: Date?
    var homeTeamId: String?
    var awayTeamId: String?
    var venueId: String?
    var venueName: String?
    var section: String?
    var row: String?
    var seat: String?
    /// "Sec 314 · Row 7 · Seat 12"
    var seatLine: String?
    /// "Ticketmaster", "StubHub", "SeatGeek", "AXS"
    var source: String?
}

/// Reads tickets from any seller by looking at what's printed on them, not by
/// calling the seller's API. Pure and deterministic.
enum TicketParser {
    static func parse(_ text: String, teams: [Team], venues: [Venue], now: Date = .now) -> TicketDraft {
        var draft = TicketDraft()
        // OCR breaks lines anywhere, so most matching runs on a single-spaced copy.
        let flat = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let lower = flat.lowercased()

        draft.source = source(in: lower)

        let venue = matchVenue(normalize(lower), venues: venues)
        draft.venueId = venue?.id
        draft.venueName = venue?.name

        let (home, away) = matchTeams(flat, lower: lower, teams: teams, venue: venue)
        draft.homeTeamId = home?.id
        draft.awayTeamId = away?.id

        draft.sport = home?.sport ?? away?.sport ?? (venue?.sports.count == 1 ? venue?.sports.first : nil)

        let tz = venue?.tz ?? .current
        draft.date = parseDate(flat, timeZone: tz, now: now)

        let seat = parseSeat(flat)
        draft.section = seat.section
        draft.row = seat.row
        draft.seat = seat.seat
        var parts: [String] = []
        if let s = seat.section { parts.append("Sec \(s)") }
        if let r = seat.row { parts.append("Row \(r)") }
        if let s = seat.seat { parts.append("Seat \(s)") }
        draft.seatLine = parts.isEmpty ? nil : parts.joined(separator: " · ")
        return draft
    }

    // MARK: Source

    static func source(in lower: String) -> String? {
        if lower.contains("ticketmaster") { return "Ticketmaster" }
        if lower.contains("stubhub") { return "StubHub" }
        if lower.contains("seatgeek") { return "SeatGeek" }
        if firstMatch("\\baxs\\b", in: lower) != nil { return "AXS" }
        if lower.contains("vivid seats") { return "Vivid Seats" }
        if lower.contains("ballpark app") || lower.contains("mlb ballpark") { return "MLB Ballpark" }
        return nil
    }

    // MARK: Venue

    private static let venueStopwords: Set<String> = [
        "field", "park", "stadium", "center", "centre", "arena", "garden", "family", "american",
        "national", "nationals", "great", "circuit", "guaranteed", "the", "americas", "ballpark",
        "square", "madison", "health", "bank", "citizens", "signal", "united", "mobile", "states",
    ]

    /// `lower` must already be normalized (lowercased, accent-folded).
    static func matchVenue(_ lower: String, venues: [Venue]) -> Venue? {
        // Full names first, longest wins ("Wrigley Field" over a shorter name inside it).
        let full = venues.filter { lower.contains(normalize($0.name)) }
            .max { $0.name.count < $1.name.count }
        if let full { return full }

        // Then a distinctive word from the name ("Wrigley", "Lambeau", "Bernabéu").
        var tokenOwners: [String: [Venue]] = [:]
        for v in venues {
            for token in normalize(v.name).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            where token.count >= 5 && !venueStopwords.contains(token) {
                tokenOwners[token, default: []].append(v)
            }
        }
        var best: (Venue, Int)?
        for (token, owners) in tokenOwners where owners.count == 1 {
            if let r = firstMatch("\\b\(NSRegularExpression.escapedPattern(for: token))\\b", in: lower) {
                if best == nil || r.location < best!.1 { best = (owners[0], r.location) }
            }
        }
        return best?.0
    }

    /// Lowercased and accent-folded so "Bernabeu" matches "Bernabéu".
    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
    }

    // MARK: Teams

    /// Nicknames that changed or that tickets print differently.
    private static let aliases: [String: String] = [
        "guardians": "mlb-cle", "white sox": "mlb-cws", "red sox": "mlb-bos",
        "athletics": "mlb-ath", "inter miami": "mls-mia", "chicago fire": "mls-chi",
        "fc barcelona": "lal-bar", "borussia dortmund": "bun-bvb", "fc schalke": "bun-s04",
        "real madrid": "lal-rma", "red bull": "f1-rbr",
    ]

    private struct Hit { let team: Team; let start: Int; let end: Int }

    static func matchTeams(_ flat: String, lower: String, teams: [Team], venue: Venue?) -> (home: Team?, away: Team?) {
        let folded = normalize(lower)
        var hits: [Hit] = []

        func add(_ team: Team, _ phrase: String) {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: normalize(phrase)))\\b"
            for r in allMatches(pattern, in: folded) {
                hits.append(Hit(team: team, start: r.location, end: r.location + r.length))
            }
        }

        let byId = Dictionary(teams.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for team in teams {
            add(team, team.teamName)
            if team.teamName != team.locationName {
                add(team, "\(team.locationName) \(team.teamName)")
            }
        }
        for (alias, id) in aliases { if let t = byId[id] { add(t, alias) } }

        // Tickets that only print codes: "CLE @ CHC", "GB vs CHI".
        if Set(hits.map(\.team.id)).count < 2,
           let m = firstMatchGroups("\\b([A-Z]{2,3})\\s*(@|vs\\.?|at|v\\.?)\\s*([A-Z]{2,3})\\b", in: flat) {
            let a = m[0], conn = m[1].lowercased(), b = m[2]
            let candidates = venueFiltered(teams, venue)
            if let ta = candidates.first(where: { $0.abbreviation == a }),
               let tb = candidates.first(where: { $0.abbreviation == b }) {
                return conn.hasPrefix("v") ? (ta, tb) : (tb, ta)
            }
        }

        // Keep teams that fit the venue's sports when there's a venue.
        if let venue {
            let fitting = hits.filter { venue.sports.contains($0.team.sport) }
            if !fitting.isEmpty { hits = fitting }
        }
        hits.sort { $0.start < $1.start }

        // The first team's sport decides; the second is the next team in that sport.
        guard let first = hits.first else { return (nil, nil) }
        guard let second = hits.first(where: { $0.team.id != first.team.id && $0.team.sport == first.team.sport && $0.start >= first.end })
            ?? hits.first(where: { $0.team.id != first.team.id && $0.team.sport == first.team.sport }) else {
            return (first.team, nil)
        }

        let (a, b) = first.start <= second.start ? (first, second) : (second, first)
        let between = substring(folded, from: a.end, to: b.start)
        if firstMatch("(^|\\s)(at|@)(\\s|$)", in: between) != nil || between.contains("@") {
            return (b.team, a.team)
        }
        return (a.team, b.team)
    }

    private static func venueFiltered(_ teams: [Team], _ venue: Venue?) -> [Team] {
        guard let venue else { return teams }
        let f = teams.filter { venue.sports.contains($0.sport) }
        return f.isEmpty ? teams : f
    }

    // MARK: Date

    private static let months: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12,
        "january": 1, "february": 2, "march": 3, "april": 4, "june": 6, "july": 7, "august": 8,
        "september": 9, "october": 10, "november": 11, "december": 12,
    ]
    private static let monthPattern =
        "(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec)"

    static func parseDate(_ flat: String, timeZone: TimeZone, now: Date) -> Date? {
        let lower = flat.lowercased()
        var y: Int?, m: Int?, d: Int?
        var at = 0

        if let r = firstMatchGroupsWithRange("\\b(\\d{4})-(\\d{2})-(\\d{2})\\b", in: lower) {
            y = Int(r.groups[0]); m = Int(r.groups[1]); d = Int(r.groups[2]); at = r.range.location
        } else if let r = firstMatchGroupsWithRange("\\b(\\d{1,2})/(\\d{1,2})/(\\d{2,4})\\b", in: lower) {
            m = Int(r.groups[0]); d = Int(r.groups[1])
            if let yy = Int(r.groups[2]) { y = yy < 100 ? 2000 + yy : yy }
            at = r.range.location
        } else if let r = firstMatchGroupsWithRange("\\b\(monthPattern)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(\\d{4})\\b", in: lower) {
            m = months[r.groups[0]]; d = Int(r.groups[1]); y = Int(r.groups[2]); at = r.range.location
        } else if let r = firstMatchGroupsWithRange("\\b(\\d{1,2})\\s+\(monthPattern)\\.?,?\\s+(\\d{4})\\b", in: lower) {
            d = Int(r.groups[0]); m = months[r.groups[1]]; y = Int(r.groups[2]); at = r.range.location
        } else if let r = firstMatchGroupsWithRange("\\b\(monthPattern)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b", in: lower) {
            m = months[r.groups[0]]; d = Int(r.groups[1]); at = r.range.location
            // "Sun • Jan 05 • 3:25 PM 2025": the year can sit anywhere after.
            let rest = substring(lower, from: r.range.location, to: (lower as NSString).length)
            if let yr = firstMatchGroups("\\b(19\\d{2}|20\\d{2})\\b", in: rest) { y = Int(yr[0]) }
        }
        guard let month = m, let day = d, (1...12).contains(month), (1...31).contains(day) else { return nil }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let (hour, minute) = parseTime(lower, after: at) ?? (19, 0)
        var comps = DateComponents(year: y ?? cal.component(.year, from: now), month: month, day: day, hour: hour, minute: minute)
        guard var date = cal.date(from: comps) else { return nil }
        // No year printed and the date would be in the future: it was last year.
        if y == nil, date > now.addingTimeInterval(86_400) {
            comps.year = (comps.year ?? 0) - 1
            date = cal.date(from: comps) ?? date
        }
        return date
    }

    /// The first time printed after the date, "7:08 PM" or "19:05".
    static func parseTime(_ lower: String, after: Int) -> (Int, Int)? {
        let twelve = allMatchGroups("\\b(\\d{1,2}):(\\d{2})\\s*([ap])\\.?m\\.?", in: lower)
        let pick = twelve.first { $0.range.location >= after } ?? twelve.first
        if let p = pick, var h = Int(p.groups[0]), let mi = Int(p.groups[1]), (1...12).contains(h), mi < 60 {
            let pm = p.groups[2] == "p"
            if pm && h != 12 { h += 12 }
            if !pm && h == 12 { h = 0 }
            return (h, mi)
        }
        let military = allMatchGroups("\\b([01]?\\d|2[0-3]):([0-5]\\d)\\b(?!:)", in: lower)
        if let p = military.first(where: { $0.range.location >= after }) ?? military.first,
           let h = Int(p.groups[0]), let mi = Int(p.groups[1]) {
            return (h, mi)
        }
        return nil
    }

    // MARK: Seat

    static func parseSeat(_ flat: String) -> (section: String?, row: String?, seat: String?) {
        let labels: Set<String> = ["row", "seat", "seats", "sec", "section", "sect", "gate", "entry", "sector", "block"]
        // Stacked labels, as screenshots print them: "SEC ROW SEAT 314 7 12".
        if let g = firstMatchGroups("(?i)\\b(?:section|sec)\\b\\.?\\s+row\\s+seats?\\s+([A-Za-z0-9]{1,6})\\s+([A-Za-z0-9]{1,4})\\s+(\\d{1,4}(?:\\s*[-–]\\s*\\d{1,4})?)", in: flat) {
            return (g[0], g[1], g[2].replacingOccurrences(of: " ", with: ""))
        }
        func value(_ pattern: String) -> String? {
            guard let g = firstMatchGroups(pattern, in: flat) else { return nil }
            let v = g[0].trimmingCharacters(in: .whitespaces)
            return labels.contains(v.lowercased()) ? nil : v
        }
        let section = value("(?i)\\b(?:section|sector|sect|sec|block)\\b\\.?\\s*[:#]?\\s*([A-Za-z0-9]{1,6})\\b")
        let row = value("(?i)\\brow\\b\\s*[:#]?\\s*([A-Za-z0-9]{1,4})\\b")
        let seat = value("(?i)\\bseats?\\b\\s*[:#]?\\s*(\\d{1,4}(?:\\s*[-–]\\s*\\d{1,4})?)")
        return (section, row, seat?.replacingOccurrences(of: " ", with: ""))
    }

    // MARK: Regex helpers

    private struct GroupMatch { let range: NSRange; let groups: [String] }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [])
    }

    private static func firstMatch(_ pattern: String, in s: String) -> NSRange? {
        regex(pattern)?.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length))?.range
    }

    private static func allMatches(_ pattern: String, in s: String) -> [NSRange] {
        regex(pattern)?.matches(in: s, range: NSRange(location: 0, length: (s as NSString).length)).map(\.range) ?? []
    }

    private static func allMatchGroups(_ pattern: String, in s: String) -> [GroupMatch] {
        guard let re = regex(pattern) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
            let groups: [String] = (1..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
            return GroupMatch(range: m.range, groups: groups)
        }
    }

    private static func firstMatchGroupsWithRange(_ pattern: String, in s: String) -> GroupMatch? {
        allMatchGroups(pattern, in: s).first
    }

    private static func firstMatchGroups(_ pattern: String, in s: String) -> [String]? {
        firstMatchGroupsWithRange(pattern, in: s)?.groups
    }

    private static func substring(_ s: String, from: Int, to: Int) -> String {
        let ns = s as NSString
        let start = max(0, min(from, ns.length)), end = max(start, min(to, ns.length))
        return ns.substring(with: NSRange(location: start, length: end - start))
    }
}
