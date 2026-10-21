import Foundation
import CoreGraphics

/// One piece of a game's media as the recap planner sees it: what it is, when it was shot, and for a video how long it runs.
struct RecapMedia: Hashable, Sendable {
    var ref: PhotoRef
    /// The capture time, when the library knows it. Bundled sample photos have none.
    var date: Date?
    var isVideo = false
    /// The video's full length in seconds; 0 for a photo or when unknown.
    var duration: TimeInterval = 0
}

/// The cut of a game's recap: a title card, the photos and clips in order with a dissolve between them, an end card.
/// Pure arithmetic over the media list, so the same game always cuts the same way and the rules can be tested.
struct RecapEdit: Hashable, Sendable {
    /// A Ken Burns move: the part of the 1080×1920 frame shown at the start and at the end, in unit coordinates
    /// (Core Image's: origin bottom-left). The renderer eases between them and scales the part up to fill the frame.
    struct KenBurns: Hashable, Sendable {
        var from: CGRect
        var to: CGRect
    }

    enum Content: Hashable, Sendable {
        case title
        case still(PhotoRef, kenBurns: KenBurns?)
        /// A video, from `inPoint` seconds into it, for `duration` seconds.
        case clip(PhotoRef, inPoint: TimeInterval, duration: TimeInterval)
        case end
    }

    struct Segment: Hashable, Sendable, Identifiable {
        var id: Int
        /// Where on the timeline this segment starts; it overlaps the previous one by `crossfade`.
        var start: TimeInterval
        var duration: TimeInterval
        var content: Content
        /// When the photo or clip was shot, for the time chip. Nil leaves the chip off.
        var date: Date?

        var end: TimeInterval { start + duration }
        var isMedia: Bool {
            switch content {
            case .still, .clip: true
            case .title, .end: false
            }
        }
    }

    var segments: [Segment]
    /// The whole timeline, title to end card.
    var duration: TimeInterval

    /// The dissolve between any two neighbouring segments.
    static let crossfade: TimeInterval = 0.25

    // MARK: Rules

    static let titleLength: TimeInterval = 1.2
    static let endLength: TimeInterval = 1.5
    static let stillLength: TimeInterval = 1.3
    static let stillMin: TimeInterval = 1.0
    static let stillMax: TimeInterval = 2.2
    static let clipMin: TimeInterval = 2.0
    static let clipMax: TimeInterval = 2.5
    static let floor: TimeInterval = 10
    static let ceiling: TimeInterval = 15
    static let maxMedia = 8
    /// A photo this close after the previous kept one is part of the same burst and is dropped.
    static let burstWindow: TimeInterval = 20
    /// Photos push in from full frame to this much magnification; the drifts end there too.
    static let kenBurnsScale: CGFloat = 1.12

    /// Cuts the recap. `media` is the game's photos and videos in library order; `cover` leads when it is among them.
    static func plan(media: [RecapMedia], cover: PhotoRef?, targetSeconds: TimeInterval = 12, reduceMotion: Bool = false) -> RecapEdit {
        let target = min(max(targetSeconds, floor), ceiling)
        var kept = select(media, cover: cover)

        var stillLength = Self.stillLength
        var titleLength = Self.titleLength
        var endLength = Self.endLength

        // Fit the total between the floor and the ceiling, as near the target as the rules allow: stills stretch or
        // shrink first, then media comes off the end, and with too little to fill ten seconds the cards hold longer.
        while true {
            let stills = kept.filter { !$0.isVideo }.count
            let clips = kept.filter(\.isVideo).reduce(0.0) { $0 + clipLength($1).duration }
            let overhead = Self.titleLength + Self.endLength - crossfade * Double(kept.count + 1)
            var total = overhead + clips + Double(stills) * Self.stillLength
            stillLength = Self.stillLength
            if total > target, stills > 0 {
                stillLength = max(stillMin, Self.stillLength - (total - target) / Double(stills))
                total = overhead + clips + Double(stills) * stillLength
            }
            if total > ceiling, !kept.isEmpty {
                // Drop the last photo; only when none is left does a clip go.
                if let i = kept.lastIndex(where: { !$0.isVideo }) { kept.remove(at: i) } else { kept.removeLast() }
                continue
            }
            if total < target, stills > 0 {
                stillLength = min(stillMax, Self.stillLength + (target - total) / Double(stills))
                total = overhead + clips + Double(stills) * stillLength
            }
            if total < floor {
                let short = floor - total
                titleLength = Self.titleLength + short * 0.4
                endLength = Self.endLength + short * 0.6
            }
            break
        }

        // Lay the segments on the timeline, each starting a crossfade before the previous one ends.
        var segments: [Segment] = []
        segments.append(Segment(id: 0, start: 0, duration: titleLength, content: .title))
        var cursor = titleLength - crossfade
        var stillIndex = 0
        for item in kept {
            let content: Content
            let length: TimeInterval
            if item.isVideo {
                let cut = clipLength(item)
                content = .clip(item.ref, inPoint: cut.inPoint, duration: cut.duration)
                length = cut.duration
            } else {
                content = .still(item.ref, kenBurns: reduceMotion ? nil : kenBurns(stillIndex))
                length = stillLength
                stillIndex += 1
            }
            segments.append(Segment(id: segments.count, start: cursor, duration: length, content: content, date: item.date))
            cursor += length - crossfade
        }
        segments.append(Segment(id: segments.count, start: cursor, duration: endLength, content: .end))
        return RecapEdit(segments: segments, duration: cursor + endLength)
    }

