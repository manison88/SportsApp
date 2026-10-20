import Foundation
import CoreLocation

/// Tells photos taken from a plane, a train or a car from photos taken on foot, by how far the phone moved between shots. The
/// approach to Heathrow from the east crosses Stamford Bridge at 1,000 m, 1 to 3 km between window shots half a minute apart,
/// and the phone's fix put those shots inside the ground's fence: a photo on the move never places a stadium visit. Speed
/// only: altitude is terrain as often as flight (the Nurburgring sits 300 m above the valley its hotels are in). Pure.
///
/// The numbers come from `ScanSettings`: `vehicleSpeed` (the fix's own speed, when the phone recorded one: a car on the
/// motorway does 40 m/s at most, so above it is a plane); `movingSpeed`, `movingDistanceMeters` and `movingWindowMinutes` (two
/// located photos at least a kilometre apart and 20 m/s between them, 72 km/h, a motorway, a train, a plane on approach at
/// 70 m/s, never the walk to the gate, were taken on the move; a kilometre, so a fix that jumps inside a full bowl does not
/// count; five minutes, so the drive to the ground and the photo in the stands an hour later do not pair).
enum TransitCheck {
    /// For the scan check.
    static func text(speed: Double, settings: ScanSettings = .current) -> String {
        "on the move, \(Int(speed)) m/s (limit \(Int(settings.movingSpeed)) m/s over \(Int(settings.movingDistanceMeters / 1000)) km)"
    }

    /// Every dated, located photo that was on the move, by id, with its speed in metres per second (from the fix, or between
    /// this photo and the one before or after it). Photos not in the result were on foot, or say nothing (no date, no location).
    static func moving(_ points: [PhotoPoint], settings: ScanSettings = .current) -> [String: Double] {
        let located = points.filter { $0.date != nil && $0.latitude != nil && $0.longitude != nil }
        var out: [String: Double] = [:]
        for p in located {
            if let speed = p.speed, speed > settings.vehicleSpeed { out[p.id] = speed }
        }
        // Consecutive located photos far apart in little time: both ends of such a pair were taken in the vehicle.
        let ordered = located.sorted { $0.date! < $1.date! }
        let window = settings.movingWindowMinutes * 60
        for (a, b) in zip(ordered, ordered.dropFirst()) {
            let seconds = b.date!.timeIntervalSince(a.date!)
            guard seconds > 0, seconds <= window else { continue }
            let metres = CLLocation(latitude: a.latitude!, longitude: a.longitude!)
                .distance(from: CLLocation(latitude: b.latitude!, longitude: b.longitude!))
            let speed = metres / seconds
            guard metres >= settings.movingDistanceMeters, speed >= settings.movingSpeed else { continue }
            for p in [a, b] { out[p.id] = max(out[p.id] ?? 0, speed) }
        }
        return out
    }
}
