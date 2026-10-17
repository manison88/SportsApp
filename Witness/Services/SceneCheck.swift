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

    /// Clearly not a game: no sign of sport, and a clear sign of somewhere else.
    var doubtful: Bool { sports < 0.15 && elsewhere >= 0.3 }
    var looksLikeGame: Bool { sports >= 0.25 }
}

/// Tells a game from a party near the stadium by looking at the photos themselves. Runs on the phone.
enum SceneCheck {
    static let sportsWords = ["stadium", "arena", "sport", "baseball", "basketball", "football", "soccer", "hockey",
                              "athlet", "ballpark", "field", "court", "crowd", "scoreboard", "bleacher", "racing", "rink",
                              "tennis", "rugby", "cricket", "jersey", "team", "goal", "pitch", "audience"]
    static let eventWords = ["concert", "stage", "stadium", "arena", "crowd", "audience", "festival", "fireworks", "spotlight"]
    static let elsewhereWords = ["bar", "pub", "nightclub", "party", "cocktail", "wine", "restaurant", "dining", "dinner",
                                 "concert", "stage", "dancing", "wedding", "kitchen", "living_room", "bedroom", "office"]

    /// Scores a visit from a sample of its photos. Nil when the classifier isn't available (some simulators),
    /// so callers treat the visit as unknown rather than doubtful.
    static func verdict(for refs: [PhotoRef], sample: Int = 6) async -> SceneVerdict? {
        guard !refs.isEmpty else { return nil }
        let step = max(1, refs.count / sample)
        let picked = stride(from: 0, to: refs.count, by: step).prefix(sample).map { refs[$0] }
        var verdict = SceneVerdict(sports: 0, elsewhere: 0, event: 0)
        var classified = false
        for ref in picked {
            guard let image = await PhotoLoader.load(ref, size: CGSize(width: 512, height: 512)),
                  let labels = await labels(for: image) else { continue }
            classified = true
            let s = score(labels)
            verdict.sports = max(verdict.sports, s.sports)
            verdict.elsewhere = max(verdict.elsewhere, s.elsewhere)
            verdict.event = max(verdict.event, s.event)
        }
        return classified ? verdict : nil
    }

    /// Pure scoring of classifier labels, unit tested.
    static func score(_ labels: [(String, Float)]) -> (sports: Double, elsewhere: Double, event: Double) {
        var sports = 0.0, elsewhere = 0.0, event = 0.0
        for (id, confidence) in labels {
            let l = id.lowercased()
            if sportsWords.contains(where: { l.contains($0) }) { sports = max(sports, Double(confidence)) }
            if eventWords.contains(where: { l.contains($0) }) { event = max(event, Double(confidence)) }
            if elsewhereWords.contains(where: { l == $0 || l.hasPrefix($0 + "_") || l.hasSuffix("_" + $0) }) {
                elsewhere = max(elsewhere, Double(confidence))
            }
        }
        return (sports, elsewhere, event)
    }

    static func labels(for image: UIImage) async -> [(String, Float)]? {
        guard let cg = image.cgImage else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<[(String, Float)]?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
                do {
                    try handler.perform([request])
                    let results = (request.results ?? []).filter { $0.confidence > 0.05 }.map { ($0.identifier, $0.confidence) }
                    cont.resume(returning: results)
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