    /// Chronological order with the undated last, the cover first, bursts collapsed, at most `maxMedia` with videos kept.
    static func select(_ media: [RecapMedia], cover: PhotoRef?) -> [RecapMedia] {
        let dated = media.filter { $0.date != nil }.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let undated = media.filter { $0.date == nil }
        let ordered = dated + undated

        // Bursts: a photo within the window of the last kept item goes. Videos and the cover always stay.
        var kept: [RecapMedia] = []
        for item in ordered {
            let isCover = item.ref == cover
            if !item.isVideo, !isCover, let d = item.date, let last = kept.last?.date, d.timeIntervalSince(last) < burstWindow {
                continue
            }
            kept.append(item)
        }

        if kept.count > maxMedia {
            var chosen = Set<Int>()
            if let c = kept.firstIndex(where: { $0.ref == cover }) { chosen.insert(c) }
            let videos = kept.indices.filter { kept[$0].isVideo && !chosen.contains($0) }
            let stills = kept.indices.filter { !kept[$0].isVideo && !chosen.contains($0) }
            for i in spread(videos, count: maxMedia - chosen.count) { chosen.insert(i) }
            for i in spread(stills, count: maxMedia - chosen.count) { chosen.insert(i) }
            kept = chosen.sorted().map { kept[$0] }
        }

        if let c = kept.firstIndex(where: { $0.ref == cover }), c > 0 {
            kept.insert(kept.remove(at: c), at: 0)
        }
        return kept
    }

    /// `count` of the indices, spaced evenly across the list.
    private static func spread(_ indices: [Int], count: Int) -> [Int] {
        guard count > 0, !indices.isEmpty else { return [] }
        if indices.count <= count { return indices }
        return (0..<count).map { indices[Int((Double($0) + 0.5) * Double(indices.count) / Double(count))] }
    }

    /// The part of a video that plays: 2–2.5 s around its middle, or all of a shorter one from the top.
    static func clipLength(_ item: RecapMedia) -> (inPoint: TimeInterval, duration: TimeInterval) {
        let length = item.duration
        if length <= 0 { return (0, clipMin) }
        if length < clipMin { return (0, length) }
        let duration = min(clipMax, length)
        return ((length - duration) / 2, duration)
    }

    /// Three moves in turn: push in, drift left to right, drift right to left.
    static func kenBurns(_ index: Int) -> KenBurns {
        let full = CGRect(x: 0, y: 0, width: 1, height: 1)
        let tight = 1 / kenBurnsScale
        let loose = 1 / (1 + (kenBurnsScale - 1) / 2)
        func rect(_ scale: CGFloat, x: CGFloat) -> CGRect {
            CGRect(x: x, y: (1 - scale) / 2, width: scale, height: scale)
        }
        switch index % 3 {
        case 0: return KenBurns(from: full, to: rect(tight, x: (1 - tight) / 2))
        case 1: return KenBurns(from: rect(loose, x: 0), to: rect(tight, x: 1 - tight))
        default: return KenBurns(from: rect(loose, x: 1 - loose), to: rect(tight, x: 0))
        }
    }
}
