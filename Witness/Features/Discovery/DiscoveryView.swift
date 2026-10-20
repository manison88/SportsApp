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
    /// Visits at a stadium with no game on the schedule: a concert, a tour, a tailgate. Reviewed after the games.
    @State private var others: [PhotoCluster] = []
    @State private var otherIndex = 0
    @State private var addedOther = 0
    @State private var otherKind = "Concert"
    @State private var otherTitle = ""
    /// Days that might be games: the fan selects the stadium, then the photos' date finds the game.
    @State private var possible: [PossibleDay] = []
    @State private var possibleIndex = 0
    @State private var possibleVenue: Venue?
    @State private var possibleMatch: (game: FoundGame?, shift: Int)?
    @State private var pickedVenueId: String?
    @State private var pickingVenue = false
    /// Every photo of the visit under review, full screen: which it is, and where to start.
    @State private var viewing: ReviewPhotos?
    @State private var clusters: [PhotoCluster] = []
    @State private var index = 0
    @State private var confirmed = 0
    @State private var lookup: FoundGame?
    /// Who the fan was there for at the game on screen; nil means the default (your teams, else home).
    @State private var rootingId: String?
    @State private var lookupFor: String?
    @State private var checkedFor: String?
    @State private var lookupVenue: Venue?
    @State private var onScoreboard = false
    @State private var scene: SceneVerdict?
    /// Visits backed by a ticket screenshot, by visit key.
    @State private var tickets: [String: TicketDraft] = [:]
    /// Pairs of visits the fan said are not the same game.
    @State private var declinedJoins: Set<String> = []

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
        .fullScreenCover(item: $viewing) { item in
            PhotoPager(photos: item.ids.map { PhotoRef.library($0) }, start: item.start)
        }
    }

    /// Six of the visit's photos; tap one to see them all. With more than six, a line under the grid says so and opens them.
    private func photoGrid(_ ids: [String]) -> some View {
        let shown = Array(ids.prefix(6))
        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(Array(shown.enumerated()), id: \.element) { i, id in
                    Button { viewing = ReviewPhotos(ids: ids, start: i) } label: {
                        Color.panel.aspectRatio(1, contentMode: .fit)
                            .overlay { PhotoView(ref: .library(id)) }
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo \(i + 1) of \(ids.count)")
                    .accessibilityIdentifier("discovery-photo-\(i)")
                }
            }
            if ids.count > shown.count {
                Button { viewing = ReviewPhotos(ids: ids, start: 0) } label: {
                    Label("See all \(ids.count) photos", systemImage: "photo.on.rectangle")
                        .font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase).tracking(1)
                        .foregroundStyle(Color.signal)
                        .frame(minHeight: 36)
                }
                .accessibilityIdentifier("discovery-photos-all")
            }
        }
    }


    @ViewBuilder
    private var content: some View {
        switch phase {
        case .requesting:
            Color.clear
        case .scanning:
            ScanProgressView(scan: presenter.scan)
                .frame(maxWidth: .infinity)
        case .denied:
            message(title: "Witness can't see your photos.",
                    body: "Allow photo access in Settings and Witness will match them to stadiums on this iPhone.",
                    showSettings: true, limited: false, id: "discovery-denied")
        case .results:
            if clusters.isEmpty && others.isEmpty && possible.isEmpty {
                let limited = PhotoAccess.current.isLimited
                let why = [limited ? PhotoAccess.limitedMessage : nil, PhotoAccess.uncheckedLine(presenter.scan.uncheckedVisits)]
                    .compactMap { $0 }.joined(separator: "\n\n")
                message(title: "No games found in your photos yet.", body: why.isEmpty ? nil : why,
                        showSettings: false, limited: limited, id: "discovery-empty")
            } else if index >= clusters.count {
                // Games first; then the visits that were near a stadium but not a game.
                if possibleIndex < possible.count { possibleReview(possible[possibleIndex]) }
                else if otherIndex < others.count { otherReview(others[otherIndex]) } else { done }
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
                        .tint(Color.primaryText)
                    Text("\(confirmed) of \(clusters.count) confirmed").unitLabel()
                }

                card(cluster)

                joinPrompt(cluster)

                if clusters.count - index > 1 {
                    Button("Add all \(clusters.count - index) games") { addAll() }
                        .buttonStyle(.secondary)
                        .accessibilityIdentifier("discovery-add-all")
                }

                HStack(spacing: Spacing.inner) {
                    Button("Skip") { presenter.scan.dismiss(cluster.assetIds, on: cluster.start, times: cluster.times, asGame: !noGame(cluster)); advance() }
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

    /// Photos from the next (or previous) day at this stadium may be the same game: ask before joining them.
    @ViewBuilder
    private func joinPrompt(_ cluster: PhotoCluster) -> some View {
        let pool = clusters.filter { !declinedJoins.contains(VisitGrouping.pairKey(cluster.id, $0.id)) }
        if let other = VisitGrouping.possibleSameGame(as: cluster, in: pool) {
            VStack(alignment: .leading, spacing: Spacing.inner) {
                Label("Same game? \(Fmt.dayTitle(other.start, in: other.venue.tz)) has \(other.assetIds.count) \(other.assetIds.count == 1 ? "photo" : "photos") at this stadium, a few hours \(other.start < cluster.start ? "before" : "after").",
                      systemImage: "square.on.square")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                HStack(spacing: Spacing.inner) {
                    Button("Keep separate") { declinedJoins.insert(VisitGrouping.pairKey(cluster.id, other.id)) }
                        .buttonStyle(.secondary)
                        .accessibilityIdentifier("discovery-join-no")
                    Button("Combine") { combine(cluster, other) }
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("discovery-join-yes")
                }
            }
            .padding(14)
            .background(Color.panel, in: .rect(cornerRadius: 14))
        }
    }

    /// Folds two visits into one card, at the earlier one's place in the list.
    private func combine(_ cluster: PhotoCluster, _ other: PhotoCluster) {
        let merged = cluster.combined(with: other)
        let at = min(clusters.firstIndex { $0.id == cluster.id } ?? index, clusters.firstIndex { $0.id == other.id } ?? index)
        if tickets[merged.id] == nil { tickets[merged.id] = tickets[cluster.id] ?? tickets[other.id] }
        clusters.removeAll { $0.id == cluster.id || $0.id == other.id }
        clusters.insert(merged, at: min(at, clusters.count))
        index = min(at, clusters.count - 1)
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
                    FoundGameChip(game: lookup)
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
            let hidden = cluster.assetIds.count - ids.count
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(Array(ids.enumerated()), id: \.element) { i, _ in
                    let id = ids[i]
                    let time = cluster.times.indices.contains(i) ? cluster.times[i] : cluster.start
                    Button { viewing = ReviewPhotos(ids: cluster.assetIds, start: i) } label: {
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
                            .overlay {
                                // The last tile carries the rest, so four thumbnails don't read as "four photos".
                                if i == ids.count - 1, hidden > 0 {
                                    ZStack {
                                        Color.black.opacity(0.55)
                                        Text("+\(hidden.formatted())")
                                            .font(.condensed(.title, weight: .heavy))
                                            .foregroundStyle(.white)
                                    }
                                    .clipShape(.rect(cornerRadius: 8))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo \(i + 1) of \(cluster.assetIds.count)")
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(cluster.assetIds.count) photos at \(cluster.venue.name)")

            rootingPicker(cluster)

            Label("\(cluster.assetIds.count.formatted()) \(cluster.assetIds.count == 1 ? "photo" : "photos") will be added to this game",
                  systemImage: "photo.on.rectangle")
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
                .accessibilityIdentifier("discovery-photo-count")

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

    // MARK: Rooting

    /// The catalog team for a schedule side, so "your teams" recognizes it.
    private func resolved(_ side: FoundGame.Side, in game: FoundGame) -> Team {
        library.catalogTeam(league: game.league, espnId: side.espnId)
            ?? library.allTeams.first { $0.sport == game.sport && $0.abbreviation == side.abbreviation
                && $0.locationName.caseInsensitiveCompare(side.location) == .orderedSame }
            ?? GameLookup.team(from: side, game: game)
    }

    /// Your team if it is playing, else the home side.
    private func defaultRoot(_ home: Team, _ away: Team) -> String {
        let favorites = Set(library.profile.favoriteTeamIds)
        return favorites.contains(home.id) ? home.id : favorites.contains(away.id) ? away.id : home.id
    }

    @ViewBuilder
    private func rootingPicker(_ cluster: PhotoCluster) -> some View {
        if let game = lookup, lookupFor == cluster.id, game.race == nil, game.sport != .motorsport {
            let home = resolved(game.home, in: game), away = resolved(game.away, in: game)
            VStack(alignment: .leading, spacing: 8) {
                RootingPicker(teams: [away, home], selection: Binding(
                    get: { rootingId ?? defaultRoot(home, away) },
                    set: { rootingId = $0 }),
                              known: !Set(library.profile.favoriteTeamIds).isDisjoint(with: [home.id, away.id]))
            }
            .accessibilityIdentifier("discovery-rooting")
        }
    }

    // MARK: Possible

    /// A day that might be a game. Instead of asking who you rooted for, ask which stadium: the date of the photos then
    /// finds the game there, or says there was none.
    private func possibleReview(_ day: PossibleDay) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Possible game").displayFont(48).textCase(.uppercase)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .accessibilityIdentifier("discovery-possible-title")
                        Spacer(minLength: 8)
                        Text("\(possibleIndex + 1) of \(possible.count)").unitLabel()
                    }
                    Text(day.reason).font(.subheadline).foregroundStyle(Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("\(Fmt.dayTitle(day.day)) \u{00B7} \(day.assetIds.count) \(day.assetIds.count == 1 ? "photo" : "photos")")
                        .font(.condensed(.title3, weight: .heavy)).textCase(.uppercase)
                    photoGrid(day.assetIds)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Which stadium?").unitLabel()
                        Spacer()
                        if !day.suggestions.isEmpty {
                            Button { pickingVenue = true } label: {
                                Label("Another stadium", systemImage: "mappin.and.ellipse")
                                    .font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase).tracking(1)
                                    .foregroundStyle(Color.signal)
                                    .frame(minHeight: 44)
                            }
                            .accessibilityIdentifier("discovery-possible-select")
                        }
                    }
                    ForEach(day.suggestions) { venue in
                        if possibleVenue?.id != venue.id {
                            Button { Task { await choosePossible(venue, for: day) } } label: {
                                HStack(spacing: 10) {
                                    Text(venue.name).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                                    Spacer()
                                    Text(venue.cityLine).font(.footnote).foregroundStyle(Color.textSecondary)
                                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary)
                                        .accessibilityHidden(true)
                                }
                                .foregroundStyle(Color.primaryText)
                                .padding(.horizontal, 14).frame(minHeight: 52)
                                .background(Color.panelRaised, in: .rect(cornerRadius: 12))
                            }
                            .accessibilityIdentifier("discovery-possible-suggest-\(venue.id)")
                        }
                    }
                    if let venue = possibleVenue {
                        chosenStadium(venue)
                    } else if day.suggestions.isEmpty {
                        Button { pickingVenue = true } label: {
                            Label("Select stadium", systemImage: "mappin.and.ellipse")
                        }
                        .buttonStyle(.secondary)
                        .accessibilityIdentifier("discovery-possible-select")
                    }
                }
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        // The answer stays in reach: Skip and Add sit under the scroll, never below it.
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: Spacing.inner) {
                Button("Skip") { presenter.scan.dismiss(day.assetIds, on: day.day, times: day.times); advancePossible() }
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 120)
                    .accessibilityIdentifier("discovery-possible-skip")
                if let venue = possibleVenue, let result = possibleMatch {
                    Button { addPossible(day, venue: venue, game: result.game) } label: {
                        Label(result.game == nil ? "Save visit" : "Add game", systemImage: "plus")
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("discovery-possible-add")
                } else if possibleVenue != nil {
                    Button {} label: { HStack(spacing: 8) { ProgressView().tint(.black); Text("Checking") } }
                        .buttonStyle(.primary).disabled(true).opacity(0.6)
                } else {
                    Button { if let first = day.suggestions.first { Task { await choosePossible(first, for: day) } } else { pickingVenue = true } } label: {
                        Label("Pick a stadium", systemImage: "mappin.and.ellipse")
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("discovery-possible-pick")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color.ink)
        }
        .scrollIndicators(.hidden)
        .task(id: day.id) {
            // The likeliest ground is checked as the screen opens, so the game and Add are there without a tap.
            if possibleVenue == nil, let first = day.suggestions.first { await choosePossible(first, for: day) }
        }
        .sheet(isPresented: $pickingVenue) {
            NavigationStack { VenuePickerView(venueId: $pickedVenueId, sport: nil) }
        }
        .onChange(of: pickedVenueId) { _, id in
            guard let id, let venue = library.venue(id) else { return }
            pickedVenueId = nil
            Task { await choosePossible(venue, for: day) }
        }
    }

    /// The chosen stadium and what its schedule says about the photos' day, in one card.
    private func chosenStadium(_ venue: Venue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(venue.name).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                Spacer()
                Image(systemName: "checkmark.circle.fill").font(.title3).accessibilityHidden(true)
            }
            Rectangle().fill(Color.hairline).frame(height: 1)
            if let result = possibleMatch {
                if let game = result.game {
                    HStack {
                        FoundGameChip(game: game).accessibilityIdentifier("discovery-possible-match")
                        Spacer(minLength: 8)
                        Text(game.completed ? "Final \u{00B7} \(game.leagueName)" : game.leagueName)
                            .font(.footnote.weight(.semibold)).foregroundStyle(Color.textSecondary).lineLimit(1)
                    }
                    if result.shift != 0 {
                        Text("Nearest game: \(Fmt.dayTitle(game.start, in: venue.tz)), a day \(result.shift < 0 ? "before" : "after") your photos")
                            .font(.footnote.weight(.semibold)).foregroundStyle(Color.signal)
                    }
                } else {
                    Label("No game here on that date. Save it as a stadium visit?", systemImage: "calendar.badge.exclamationmark")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                        .accessibilityIdentifier("discovery-possible-none")
                }
            } else {
                HStack(spacing: 8) { ProgressView().tint(Color.primaryText); Text("Checking the schedule").font(.footnote).foregroundStyle(Color.textSecondary) }
            }
        }
        .foregroundStyle(Color.primaryText)
        .padding(14)
        .background(Color.panelRaised, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primaryText, lineWidth: 2))
        .accessibilityElement(children: .contain)
    }

    /// The stadium is chosen: the photos' date finds the game there.
    private func choosePossible(_ venue: Venue, for day: PossibleDay) async {
        possibleVenue = venue
        possibleMatch = nil
        let result = await GameLookup.gameNear(day.day, at: venue)
        guard possibleVenue?.id == venue.id, possible.indices.contains(possibleIndex), possible[possibleIndex].id == day.id else { return }
        possibleMatch = result
    }

    private func addPossible(_ day: PossibleDay, venue: Venue, game: FoundGame?) {
        var entry = GameEntry(sport: game?.sport ?? venue.sports.first ?? .baseball, date: game?.start ?? day.day, venueId: venue.id,
                              photos: day.assetIds.map { PhotoRef.library($0) }, origin: .photos)
        if let game {
            GameLookup.apply(game, detail: nil, to: &entry, library: library)
            let id = entry.id
            Task {
                guard let detail = await GameLookup.detail(game), var saved = library.game(id) else { return }
                GameLookup.apply(game, detail: detail, to: &saved, library: library)
                library.update(saved)
            }
        } else {
            entry.kind = .visit
            entry.competition = "Stadium visit"
        }
        library.add(entry)
        confirmed += 1
        advancePossible()
    }

    private func advancePossible() {
        possibleIndex += 1
        possibleVenue = nil
        possibleMatch = nil
    }

    // MARK: Other

    private static let otherKinds = ["Concert", "Stadium tour", "Tailgate", "Other event"]

    /// A visit at or near a stadium with no game on the schedule. The person says what it was, or skips it.
    private func otherReview(_ cluster: PhotoCluster) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Other").displayFont(48).textCase(.uppercase)
                            .accessibilityIdentifier("discovery-other-title")
                        Spacer(minLength: 8)
                        Text("\(otherIndex + 1) of \(others.count)").unitLabel()
                    }
                    Text("Near or at a stadium, but not part of a game on the schedule. A concert, a tour, a tailgate? Add what it was, or skip it.")
                        .font(.subheadline).foregroundStyle(Color.textSecondary)
                }

                if let note = presenter.scan.notes[cluster.id], let game = presenter.scan.matches[cluster.id] {
                    VStack(alignment: .leading, spacing: Spacing.inner) {
                        Label(note, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                            .accessibilityIdentifier("discovery-other-note")
                        Button("I was at the game") { addAsGame(cluster, game) }
                            .buttonStyle(.secondary)
                            .accessibilityIdentifier("discovery-other-was-game")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(cluster.venue.name).font(.condensed(.title3, weight: .heavy)).textCase(.uppercase)
                        Spacer(minLength: 8)
                        Text("\(Fmt.dayTitle(cluster.start, in: cluster.venue.tz)) \u{00B7} \(cluster.assetIds.count) \(cluster.assetIds.count == 1 ? "photo" : "photos")")
                            .font(.footnote).foregroundStyle(Color.textSecondary)
                    }
                    photoGrid(cluster.assetIds)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("What was it?").unitLabel()
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Self.otherKinds, id: \.self) { kind in
                                Button { otherKind = kind } label: {
                                    Text(kind)
                                        .font(.condensed(.subheadline, weight: .heavy))
                                        .textCase(.uppercase)
                                        .foregroundStyle(otherKind == kind ? Color.onPrimary : Color.primaryText)
                                        .padding(.horizontal, 14)
                                        .frame(minHeight: 44)
                                        .background(otherKind == kind ? Color.primaryText : Color.panelRaised, in: .capsule)
                                }
                                .accessibilityAddTraits(otherKind == kind ? .isSelected : [])
                                .accessibilityIdentifier("discovery-other-kind-\(kind)")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    TextField("Name it (optional)", text: $otherTitle)
                        .textInputAutocapitalization(.words)
                        .padding(14)
                        .background(Color.panel, in: .rect(cornerRadius: 12))
                        .accessibilityIdentifier("discovery-other-name")
                }
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        // Skip and Add stay under the scroll; "Add all" is a line above them so it never pushes them off.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if others.count - otherIndex > 1 {
                    Button("Add all \(others.count - otherIndex) as stadium visits") { addAllOthers() }
                        .font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase).tracking(1)
                        .foregroundStyle(Color.signal)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .accessibilityIdentifier("discovery-other-add-all")
                }
                HStack(spacing: Spacing.inner) {
                    Button("Skip") { presenter.scan.dismiss(cluster.assetIds, on: cluster.start, times: cluster.times); advanceOther() }
                        .buttonStyle(.secondary)
                        .frame(maxWidth: 120)
                        .accessibilityIdentifier("discovery-other-skip")
                    Button { addOther(cluster) } label: { Label("Add", systemImage: "plus") }
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("discovery-other-add")
                }
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color.ink)
        }
        .scrollIndicators(.hidden)
    }

    /// The photos didn't look like a game, but the fan says it was: add it as that game from the schedule.
    private func addAsGame(_ cluster: PhotoCluster, _ game: FoundGame) {
        let venue = GameLookup.venue(of: game, in: library.venues) ?? cluster.venue
        var entry = GameEntry(sport: game.sport, date: game.start, venueId: venue.id,
                              photos: cluster.assetIds.map { PhotoRef.library($0) }, origin: .photos)
        GameLookup.apply(game, detail: nil, to: &entry, library: library)
        let id = entry.id
        Task {
            guard let detail = await GameLookup.detail(game), var saved = library.game(id) else { return }
            GameLookup.apply(game, detail: detail, to: &saved, library: library)
            library.update(saved)
        }
        library.add(entry)
        confirmed += 1
        advanceOther()
    }

    private func addOther(_ cluster: PhotoCluster) {
        var entry = GameEntry(sport: cluster.venue.sports.first ?? .baseball, date: cluster.start, venueId: cluster.venue.id,
                              photos: cluster.assetIds.map { PhotoRef.library($0) }, origin: .photos)
        entry.kind = .visit
        entry.competition = otherKind
        let title = otherTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { entry.headline = title }
        library.add(entry)
        addedOther += 1
        advanceOther()
    }

    private func advanceOther() {
        otherIndex += 1
        otherKind = "Concert"
        otherTitle = ""
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            Spacer()
            Text("\(confirmed)")
                .displayFont(120)
            Text(confirmed == 1 ? "Game added" : "Games added")
                .font(.condensed(.title2, weight: .heavy))
                .textCase(.uppercase)
            if addedOther > 0 {
                Text("And \(addedOther) other \(addedOther == 1 ? "event" : "events")")
                    .font(.condensed(.headline, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
            }
            Spacer()
            Button("Done") { close() }
                .buttonStyle(.primary)
                .accessibilityIdentifier("discovery-done")
        }
        .gutter()
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func message(title: String, body: String?, showSettings: Bool, limited: Bool, id: String) -> some View {
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
            } else if limited {
                LimitedAccessButtons()
                Button("Add a game") { addManually() }
                    .buttonStyle(.secondary)
                    .accessibilityIdentifier("discovery-add")
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
        let scan = presenter.scan
        // Onboarding already scanned, matched and read the tickets: go straight to the first game.
        // Results already waiting (the first pass, or the optional second pass over albums and trips) are shown without scanning again.
        let waiting = (scan.state == .done && !scan.reviewed) || (scan.deepState == .done && !scan.deepReviewed)
        if !waiting {
            phase = .scanning
            scan.reset()
            scan.start(library: library)
            while scan.state == .idle || scan.inProgress || (scan.state == .done && !scan.shown) {
                try? await Task.sleep(for: .milliseconds(300))
                if Task.isCancelled { return }
            }
            if scan.state == .denied { phase = .denied; return }
        }
        // Each result is reviewed once: what this screen takes leaves the scan, so a later search shows only its own finds,
        // and anything already added or skipped is left out.
        tickets = scan.tickets
        let review = scan.takeForReview(library: library)
        clusters = review.games
        others = review.others
        possible = review.possible
        phase = .results
    }

    /// Checks the photos' venue and time against real league schedules,
    /// then the venues next door (a stadium and its arena share a parking lot).
    private func lookUp(_ cluster: PhotoCluster) async {
        lookup = nil
        lookupFor = nil
        if let known = presenter.scan.matches[cluster.id] {
            // Already matched during the scan.
            lookup = known
            lookupFor = cluster.id
            lookupVenue = GameLookup.venue(of: known, in: library.venues) ?? cluster.venue
        } else {
            for venue in [cluster.venue] + PhotoMatcher.neighbors(of: cluster.venue, in: library.venues) {
                if let game = await GameLookup.games(at: venue, from: cluster.start, to: cluster.end).first {
                    lookup = game
                    lookupFor = cluster.id
                    lookupVenue = venue
                    break
                }
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
                              photos: cluster.assetIds.map { PhotoRef.library($0) },
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
            if lookup.race == nil, let rootingId {
                let home = resolved(lookup.home, in: lookup), away = resolved(lookup.away, in: lookup)
                entry.rootingForTeamId = rootingId == away.id ? entry.awayTeamId : rootingId == home.id ? entry.homeTeamId : entry.rootingForTeamId
            }
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

    /// Adds every game still waiting, each as the scan matched it, without asking about each one. A card the fan combined
    /// has no scan match yet, so its game is looked up first.
    private func addAll() {
        let rest = Array(clusters[index...])
        index = clusters.count
        Task {
            var found: [String: FoundGame] = [:]
            for cluster in rest where presenter.scan.matches[cluster.id] == nil && tickets[cluster.id] == nil {
                if let game = await ScanModel.match(cluster, venues: library.venues) { found[cluster.id] = game }
            }
            confirmed += presenter.scan.commit(rest, tickets: tickets, matches: found, into: library)
        }
    }

    /// Adds every visit still waiting as a stadium visit.
    private func addAllOthers() {
        let rest = Array(others[otherIndex...])
        addedOther += presenter.scan.commit(rest, asVisits: true, into: library)
        otherIndex = others.count
    }

    private func advance() {
        rootingId = nil
        lookup = nil
        lookupFor = nil
        index += 1
    }

    private func addManually() {
        library.startEmpty()
        presenter.modal = .addGame
    }

    private func close() {
        if (confirmed > 0 || addedOther > 0) && !library.hasLibrary { library.startEmpty() }
        dismiss()
    }
}

/// The photos under review, opened full screen from one of their tiles.
struct ReviewPhotos: Identifiable {
    let ids: [String]
    let start: Int
    var id: String { "\(ids.first ?? "")-\(start)" }
}
