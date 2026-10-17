import SwiftUI
import Charts

/// 06 · You were there. A photo with a broadcast lower third, the win
/// probability curve as a scrubber, and the three plays that mattered.
struct YouWereThereView: View {
    let gameId: String

    @Environment(Library.self) private var library
    @State private var selection: Date?

    var body: some View {
        if let game = library.game(gameId) {
            content(game)
        } else {
            ContentUnavailableView("Game not found", systemImage: "ticket")
                .inkBackground()
        }
    }

    private func content(_ game: GameEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                photo(game)
                if game.winProbability.count > 1 {
                    ProbabilityCurve(game: game,
                                     rootingIsHome: library.rootingTeam(game) == game.homeTeamId || game.awayTeamId == nil,
                                     accent: library.team(library.rootingTeam(game))?.accent ?? Color.signal,
                                     selection: $selection)
                        .frame(height: 210)
                        .accessibilityIdentifier("ywt-chart")
                }
                plays(game)
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .inkBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ScoreBug(game: game, showFinal: true)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText(game)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
    }

    // MARK: Photo with lower third

    private func photo(_ game: GameEntry) -> some View {
        let tz = library.venue(game.venueId)?.tz ?? .current
        let finalTime = game.plays.last?.time
        let moment = game.savedMoments.last ?? finalTime
        return ZStack(alignment: .bottomLeading) {
            Group {
                if let last = game.photos.last {
                    PhotoView(ref: last)
                } else {
                    GameBackdrop(game: game)
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
                    Text(Self.caption(moment: moment, final: finalTime, hasSaved: !game.savedMoments.isEmpty))
                        .font(.condensed(.subheadline, weight: .heavy))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .background(Color.ink.opacity(0.88))
                }
                .accessibilityElement(children: .combine)
            }
        }
        .clipShape(.rect(cornerRadius: 14))
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

    private func shareText(_ game: GameEntry) -> String {
        let venue = library.venue(game.venueId)
        return "\(headlineText(game, library))\n\(venue?.name ?? "") · I was there."
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
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.ink, lineWidth: 2))
                    }
            }
            if let finalPlay = game.plays.last, domain.contains(finalPlay.time) {
                PointMark(x: .value("Time", finalPlay.time), y: .value("Win probability", value(at: finalPlay.time)))
                    .symbol {
                        FinalPin(photo: game.photos.last)
                    }
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
            AxisMarks(values: tickList.map(\.0)) { value in
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
        .accessibilityValue("Final \(Int((points.last?.value ?? 0.5) * 100)) percent")
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
