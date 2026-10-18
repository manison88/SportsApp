import Foundation
import Photos
import CoreLocation

/// A run of photos taken inside one stadium on one day: probably a game.
struct PhotoCluster: Identifiable, Hashable {
    let id: String
    let venue: Venue
    let start: Date
    let end: Date
    let assetIds: [String]
    let times: [Date]
}

/// Finds games in the photo library from each photo's time and place. On-device only.
enum PhotoMatcher {
    /// Whether photo access is already granted (full or limited), without asking.
    static var hasAccess: Bool {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return s == .authorized || s == .limited
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
    private static func locatedAssets(from: Date? = nil, to: Date? = nil) -> [Located] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if let from, let to {
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", from as NSDate, to as NSDate)
        }
        let result = PHAsset.fetchAssets(with: .image, options: options)
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

    /// Other venues close enough that the same photos could belong to them.
    static func neighbors(of venue: Venue, in venues: [Venue], within radius: CLLocationDistance = 400) -> [Venue] {
        venues.filter { $0.id != venue.id && $0.location.distance(from: venue.location) <= radius }
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

    /// Finds visits in the whole library, newest first. Photos near a stadium on a visit's day count toward it
    /// (see `VisitGrouping.matchdayReach`), and a visit needs a 15-minute stay inside the fence.
    /// `progress` is called about every thousand photos, from a background thread.
    static func discover(venues: [Venue], existing: [GameEntry], radius: CLLocationDistance? = nil,
                         progress: (@Sendable (ScanProgress) -> Void)? = nil) async -> [PhotoCluster] {
        let existingKeys: Set<String> = Set(existing.compactMap { g -> String? in
            guard let v = venues.first(where: { $0.id == g.venueId }) else { return nil }
            return VisitGrouping.key(venueId: v.id, date: g.date, tz: v.tz)
        })
        return await Task.detached(priority: .userInitiated) { () -> [PhotoCluster] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let result = PHAsset.fetchAssets(with: .image, options: options)
            let index = VenueIndex(venues)
            var state = ScanProgress(total: result.count)
            var tallyAt: [String: Int] = [:]
            var visitKeys = Set<String>()
            var days = DayKeyer()
            var points: [PhotoPoint] = []
            points.reserveCapacity(result.count)
            result.enumerateObjects { asset, i, _ in
                let loc = asset.location
                points.append(PhotoPoint(id: asset.localIdentifier, date: asset.creationDate,
                                         latitude: loc?.coordinate.latitude, longitude: loc?.coordinate.longitude))
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
                        }
                        state.recentIds.insert(asset.localIdentifier, at: 0)
                        if state.recentIds.count > 5 { state.recentIds.removeLast() }
                    }
                }
                if i % 1000 == 999 {
                    state.scanned = i + 1
                    state.date = asset.creationDate
                    progress?(state)
                }
            }
            state.scanned = result.count
            progress?(state)
            return VisitGrouping.group(points, venues: venues, radius: radius, minimumStay: 15 * 60, skipping: existingKeys)
                .visits.sorted { $0.start > $1.start }
        }.value
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

    /// Where a game's own photos were taken: the first of them that carries a location.
    static func location(ofPhotos ids: [String]) async -> CLLocation? {
        guard hasAccess, !ids.isEmpty else { return nil }
        let some = Array(ids.prefix(24))
        return await Task.detached(priority: .utility) { () -> CLLocation? in
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: some, options: nil)
            var found: CLLocation?
            assets.enumerateObjects { asset, _, stop in
                if let l = asset.location { found = l; stop.pointee = true }
            }
            return found
        }.value
    }

    /// A drive-by snapshot isn't a game: ask for at least two photos taken
    /// at least 15 minutes apart, the shortest plausible stay in the stands.
    static func looksLikeAGame(_ times: [Date], minimumStay: TimeInterval = 15 * 60) -> Bool {
        guard times.count >= 2, let first = times.min(), let last = times.max() else { return false }
        return last.timeIntervalSince(first) >= minimumStay
    }

    /// "wrigley|2016-10-30", the venue's local calendar day.
    static func key(venueId: String, date: Date, tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%@|%04d-%02d-%02d", venueId, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
