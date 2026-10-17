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
    @State private var clusters: [PhotoCluster] = []
    @State private var index = 0
    @State private var confirmed = 0
    @State private var lookup: ScoreResult?
    @State private var lookupFor: String?

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
            VStack(spacing: Spacing.inner) {
                Spacer()
                ProgressView().controlSize(.large).tint(.white)
                Text("Looking for stadiums in your photos")
                    .font(.condensed(.headline))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
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
                        Label("Confirm", systemImage: "checkmark")
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
                Text(cluster.venue.name)
                    .font(.condensed(.title3, weight: .heavy))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                if let lookup, lookupFor == cluster.id {
                    HStack(spacing: 5) {
                        TeamTile(team: library.team(lookup.awayTeamId), compact: true)
                        Text("\(lookup.awayScore)").font(.condensed(.subheadline, weight: .heavy)).monospacedDigit()
                        TeamTile(team: library.team(lookup.homeTeamId), compact: true)
                        Text("\(lookup.homeScore)").font(.condensed(.subheadline, weight: .heavy)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    Text(Fmt.day(cluster.start, in: cluster.venue.tz)).unitLabel()
                }
            }
            let ids = Array(cluster.assetIds.prefix(4))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(ids.indices, id: \.self) { i in
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
        }
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
        clusters = await PhotoMatcher.discover(venues: library.venues, existing: library.games)
        phase = .results
    }

    private func lookUp(_ cluster: PhotoCluster) async {
        lookup = nil
        lookupFor = nil
        guard let park = library.ballparks.first(where: { $0.venueId == cluster.venue.id }) else { return }
        let home = library.allTeams.first { $0.sport == .baseball && $0.abbreviation == park.code }
        if let result = await ScoreLookup.mlb(on: cluster.start, venue: cluster.venue, teams: library.allTeams, homeTeamId: home?.id) {
            lookup = result
            lookupFor = cluster.id
        }
    }

    private func confirm(_ cluster: PhotoCluster) {
        let venue = cluster.venue
        var entry = GameEntry(sport: venue.sports.first ?? .baseball,
                              date: cluster.start,
                              venueId: venue.id,
                              photos: cluster.assetIds.prefix(12).map { PhotoRef.library($0) },
                              origin: .photos)
        if let lookup, lookupFor == cluster.id {
            entry.sport = .baseball
            entry.homeTeamId = lookup.homeTeamId
            entry.awayTeamId = lookup.awayTeamId
            entry.homeScore = lookup.homeScore
            entry.awayScore = lookup.awayScore
            entry.lineHome = lookup.lineHome
            entry.lineAway = lookup.lineAway
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
