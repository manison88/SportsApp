import Foundation
import CoreLocation

/// What the photo scan makes of one day, step by step, so a game it missed can be traced on the phone: where each photo was
/// placed, the visits that makes under the scan's rule and the album rule, what the library already holds that day (which can
/// keep the scan and the background search away from it), and what the schedules say at each stadium and the grounds next
/// door. Plain text to share; nothing leaves the phone unless the fan sends it.
enum ScanCheck {
    /// How many photos are listed one by one; the rest are counted.
    static let listed = 150

    /// The pure part: the photos, the visits they make and what is saved that day. Times are shown in `zone`.
    static func lines(points: [PhotoPoint], venues: [Venue], saved: [GameEntry], zone: TimeZone = .current) -> [String] {
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        time.timeZone = zone
        var out: [String] = []
        let located = points.filter { $0.latitude != nil && $0.longitude != nil }
        let transit = TransitCheck.verdicts(points)
        let airborne = transit.values.filter { if case .airborne = $0 { true } else { false } }.count
        out.append("Photos: \(points.count) (\(located.count) with a location, \(points.count - located.count) without)"
                   + (transit.isEmpty ? "" : " \u{00B7} \(airborne) in the air, \(transit.count - airborne) on the move: these never place a visit"))

        let index = VenueIndex(venues)
        out.append("")
        out.append("Where each photo was placed (inside = the stadium's fence; near = within \(Int(VisitGrouping.matchdayReach)) m, joins a visit that day; "
                   + "m up = altitude; in the air = \(Int(TransitCheck.climb))+ m above the lowest photo nearby; on the move = \(Int(TransitCheck.movingSpeed))+ m/s between shots \(Int(TransitCheck.movingDistance / 1000))+ km apart):")
        for p in located.prefix(listed) {
            guard let lat = p.latitude, let lon = p.longitude else { continue }
            let here = CLLocation(latitude: lat, longitude: lon)
            let place: String
            if let v = index.nearest(lat: lat, lon: lon) {
                place = "inside \(v.name) (\(Int(here.distance(from: v.location))) m, fence \(Int(v.geofence)) m)"
            } else if let v = index.nearest(lat: lat, lon: lon, radius: VisitGrouping.matchdayReach) {
                place = "near \(v.name) (\(Int(here.distance(from: v.location))) m)"
            } else if let v = index.nearest(lat: lat, lon: lon, radius: GameSuggester.reach) {
                place = "\(Int(here.distance(from: v.location))) m from \(v.name)"
            } else {
                place = "no stadium within \(Int(GameSuggester.reach / 1000)) km"
            }
            let height = p.altitude.map { " \u{00B7} \(Int($0)) m up" } ?? ""
            let verdict = transit[p.id].map { " \u{00B7} \($0.text)" } ?? ""
            out.append("  \(p.date.map { time.string(from: $0) } ?? "--:--")  \(String(format: "%.5f,%.5f", lat, lon))  \(place)\(height)\(verdict)")
        }
        if located.count > listed { out.append("  ... and \(located.count - listed) more") }

        out.append("")
        out.append("Saved that day:")
        if saved.isEmpty { out.append("  nothing") }
        let settled = PhotoMatcher.settledKeys(saved, venues: venues)
        for g in saved {
            let venue = venues.first { $0.id == g.venueId }
            let what = g.isVisit ? "stadium visit" : g.source.map { "game (\($0.league) \($0.eventId))" } ?? "game (no schedule match)"
            let key = venue.map { VisitGrouping.key(venueId: $0.id, date: g.date, tz: $0.tz) } ?? g.venueId
            out.append("  \(time.string(from: g.date))  \(what) at \(venue?.name ?? g.venueId), \(g.photos.count) photos"
                       + (settled.contains(key) ? " \u{00B7} the scan leaves \(venue?.name ?? "this stadium") alone this day" : " \u{00B7} checked again by the scan"))
        }
        if !saved.isEmpty { out.append("  The background search skips this day: something is saved on it.") }

        let scan = VisitGrouping.group(points, venues: venues, minimumStay: 15 * 60, skipping: settled, transit: transit)
        let album = VisitGrouping.group(points, venues: venues, transit: transit)
        out.append("")
        out.append("Visits (scan rule: a photo inside the fence, on the ground and not on the move, and the day's photos 15+ min apart):")
        if scan.visits.isEmpty { out.append("  none") }
        for v in scan.visits { out.append("  " + describe(v, time: time)) }
        let dropped = album.visits.filter { a in !scan.visits.contains { $0.id == a.id } }
        if !dropped.isEmpty {
            out.append("Visits only an album would make (the scan drops these: too short a stay inside the fence, or already saved):")
            for v in dropped { out.append("  " + describe(v, time: time)) }
        }
        // As if every photo were on the ground: what the air or the road would have placed.
        let grounded = VisitGrouping.group(points, venues: venues, transit: [:]).visits.filter { g in !album.visits.contains { $0.id == g.id } }
        if !grounded.isEmpty {
            out.append("Visits the photos would make if every one were on the ground (the scan drops these: every photo inside the fence was in the air or on the move):")
            for v in grounded { out.append("  " + describe(v, time: time)) }
        }
        return out
    }

