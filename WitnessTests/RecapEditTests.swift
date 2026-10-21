import Foundation
import Testing
@testable import Witness

/// The recap planner: the cut always lands between ten and fifteen seconds, in order, the cover first, bursts folded,
/// videos kept over photos when something has to go.
struct RecapEditTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func stills(_ n: Int, gap: TimeInterval = 120) -> [RecapMedia] {
        (0..<n).map { RecapMedia(ref: .library("p\($0)"), date: t0.addingTimeInterval(Double($0) * gap)) }
    }

    private func media(_ plan: RecapEdit) -> [RecapEdit.Segment] { plan.segments.filter(\.isMedia) }

    private func refs(_ plan: RecapEdit) -> [PhotoRef] {
        media(plan).compactMap {
            switch $0.content {
            case .still(let r, _), .clip(let r, _, _): r
            default: nil
            }
        }
    }

    /// Segments abut with the crossfade overlap, and the plan's duration is the end card's end.
    private func checkTimeline(_ plan: RecapEdit) {
        for (a, b) in zip(plan.segments, plan.segments.dropFirst()) {
            #expect(abs(b.start - (a.end - RecapEdit.crossfade)) < 0.001)
        }
        #expect(abs(plan.duration - (plan.segments.last?.end ?? 0)) < 0.001)
    }

    @Test(arguments: [0, 1, 3, 8, 25])
    func totalLandsBetweenTenAndFifteenSeconds(count: Int) {
        let plan = RecapEdit.plan(media: stills(count), cover: nil)
        #expect(plan.duration >= 10 && plan.duration <= 15, "\(count) photos ran \(plan.duration) s")
        #expect(media(plan).count == min(count, RecapEdit.maxMedia))
        checkTimeline(plan)
    }

    @Test func titleAndEndCardsAreAlwaysThere() {
        for count in [0, 2, 12] {
            let plan = RecapEdit.plan(media: stills(count), cover: nil)
            #expect(plan.segments.first?.content == .title)
            #expect(plan.segments.last?.content == .end)
        }
    }

    @Test func zeroMediaIsTitleThenEnd() {
        let plan = RecapEdit.plan(media: [], cover: nil)
        #expect(plan.segments.count == 2)
        #expect(plan.duration >= 10)
    }

    @Test func mediaRunsChronologicallyWithTheUndatedLast() {
        let shuffled = [
            RecapMedia(ref: .library("c"), date: t0.addingTimeInterval(300)),
            RecapMedia(ref: .bundled("x")),
            RecapMedia(ref: .library("a"), date: t0),
            RecapMedia(ref: .library("b"), date: t0.addingTimeInterval(100)),
        ]
        let plan = RecapEdit.plan(media: shuffled, cover: nil)
        #expect(refs(plan) == [.library("a"), .library("b"), .library("c"), .bundled("x")])
    }

    @Test func burstsCollapseToOnePhoto() {
        var items = stills(1)
        // Four more within twenty seconds of the first: one burst.
        for i in 1...4 { items.append(RecapMedia(ref: .library("burst\(i)"), date: t0.addingTimeInterval(Double(i) * 4))) }
        items.append(RecapMedia(ref: .library("later"), date: t0.addingTimeInterval(60)))
        let plan = RecapEdit.plan(media: items, cover: nil)
        #expect(refs(plan) == [.library("p0"), .library("later")])
    }

    @Test func coverLeadsEvenWhenShotLater() {
        let items = stills(4)
        let plan = RecapEdit.plan(media: items, cover: .library("p2"))
        #expect(refs(plan).first == .library("p2"))
        #expect(refs(plan) == [.library("p2"), .library("p0"), .library("p1"), .library("p3")])
    }

    @Test func videosAreKeptOverStillsWhenCapped() {
        var items = stills(20)
        items.append(RecapMedia(ref: .library("v1"), date: t0.addingTimeInterval(130), isVideo: true, duration: 8))
        items.append(RecapMedia(ref: .library("v2"), date: t0.addingTimeInterval(1500), isVideo: true, duration: 8))
        let plan = RecapEdit.plan(media: items, cover: nil)
        let kept = refs(plan)
        #expect(kept.count == RecapEdit.maxMedia)
        #expect(kept.contains(.library("v1")) && kept.contains(.library("v2")))
        #expect(plan.duration <= 15)
    }

    @Test func videosAreKeptOverStillsWhenTheCutRunsLong() {
        var items: [RecapMedia] = []
        for i in 0..<6 { items.append(RecapMedia(ref: .library("v\(i)"), date: t0.addingTimeInterval(Double(i) * 200), isVideo: true, duration: 10)) }
        items.append(RecapMedia(ref: .library("s"), date: t0.addingTimeInterval(5000)))
        let plan = RecapEdit.plan(media: items, cover: nil)
        #expect(plan.duration <= 15)
        #expect(!refs(plan).contains(.library("s")), "the photo goes before any clip does")
        #expect(refs(plan).allSatisfy { if case .library(let id) = $0 { return id.hasPrefix("v") } else { return false } })
    }

    @Test func clipsPlayFromTheirMiddle() {
        let items = [RecapMedia(ref: .library("v"), date: t0, isVideo: true, duration: 10)]
        let plan = RecapEdit.plan(media: items, cover: nil)
        guard case .clip(_, let inPoint, let duration) = media(plan)[0].content else { Issue.record("no clip"); return }
        #expect(duration == RecapEdit.clipMax)
        #expect(abs(inPoint + duration / 2 - 5) < 0.001)

        let short = RecapEdit.plan(media: [RecapMedia(ref: .library("v"), date: t0, isVideo: true, duration: 1.4)], cover: nil)
        guard case .clip(_, let shortIn, let shortLength) = media(short)[0].content else { Issue.record("no clip"); return }
        #expect(shortIn == 0 && shortLength == 1.4)
    }

    @Test func stillsStretchAndShrinkWithinTheirBounds() {
        let few = RecapEdit.plan(media: stills(3), cover: nil)
        for s in media(few) { #expect(s.duration <= RecapEdit.stillMax && s.duration >= RecapEdit.stillMin) }
        let many = RecapEdit.plan(media: stills(8), cover: nil)
        for s in media(many) { #expect(s.duration >= RecapEdit.stillMin) }
    }

    @Test func kenBurnsRotatesAndStopsForReduceMotion() {
        let plan = RecapEdit.plan(media: stills(3), cover: nil)
        let moves = media(plan).compactMap { if case .still(_, let kb) = $0.content { return kb } else { return nil } }
        #expect(moves.count == 3)
        #expect(Set(moves).count == 3, "three different presets")
        #expect(moves[0].from == CGRect(x: 0, y: 0, width: 1, height: 1), "the first pushes in from full frame")
        #expect(abs(moves[0].to.width - 1 / RecapEdit.kenBurnsScale) < 0.001)

        let still = RecapEdit.plan(media: stills(3), cover: nil, reduceMotion: true)
        for s in media(still) {
            if case .still(_, let kb) = s.content { #expect(kb == nil) }
        }
    }

    @Test func segmentsCarryTheirCaptureTimeForTheChip() {
        let plan = RecapEdit.plan(media: stills(2) + [RecapMedia(ref: .bundled("x"))], cover: nil)
        let dates = media(plan).map(\.date)
        #expect(dates[0] == t0 && dates[2] == nil)
    }

    @Test func cacheKeyChangesWithMediaScoreAndMotion() {
        let a = RecapCacheKey(gameId: "g", refs: [.bundled("x")], score: "3–1", reduceMotion: false)
        var b = a; b.refs.append(.library("y"))
        var c = a; c.score = "3–2"
        var d = a; d.reduceMotion = true
        #expect(Set([a, b, c, d].map(\.digest)).count == 4)
        #expect(a.fileName == "g-\(a.digest).mp4")
        #expect(a.digest == RecapCacheKey(gameId: "g", refs: [.bundled("x")], score: "3–1", reduceMotion: false).digest)
    }
}
