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

    /// The nearest venue whose geofence holds the point. A cheap lat/lon box runs before the true distance,
    /// and nearest wins because stadiums often have an arena next door (Michigan Stadium and Crisler, 180 m).
    private static func venue(for p: Located, in venues: [Venue], radius: CLLocationDistance) -> Venue? {
        let dLat = radius / 111_000
        let here = CLLocation(latitude: p.lat, longitude: p.lon)
        var best: (Venue, CLLocationDistance)?
        for v in venues {
            guard abs(v.latitude - p.lat) <= dLat else { continue }
            let dLon = dLat / max(0.1, cos(v.latitude * .pi / 180))
            guard abs(v.longitude - p.lon) <= dLon else { continue }
            let d = here.distance(from: v.location)
            if d <= radius, d < (best?.1 ?? .infinity) { best = (v, d) }
        }
        return best?.0
    }

    /// Other venues close enough that the same photos could belong to them.
    static func neighbors(of venue: Venue, in venues: [Venue], within radius: CLLocationDistance = 600) -> [Venue] {
        venues.filter { $0.id != venue.id && $0.location.distance(from: venue.location) <= radius }
            .sorted { $0.location.distance(from: venue.location) < $1.location.distance(from: venue.location) }
    }

    static func discover(venues: [Venue], existing: [GameEntry], radius: CLLocationDistance = 600) async -> [PhotoCluster] {
        let existingKeys: Set<String> = Set(existing.compactMap { g -> String? in
            guard let v = venues.first(where: { $0.id == g.venueId }) else { return nil }
            return key(venueId: v.id, date: g.date, tz: v.tz)
        })
        return await Task.detached(priority: .userInitiated) { () -> [PhotoCluster] in
            let assets = locatedAssets()
            var groups: [String: (Venue, [Located])] = [:]
            for a in assets {
                guard let v = venue(for: a, in: venues, radius: radius) else { continue }
                let k = key(venueId: v.id, date: a.date, tz: v.tz)
                if existingKeys.contains(k) { continue }
                var entry = groups[k] ?? (v, [])
                entry.1.append(a)
                groups[k] = entry
            }
            return groups.compactMap { k, value -> PhotoCluster? in
                let sorted = value.1.sorted { $0.date < $1.date }
                guard looksLikeAGame(sorted.map(\.date)) else { return nil }
                return PhotoCluster(id: k, venue: value.0, start: sorted.first!.date, end: sorted.last!.date,
                                    assetIds: sorted.map(\.id), times: sorted.map(\.date))
            }
            .sorted { $0.start > $1.start }
        }.value
    }

    static func photos(at venue: Venue, around date: Date, hours: Double = 6, radius: CLLocationDistance = 800) async -> [String] {
        let from = date.addingTimeInterval(-hours * 3600 / 2)
        let to = date.addingTimeInterval(hours * 3600)
        return await Task.detached(priority: .userInitiated) { () -> [String] in
            locatedAssets(from: from, to: to)
                .filter { self.venue(for: $0, in: [venue], radius: radius) != nil }
                .map(\.id)
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
