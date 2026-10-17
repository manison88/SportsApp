import Foundation
import Photos

/// A ticket screenshot in the camera roll, read on the phone: it pins a game to a venue and a time
/// even when none of the night's photos carry GPS.
struct TicketAnchor: Identifiable, Hashable {
    let id: String          // the screenshot's asset id
    let draft: TicketDraft
    let venue: Venue
    let date: Date
}

enum TicketAnchors {
    /// Recent screenshots (the usual way tickets end up in Photos), optionally only those in one album.
    static func screenshots(limit: Int = 300, inAlbum albumId: String? = nil) -> [String] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let result: PHFetchResult<PHAsset>
        if let albumId, let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil).firstObject {
            result = PHAsset.fetchAssets(in: album, options: options)
        } else {
            result = PHAsset.fetchAssets(with: .image, options: options)
        }
        var ids: [String] = []
        result.enumerateObjects { a, _, _ in ids.append(a.localIdentifier) }
        return ids
    }

    /// Reads screenshots and keeps the ones that are tickets with a date and a place.
    static func find(in assetIds: [String], teams: [Team], venues: [Venue]) async -> [TicketAnchor] {
        var out: [TicketAnchor] = []
        for id in assetIds {
            guard let image = await PhotoLoader.load(.library(id), size: CGSize(width: 1600, height: 1600)),
                  let text = try? await TextRecognizer.text(in: image) else { continue }
            if let anchor = anchor(from: text, assetId: id, teams: teams, venues: venues) { out.append(anchor) }
        }
        return out
    }

    /// Pure: ticket text to an anchor. Needs ticket words, a date, and a venue (printed, or the home team's).
    static func anchor(from text: String, assetId: String, teams: [Team], venues: [Venue]) -> TicketAnchor? {
        let upper = text.uppercased()
        let ticketWords = ["SEC", "SECTION", "ROW", "SEAT", "TICKET", "GATE", "ADMIT", "ENTRY", "ENTRANCE"]
        guard ticketWords.contains(where: { upper.contains($0) }) else { return nil }
        let draft = TicketParser.parse(text, teams: teams, venues: venues)
        guard let date = draft.date else { return nil }
        var venue = draft.venueId.flatMap { id in venues.first { $0.id == id } }
        if venue == nil, let homeId = draft.homeTeamId, let home = teams.first(where: { $0.id == homeId }) {
            let full = "\(home.locationName) \(home.teamName)".lowercased()
            venue = venues.first { v in (v.homeTeams ?? []).contains { $0.lowercased() == full } }
        }
        guard let venue else { return nil }
        return TicketAnchor(id: assetId, draft: draft, venue: venue, date: date)
    }
}
