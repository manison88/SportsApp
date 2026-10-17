import SwiftUI
import Charts

// MARK: - Model

/// A game's win-probability series from the fan's perspective, with key moments
/// and the fan's photos placed on the curve at the second they were taken.
struct WinProbabilityModel {
    struct Sample: Identifiable { let id: Int; let minute: Double; let p: Double }

    struct Moment: Identifiable {
        let event: GameEvent
        let number: Int
        let minute: Double
        let p: Double
        let isFan: Bool
        var id: String { event.id }
    }

    struct Pin: Identifiable {
        let photo: PhotoAsset
        let minute: Double
        let p: Double
        /// The most recent event before the shutter, for "taken 40s after …".
        let after: GameEvent?
        var id: String { photo.id }
        var delta: TimeInterval? { after.map { photo.creationDate.timeIntervalSince($0.timestamp) } }
    }

    struct Tick { let minute: Double; let label: String }

    let game: Game
    let fanIsHome: Bool
    let samples: [Sample]
    let moments: [Moment]
    let pins: [Pin]
    let ticks: [Tick]
    let xDomain: ClosedRange<Double>
    let duration: Double

    init(game: Game, store: MockStore = .shared) {
        let isHome = store.perspectiveIsHome(for: game)
        let start = game.startTime
        func minute(_ d: Date) -> Double { d.timeIntervalSince(start) / 60 }
        func fanP(_ homePercent: Double) -> Double { isHome ? homePercent / 100 : 1 - homePercent / 100 }

        let s = game.winProbability.enumerated().map {
            Sample(id: $0.offset, minute: minute($0.element.timestamp), p: fanP($0.element.homeTeamWinProbability))
        }
        func p(at m: Double) -> Double {
            guard let first = s.first, let last = s.last else { return 0.5 }
            if m <= first.minute { return first.p }
            if m >= last.minute { return last.p }
            let i = s.firstIndex { $0.minute >= m } ?? s.count - 1
            let a = s[max(i - 1, 0)], b = s[i]
            let t = b.minute == a.minute ? 0 : (m - a.minute) / (b.minute - a.minute)
            return a.p + (b.p - a.p) * t
        }

        let fanTeamId = isHome ? game.home?.teamId : game.away?.teamId
        let keyEvents = game.events.filter { $0.isKeyMoment && $0.kind != .start }
        let m = keyEvents.enumerated().map { idx, e in
            // place the dot just after the play lands
            Moment(event: e, number: idx + 1, minute: minute(e.timestamp), p: p(at: minute(e.timestamp) + 0.3),
                   isFan: e.teamId == nil || e.teamId == fanTeamId)
        }

        let photos = store.photos(for: game)
        let pinList = photos.map { photo -> Pin in
            let pm = minute(photo.creationDate)
            let prior = game.events.last { $0.timestamp <= photo.creationDate }
            return Pin(photo: photo, minute: pm, p: p(at: pm), after: prior)
        }

        let dur = game.events.last.map { minute($0.timestamp) } ?? 180
        let lo = min(0, (pinList.map(\.minute).min() ?? 0) - 4)
        let hi = max(dur + 4, (pinList.map(\.minute).max() ?? dur) + 4)

        var t = game.periods.map { Tick(minute: minute($0.timestamp), label: $0.label) }
        if t.count > 5 { t = t.enumerated().filter { $0.offset % 2 == 0 }.map(\.element) }

        self.game = game
        self.fanIsHome = isHome
        self.samples = s
        self.moments = m
        self.pins = pinList
        self.ticks = t
        self.xDomain = lo...hi
        self.duration = dur
    }

    func label(forMinute m: Double) -> String {
        ticks.min { abs($0.minute - m) < abs($1.minute - m) }?.label ?? ""
    }

    /// Largest single jump in the fan's win probability and the play behind it.
    var biggestSwing: (delta: Double, event: GameEvent?) {
        var best = (delta: 0.0, minute: 0.0)
        for (a, b) in zip(samples, samples.dropFirst()) where abs(b.p - a.p) > abs(best.delta) {
            best = (b.p - a.p, b.minute)
        }
        let start = game.startTime
        let e = game.events.last { $0.timestamp.timeIntervalSince(start) / 60 <= best.minute }
        return (best.delta, e)
    }

    var leadChanges: Int {
        var count = 0
        var last = 0
        for e in game.events {
            let lead = (e.homeScore > e.awayScore) ? 1 : (e.homeScore < e.awayScore ? -1 : 0)
            if lead != 0 && last != 0 && lead != last { count += 1 }
            if lead != 0 { last = lead }
        }
        return count
    }
}

// MARK: - Chart