    /// What can keep the day out of a review even when the schedule has its game: the skips kept on disk, the visits waiting for
    /// the background search, the days spent around a stadium with no photo inside its fence.
    static func gates(points: [PhotoPoint], venues: [Venue], library: [GameEntry], ledger: ReviewLedger, pending: [PhotoCluster],
                      zone: TimeZone = .current) -> [String] {
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        time.timeZone = zone
        let ids = Set(points.map(\.id))
        var keyer = DayKeyer()
        let days = Set(points.compactMap(\.date).map { keyer.day($0, tz: zone) })
        var out = [""]
        out.append("Skips (review-ledger.json): \(ids.intersection(ledger.dismissedAssets).count) of this day's photos skipped, "
                   + "\(ids.intersection(ledger.dismissedGames).count) of them as a game \u{00B7} day skipped: "
                   + (days.isDisjoint(with: ledger.dismissedDays) ? "no" : "yes (the album search leaves it alone)"))
        let waiting = pending.filter { !ids.isDisjoint(with: $0.assetIds) }
        out.append("Waiting for the background search (pending-visits.json): "
                   + (waiting.isEmpty ? "none" : waiting.map { describe($0, time: time) }.joined(separator: "; ")))
        let found = PhotoMatcher.found(in: points, venues: venues, existing: library)
        out.append("Around a stadium, no photo inside its fence (within \(Int(PhotoMatcher.nearbyReach)) m, 3+ photos, 15+ min; a possible game when the schedule has one):")
        if found.nearby.isEmpty { out.append("  none") }
        for day in found.nearby { out.append("  " + describe(day, time: time)) }
        return out
    }

    /// Whether the review shows a visit the schedule matched, and if not, what keeps it out.
    static func verdict(_ cluster: PhotoCluster, library: [GameEntry], venues: [Venue], ledger: ReviewLedger) -> String {
        if !ReviewQueue.firstPass(games: [cluster], others: [], library: library, venues: venues, ledger: ledger).games.isEmpty {
            return "the review shows it"
        }
        let ids = Set(cluster.assetIds)
        if !ids.isDisjoint(with: ledger.dismissedGames) { return "left out: skipped as a game in an earlier review" }
        let holder = library.first { g in
            !g.awaitsGame && g.photos.contains { if case .library(let id) = $0 { return ids.contains(id) } else { return false } }
        }
        if let holder {
            let name = venues.first { $0.id == holder.venueId }?.name ?? holder.venueId
            return "left out: its photos are on a saved game at \(name) (\(holder.source.map { "\($0.league) \($0.eventId)" } ?? "no schedule match"))"
        }
        return "left out"
    }

