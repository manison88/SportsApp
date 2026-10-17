import SwiftUI

/// Screen 7 — "You were there."
/// Signature moment: the game's win-probability curve with your own photos
/// hung from it at the exact second you took them.
struct YouWereThereScreen: View {
    let game: Game
    private let store: MockStore
    private let venue: Venue
    private let pair: TeamPair?
    private let fan: Team?
    private let rival: Team?
    private let model: WinProbabilityModel

    @State private var selectedPhotoID: String?
    @Environment(\.dismiss) private var dismiss

    init(gameID: String = MockStore.worldSeriesGame5, store: MockStore = .shared) {
        let game = store.game(gameID)!
        self.game = game
        self.store = store
        venue = store.venue(for: game)
        let pair = store.pair(for: game)
        self.pair = pair
        let fan = store.perspectiveTeam(for: game)
        self.fan = fan
        rival = pair.map { $0.home.id == fan?.id ? $0.away : $0.home }
        let model = WinProbabilityModel(game: game, store: store)
        self.model = model
        // Default to the shot taken right after the game ended, else a favorite.
        let defaultPin = model.pins.first { $0.after?.kind == .final }
            ?? model.pins.first { $0.photo.isFavorite }
            ?? model.pins.last
        _selectedPhotoID = State(initialValue: defaultPin?.id)
    }

