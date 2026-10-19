import SwiftUI

/// First run: the welcome (thousands of photos counted down to the games in them), photo access, then the scan and its first result.
struct OnboardingView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @Environment(\.scenePhase) private var scenePhase
    @State private var started = false
    @State private var legal: LegalDocument?

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
                case .idle, .denied, .scanning, .matching, .verifying: pages(denied: scan.state == .denied)
                case .done: ResultScreen(scan: scan) { presenter.modal = .discovery }
                case .empty: emptyScreen(scan)
                }
            }
        }
        .onChange(of: started) { _, now in if now { Analytics.shared.track(.onboardingStep, ["step": "welcome_done"]) } }
        .sheet(item: $legal) { doc in
            NavigationStack { LegalView(document: doc, online: doc.title == LegalContent.terms.title ? LegalLinks.terms : LegalLinks.privacy) }
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

    /// After the welcome, one page: what Witness reads, and the ask for photo access.
    private func pages(denied: Bool) -> some View {
        ZStack {
            AccessPage()
            VStack(spacing: Spacing.inner) {
                Spacer()
                controls
            }
            .gutter()
            .padding(.bottom, 12)

            if denied { DeniedSheet() }
        }
    }

    private var controls: some View {
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
            HStack(spacing: 18) {
                Button("Privacy policy") { legal = LegalContent.privacy }
                    .accessibilityIdentifier("onboarding-privacy")
                Button("Terms of use") { legal = LegalContent.terms }
                    .accessibilityIdentifier("onboarding-terms")
            }
            .font(.footnote)
            .foregroundStyle(Color.textSecondary)
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

// MARK: - Photo access

private struct AccessPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
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
            if !scan.possible.isEmpty {
                Label("\(scan.possible.count) more \(scan.possible.count == 1 ? "visit" : "visits") near stadiums might be games. You confirm the stadium and we match the date.",
                      systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .opacity(beat >= 3 ? 1 : 0)
                    .accessibilityIdentifier("onboarding-possible-note")
            }
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                if scan.games.count > 1 {
                    Button("Add all \(scan.games.count) games") {
                        scan.commit(scan.games, into: library)
                        if scan.possible.isEmpty { scan.markReviewed(); return }
                        onReview()
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("onboarding-add-all")
                    Button(scan.games.isEmpty ? "Review possible games" : "Review one by one", action: onReview)
                        .buttonStyle(.secondary)
                        .accessibilityIdentifier("onboarding-review")
                } else {
                    Button(scan.games.isEmpty ? "Review possible games" : "Review games", action: onReview)
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("onboarding-review")
                }
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
                        FoundGameChip(game: g, font: .condensed(.headline, weight: .heavy))
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
    @Environment(Library.self) private var library

    var body: some View {
        let scan = presenter.scan
        if scan.deepState == .running {
            card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Searching albums and trips").font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                        Spacer()
                        Text("\(Int((scan.deepFraction * 100).rounded()))%")
                            .font(.condensed(.subheadline, weight: .heavy)).monospacedDigit().foregroundStyle(Color.signal)
                    }
                    ProgressView(value: scan.deepFraction).tint(Color.signal)
                        .animation(.smooth, value: scan.deepFraction)
                    Text(deepLine(scan)).font(.footnote).foregroundStyle(Color.textSecondary)
                }
            }
            .accessibilityIdentifier("deep-scan-running")
        } else if scan.deepState == .done && !scan.deepReviewed {
            Button { presenter.modal = .discovery } label: {
                card {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("\(scan.possible.count) possible games in your albums and trips")
                        .font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                    Spacer()
                    Text("Review").font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase).foregroundStyle(Color.signal)
                }
            }
            .accessibilityIdentifier("deep-scan-review")
        } else if offerDeepScan(scan) {
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Look for more games?").font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                    Text("Search your albums, trips and less obvious photos for games without a stadium location. It runs in the background and you pick the stadium for each one.")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                    HStack(spacing: 10) {
                        Button("Search") { scan.startDeepScan(library: library) }
                            .buttonStyle(.primary).accessibilityIdentifier("deep-scan-start")
                        Button("Not now") { scan.deepDeclined = true }
                            .buttonStyle(.secondary).accessibilityIdentifier("deep-scan-decline")
                    }
                }
            }
        } else {
            firstPass(scan)
        }
    }

    /// What the background search is doing right now, with a count, so a long search never looks stuck.
    private func deepLine(_ scan: ScanModel) -> String {
        let count = scan.deepTotal > 0 ? " \(min(scan.deepDone + 1, scan.deepTotal)) of \(scan.deepTotal)" : ""
        switch scan.deepStep {
        case .visits: return "Checking stadium visits\(count). You can keep using the app."
        case .reading: return "Reading your albums\(count)"
        case .sorting: return "Looking for stadium photos\(count)"
        case .days: return scan.deepTotal > 0 ? "Checking days that might be games\(count)" : "Checking days that might be games"
        }
    }

    /// Offered once the first pass has been seen, to anyone who gave photo access and has not said no.
    private func offerDeepScan(_ scan: ScanModel) -> Bool {
        guard scan.deepState == .idle, !scan.deepDeclined, PhotoMatcher.hasAccess else { return false }
        return (scan.state == .done && scan.reviewed) || scan.state == .empty
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12) { content() }
            .foregroundStyle(.white)
            .padding(14)
            .background(Color.panel, in: .rect(cornerRadius: 14))
            .gutter()
            .padding(.vertical, 6)
    }

    @ViewBuilder
    private func firstPass(_ scan: ScanModel) -> some View {
        switch scan.state {
        case .scanning, .matching, .verifying:
            HStack(spacing: 12) {
                ProgressView().tint(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scan.state == .scanning ? "Scanning your photos" : scan.state == .matching ? "Matching to the schedule" : "Checking your photos")
                        .font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                    Text(scan.state == .scanning
                         ? "\(scan.progress.scanned.formatted()) of \(scan.progress.total.formatted()), \(scan.progress.visits) visits so far"
                         : "\(scan.checkedVisits) of \(scan.totalVisits) visits, \(scan.matchedCount) games so far")
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
