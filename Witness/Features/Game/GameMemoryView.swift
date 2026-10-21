import SwiftUI
import PhotosUI

/// 05 · Game memory. A tall photo hero carries the headline; under it the
/// line score, who you were with, and one action: Play recap.
struct GameMemoryView: View {
    let gameId: String

    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var sharing = false
    @State private var adding: [PhotosPickerItem] = []
    @State private var viewer: PhotoViewerItem?

    /// Short enough that the photos section sits above the tab bar on a normal phone.
    private var heroHeight: CGFloat { min(max(UIScreen.main.bounds.height * 0.43, 340), 440) }

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
            VStack(alignment: .leading, spacing: 18) {
                hero(game)
                if game.sport == .motorsport { scoreBlock(game).gutter() }
                photosBlock(game).padding(.top, -10)
                peopleBlock(game)
                links(game)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .lightStatusBar()
        .inkBackground()
        .onAppear { ReviewPrompt.noteGameOpened() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            // One item, so the three buttons sit close; separate items get the system's wide gap.
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 2) { playButton(game); addPhotosButton; menu(game) }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("game-toolbar")
            }
        }
        .fullScreenCover(item: $viewer) { item in
            PhotoPager(photos: game.photos, start: item.id, cover: game.heroPhoto, onSetCover: { ref in
                library.setCover(game.id, to: ref, byFan: true)
            }, onDelete: { ref in
                library.removePhotos(game.id, [ref])
            })
        }
        .task(id: game.id) {
            Analytics.shared.track(.gameOpened, ["sport": game.sport.rawValue, "photos": Analytics.bucket(game.photos.count)])
            if !ProcessInfo.processInfo.arguments.contains("-uitest") { await library.autoCover(game.id) }
        }
        .sheet(isPresented: $editing) {
            AddGameView(editing: game)
        }
        .shareCardSheet(isPresented: $sharing, kind: "game", title: headlineText(game, library).replacingOccurrences(of: "\n", with: " "), format: .story, key: game.id) {
            await shareVariants(game)
        }
        .confirmationDialog("Delete this game?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                library.delete(game.id)
                dismiss()
            }
        } message: {
            Text("Its photos stay in your library.")
        }
    }

    // MARK: Hero

    private func hasDetail(_ game: GameEntry) -> Bool {
        !game.plays.isEmpty || !game.winProbability.isEmpty
    }

    private func hero(_ game: GameEntry) -> some View {
        let venue = library.venue(game.venueId)
        let tz = venue?.tz ?? .current
        // The photo is the hero's background, never a sibling above or below its buttons, so nothing can sit in front
        // of the stadium link or You were there.
        return VStack(alignment: .leading, spacing: 20) {
            if let stage = game.bigGame {
                EventMark(game: game, stage: stage)
            }
            ScoreLinesTitle(game: game)
                .accessibilityIdentifier("game-title")
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    venueLine(venue, game: game, tz: tz)
                    if let kickoff = Fmt.kickoff(game, in: tz) {
                        Label(kickoff, systemImage: game.weather?.symbol ?? "clock")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .accessibilityIdentifier("game-kickoff")
                    }
                }
                Spacer(minLength: 8)
                if hasDetail(game) {
                    NavigationLink(value: Route.youWereThere(game.id)) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.signal)
                            .frame(width: 48, height: 48)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("You were there")
                    .accessibilityHint("Opens the moments you were there for")
                    .accessibilityIdentifier("hero-you-were-there")
                }
            }
        }
        .gutter()
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, minHeight: heroHeight, maxHeight: heroHeight, alignment: .bottomLeading)
        .background {
            ZStack {
                GameBackdrop(game: game)
                Scrim()
                if game.bigGame?.kind == .championship {
                    // A warm floor of light under title-game headlines.
                    LinearGradient(colors: [Color.trophy.opacity(0.22), .clear], startPoint: .bottom, endPoint: .center)
                }
            }
            .allowsHitTesting(false)
        }
        .clipped()
        // The photo and its scrim are dark in both appearances, so the text on them stays white.
        .environment(\.colorScheme, .dark)
    }

    /// The stadium, tappable, then the date: "Wrigley Field, Oct 30, 2016".
    @ViewBuilder
    private func venueLine(_ venue: Venue?, game: GameEntry, tz: TimeZone) -> some View {
        let date = Fmt.dayTitle(game.date, in: tz)
        if let venue {
            HStack(spacing: 0) {
                NavigationLink(value: Route.venue(venue.id)) {
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns").font(.footnote.weight(.semibold))
                        Text(venue.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    }
                    .foregroundStyle(Color.signal)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(venue.name), stadium")
                .accessibilityIdentifier("hero-venue")
                Text(", \(date)").font(.subheadline).foregroundStyle(Color.textSecondary).lineLimit(1)
            }
        } else {
            Text(date).font(.subheadline).foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: Score

    @ViewBuilder
    private func scoreBlock(_ game: GameEntry) -> some View {
        if game.sport == .motorsport {
            if !game.podium.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(game.podium.enumerated()), id: \.offset) { i, line in
                        Text(line)
                            .font(.condensed(.title3, weight: .heavy))
                            .foregroundStyle(i == 0 ? Color.primaryText : Color.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                if i < game.podium.count - 1 { Rectangle().fill(Color.hairline).frame(height: 1) }
                            }
                    }
                }
            }
            if let circuit = F1Calendar.circuits[game.venueId] {
                let facts = [circuit.lengthKm.map { "\($0.formatted()) km" }, circuit.turns.map { "\($0) turns" },
                             circuit.lapRecord.flatMap { r in r.time.map { "Lap record \($0)" + (r.year.map { " (\($0))" } ?? "") } }]
                    .compactMap { $0 }
                if !facts.isEmpty {
                    Text(facts.joined(separator: " \u{00B7} ")).unitLabel()
                        .padding(.top, 8)
                        .accessibilityIdentifier("circuit-facts")
                }
            }
        } else if !game.lineHome.isEmpty || !game.lineAway.isEmpty {
            LineScoreTable(game: game)
        } else if game.hasScore {
            ScoreStack(game: game)
        }
    }

    // MARK: Photos

    /// The fan's photos from this game: a strip under the score, each opens full screen.
    @ViewBuilder
    private func photosBlock(_ game: GameEntry) -> some View {
        if !game.photos.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.inner) {
                HStack {
                    Text("Photos").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                    Text("\(game.photos.count)").unitLabel()
                    Spacer()
                    NavigationLink(value: Route.photos(game.id)) {
                        Text("See all")
                            .font(.condensed(.subheadline, weight: .bold))
                            .foregroundStyle(Color.signal)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityIdentifier("game-photos-all")
                }
                .gutter()
                photoGrid(game)
                    .gutter()
            }
            // A container: its identifier must not replace the identifiers of the photos inside it.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("game-photos")
        }
    }

    /// One wide photo, then a two-column grid; the last tile says how many more there are.
    private func photoGrid(_ game: GameEntry) -> some View {
        let shown = Array(game.photos.prefix(5))
        let extra = game.photos.count - shown.count
        func tile(_ i: Int, height: CGFloat) -> some View {
            Button { viewer = PhotoViewerItem(id: i) } label: {
                Color.panel
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .overlay { PhotoView(ref: shown[i], showsMediaBadge: true) }
                    .overlay {
                        if i == shown.count - 1, extra > 0 {
                            ZStack {
                                Color.black.opacity(0.55)
                                Text("+\(extra)").font(.condensed(.title2, weight: .heavy)).foregroundStyle(.white)
                            }
                        }
                    }
                    .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Photo \(i + 1) of \(game.photos.count)")
            .accessibilityIdentifier("game-photo-\(i)")
        }
        return VStack(spacing: 6) {
            tile(0, height: 190)
            if shown.count > 1 {
                let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(1..<shown.count, id: \.self) { tile($0, height: 130) }
                }
            }
        }
    }

    // MARK: People

    @ViewBuilder
    private func peopleBlock(_ game: GameEntry) -> some View {
        let people = game.companionIds.compactMap { library.person($0) }
        let note = game.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !people.isEmpty || !note.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.inner) {
                if !people.isEmpty {
                    HStack(spacing: 10) {
                        AvatarStack(people: people)
                        Text("With \(people.namesText)")
                            .font(.condensed(.headline, weight: .heavy))
                            .textCase(.uppercase)
                    }
                    .accessibilityElement(children: .combine)
                }
                if !note.isEmpty {
                    Text("“\(note)”")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }
            }
            .gutter()
        }
    }

    // MARK: Links

    @ViewBuilder
    private func links(_ game: GameEntry) -> some View {
        // The stadium and You were there live on the cover now; only the trip is left down here.
        if let trip = library.trip(game.tripId) {
            VStack(spacing: 0) {
                linkRow(trip.title, symbol: "airplane", route: .trip(trip.id))
                    .accessibilityIdentifier("open-trip")
            }
            .gutter()
        }
    }

    private func linkRow(_ title: String, symbol: String, route: Route) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.condensed(.headline, weight: .bold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 52)
            .contentShape(.rect)
            .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    // MARK: Menu

    /// "I was there for": pick the side, in the menu so the page stays short.
    @ViewBuilder
    private func rootingMenu(_ game: GameEntry) -> some View {
        if game.sport != .motorsport, let home = library.team(game.homeTeamId), let away = library.team(game.awayTeamId) {
            Menu {
                Picker("I was there for", selection: Binding(
                    get: { library.rootingTeam(game) ?? home.id },
                    set: { library.setRooting(game.id, to: $0) })) {
                    Text(away.locationName).tag(away.id)
                    Text(home.locationName).tag(home.id)
                }
                if let chosen = library.rootingTeam(game), !library.profile.favoriteTeamIds.contains(chosen),
                   let team = library.team(chosen) {
                    Button { library.addFavorite(chosen) } label: {
                        Label("Always root for \(team.locationName)", systemImage: "plus.circle")
                    }
                }
            } label: {
                Label("I was there for", systemImage: "heart")
            }
            .accessibilityIdentifier("game-rooting-menu")
        }
    }

    /// The slideshow, one tap from the cover, beside the menu.
    private func playButton(_ game: GameEntry) -> some View {
        Button {
            Analytics.shared.track(.photosAction, ["action": "slideshow"])
            presenter.modal = .recap(game.id)
        } label: {
            Image(systemName: "play.fill")
                .font(.body.weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(.white, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .accessibilityLabel("Play recap")
        .accessibilityIdentifier("play-recap")
    }

    /// Adds photos and videos from the library to this game, by hand.
    private var addPhotosButton: some View {
        PhotosPicker(selection: $adding, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
            HeroToolbarIcon(systemName: "plus")
        }
        .accessibilityLabel("Add photos")
        .accessibilityIdentifier("game-add-photos")
        .onChange(of: adding) { _, items in
            guard !items.isEmpty else { return }
            library.addPhotos(gameId, items.compactMap(\.itemIdentifier).map { PhotoRef.library($0) })
            adding = []
        }
    }

    private func menu(_ game: GameEntry) -> some View {
        Menu {
            Button { sharing = true } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("game-share")
            rootingMenu(game)
            Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                .accessibilityIdentifier("game-delete")
        } label: {
            HeroToolbarIcon(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("game-menu")
    }

    private func shareVariants(_ game: GameEntry) async -> [ShareCardVariant] {
        let venue = library.venue(game.venueId)
        let headline = headlineText(game, library)
        let matchup = matchupText(game, library)
        let when = Fmt.dayAndKickoff(game, in: venue?.tz ?? .current)
        var score = ""
        var result = ""
        if let hs = game.homeScore, let aw = game.awayScore {
            let outcome = library.outcome(game)
            let awayFirst = library.rootingTeam(game) != nil && library.rootingTeam(game) == game.awayTeamId
            if outcome != .none {
                score = awayFirst ? "\(aw)–\(hs)" : "\(hs)–\(aw)"
            } else {
                score = "\(aw)–\(hs)"
            }
            switch outcome {
            case .win: result = "Win"
            case .loss: result = "Loss"
            case .draw: result = "Draw"
            case .none: result = ""
            }
        }
        let accent = library.team(library.rootingTeam(game))?.accent ?? Color.signal
        let stage = game.bigGame
        var photo: UIImage?
        if let ref = game.heroPhoto { photo = await PhotoLoader.load(ref) }
        func card(_ style: GameShareCard.Style) -> GameShareCard {
            GameShareCard(
                style: style,
                photo: photo,
                accent: accent,
                headline: headline,
                matchup: matchup,
                score: score,
                result: result,
                venue: venue?.name ?? "",
                date: when,
                stageLabel: stage?.label,
                stageSymbol: stage?.kind.symbol,
                stageTint: stage?.kind.tint ?? Color.white
            )
        }
        _ = card
        let aerial: UIImage? = if let venue { await AerialCache.shared.image(for: venue, points: 390) } else { nil }
        let library = library
        return GameStoryCard.Style.allCases.map { style in
            ShareCardVariant(style.name) {
                GameStoryCard(style: style, game: game, photo: photo, aerial: aerial).environment(library)
            }
        }
    }
}

/// The 1080x1920 story card for one game, in five looks. Story suits all of them: tall photo, giant type, full-height stub.
private struct GameShareCard: View {
    enum Style { case photo, number, color, paper, stub }

    let style: Style
    let photo: UIImage?
    let accent: Color
    let headline: String
    let matchup: String
    let score: String
    let result: String
    let venue: String
    let date: String
    let stageLabel: String?
    let stageSymbol: String?
    let stageTint: Color

    private let paperColor = Color(hex: "F4F1EA")

    private var headlineLines: String {
        headline.uppercased().replacingOccurrences(of: ". ", with: ".\n")
    }

    private var place: String {
        [venue, date].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var resultLine: String {
        [result, score].filter { !$0.isEmpty }.joined(separator: " ").uppercased()
    }

    var body: some View {
        switch style {
        case .photo: photoCard
        case .number: numberCard
        case .color: colorCard
        case .paper: paperCard
        case .stub: stubCard
        }
    }

    // MARK: Pieces

    private func label(_ text: String, size: CGFloat, color: Color, lines: Int = 1) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy).width(.condensed))
            .tracking(4)
            .foregroundStyle(color)
            .lineLimit(lines)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func stageRow(_ color: Color, tint: Color) -> some View {
        if let stageLabel, let stageSymbol {
            HStack(spacing: 18) {
                Image(systemName: stageSymbol)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(tint)
                label(stageLabel.uppercased(), size: 40, color: color)
            }
        }
    }

    private func mark(_ color: Color) -> some View {
        Text("WITNESS")
            .font(.system(size: 40, weight: .heavy).width(.compressed))
            .tracking(10)
            .foregroundStyle(color)
    }

    private func heroText(size: CGFloat, color: Color, lines: Int, maxHeight: CGFloat) -> some View {
        Text(headlineLines)
            .font(.display(size))
            .foregroundStyle(color)
            .lineLimit(lines)
            .minimumScaleFactor(0.3)
            .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .topLeading)
    }

    // MARK: 1 Photo: full-bleed photo, type at the bottom

    private var photoCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [accent.opacity(0.7), .black], startPoint: .top, endPoint: .bottom)
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 1080, height: 1920)
                    .clipped()
            }
            LinearGradient(stops: [
                .init(color: .black.opacity(0.45), location: 0),
                .init(color: .black.opacity(0), location: 0.25),
                .init(color: .black.opacity(0.9), location: 0.7),
                .init(color: .black, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 28) {
                stageRow(.white, tint: stageTint)
                heroText(size: 200, color: .white, lines: 4, maxHeight: 640)
                if !resultLine.isEmpty { label(resultLine, size: 64, color: .white) }
                if !place.isEmpty { label(place.uppercased(), size: 38, color: .white.opacity(0.65), lines: 2) }
                label("I WAS THERE.", size: 48, color: Color.signal)
                mark(.white.opacity(0.9)).padding(.top, 16)
            }
            .padding(.horizontal, 84)
            .padding(.bottom, 250)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    // MARK: 2 Number: giant type on ink

    private var numberCard: some View {
        ShareCardFrame(format: .story, accent: accent) {
            VStack(alignment: .leading, spacing: 36) {
                stageRow(.white, tint: stageTint)
                Spacer(minLength: 0)
                if !score.isEmpty {
                    Text(score)
                        .font(.display(430))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    label(matchup.uppercased(), size: 56, color: .white.opacity(0.85), lines: 2)
                } else {
                    heroText(size: 300, color: .white, lines: 5, maxHeight: 900)
                }
                if !result.isEmpty { label(result.uppercased(), size: 56, color: .white.opacity(0.6)) }
                label("I WAS THERE.", size: 48, color: Color.signal)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: 3 Color: solid team color field

    private var colorCard: some View {
        let ink = accent.readableInk
        return ZStack(alignment: .topLeading) {
            accent
            VStack(alignment: .leading, spacing: 36) {
                stageRow(ink, tint: ink)
                Spacer(minLength: 0)
                if !score.isEmpty {
                    Text(score)
                        .font(.display(360))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                heroText(size: 130, color: ink, lines: 3, maxHeight: 420)
                if !place.isEmpty { label(place.uppercased(), size: 38, color: ink.opacity(0.75), lines: 2) }
                label("I WAS THERE.", size: 48, color: ink)
                mark(ink)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: 4 Paper: light inverse, black type

    private var paperCard: some View {
        ZStack(alignment: .topLeading) {
            paperColor
            VStack(alignment: .leading, spacing: 36) {
                stageRow(.black, tint: .black)
                if let photo {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 620)
                        .overlay {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(.rect(cornerRadius: 8))
                }
                heroText(size: 170, color: .black, lines: 4, maxHeight: 560)
                Rectangle().fill(Color(hex: "FFB547")).frame(width: 140, height: 12)
                if !resultLine.isEmpty { label(resultLine, size: 60, color: .black) }
                if !place.isEmpty { label(place.uppercased(), size: 38, color: .black.opacity(0.6), lines: 2) }
                Spacer(minLength: 0)
                label("I WAS THERE.", size: 48, color: .black)
                mark(.black)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .light)
    }

    // MARK: 5 Stub: a ticket-stub grid of facts

    private var stubRows: [(String, String)] {
        var rows: [(String, String)] = []
        if let stageLabel { rows.append(("Event", stageLabel)) }
        rows.append(("Game", matchup))
        if !score.isEmpty { rows.append(("Final", resultLine)) }
        if !venue.isEmpty { rows.append(("Venue", venue)) }
        if !date.isEmpty { rows.append(("Date", date)) }
        return rows
    }

    private var stubCard: some View {
        ShareCardFrame(format: .story, accent: accent) {
            VStack(alignment: .leading, spacing: 0) {
                label("ADMIT ONE", size: 56, color: .white.opacity(0.6))
                    .padding(.bottom, 40)
                ForEach(Array(stubRows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 10) {
                        label(row.0.uppercased(), size: 34, color: .white.opacity(0.5))
                        Text(row.1.uppercased())
                            .font(.display(92))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 28)
                    .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.2)).frame(height: 2) }
                }
                Spacer(minLength: 0)
                label("I WAS THERE.", size: 56, color: Color.signal)
            }
        }
    }
}

/// A clean line score: periods, then the total in heavier white.
private struct LineScoreTable: View {
    @Environment(Library.self) private var library
    let game: GameEntry

    private var columns: Int { max(game.lineHome.count, game.lineAway.count) }

    private func label(_ i: Int) -> String {
        let labels = game.sport.periodLabels
        if i < labels.count { return labels[i] }
        return game.sport == .baseball ? "\(i + 1)" : "OT"
    }

    var body: some View {
        let showCity = columns <= 5
        let awayTotal = game.awayScore ?? game.lineAway.reduce(0, +)
        let homeTotal = game.homeScore ?? game.lineHome.reduce(0, +)
        Grid(alignment: .trailing, horizontalSpacing: 0, verticalSpacing: 14) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                    .gridColumnAlignment(.leading)
                ForEach(0..<columns, id: \.self) { i in
                    Text(label(i)).unitLabel()
                        .frame(minWidth: showCity ? 30 : 22, alignment: .trailing)
                }
                Text("T").unitLabel().frame(minWidth: 40, alignment: .trailing)
            }
            row(teamId: game.awayTeamId, line: game.lineAway, total: awayTotal, won: awayTotal > homeTotal, showCity: showCity)
            row(teamId: game.homeTeamId, line: game.lineHome, total: homeTotal, won: homeTotal > awayTotal, showCity: showCity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(awayTotal: awayTotal, homeTotal: homeTotal))
    }

    private func row(teamId: String?, line: [Int], total: Int, won: Bool, showCity: Bool) -> some View {
        let team = library.team(teamId)
        let tone: Color = won ? .white : .textSecondary
        return GridRow {
            HStack(spacing: 10) {
                TeamTile(team: team, compact: true)
                if showCity {
                    Text(team?.locationName ?? "")
                        .font(.condensed(.headline, weight: .bold))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .foregroundStyle(tone)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<columns, id: \.self) { i in
                Text(i < line.count ? "\(line[i])" : "–")
                    .font(.condensed(.subheadline, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(tone)
            }
            Text("\(total)")
                .displayFont(26, relativeTo: .title2)
                .foregroundStyle(tone)
        }
    }

    private func accessibilityText(awayTotal: Int, homeTotal: Int) -> String {
        let away = library.team(game.awayTeamId)?.locationName ?? "Away"
        let home = library.team(game.homeTeamId)?.locationName ?? "Home"
        return "Final: \(away) \(awayTotal), \(home) \(homeTotal)"
    }
}
