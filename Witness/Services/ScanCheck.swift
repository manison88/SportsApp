import Foundation
import CoreLocation

/// What the photo scan makes of one day, step by step, so a game it missed can be traced on the phone: where each photo was
/// placed, the visits that makes under the scan's rule and the album rule, what the library already holds that day (which can
/// keep the scan and the background search away from it), and what the schedules say at each stadium and the grounds next
/// door. Plain text to share; nothing leaves the phone unless the fan sends it.
enum ScanCheck {
    /// The pure part: the photos, the visits they make and what is saved that day. Times are shown in `zone`. At most
    /// `scanCheckListed` photos are listed one by one; the rest are counted.
    static func lines(points: [PhotoPoint], venues: [Venue], saved: [GameEntry], zone: TimeZone = .current,
                      settings: ScanSettings = .current) -> [String] {
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        time.timeZone = zone
        var out: [String] = []
        let located = points.filter { $0.latitude != nil && $0.longitude != nil }
        let moving = TransitCheck.moving(points, settings: settings)
        out.append("Photos: \(points.count) (\(located.count) with a location, \(points.count - located.count) without)"
                   + (moving.isEmpty ? "" : " \u{00B7} \(moving.count) on the move: these never place a visit"))

        let index = VenueIndex(venues, settings: settings)
        let listed = settings.scanCheckListed
        out.append("")
        out.append("Where each photo was placed (inside = the stadium's fence; near = within \(Int(settings.matchdayReachMeters)) m, joins a visit that day; "
                   + "on the move = \(Int(settings.movingSpeed))+ m/s between shots \(Int(settings.movingDistanceMeters / 1000))+ km apart, or a fix over \(Int(settings.vehicleSpeed)) m/s, never places a visit):")
        for p in located.prefix(listed) {
            guard let lat = p.latitude, let lon = p.longitude else { continue }
            let here = CLLocation(latitude: lat, longitude: lon)
            let place: String
            if let v = index.nearest(lat: lat, lon: lon) {
                place = "inside \(v.name) (\(Int(here.distance(from: v.location))) m, fence \(Int(v.geofence(settings))) m)"
            } else if let v = index.nearest(lat: lat, lon: lon, radius: settings.matchdayReachMeters) {
                place = "near \(v.name) (\(Int(here.distance(from: v.location))) m)"
            } else if let v = index.nearest(lat: lat, lon: lon, radius: settings.suggestReachMeters) {
                place = "\(Int(here.distance(from: v.location))) m from \(v.name)"
            } else {
                place = "no stadium within \(Int(settings.suggestReachMeters / 1000)) km"
            }
            let verdict = moving[p.id].map { " \u{00B7} " + TransitCheck.text(speed: $0, settings: settings) } ?? ""
            out.append("  \(p.date.map { time.string(from: $0) } ?? "--:--")  \(String(format: "%.5f,%.5f", lat, lon))  \(place)\(verdict)")
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

        let stay = settings.visitStayMinutes * 60
        let scan = VisitGrouping.group(points, venues: venues, minimumStay: stay, skipping: settled, moving: moving, settings: settings)
        let album = VisitGrouping.group(points, venues: venues, moving: moving, settings: settings)
        out.append("")
        out.append("Visits (scan rule: a photo inside the fence, not on the move, and another inside or within reach of it, \(Int(settings.visitStayMinutes))+ min apart):")
        if scan.visits.isEmpty { out.append("  none") }
        for v in scan.visits { out.append("  " + describe(v, time: time)) }
        let dropped = album.visits.filter { a in !scan.visits.contains { $0.id == a.id } }
        if !dropped.isEmpty {
            out.append("Visits only an album would make (the scan drops these: too short a stay inside the fence, or already saved):")
            for v in dropped { out.append("  " + describe(v, time: time)) }
        }
        // As if no photo were on the move: what the air or the road would have placed.
        let grounded = VisitGrouping.group(points, venues: venues, moving: [:], settings: settings).visits.filter { g in !album.visits.contains { $0.id == g.id } }
        if !grounded.isEmpty {
            out.append("Visits the photos would make if none were on the move (the scan drops these: every photo inside the fence was on the move):")
            for v in grounded { out.append("  " + describe(v, time: time)) }
        }
        return out
    }

    /// What can keep the day out of a review even when the schedule has its game: the skips kept on disk, the visits waiting for
    /// the background search, the days spent around a stadium with no photo inside its fence.
    static func gates(points: [PhotoPoint], venues: [Venue], library: [GameEntry], ledger: ReviewLedger, pending: [PhotoCluster],
                      zone: TimeZone = .current, settings: ScanSettings = .current) -> [String] {
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        time.timeZone = zone
        let ids = Set(points.map(\.id))
        var out = [""]
        out.append("Skips (review-ledger.json): \(ids.intersection(ledger.dismissedAssets).count) of this day's photos skipped, "
                   + "\(ids.intersection(ledger.dismissedGames).count) of them as a game \u{00B7} outing skipped near this day's photos: "
                   + (points.compactMap(\.date).contains { ledger.skipped(at: $0, settings: settings) }
                      ? "yes (a possible game within \(Int(settings.skipWindowHours)) h of it is left out; the rest of the day is not)" : "no"))
        let waiting = pending.filter { !ids.isDisjoint(with: $0.assetIds) }
        out.append("Waiting for the background search (pending-visits.json): "
                   + (waiting.isEmpty ? "none" : waiting.map { describe($0, time: time) }.joined(separator: "; ")))
        let found = PhotoMatcher.found(in: points, venues: venues, existing: library, settings: settings)
        out.append("Around a stadium, no photo inside its fence (within \(Int(settings.nearbyReachMeters)) m, \(settings.nearbyPhotos)+ photos, "
                   + "\(Int(settings.visitStayMinutes))+ min; a possible game when the schedule has one):")
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
                           zone: TimeZone = .current, settings: ScanSettings = .current) -> [String] {
        let time = DateFormatter()
        time.dateFormat = "MMM d HH:mm"
        time.timeZone = zone
        let album = outcome.album, parsed = outcome.parsed
        var out = ["  \u{201C}\(album.title)\u{201D}: \(album.count) photos, \(inDay) of them from this day"]
        if GameSuggester.isAppAlbum(album.title, settings: settings) {
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
        if outcome.outings.isEmpty { out.append("    no run of \(settings.suggestMinPhotos)+ dated photos to look up") }
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
                line += "no game between these teams on any of their schedules then (\(Int(settings.matchupWindowHours)) h either side)"
            }
            out.append(line)
        }
        return out
    }

