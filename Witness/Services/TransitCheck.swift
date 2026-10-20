import Foundation
import CoreLocation

/// Tells photos taken from a plane, a train or a car from photos taken on foot, by each photo's altitude and by how far the
/// phone moved between shots. The approach to Heathrow from the east crosses Stamford Bridge at 1,000 m, and the phone's fix
/// put the window shots inside the ground's fence: a photo in the air, or on the move, never places a stadium visit. Pure.
enum TransitCheck {
    /// A photo this far above the lowest located photo nearby is in the air. Relative, not absolute: Coors Field sits at
    /// 1,600 m and Estadio Azteca at 2,200 m, and the catalog has no altitude for a ground.
    static let climb: Double = 250
    /// "Nearby": the same or a neighbouring cell of this many degrees (33 km of latitude), so the floor is the airport, the
    /// hotel or the street, roughly 30 to 60 km around. One pass over the library, however big.
    static let cell = 0.3
    /// The fix's own speed, when the phone recorded one: a car on the motorway does 40 m/s at most, so above it is a plane.
    static let vehicleSpeed: Double = 40
    /// Two located photos at least a kilometre apart and this fast between them (20 m/s, 72 km/h: a motorway, a train, a plane
    /// on approach at 70 m/s; never the walk to the gate) were taken on the move. A kilometre, so a fix that jumps inside a
    /// full bowl does not count; five minutes, so the drive to the ground and the photo in the stands an hour later do not pair.
    static let movingSpeed: Double = 20
    static let movingDistance: CLLocationDistance = 1_000
    static let movingWindow: TimeInterval = 5 * 60

    enum Verdict: Equatable, Sendable {
        case ground
        /// Metres above the lowest located photo nearby.
        case airborne(above: Double)
        /// Metres per second, from the fix or between this photo and the one before or after it.
        case moving(speed: Double)

        var placesAVisit: Bool { self == .ground }

        /// For the scan check.
        var text: String {
            switch self {
            case .ground: "on the ground"
            case .airborne(let above): "in the air, \(Int(above)) m above the lowest photo nearby (limit \(Int(TransitCheck.climb)) m)"
            case .moving(let speed): "on the move, \(Int(speed)) m/s (limit \(Int(TransitCheck.movingSpeed)) m/s over \(Int(TransitCheck.movingDistance / 1000)) km)"
            }
        }
    }

    /// Every dated, located photo that was in the air or on the move, by id. Photos not in the result are on the ground (or
    /// say nothing: no date, no location).
    static func verdicts(_ points: [PhotoPoint]) -> [String: Verdict] {
        let located = points.filter { $0.date != nil && $0.latitude != nil && $0.longitude != nil }
        var out: [String: Verdict] = [:]

        // The floor under each cell: the lowest photo in it. A photo is in the air when it is well above the floor of its own
        // cell or a neighbour's, so a town at 1,600 m keeps its ballpark on the ground.
        var floors: [Int: Double] = [:]
        for p in located {
            guard let altitude = p.altitude else { continue }
            let k = key(p)
            floors[k] = min(floors[k] ?? .infinity, altitude)
        }
        for p in located {
            guard let altitude = p.altitude else { continue }
            let (i, j) = cell(p)
            var floor = altitude
            for di in -1...1 {
                for dj in -1...1 {
                    if let f = floors[key(i + di, j + dj)] { floor = min(floor, f) }
                }
            }
            if altitude - floor > climb { out[p.id] = .airborne(above: altitude - floor) }
        }

        for p in located where out[p.id] == nil {
            if let speed = p.speed, speed > vehicleSpeed { out[p.id] = .moving(speed: speed) }
        }

        // On the move: consecutive located photos far apart in little time. Both ends of such a pair were taken in the vehicle.
        let ordered = located.sorted { $0.date! < $1.date! }
        for (a, b) in zip(ordered, ordered.dropFirst()) {
            let seconds = b.date!.timeIntervalSince(a.date!)
            guard seconds > 0, seconds <= movingWindow else { continue }
            let metres = CLLocation(latitude: a.latitude!, longitude: a.longitude!)
                .distance(from: CLLocation(latitude: b.latitude!, longitude: b.longitude!))
            let speed = metres / seconds
            guard metres >= movingDistance, speed >= movingSpeed else { continue }
            for p in [a, b] {
                switch out[p.id] {
                case .airborne: continue
                case .moving(let known) where known >= speed: continue
                default: out[p.id] = .moving(speed: speed)
                }
            }
        }
        return out
    }

    private static func cell(_ p: PhotoPoint) -> (Int, Int) {
        (Int((p.latitude! / cell).rounded(.down)), Int((p.longitude! / cell).rounded(.down)))
    }

    private static func key(_ p: PhotoPoint) -> Int {
        let (i, j) = cell(p)
        return key(i, j)
    }

    private static func key(_ i: Int, _ j: Int) -> Int { i * 20_000 + j }
}