    private var fanColor: Color { fan?.accentColor ?? Palette.signal }
    private var rivalColor: Color { rival?.accentColor ?? Palette.textTertiary }
    private var selectedPin: WinProbabilityModel.Pin? { model.pins.first { $0.id == selectedPhotoID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 64)

                chartCard
                    .padding(.top, Space.xl)
                    .padding(.horizontal, Space.gutter - 8)

                if let pin = selectedPin {
                    SelectedPhotoCard(pin: pin, game: game, store: store, fan: fan)
                        .id(pin.id)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .padding(.top, Space.l)
                        .padding(.horizontal, Space.gutter)
                }

                statRow
                    .padding(.top, Space.section)
                    .padding(.horizontal, Space.gutter)

                nightTimeline
                    .padding(.top, Space.section)
                    .padding(.horizontal, Space.gutter)

                Text("Win probability via \(GameMemoryDetailScreen.providerName(game.source.provider)) · Photo times from your library, never uploaded")
                    .font(WType.caption)
                    .foregroundStyle(Palette.textQuaternary)
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.xl)
                    .padding(.bottom, Space.xxxl)
            }
        }
        .scrollIndicators(.hidden)
        .background {
            ZStack(alignment: .top) {
                Palette.ink
                (pair?.wash ?? LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 520)
                    .opacity(0.55)
                    .blur(radius: 40)
                GrainOverlay(intensity: 0.07)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            HStack {
                ChromeButton(symbol: "chevron.left") { dismiss() }
                Spacer()
                ChromeButton(symbol: "square.and.arrow.up")
            }
            .padding(.horizontal, Space.s)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text([game.competition, Fmt.shortDate(game.startTime, tz: venue.tz)].compactMap { $0 }.joined(separator: "  ·  "))
                .eyebrow(Palette.signal)

            Text("You were there.")
                .font(WType.heroTitle)
                .tracking(Tracking.display)
                .foregroundStyle(Palette.textPrimary)

            Text("\(venue.name). \(game.headline)")
                .font(WType.display(19))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let pair, let home = game.home, let away = game.away {
                HStack(spacing: Space.s) {
                    TeamMonogram(team: pair.away, size: Size.monogramSmall, dimmed: away.score < home.score)
                    Text("\(away.score)")
                        .font(WType.score(30))
                        .foregroundStyle(away.score > home.score ? Palette.textPrimary : Palette.textTertiary)
                    Text("–").font(WType.score(24)).foregroundStyle(Palette.textQuaternary)
                    Text("\(home.score)")
                        .font(WType.score(30))
                        .foregroundStyle(home.score > away.score ? Palette.textPrimary : Palette.textTertiary)
                    TeamMonogram(team: pair.home, size: Size.monogramSmall, dimmed: home.score < away.score)
                    Spacer()
                    Pill(text: "Final", tint: Palette.textSecondary)
                }
                .padding(.top, Space.xxs)
            }
        }
    }

    // MARK: Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Circle().fill(fanColor).frame(width: 7, height: 7)
                    Text("\(fan?.displayName ?? "Home") win probability")
                }
                .eyebrow(Palette.textSecondary)
                Spacer()
                if let pin = selectedPin {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(Int((pin.p * 100).rounded()))%")
                            .font(WType.score(28, weight: .bold))
                            .foregroundStyle(Palette.signal)
                            .contentTransition(.numericText(value: pin.p))
                        Text("when you took it")
                            .font(WType.caption)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 8)

            WinProbabilityChart(model: model, fanColor: fanColor, rivalColor: rivalColor,
                                selectedPhotoID: $selectedPhotoID.animation(Motion.snappy))
                .frame(height: 300)
                .padding(.top, Space.s)

            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill").font(.system(size: 10))
                Text("Tap a photo to relive the moment")
            }
            .eyebrow(small: true)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Space.m)
        .padding(.horizontal, Space.xs)
        .card(radius: Radius.card, fill: Palette.surface.opacity(0.85))
    }

    // MARK: Stats

    private var statRow: some View {
        let swing = model.biggestSwing
        return HStack(alignment: .top, spacing: 0) {
            statBlock(value: "\(swing.delta >= 0 ? "+" : "−")\(Int(abs(swing.delta * 100).rounded()))%",
                      label: "Biggest swing",
                      detail: swing.event?.shortLabel ?? "—")
            Rectangle().fill(Palette.hairline).frame(width: Size.hairline, height: 70)
            statBlock(value: "\(model.pins.count)", label: "Your photos",
                      detail: "\(model.pins.filter { $0.photo.isFavorite }.count) favorites")
            Rectangle().fill(Palette.hairline).frame(width: Size.hairline, height: 70)
            statBlock(value: "\(model.leadChanges)", label: "Lead changes",
                      detail: "\(Fmt.shortSpan(game.duration)) of game")
        }
    }

    private func statBlock(value: String, label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(WType.statNumber)
                .tracking(Tracking.score)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).eyebrow(small: true)
            Text(detail)
                .font(WType.caption)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.s)
    }

    // MARK: Night timeline

    private enum Entry: Identifiable {
        case moment(WinProbabilityModel.Moment)
        case play(GameEvent)
        case photo(WinProbabilityModel.Pin)

        var id: String {
            switch self {
            case .moment(let m): "m-\(m.id)"
            case .play(let e): "e-\(e.id)"
            case .photo(let p): "p-\(p.id)"
            }
        }

        var date: Date {
            switch self {
            case .moment(let m): m.event.timestamp
            case .play(let e): e.timestamp
            case .photo(let p): p.photo.creationDate
            }
        }
    }

    private var entries: [Entry] {
        let momentIDs = Set(model.moments.map(\.id))
        let plays = game.events.filter { !momentIDs.contains($0.id) }.map(Entry.play)
        let all = model.moments.map(Entry.moment) + plays + model.pins.map(Entry.photo)
        return all.sorted { $0.date < $1.date }
    }

    private var nightTimeline: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SectionHeader(eyebrow: "The night, as it happened", title: "Your view of it",
                          trailing: game.memory.seat)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(entries) { entry in
                    switch entry {
                    case .moment(let m):
                        TimelineMomentRow(moment: m, game: game, venue: venue, pair: pair,
                                          color: m.isFan ? fanColor : rivalColor)
                    case .play(let e):
                        TimelinePlayRow(event: e, venue: venue)
                    case .photo(let p):
                        TimelinePhotoRow(pin: p, game: game, venue: venue,
                                         isSelected: p.id == selectedPhotoID) {
                            withAnimation(Motion.snappy) { selectedPhotoID = p.id }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Selected photo

private struct SelectedPhotoCard: View {
    let pin: WinProbabilityModel.Pin
    let game: Game
    let store: MockStore
    let fan: Team?

    var body: some View {
        let venue = store.venue(for: game)
        let pair = store.pair(for: game)
        let score = pin.after
        ZStack(alignment: .bottomLeading) {
            StadiumPhoto(photo: pin.photo, game: game, grain: 0.12)
                .aspectRatio(4.0 / 3.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
            BottomScrim(color: .black)
                .frame(height: 220)
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill").font(.system(size: 10, weight: .bold))
                    Text(Fmt.time(pin.photo.creationDate, tz: venue.tz, seconds: true))
                        .monospacedDigit()
                    if pin.photo.isLivePhoto { Text("· Live") }
                }
                .eyebrow(Palette.signal)

                Text(Self.caption(for: pin, game: game))
                    .font(WType.display(27))
                    .tracking(Tracking.display)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Space.xs) {
                    if let pair, let score {
                        Text("\(pair.away.displayName) \(score.awayScore), \(pair.home.displayName) \(score.homeScore)")
                    }
                    if let w = game.weather, !game.isIndoor {
                        Text("·")
                        Text("\(w.temperatureText) \(w.condition.lowercased())")
                    }
                }
                .font(WType.footnote)
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(Space.l)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.hairlineStrong, lineWidth: Size.hairline)
        }
        .shadow(color: (fan?.accentColor ?? Palette.signal).opacity(0.25), radius: 30, y: 12)
    }

    static func caption(for pin: WinProbabilityModel.Pin, game: Game) -> String {
        guard let first = game.events.first else { return "Taken from your seat." }
        if pin.photo.creationDate < first.timestamp {
            return "Taken \(Fmt.span(first.timestamp.timeIntervalSince(pin.photo.creationDate))) before \(first.phrase)."
        }
        guard let after = pin.after, let delta = pin.delta else { return "Taken from your seat." }
        if after.kind == .final && delta > 300 {
            return "Taken \(Fmt.span(delta)) after \(after.phrase). Nobody had left."
        }
        return "Taken \(Fmt.span(delta)) after \(after.phrase)."
    }
}

// MARK: - Timeline rows

private enum TimelineLayout {
    /// Width of the leading column shared by moment badges, play dots and photo thumbnails.
    static let marker: CGFloat = 44
}

private struct TimelineMomentRow: View {
    let moment: WinProbabilityModel.Moment
    let game: Game
    let venue: Venue
    let pair: TeamPair?
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Text("\(moment.number)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(moment.isFan ? Palette.ink : Palette.textPrimary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(color))
                .shadow(color: color.opacity(0.6), radius: 8)
                .frame(width: TimelineLayout.marker)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(periodLabel).eyebrow(color)
                    Spacer()
                    Text(Fmt.time(moment.event.timestamp, tz: venue.tz))
                        .font(WType.caption).monospacedDigit()
                        .foregroundStyle(Palette.textTertiary)
                }
                Text(moment.event.description)
                    .font(WType.callout)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(Int((moment.p * 100).rounded()))% after this play")
                    .font(WType.caption)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.vertical, Space.s)
    }

    private var periodLabel: String {
        let p = moment.event.period
        if game.sport == .baseball, let n = Int(p) {
            // "Bot 4th"
            return [moment.event.clock, "\(n)\(Self.suffix(n))"].compactMap { $0 }.joined(separator: " ")
        }
        return [p, moment.event.clock].compactMap { $0 }.joined(separator: " · ")
    }

    static func suffix(_ n: Int) -> String {
        switch n % 10 {
        case 1 where n % 100 != 11: "st"
        case 2 where n % 100 != 12: "nd"
        case 3 where n % 100 != 13: "rd"
        default: "th"
        }
    }
}

