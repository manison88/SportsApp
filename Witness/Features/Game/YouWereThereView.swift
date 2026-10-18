import SwiftUI
import Charts
import Photos

/// 06 · You were there. A photo with a broadcast lower third, the win
/// probability curve as a scrubber, and the three plays that mattered.
struct YouWereThereView: View {
    let gameId: String

    @Environment(Library.self) private var library
    @State private var selection: Date?
    /// When each of the fan's photos was taken, read from Photos; the photo on show.
    @State private var photoTimes: [PhotoRef: Date] = [:]
    @State private var current: PhotoRef?

    var body: some View {
        if let game = library.game(gameId) {
            content(game)
        } else {
            ContentUnavailableView("Game not found", systemImage: "ticket")
                .inkBackground()
        }
    }

    private func content(_ game: GameEntry) -> some View {
        let moments = photoMoments(game)
        return MatchReportView(game: game, moments: moments)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ScoreBug(game: game, showFinal: true)
            }
            .withoutGlass()
            ToolbarItem(placement: .topBarTrailing) {
                ShareCardSheetLink(title: "You were there",
                                   format: .story,
                                   key: shareKey(game, moments: moments),
                                   variants: { await shareVariants(shareInfo(game, moments: moments)) }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
        .task(id: game.photos) { photoTimes = await PhotoTimes.load(game.photos) }
    }

    // MARK: Photos along the game

    struct PhotoMoment: Identifiable {
        let index: Int
        let ref: PhotoRef
        let time: Date?
        var id: Int { index }
    }

    /// The fan's photos in the order they were taken. Library photos use their real capture time; the bundled sample
    /// photos (which carry none) are spread across the game so the sample shows how this works.
    private func photoMoments(_ game: GameEntry) -> [PhotoMoment] {
        let start = game.plays.first?.time ?? game.winProbability.first?.time
        let end = game.plays.last?.time ?? game.winProbability.last?.time
        let raw: [PhotoMoment] = game.photos.enumerated().map { i, ref in
            var time = photoTimes[ref]
            if time == nil, case .bundled = ref, let start, let end, end > start {
                time = start.addingTimeInterval(end.timeIntervalSince(start) * (Double(i) + 1) / Double(game.photos.count + 1))
            }
            return PhotoMoment(index: i, ref: ref, time: time)
        }
        return raw.sorted { a, b in
            switch (a.time, b.time) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.index < b.index
            }
        }
    }

    private func pins(_ moments: [PhotoMoment]) -> [PhotoPin] {
        moments.compactMap { m in m.time.map { PhotoPin(id: m.index, ref: m.ref, time: $0) } }
    }

    /// The photo on show: the one chosen by scrubbing or swiping, else the last one.
    private func shown(_ moments: [PhotoMoment]) -> PhotoMoment? {
        if let current, let m = moments.first(where: { $0.ref == current }) { return m }
        return moments.last
    }

    // MARK: Photo with lower third

