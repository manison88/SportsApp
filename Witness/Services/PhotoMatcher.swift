import Foundation
import Photos
import CoreLocation

/// A run of photos taken inside one stadium on one day: probably a game.
struct PhotoCluster: Identifiable, Hashable, Codable {
    let id: String
    let venue: Venue
    let start: Date
    let end: Date
    let assetIds: [String]
    let times: [Date]
    /// The photos inside the fence, not on the move: the ones that placed the visit. Nil for a visit built from an album, a
    /// ticket or a saved game, where every photo counts.
    var insideIds: [String]? = nil

    /// The photos the visit is judged by: the ones inside the fence, or all of them when that is not known.
    var anchors: [String] { insideIds ?? assetIds }

    /// How long the photos inside the fence span, first to last.
    var insideSpan: TimeInterval {
        let inside = insideIds.map(Set.init)
        let times = zip(assetIds, times).filter { inside?.contains($0.0) ?? true }.map(\.1)
        guard let first = times.min(), let last = times.max() else { return 0 }
        return last.timeIntervalSince(first)
    }

    /// A stadium visit with no game on the schedule (a tour, a walk round the ground) is offered when `dwellPhotos` photos inside
    /// the fence, none on the move, span `dwellMinutes` (two, however close: a photo inside the fence that was not taken on the
    /// move is a photo at the ground, and a wrong offer is one tap to skip). A plane over the ground is on the move; a drive past
    /// it leaves one photo, which can be a stray fix; a bar across the street is outside the fence.
    var isStadiumVisit: Bool { isStadiumVisit(ScanSettings.current) }
    func isStadiumVisit(_ settings: ScanSettings) -> Bool {
        anchors.count >= settings.dwellPhotos && insideSpan >= settings.dwellMinutes * 60
    }
}

/// Finds games in the photo library from each photo's time and place. On-device only.
enum PhotoMatcher {
    /// Whether photo access is already granted (full or limited), without asking.
    static var hasAccess: Bool {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return s == .authorized || s == .limited
    }