struct WinProbabilityChart: View {
    let model: WinProbabilityModel
    let fanColor: Color
    let rivalColor: Color
    @Binding var selectedPhotoID: String?
    var compact = false

    private let headroom = 1.17

    var body: some View {
        Chart {
            RuleMark(y: .value("Even", 0.5))
                .foregroundStyle(Palette.hairlineStrong)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))

            if !compact {
                ForEach(model.moments) { m in
                    RuleMark(x: .value("Minute", m.minute), yStart: .value("Low", 0.0), yEnd: .value("High", 1.06))
                        .foregroundStyle(.white.opacity(0.09))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }

            ForEach(model.samples) { s in
                LineMark(x: .value("Minute", s.minute), y: .value("Win probability", s.p))
                    .foregroundStyle(Palette.textPrimary)
                    .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2.2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)
            }

            ForEach(model.moments) { m in
                PointMark(x: .value("Minute", m.minute), y: .value("Win probability", m.p))
                    .symbolSize(compact ? 12 : 34)
                    .foregroundStyle(m.isFan ? fanColor : rivalColor)
            }
        }
        .chartXScale(domain: model.xDomain)
        .chartYScale(domain: (compact ? -0.02 : -0.04)...(compact ? 1.04 : headroom))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: model.ticks.map(\.minute)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Palette.hairline)
                AxisValueLabel {
                    if let m = value.as(Double.self) {
                        Text(model.label(forMinute: m))
                            .font(WType.micro)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0.0, 0.5, 1.0]) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v == 0.5 ? "50%" : "\(Int(v * 100))")
                            .font(WType.micro)
                            .monospacedDigit()
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
        }
        .chartXAxis(compact ? .hidden : .automatic)
        .chartYAxis(compact ? .hidden : .automatic)
        .chartBackground { proxy in
            GeometryReader { geo in
                if let anchor = proxy.plotFrame {
                    fills(proxy: proxy, plot: geo[anchor], size: geo.size)
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let anchor = proxy.plotFrame {
                    pinsAndBadges(proxy: proxy, plot: geo[anchor])
                }
            }
        }
    }

    // MARK: Fill + glow

    private func points(_ proxy: ChartProxy, _ plot: CGRect) -> [CGPoint] {
        model.samples.compactMap { s in
            guard let x = proxy.position(forX: s.minute), let y = proxy.position(forY: s.p) else { return nil }
            return CGPoint(x: plot.minX + x, y: plot.minY + y)
        }
    }

    @ViewBuilder
    private func fills(proxy: ChartProxy, plot: CGRect, size: CGSize) -> some View {
        let pts = points(proxy, plot)
        let midY = plot.minY + (proxy.position(forY: 0.5) ?? plot.height / 2)
        let topY = plot.minY + (proxy.position(forY: 1.0) ?? 0)
        let botY = plot.minY + (proxy.position(forY: 0.0) ?? plot.height)
        let H = max(size.height, 1)
        let area = Path { p in
            guard let first = pts.first, let last = pts.last else { return }
            p.move(to: CGPoint(x: first.x, y: midY))
            for pt in pts { p.addLine(to: pt) }
            p.addLine(to: CGPoint(x: last.x, y: midY))
            p.closeSubpath()
        }
        let line = Path { p in
            guard let first = pts.first else { return }
            p.move(to: first)
            for pt in pts.dropFirst() { p.addLine(to: pt) }
        }
        let gradient = LinearGradient(stops: [
            .init(color: fanColor.opacity(0.62), location: max(0, topY / H)),
            .init(color: fanColor.opacity(0.04), location: min(max(0, midY / H - 0.001), 1)),
            .init(color: rivalColor.opacity(0.04), location: min(midY / H + 0.001, 1)),
            .init(color: rivalColor.opacity(0.5), location: min(botY / H, 1)),
        ], startPoint: .top, endPoint: .bottom)

        ZStack {
            // pregame / postgame bands
            if !compact, let x0 = proxy.position(forX: 0.0), let x1 = proxy.position(forX: model.duration) {
                Rectangle()
                    .fill(.white.opacity(0.025))
                    .frame(width: max(0, x0), height: botY - topY)
                    .position(x: plot.minX + x0 / 2, y: (topY + botY) / 2)
                Rectangle()
                    .fill(.white.opacity(0.025))
                    .frame(width: max(0, plot.width - x1), height: botY - topY)
                    .position(x: plot.minX + (x1 + plot.width) / 2, y: (topY + botY) / 2)
            }
            area.fill(gradient)
            line.stroke(fanColor, style: StrokeStyle(lineWidth: compact ? 4 : 7, lineCap: .round, lineJoin: .round))
                .blur(radius: compact ? 4 : 9)
                .opacity(0.7)
        }
    }

    // MARK: Moments + photo pins

    @ViewBuilder
    private func pinsAndBadges(proxy: ChartProxy, plot: CGRect) -> some View {
        if !compact {
            let badges = momentBadges(proxy, plot)
            ForEach(badges, id: \.moment.id) { b in
                Text("\(b.moment.number)")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(b.moment.isFan ? Palette.ink : Palette.textPrimary)
                    .frame(width: 17, height: 17)
                    .background(Circle().fill(b.moment.isFan ? fanColor : rivalColor.opacity(0.85)))
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 1.5))
                    .position(b.point)
            }
        }
        // stems alternate by original order; the selected pin draws last, on top
        let indexed = Array(model.pins.enumerated())
        let ordered = indexed.filter { $0.element.id != selectedPhotoID } + indexed.filter { $0.element.id == selectedPhotoID }
        ForEach(ordered, id: \.element.id) { index, pin in
            if let x = proxy.position(forX: pin.minute), let y = proxy.position(forY: pin.p) {
                PhotoPinView(pin: pin, game: model.game,
                             anchor: CGPoint(x: plot.minX + x, y: plot.minY + y),
                             hangsDown: pin.p > 0.6,
                             stem: compact ? 0 : (index % 2 == 0 ? 30 : 58),
                             isSelected: pin.id == selectedPhotoID,
                             compact: compact)
                    .onTapGesture {
                        withAnimation(Motion.snappy) { selectedPhotoID = pin.id }
                    }
            }
        }
    }

    private struct Badge { let moment: WinProbabilityModel.Moment; let point: CGPoint }

    /// Numbered moment badges along the top, stacked into a second row on collision.
    private func momentBadges(_ proxy: ChartProxy, _ plot: CGRect) -> [Badge] {
        let rowY = [plot.minY + (proxy.position(forY: 1.105) ?? 0), plot.minY + (proxy.position(forY: 1.105) ?? 0) - 19]
        var lastX = [-CGFloat.infinity, -CGFloat.infinity]
        var out: [Badge] = []
        for m in model.moments {
            guard let x = proxy.position(forX: m.minute) else { continue }
            let px = plot.minX + x
            let row = px - lastX[0] >= 19 ? 0 : 1
            lastX[row] = px
            out.append(Badge(moment: m, point: CGPoint(x: px, y: rowY[row])))
        }
        return out
    }
}