    /// How an album with the day's photos reads: whether its title names two teams, which, and the game between them while
    /// its photos were taken. `offered` says whether the review would show each day found.
    static func albumLines(_ outcome: MatchupAlbums.Outcome, inDay: Int, venues: [Venue], offered: (PossibleDay) -> Bool,
                           zone: TimeZone = .current) -> [String] {
        let time = DateFormatter()
        time.dateFormat = "MMM d HH:mm"
        time.timeZone = zone
        let album = outcome.album, parsed = outcome.parsed
        var out = ["  \u{201C}\(album.title)\u{201D}: \(album.count) photos, \(inDay) of them from this day"]
        if GameSuggester.isAppAlbum(album.title) {
            out.append("    an app's album (skipped)")
            return out
        }
        func names(_ teams: [Team]) -> String { teams.isEmpty ? "no team" : teams.map { "\($0.locationName) (\($0.abbreviation), \($0.league))" }.joined(separator: " or ") }
        if parsed.sides.isEmpty {
            out.append("    title: no \"v\", \"vs\", \"-\" or \"@\" between two sides")
        } else {
            out.append("    title: \"\(parsed.sides[0])\" \u{2192} \(names(parsed.home)) \u{00B7} \"\(parsed.sides[1])\" \u{2192} \(names(parsed.away))")
        }
        guard parsed.isMatchup else {
            out.append("    not a matchup: read like any album (its photos must show a game, and a stadium it names must have one)")
            return out
        }
        if outcome.outings.isEmpty { out.append("    no run of \(GameSuggester.minPhotos)+ dated photos to look up") }
        for o in outcome.outings {
            var line = "    photos \(time.string(from: o.first))\u{2013}\(time.string(from: o.last)) (\(o.count)): "
            if let game = o.game {
                let at = GameLookup.venue(of: game, in: venues)
                let local = DateFormatter()
                local.dateFormat = "MMM d HH:mm zzz"
                local.timeZone = at?.tz ?? zone
                line += "\(game.away.name) at \(game.home.name), \(at?.name ?? game.venueName + " (not in the catalog)"), \(local.string(from: game.start)) (\(game.league) \(game.eventId))"
                if let day = outcome.days.first(where: { $0.id.hasSuffix("|" + game.id) && Set($0.times).contains(o.first) }) {
                    line += offered(day) ? " \u{2192} offered as a possible game" : " \u{2192} left out: already added or skipped"
                } else {
                    line += " \u{2192} left out: already in the library"
                }
            } else {
                line += "no game between these teams on any of their schedules then (6 h either side)"
            }
            out.append(line)
        }
        return out
    }

