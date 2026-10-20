import Foundation
import UIKit
import Vision

/// What a visit's photos look like, from Apple's on-device image classifier.
struct SceneVerdict: Hashable {
    /// Strongest "at a game" signal across the photos (stadium, field, court, crowd, scoreboard...), 0...1.
    var sports: Double
    /// Strongest "out somewhere else" signal (bar, restaurant, party, concert...), 0...1.
    var elsewhere: Double
    /// Strongest sign of a live event of any kind (stage, concert, arena, crowd), 0...1.
    var event: Double = 0
    /// Strongest sign of being indoors (arena, court, rink, ceiling) and outdoors (sky, grass, field), 0...1.
    var indoor: Double = 0
    var outdoor: Double = 0
    /// Strongest sign of a stadium, arena, ballpark, scoreboard or a named sport (not just a crowd or a field), 0...1.
    var venueSign: Double = 0

    /// The photos' setting fits the ground: an arena should look indoors, a ballpark or stadium outdoors. A second opinion only:
    /// the place and the date already found the game.
    func fits(_ venue: Venue) -> Bool { venue.isIndoor ? indoor >= 0.3 : outdoor >= 0.3 }

    /// Clearly not a game: no sign of sport, and a clear sign of somewhere else.
    var doubtful: Bool { sports < 0.15 && elsewhere >= 0.3 }
    var looksLikeGame: Bool { sports >= 0.25 }
    /// A crowd, a field or a team could be a wedding, a school play or a kid's game. This needs a stadium, arena, scoreboard or sport.
    var showsAVenue: Bool { venueSign >= 0.25 }

    /// Positively somewhere else: a clear sign of a bedroom, a restaurant, a bar and no sign of sport. An unsure result
    /// is never grounds for dropping a game, because the classifier's confidence on real stadium photos can be low.
    var clearlyElsewhere: Bool { elsewhere >= 0.25 && sports < 0.2 && event < 0.25 }
}

/// Tells a game from a party near the stadium by looking at the photos themselves. Runs on the phone.
enum SceneCheck {
    /// The word lists come from `ScanSettings` (`sceneSportsWords`, `sceneVenueLabels`, ...); these read the settings in force.
    static var sportsWords: [String] { ScanSettings.current.sceneSportsWords }
    /// What only a real game venue or sport produces, as the classifier's exact identifiers. Matched whole, not as substrings:
    /// "rink" is inside "drink" and "baseball" inside "baseball_hat". "crowd", "people" and "grass" are not here on purpose
    /// (the taxonomy has no "field", "court", "pitch", "team" or "audience").
    static var venueLabels: Set<String> { Set(ScanSettings.current.sceneVenueLabels) }
    /// The ground itself rather than a sport, which a park, a schoolyard or a beach can show too. Real stadium photos carry
    /// "stadium" and "arena" together (0.8 to 0.9), and often "scoreboard".
    static var structureLabels: Set<String> { Set(ScanSettings.current.sceneStructureLabels) }
    static var indoorWords: [String] { ScanSettings.current.sceneIndoorWords }
    static var outdoorWords: [String] { ScanSettings.current.sceneOutdoorWords }
    static var eventWords: [String] { ScanSettings.current.sceneEventWords }
    static var elsewhereWords: [String] { ScanSettings.current.sceneElsewhereWords }

    /// Scores a visit from a sample (`sceneVerdictSample`) of its photos. Nil when the classifier isn't available (some simulators),
    /// so callers treat the visit as unknown rather than doubtful.
    static func verdict(for refs: [PhotoRef], sample: Int? = nil, settings: ScanSettings = .current) async -> SceneVerdict? {
        guard !refs.isEmpty else { return nil }
        let sample = sample ?? settings.sceneVerdictSample
        let step = max(1, refs.count / sample)
        let picked = stride(from: 0, to: refs.count, by: step).prefix(sample).map { refs[$0] }
        var verdict = SceneVerdict(sports: 0, elsewhere: 0, event: 0, indoor: 0, outdoor: 0)
        var classified = false
        for ref in picked {
            guard let image = await PhotoLoader.load(ref, size: CGSize(width: 512, height: 512)),
                  let labels = await labels(for: image, settings: settings) else { continue }
            classified = true
            let s = score(labels, settings: settings)
            verdict.sports = max(verdict.sports, s.sports)
            verdict.elsewhere = max(verdict.elsewhere, s.elsewhere)
            verdict.event = max(verdict.event, s.event)
            verdict.venueSign = max(verdict.venueSign, venueSign(labels, settings: settings))
            let setting = Self.setting(labels, settings: settings)
            verdict.indoor = max(verdict.indoor, setting.indoor)
            verdict.outdoor = max(verdict.outdoor, setting.outdoor)
        }
        return classified ? verdict : nil
    }

    /// Pure: the strongest label that names a stadium, arena, scoreboard or sport.
    static func venueSign(_ labels: [(String, Float)], settings: ScanSettings = .current) -> Double {
        let venue = settings.sceneVenueLabels
        return labels.filter { venue.contains($0.0.lowercased()) }.map { Double($0.1) }.max() ?? 0
    }

