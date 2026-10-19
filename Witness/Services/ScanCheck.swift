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
        out.append("Photos: \(points.count) (\(located.count) with a location, \(points.count - located.count) without)")

        let index = VenueIndex(venues)
        out.append("")
        out.append("Where each photo was placed (inside = the stadium's fence; near = within \(Int(VisitGrouping.matchdayReach)) m, joins a visit that day):")
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
            out.append("  \(p.date.map { time.string(from: $0) } ?? "--:--")  \(String(format: "%.5f,%.5f", lat, lon))  \(place)")
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

        let scan = VisitGrouping.group(points, venues: venues, minimumStay: 15 * 60, skipping: settled)
        let album = VisitGrouping.group(points, venues: venues)
        out.append("")
        out.append("Visits (scan rule: 2+ photos inside the fence, 15+ min apart):")
        if scan.visits.isEmpty { out.append("  none") }
        for v in scan.visits { out.append("  " + describe(v, time: time)) }
        let dropped = album.visits.filter { a in !scan.visits.contains { $0.id == a.id } }
        if !dropped.isEmpty {
            out.append("Visits only an album would make (the scan drops these: too short a stay inside the fence, or already saved):")
            for v in dropped { out.append("  " + describe(v, time: time)) }
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

    private static func describe(_ v: PhotoCluster, time: DateFormatter) -> String {
        "\(v.venue.name) [\(v.id)]: \(v.assetIds.count) photos, \(time.string(from: v.start))\u{2013}\(time.string(from: v.end))"
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
        // What the scan itself makes of the day, with the library's saved games and the skips: what the review would show.
        let scanned = PhotoMatcher.found(in: points, venues: venues, existing: library.games)
        out.append("")
        out.append("Review (what Find in photos would offer for this day):")
        if scanned.visits.isEmpty && scanned.nearby.isEmpty { out.append("  nothing: no visit and no day around a stadium") }
        for visit in scanned.visits {
            if let game = await ScanModel.match(visit, venues: venues) {
                out.append("  \(visit.venue.name): \(game.away.name) at \(game.home.name) \u{2192} "
                           + verdict(visit, library: library.games, venues: venues, ledger: ledger))
            } else {
                out.append("  \(visit.venue.name): no game on the schedule \u{2192} a stadium visit if a photo shows the ground, else waits for the background search")
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