    /// The photos with no location: how many, by hour, each stretch of them, where the located photos around it say the fan
    /// was, and the stadiums whose schedules that city's day asks. `day` is the phone's calendar day; `points` reach twelve
    /// hours either side, for the evening before and the next morning.
    static func cityLines(points: [PhotoPoint], day: Range<Date>, venues: [Venue], taken: Set<String>, existing: [GameEntry],
                          zone: TimeZone = .current) -> [String] {
        let located = CityDays.located(points)
        let big = CityDays.bigGrounds(venues)
        let runs = CityDays.runs(points, taken: taken).filter { r in r.contains { day.contains($0.date!) } }
        let verdicts = runs.map { CityDays.judge($0, located: located, grounds: big, existing: existing) }
        // Hours in the city's time zone once one is known, else the phone's.
        let cityZone = verdicts.lazy.compactMap { v -> TimeZone? in if case .day(let d) = v { return d.venues.first?.tz } else { return nil } }.first
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        time.timeZone = zone
        let hour = DateFormatter()
        hour.dateFormat = "HH"
        hour.timeZone = cityZone ?? zone
        let loose = points.filter { $0.latitude == nil && $0.date.map(day.contains) == true }
        var out = ["", "Photos with no location (a possible game when the located photos around them place you in one city and its schedule had a game then):"]
        let shots = loose.filter(\.screenshot).count
        out.append("  \(loose.count) this day\(shots > 0 ? ", \(shots) of them screenshots (left out)" : "")\(taken.isEmpty ? "" : " \u{00B7} photos on a visit or a day around a stadium are left out")")
        var counts: [String: Int] = [:]
        for p in loose where !p.screenshot { counts[hour.string(from: p.date!), default: 0] += 1 }
        if !counts.isEmpty {
            out.append("  by hour (\((cityZone ?? zone).identifier)): " + counts.keys.sorted().map { "\($0)h \(counts[$0]!)" }.joined(separator: " \u{00B7} "))
        }
        if runs.isEmpty { out.append("  no stretch of photos with no location") }
        func spot(_ p: PhotoPoint, _ span: ClosedRange<Date>) -> String {
            let when = p.date! < span.lowerBound ? "before" : p.date! > span.upperBound ? "after" : "during"
            return "\(time.string(from: p.date!)) \(String(format: "%.5f,%.5f", p.latitude!, p.longitude!)) (\(when))"
        }
        for (run, verdict) in zip(runs, verdicts) {
            let span = run.first!.date!...run.last!.date!
            var line = "  \(time.string(from: span.lowerBound))\u{2013}\(time.string(from: span.upperBound)) (\(run.count) photos): "
            switch verdict {
            case .day(let d):
                line += "in \(d.city), from \(d.anchors.map { spot($0, span) }.joined(separator: ", ")) \u{00B7} schedules asked: "
                    + d.venues.map(\.name).joined(separator: ", ")
            case .noGrounds(let anchors):
                line += verdict.why + " (" + anchors.map { spot($0, span) }.joined(separator: ", ") + ")"
            default:
                line += verdict.why
            }
            out.append(line)
        }
        return out
    }

    /// What a city day's schedules and photos said, and whether the review shows it.
    static func cityLines(_ eval: CityDays.Evaluation, offered: (PossibleDay) -> Bool) -> [String] {
        let day = eval.day
        let zone = day.venues.first?.tz ?? .current
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        time.timeZone = zone
        var out = ["  \(day.city), \(time.string(from: day.start))\u{2013}\(time.string(from: day.end)) \(zone.abbreviation(for: day.start) ?? zone.identifier):"]
        if eval.games.isEmpty { out.append("    no game at these stadiums then") }
        for fit in eval.games {
            let k = fit.game.start
            out.append("    \(fit.game.away.name) at \(fit.game.home.name), \(fit.venue.name), kickoff \(time.string(from: k)) (\(fit.game.league) \(fit.game.eventId)): "
                       + "window \(time.string(from: k.addingTimeInterval(-CityDays.before)))\u{2013}\(time.string(from: k.addingTimeInterval(CityDays.after))), "
                       + (fit.photos.isEmpty ? "no stay in it (\(CityDays.minPhotos)+ photos over \(Int(CityDays.minSpan / 60))+ min)" : "\(fit.photos.count) photos in it"))
        }
        if let look = eval.look {
            out.append("    scene check of the window's photos: \(look.classified) classified, \(look.venue) stadium or sport, \(look.structure) the ground itself, "
                       + "\(look.elsewhere) somewhere else \u{2192} looks like a stadium: \(CityDays.looksLikeTheGround(look) ? "yes" : "no") "
                       + "(needs 3+ stadium or sport and 30%+, 2+ the ground, under 25% somewhere else)")
        }
        if let offer = eval.offer {
            out.append("    \u{2192} " + (offered(offer) ? "offered as a possible game: \(offer.reason)" : "left out: already added or skipped"))
        } else {
            out.append("    \u{2192} not offered: " + (eval.games.isEmpty ? "no game" : eval.best.isEmpty ? "no game's window holds a stay" : "the photos don't look like a stadium"))
        }
        return out
    }

