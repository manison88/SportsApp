import Foundation
import CoreLocation

/// One photo's time and place, as far as we know them.
struct PhotoPoint: Hashable, Sendable {
    let id: String
    let date: Date?
    let latitude: Double?
    let longitude: Double?
}

/// Photos from one day that we couldn't place at a stadium (no GPS, or GPS nowhere near one).
struct DayPile: Identifiable, Hashable {
    let id: String          // "2015-06-15"
    let day: Date
    let assetIds: [String]
    let times: [Date]
}

/// What a set of photos says: stadium visits, days we need a stadium for, and photos with no date at all.
struct PhotoScan: Hashable {
    var visits: [PhotoCluster] = []
    var unplacedDays: [DayPile] = []
    var undated: [String] = []
}

/// Groups photos into stadium visits. Pure, so it's shared by library discovery and album import and unit tested.
enum VisitGrouping {
    /// Photos this close to a stadium on a visit's day belong to the visit (the pub, the tailgate, the walk in).
    /// They can't start a visit: only photos inside the venue's own fence do.
    static let matchdayReach: CLLocationDistance = 500

    /// - minimumStay: required spread of a visit's photos inside the fence (library discovery uses 15 min to
    ///   skip drive-bys; an album the fan chose is trusted, so it passes nil).
    /// - skipping: "venueId|yyyy-MM-dd" keys of games already in the library.
    static func group(_ points: [PhotoPoint], venues: [Venue], radius: CLLocationDistance? = nil,
                      minimumStay: TimeInterval? = nil, skipping: Set<String> = []) -> PhotoScan {
        var scan = PhotoScan()
        var visits: [String: (Venue, [(String, Date)])] = [:]
        var loose: [(String, Date)] = []
        var around: [(String, Date, Venue)] = []
        var joined: [String: [(String, Date)]] = [:]

        for p in points {
            guard let date = p.date else { scan.undated.append(p.id); continue }
            if let lat = p.latitude, let lon = p.longitude, let v = nearestVenue(lat: lat, lon: lon, in: venues, radius: radius) {
                let k = key(venueId: v.id, date: date, tz: v.tz)
                if skipping.contains(k) { continue }
                var entry = visits[k] ?? (v, [])
                entry.1.append((p.id, date))
                visits[k] = entry
            } else if let lat = p.latitude, let lon = p.longitude,
                      let v = nearestVenue(lat: lat, lon: lon, in: venues, radius: matchdayReach) {
                around.append((p.id, date, v))
            } else {
                loose.append((p.id, date))
            }
        }

        // Within 500 m on a visit's day: part of the visit. With no visit that day, they wait like any other photo.
        for (id, date, v) in around {
            let k = key(venueId: v.id, date: date, tz: v.tz)
            if visits[k] != nil { joined[k, default: []].append((id, date)) } else { loose.append((id, date)) }
        }

        // Photos without a stadium fix that were taken on a visit's day belong to that visit (edited copies,
        // a friend's shared photos, location switched off). The rest wait for the fan to tell us where.
        var byDay: [String: [(String, Date)]] = [:]
        for (id, date) in loose {
            if let k = visits.keys.first(where: { k in
                let v = visits[k]!.0
                return k == key(venueId: v.id, date: date, tz: v.tz)
            }) {
                visits[k]!.1.append((id, date))
            } else {
                byDay[dayString(date, tz: .current), default: []].append((id, date))
            }
        }

        scan.visits = visits.compactMap { k, value -> PhotoCluster? in
            let anchors = value.1.sorted { $0.1 < $1.1 }
            if let minimumStay {
                guard anchors.count >= 2, anchors.last!.1.timeIntervalSince(anchors.first!.1) >= minimumStay else { return nil }
            }
            let sorted = (value.1 + (joined[k] ?? [])).sorted { $0.1 < $1.1 }
            return PhotoCluster(id: k, venue: value.0, start: sorted.first!.1, end: sorted.last!.1,
                                assetIds: sorted.map(\.0), times: sorted.map(\.1))
        }
        .sorted { $0.start < $1.start }

        scan.unplacedDays = byDay.map { day, items in
            let sorted = items.sorted { $0.1 < $1.1 }
            return DayPile(id: day, day: sorted.first!.1, assetIds: sorted.map(\.0), times: sorted.map(\.1))
        }
        .sorted { $0.day < $1.day }
        return scan
    }

    /// The nearest venue whose geofence holds the point (each venue's own `geofence`, unless `radius` overrides it).
    /// A cheap lat/lon box runs before the true distance, and nearest wins because stadiums often have an arena
    /// next door (Michigan Stadium and Crisler, 180 m).
    static func nearestVenue(lat: Double, lon: Double, in venues: [Venue], radius: CLLocationDistance? = nil) -> Venue? {
        let box = radius ?? 320
        let dLat = box / 111_000
        let here = CLLocation(latitude: lat, longitude: lon)
        var best: (Venue, CLLocationDistance)?
        for v in venues {
            guard abs(v.latitude - lat) <= dLat else { continue }
            let dLon = dLat / max(0.1, cos(v.latitude * .pi / 180))
            guard abs(v.longitude - lon) <= dLon else { continue }
            let d = here.distance(from: v.location)
            if d <= (radius ?? v.geofence), d < (best?.1 ?? .infinity) { best = (v, d) }
        }
        return best?.0
    }

    /// "wrigley|2016-10-30", the venue's local calendar day.
    static func key(venueId: String, date: Date, tz: TimeZone) -> String {
        "\(venueId)|\(dayString(date, tz: tz))"
    }

    static func dayString(_ date: Date, tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
