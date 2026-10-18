import Foundation
import Photos
import CoreLocation

/// An album in the fan's Apple Photos library.
struct PhotoAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
    let coverId: String?
    let start: Date?
    let end: Date?
    /// Set for a trip found in the library (no album behind it): every photo taken in this window belongs to it.
    var range: ClosedRange<Date>? = nil
}

/// Reads albums the fan already made ("Spain 2020", "Chicago weekend") so a whole trip can come in at once.
enum AlbumImporter {
    /// The fan's own albums and shared albums, most recent first.
    static func albums() -> [PhotoAlbum] {
        var out: [PhotoAlbum] = []
        for subtype in [PHAssetCollectionSubtype.albumRegular, .albumCloudShared, .albumSyncedAlbum] {
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: subtype, options: nil)
            collections.enumerateObjects { collection, _, _ in
                let options = PHFetchOptions()
                options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                let assets = PHAsset.fetchAssets(in: collection, options: options)
                guard assets.count > 0 else { return }
                out.append(PhotoAlbum(id: collection.localIdentifier, title: collection.localizedTitle ?? "Album",
                                      count: assets.count, coverId: assets.lastObject?.localIdentifier,
                                      start: assets.firstObject?.creationDate, end: assets.lastObject?.creationDate))
            }
        }
        return out.sorted { ($0.end ?? .distantPast) > ($1.end ?? .distantPast) }
    }

    /// The photos of an album, or of a trip's time window.
    static func points(in album: PhotoAlbum) -> [PhotoPoint] {
        if let range = album.range { return points(from: range.lowerBound, to: range.upperBound) }
        return points(in: album.id)
    }

    /// Every photo taken in a window, with whatever place it carries (friends' copies with no location included).
    static func points(from: Date, to: Date) -> [PhotoPoint] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", from as NSDate, to as NSDate)
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var out: [PhotoPoint] = []
        out.reserveCapacity(assets.count)
        assets.enumerateObjects { a, _, _ in
            out.append(PhotoPoint(id: a.localIdentifier, date: a.creationDate,
                                  latitude: a.location?.coordinate.latitude, longitude: a.location?.coordinate.longitude))
        }
        return out
    }

    /// Every photo in an album with whatever time and place it carries.
    static func points(in albumId: String) -> [PhotoPoint] {
        guard let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil).firstObject
        else { return [] }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let assets = PHAsset.fetchAssets(in: collection, options: options)
        var out: [PhotoPoint] = []
        out.reserveCapacity(assets.count)
        assets.enumerateObjects { a, _, _ in
            out.append(PhotoPoint(id: a.localIdentifier, date: a.creationDate,
                                  latitude: a.location?.coordinate.latitude, longitude: a.location?.coordinate.longitude))
        }
        return out
    }

    /// Test support: puts every photo in the library into one album, so UI tests have an album to import.
    static func makeAlbumOfEverything(named title: String) async {
        let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var found = false
        existing.enumerateObjects { c, _, stop in if c.localizedTitle == title { found = true; stop.pointee = true } }
        guard !found else { return }
        let assets = PHAsset.fetchAssets(with: .image, options: nil)
        try? await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            request.addAssets(assets)
        }
    }
}

/// Trips found in the library without an album: stretches of photos taken far from home.
/// A trip is the photos taken away from home with no gap of more than a day and a half; it is imported by its time window,
/// so photos from the trip that carry no location come along.
enum TripFinder {
    /// Farther than this from home counts as away.
    static let awayMeters: CLLocationDistance = 80_000
    /// A longer pause between away photos ends the trip.
    static let maxGap: TimeInterval = 36 * 3600
    /// Fewer photos than this is a day out, not a trip worth listing.
    static let minPhotos = 5

    private struct Shot {
        let id: String
        let date: Date
        let location: CLLocation
    }

    /// Trips, most recent first, named for the nearest stadium's city when there is one.
    static func find(home: CLLocation, venues: [Venue]) -> [PhotoAlbum] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var stretches: [[Shot]] = []
        var current: [Shot] = []
        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate, let location = asset.location,
                  location.distance(from: home) > awayMeters else { return }
            if let last = current.last, date.timeIntervalSince(last.date) > maxGap {
                stretches.append(current)
                current = []
            }
            current.append(Shot(id: asset.localIdentifier, date: date, location: location))
        }
        if !current.isEmpty { stretches.append(current) }

        let pad: TimeInterval = 6 * 3600
        var out: [PhotoAlbum] = []
        for stretch in stretches where stretch.count >= minPhotos {
            guard let first = stretch.first, let last = stretch.last else { continue }
            let window = first.date.addingTimeInterval(-pad)...last.date.addingTimeInterval(pad)
            let latitude = stretch.map { $0.location.coordinate.latitude }.reduce(0, +) / Double(stretch.count)
            let longitude = stretch.map { $0.location.coordinate.longitude }.reduce(0, +) / Double(stretch.count)
            let center = CLLocation(latitude: latitude, longitude: longitude)
            let nearest = venues.filter { $0.location.distance(from: center) < 60_000 }
                .min { $0.location.distance(from: center) < $1.location.distance(from: center) }
            let countOptions = PHFetchOptions()
            countOptions.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@",
                                                 window.lowerBound as NSDate, window.upperBound as NSDate)
            let total = PHAsset.fetchAssets(with: .image, options: countOptions).count
            out.append(PhotoAlbum(id: "trip-\(Int(first.date.timeIntervalSince1970))",
                                  title: nearest.map { "\($0.city) trip" } ?? "Trip",
                                  count: total, coverId: stretch[stretch.count / 2].id,
                                  start: first.date, end: last.date, range: window))
        }
        return out.sorted { ($0.end ?? .distantPast) > ($1.end ?? .distantPast) }
    }
}
