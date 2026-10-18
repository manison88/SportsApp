import SwiftUI

/// 06 · You were there, as a match report: your photos woven into the game's own story. A pinned timeline of the game
/// clock shows when you took pictures; below it every key play is a card with the photos you took around it.
struct MatchReportView: View {
    let game: GameEntry
    let moments: [YouWereThereView.PhotoMoment]

    @Environment(Library.self) private var library
    @State private var viewing: PhotoViewerItem?
    @State private var activeId: String?
    @State private var scrollTo: String?

    // MARK: Beats

    /// One stop in the report: before the game, the opening stretch, a key play, or after the final whistle.
    struct Beat: Identifiable {
        enum Kind { case before, opening, play(Play), after, untimed }
        let id: String
        let kind: Kind
        let photos: [YouWereThereView.PhotoMoment]
        /// Where it sits on the game clock.
        let time: Date?
    }

    private var tz: TimeZone { library.venue(game.venueId)?.tz ?? .current }
    private var keyPlays: [Play] { game.plays.filter(\.isKey).sorted { $0.time < $1.time } }
    private var kickoff: Date { game.date }

    /// When the game ended: the final play, plus how long a finished game's last whistle trails its last event.
    private var endTime: Date {
        let last = game.plays.map(\.time).max() ?? kickoff.addingTimeInterval(typical)
        let grace: TimeInterval = game.sport == .soccer ? 14 * 60 : game.sport == .basketball ? 8 * 60 : 3 * 60
        return last.addingTimeInterval(grace)
    }

    private var typical: TimeInterval {
        switch game.sport {
        case .soccer: 105 * 60
        case .baseball: 3 * 3600
        case .football: 3.2 * 3600
        case .basketball: 2.3 * 3600
        case .hockey: 2.5 * 3600
        default: 2 * 3600
        }
    }

    private var beats: [Beat] {
        let timed = moments.filter { $0.time != nil }
        let untimed = moments.filter { $0.time == nil }
        let plays = keyPlays
        var out: [Beat] = []

        let before = timed.filter { $0.time! < kickoff }
        if !before.isEmpty { out.append(Beat(id: "before", kind: .before, photos: before, time: before.first?.time)) }

        let firstPlay = plays.first?.time ?? endTime
        let opening = timed.filter { $0.time! >= kickoff && $0.time! < firstPlay }
        out.append(Beat(id: "opening", kind: .opening, photos: opening, time: kickoff))

        for (i, play) in plays.enumerated() {
            let next = i + 1 < plays.count ? plays[i + 1].time : endTime
            let photos = timed.filter { $0.time! >= play.time && $0.time! < next }
            out.append(Beat(id: play.id, kind: .play(play), photos: photos, time: play.time))
        }

        let after = timed.filter { $0.time! >= endTime }
        if !after.isEmpty { out.append(Beat(id: "after", kind: .after, photos: after, time: after.first?.time)) }
        if !untimed.isEmpty { out.append(Beat(id: "untimed", kind: .untimed, photos: untimed, time: nil)) }
        return out
    }

    // MARK: Story numbers

    private var timedPhotos: [Date] { moments.compactMap(\.time) }
    private var duringCount: Int { timedPhotos.filter { $0 >= kickoff && $0 < endTime }.count }
    private var nearPlayCount: Int {
        let times = keyPlays.map(\.time)
        return timedPhotos.filter { t in times.contains { abs($0.timeIntervalSince(t)) <= 60 } }.count
    }

    private var allRefs: [PhotoRef] { moments.map(\.ref) }

    // MARK: Body

    var body: some View {
        let beats = beats
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    hero
                        .gutter()
                        .padding(.top, 8)
                        .padding(.bottom, Spacing.inner)

                    Section {
                        ForEach(beats) { beat in
                            row(beat)
                                .id(beat.id)
                        }
                        Color.clear.frame(height: 60)
                    } header: {
                        timeline(beats) { id in
                            withAnimation(.snappy) { proxy.scrollTo(id, anchor: .top) }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.5) { ids in
                if let first = ids.first(where: { id in beats.contains { $0.id == id } }) { activeId = first }
            }
        }
        .inkBackground()
        .fullScreenCover(item: $viewing) { item in
            PhotoPager(photos: allRefs, start: item.id, cover: game.heroPhoto, onDelete: { ref in
                library.removePhotos(game.id, [ref])
            })
        }
        .accessibilityIdentifier("ywt-report")
    }