private struct TimelinePlayRow: View {
    let event: GameEvent
    let venue: Venue

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Circle()
                .fill(Palette.textQuaternary)
                .frame(width: 5, height: 5)
                .frame(width: TimelineLayout.marker)
            Text(event.description)
                .font(WType.footnote)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Space.s)
            Text(Fmt.time(event.timestamp, tz: venue.tz))
                .font(WType.caption).monospacedDigit()
                .foregroundStyle(Palette.textQuaternary)
        }
        .padding(.vertical, Space.xs)
    }
}

private struct TimelinePhotoRow: View {
    let pin: WinProbabilityModel.Pin
    let game: Game
    let venue: Venue
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Space.m) {
                StadiumPhoto(photo: pin.photo, game: game, grain: 0.05)
                    .frame(width: TimelineLayout.marker, height: TimelineLayout.marker)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? Palette.signal : Palette.hairlineStrong, lineWidth: isSelected ? 2 : Size.hairline)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text("You took a photo").eyebrow(isSelected ? Palette.signal : Palette.textTertiary, small: true)
                    Text(SelectedPhotoCard.caption(for: pin, game: game))
                        .font(WType.subhead)
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Space.s)
                Text(Fmt.time(pin.photo.creationDate, tz: venue.tz))
                    .font(WType.caption).monospacedDigit()
                    .foregroundStyle(Palette.textQuaternary)
            }
            .padding(.vertical, Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview {
    NavigationStack {
        YouWereThereScreen()
    }
}
