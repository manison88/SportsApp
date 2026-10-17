import SwiftUI

/// First run: the welcome, then three pages (the problem, the fix, photo access), then the scan and its first result.
struct OnboardingView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @Environment(\.scenePhase) private var scenePhase
    @State private var started = false
    @State private var page = 0

    var body: some View {
        let scan = presenter.scan
        ZStack {
            Color.ink.ignoresSafeArea()
            if !started {
                WelcomeView { withAnimation(.smooth) { started = true } }
                    .transition(.opacity)
            } else if scan.inProgress || (scan.state == .done && !scan.shown) {
                // One screen from the first photo to the last step; the matches appear only after it.
                ScanProgressView(scan: scan)
            } else {
                switch scan.state {
                case .idle, .denied, .scanning, .matching: pages(denied: scan.state == .denied)
                case .done: ResultScreen(scan: scan) { presenter.modal = .discovery }
                case .empty: emptyScreen(scan)
                }
            }
        }
        .animation(.smooth, value: presenter.scan.state)
        .animation(.smooth, value: presenter.scan.shown)
        .onChange(of: scenePhase) { _, phase in
            // Back from Settings with access turned on: carry straight on.
            if phase == .active, presenter.scan.state == .denied, PhotoMatcher.hasAccess {
                presenter.scan.start(library: library)
            }
        }
    }

    // MARK: Pages

    private func pages(denied: Bool) -> some View {
        ZStack {
            TabView(selection: $page) {
                ProblemPage().tag(0)
                SolutionPage().tag(1)
                AccessPage().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: Spacing.inner) {
                HStack {
                    Spacer()
                    if page < 2 {
                        Button { withAnimation(.smooth) { page = 2 } } label: {
                            Text("Skip")
                                .font(.condensed(.subheadline, weight: .heavy))
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(.black.opacity(0.5), in: .rect(cornerRadius: 10))
                        }
                        .accessibilityIdentifier("onboarding-skip")
                    }
                }
                Spacer()
                PageDots(count: 3, current: page)
                controls
            }
            .gutter()
            .padding(.bottom, 12)

            if denied { DeniedSheet() }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch page {
        case 0:
            Button("Next") { withAnimation(.smooth) { page = 1 } }
                .buttonStyle(.primary)
                .accessibilityIdentifier("onboarding-next")
        case 1:
            Button("Continue") { withAnimation(.smooth) { page = 2 } }
                .buttonStyle(.primary)
                .accessibilityIdentifier("onboarding-next")
        default:
            VStack(spacing: Spacing.inner) {
                Button("Allow photo access") { presenter.scan.start(library: library) }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("onboarding-allow")
                Button("Choose an album instead") { presenter.modal = .importAlbum }
                    .buttonStyle(.secondary)
                    .accessibilityIdentifier("onboarding-album")
                Button("Not now") { library.loadSample() }
                    .font(.condensed(.headline, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("onboarding-notnow")
            }
        }
    }

    private func emptyScreen(_ scan: ScanModel) -> some View {
        ZStack {
            ScanProgressView(scan: scan, finished: true)
                .opacity(0.45)
            EmptySheet(checked: scan.progress.total)
        }
    }
}

// MARK: - Dots

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.white : Color.panelRaised)
                    .frame(width: i == current ? 28 : 8, height: 8)
            }
        }
        .animation(.smooth, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

// MARK: - Page 1: the problem

private struct ProblemPage: View {
    fileprivate static let names = ["wrigley-night", "fenway-day", "lambeau-exterior", "united-center-court", "soldier-skyline",
                                "wrigley-bleachers", "fenway-night", "camp-nou-aerial", "soldier-aerial", "lambeau-concourse",
                                "wrigley-scoreboard", "soldier-soccer", "fenway-postcard", "wrigley-night-2"]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            roll
            LinearGradient(colors: [Color.ink.opacity(0.35), Color.ink.opacity(0.92)], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 14) {
                Text("Your camera roll").unitLabel().foregroundStyle(Color.textSecondary)
                VStack(alignment: .leading, spacing: -4) {
                    Text("40,000\nPhotos.")
                        .displayFont(104)
                        .foregroundStyle(.white)
                    Text("How many\ngames?")
                        .displayFont(64)
                        .foregroundStyle(Color.signal)
                }
                .textCase(.uppercase)
                .lineLimit(4)
                .minimumScaleFactor(0.5)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Text("Somewhere in there is every game you went to. Nothing in it says which.")
                    .font(.title3)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .gutter()
            .padding(.bottom, 190)
        }
        .accessibilityIdentifier("onboarding-problem")
    }

    /// A dimmed grid of real photos, the camera roll the problem is about.
    private var roll: some View {
        GeometryReader { geo in
            let cols = 6
            let side = geo.size.width / CGFloat(cols)
            let rows = Int(ceil(geo.size.height * 0.62 / side))
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { c in
                            let i = r * cols + c
                            Color.panel
                                .frame(width: side, height: side)
                                .overlay {
                                    if (i * 7) % 5 != 0 {
                                        Image(Self.names[(i * 3) % Self.names.count])
                                            .resizable().scaledToFill()
                                            .opacity(0.45)
                                    }
                                }
                                .clipped()
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Page 2: the fix

private struct SolutionPage: View {
    @Environment(Library.self) private var library
    @State private var tile: CGFloat = 46

    private let cols = 7
    private let rows = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    pile
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { w in
                            tile = max(24, (w - CGFloat(cols - 1) * 4) / CGFloat(cols))
                        }
                    Rectangle().fill(Color.signal).frame(width: 2, height: 18).padding(.leading, tile / 2 - 1)
                    gameCard
                }
                .padding(.top, 60)

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: -4) {
                        Text("One photo.").foregroundStyle(.white)
                        Text("One game.").foregroundStyle(Color.signal)
                    }
                    .displayFont(58)
                    .textCase(.uppercase)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    Text("Witness reads each photo's date and place, matches it to the real schedule, and you confirm.")
                        .font(.body)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 170)
            }
            .gutter()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("onboarding-solution")
    }

    /// A few rows of the camera roll, dimmed and gray, with one photo in color and ringed: one among many.
    private var pile: some View {
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { c in cell(r, c) }
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 6) {
                chip("calendar", "Jul 4, 2026 \u{00B7} 7:02 PM")
                chip("mappin.and.ellipse", "Near Wrigley Field")
            }
            .padding(.leading, tile + 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("One photo picked out of many, taken Jul 4, 2026 near Wrigley Field")
    }

    private func cell(_ r: Int, _ c: Int) -> some View {
        let picked = r == rows - 1 && c == 0
        let names = ProblemPage.names
        return Color.panel
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(picked ? "wrigley-night-2" : names[(r * cols + c) * 3 % names.count])
                    .resizable()
                    .scaledToFill()
                    .saturation(picked ? 1 : 0)
                    .opacity(picked ? 1 : 0.3)
            }
            .clipShape(.rect(cornerRadius: 6))
            .overlay {
                if picked { RoundedRectangle(cornerRadius: 6).strokeBorder(Color.signal, lineWidth: 2) }
            }
            .shadow(color: picked ? Color.signal.opacity(0.55) : .clear, radius: 8)
            .zIndex(picked ? 1 : 0)
    }

    private func chip(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.condensed(.caption, weight: .heavy))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .background(Color.panelRaised, in: .rect(cornerRadius: 8))
    }

    /// A made-up example, labelled as one.
    private var gameCard: some View {
        let chc = library.allTeams.first { $0.sport == .baseball && $0.abbreviation == "CHC" }
        let mil = library.allTeams.first { $0.sport == .baseball && $0.abbreviation == "MIL" }
        return ZStack(alignment: .bottomLeading) {
            Color.panel
            PhotoView(ref: .bundled("wrigley-bleachers"))
            Scrim()
            VStack(alignment: .leading, spacing: 8) {
                Text("Wrigley Field").displayFont(30).textCase(.uppercase).foregroundStyle(.white)
                HStack(spacing: 8) {
                    TeamTile(team: chc, compact: true)
                    Text("4").font(.condensed(.headline, weight: .heavy))
                    Text("3").font(.condensed(.headline, weight: .heavy))
                    TeamTile(team: mil, compact: true)
                }
                .foregroundStyle(.white)
                Text("Jul 4, 2026 · Bleachers 314").font(.footnote).foregroundStyle(Color.textSecondary)
            }
            .padding(14)
        }
        .frame(height: 176)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(alignment: .topLeading) {
            Text("Example").font(.condensed(.caption, weight: .heavy)).textCase(.uppercase).tracking(1.2)
                .foregroundStyle(.white)
                .padding(.horizontal, 8).frame(minHeight: 24)
                .background(.black.opacity(0.55), in: .capsule)
                .padding(10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example: a photo from Wrigley Field matched to Cubs 4, Brewers 3")
    }
}

// MARK: - Page 3: access

private struct AccessPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            Text("Step 3 of 3").unitLabel().foregroundStyle(Color.textTertiary)
            VStack(alignment: .leading, spacing: -4) {
                Text("Dates and\nplaces.").foregroundStyle(.white)
                Text("Nothing else.").foregroundStyle(Color.signal)
            }
            .displayFont(60)
            .textCase(.uppercase)
            .lineLimit(4)
            .minimumScaleFactor(0.6)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                row("Date", "Jul 4, 2026 · 7:02 PM", muted: false)
                row("Place", "Near a stadium", muted: false)
                row("Content", "Not read", muted: true)
            }
            .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }

            Label("Photos and results stay on this iPhone. Nothing is uploaded.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .gutter()
        .padding(.top, 76)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("onboarding-access")
    }

    private func row(_ label: String, _ value: String, muted: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).unitLabel().foregroundStyle(Color.textTertiary).frame(width: 84, alignment: .leading)
            Text(value)
                .font(.condensed(.title3, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(muted ? Color.textSecondary : .white)
            Spacer()
        }
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Fallback sheets

private struct SheetFrame<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: Spacing.inner) { content }
                .gutter()
                .padding(.top, 22)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.panel, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .overlay(alignment: .top) { Capsule().fill(Color.hairline).frame(width: 40, height: 4).padding(.top, 8) }
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom))
    }
}