    private static func describe(_ v: PhotoCluster, time: DateFormatter) -> String {
        "\(v.venue.name) [\(v.id)]: \(v.assetIds.count) photos, \(time.string(from: v.start))\u{2013}\(time.string(from: v.end))"
            + (v.insideIds.map { " (\($0.count) inside the fence)" } ?? "")
    }

    /// What the scene check made of a visit with no game: whether it is offered as a stadium visit (a tour), and why.
    static func tourLine(_ visit: PhotoCluster, look: SceneCheck.DayLook) -> String {
        "scene check of the \(visit.anchors.count) photos inside the fence: \(look.classified) classified, \(look.structure) the ground itself, "
            + "\(look.aerial) from the air, \(look.elsewhere) somewhere else \u{2192} "
            + (look.showsTheGround() ? "offered as a stadium visit" : "not a stadium visit, waits for the background search")
            + " (needs 3+ of the ground itself, none from the air, under half somewhere else)"
    }

    /// The whole report for the phone's calendar day holding `day`, with each visit's schedule lookups.
    @MainActor
    static func report(day: Date, library: Library, scan: ScanModel? = nil) async -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let venues = library.venues
        let saved = library.games.filter { $0.origin != .sample && $0.date >= start && $0.date < end }
        let points = await PhotoMatcher.points(from: start, to: end)
        let stamp = DateFormatter()
        stamp.dateStyle = .full
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        var out = ["Witness scan check \u{00B7} \(stamp.string(from: start)) \u{00B7} \(TimeZone.current.identifier) \u{00B7} app \(version) (\(build))",
                   "Photo access: \(PhotoMatcher.accessDescription) \u{00B7} catalog stadiums: \(venues.count) \u{00B7} background search declined: \(UserDefaults.standard.bool(forKey: "deepScanDeclined") ? "yes" : "no")"]
        if let scan {
            out.append("Scan now: \(scan.state) \u{00B7} reviewed: \(scan.reviewed ? "yes" : "no") \u{00B7} background search: \(scan.deepState)"
                       + " \u{00B7} waiting for review: \(scan.games.count) games, \(scan.others.count) visits, \(scan.possible.count) possible")
        }
        out += lines(points: points, venues: venues, saved: saved)
        let ledger = scan?.ledger ?? ReviewLedger.load(from: ScanModel.ledgerURL)
        out += gates(points: points, venues: venues, library: library.games, ledger: ledger, pending: scan?.pendingVisits ?? [])

        // The schedule for every visit an album would make (the scan's visits are among them): the stadium, then next door.
        let visits = VisitGrouping.group(points, venues: venues).visits
        out.append("")
        out.append("Schedules (each visit's photo times, from 5 hours before the first to an hour after the last):")
        if visits.isEmpty { out.append("  no visit to look up") }
        for visit in visits {
            out.append("  \(visit.venue.name):")
            for venue in [visit.venue] + PhotoMatcher.neighbors(of: visit.venue, in: venues) {
                let leagues = GameLookup.leagues(for: venue)
                let games = await GameLookup.games(at: venue, from: visit.start, to: visit.end)
                let found = games.isEmpty ? "no game" : games.map { g in
                    "\(g.away.name) at \(g.home.name), \(DateFormatter.localizedString(from: g.start, dateStyle: .none, timeStyle: .short)) (\(g.league) \(g.eventId))"
                }.joined(separator: "; ")
                out.append("    \(venue.id == visit.venue.id ? "" : "next door: ")\(venue.name) [\(leagues.count) competitions: \(leagues.joined(separator: ", "))] \u{2192} \(found)")
            }
            let match = await ScanModel.match(visit, venues: venues)
            out.append("    scan match: \(match.map { "\($0.away.name) at \($0.home.name) (\($0.league) \($0.eventId))" } ?? "none")")
        }
        // The albums holding the day's photos: a title naming the game finds it with no located photo.
        let albums = await Task.detached(priority: .userInitiated) { AlbumImporter.albums(containing: points.map(\.id)) }.value
        out.append("")
        out.append("Albums with this day's photos (a title naming two teams asks their schedules for a game while the photos were taken):")
        if albums.isEmpty { out.append("  none") }
        let reader = MatchupAlbums.Reader(teams: library.allTeams)
        for (album, inDay) in albums.prefix(12) {
            let parsed = reader.parse(album.title)
            let albumPoints = parsed.isMatchup ? await Task.detached { AlbumImporter.points(in: album) }.value : []
            let outcome = await MatchupAlbums.check(album, points: albumPoints, parsed: parsed, venues: venues, existing: library.games)
            out += albumLines(outcome, inDay: inDay, venues: venues, offered: {
                !ReviewQueue.possible([$0], alongside: [], library: library.games, ledger: ledger).isEmpty
            })
        }

