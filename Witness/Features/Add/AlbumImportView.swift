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
        /// Days between the date the fan picked and the day the game was found on (0 = the same day).
        var dayShift = 0
        var included = true
        var id: String { cluster.id }
    }

    @State private var phase: Phase = .loading
    @State private var albums: [PhotoAlbum] = []
    @State private var album: PhotoAlbum?
    /// 0 = the fan's albums, 1 = trips found by where and when photos were taken.
    @State private var source = 0
    @State private var trips: [PhotoAlbum] = []
    @State private var findingTrips = false
    @State private var triedTrips = false
    @State private var items: [Item] = []
    @State private var unplaced: [DayPile] = []
    @State private var skippedDays = 0
    /// Pairs of visits the fan said are not the same game.
    @State private var declinedJoins: Set<String> = []
    @State private var undated: [String] = []
    @State private var progress = ""
    @State private var pickingDay: DayPile?
    /// The day being placed, kept after the sheet closes (picking a venue dismisses it).
    @State private var placingDay: DayPile?
    @State private var pickedVenueId: String?
    @State private var datingUndated = false
    @State private var undatedDate = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now
    @State private var undatedVenueId: String?

    var body: some View {
        NavigationStack {
            content
                .scrollContentBackground(.hidden)
                .background(Color.ink.ignoresSafeArea())
                .navigationTitle(album?.title ?? "Album or trip")
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
        .sheet(item: $pickingDay, onDismiss: placePicked) { _ in
            NavigationStack { VenuePickerView(venueId: $pickedVenueId, sport: nil) }
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
            VStack(spacing: 0) {
                Picker("Import from", selection: $source) {
                    Text("Albums").tag(0)
                    Text("Trips").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, 12)
                .accessibilityIdentifier("album-source")

                List(source == 0 ? albums : trips) { a in
                    Button { Task { await scan(a) } } label: { albumRow(a) }
                        .listRowBackground(Color.panel)
                        .accessibilityIdentifier("album-\(a.title)")
                }
                .overlay {
                    if source == 0 && albums.isEmpty {
                        ContentUnavailableView("No albums yet", systemImage: "rectangle.stack",
                                               description: Text("Make an album in Photos for a trip, or switch to Trips."))
                    } else if source == 1 && findingTrips {
                        VStack(spacing: Spacing.inner) {
                            ProgressView().controlSize(.large).tint(.white)
                            Text("Looking for trips in your photos")
                                .font(.condensed(.headline)).foregroundStyle(Color.textSecondary)
                        }
                    } else if source == 1 && trips.isEmpty {
                        ContentUnavailableView("No trips found", systemImage: "airplane",
                                               description: Text("Trips are stretches of photos taken far from home. Photos need a location."))
                    }
                }
            }
            .onChange(of: source) { _, new in
                if new == 1 && !triedTrips { Task { await loadTrips() } }
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
        let asks = unplaced.count + (undated.isEmpty ? 0 : 1)
        // Photos with no location aren't "no games": lead with the question that gets them placed.
        let needsPlacing = items.isEmpty && asks > 0
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                HStack(alignment: .center, spacing: 14) {
                    Text("\(needsPlacing ? asks : items.count)").displayFont(110)
                    Text(needsPlacing ? (asks == 1 ? "Day to\nplace" : "Days to\nplace")
                                      : (items.count == 1 ? "Game in\nthis album" : "Games in\nthis album"))
                        .displayFont(30, relativeTo: .title)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("album-found")

                if needsPlacing {
                    Text("These photos have no location. Pick the stadium and we'll find the game from the date and time.")
                        .font(.subheadline).foregroundStyle(Color.textSecondary)
                        .accessibilityIdentifier("album-needs-placing")
                }

                if let pair = joinCandidate {
                    joinPrompt(pair.0, pair.1)
                }

                if !items.isEmpty {
                    VStack(spacing: 0) {
                        ForEach($items) { $item in visitRow($item) }
                    }
                }

                if skippedDays > 0 {
                    Label("Skipped \(skippedDays == 1 ? "a day" : "\(skippedDays) days") that didn't look like a game",
                          systemImage: "eye.slash")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                        .accessibilityIdentifier("album-skipped")
                }

                if !unplaced.isEmpty || !undated.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(unplaced) { day in
                            Button { placingDay = day; pickingDay = day } label: {
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
                    Text(chosen == 0 && asks > 0 ? "Choose a stadium first"
                         : chosen == 1 ? "Add 1 game" : "Add \(chosen) games")
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

    /// Two visits at one stadium a few hours apart on consecutive days: probably one game, so ask.
    private var joinCandidate: (Item, Item)? {
        for a in items {
            let pool = items.map(\.cluster).filter { !declinedJoins.contains(VisitGrouping.pairKey(a.cluster.id, $0.id)) }
            if let other = VisitGrouping.possibleSameGame(as: a.cluster, in: pool),
               let b = items.first(where: { $0.id == other.id }) {
                return (a, b)
            }
        }
        return nil
    }

    private func joinPrompt(_ a: Item, _ b: Item) -> some View {
        let first = a.cluster.start <= b.cluster.start ? a : b
        let second = a.cluster.start <= b.cluster.start ? b : a
        let tz = first.cluster.venue.tz
        return VStack(alignment: .leading, spacing: Spacing.inner) {
            Label("Same game? \(Fmt.dayTitle(first.cluster.start, in: tz)) and \(Fmt.dayTitle(second.cluster.start, in: tz)) at \(first.cluster.venue.name), a few hours apart.",
                  systemImage: "square.on.square")
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: Spacing.inner) {
                Button("Keep separate") { declinedJoins.insert(VisitGrouping.pairKey(a.cluster.id, b.cluster.id)) }
                    .buttonStyle(.secondary)
                    .accessibilityIdentifier("album-join-no")
                Button("Combine") { combine(first, second) }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("album-join-yes")
            }
        }
        .padding(14)
        .background(Color.panel, in: .rect(cornerRadius: 14))
    }

    /// One game from two visits: the earlier visit's entry takes the later one's photos.
    private func combine(_ first: Item, _ second: Item) {
        guard let at = items.firstIndex(where: { $0.id == first.id }) else { return }
        var merged = first
        merged.cluster = first.cluster.combined(with: second.cluster)
        merged.game = first.game ?? second.game
        merged.ticket = first.ticket ?? second.ticket
        merged.onScoreboard = first.onScoreboard || second.onScoreboard
        merged.foundByScoreboard = first.foundByScoreboard || second.foundByScoreboard
        merged.doubtful = first.doubtful && second.doubtful
        merged.included = first.included || second.included
        items[at] = merged
        items.removeAll { $0.id == second.id }
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
                    if i.dayShift != 0 {
                        Text("Nearest game: \(Fmt.dayTitle(game.start, in: venue.tz)), a day \(i.dayShift < 0 ? "before" : "after") your date")
                            .font(.footnote.weight(.semibold)).foregroundStyle(Color.signal)
                            .accessibilityIdentifier("album-day-shift")
                    }
                    HStack(spacing: 6) {
                        FoundGameChip(game: game)
                        if i.onScoreboard {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.trophy)
                                .accessibilityLabel(i.foundByScoreboard ? "Found from the scoreboard" : "Seen on the scoreboard")
                                .accessibilityIdentifier("album-scoreboard")
                        }
                    }
                    .foregroundStyle(.white)
                } else {
                    Text(i.ticket == nil ? "No game on the schedule · saved as a stadium visit" : "No game on the schedule")
                        .font(.footnote).foregroundStyle(Color.textTertiary)
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
        albums = await Task.detached { AlbumImporter.albums() }.value
        phase = .choose
    }

    /// Trips from where and when photos were taken, for people who keep a trip in Photos instead of an album.
    private func loadTrips() async {
        findingTrips = true
        let home = library.profile.homeLocation
        let venues = library.venues
        trips = await Task.detached { TripFinder.find(home: home, venues: venues) }.value
        findingTrips = false
        triedTrips = true
    }

    private func scan(_ a: PhotoAlbum) async {
        album = a
        phase = .scanning
        progress = "Reading \(photoCount(a.count))"
        let venues = library.venues
        let found = await Task.detached { VisitGrouping.group(AlbumImporter.points(in: a), venues: venues) }.value
        undated = found.undated
        items = found.visits.map { Item(cluster: $0) }
        var days = found.unplacedDays

        // Ticket screenshots in the album pin their game even when the night's photos have no GPS.
        progress = "Looking for tickets"
        let found2 = await TicketAnchors.find(in: TicketAnchors.screenshots(limit: 500, inAlbum: a.range == nil ? a.id : nil),
                                              teams: library.allTeams, venues: venues)
        // A trip has no album to look in: keep the tickets dated within a day of it.
        let anchors = found2.filter { anchor in
            guard let range = a.range else { return true }
            return (range.lowerBound.addingTimeInterval(-86_400)...range.upperBound.addingTimeInterval(86_400)).contains(anchor.date)
        }
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
            let item = items[index]
            progress = "Checking \(item.cluster.venue.name)"
            let r = await Self.analyze(item.cluster, hasTicket: item.ticket != nil, venues: venues)
            items[index].game = r.game
            items[index].onScoreboard = r.onBoard
            if r.doubtful {
                items[index].doubtful = true
                items[index].included = false
            }
        }

        // Days without a stadium: try the scoreboard before asking, and drop days that don't look like a game.
        var stillUnplaced: [DayPile] = []
        for day in days {
            progress = "Reading photos from \(Fmt.dayTitle(day.day))"
            let r = await Self.analyze(day, venues: venues)
            if let item = r.item { items.append(item) } else if r.skipped { skippedDays += 1 } else { stillUnplaced.append(day) }
        }
        unplaced = stillUnplaced
        items.sort { $0.cluster.start < $1.cluster.start }
        phase = .review
    }

    /// A stadium visit's game, whether a scoreboard backs it, and whether the photos look like a party instead.
    private static func analyze(_ c: PhotoCluster, hasTicket: Bool, venues: [Venue]) async
        -> (game: FoundGame?, onBoard: Bool, doubtful: Bool) {
        var game: FoundGame?
        for venue in [c.venue] + PhotoMatcher.neighbors(of: c.venue, in: venues) {
            if let g = await GameLookup.games(at: venue, from: c.start, to: c.end).first { game = g; break }
        }
        let refs = c.assetIds.map { PhotoRef.library($0) }
        var onBoard = false
        if let game {
            let readings = await ScoreboardReader.read(refs)
            onBoard = readings.contains { ScoreboardReader.confirms($0, game) }
        }
        // Party near a downtown stadium? Look at the photos before pre-selecting.
        var doubtful = false
        if !hasTicket && !onBoard, let scene = await SceneCheck.verdict(for: refs), scene.doubtful { doubtful = true }
        return (game, onBoard, doubtful)
    }

    /// A day with no stadium fix: a scoreboard in the photos can still name the game; otherwise sightseeing is skipped.
    private static func analyze(_ day: DayPile, venues: [Venue]) async -> (item: Item?, skipped: Bool) {
        let refs = day.assetIds.map { PhotoRef.library($0) }
        let readings = await ScoreboardReader.read(refs)
        if let game = await ScoreboardReader.findGame(around: day.times, boards: readings),
           let venue = GameLookup.venue(of: game, in: venues) {
            let cluster = PhotoCluster(id: VisitGrouping.key(venueId: venue.id, date: game.start, tz: venue.tz),
                                       venue: venue, start: day.times.first ?? day.day, end: day.times.last ?? day.day,
                                       assetIds: day.assetIds, times: day.times)
            return (Item(cluster: cluster, game: game, onScoreboard: true, foundByScoreboard: true), false)
        }
        if let scene = await SceneCheck.verdict(for: refs), scene.sports < 0.15 { return (nil, true) }
        return (nil, false)
    }

    private func bestGame(for cluster: PhotoCluster) async -> FoundGame? {
        for venue in [cluster.venue] + PhotoMatcher.neighbors(of: cluster.venue, in: library.venues) {
            if let game = await GameLookup.games(at: venue, from: cluster.start, to: cluster.end).first { return game }
        }
        return nil
    }

    /// The venue picker closed: if it picked a venue, that is where the day's photos were taken.
    private func placePicked() {
        defer { placingDay = nil; pickedVenueId = nil }
        guard let day = placingDay, let id = pickedVenueId, let venue = library.venue(id) else { return }
        Task { await place(day, at: venue) }
    }

    /// The fan told us where a day's photos were taken.
    private func place(_ day: DayPile, at venue: Venue) async {
        let cluster = PhotoCluster(id: VisitGrouping.key(venueId: venue.id, date: day.day, tz: venue.tz), venue: venue,
                                   start: day.times.first ?? day.day, end: day.times.last ?? day.day,
                                   assetIds: day.assetIds, times: day.times)
        unplaced.removeAll { $0.id == day.id }
        // The venue's own calendar day, not the phone's: a game in Seattle is still that Seattle evening.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = venue.tz
        let start = cal.startOfDay(for: day.times.first ?? day.day)
        var item = Item(cluster: cluster)
        let games = await GameLookup.games(at: venue, from: start.addingTimeInterval(5 * 3600),
                                           to: start.addingTimeInterval(24 * 3600))
        let middle = day.times.sorted().dropFirst(day.times.count / 2).first ?? day.day
        item.game = games.min { abs($0.start.timeIntervalSince(middle)) < abs($1.start.timeIntervalSince(middle)) }
        items.append(item)
        items.sort { $0.cluster.start < $1.cluster.start }
    }

    /// The game at a stadium on the calendar day the fan picked, whatever the sport or competition. The day is the stadium's own
    /// day, from midnight to midnight (a 5 pm kickoff is that day, wherever the phone is). When that day has no game, the day
    /// before and the day after are checked, since a remembered date is often a day off; the shift says which one matched.
    static func gameNear(_ date: Date, at venue: Venue) async -> (game: FoundGame?, shift: Int) {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = venue.tz
        guard let picked = cal.date(from: parts) else { return (nil, 0) }
        for shift in [0, -1, 1] {
            guard let start = cal.date(byAdding: .day, value: shift, to: picked),
                  let end = cal.date(byAdding: .day, value: 1, to: start) else { continue }
            let games = await GameLookup.games(at: venue, from: start, to: end).filter { $0.start >= start && $0.start < end }
            let evening = start.addingTimeInterval(19 * 3600)
            if let best = games.min(by: { abs($0.start.timeIntervalSince(evening)) < abs($1.start.timeIntervalSince(evening)) }) {
                return (best, shift)
            }
        }
        return (nil, 0)
    }

    /// The fan told us when and where the undated photos were taken.
    private func placeUndated(at venue: Venue, on date: Date) async {
        let ids = undated
        undated = []
        let cluster = PhotoCluster(id: VisitGrouping.key(venueId: venue.id, date: date, tz: venue.tz), venue: venue,
                                   start: date, end: date, assetIds: ids, times: ids.map { _ in date })
        var item = Item(cluster: cluster)
        let found = await Self.gameNear(date, at: venue)
        item.game = found.game
        item.dayShift = found.shift
        items.append(item)
        items.sort { $0.cluster.start < $1.cluster.start }
    }

    private func addGames() {
        let chosen = items.filter(\.included)
        var created: [GameEntry] = []
        for item in chosen {
            let c = item.cluster
            var entry = GameEntry(sport: c.venue.sports.first ?? .baseball, date: item.game?.start ?? c.start,
                                  venueId: c.venue.id, photos: c.assetIds.map { PhotoRef.library($0) },
                                  origin: item.ticket == nil ? .photos : .ticket)
            entry.seat = item.ticket?.seatLine
            if item.game == nil && item.ticket == nil && !GameLookup.leagues(for: c.venue).isEmpty {
                entry.kind = .visit
                entry.competition = "Stadium visit"
            }
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