private struct FallbackRow: View {
    let title: String
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).tracking(1)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary)
            }
            .foregroundStyle(.white)
            .frame(minHeight: 52)
            .contentShape(.rect)
            .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
        }
        .accessibilityIdentifier(id)
    }
}

private struct DeniedSheet: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            SheetFrame {
                Image(systemName: "sun.max").font(.title3)
                    .frame(width: 48, height: 48)
                    .background(Color.panelRaised, in: .rect(cornerRadius: 12))
                Text("Photo access is off").displayFont(34).textCase(.uppercase).foregroundStyle(.white)
                    .accessibilityIdentifier("onboarding-denied")
                Text("Witness can't see your photos, so it can't find your games. Turn access on in Settings, or start another way.")
                    .font(.body).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("onboarding-settings")
                FallbackRow(title: "Choose an album", id: "onboarding-denied-album") { presenter.modal = .importAlbum }
                FallbackRow(title: "Add a game by hand", id: "onboarding-denied-add") {
                    library.startEmpty()
                    presenter.modal = .addGame
                }
                FallbackRow(title: "Explore sample games", id: "onboarding-denied-sample") { library.loadSample() }
            }
        }
    }
}

private struct EmptySheet: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    let checked: Int

    var body: some View {
        SheetFrame {
            Image(systemName: "magnifyingglass").font(.title3)
                .frame(width: 48, height: 48)
                .background(Color.panelRaised, in: .rect(cornerRadius: 12))
            Text("No games found yet").displayFont(34).textCase(.uppercase).foregroundStyle(.white)
                .accessibilityIdentifier("onboarding-empty")
            Text("\(checked.formatted()) photos checked, none taken inside a stadium. Older photos, or ones with location off, may be missing a date or a place.")
                .font(.body).foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Choose another album") { presenter.modal = .importAlbum }
                .buttonStyle(.primary)
                .accessibilityIdentifier("onboarding-empty-album")
            FallbackRow(title: "Add a game by hand", id: "onboarding-empty-add") {
                library.startEmpty()
                presenter.modal = .addGame
            }
            FallbackRow(title: "Explore sample games", id: "onboarding-empty-sample") { library.loadSample() }
        }
    }
}

