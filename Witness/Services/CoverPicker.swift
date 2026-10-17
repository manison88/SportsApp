import UIKit
import Vision

/// Chooses the photo that best heads a game: the one Apple's on-device aesthetics model likes most
/// that also looks like it was taken at a game. Screenshots and tickets are marked down.
enum CoverPicker {
    /// Higher is better. `aesthetics` is Vision's overall score (-1...1) when the model is available;
    /// `sports` is how strongly the scene reads as a stadium, field or crowd (0...1).
    static func score(aesthetics: Double?, utility: Bool, sports: Double) -> Double {
        var s = (aesthetics.map { ($0 + 1) / 2 } ?? 0.5) * 0.6 + min(max(sports, 0), 1) * 0.4
        if utility { s -= 0.5 }
        return s
    }

    /// The best of up to `limit` photos, spread evenly across the game. The earliest wins a tie.
    static func best(_ refs: [PhotoRef], limit: Int = 16) async -> PhotoRef? {
        guard refs.count > 1 else { return refs.first }
        let step = max(1, refs.count / limit)
        let picked = stride(from: 0, to: refs.count, by: step).prefix(limit).map { refs[$0] }
        var best: (PhotoRef, Double)?
        for ref in picked {
            guard let image = await PhotoLoader.load(ref, size: CGSize(width: 640, height: 640)) else { continue }
            let a = await aesthetics(of: image)
            let sports = SceneCheck.score(await SceneCheck.labels(for: image) ?? []).sports
            let s = score(aesthetics: a?.overall, utility: a?.utility ?? false, sports: sports)
            if s > (best?.1 ?? -.infinity) { best = (ref, s) }
        }
        return best?.0 ?? refs.first
    }

    private static func aesthetics(of image: UIImage) async -> (overall: Double, utility: Bool)? {
        guard let cg = image.cgImage else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<(overall: Double, utility: Bool)?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNCalculateImageAestheticsScoresRequest()
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                if (try? handler.perform([request])) != nil, let o = request.results?.first {
                    cont.resume(returning: (Double(o.overallScore), o.isUtility))
                } else {
                    cont.resume(returning: nil)   // some simulators lack the model; the scene signal still ranks
                }
            }
        }
    }
}
