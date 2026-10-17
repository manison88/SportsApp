import SwiftUI
import CoreLocation

/// 01 · Finds games in the photo library by stadium geofence and asks the fan
/// to confirm each one.
struct DiscoveryView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable { case requesting, scanning, denied, results }

    @State private var phase: Phase = .requesting
    @State private var scanProgress: PhotoMatcher.ScanProgress?
    @State private var clusters: [PhotoCluster] = []
    @State private var index = 0
    @State private var confirmed = 0
    @State private var lookup: FoundGame?
    @State private var lookupFor: String?
    @State private var checkedFor: String?
    @State private var lookupVenue: Venue?
    @State private var onScoreboard = false
    @State private var scene: SceneVerdict?
    /// Visits backed by a ticket screenshot, by visit key.
    @State private var tickets: [String: TicketDraft] = [:]

    var body: some View {
        ZStack(alignment: .top) {
            Color.ink.ignoresSafeArea()
            content
                .padding(.top, 56)
            HStack {
                CircleButton(systemName: "xmark", label: "Close") { close() }
                    .accessibilityIdentifier("discovery-close")
                Spacer()
            }
            .padding(.horizontal, Spacing.gutter - 4)
        }
        .task { await run() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .requesting, .scanning:
            scanning
                .frame(maxWidth: .infinity)
        case .denied:
            message(title: "Witness can't see your photos.",
                    body: "Allow photo access in Settings and Witness will match them to stadiums on this iPhone.",
                    showSettings: true, id: "discovery-denied")
        case .results:
            if clusters.isEmpty {
                message(title: "No games found in your photos yet.", body: nil, showSettings: false, id: "discovery-empty")
            } else if index >= clusters.count {
                done
            } else {
                results(clusters[index])
            }
        }
    }

    // MARK: Results

    private func results(_ cluster: PhotoCluster) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                VStack(alignment: .leading, spacing: Spacing.inner) {
                    HStack(alignment: .center, spacing: 14) {
                        Text("\(clusters.count)")
                            .displayFont(110)
                        Text(clusters.count == 1 ? "Game in\nyour photos" : "Games in\nyour photos")
                            .font(.condensed(.title2, weight: .heavy))
                            .textCase(.uppercase)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("discovery-count")
                    ProgressView(value: Double(confirmed), total: Double(max(clusters.count, 1)))
                        .tint(.white)
                    Text("\(confirmed) of \(clusters.count) confirmed").unitLabel()
                }

                card(cluster)

                HStack(spacing: Spacing.inner) {
                    Button("Skip") { advance() }
                        .buttonStyle(.secondary)
                        .frame(maxWidth: 120)
                        .accessibilityIdentifier("discovery-skip")
                    Button {
                        confirm(cluster)
                    } label: {
                        Label(noGame(cluster) ? "Save visit" : "Confirm", systemImage: "checkmark")
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("discovery-confirm")
                }

                Label("Matched privately on this iPhone", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .task(id: cluster.id) { await lookUp(cluster) }
    }

    private func card(_ cluster: PhotoCluster) -> some View {
        VStack(alignment: .leading, spacing: Spacing.inner) {
            HStack(spacing: 10) {
                Text((lookupFor == cluster.id ? lookupVenue?.name : nil) ?? cluster.venue.name)
                    .font(.condensed(.title3, weight: .heavy))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                if let lookup, lookupFor == cluster.id {
                    HStack(spacing: 5) {
                        TeamTile(team: GameLookup.team(from: lookup.away, game: lookup), compact: true)
                        Text(lookup.away.score.map(String.init) ?? "").font(.condensed(.subheadline, weight: .heavy)).monospacedDigit()
                        TeamTile(team: GameLookup.team(from: lookup.home, game: lookup), compact: true)
                        Text(lookup.home.score.map(String.init) ?? "").font(.condensed(.subheadline, weight: .heavy)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(lookup.away.location) \(lookup.away.score ?? 0), \(lookup.home.location) \(lookup.home.score ?? 0), on the schedule")
                    .accessibilityIdentifier("discovery-verified")
                    if onScoreboard {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.trophy)
                            .accessibilityLabel("Seen on the scoreboard in your photos")
                    }
                } else {
                    Text(Fmt.day(cluster.start, in: cluster.venue.tz)).unitLabel()
                }
            }
            let ids = Array(cluster.assetIds.prefix(4))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(Array(ids.enumerated()), id: \.element) { i, _ in
                    let id = ids[i]
                    let time = cluster.times.indices.contains(i) ? cluster.times[i] : cluster.start
                    Color.panel
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .overlay { PhotoView(ref: .library(id)) }
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay(alignment: .bottomLeading) {
                            Text(Fmt.time(time, in: cluster.venue.tz))
                                .font(.condensed(.caption, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.black.opacity(0.55), in: .rect(cornerRadius: 4))
                                .padding(6)
                        }
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(cluster.assetIds.count) photos at \(cluster.venue.name)")

            if tickets[cluster.id] != nil {
                Label("From your ticket", systemImage: "ticket.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityIdentifier("discovery-ticket")
            } else if checkedFor == cluster.id, scene?.doubtful == true {
                Label("These don't look like they were taken inside. Keep it?", systemImage: "questionmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityIdentifier("discovery-doubtful")
            }
            if noGame(cluster) {
                Label("No game on the schedule that day. Save it as a stadium visit?", systemImage: "calendar.badge.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityIdentifier("discovery-unverified")
            }
        }
    }

    private var scanning: some View {
        VStack(spacing: Spacing.inner) {
            Spacer()
            if let p = scanProgress, p.total > 0 {
                Text(p.date.map { $0.formatted(.dateTime.month(.wide).year()) } ?? "Starting")
                    .displayFont(48)
                    .textCase(.uppercase)
                    .contentTransition(.numericText())
                ProgressView(value: Double(p.scanned), total: Double(p.total))
                    .tint(Color.signal)
                    .padding(.horizontal, 48)
                Text("\(p.scanned.formatted()) of \(p.total.formatted()) photos")
                    .font(.condensed(.headline))
                    .foregroundStyle(Color.textSecondary)
                if p.atStadiums > 0 {
                    Label("\(p.atStadiums) near a stadium" + (p.latestVenue.map { " · \($0)" } ?? ""), systemImage: "building.columns")
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                        .accessibilityIdentifier("discovery-progress-found")
                }
            } else {
                ProgressView().controlSize(.large).tint(.white)
            }
            Text("Looking for stadiums in your photos")
                .font(.condensed(.headline))
                .foregroundStyle(Color.textTertiary)
            Label("Matched privately on this iPhone", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
        .animation(.default, value: scanProgress?.atStadiums)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("discovery-scanning")
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            Spacer()
            Text("\(confirmed)")
                .displayFont(120)
            Text(confirmed == 1 ? "Game added" : "Games added")
                .font(.condensed(.title2, weight: .heavy))
                .textCase(.uppercase)
            Spacer()
            Button("Done") { close() }
                .buttonStyle(.primary)
                .accessibilityIdentifier("discovery-done")
        }
        .gutter()
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func message(title: String, body: String?, showSettings: Bool, id: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.inner) {
            Spacer()
            Text(title)
                .displayFont(48)
                .textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(id)
            if let body {
                Text(body)
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            if showSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.primary)
                Button("Add a game") { addManually() }
                    .buttonStyle(.secondary)
            } else {
                Button("Add a game") { addManually() }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("discovery-add")
                Button("Explore sample games") {
                    library.loadSample()
                    dismiss()
                }
                .buttonStyle(.secondary)
                .accessibilityIdentifier("discovery-sample")
            }
        }
        .gutter()
        .padding(.bottom, 16)
    }

    // MARK: Actions

    private func run() async {
        guard phase == .requesting else { return }
        let granted = await PhotoMatcher.requestAccess()
        guard granted else { phase = .denied; return }
        phase = .scanning
        // Onboarding already scanned the library: review those results instead of scanning twice.
        var found: [PhotoCluster]
        if presenter.scan.state == .done, !presenter.scan.clusters.isEmpty {
            found = presenter.scan.clusters
            presenter.scan.markReviewed()
        } else {
            found = await PhotoMatcher.discover(venues: library.venues, existing: library.games) { p in
                Task { @MainActor in scanProgress = p }
            }
        }
        // Ticket screenshots pin games on their own, even when none of the night's photos have GPS.
        let have = Set(library.games.compactMap { g in library.venue(g.venueId).map { VisitGrouping.key(venueId: $0.id, date: g.date, tz: $0.tz) } })
        let anchors = await TicketAnchors.find(in: TicketAnchors.screenshots(limit: 200), teams: library.allTeams, venues: library.venues)
        for anchor in anchors {
            let key = VisitGrouping.key(venueId: anchor.venue.id, date: anchor.date, tz: anchor.venue.tz)
            guard !have.contains(key) else { continue }
            tickets[key] = anchor.draft
            if found.contains(where: { $0.id == key }) { continue }
            let ids = await PhotoMatcher.photos(at: anchor.venue, around: anchor.date) + [anchor.id]
            found.append(PhotoCluster(id: key, venue: anchor.venue, start: anchor.date, end: anchor.date,
                                      assetIds: ids, times: ids.map { _ in anchor.date }))
        }
        clusters = found.sorted { $0.start > $1.start }
        phase = .results
    }

    /// Checks the photos' venue and time against real league schedules,
    /// then the venues next door (a stadium and its arena share a parking lot).
    private func lookUp(_ cluster: PhotoCluster) async {
        lookup = nil
        lookupFor = nil
        for venue in [cluster.venue] + PhotoMatcher.neighbors(of: cluster.venue, in: library.venues) {
            if let game = await GameLookup.games(at: venue, from: cluster.start, to: cluster.end).first {
                lookup = game
                lookupFor = cluster.id
                lookupVenue = venue
                break
            }
        }
        checkedFor = cluster.id
        onScoreboard = false
        scene = nil
        if let game = lookup, lookupFor == cluster.id {
            // A scoreboard in the photos that shows these teams confirms it.
            let readings = await ScoreboardReader.read(cluster.assetIds.map { PhotoRef.library($0) })
            onScoreboard = readings.contains { ScoreboardReader.confirms($0, game) }
        }
        // A downtown stadium on game night can still be a party across the street: look at the photos.
        if tickets[cluster.id] == nil && !onScoreboard {
            scene = await SceneCheck.verdict(for: cluster.assetIds.map { PhotoRef.library($0) })
        }
    }

    /// The schedule was checked and had nothing: a tour, or a walk past the ground.
    private func noGame(_ cluster: PhotoCluster) -> Bool {
        checkedFor == cluster.id && lookupFor != cluster.id && tickets[cluster.id] == nil
            && !GameLookup.leagues(for: cluster.venue).isEmpty
    }

    private func confirm(_ cluster: PhotoCluster) {
        let venue = cluster.venue
        var entry = GameEntry(sport: venue.sports.first ?? .baseball,
                              date: cluster.start,
                              venueId: venue.id,
                              photos: cluster.assetIds.prefix(12).map { PhotoRef.library($0) },
                              origin: .photos)
        if let draft = tickets[cluster.id] {
            entry.seat = draft.seatLine
            entry.origin = .ticket
        }
        if noGame(cluster) {
            entry.kind = .visit
            entry.competition = "Stadium visit"
        }
        if let lookup, lookupFor == cluster.id {
            entry.date = lookup.start
            if let lookupVenue { entry.venueId = lookupVenue.id }
            GameLookup.apply(lookup, detail: nil, to: &entry, library: library)
            // Plays and the win-probability curve arrive after; the card moves on now.
            let id = entry.id
            Task {
                guard let detail = await GameLookup.detail(lookup), var saved = library.game(id) else { return }
                GameLookup.apply(lookup, detail: detail, to: &saved, library: library)
                library.update(saved)
            }
        }
        library.add(entry)
        confirmed += 1
        advance()
    }

    private func advance() {
        lookup = nil
        lookupFor = nil
        index += 1
    }

    private func addManually() {
        library.startEmpty()
        presenter.modal = .addGame
    }

    private func close() {
        if confirmed > 0 && !library.hasLibrary { library.startEmpty() }
        dismiss()
    }
}