    /// "full", "limited" (only the photos the fan picked are seen) or "no", for the scan check.
    static var accessDescription: String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: "full"
        case .limited: "limited (only the photos picked in Settings are scanned)"
        default: "no"
        }
    }

    static func requestAccess() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized, .limited: return true
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return status == .authorized || status == .limited
        default: return false
        }
    }

    private struct Located: Sendable {
        let id: String
        let date: Date
        let lat: Double
        let lon: Double
    }

    /// Every image with both a capture date and a location, fetched once.
    private static func locatedAssets(from: Date? = nil, to: Date? = nil, mediaType: PHAssetMediaType = .image) -> [Located] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if let from, let to {
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", from as NSDate, to as NSDate)
        }
        let result = PHAsset.fetchAssets(with: mediaType, options: options)
        var out: [Located] = []
        out.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate, let loc = asset.location else { return }
            out.append(Located(id: asset.localIdentifier, date: date,
                               lat: loc.coordinate.latitude, lon: loc.coordinate.longitude))
        }
        return out
    }

    private static func venue(for p: Located, in venues: [Venue], radius: CLLocationDistance?) -> Venue? {
        VisitGrouping.nearestVenue(lat: p.lat, lon: p.lon, in: venues, radius: radius)
    }

    /// Other grounds close enough (`neighborMeters`, 1 km) that a fan's photos on the way in can land at either: Lumen Field and
    /// T-Mobile Park are 440 m apart, the United Center and its practice rinks closer still.
    static func neighbors(of venue: Venue, in venues: [Venue], within radius: CLLocationDistance? = nil,
                          settings: ScanSettings = .current) -> [Venue] {
        let radius = radius ?? settings.neighborMeters
        return venues.filter { $0.id != venue.id && $0.location.distance(from: venue.location) <= radius }
            .sorted { $0.location.distance(from: venue.location) < $1.location.distance(from: venue.location) }
    }

    /// How far a library scan has got, for the waiting screen. Every number is real.
    struct ScanProgress: Sendable, Equatable {
        var scanned = 0
        var total = 0
        /// Photos that carry a location.
        var located = 0
        /// Photos inside a stadium's fence so far.
        var atStadiums = 0
        /// The stadium of the most recent such photo.
        var latestVenue: String?
        /// The date of the photo being read (the scan runs newest to oldest).
        var date: Date?
        /// Stadiums found so far, in the order they turned up, with how many photos each holds.
        var venues: [VenueTally] = []
        /// Distinct stadium visits (a stadium on a day) seen so far.
        var visits = 0
        /// The last few photos taken inside a stadium's fence, newest first.
        var recentIds: [String] = []
    }

    struct VenueTally: Sendable, Equatable, Identifiable {
        let id: String
        let name: String
        let sport: Sport?
        var count: Int
    }

    /// What a library scan found: stadium visits, and days spent just outside a stadium's fence.
    struct Found: Sendable {
        /// Photos inside a stadium's fence, newest first.
        var visits: [PhotoCluster] = []
        /// Photos only around a stadium (the plaza, the car park, the march in), never inside its fence, newest first. A World
        /// Cup crowd photographs the day outside and the phone may place few photos, or none, inside the bowl. Only ever a
        /// possible game, when the schedule has one there.
        var nearby: [PhotoCluster] = []
        /// Stretches of photos with no location on a day the located ones place in a city with big stadiums, newest first.
        /// Only ever a possible game, when the city's schedule had one then and the photos look like a stadium.
        var cityDays: [CityDay] = []
    }

    /// The pure part of `discover`: visits from photos inside a fence (the `visitStayMinutes` stay), then the days spent just
    /// outside one: within `nearbyReachMeters` (600 m: the plaza and car parks, and the fan march; Occidental Park is 540 m
    /// from Lumen Field), `nearbyPhotos` or more, at most `nearbyMaxDays` newest first (someone who lives next to a stadium has
    /// hundreds). Photos on the move (a landing over the ground, the motorway past it) place neither.
    static func found(in points: [PhotoPoint], venues: [Venue], existing: [GameEntry], radius: CLLocationDistance? = nil,
                      settings: ScanSettings = .current) -> Found {
        let skipping = settledKeys(existing, venues: venues)
        let moving = TransitCheck.moving(points, settings: settings)
        let stay = settings.visitStayMinutes * 60
        let visits = VisitGrouping.group(points, venues: venues, radius: radius, minimumStay: stay, skipping: skipping,
                                         moving: moving, settings: settings).visits
        let inVisits = Set(visits.flatMap(\.assetIds))
        let outside = points.filter { $0.latitude != nil && $0.longitude != nil && !inVisits.contains($0.id) }
        var keyer = DayKeyer()
        let nearby = VisitGrouping.group(outside, venues: venues, radius: max(radius ?? 0, settings.nearbyReachMeters), minimumStay: stay,
                                         moving: moving, settings: settings).visits
            .filter { day in
                // Only the photos placed near the ground count: ones with no location or far away come with the day, they do not make it.
                guard (day.insideIds?.count ?? 0) >= settings.nearbyPhotos else { return false }
                let key = keyer.day(day.start, tz: day.venue.tz)
                // A visit (or a saved game) at this ground or next door that day already holds the day.
                let near = [day.venue] + neighbors(of: day.venue, in: venues, settings: settings)
                return !near.contains { v in
                    skipping.contains("\(v.id)|\(key)") || visits.contains { $0.venue.id == v.id && keyer.day($0.start, tz: v.tz) == key }
                }
            }
        let kept = Array(nearby.sorted { $0.start > $1.start }.prefix(settings.nearbyMaxDays))
        let taken = Set(visits.flatMap(\.assetIds) + kept.flatMap(\.assetIds))
        return Found(visits: visits.sorted { $0.start > $1.start }, nearby: kept,
                     cityDays: CityDays.candidates(points, venues: venues, taken: taken, existing: existing, settings: settings))
    }

    /// Finds visits in the whole library, newest first. Photos near a stadium on a visit's day count toward it
    /// (`matchdayReachMeters`), and a visit needs a `visitStayMinutes` stay inside the fence.
    /// `progress` is called about every `progressEveryPhotos` photos, from a background thread.
    static func discover(venues: [Venue], existing: [GameEntry], radius: CLLocationDistance? = nil,
                         progress: (@Sendable (ScanProgress) -> Void)? = nil) async -> Found {
        let settings = ScanSettings.current
        return await Task.detached(priority: .userInitiated) { () -> Found in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let result = PHAsset.fetchAssets(with: .image, options: options)
            let index = VenueIndex(venues, settings: settings)
            var state = ScanProgress(total: result.count)
            var tallyAt: [String: Int] = [:]
            var visitKeys = Set<String>()
            var days = DayKeyer()
            var points: [PhotoPoint] = []
            points.reserveCapacity(result.count)
            result.enumerateObjects { asset, i, _ in
                let loc = asset.location
                points.append(PhotoPoint(id: asset.localIdentifier, date: asset.creationDate,
                                         latitude: loc?.coordinate.latitude, longitude: loc?.coordinate.longitude,
                                         screenshot: asset.mediaSubtypes.contains(.photoScreenshot), speed: loc.flatMap(PhotoPoint.speed)))
                if let loc {
                    state.located += 1
                    if let v = index.nearest(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude, radius: radius) {
                        state.atStadiums += 1
                        state.latestVenue = v.name
                        if let at = tallyAt[v.id] {
                            state.venues[at].count += 1
                        } else {
                            tallyAt[v.id] = state.venues.count
                            state.venues.append(VenueTally(id: v.id, name: v.name, sport: v.sports.first, count: 1))
                        }
                        if let when = asset.creationDate, visitKeys.insert("\(v.id)|\(days.day(when, tz: v.tz))").inserted {
                            state.visits += 1
                            // One photo per visit, so the strip on the scan screen shows many games, not one game many times.
                            state.recentIds.insert(asset.localIdentifier, at: 0)
                            if state.recentIds.count > settings.progressRecentPhotos { state.recentIds.removeLast() }
                        }
                    }
                }
                if i % settings.progressEveryPhotos == settings.progressEveryPhotos - 1 {
                    state.scanned = i + 1
                    state.date = asset.creationDate
                    progress?(state)
                }
            }
            state.scanned = result.count
            progress?(state)
            return found(in: points, venues: venues, existing: existing, radius: radius, settings: settings)
        }.value
    }

    /// "venue|day" keys of the saved games a scan leaves alone. A stadium visit is not settled: it was saved because no game
    /// turned up that day (perhaps by a scan that did not look next door, or a lookup that failed), so its photos are checked
    /// again, and a game found for them replaces the visit. The same goes for a game card saved from photos with no teams and
    /// no schedule match (confirmed before its lookup came back).
    static func settledKeys(_ existing: [GameEntry], venues: [Venue]) -> Set<String> {
        Set(existing.compactMap { g -> String? in
            guard !g.awaitsGame, let v = venues.first(where: { $0.id == g.venueId }) else { return nil }
            return VisitGrouping.key(venueId: v.id, date: g.date, tz: v.tz)
        })
    }

    /// "venue|day" keys of saved stadium visits (and game cards with no game): checked again for a game, but not offered again as visits.
    static func savedVisitKeys(_ existing: [GameEntry], venues: [Venue]) -> Set<String> {
        Set(existing.compactMap { g -> String? in
            guard g.isVisit || g.awaitsGame, let v = venues.first(where: { $0.id == g.venueId }) else { return nil }
            return VisitGrouping.key(venueId: v.id, date: g.date, tz: v.tz)
        })
    }

    static func photos(at venue: Venue, around date: Date, hours: Double = 6, radius: CLLocationDistance? = nil) async -> [String] {
        let from = date.addingTimeInterval(-hours * 3600 / 2)
        let to = date.addingTimeInterval(hours * 3600)
        return await Task.detached(priority: .userInitiated) { () -> [String] in
            locatedAssets(from: from, to: to)
                .filter { self.venue(for: $0, in: [venue], radius: radius) != nil }
                .map(\.id)
        }.value
    }

    /// Every photo taken in the window, with its place when it has one, oldest first (for the scan check).
    static func points(from: Date, to: Date) async -> [PhotoPoint] {
        await Task.detached(priority: .userInitiated) { () -> [PhotoPoint] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", from as NSDate, to as NSDate)
            var out: [PhotoPoint] = []
            PHAsset.fetchAssets(with: .image, options: options).enumerateObjects { asset, _, _ in
                let loc = asset.location
                out.append(PhotoPoint(id: asset.localIdentifier, date: asset.creationDate,
                                      latitude: loc?.coordinate.latitude, longitude: loc?.coordinate.longitude,
                                      screenshot: asset.mediaSubtypes.contains(.photoScreenshot), speed: loc.flatMap(PhotoPoint.speed)))
            }
            return out
        }.value
    }

    /// Videos shot at the venue around the game's start.
    static func videos(at venue: Venue, around date: Date, hours: Double = 6) async -> [String] {
        let from = date.addingTimeInterval(-hours * 3600 / 2)
        let to = date.addingTimeInterval(hours * 3600)
        return await Task.detached(priority: .utility) { () -> [String] in
            locatedAssets(from: from, to: to, mediaType: .video)
                .filter { self.venue(for: $0, in: [venue], radius: nil) != nil }
                .map(\.id)
        }.value
    }

    /// Where a game's own photos were taken: the first of them that carries a location.
    static func location(ofPhotos ids: [String]) async -> CLLocation? {
        guard hasAccess, !ids.isEmpty else { return nil }
        let some = Array(ids.prefix(ScanSettings.current.photoLocationSample))
        return await Task.detached(priority: .utility) { () -> CLLocation? in
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: some, options: nil)
            var found: CLLocation?
            assets.enumerateObjects { asset, _, stop in
                if let l = asset.location { found = l; stop.pointee = true }
            }
            return found
        }.value
    }

    /// A drive-by snapshot isn't a game: ask for at least two photos, taken at least `visitStayMinutes` apart (0 by default:
    /// two photos at the ground are enough).
    static func looksLikeAGame(_ times: [Date], minimumStay: TimeInterval? = nil, settings: ScanSettings = .current) -> Bool {
        guard times.count >= 2, let first = times.min(), let last = times.max() else { return false }
        return last.timeIntervalSince(first) >= (minimumStay ?? settings.visitStayMinutes * 60)
    }

    /// "wrigley|2016-10-30", the venue's local calendar day.
    static func key(venueId: String, date: Date, tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%@|%04d-%02d-%02d", venueId, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