// MARK: - First result

private struct ResultScreen: View {
    @Environment(Library.self) private var library
    let scan: ScanModel
    let onReview: () -> Void
    /// The result arrives in beats: the number counts up, then the figures, then the newest game.
    @State private var beat = 0
    @State private var counted = 0

    var body: some View {
        let p = scan.progress
        VStack(alignment: .leading, spacing: Spacing.block) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(counted)")
                    .displayFont(150)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    .accessibilityIdentifier("onboarding-result")
                Text("Games\nfound").displayFont(44).textCase(.uppercase).foregroundStyle(.white)
            }
            HStack(alignment: .top) {
                stat(p.total, "Photos\nchecked")
                stat(p.venues.count, "Venues")
                stat(p.atStadiums, "Photos at\nstadiums")
            }
            .opacity(beat >= 1 ? 1 : 0)
            .offset(y: beat >= 1 ? 0 : 12)
            newestCard
                .opacity(beat >= 2 ? 1 : 0)
                .offset(y: beat >= 2 ? 0 : 18)
            if !scan.others.isEmpty {
                Label("\(scan.others.count) other \(scan.others.count == 1 ? "visit" : "visits") near a stadium to look at after your games: a concert, a tour, a tailgate.",
                      systemImage: "ticket")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .opacity(beat >= 3 ? 1 : 0)
                    .accessibilityIdentifier("onboarding-other-note")
            }
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Button(scan.games.isEmpty ? "Review other visits" : "Review games", action: onReview)
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("onboarding-review")
                Label("Found on this iPhone. Nothing was uploaded.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .gutter()
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            withAnimation(.easeOut(duration: 0.9)) { counted = scan.games.count }
            for next in 1...3 {
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.smooth(duration: 0.5)) { beat = next }
            }
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.formatted()).displayFont(40).foregroundStyle(.white)
            Text(label).unitLabel().foregroundStyle(Color.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var newestCard: some View {
        if let c = scan.games.first {
            let hero = c.assetIds.isEmpty ? nil : c.assetIds[c.assetIds.count / 2]
            ZStack(alignment: .bottomLeading) {
                Color.panel
                if let hero { PhotoView(ref: .library(hero)) }
                Scrim()
                VStack(alignment: .leading, spacing: 8) {
                    Text(c.venue.name).displayFont(30).textCase(.uppercase).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.6)
                    if let g = scan.newest {
                        HStack(spacing: 8) {
                            TeamTile(team: GameLookup.team(from: g.away, game: g), compact: true)
                            Text(g.away.score.map(String.init) ?? "").font(.condensed(.headline, weight: .heavy))
                            Text(g.home.score.map(String.init) ?? "").font(.condensed(.headline, weight: .heavy))
                            TeamTile(team: GameLookup.team(from: g.home, game: g), compact: true)
                        }
                        .foregroundStyle(.white)
                    }
                    Text("\(Fmt.dayTitle(c.start, in: c.venue.tz)) · \(c.assetIds.count) photos")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipShape(.rect(cornerRadius: 18))
            .overlay(alignment: .topLeading) {
                Text("Newest").font(.condensed(.caption, weight: .heavy)).textCase(.uppercase).tracking(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).frame(minHeight: 24)
                    .background(.black.opacity(0.55), in: .capsule)
                    .padding(10)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Timeline banner

/// While a scan runs in the background, or has results waiting, the Timeline says so.
struct ScanBanner: View {
    @Environment(Presenter.self) private var presenter

    var body: some View {
        let scan = presenter.scan
        switch scan.state {
        case .scanning, .matching:
            HStack(spacing: 12) {
                ProgressView().tint(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scan.state == .matching ? "Matching to the schedule" : "Scanning your photos")
                        .font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                    Text(scan.state == .matching
                         ? "\(scan.checkedVisits) of \(scan.totalVisits) visits, \(scan.matchedCount) games so far"
                         : "\(scan.progress.scanned.formatted()) of \(scan.progress.total.formatted()), \(scan.progress.visits) visits so far")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(Color.panel, in: .rect(cornerRadius: 14))
            .gutter()
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("scan-banner")
        case .done where !scan.reviewed:
            Button { presenter.modal = .discovery } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("\(scan.games.count) games found in your photos")
                        .font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                    Spacer()
                    Text("Review").font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase).foregroundStyle(Color.signal)
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(Color.panel, in: .rect(cornerRadius: 14))
                .gutter()
                .padding(.vertical, 6)
            }
            .accessibilityIdentifier("scan-banner-review")
        default:
            EmptyView()
        }
    }
}
