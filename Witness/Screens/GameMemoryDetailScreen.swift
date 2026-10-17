import SwiftUI

/// Screen 6 — Game memory detail.
/// Signature moment: a full-bleed, parallax hero photo that stretches on
/// pull-down, with the final score set like a broadcast bug beneath it.
struct GameMemoryDetailScreen: View {
    let game: Game
    private let store: MockStore
    private let venue: Venue
    private let pair: TeamPair?
    private let photos: [PhotoAsset]
    private let hero: PhotoAsset?
    private let companions: [Person]
    private let accent: Color

    @Environment(\.dismiss) private var dismiss

    init(gameID: String = MockStore.lambeau2025, store: MockStore = .shared) {
        let game = store.game(gameID)!
        self.game = game
        self.store = store
        venue = store.venue(for: game)
        pair = store.pair(for: game)
        photos = store.photos(for: game)
        hero = photos.first { $0.isFavorite } ?? photos.first
        companions = store.companions(for: game)
        accent = store.perspectiveTeam(for: game)?.accentColor ?? Palette.signal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroHeader
                VStack(alignment: .leading, spacing: Space.section) {
                    scoreboard
                    if !companions.isEmpty { withSection }
                    if let note = game.memory.note { noteSection(note) }
                    photoStrip
                    youWereThereLink
                    momentsSection
                    factsGrid
                    sourceFooter
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, -Space.xl)
                .padding(.bottom, Space.xxxl)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(Palette.ink.ignoresSafeArea())
        .overlay(alignment: .top) { chrome }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    // MARK: Chrome

    private var chrome: some View {
        HStack {
            ChromeButton(symbol: "chevron.left") { dismiss() }
            Spacer()
            ChromeButton(symbol: "heart.fill")
            ChromeButton(symbol: "square.and.arrow.up")
        }
        .padding(.horizontal, Space.s)
    }

    // MARK: Hero

    private var heroHeader: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .scrollView).minY
            let stretch = max(0, minY)
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let hero {
                        StadiumPhoto(photo: hero, game: game, grain: 0.12)
                    } else {
                        pair?.wash ?? LinearGradient(colors: [Palette.surface], startPoint: .top, endPoint: .bottom)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height + stretch)
                // parallax while scrolling up, stretch while pulling down
                .offset(y: minY > 0 ? -minY : -minY * Motion.parallax)

                BottomScrim()
                    .frame(height: geo.size.height * 0.62)
                    .offset(y: minY > 0 ? 0 : -minY * Motion.parallax)

