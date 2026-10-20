import Foundation
import CoreLocation

/// Tells photos taken from a plane, a train or a car from photos taken on foot, by how far the phone moved between shots. The
/// approach to Heathrow from the east crosses Stamford Bridge at 1,000 m, 1 to 3 km between window shots half a minute apart,
/// and the phone's fix put those shots inside the ground's fence: a photo on the move never places a stadium visit. Speed
/// only: altitude is terrain as often as flight (the Nurburgring sits 300 m above the valley its hotels are in). Pure.
enum TransitCheck {
    /// The fix's own speed, when the phone recorded one: a car on the motorway does 40 m/s at most, so above it is a plane.
    static let vehicleSpeed: Double = 40
    /// Two located photos at least a kilometre apart and this fast between them (20 m/s, 72 km/h: a motorway, a train, a plane
    /// on approach at 70 m/s; never the walk to the gate) were taken on the move. A kilometre, so a fix that jumps inside a
    /// full bowl does not count; five minutes, so the drive to the ground and the photo in the stands an hour later do not pair.
    static let movingSpeed: Double = 20
    static let movingDistance: CLLocationDistance = 1_000
    static let movingWindow: TimeInterval = 5 * 60

    /// For the scan check.
    static func text(speed: Double) -> String {
        "on the move, \(Int(speed)) m/s (limit \(Int(movingSpeed)) m/s over \(Int(movingDistance / 1000)) km)"
    }

    /// Every dated, located photo that was on the move, by id, with its speed in metres per second (from the fix, or between
    /// this photo and the one before or after it). Photos not in the result were on foot, or say nothing (no date, no location).
    static func moving(_ points: [PhotoPoint]) -> [String: Double] {
        let located = points.filter { $0.date != nil && $0.latitude != nil && $0.longitude != nil }
        var out: [String: Double] = [:]
        for p in located {
            if let speed = p.speed, speed > vehicleSpeed { out[p.id] = speed }
        }
        // Consecutive located photos far apart in little time: both ends of such a pair were taken in the vehicle.
        let ordered = located.sorted { $0.date! < $1.date! }
        for (a, b) in zip(ordered, ordered.dropFirst()) {
            let seconds = b.date!.timeIntervalSince(a.date!)
            guard seconds > 0, seconds <= movingWindow else { continue }
            let metres = CLLocation(latitude: a.latitude!, longitude: a.longitude!)
                .distance(from: CLLocation(latitude: b.latitude!, longitude: b.longitude!))
            let speed = metres / seconds
            guard metres >= movingDistance, speed >= movingSpeed else { continue }
            for p in [a, b] { out[p.id] = max(out[p.id] ?? 0, speed) }
        }
        return out
    }
}