        // Photos with no location: the located photos around them (the evening before, the next morning) say which city.
        let reach = CityDays.anchorReach
        let wide = await PhotoMatcher.points(from: start.addingTimeInterval(-reach), to: end.addingTimeInterval(reach))
        let wideScan = PhotoMatcher.found(in: wide, venues: venues, existing: library.games)
        let taken = Set(wideScan.visits.flatMap(\.assetIds) + wideScan.nearby.flatMap(\.assetIds))
        out += cityLines(points: wide, day: start..<end, venues: venues, taken: taken, existing: library.games)
        for day in wideScan.cityDays where day.end >= start && day.start < end {
            let eval = await CityDays.evaluate(day) { await SceneCheck.look(at: $0, max: CityDays.sample) }
            out += cityLines(eval) { !ReviewQueue.possible([$0], alongside: [], library: library.games, ledger: ledger).isEmpty }
        }

        // What the scan itself makes of the day, with the library's saved games and the skips: what the review would show.
        let scanned = PhotoMatcher.found(in: points, venues: venues, existing: library.games)
        out.append("")
        out.append("Review (what Find in photos would offer for this day):")
        if scanned.visits.isEmpty && scanned.nearby.isEmpty { out.append("  nothing: no visit and no day around a stadium") }
        // What the scan would have made of the day had every photo been on the ground.
        let grounded = VisitGrouping.group(points, venues: venues, minimumStay: 15 * 60,
                                           skipping: PhotoMatcher.settledKeys(library.games, venues: venues), transit: [:]).visits
        for visit in grounded where !scanned.visits.contains(where: { $0.id == visit.id }) {
            out.append("  \(visit.venue.name): dropped, every photo inside its fence was in the air or on the move (see each photo above)")
        }
        for visit in scanned.visits {
            if let game = await ScanModel.match(visit, venues: venues) {
                out.append("  \(visit.venue.name): \(game.away.name) at \(game.home.name) \u{2192} "
                           + verdict(visit, library: library.games, venues: venues, ledger: ledger))
            } else {
                let look = await SceneCheck.look(at: visit.anchors.map { PhotoRef.library($0) }, max: SceneCheck.tourSample)
                out.append("  \(visit.venue.name): no game on the schedule \u{2192} " + tourLine(visit, look: look))
            }
        }
        for day in scanned.nearby {
            let offer = await ScanModel.nearbyDay(day, venues: venues)
            let shown = offer.map { !ReviewQueue.possible([$0], alongside: [], library: library.games, ledger: ledger).isEmpty } ?? false
            out.append("  around \(day.venue.name): " + (offer.map { "\($0.reason) \u{2192} " + (shown ? "offered as a possible game" : "left out: already added or skipped") }
                                                         ?? "no game on the schedule while the photos were taken"))
        }
        return out.joined(separator: "\n")
    }
}