                heroCaption
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.xxl + Space.s)
                    .offset(y: minY > 0 ? 0 : -minY * 0.15)
                    .opacity(1 - min(1, max(0, -minY) / 260))
            }
        }
        .frame(height: Size.heroHeight)
    }

    private var heroCaption: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.xs) {
                if game.memory.tripId != nil {
                    Pill(text: "Road trip", symbol: "car.fill", tint: Palette.signal)
                }
                if let comp = game.competition { Pill(text: comp) }
                if game.provenance == .verified, game.memory.rating == 5 {
                    Pill(text: "All-timer", symbol: "star.fill", tint: Palette.signalSoft)
                }
            }
            Text(game.headline)
                .font(WType.display(36))
                .tracking(Tracking.display)
                .foregroundStyle(Palette.textPrimary)
                .lineSpacing(-1)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.4), radius: 12)
        }
    }

    // MARK: Score

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Text("Final").eyebrow(Palette.textSecondary)
                Spacer()
                Text(Fmt.eyebrowDate(game.startTime, tz: venue.tz)).eyebrow()
            }

            if let pair, let home = game.home, let away = game.away {
                VStack(spacing: 2) {
                    scoreRow(team: pair.away, score: away.score, won: away.score > home.score)
                    scoreRow(team: pair.home, score: home.score, won: home.score > away.score)
                }
            }

            TeamRule(pair: pair, height: 2)
                .opacity(0.8)

            HStack(alignment: .center, spacing: Space.s) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(venue.name)
                        .font(WType.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(venue.cityLine)
                        .font(WType.footnote)
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                if let weather = game.weather {
                    WeatherChip(weather: weather, indoor: game.isIndoor)
                }
            }
        }
        .padding(Space.l)
        .card(radius: Radius.card, fill: Palette.surface)
        .overlay(alignment: .topLeading) {
            // team-color glow bleeding off the card's top edge
            (pair?.gradient ?? LinearGradient(colors: [accent], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
                .padding(.horizontal, Space.xl)
                .blur(radius: 0.5)
                .shadow(color: accent, radius: 10)
        }
    }

    private func scoreRow(team: Team, score: Int, won: Bool) -> some View {
        HStack(spacing: Space.m) {
            TeamMonogram(team: team, size: 46, dimmed: !won)
            VStack(alignment: .leading, spacing: 2) {
                Text(team.displayName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(won ? Palette.textPrimary : Palette.textTertiary)
                Text(team.abbreviation)
                    .eyebrow(small: true)
            }
            Spacer()
            if won {
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(team.accentColor)
            }
            Text("\(score)")
                .font(WType.score(68))
                .tracking(Tracking.score)
                .foregroundStyle(won ? Palette.textPrimary : Palette.textQuaternary)
                .frame(minWidth: 70, alignment: .trailing)
        }
    }

    // MARK: With

    private var withSection: some View {
        let names = ListFormatter.localizedString(byJoining: companions.map(\.name))
        let firstCompanion = companions[0]
        let together = store.games(with: firstCompanion.id).filter { $0.startTime <= game.startTime }.count
        return HStack(spacing: Space.m) {
            CompanionStack(people: companions, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text("With").eyebrow()
                Text(names)
                    .font(WType.display(22))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(firstCompanion.name)’s \(Self.ordinal(together)) game with you")
                    .font(WType.footnote)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
        }
    }

    // MARK: Note

    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("“")
                .font(WType.display(76))
                .foregroundStyle(accent)
                .frame(height: 38, alignment: .top)
                .padding(.bottom, -Space.xs)
            Text(note)
                .font(WType.pullQuote)
                .lineSpacing(6)
                .foregroundStyle(Palette.textPrimary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.xs) {
                Rectangle().fill(accent).frame(width: 18, height: 1)
                Text("Your note · the next morning").eyebrow()
            }
            .padding(.top, Space.xs)
        }
        .padding(.leading, Space.xxs)
    }

    // MARK: Photos

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(eyebrow: "\(photos.count) photos", title: "From your seat", trailing: game.memory.seat)
            ScrollView(.horizontal) {
                LazyHStack(spacing: Space.s) {
                    ForEach(photos) { photo in
                        photoCard(photo)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .padding(.horizontal, -Space.gutter)
        }
    }

    private func photoCard(_ photo: PhotoAsset) -> some View {
        let event = game.events.last { $0.timestamp <= photo.creationDate }
        let period = event.map { e in [e.period, e.clock].compactMap { $0 }.joined(separator: " · ") } ?? "Pregame"
        return VStack(alignment: .leading, spacing: Space.xs) {
            StadiumPhoto(photo: photo, game: game, grain: 0.10)
                .frame(width: 168, height: 224)
                .clipShape(RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if photo.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Circle().fill(.black.opacity(0.35)))
                            .padding(Space.xs)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if photo.isLivePhoto {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.35)))
                            .padding(Space.xs)
                    }
                }
            Text(Fmt.time(photo.creationDate, tz: venue.tz))
                .font(WType.subhead)
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
            Text(photo.creationDate < game.startTime ? "Pregame" : period)
                .eyebrow(small: true)
        }
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(1 - abs(phase.value) * 0.06)
                .opacity(1 - abs(phase.value) * 0.35)
        }
    }

    // MARK: You were there

    private var youWereThereLink: some View {
        NavigationLink {
            YouWereThereScreen(gameID: game.id)
        } label: {
            YouWereTherePreview(game: game, store: store)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Moments

    private var momentsSection: some View {
        let moments = game.keyMoments.filter { $0.kind != .start }
        return VStack(alignment: .leading, spacing: Space.l) {
            SectionHeader(eyebrow: "How it happened", title: "The moments")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(moments.enumerated()), id: \.element.id) { index, event in
                    MomentRow(event: event, game: game, store: store, isLast: index == moments.count - 1)
                }
            }
        }
    }

    // MARK: Facts

    private var factsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)]
        return LazyVGrid(columns: columns, spacing: Space.s) {
            fact(label: "Kickoff", value: Fmt.time(game.startTime, tz: venue.tz), symbol: "clock")
            if let w = game.weather {
                fact(label: "Feels like", value: "\(Int(w.apparentTemperature.rounded()))°", symbol: "thermometer.snowflake",
                     detail: "Wind \(Int(w.windSpeed10m.rounded())) mph")
            }
            if let attendance = game.attendance {
                fact(label: "In the stands", value: Fmt.number(attendance), symbol: "person.3.fill", detail: "Including you")
            }
            fact(label: "From home", value: "\(store.milesFromHome(venue)) mi", symbol: "car.fill",
                 detail: store.trip(game.memory.tripId)?.title)
        }
    }

    private func fact(label: String, value: String, symbol: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                Text(label)
            }
            .eyebrow()
            Text(value)
                .font(WType.score(36, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail ?? " ")
                .font(WType.caption)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.m)
        .card(radius: Radius.photo, fill: Palette.surface)
    }

    private var sourceFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Photos stay on this iPhone", systemImage: "lock.fill")
            Text("Score and plays via \(Self.providerName(game.source.provider)) · Weather via Open-Meteo")
        }
        .font(WType.caption)
        .foregroundStyle(Palette.textQuaternary)
    }

    // MARK: Helpers

    static func ordinal(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    static func providerName(_ id: String) -> String {
        switch id {
        case "mlb-stats-api": "MLB Stats API"
        case "nhl-api-web": "NHL API"
        case "jolpica-f1": "Jolpica-F1"
        case "statsbomb-open-data": "StatsBomb Open Data"
        default: "TheSportsDB"
        }
    }
}