/// A photo thumbnail hung from the curve on a thin stem.
private struct PhotoPinView: View {
    let pin: WinProbabilityModel.Pin
    let game: Game
    let anchor: CGPoint
    let hangsDown: Bool
    let stem: CGFloat
    let isSelected: Bool
    let compact: Bool

    var body: some View {
        let d: CGFloat = compact ? 9 : (isSelected ? 54 : 34)
        let dir: CGFloat = hangsDown ? 1 : -1
        let thumbCenter = CGPoint(x: anchor.x, y: anchor.y + dir * (stem + d / 2))
        ZStack {
            if !compact {
                Path { p in
                    p.move(to: anchor)
                    p.addLine(to: CGPoint(x: anchor.x, y: anchor.y + dir * stem))
                }
                .stroke(isSelected ? Palette.signal : .white.opacity(0.55), lineWidth: isSelected ? 1.5 : 1)

                Circle()
                    .fill(isSelected ? Palette.signal : .white)
                    .frame(width: 7, height: 7)
                    .position(anchor)

                StadiumPhoto(photo: pin.photo, game: game, grain: 0.05)
                    .frame(width: d, height: d)
                    .clipShape(RoundedRectangle(cornerRadius: d * 0.3, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: d * 0.3, style: .continuous)
                            .strokeBorder(isSelected ? Palette.signal : .white.opacity(0.9), lineWidth: isSelected ? 2.5 : 1.5)
                    }
                    .shadow(color: isSelected ? Palette.signal.opacity(0.6) : .black.opacity(0.6), radius: isSelected ? 14 : 6)
                    .position(thumbCenter)
            } else {
                Circle()
                    .fill(Palette.signal)
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 1.5))
                    .frame(width: d, height: d)
                    .position(anchor)
            }
        }
        .contentShape(Rectangle().size(width: d + 20, height: stem + d + 20)
            .offset(x: anchor.x - (d + 20) / 2, y: hangsDown ? anchor.y : anchor.y - stem - d - 20))
        .accessibilityElement()
        .accessibilityLabel("Photo taken at \(pin.photo.creationDate.formatted(date: .omitted, time: .shortened))")
        .accessibilityAddTraits(.isButton)
    }
}