    /// What one photo shows, for counting a day.
    enum PhotoKind: Equatable { case venue(structure: Bool), elsewhere, neither }

    /// Pure: a photo is at a game when a venue or sport label is clear (`sceneKindThreshold`) and beats every beach, party or
    /// meal label (a beach with a ball reads "soccer" too); somewhere else when one of those is clear and no game is.
    static func kind(_ labels: [(String, Float)], settings: ScanSettings = .current) -> PhotoKind {
        let clear = settings.sceneKindThreshold
        let v = venueSign(labels, settings: settings), e = score(labels, settings: settings).elsewhere
        if v >= clear && v > e {
            let structure = settings.sceneStructureLabels
            let s = labels.filter { structure.contains($0.0.lowercased()) }.map { Double($0.1) }.max() ?? 0
            return .venue(structure: s >= clear)
        }
        return e >= clear ? .elsewhere : .neither
    }

    /// A day's photos counted one by one: how many show a stadium, arena, scoreboard or sport, and how many show somewhere
    /// else (a beach, a party, a meal). For the background search, which has time to look at most of a day.
    struct DayLook {
        var classified = 0
        var venue = 0
        var elsewhere = 0
        /// Venue photos that show the ground itself (stadium, arena, scoreboard, bleachers), not only a sport.
        var structure = 0
        var venueShare: Double { classified == 0 ? 0 : Double(venue) / Double(classified) }
        var elsewhereShare: Double { classified == 0 ? 0 : Double(elsewhere) / Double(classified) }
        /// Several photos of the day clearly at a game (`lookMinVenue` at `lookMinShare`), and the day not mostly somewhere else
        /// (under `lookMaxElsewhere`). One stray "soccer pitch" is not enough.
        func isGame(minVenue: Int? = nil, minShare: Double? = nil, settings: ScanSettings = .current) -> Bool {
            venue >= (minVenue ?? settings.lookMinVenue) && venueShare >= (minShare ?? settings.lookMinShare)
                && elsewhereShare < settings.lookMaxElsewhere
        }
        var mostlyElsewhere: Bool { mostlyElsewhere(.current) }
        func mostlyElsewhere(_ settings: ScanSettings) -> Bool { elsewhereShare >= settings.lookMostlyElsewhere }
    }

    static func look(at refs: [PhotoRef], max: Int? = nil, settings: ScanSettings = .current) async -> DayLook {
        var out = DayLook()
        guard !refs.isEmpty else { return out }
        let max = max ?? settings.dayLookPhotos
        let step = Swift.max(1, refs.count / max)
        for ref in stride(from: 0, to: refs.count, by: step).prefix(max).map({ refs[$0] }) {
            if Task.isCancelled { break }
            guard let image = await PhotoLoader.load(ref, size: CGSize(width: 384, height: 384)),
                  let labels = await labels(for: image, settings: settings) else { continue }
            out.classified += 1
            switch kind(labels, settings: settings) {
            case .venue(let structure): out.venue += 1; if structure { out.structure += 1 }
            case .elsewhere: out.elsewhere += 1
            case .neither: break
            }
        }
        return out
    }

    /// Pure: how indoors and how outdoors the labels say the photo is.
    static func setting(_ labels: [(String, Float)], settings: ScanSettings = .current) -> (indoor: Double, outdoor: Double) {
        var indoor = 0.0, outdoor = 0.0
        for (id, confidence) in labels {
            let l = id.lowercased()
            if settings.sceneIndoorWords.contains(where: { l.contains($0) }) { indoor = max(indoor, Double(confidence)) }
            if settings.sceneOutdoorWords.contains(where: { l.contains($0) }) { outdoor = max(outdoor, Double(confidence)) }
        }
        return (indoor, outdoor)
    }

    /// Pure scoring of classifier labels, unit tested.
    static func score(_ labels: [(String, Float)], settings: ScanSettings = .current) -> (sports: Double, elsewhere: Double, event: Double) {
        var sports = 0.0, elsewhere = 0.0, event = 0.0
        for (id, confidence) in labels {
            let l = id.lowercased()
            if settings.sceneSportsWords.contains(where: { l.contains($0) }) { sports = max(sports, Double(confidence)) }
            if settings.sceneEventWords.contains(where: { l.contains($0) }) { event = max(event, Double(confidence)) }
            if settings.sceneElsewhereWords.contains(where: { l == $0 || l.hasPrefix($0 + "_") || l.hasSuffix("_" + $0) }) {
                elsewhere = max(elsewhere, Double(confidence))
            }
        }
        return (sports, elsewhere, event)
    }

    /// The classifier's labels for an image, those over `sceneLabelFloor`.
    static func labels(for image: UIImage, settings: ScanSettings = .current) async -> [(String, Float)]? {
        guard let cg = image.cgImage else { return nil }
        let floor = Float(settings.sceneLabelFloor)
        return await withCheckedContinuation { (cont: CheckedContinuation<[(String, Float)]?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
                do {
                    try handler.perform([request])
                    let results = (request.results ?? []).filter { $0.confidence > floor }.map { ($0.identifier, $0.confidence) }
                    cont.resume(returning: results)
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