// MARK: - Moment row

private struct MomentRow: View {
    let event: GameEvent
    let game: Game
    let store: MockStore
    let isLast: Bool

    var body: some View {
        let team = store.team(event.teamId)
        let color = team?.accentColor ?? Palette.textTertiary
        HStack(alignment: .top, spacing: Space.m) {
            // rail
            VStack(spacing: 0) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
                    .shadow(color: color.opacity(0.8), radius: 6)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(LinearGradient(colors: [color.opacity(0.5), Palette.hairline], startPoint: .top, endPoint: .bottom))
                        .frame(width: 1)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text([event.period, event.clock].compactMap { $0 }.joined(separator: " · "))
                        .eyebrow(color)
                    Spacer()
                    if let pair = store.pair(for: game) {
                        Text("\(pair.away.abbreviation) \(event.awayScore) – \(event.homeScore) \(pair.home.abbreviation)")
                            .font(WType.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                Text(event.description)
                    .font(WType.callout)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : Space.l)
        }
    }
}

// MARK: - You were there preview card

/// Compact win-probability sparkline with photo dots, linking to screen 7.
struct YouWereTherePreview: View {
    let game: Game
    let store: MockStore
    @State private var selected: String? = nil

    var body: some View {
        let model = WinProbabilityModel(game: game, store: store)
        let fan = store.perspectiveTeam(for: game)
        let pair = store.pair(for: game)
        let rival = pair.map { $0.home.id == fan?.id ? $0.away : $0.home }
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Moment by moment").eyebrow(Palette.signal)
                    Text("You were there.")
                        .font(WType.display(28))
                        .tracking(Tracking.display)
                        .foregroundStyle(Palette.textPrimary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            WinProbabilityChart(model: model,
                                fanColor: fan?.accentColor ?? Palette.signal,
                                rivalColor: rival?.accentColor ?? Palette.textTertiary,
                                selectedPhotoID: $selected,
                                compact: true)
                .frame(height: 84)
                .allowsHitTesting(false)
            Text("Your \(model.pins.count) photos, pinned to the second the game swung.")
                .font(WType.footnote)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(Space.l)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(pair?.wash ?? LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
                        .opacity(0.5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Palette.hairlineStrong, lineWidth: Size.hairline)
                }
        }
    }
}

#Preview {
    NavigationStack {
        GameMemoryDetailScreen()
    }
}