    // MARK: Hero

    private var hero: some View {
        let best = game.heroPhoto ?? moments.first?.ref
        return HStack(spacing: 0) {
            ZStack {
                Color.panelRaised
                if let best { PhotoView(ref: best) } else { GameBackdrop(game: game) }
            }
            .frame(width: 118)
            .clipped()
            VStack(alignment: .leading, spacing: 10) {
                Text(headlineText(game, library).replacingOccurrences(of: "\n", with: " \u{00B7} ").uppercased())
                    .font(.condensed(.caption, weight: .heavy)).tracking(1.2)
                    .foregroundStyle(Color.textSecondary).lineLimit(1).minimumScaleFactor(0.7)
                Text("You were there")
                    .font(.condensed(.title, weight: .heavy)).textCase(.uppercase).foregroundStyle(.white)
                if moments.isEmpty {
                    Text("Add photos from this night and they land on the game clock.")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        stat("\(moments.count)", moments.count == 1 ? "photo" : "photos")
                        if !keyPlays.isEmpty || duringCount > 0 { stat("\(duringCount)", "during play") }
                        if nearPlayCount > 0 { stat("\(nearPlayCount)", "within a minute of a play", accent: true) }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 138)
        .background(Color.panel)
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ywt-hero")
    }

    private func stat(_ value: String, _ label: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).displayFont(30).foregroundStyle(accent ? Color.signal : .white)
            Text(label).font(.caption).foregroundStyle(Color.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Timeline

    /// The pinned bar: when you took photos along the game clock, the key plays, and where you are in the report.
    private func timeline(_ beats: [Beat], jump: @escaping (String) -> Void) -> some View {
        let times = timedPhotos
        let lo = min(([kickoff] + times).min() ?? kickoff, kickoff).addingTimeInterval(-600)
        let hi = max(([endTime] + times).max() ?? endTime, endTime).addingTimeInterval(600)
        let span = max(hi.timeIntervalSince(lo), 1)
        let active = beats.first { $0.id == activeId }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(readout(active)).font(.condensed(.subheadline, weight: .heavy)).foregroundStyle(.white).lineLimit(1)
                Spacer(minLength: 8)
                Text(scoreLine(for: active)).font(.condensed(.subheadline, weight: .heavy)).monospacedDigit().foregroundStyle(Color.textSecondary)
            }
            GeometryReader { geo in
                let w = geo.size.width
                let x: (Date) -> CGFloat = { CGFloat($0.timeIntervalSince(lo) / span) * w }
                ZStack(alignment: .bottomLeading) {
                    Canvas { ctx, size in
                        // The game itself, a quiet band.
                        let band = CGRect(x: x(kickoff), y: size.height - 6, width: max(x(endTime) - x(kickoff), 2), height: 3)
                        ctx.fill(Path(roundedRect: band, cornerRadius: 1.5), with: .color(Color.hairline))
                        // Photo density: a bar per ~2 minutes.
                        let bin: TimeInterval = max(span / 64, 60)
                        var counts: [Int: Int] = [:]
                        for t in times { counts[Int(t.timeIntervalSince(lo) / bin), default: 0] += 1 }
                        let peak = max(counts.values.max() ?? 1, 1)
                        for (b, n) in counts {
                            let h = 6 + CGFloat(n) / CGFloat(peak) * (size.height - 20)
                            let rect = CGRect(x: CGFloat(Double(b) * bin / span) * size.width, y: size.height - 8 - h, width: 3, height: h)
                            ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Color.signal.opacity(0.85)))
                        }
                    }
                    ForEach(keyPlays) { play in
                        Circle().fill(Color(hex: "2F6BFF")).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color.ink, lineWidth: 1.5))
                            .position(x: x(play.time), y: geo.size.height - 5)
                    }
                    if let t = active?.time {
                        Rectangle().fill(.white).frame(width: 2, height: geo.size.height)
                            .position(x: x(t), y: geo.size.height / 2)
                    }
                }
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let at = lo.addingTimeInterval(Double(value.location.x / max(w, 1)) * span)
                    let withTime = beats.filter { $0.time != nil }
                    if let nearest = withTime.min(by: { abs($0.time!.timeIntervalSince(at)) < abs($1.time!.timeIntervalSince(at)) }) {
                        activeId = nearest.id
                        jump(nearest.id)
                    }
                })
            }
            .frame(height: 44)
            .accessibilityElement()
            .accessibilityLabel("Game timeline with your photos")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.ink.opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
        .accessibilityIdentifier("ywt-timeline")
    }

    private func readout(_ beat: Beat?) -> String {
        guard let beat else { return "Your night" }
        switch beat.kind {
        case .before: return "Before the game"
        case .opening: return "Kickoff"
        case .play(let p): return [p.period, Self.clock(p.time, tz)].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
        case .after: return "After the final whistle"
        case .untimed: return "More photos"
        }
    }

    private func scoreLine(for beat: Beat?) -> String {
        guard let beat else { return "" }
        switch beat.kind {
        case .play(let p): return score(p)
        case .after: return keyPlays.last.map { score($0) } ?? ""
        default: return ""
        }
    }

    /// Score with the side you were there for first.
    private func score(_ play: Play) -> String {
        library.rootingTeam(game) == game.homeTeamId ? "\(play.homeScore)\u{2013}\(play.awayScore)" : "\(play.awayScore)\u{2013}\(play.homeScore)"
    }

    // MARK: Rows

    @ViewBuilder
    private func row(_ beat: Beat) -> some View {
        switch beat.kind {
        case .before:
            moment(label: "Before", clock: beat.photos.first?.time, title: "Arriving and warming up",
                   detail: nil, scoreText: nil, accent: false, photos: beat.photos, caption: photoSpan(beat.photos, "You took"))
        case .opening:
            moment(label: "KO", clock: kickoff, title: "Kickoff",
                   detail: nil, scoreText: nil, accent: false, photos: beat.photos,
                   caption: beat.photos.isEmpty ? nil : photoSpan(beat.photos, "You took"))
        case .play(let play):
            let mine = library.rootingTeam(game).map { $0 == game.homeTeamId } ?? true
            let scoredForMe = playHelpsMe(play, mine)
            moment(label: play.period.isEmpty ? Self.clock(play.time, tz) : play.period, clock: play.time, title: Self.title(play.text),
                   detail: Self.detail(play.text), scoreText: score(play), accent: scoredForMe, photos: beat.photos,
                   caption: beat.photos.isEmpty ? nil : photoSpan(beat.photos, "You took", after: play.time))
        case .after:
            moment(label: "After", clock: beat.photos.first?.time, title: "After the final whistle",
                   detail: game.homeScore != nil ? finalLine : nil, scoreText: nil, accent: false, photos: beat.photos,
                   caption: photoSpan(beat.photos, "You took"))
        case .untimed:
            moment(label: "More", clock: nil, title: "More from this game", detail: nil, scoreText: nil, accent: false,
                   photos: beat.photos, caption: nil)
        }
    }

    private var finalLine: String? {
        guard let h = game.homeScore, let a = game.awayScore else { return nil }
        return "Final \u{00B7} " + (library.rootingTeam(game) == game.homeTeamId ? "\(h)\u{2013}\(a)" : "\(a)\u{2013}\(h)")
    }

    /// True when the play moved the score toward the side you were there for.
    private func playHelpsMe(_ play: Play, _ rootingHome: Bool) -> Bool {
        guard let i = game.plays.firstIndex(of: play) else { return false }
        let before = i > 0 ? game.plays[i - 1] : nil
        let dh = play.homeScore - (before?.homeScore ?? 0)
        let da = play.awayScore - (before?.awayScore ?? 0)
        return rootingHome ? dh > da : da > dh
    }

    private func moment(label: String, clock: Date?, title: String, detail: String?, scoreText: String?, accent: Bool,
                        photos: [YouWereThereView.PhotoMoment], caption: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(label).font(.condensed(.title3, weight: .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                if let clock { Text(Self.clock(clock, tz)).font(.caption2).foregroundStyle(Color.textTertiary).monospacedDigit() }
            }
            .frame(width: 52)
            Circle().fill(accent ? Color.signal : Color.textTertiary).frame(width: 10, height: 10).padding(.top, 8)
                .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(width: 2).offset(y: 18) }
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.condensed(.headline, weight: .heavy)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if let scoreText {
                        Text(scoreText).font(.condensed(.title3, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(accent ? Color.signal : .white)
                    }
                }
                if let detail { Text(detail).font(.subheadline).foregroundStyle(Color.textSecondary).fixedSize(horizontal: false, vertical: true) }
                if let caption {
                    Label(caption, systemImage: "camera.fill").font(.footnote.weight(.semibold)).foregroundStyle(Color.signal)
                }
                if !photos.isEmpty { strip(photos) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func strip(_ photos: [YouWereThereView.PhotoMoment]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(photos) { m in
                    Button {
                        if let i = moments.firstIndex(where: { $0.ref == m.ref }) { viewing = PhotoViewerItem(id: i) }
                    } label: {
                        VStack(spacing: 4) {
                            Color.panelRaised.frame(width: 104, height: 78)
                                .overlay { PhotoView(ref: m.ref) }
                                .clipShape(.rect(cornerRadius: 8))
                            if let t = m.time { Text(Self.clockSeconds(t, tz)).font(.caption2).foregroundStyle(Color.textTertiary).monospacedDigit() }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(m.time.map { "Photo at \(Self.clock($0, tz))" } ?? "Photo")
                    .accessibilityIdentifier("ywt-photo-\(m.index)")
                }
            }
        }
        .scrollClipDisabled()
    }

    /// "You took 4 photos in the next 3 minutes" / "You took 12 photos between 10:40 and 11:55".
    private func photoSpan(_ photos: [YouWereThereView.PhotoMoment], _ lead: String, after: Date? = nil) -> String? {
        guard !photos.isEmpty else { return nil }
        let noun = photos.count == 1 ? "photo" : "photos"
        let times = photos.compactMap(\.time)
        guard let first = times.min(), let last = times.max() else { return "\(lead) \(photos.count) \(noun)" }
        if let after {
            let lag = Int(first.timeIntervalSince(after).rounded())
            if photos.count == 1 { return lag < 60 ? "\(lead) a photo \(max(lag, 0)) seconds later" : "\(lead) a photo \(lag / 60) min later" }
            let mins = max(Int((last.timeIntervalSince(first) / 60).rounded()), 1)
            return "\(lead) \(photos.count) \(noun) in the next \(mins) min"
        }
        if photos.count == 1 { return "\(lead) a photo at \(Self.clock(first, tz))" }
        return "\(lead) \(photos.count) \(noun), \(Self.clock(first, tz)) to \(Self.clock(last, tz))"
    }

    // MARK: Text

    /// "Goal! Bosnia and Herzegovina 2, Qatar 1. Hassan Al Haydos (Qatar) right footed shot from very close range..." becomes the scorer.
    private static func title(_ text: String) -> String {
        let t = stripScoreSentence(text)
        if let paren = t.range(of: " (") { return String(t[..<paren.lowerBound]) }
        return t.split(separator: ".", maxSplits: 1).first.map(String.init) ?? t
    }

    private static func detail(_ text: String) -> String? {
        let t = stripScoreSentence(text)
        guard let paren = t.range(of: ") ") else { return nil }
        var rest = String(t[paren.upperBound...])
        if rest.hasSuffix(".") { rest.removeLast() }
        return rest.isEmpty ? nil : rest.prefix(1).uppercased() + rest.dropFirst()
    }

    private static func stripScoreSentence(_ text: String) -> String {
        guard text.hasPrefix("Goal!") || text.hasPrefix("Own Goal") else { return text }
        let range = text.range(of: #"^(Goal!|Own Goal[^.]*\.)\s*.*?\d+, .*?\d+\.\s*"#, options: .regularExpression)
        return range.map { String(text[$0.upperBound...]) }.flatMap { $0.isEmpty ? nil : $0 } ?? text
    }

    static func clock(_ date: Date, _ tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    static func clockSeconds(_ date: Date, _ tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "h:mm:ss"
        return f.string(from: date)
    }
}