    private func photo(_ game: GameEntry, moments: [PhotoMoment]) -> some View {
        let tz = library.venue(game.venueId)?.tz ?? .current
        let on = shown(moments)
        let finalTime = game.plays.last?.time
        let moment = on?.time ?? game.savedMoments.last ?? finalTime
        let swipe = Binding<Int>(
            get: { moments.firstIndex { $0.ref == on?.ref } ?? max(moments.count - 1, 0) },
            set: { i in
                guard moments.indices.contains(i) else { return }
                current = moments[i].ref
                if let t = moments[i].time { selection = t }
            })
        return ZStack(alignment: .bottomLeading) {
            Group {
                if moments.isEmpty {
                    GameBackdrop(game: game)
                } else {
                    TabView(selection: swipe) {
                        ForEach(Array(moments.enumerated()), id: \.offset) { i, m in
                            PhotoView(ref: m.ref).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipped()

            if let moment {
                HStack(spacing: 0) {
                    Text(Self.clock(moment, tz))
                        .font(.condensed(.subheadline, weight: .heavy))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .frame(minHeight: 34)
                        .background(Color(hex: "2F6BFF"))
                    Text(on?.time != nil ? situation(at: moment, game) : Self.caption(moment: moment, final: finalTime, hasSaved: !game.savedMoments.isEmpty))
                        .font(.condensed(.subheadline, weight: .heavy))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .background(Color.ink.opacity(0.88))
                }
                .accessibilityElement(children: .combine)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if moments.count > 1, let on, let i = moments.firstIndex(where: { $0.ref == on.ref }) {
                Text("\(i + 1) / \(moments.count)")
                    .font(.condensed(.caption, weight: .heavy))
                    .padding(.horizontal, 8).frame(minHeight: 24)
                    .background(.black.opacity(0.55), in: .capsule)
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityIdentifier("ywt-photo")
    }

    /// Where the game stood when a photo was taken: the period and score at the nearest play.
    private func situation(at time: Date, _ game: GameEntry) -> String {
        guard let first = game.plays.first?.time, let last = game.plays.last?.time else { return "During the game" }
        if time < first.addingTimeInterval(-300) { return "Before the game" }
        if time > last.addingTimeInterval(300) { return "After the game" }
        guard let play = game.plays.min(by: { abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time)) }) else {
            return "During the game"
        }
        return "\(play.period) \u{00B7} \(score(play, game))"
    }

    private static func clock(_ date: Date, _ tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    private static func caption(moment: Date, final: Date?, hasSaved: Bool) -> String {
        guard hasSaved, let final else { return final == nil ? "You were here" : "At the final out" }
        let s = Int(moment.timeIntervalSince(final).rounded())
        if s < 0 { return "Before the final out" }
        if s < 5 { return "At the final out" }
        if s < 120 { return "\(s) seconds after the final out" }
        return "\(s / 60) minutes after the final out"
    }

    // MARK: Plays

    @ViewBuilder
    private func plays(_ game: GameEntry) -> some View {
        let list = visiblePlays(game)
        if !list.isEmpty {
            let highlightId = highlighted(game)?.id
            VStack(spacing: 0) {
                ForEach(list) { play in
                    PlayRow(play: play,
                            score: score(play, game),
                            highlighted: play.id == highlightId)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("ywt-plays")
        }
    }

    /// The play nearest the scrubber, or the final play.
    private func highlighted(_ game: GameEntry) -> Play? {
        if let selection {
            return game.plays.min { abs($0.time.timeIntervalSince(selection)) < abs($1.time.timeIntervalSince(selection)) }
        }
        return game.plays.last
    }

    /// Three plays: a window around the highlighted one, else the last three key plays.
    private func visiblePlays(_ game: GameEntry) -> [Play] {
        guard !game.plays.isEmpty else { return [] }
        if selection != nil, let h = highlighted(game), let i = game.plays.firstIndex(of: h) {
            let start = max(0, min(i - 1, game.plays.count - 3))
            return Array(game.plays[start..<min(game.plays.count, start + 3)])
        }
        var key = game.plays.filter(\.isKey)
        if let last = game.plays.last, !key.contains(last) { key.append(last) }
        return Array(key.suffix(3))
    }

    /// Score with the side you were there for first.
    private func score(_ play: Play, _ game: GameEntry) -> String {
        let rootingHome = library.rootingTeam(game) == game.homeTeamId
        return rootingHome ? "\(play.homeScore)–\(play.awayScore)" : "\(play.awayScore)–\(play.homeScore)"
    }

    // MARK: Share card

    /// Everything the share card shows, as plain values.
    private struct ShareInfo {
        var ref: PhotoRef?
        var accent: Color
        var score: String
        var headline: String
        var footer: String
        var period: String
        var playText: String
    }

    private func shareKey(_ game: GameEntry, moments: [PhotoMoment]) -> String {
        let ref = shown(moments)?.ref
        return "\(game.id)|\(ref.map { "\($0)" } ?? "none")|\(game.plays.count)"
    }

    private func shareInfo(_ game: GameEntry, moments: [PhotoMoment]) -> ShareInfo {
        let on = shown(moments)
        // The play closest to the photo on show, else the last key play, else the last play.
        var play: Play?
        if let t = on?.time {
            play = game.plays.min { abs($0.time.timeIntervalSince(t)) < abs($1.time.timeIntervalSince(t)) }
        }
        if play == nil { play = game.plays.last(where: { $0.isKey }) ?? game.plays.last }

        let rootingHome = library.rootingTeam(game) == game.homeTeamId
        var scoreText = ""
        if let hs = game.homeScore, let aw = game.awayScore {
            scoreText = rootingHome ? "\(hs)\u{2013}\(aw)" : "\(aw)\u{2013}\(hs)"
        }

        let venue = library.venue(game.venueId)
        let tz = venue?.tz ?? .current
        let footer = [venue?.name, Fmt.dayAndKickoff(game, in: tz)]
            .compactMap { $0 }.joined(separator: " \u{00B7} ")

        return ShareInfo(ref: on?.ref,
                         accent: library.team(library.rootingTeam(game))?.accent ?? Color.signal,
                         score: scoreText,
                         headline: headlineText(game, library),
                         footer: footer,
                         period: play?.period ?? "",
                         playText: play?.text ?? "")
    }

    @MainActor
    private func shareVariants(_ info: ShareInfo) async -> [ShareCardVariant] {
        var photo: UIImage?
        if let ref = info.ref { photo = await PhotoLoader.load(ref) }
        var out: [ShareCardVariant] = []
        for style in YouWereThereShareCard.Style.allCases {
            out.append(ShareCardVariant(style.name) {
                YouWereThereShareCard(style: style,
                                      photo: photo,
                                      accent: info.accent,
                                      score: info.score,
                                      headline: info.headline,
                                      footer: info.footer,
                                      period: info.period,
                                      playText: info.playText)
            })
        }
        return out
    }
}

/// The 1080x1920 story cards: five looks of the same moment (score, headline, photo, the play you saw).
private struct YouWereThereShareCard: View {
    enum Style: CaseIterable {
        case photo, numeral, field, paper, stub

        var name: String {
            switch self {
            case .photo: "Moment"
            case .numeral: "Numeral"
            case .field: "Color"
            case .paper: "Paper"
            case .stub: "Stub"
            }
        }
    }

    let style: Style
    let photo: UIImage?
    let accent: Color
    let score: String
    let headline: String
    let footer: String
    let period: String
    let playText: String

    private var paperInk: Color { Color(red: 0.07, green: 0.07, blue: 0.08) }
    private var paperBg: Color { Color(red: 0.96, green: 0.95, blue: 0.92) }

    /// The big line: the score, else the headline.
    private var heroText: String { score.isEmpty ? headline : score }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Text("WITNESS")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .tracking(10)
                    .foregroundStyle(style == .paper ? paperInk : Color.white.opacity(0.9))
                    .padding(.top, 40)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Backgrounds

    @ViewBuilder
    private var background: some View {
        switch style {
        case .photo:
            ZStack {
                LinearGradient(colors: [accent.opacity(0.6), .black], startPoint: .top, endPoint: .bottom)
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 1080, height: 1920)
                        .clipped()
                }
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.55), location: 0),
                    .init(color: .black.opacity(0), location: 0.25),
                    .init(color: .black.opacity(0.88), location: 0.65),
                    .init(color: .black, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: 1080, height: 1920)
        case .numeral:
            ZStack(alignment: .top) {
                Color.ink
                LinearGradient(colors: [accent.opacity(0.4), .clear], startPoint: .top, endPoint: .center)
            }
            .frame(width: 1080, height: 1920)
        case .field:
            ZStack {
                accent
                Color.black.opacity(0.22)
            }
            .frame(width: 1080, height: 1920)
        case .paper:
            paperBg.frame(width: 1080, height: 1920)
        case .stub:
            Color.ink.frame(width: 1080, height: 1920)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch style {
        case .photo: photoContent
        case .numeral: numeralContent
        case .field: fieldContent
        case .paper: paperContent
        case .stub: stubContent
        }
    }

    private var label: some View {
        Text("YOU WERE THERE")
            .font(.system(size: 44, weight: .heavy).width(.condensed))
            .tracking(8)
            .foregroundStyle(Color.signal)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func playLine(_ color: Color, size: CGFloat, lines: Int) -> some View {
        Text(period.isEmpty ? playText : "\(period)  \u{00B7}  \(playText)")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(lines)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footerLine(_ color: Color) -> some View {
        Text(footer.uppercased())
            .font(.system(size: 34, weight: .bold).width(.condensed))
            .tracking(4)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    /// 1. Full-bleed photo, type at the bottom.
    private var photoContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            label
            Spacer(minLength: 0)
            Text(heroText)
                .font(.display(score.isEmpty ? 190 : 320))
                .foregroundStyle(.white)
                .lineLimit(score.isEmpty ? 3 : 1)
                .minimumScaleFactor(0.4)
            if !score.isEmpty {
                Text(headline)
                    .font(.system(size: 52, weight: .bold).width(.condensed))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            if !playText.isEmpty { playLine(.white.opacity(0.85), size: 44, lines: 3) }
            if !footer.isEmpty { footerLine(.white.opacity(0.6)) }
        }
    }

    /// 2. Pure type: the score at the largest size the width allows, on ink.
    private var numeralContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            label
            Spacer(minLength: 0)
            Text(heroText)
                .font(.display(score.isEmpty ? 260 : 560))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(score.isEmpty ? 4 : 1)
                .minimumScaleFactor(0.3)
            if !score.isEmpty {
                Text(headline)
                    .font(.system(size: 56, weight: .bold).width(.condensed))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            }
            if !footer.isEmpty { footerLine(.white.opacity(0.6)) }
            Spacer(minLength: 0)
        }
    }

    /// 3. A solid field of the team color; the play is the voice.
    private var fieldContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("YOU WERE THERE")
                .font(.system(size: 44, weight: .heavy).width(.condensed))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !playText.isEmpty {
                Text(playText)
                    .font(.display(150))
                    .foregroundStyle(.white)
                    .lineLimit(5)
                    .minimumScaleFactor(0.4)
            }
            Spacer(minLength: 0)
            if !score.isEmpty {
                Text(score)
                    .font(.display(240))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            Text(headline)
                .font(.system(size: 48, weight: .bold).width(.condensed))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            if !footer.isEmpty { footerLine(.white.opacity(0.75)) }
        }
    }

    /// 4. Paper: off-white, black type, the photo as a print.
    private var paperContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("YOU WERE THERE")
                .font(.system(size: 44, weight: .heavy).width(.condensed))
                .tracking(8)
                .foregroundStyle(paperInk)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 912, height: 620)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 8))
            }
            Text(heroText)
                .font(.display(score.isEmpty ? 190 : 300))
                .monospacedDigit()
                .foregroundStyle(paperInk)
                .lineLimit(score.isEmpty ? 3 : 1)
                .minimumScaleFactor(0.4)
            if !score.isEmpty {
                Text(headline)
                    .font(.system(size: 50, weight: .bold).width(.condensed))
                    .foregroundStyle(paperInk.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            if !footer.isEmpty { footerLine(paperInk.opacity(0.55)) }
            Spacer(minLength: 0)
        }
    }

    /// 5. Data-forward: a ticket stub of ruled rows.
    private var stubContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            label
                .padding(.bottom, 36)
            if !score.isEmpty {
                Text(score)
                    .font(.display(300))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.bottom, 24)
            }
            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 2)
            if !headline.isEmpty { stubRow("GAME", headline, lines: 2) }
            if !footer.isEmpty { stubRow("WHERE", footer, lines: 2) }
            if !period.isEmpty { stubRow("WHEN", period, lines: 1) }
            if !playText.isEmpty { stubRow("PLAY", playText, lines: 4) }
            Spacer(minLength: 0)
        }
    }

    private func stubRow(_ name: String, _ value: String, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.system(size: 30, weight: .bold).width(.condensed))
                .tracking(6)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 52, weight: .bold).width(.condensed))
                .foregroundStyle(.white)
                .lineLimit(lines)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 26)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.3)).frame(height: 2) }
    }
}

