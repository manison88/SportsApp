import SwiftUI
import CoreLocation

/// 12 · At the game. Keep score loosely, tap to save moments, save the game at the end.
struct LiveCheckInView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var location = LocationService()

    @State private var started = false
    @State private var startedAt = Date.now
    @State private var venueId: String = ""
    @State private var sport: Sport = .baseball
    @State private var homeId: String = ""
    @State private var awayId: String = ""
    @State private var seat = ""

    @State private var homeScore = 0
    @State private var awayScore = 0
    /// Half-innings for baseball (0 = Top 1st), periods otherwise.
    @State private var period = 0
    @State private var outs = 0
    @State private var bases = [false, false, false]
    @State private var moments: [Date] = []
    @State private var suggested = false
    /// Games on the schedule at the stadium you're standing in, found from your location and the time.
    @State private var nearbyGames: [NearbyGame] = []
    @State private var nearbyPlaces: [Venue] = []
    @State private var nearestStadium: (Venue, CLLocationDistance)?
    @State private var manual = false
    @State private var nearbyVenue: Venue?
    @State private var searchedNearby = false
    @State private var chosen: FoundGame?

    private var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uitest") }

    var body: some View {
        Group {
            if started { board } else { setup }
        }
        .onAppear {
            prefill()
            if isUITest { manual = true } else {
                location.start()
                // No fix (indoors, or location is slow): stop spinning and say so.
                Task {
                    try? await Task.sleep(for: .seconds(12))
                    if !searchedNearby && location.location == nil && !location.denied {
                        searchedNearby = true
                        Analytics.shared.track(.checkinStarted, ["result": "no_location"])
                    }
                }
            }
        }
        .onDisappear { location.stop() }
        .onChange(of: location.location) { _, newValue in
            guard !suggested, let loc = newValue else { return }
            suggested = true
            Task { await findNearby(around: loc) }
        }
    }

    // MARK: Setup

    private var setup: some View {
        NavigationStack {
            Group {
                if manual { manualForm } else { nearbyView }
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle(manual ? "Log manually" : "Check in")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: sport) { _, _ in defaultTeams() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("live-close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        startedAt = .now
                        started = true
                        Analytics.shared.track(.checkinStarted, ["result": chosen != nil ? "started_from_list" : "started_manual"])
                    } label: { Image(systemName: "checkmark") }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canStart || (!manual && chosen == nil))
                    .accessibilityLabel("Start")
                    .accessibilityIdentifier("live-start")
                }
            }
        }
    }

    /// Pick the venue and the teams by hand.
    private var manualForm: some View {
        Form {
            if !isUITest {
                Section {
                    Button { manual = false } label: { Label("Find games near me", systemImage: "location") }
                        .accessibilityIdentifier("live-find-nearby")
                }
                .listRowBackground(Color.panel)
            }
            Section {
                Picker("Venue", selection: venueBinding) {
                    if venueId.isEmpty { Text("Choose a venue").tag("") }
                    ForEach(library.venues(for: nil)) { v in
                        Text(v.name).tag(v.id)
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityIdentifier("live-venue")

                Picker("Sport", selection: $sport) {
                    ForEach(Sport.allCases.filter { $0 != .motorsport }) { s in
                        Label(s.name, systemImage: s.symbol).tag(s)
                    }
                }
            }
            Section {
                teamPicker("Home", selection: $homeId).accessibilityIdentifier("live-home")
                teamPicker("Away", selection: $awayId).accessibilityIdentifier("live-away")
            }
            Section {
                TextField("Seat", text: $seat)
                    .textInputAutocapitalization(.words)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Games near you

    /// A game on the schedule at a stadium close to you.
    struct NearbyGame: Identifiable {
        let game: FoundGame
        let venue: Venue
        let meters: CLLocationDistance
        var id: String { game.id }
    }

    /// Looks at where you are, finds the stadiums around you and lists the games on their schedules today.
    private var nearbyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if location.denied && location.location == nil {
                    state("location.slash", "Location is off",
                          "Allow location and Witness will find the stadiums around you and the games on today.") {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("live-open-settings")
                    }
                } else if !searchedNearby {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Finding stadiums near you\u{2026}").font(.subheadline).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                    .accessibilityIdentifier("live-locating")
                } else if nearbyGames.isEmpty {
                    state("calendar.badge.exclamationmark", "Sorry, no game found",
                          emptyDetail, content: { EmptyView() })
                        .accessibilityIdentifier("live-nearby-none")
                } else {
                    Text("Games near you").unitLabel()
                    ForEach(nearbyGames) { item in gameCard(item) }
                    if chosen != nil { chosenDetails }
                }
                Button { manual = true } label: {
                    Label("Not here, or not listed? Log manually", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(nearbyGames.isEmpty && searchedNearby ? Color.black : Color.signal)
                        .background(nearbyGames.isEmpty && searchedNearby ? Color.white : Color.clear, in: .rect(cornerRadius: 14))
                }
                .padding(.top, 6)
                .accessibilityIdentifier("live-log-manually")
            }
            .gutter()
            .padding(.top, 8)
        }
    }

    /// Seat for the chosen game: the label on the left, the answer on the right, like the rows of the manual form.
    private var chosenDetails: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Seat").font(.body)
                TextField("Section, row", text: $seat)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
            }
            .frame(minHeight: 50)
        }
        .padding(.horizontal, 16)
        .foregroundStyle(.white)
        .background(Color.panel, in: .rect(cornerRadius: 16))
    }

    private func state<Content: View>(_ symbol: String, _ title: String, _ detail: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(Color.signal)
            Text(title).font(.condensed(.title2, weight: .heavy)).textCase(.uppercase)
            Text(detail).font(.subheadline).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
            content()
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    /// Why nothing is listed: no location, no stadium close by (with how far the closest one is), or no game on today.
    private var emptyDetail: String {
        if location.location == nil { return "We couldn\u{2019}t get your location. Check that Location is on for Witness." }
        if nearbyPlaces.isEmpty {
            guard let near = nearestStadium else { return "We couldn\u{2019}t find a stadium near you." }
            return "No stadium within \(Fmt.metric ? "8 km" : "5 miles") of you. The closest is \(near.0.name), \(Fmt.distance(meters: near.1)) away."
        }
        return "No games on the schedule at \(nearbyVenueNames) right now."
    }

    private var nearbyVenueNames: String {
        let names = nearbyPlaces.prefix(2).map(\.name)
        return names.joined(separator: " or ")
    }

    private func gameCard(_ item: NearbyGame) -> some View {
        let game = item.game
        let selected = chosen?.id == game.id
        return Button { nearbyVenue = item.venue; select(game) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TeamTile(team: GameLookup.team(from: game.away, game: game), compact: true)
                        Text(game.away.location).lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        TeamTile(team: GameLookup.team(from: game.home, game: game), compact: true)
                        Text(game.home.location).lineLimit(1)
                    }
                }
                .font(.condensed(.headline, weight: .bold))
                .textCase(.uppercase)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(LiveGames.status(game, now: .now)).unitLabel()
                    Text("\(item.venue.name) \u{00B7} \(Self.distance(item.meters))")
                        .font(.caption).foregroundStyle(Color.textSecondary).lineLimit(1)
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.signal) }
                }
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.signal : .clear, lineWidth: 1.5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("live-game-\(game.eventId)")
    }

    private static func distance(_ meters: CLLocationDistance) -> String {
        meters < 160 ? "here" : (meters < 1000 ? "\(Int((meters / 10).rounded()) * 10) m" : String(format: "%.1f km", meters / 1000))
    }

    /// How far from you a stadium can be and still be listed: about 5 miles, enough for a parking lot or a tailgate.
    private static let searchRadius: CLLocationDistance = 8_000

    private func findNearby(around loc: CLLocation) async {
        nearestStadium = library.venues.map { ($0, $0.location.distance(from: loc)) }.min { $0.1 < $1.1 }
        let places = library.venues.map { ($0, $0.location.distance(from: loc)) }
            .filter { $0.1 <= Self.searchRadius }.sorted { $0.1 < $1.1 }.prefix(6)
        nearbyPlaces = places.map(\.0)
        let now = Date.now
        var found: [NearbyGame] = []
        var seen = Set<String>()
        for (venue, meters) in places {
            // In progress (started up to five hours ago) or starting later today.
            for game in await GameLookup.games(at: venue, from: now, to: now.addingTimeInterval(12 * 3600)) where seen.insert(game.id).inserted {
                found.append(NearbyGame(game: game, venue: venue, meters: meters))
            }
        }
        let order = LiveGames.ordered(found.map(\.game), now: now).map(\.id)
        nearbyGames = found.sorted { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
        searchedNearby = true
        Analytics.shared.track(.checkinStarted, ["result": nearbyGames.isEmpty ? (nearbyPlaces.isEmpty ? "no_stadium" : "no_games") : "found_games", "games": nearbyGames.count])
        // One game on and not over: that's the one.
        let open = nearbyGames.filter { !$0.game.completed }
        if open.count == 1, let only = open.first { nearbyVenue = only.venue; select(only.game) }
    }

    private func select(_ game: FoundGame) {
        chosen = game
        sport = game.sport
        if let v = GameLookup.venue(of: game, in: library.venues) ?? nearbyVenue { venueId = v.id }
        homeId = library.addTeam(GameLookup.team(from: game.home, game: game)).id
        awayId = library.addTeam(GameLookup.team(from: game.away, game: game)).id
    }

    private func teamPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag("")
            ForEach(library.teams(for: sport)) { t in
                Text("\(t.abbreviation)  \(t.locationName)").tag(t.id)
            }
        }
        .pickerStyle(.navigationLink)
    }

    private var canStart: Bool {
        !venueId.isEmpty && !homeId.isEmpty && !awayId.isEmpty && homeId != awayId
    }

    private var venueBinding: Binding<String> {
        Binding(get: { venueId }, set: { chosen = nil; selectVenue($0) })
    }

    // MARK: Board

    private var board: some View {
        let home = library.team(homeId)
        let away = library.team(awayId)
        return ZStack {
            Color.ink.ignoresSafeArea()
            RadialGradient(colors: [(home?.accent ?? Color(hex: "2F6BFF")).opacity(0.38), .clear],
                           center: UnitPoint(x: 0.5, y: 0.32), startRadius: 10, endRadius: 420)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                ZStack {
                    HStack {
                        CircleButton(systemName: "xmark", label: "Close") { dismiss() }
                            .accessibilityIdentifier("live-close")
                        Spacer()
                    }
                    Label("Live", systemImage: "circle.fill")
                        .labelStyle(LivePillStyle())
                }
                .padding(.horizontal, Spacing.gutter - 4)

                Spacer(minLength: 16)

                HStack(alignment: .top, spacing: 0) {
                    scoreColumn(team: home, score: $homeScore, dimmed: homeScore < awayScore, id: "home")
                    centerColumn
                    scoreColumn(team: away, score: $awayScore, dimmed: awayScore < homeScore, id: "away")
                }
                .gutter()

                Spacer(minLength: 16)

                if let pill = pillText {
                    HStack(spacing: 10) {
                        Text(pill)
                            .font(.condensed(.subheadline, weight: .heavy))
                            .textCase(.uppercase)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(Color.panelRaised.opacity(0.8), in: .capsule)
                    .gutter()
                    .accessibilityElement(children: .combine)
                }

                Spacer(minLength: 16)

                card(home: home, away: away)
                    .gutter()

                Spacer(minLength: 16)

                VStack(spacing: 4) {
                    Button {
                        moments.append(.now)
                    } label: {
                        Label("Save this moment", systemImage: "camera")
                            .frame(minHeight: 68)
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("live-save-moment")
                    .sensoryFeedback(.impact, trigger: moments.count)

                    HStack {
                        Text(moments.count == 1 ? "1 moment" : "\(moments.count) moments")
                            .font(.condensed(.subheadline, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                            .accessibilityIdentifier("live-moment-count")
                        Spacer()
                        Button("End & save game") { finish() }
                            .font(.condensed(.headline, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("live-end")
                    }
                }
                .gutter()
                .padding(.bottom, 8)
            }
        }
    }

    private func scoreColumn(team: Team?, score: Binding<Int>, dimmed: Bool, id: String) -> some View {
        VStack(spacing: 10) {
            TeamTile(team: team)
            Text("\(score.wrappedValue)")
                .displayFont(150)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(dimmed ? Color(hex: "6B7690") : .white)
                .contentTransition(.numericText())
                .accessibilityIdentifier("live-score-\(id)")
                .accessibilityLabel("\(team?.locationName ?? id) score")
                .accessibilityValue("\(score.wrappedValue)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: score.wrappedValue += 1
                    case .decrement: score.wrappedValue = max(0, score.wrappedValue - 1)
                    @unknown default: break
                    }
                }
            HStack(spacing: 4) {
                stepButton("minus", label: "\(team?.abbreviation ?? id) minus one") {
                    score.wrappedValue = max(0, score.wrappedValue - 1)
                }
                stepButton("plus", label: "\(team?.abbreviation ?? id) plus one") {
                    score.wrappedValue += 1
                }
                .accessibilityIdentifier("live-\(id)-plus")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var centerColumn: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 40)
            HStack(spacing: 2) {
                stepButton("chevron.left", label: "Previous period") { period = max(0, period - 1) }
                Text(shortPeriod)
                    .displayFont(34, relativeTo: .title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(minWidth: 54)
                stepButton("chevron.right", label: "Next period") { period += 1; outs = 0; bases = [false, false, false] }
            }
            if sport == .baseball {
                diamond
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                            .background(Circle().fill(i < outs ? Color.white : .clear))
                            .frame(width: 13, height: 13)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .onTapGesture { outs = (outs + 1) % 3 }
                .accessibilityElement()
                .accessibilityLabel("\(outs) out")
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(width: 146)
    }

    private var diamond: some View {
        ZStack {
            base(1).offset(x: 0, y: -11)
            base(2).offset(x: -44, y: 11)
            base(0).offset(x: 44, y: 11)
        }
        .frame(width: 132, height: 66)
    }

    private func base(_ i: Int) -> some View {
        Button {
            bases[i].toggle()
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(.white.opacity(0.85), lineWidth: 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(bases[i] ? Color.white : .clear))
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(45))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(["First", "Second", "Third"][i] + (bases[i] ? " base, runner" : " base, empty"))
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func card(home: Team?, away: Team?) -> some View {
        HStack(spacing: 10) {
            TeamTile(team: home, compact: true)
            Text("\(homeScore) – \(awayScore)")
                .displayFont(30, relativeTo: .title2)
            TeamTile(team: away, compact: true)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(longPeriod).font(.subheadline.weight(.semibold))
                if !seat.isEmpty {
                    Text(seat).font(.subheadline).foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 76)
        .background(Color.panel.opacity(0.9), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.hairline))
        .accessibilityElement(children: .combine)
    }

    // MARK: Text

    private var shortPeriod: String {
        switch sport {
        case .baseball: return ordinal(period / 2 + 1).uppercased()
        default:
            let labels = sport.periodLabels
            if period < labels.count { return sport == .soccer ? labels[period] : (sport == .hockey ? "P" : "Q") + labels[period] }
            return "OT"
        }
    }

    private var longPeriod: String {
        guard sport == .baseball else { return shortPeriod }
        let half = period % 2 == 0 ? "Top" : "Bot"
        return "\(half) \(ordinal(period / 2 + 1)) · \(outs) out"
    }

    private var pillText: String? {
        guard let venue = library.venue(venueId) else { return nil }
        let visit = library.games(at: venueId).count + 1
        return "\(ordinal(visit)) \(shortName(venue)) visit"
    }

    private func shortName(_ v: Venue) -> String {
        let words = v.name.split(separator: " ")
        let generic: Set<String> = ["Field", "Stadium", "Park", "Center", "Centre", "Arena", "Ballpark"]
        if words.count > 1, let last = words.last, generic.contains(String(last)) {
            return words.dropLast().joined(separator: " ")
        }
        return v.name
    }

    private func ordinal(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: Actions

    private func prefill() {
        guard venueId.isEmpty else { return }
        // A real check-in waits for your location; the tests start on a known ballpark.
        if isUITest {
            selectVenue(library.venue("wrigley")?.id ?? library.venues.first?.id ?? "")
        }
    }

    private func selectVenue(_ id: String) {
        venueId = id
        if let v = library.venue(id), let s = v.sports.first, s != .motorsport {
            sport = s
        }
        defaultTeams()
    }

    private func defaultTeams() {
        let teams = library.teams(for: sport)
        var home = teams.first { $0.id == homeId }
        if home == nil, let park = library.ballparks.first(where: { $0.venueId == venueId }), sport == .baseball {
            home = teams.first { $0.abbreviation == park.code }
        }
        if home == nil {
            let favorites = Set(library.profile.favoriteTeamIds)
            home = teams.first { favorites.contains($0.id) } ?? teams.first
        }
        homeId = home?.id ?? ""
        if teams.first(where: { $0.id == awayId }) == nil || awayId == homeId {
            awayId = teams.first { $0.id != homeId }?.id ?? ""
        }
    }

    private func finish() {
        var entry = GameEntry(sport: sport, date: startedAt, venueId: venueId, origin: .live)
        entry.homeTeamId = homeId.isEmpty ? nil : homeId
        entry.awayTeamId = awayId.isEmpty ? nil : awayId
        entry.homeScore = homeScore
        entry.awayScore = awayScore
        entry.seat = seat.isEmpty ? nil : seat
        entry.savedMoments = moments
        if let game = chosen {
            // The schedule fills in the competition, big-game stage and source; your own live score stands unless the game is over.
            entry.date = game.start
            GameLookup.apply(game, detail: nil, to: &entry, library: library)
            if !game.completed {
                entry.homeScore = homeScore
                entry.awayScore = awayScore
            }
            let id = entry.id
            Task {
                guard let detail = await GameLookup.detail(game), var saved = library.game(id) else { return }
                GameLookup.apply(game, detail: detail, to: &saved, library: library)
                if !game.completed {
                    saved.homeScore = entry.homeScore
                    saved.awayScore = entry.awayScore
                }
                library.update(saved)
            }
        }
        library.add(entry)
        dismiss()
    }
}

private struct LivePillStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
        .font(.condensed(.subheadline, weight: .heavy))
        .textCase(.uppercase)
        .tracking(1.4)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(minHeight: 30)
        .background(Color.live, in: .rect(cornerRadius: 7))
    }
}


/// Orders and labels the games found at your stadium for the check-in picker.
enum LiveGames {
    /// In progress first, then what starts next, then games already over.
    static func ordered(_ games: [FoundGame], now: Date) -> [FoundGame] {
        func rank(_ g: FoundGame) -> Int { g.completed ? 2 : (g.start <= now ? 0 : 1) }
        return games.sorted { a, b in
            rank(a) != rank(b) ? rank(a) < rank(b) : (rank(a) == 2 ? a.start > b.start : a.start < b.start)
        }
    }

    static func status(_ game: FoundGame, now: Date) -> String {
        if game.completed { return "Final" }
        if game.start <= now { return "Live" }
        return "Starts " + game.start.formatted(date: .omitted, time: .shortened)
    }
}
