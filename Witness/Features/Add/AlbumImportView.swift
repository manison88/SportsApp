import SwiftUI

/// Bring a whole trip in from an album the fan already made. Photos with time and place match themselves;
/// for the rest we ask: which stadium was this day, or when were these taken.
struct AlbumImportView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable { case loading, denied, choose, scanning, review }

    /// A visit plus what we learned about it.
    struct Item: Identifiable, Hashable {
        var cluster: PhotoCluster
        var game: FoundGame?
        var onScoreboard = false
        var foundByScoreboard = false
        var ticket: TicketDraft?
        var doubtful = false
        var included = true
        var id: String { cluster.id }
    }

    @State private var phase: Phase = .loading
    @State private var albums: [PhotoAlbum] = []
    @State private var album: PhotoAlbum?
    @State private var items: [Item] = []
    @State private var unplaced: [DayPile] = []
    @State private var undated: [String] = []
    @State private var progress = ""
    @State private var pickingDay: DayPile?
    @State private var pickedVenueId: String?
    @State private var datingUndated = false
    @State private var undatedDate = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now
    @State private var undatedVenueId: String?

    var body: some View {
        NavigationStack {
            content
                .scrollContentBackground(.hidden)
                .background(Color.ink.ignoresSafeArea())
                .navigationTitle(album?.title ?? "Import an album")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { close() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Close")
                            .accessibilityIdentifier("album-close")
                    }
                }
        }
        .task { await start() }
        .sheet(item: $pickingDay) { day in
            NavigationStack { VenuePickerView(venueId: $pickedVenueId, sport: nil) }
                .onChange(of: pickedVenueId) { _, id in
                    guard let id, let venue = library.venue(id) else { return }
                    pickingDay = nil
                    pickedVenueId = nil
                    Task { await place(day, at: venue) }
                }
        }
        .sheet(isPresented: $datingUndated) { undatedSheet }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading, .scanning:
            VStack(spacing: Spacing.inner) {
                ProgressView().controlSize(.large).tint(.white)
                Text(progress.isEmpty ? "Opening your albums" : progress)
                    .font(.condensed(.headline))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            ContentUnavailableView("Witness can't see your albums", systemImage: "photo.on.rectangle",
                                   description: Text("Allow photo access in Settings to import an album."))
        case .choose:
            List(albums) { a in
                Button { Task { await scan(a) } } label: { albumRow(a) }
                    .listRowBackground(Color.panel)
                    .accessibilityIdentifier("album-\(a.title)")
            }
            .overlay {
                if albums.isEmpty {
                    ContentUnavailableView("No albums yet", systemImage: "rectangle.stack",
                                           description: Text("Make an album in Photos for a trip, then import it here."))
                }
            }
        case .review:
            review
        }
    }

    private func albumRow(_ a: PhotoAlbum) -> some View {
        HStack(spacing: 14) {
            Color.panelRaised
                .frame(width: 56, height: 56)
                .overlay { if let c = a.coverId { PhotoView(ref: .library(c)) } }
                .clipShape(.rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(a.title).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).foregroundStyle(.white)
                Text(albumDetail(a)).font(.footnote).foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .frame(minHeight: 64)
        .contentShape(.rect)
    }

    private func albumDetail(_ a: PhotoAlbum) -> String {
        let count = a.count == 1 ? "1 photo" : "\(a.count) photos"
        guard let s = a.start, let e = a.end else { return count }
        let range = Calendar.current.isDate(s, inSameDayAs: e) ? Fmt.dayTitle(s) : "\(Fmt.dayTitle(s)) – \(Fmt.dayTitle(e))"
        return "\(count) · \(range)"
    }

    // MARK: Review

    private var review: some View {
        let chosen = items.filter(\.included).count
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                HStack(alignment: .center, spacing: 14) {
                    Text("\(items.count)").displayFont(110)
                    Text(items.count == 1 ? "Game in\nthis album" : "Games in\nthis album")
                        .displayFont(30, relativeTo: .title)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("album-found")

                if !items.isEmpty {
                    VStack(spacing: 0) {
                        ForEach($items) { $item in visitRow($item) }
                    }
                }

                if !unplaced.isEmpty || !undated.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(unplaced) { day in
                            Button { pickingDay = day } label: {
                                askRow(symbol: "mappin.and.ellipse", title: "Which stadium?",
                                       detail: "\(Fmt.dayTitle(day.day)) · \(photoCount(day.assetIds.count))")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("album-ask-\(day.id)")
                        }
                        if !undated.isEmpty {
                            Button { datingUndated = true } label: {
                                askRow(symbol: "calendar.badge.questionmark", title: "When were these?",
                                       detail: "\(photoCount(undated.count)) with no date")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("album-ask-undated")
                        }
                    }
                }

                Button {
                    addGames()
                } label: {
                    Text(chosen == 1 ? "Add 1 game" : "Add \(chosen) games")
                }
                .buttonStyle(.primary)
                .disabled(chosen == 0)
                .opacity(chosen == 0 ? 0.5 : 1)
                .accessibilityIdentifier("album-add")

                Label("Read on this iPhone, scoreboards included", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, Spacing.block)
        }
    }

    private func visitRow(_ item: Binding<Item>) -> some View {
        let i = item.wrappedValue
        let venue = i.cluster.venue
        return HStack(spacing: 12) {
            Color.panelRaised
                .frame(width: 52, height: 52)
                .overlay { if let id = i.cluster.assetIds.last { PhotoView(ref: .library(id)) } }
                .clipShape(.rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(venue.name).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).foregroundStyle(.white).lineLimit(1)
                Text(Fmt.dayTitle(i.cluster.start, in: venue.tz) + " · " + photoCount(i.cluster.assetIds.count))
                    .font(.footnote).foregroundStyle(Color.textSecondary)
                if let game = i.game {
                    HStack(spacing: 6) {
                        TeamTile(team: GameLookup.team(from: game.away, game: game), compact: true)
                        Text(game.away.score.map(String.init) ?? "").font(.condensed(.subheadline, weight: .heavy))
                        TeamTile(team: GameLookup.team(from: game.home, game: game), compact: true)
                        Text(game.home.score.map(String.init) ?? "").font(.condensed(.subheadline, weight: .heavy))
                        if i.onScoreboard {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.trophy)
                                .accessibilityLabel(i.foundByScoreboard ? "Found from the scoreboard" : "Seen on the scoreboard")
                                .accessibilityIdentifier("album-scoreboard")
                        }
                    }
                    .foregroundStyle(.white)
                } else {
                    Text("No game on the schedule").font(.footnote).foregroundStyle(Color.textTertiary)
                }
                if i.ticket != nil {
                    Label("From your ticket", systemImage: "ticket.fill").font(.footnote).foregroundStyle(Color.textSecondary)
                } else if i.doubtful {
                    Label("Doesn't look like inside. Include?", systemImage: "questionmark.circle")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                        .accessibilityIdentifier("album-doubtful")
                }
            }
            Spacer(minLength: 8)
            Toggle("Include", isOn: item.included).labelsHidden().tint(.white)
        }
        .frame(minHeight: 76)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
    }

    private func askRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Color.signal).frame(width: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).foregroundStyle(.white)
                Text(detail).font(.footnote).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 64)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
    }

    private var undatedSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $undatedDate)
                    .accessibilityIdentifier("album-undated-date")
                NavigationLink {
                    VenuePickerView(venueId: $undatedVenueId, sport: nil)
                } label: {
                    LabeledContent("Venue", value: undatedVenueId.flatMap { library.venue($0)?.name } ?? "Choose")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle(photoCount(undated.count))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { datingUndated = false } label: { Image(systemName: "xmark") }.accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        datingUndated = false
                        if let v = undatedVenueId.flatMap({ library.venue($0) }) {
                            Task { await placeUndated(at: v, on: undatedDate) }
                        }
                    } label: { Image(systemName: "checkmark") }
                    .buttonStyle(.borderedProminent)
                    .disabled(undatedVenueId == nil)
                    .accessibilityLabel("Done")
                }
            }
        }
    }

    private func photoCount(_ n: Int) -> String { n == 1 ? "1 photo" : "\(n) photos" }

    // MARK: Work

    private func start() async {
        guard phase == .loading else { return }
        guard await PhotoMatcher.requestAccess() else { phase = .denied; return }
        if ProcessInfo.processInfo.arguments.contains("-seedAlbum") {
            await AlbumImporter.makeAlbumOfEverything(named: "Chicago weekend")
        }
        albums = AlbumImporter.albums()
        phase = .choose
    }

    private func scan(_ a: PhotoAlbum) async {
        album = a
        phase = .scanning
        progress = "Reading \(photoCount(a.count))"
        let venues = library.venues
        let points = AlbumImporter.points(in: a.id)
        let found = VisitGrouping.group(points, venues: venues)
        undated = found.undated
        items = found.visits.map { Item(cluster: $0) }
        var days = found.unplacedDays

        // Ticket screenshots in the album pin their game even when the night's photos have no GPS.
        progress = "Looking for tickets"
        let anchors = await TicketAnchors.find(in: TicketAnchors.screenshots(limit: 500, inAlbum: a.id),
                                               teams: library.allTeams, venues: venues)
        for anchor in anchors {
            let key = VisitGrouping.key(venueId: anchor.venue.id, date: anchor.date, tz: anchor.venue.tz)
            if let i = items.firstIndex(where: { $0.id == key }) {
                items[i].ticket = anchor.draft
                continue
            }
            // That day's unplaced photos belong to the ticket's game.
            let day = VisitGrouping.dayString(anchor.date, tz: .current)
            let pile = days.first { $0.id == day }
            days.removeAll { $0.id == day }
            let ids = (pile?.assetIds ?? []) + (pile?.assetIds.contains(anchor.id) == true ? [] : [anchor.id])
            let times = (pile?.times ?? []) + (pile?.assetIds.contains(anchor.id) == true ? [] : [anchor.date])
            items.append(Item(cluster: PhotoCluster(id: key, venue: anchor.venue, start: times.min() ?? anchor.date,
                                                    end: times.max() ?? anchor.date, assetIds: ids, times: times),
                              ticket: anchor.draft))
        }

        for index in items.indices {
            let c = items[index].cluster
            progress = "Checking \(c.venue.name)"
            items[index].game = await bestGame(for: c)
            if let game = items[index].game {
                let readings = await ScoreboardReader.read(c.assetIds.map { PhotoRef.library($0) })
                items[index].onScoreboard = readings.contains { ScoreboardReader.support($0, for: game) > 0 }
            }
            // Party near a downtown stadium? Look at the photos before pre-selecting.
            if items[index].ticket == nil && !items[index].onScoreboard,
               let scene = await SceneCheck.verdict(for: c.assetIds.map { PhotoRef.library($0) }), scene.doubtful {
                items[index].doubtful = true
                items[index].included = false
            }
        }

        // Days without a stadium: try the scoreboard before asking.
        var stillUnplaced: [DayPile] = []
        for day in days {
            progress = "Reading scoreboards from \(Fmt.dayTitle(day.day))"
            let readings = await ScoreboardReader.read(day.assetIds.map { PhotoRef.library($0) })
            if let game = await ScoreboardReader.findGame(around: day.times, boards: readings),
               let venue = GameLookup.venue(of: game, in: venues) {
                let cluster = PhotoCluster(id: VisitGrouping.key(venueId: venue.id, date: game.start, tz: venue.tz),
                                           venue: venue, start: day.times.first ?? day.day, end: day.times.last ?? day.day,
                                           assetIds: day.assetIds, times: day.times)
                items.append(Item(cluster: cluster, game: game, onScoreboard: true, foundByScoreboard: true))
            } else {
                stillUnplaced.append(day)
            }
        }
        unplaced = stillUnplaced
        items.sort { $0.cluster.start < $1.cluster.start }
        phase = .review
    }

    private func bestGame(for cluster: PhotoCluster) async -> FoundGame? {
        for venue in [cluster.venue] + PhotoMatcher.neighbors(of: cluster.venue, in: library.venues) {
            if let game = await GameLookup.games(at: venue, from: cluster.start, to: cluster.end).first { return game }
        }
        return nil
    }

    /// The fan told us where a day's photos were taken.
    private func place(_ day: DayPile, at venue: Venue) async {
        let cluster = PhotoCluster(id: VisitGrouping.key(venueId: venue.id, date: day.day, tz: venue.tz), venue: venue,
                                   start: day.times.first ?? day.day, end: day.times.last ?? day.day,
                                   assetIds: day.assetIds, times: day.times)
        unplaced.removeAll { $0.id == day.id }
        let start = Calendar.current.startOfDay(for: day.day)
        var item = Item(cluster: cluster)
        item.game = await GameLookup.games(at: venue, from: start.addingTimeInterval(5 * 3600),
                                           to: start.addingTimeInterval(24 * 3600)).first
        items.append(item)
        items.sort { $0.cluster.start < $1.cluster.start }
    }

    /// The fan told us when and where the undated photos were taken.
    private func placeUndated(at venue: Venue, on date: Date) async {
        let ids = undated
        undated = []
        let cluster = PhotoCluster(id: VisitGrouping.key(venueId: venue.id, date: date, tz: venue.tz), venue: venue,
                                   start: date, end: date, assetIds: ids, times: ids.map { _ in date })
        var item = Item(cluster: cluster)
        item.game = await GameLookup.games(at: venue, from: date.addingTimeInterval(-6 * 3600),
                                           to: date.addingTimeInterval(6 * 3600)).first
        items.append(item)
        items.sort { $0.cluster.start < $1.cluster.start }
    }

    private func addGames() {
        let chosen = items.filter(\.included)
        var created: [GameEntry] = []
        for item in chosen {
            let c = item.cluster
            var entry = GameEntry(sport: c.venue.sports.first ?? .baseball, date: item.game?.start ?? c.start,
                                  venueId: c.venue.id, photos: c.assetIds.suffix(24).map { PhotoRef.library($0) },
                                  origin: item.ticket == nil ? .photos : .ticket)
            entry.seat = item.ticket?.seatLine
            if let game = item.game {
                GameLookup.apply(game, detail: nil, to: &entry, library: library)
                let id = entry.id
                Task {
                    guard let detail = await GameLookup.detail(game), var saved = library.game(id) else { return }
                    GameLookup.apply(game, detail: detail, to: &saved, library: library)
                    library.update(saved)
                }
            }
            created.append(entry)
        }
        if created.count >= 2, let album {
            let trip = makeTrip(album, games: created)
            for i in created.indices { created[i].tripId = trip.id }
            library.addTrip(trip)
        }
        for g in created { library.add(g) }
        close()
    }

    /// A trip named after the album: home, then each game's city and game, then home.
    private func makeTrip(_ album: PhotoAlbum, games: [GameEntry]) -> Trip {
        let home = library.profile
        let sorted = games.sorted { $0.date < $1.date }
        var stops: [Trip.Stop] = [.init(city: home.homeCity, latitude: home.homeLatitude, longitude: home.homeLongitude,
                                        date: sorted.first!.date.addingTimeInterval(-86_400), kind: .depart)]
        for g in sorted {
            guard let v = library.venue(g.venueId) else { continue }
            stops.append(.init(city: v.city, latitude: v.latitude, longitude: v.longitude, date: g.date, kind: .city))
            stops.append(.init(city: v.name, latitude: v.latitude, longitude: v.longitude, date: g.date, kind: .game, venueId: v.id))
        }
        stops.append(.init(city: home.homeCity, latitude: home.homeLatitude, longitude: home.homeLongitude,
                           date: sorted.last!.date.addingTimeInterval(86_400), kind: .return))
        return Trip(id: "album-" + album.id.replacingOccurrences(of: "/", with: "-"), title: album.title, gameIds: sorted.map(\.id),
                    startDate: sorted.first!.date, endDate: sorted.last!.date, stops: stops)
    }

    private func close() {
        if presenter.modal != nil { presenter.modal = nil }
        dismiss()
    }
}