    /// The photos with no location: how many, by hour, each stretch of them, where the located photos around it say the fan
    /// was, and the stadiums whose schedules that city's day asks. `day` is the phone's calendar day; `points` reach twelve
    /// hours either side, for the evening before and the next morning.
    static func cityLines(points: [PhotoPoint], day: Range<Date>, venues: [Venue], taken: Set<String>, existing: [GameEntry],
                          zone: TimeZone = .current, settings: ScanSettings = .current) -> [String] {
        let located = CityDays.located(points)
        let big = CityDays.bigGrounds(venues, settings: settings)
        let runs = CityDays.runs(points, taken: taken, settings: settings).filter { r in r.contains { day.contains($0.date!) } }
        let verdicts = runs.map { CityDays.judge($0, located: located, grounds: big, existing: existing, settings: settings) }
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
                line += verdict.why(settings) + " (" + anchors.map { spot($0, span) }.joined(separator: ", ") + ")"
            default:
                line += verdict.why(settings)
            }
            out.append(line)
        }
        return out
    }

    /// What a city day's schedules and photos said, and whether the review shows it.
    static func cityLines(_ eval: CityDays.Evaluation, offered: (PossibleDay) -> Bool, settings: ScanSettings = .current) -> [String] {
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
                       + "window \(time.string(from: k.addingTimeInterval(-settings.cityBeforeMinutes * 60)))\u{2013}\(time.string(from: k.addingTimeInterval(settings.cityAfterMinutes * 60))), "
                       + (fit.photos.isEmpty ? "no stay in it (\(settings.cityPhotos)+ photos over \(Int(settings.citySpanMinutes))+ min)" : "\(fit.photos.count) photos in it"))
        }
        if let look = eval.look {
            out.append("    scene check of the window's photos: \(look.classified) classified, \(look.venue) stadium or sport, \(look.structure) the ground itself, "
                       + "\(look.elsewhere) somewhere else \u{2192} looks like a stadium: \(CityDays.looksLikeTheGround(look, settings: settings) ? "yes" : "no") "
                       + "(needs \(settings.cityMinVenue)+ stadium or sport and \(Int(settings.cityVenueShare * 100))%+, \(settings.cityMinStructure)+ the ground, "
                       + "under \(Int(settings.cityElsewhereShare * 100))% somewhere else)")
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

    /// Whether a visit with no game is offered as a stadium visit (a tour), and why.
    static func visitLine(_ visit: PhotoCluster, settings: ScanSettings = .current) -> String {
        "stadium visit: \(visit.anchors.count) photos inside the fence over \(Int(visit.insideSpan / 60)) min \u{2014} "
            + (visit.isStadiumVisit(settings) ? "offered" : "fewer than \(settings.dwellPhotos) or under \(Int(settings.dwellMinutes)) min, dropped")
    }

    /// The header's settings line ("settings v1 (built-in)") and one line per value that differs from the built-in defaults.
    static func settingsLines(_ settings: ScanSettings = .current, source: ScanSettings.Source = ScanSettings.source) -> [String] {
        ["Settings: v\(settings.version) (\(source.rawValue))"] + settings.differences().map { "  changed: \($0)" }
    }

    /// The whole report for the phone's calendar day holding `day`, with each visit's schedule lookups.
    @MainActor
    static func report(day: Date, library: Library, scan: ScanModel? = nil) async -> String {
        let settings = ScanSettings.current
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
        var out = ["Witness scan check \u{00B7} \(stamp.string(from: start)) \u{00B7} \(TimeZone.current.identifier) \u{00B7} app \(version) (\(build))"
                   + " \u{00B7} settings v\(settings.version) (\(ScanSettings.source.rawValue))",
                   "Photo access: \(PhotoMatcher.accessDescription) \u{00B7} catalog stadiums: \(venues.count) \u{00B7} background search declined: \(UserDefaults.standard.bool(forKey: "deepScanDeclined") ? "yes" : "no")"]
        out += settingsLines(settings).dropFirst()
        if let scan {
            out.append("Scan now: \(scan.state) \u{00B7} reviewed: \(scan.reviewed ? "yes" : "no") \u{00B7} background search: \(scan.deepState)"
                       + " \u{00B7} waiting for review: \(scan.games.count) games, \(scan.others.count) visits, \(scan.possible.count) possible")
            if let line = PhotoAccess.uncheckedLine(scan.uncheckedVisits) { out.append("Last scan: " + line) }
        }
        out += lines(points: points, venues: venues, saved: saved, settings: settings)
        let ledger = scan?.ledger ?? ReviewLedger.load(from: ScanModel.ledgerURL)
        out += gates(points: points, venues: venues, library: library.games, ledger: ledger, pending: scan?.pendingVisits ?? [], settings: settings)

        // The schedule for every visit an album would make (the scan's visits are among them): the stadium, then next door.
        let visits = VisitGrouping.group(points, venues: venues, settings: settings).visits
        out.append("")
        out.append("Schedules (each visit's photo times, from \(Int(settings.scheduleBeforeHours)) hours before the first to \(Int(settings.scheduleAfterHours)) after the last):")
        if visits.isEmpty { out.append("  no visit to look up") }
        for visit in visits {
            out.append("  \(visit.venue.name):")
            for venue in [visit.venue] + PhotoMatcher.neighbors(of: visit.venue, in: venues, settings: settings) {
                let leagues = GameLookup.leagues(for: venue)
                let games = await GameLookup.games(at: venue, from: visit.start, to: visit.end, settings: settings)
                let found = games.isEmpty ? "no game" : games.map { g in
                    "\(g.away.name) at \(g.home.name), \(DateFormatter.localizedString(from: g.start, dateStyle: .none, timeStyle: .short)) (\(g.league) \(g.eventId))"
                }.joined(separator: "; ")
                out.append("    \(venue.id == visit.venue.id ? "" : "next door: ")\(venue.name) [\(leagues.count) competitions: \(leagues.joined(separator: ", "))] \u{2192} \(found)")
            }
            let looked = await ScanModel.lookup(visit, venues: venues, settings: settings)
            out.append("    scan match: \(looked.game.map { "\($0.away.name) at \($0.home.name) (\($0.league) \($0.eventId))" } ?? (looked.complete ? "none" : "could not be checked (no connection or the schedule did not answer): connect and run Find in photos again"))")
        }
        // The albums holding the day's photos: a title naming the game finds it with no located photo.
        let albums = await Task.detached(priority: .userInitiated) { AlbumImporter.albums(containing: points.map(\.id)) }.value
        out.append("")
        out.append("Albums with this day's photos (a title naming two teams asks their schedules for a game while the photos were taken):")
        if albums.isEmpty { out.append("  none") }
        let reader = MatchupAlbums.Reader(teams: library.allTeams, settings: settings)
        for (album, inDay) in albums.prefix(12) {
            let parsed = reader.parse(album.title)
            let albumPoints = parsed.isMatchup ? await Task.detached { AlbumImporter.points(in: album) }.value : []
            let outcome = await MatchupAlbums.check(album, points: albumPoints, parsed: parsed, venues: venues, existing: library.games, settings: settings)
            out += albumLines(outcome, inDay: inDay, venues: venues, offered: {
                !ReviewQueue.possible([$0], alongside: [], library: library.games, ledger: ledger).isEmpty
            }, settings: settings)
        }

        // Photos with no location: the located photos around them (the evening before, the next morning) say which city.
        let reach = settings.cityAnchorHours * 3600
        let wide = await PhotoMatcher.points(from: start.addingTimeInterval(-reach), to: end.addingTimeInterval(reach))
        let wideScan = PhotoMatcher.found(in: wide, venues: venues, existing: library.games, settings: settings)
        let taken = Set(wideScan.visits.flatMap(\.assetIds) + wideScan.nearby.flatMap(\.assetIds))
        out += cityLines(points: wide, day: start..<end, venues: venues, taken: taken, existing: library.games, settings: settings)
        for day in wideScan.cityDays where day.end >= start && day.start < end {
            let eval = await CityDays.evaluate(day, look: { await SceneCheck.look(at: $0, max: settings.citySample, settings: settings) }, settings: settings)
            out += cityLines(eval, offered: { !ReviewQueue.possible([$0], alongside: [], library: library.games, ledger: ledger).isEmpty }, settings: settings)
        }

        // What the scan itself makes of the day, with the library's saved games and the skips: what the review would show.
        let scanned = PhotoMatcher.found(in: points, venues: venues, existing: library.games, settings: settings)
        out.append("")
        out.append("Review (what Find in photos would offer for this day):")
        if scanned.visits.isEmpty && scanned.nearby.isEmpty { out.append("  nothing: no visit and no day around a stadium") }
        // What the scan would have made of the day had no photo been on the move.
        let grounded = VisitGrouping.group(points, venues: venues, minimumStay: settings.visitStayMinutes * 60,
                                           skipping: PhotoMatcher.settledKeys(library.games, venues: venues), moving: [:], settings: settings).visits
        for visit in grounded where !scanned.visits.contains(where: { $0.id == visit.id }) {
            out.append("  \(visit.venue.name): dropped, every photo inside its fence was on the move (see each photo above)")
        }
        for visit in scanned.visits {
            let looked = await ScanModel.lookup(visit, venues: venues, settings: settings)
            if let game = looked.game {
                out.append("  \(visit.venue.name): \(game.away.name) at \(game.home.name) \u{2192} "
                           + verdict(visit, library: library.games, venues: venues, ledger: ledger))
            } else if !looked.complete {
                out.append("  \(visit.venue.name): could not be checked, no game judged \u{2192} connect and run Find in photos again")
            } else {
                out.append("  \(visit.venue.name): no game on the schedule \u{2192} " + visitLine(visit, settings: settings))
            }
        }
        for day in scanned.nearby {
            let offer = await ScanModel.nearbyDay(day, venues: venues, settings: settings)
            let shown = offer.map { !ReviewQueue.possible([$0], alongside: [], library: library.games, ledger: ledger).isEmpty } ?? false
            out.append("  around \(day.venue.name): " + (offer.map { "\($0.reason) \u{2192} " + (shown ? "offered as a possible game" : "left out: already added or skipped") }
                                                         ?? "no game on the schedule while the photos were taken"))
        }
        return out.joined(separator: "\n")
    }
}