private struct PlayRow: View {
    let play: Play
    let score: String
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(play.period)
                .font(.condensed(.caption, weight: .heavy))
                .foregroundStyle(highlighted ? Color.black : Color.textSecondary)
                .frame(minWidth: 30, minHeight: 24)
                .background(highlighted ? Color.white : Color.clear, in: .rect(cornerRadius: 5))
            Text(play.text)
                .font(.subheadline.weight(highlighted ? .semibold : .regular))
                .foregroundStyle(highlighted ? Color.white : Color.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(score)
                .font(.condensed(.headline, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(highlighted ? Color.white : Color.textSecondary)
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

/// Thin win-probability line with a soft fill, round pins on key plays and a
/// photo pin at the final play. Drag across it to scrub through the game.
private struct ProbabilityCurve: View {
    let game: GameEntry
    let rootingIsHome: Bool
    let accent: Color
    let pins: [PhotoPin]
    let shown: PhotoRef?
    @Binding var selection: Date?

    private struct Point: Identifiable {
        let time: Date
        let value: Double
        var id: Date { time }
    }

    private var points: [Point] {
        game.winProbability.map { Point(time: $0.time, value: rootingIsHome ? $0.home : 1 - $0.home) }
    }

    private var domain: ClosedRange<Date> {
        let first = points.first?.time ?? game.date
        let last = max(points.last?.time ?? first, game.plays.last?.time ?? first)
        return first...max(last, first.addingTimeInterval(60))
    }

    /// Photos from before the first play or after the last sit at the ends of the chart.
    private func clamped(_ time: Date) -> Date { min(max(time, domain.lowerBound), domain.upperBound) }

    private func value(at time: Date) -> Double {
        points.min { abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time)) }?.value ?? 0.5
    }

    private var keyPlays: [Play] {
        game.plays.filter { $0.isKey && domain.contains($0.time) }
    }

    /// Evenly spaced period ticks across the game.
    private var ticks: [(Date, String)] {
        let labels: [String] = {
            let n = max(game.lineHome.count, game.sport.periodLabels.count)
            return (0..<n).map { i in i < game.sport.periodLabels.count ? game.sport.periodLabels[i] : "\(i + 1)" }
        }()
        guard !labels.isEmpty else { return [] }
        let start = domain.lowerBound.timeIntervalSinceReferenceDate
        let span = domain.upperBound.timeIntervalSinceReferenceDate - start
        return labels.enumerated().map { i, label in
            (Date(timeIntervalSinceReferenceDate: start + span * (Double(i) + 0.5) / Double(labels.count)), label)
        }
    }

    var body: some View {
        let tickList = ticks
        Chart {
            ForEach(points) { p in
                AreaMark(x: .value("Time", p.time), y: .value("Win probability", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [accent.opacity(0.32), accent.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
            }
            ForEach(points) { p in
                LineMark(x: .value("Time", p.time), y: .value("Win probability", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            RuleMark(y: .value("Even", 0.5))
                .foregroundStyle(Color.hairline)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            ForEach(keyPlays) { play in
                PointMark(x: .value("Time", play.time), y: .value("Win probability", value(at: play.time)))
                    .symbol {
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color.ink, lineWidth: 1.5))
                    }
            }
            if pins.isEmpty, let finalPlay = game.plays.last, domain.contains(finalPlay.time) {
                PointMark(x: .value("Time", finalPlay.time), y: .value("Win probability", value(at: finalPlay.time)))
                    .symbol {
                        FinalPin(photo: game.photos.last)
                    }
            }
            ForEach(pins) { pin in
                let t = clamped(pin.time)
                PointMark(x: .value("Time", t), y: .value("Win probability", value(at: t)))
                    .symbol { PhotoPinView(ref: pin.ref, selected: pin.ref == shown) }
            }
            if let selection {
                RuleMark(x: .value("Selected", selection))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: tickList.map { $0.0 }) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self),
                       let label = tickList.first(where: { abs($0.0.timeIntervalSince(date)) < 1 })?.1 {
                        Text(label)
                            .font(.condensed(.caption, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .chartXSelection(value: $selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Win probability through the game")
        .accessibilityValue(selectedValueText)
        .accessibilityAdjustableAction { direction in
            let times = game.plays.map(\.time)
            guard !times.isEmpty else { return }
            let current = selection.flatMap { s in times.lastIndex { $0 <= s } } ?? times.count - 1
            switch direction {
            case .increment: selection = times[min(current + 1, times.count - 1)]
            case .decrement: selection = times[max(current - 1, 0)]
            @unknown default: break
            }
        }
    }

    private var selectedValueText: String {
        let t = selection ?? game.plays.last?.time ?? domain.upperBound
        let play = game.plays.min { abs($0.time.timeIntervalSince(t)) < abs($1.time.timeIntervalSince(t)) }
        return (play.map { "\($0.period), \($0.text), " } ?? "") + "\(Int((value(at: t) * 100).rounded())) percent"
    }
}

private struct FinalPin: View {
    let photo: PhotoRef?

    var body: some View {
        Group {
            if let photo {
                PhotoView(ref: photo)
            } else {
                Color.white
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }
}


struct PhotoPin: Identifiable {
    let id: Int
    let ref: PhotoRef
    let time: Date
}

/// A photo on the chart: a small round thumbnail, larger and ringed in amber when it is the one on show.
private struct PhotoPinView: View {
    let ref: PhotoRef
    let selected: Bool

    var body: some View {
        PhotoView(ref: ref)
            .frame(width: selected ? 34 : 22, height: selected ? 34 : 22)
            .clipShape(Circle())
            .overlay(Circle().stroke(selected ? Color.signal : Color.white, lineWidth: selected ? 3 : 1.5))
            .shadow(color: .black.opacity(0.5), radius: selected ? 6 : 2)
            .animation(.smooth(duration: 0.2), value: selected)
    }
}

/// When the fan's library photos were taken.
enum PhotoTimes {
    static func load(_ refs: [PhotoRef]) async -> [PhotoRef: Date] {
        let ids: [String] = refs.compactMap { if case .library(let id) = $0 { id } else { nil } }
        guard !ids.isEmpty else { return [:] }
        return await Task.detached { () -> [PhotoRef: Date] in
            var out: [PhotoRef: Date] = [:]
            PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).enumerateObjects { asset, _, _ in
                if let date = asset.creationDate { out[.library(asset.localIdentifier)] = date }
            }
            return out
        }.value
    }
}
