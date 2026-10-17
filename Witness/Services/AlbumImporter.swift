import Foundation
import Photos

/// An album in the fan's Apple Photos library.
struct PhotoAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
    let coverId: String?
    let start: Date?
    let end: Date?
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
