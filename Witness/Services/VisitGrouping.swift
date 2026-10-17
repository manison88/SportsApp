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

/// Local calendar day strings with one cached Calendar per time zone (building a Calendar per photo is the slow part
/// of grouping a large library).
struct DayKeyer {
    private var calendars: [String: Calendar] = [:]

    mutating func day(_ date: Date, tz: TimeZone) -> String {
        let cal: Calendar
        if let cached = calendars[tz.identifier] {
            cal = cached
        } else {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = tz
            calendars[tz.identifier] = c
            cal = c
        }
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// Venues bucketed into ~2 km cells, so a photo checks a handful of venues instead of all of them.
struct VenueIndex {
    private static let cell = 0.02
    private let cells: [Int: [Venue]]

    init(_ venues: [Venue]) {
        var cells: [Int: [Venue]] = [:]
        for v in venues { cells[Self.key(Self.index(v.latitude), Self.index(v.longitude)), default: []].append(v) }
        self.cells = cells
    }

    private static func index(_ degrees: Double) -> Int { Int((degrees / cell).rounded(.down)) }
    private static func key(_ i: Int, _ j: Int) -> Int { i * 20_000 + j }

    /// Same rule as `VisitGrouping.nearestVenue`: the nearest venue whose geofence (or `radius`) holds the point.
    func nearest(lat: Double, lon: Double, radius: CLLocationDistance? = nil) -> Venue? {
        let box = radius ?? 320
        let dLat = box / 111_000
        let here = CLLocation(latitude: lat, longitude: lon)
        let ci = Self.index(lat), cj = Self.index(lon)
        var best: (Venue, CLLocationDistance)?
        for di in -1...1 {
            for dj in -1...1 {
                for v in cells[Self.key(ci + di, cj + dj)] ?? [] {
                    guard abs(v.latitude - lat) <= dLat else { continue }
                    let dLon = dLat / max(0.1, cos(v.latitude * .pi / 180))
                    guard abs(v.longitude - lon) <= dLon else { continue }
                    let d = here.distance(from: v.location)
                    if d <= (radius ?? v.geofence), d < (best?.1 ?? .infinity) { best = (v, d) }
                }
            }
        }
        return best?.0
    }
}

/// Groups photos into stadium visits. Pure, so it's shared by library discovery and album import and unit tested.
enum VisitGrouping {
    /// Photos this close to a stadium on a visit's day belong to the visit (the pub, the tailgate, the walk in).
    /// They can't start a visit: only photos inside the venue's own fence do.
    static let matchdayReach: CLLocationDistance = 500

    /// A game that runs past midnight is photographed on two calendar days. Photos at one venue on consecutive
    /// local days, with no more than this between the last of the first day and the first of the next, are one visit.
    static let overnightGap: TimeInterval = 6 * 3600

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
        let index = VenueIndex(venues)
        var days = DayKeyer()

        for p in points {
            guard let date = p.date else { scan.undated.append(p.id); continue }
            guard let lat = p.latitude, let lon = p.longitude else { loose.append((p.id, date)); continue }
            if let v = index.nearest(lat: lat, lon: lon, radius: radius) {
                let k = "\(v.id)|\(days.day(date, tz: v.tz))"
                if skipping.contains(k) { continue }
                var entry = visits[k] ?? (v, [])
                entry.1.append((p.id, date))
                visits[k] = entry
            } else if let v = index.nearest(lat: lat, lon: lon, radius: matchdayReach) {
                around.append((p.id, date, v))
            } else {
                loose.append((p.id, date))
            }
        }

        // Join visits that straddle midnight (a night game, the walk home). The later day's key points at the earlier.
        var alias: [String: String] = [:]
        let byVenue = Dictionary(grouping: Array(visits.keys), by: { String($0.split(separator: "|").first ?? "") })
        for (venueId, keys) in byVenue where keys.count > 1 {
            let ordered = keys.sorted()
            var current = ordered[0]
            for next in ordered.dropFirst() {
                var merged = false
                if let a = visits[current], let b = visits[next], let after = dayAfter(current), next == "\(venueId)|\(after)",
                   let lastOfFirst = a.1.map({ $0.1 }).max(), let firstOfNext = b.1.map({ $0.1 }).min(),
                   firstOfNext.timeIntervalSince(lastOfFirst) <= overnightGap {
                    visits[current] = (a.0, a.1 + b.1)
                    visits[next] = nil
                    alias[next] = current
                    merged = true
                }
                if !merged { current = next }
            }
        }

        // Within 500 m on a visit's day: part of the visit. With no visit that day, they wait like any other photo.
        for (id, date, v) in around {
            let own = "\(v.id)|\(days.day(date, tz: v.tz))"
            let k = alias[own] ?? own
            if visits[k] != nil { joined[k, default: []].append((id, date)) } else { loose.append((id, date)) }
        }

        // Photos without a stadium fix that were taken on a visit's day belong to that visit (edited copies,
        // a friend's shared photos, location switched off). The rest wait for the fan to tell us where.
        // Visits are indexed by time zone and local day so each loose photo is one lookup per zone, not per visit.
        var visitByDay: [String: String] = [:]
        var zones: [String: TimeZone] = [:]
        for (k, value) in visits.sorted(by: { $0.key < $1.key }) {
            let tz = value.0.tz
            zones[tz.identifier] = tz
            let dayKey = "\(tz.identifier)|\(k.split(separator: "|").last ?? "")"
            if visitByDay[dayKey] == nil { visitByDay[dayKey] = k }
        }
        for (from, to) in alias {
            guard let tz = visits[to]?.0.tz else { continue }
            let dayKey = "\(tz.identifier)|\(from.split(separator: "|").last ?? "")"
            if visitByDay[dayKey] == nil { visitByDay[dayKey] = to }
        }
        var byDay: [String: [(String, Date)]] = [:]
        for (id, date) in loose {
            var home: String?
            for (zoneId, tz) in zones {
                if let k = visitByDay["\(zoneId)|\(days.day(date, tz: tz))"] { home = k; break }
            }
            if let home {
                visits[home]!.1.append((id, date))
            } else {
                byDay[days.day(date, tz: .current), default: []].append((id, date))
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

    /// The day after "venue|2016-10-30" (or "2016-10-30"), as "2016-10-31".
    private static func dayAfter(_ key: String) -> String? {
        let day = String(key.split(separator: "|").last ?? "")
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let utc = TimeZone(identifier: "UTC") else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        guard let start = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let next = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
        let c = cal.dateComponents([.year, .month, .day], from: next)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
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
