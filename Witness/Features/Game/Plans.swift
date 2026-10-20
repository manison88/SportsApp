import SwiftUI
import UserNotifications
import EventKit

// MARK: - Helpers

@MainActor
enum PlanText {
    /// "Yankees at Red Sox".
    static func title(_ plan: GameEntry, _ library: Library) -> String {
        let home = library.team(plan.homeTeamId)?.locationName ?? "Home"
        guard let away = library.team(plan.awayTeamId)?.locationName else { return home }
        return "\(away) at \(home)"
    }

    /// Whole days from today to the game, counted on the venue's calendar.
    static func daysAway(_ plan: GameEntry, tz: TimeZone, now: Date = .now) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: plan.date)).day ?? 0
    }

    static func countdown(_ days: Int) -> String {
        switch days {
        case ..<0: "Past"
        case 0: "Today"
        case 1: "Tomorrow"
        default: "In \(days) days"
        }
    }

    /// Planned games that haven't passed, soonest first.
    static func coming(_ library: Library) -> [GameEntry] {
        library.plans.filter { $0.date > Date().addingTimeInterval(-6 * 3600) }
    }
}

// MARK: - Plan a game

/// Pick a team, see its coming games, plan one. One forward flow: every league, one league's teams, the team's schedule.
struct PlanGameView: View {
    enum Step: Hashable { case league(String), team(String) }
    @Environment(\.dismiss) private var dismiss
    @Environment(Library.self) private var library
    @State private var picked: String?
    @State private var path: [Step] = []

    var body: some View {
        NavigationStack(path: $path) {
            TeamPickerView(selection: $picked, sport: .baseball, title: "Plan a game",
                           onPick: { path.append(.team($0)) }, onLeague: { path.append(.league($0)) })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Close")
                            .accessibilityIdentifier("plan-close")
                    }
                }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .league(let name):
                        LeagueTeamsView(league: name, teams: library.allTeams.filter { $0.league == name }, selection: $picked, popsSelf: false) {
                            if let picked { path.append(.team(picked)) }
                        }
                    case .team(let id):
                        PlanScheduleView(teamId: id) { dismiss() }
                    }
                }
        }
    }
}

/// One team's coming games. Tapping one plans it and opens the plan.
struct PlanScheduleView: View {
    let teamId: String
    /// Closes the whole Plan a game sheet.
    let close: () -> Void
    @Environment(Library.self) private var library
    @State private var games: [FoundGame] = []
    @State private var loading = true
    @State private var empty = false
    @State private var noSource = false
    @State private var teamEspnId: String?
    @State private var addingByHand = false
    /// The plan just made (or already made) from a row, opened on top of the list.
    @State private var openPlanId: String?
    /// Plans made by "Plan it" and not yet confirmed with "Plan": backing out removes them.
    @State private var tentative: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let team = library.team(teamId) {
                    HStack(spacing: 12) {
                        TeamTile(team: team)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(team.locationName).font(.condensed(.title3, weight: .heavy)).textCase(.uppercase)
                            Text(team.league).font(.footnote).foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                    }
                    .foregroundStyle(Color.primaryText)
                    .padding(14)
                    .background(Color.panel, in: .rect(cornerRadius: 16))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("plan-team")
                }

                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
                } else if !games.isEmpty {
                    Text("Upcoming games").unitLabel()
                    ForEach(games) { game in row(game) }
                } else if noSource {
                    Text("We can\u{2019}t look up this team\u{2019}s schedule yet. Add the game from Add game instead.")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                } else if empty {
                    Text("No upcoming games on this team\u{2019}s schedule right now. In the off-season the schedule comes out later.")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                }

                if !loading {
                    Button { addingByHand = true } label: {
                        Label(games.isEmpty ? "Add the game yourself" : "Not listed? Add it yourself", systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(games.isEmpty ? Color.onPrimary : Color.signal)
                            .background(games.isEmpty ? Color.primaryText : Color.clear, in: .rect(cornerRadius: 14))
                    }
                    .accessibilityIdentifier("plan-add-by-hand")
                }
            }
            .gutter()
            .padding(.top, 8)
        }
        .inkBackground()
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: teamId) { await load() }
        .sheet(isPresented: $addingByHand) {
            AddGameView(planning: true, presetTeamId: teamId, onPlanned: { _ in close() }, onDone: { addingByHand = false })
        }
        .navigationDestination(item: $openPlanId) { id in
            PlanView(planId: id, onConfirm: tentative.contains(id) ? { tentative.remove(id); close() } : nil)
        }
        .onChange(of: openPlanId) { old, new in
            guard new == nil, let old, tentative.remove(old) != nil else { return }
            library.removePlan(old)
        }
    }

    private func load() async {
        games = []
        empty = false
        noSource = false
        guard let team = library.team(teamId) else { loading = false; return }
        loading = true
        defer { loading = false }
        guard let source = await TeamDirectory.shared.resolve(team) else {
            noSource = true
            library.recordScheduleSearch(team, found: 0, noSource: true)
            return
        }
        teamEspnId = source.id
        if team.sport == .soccer, team.id.hasPrefix("nat-") || team.league.lowercased().contains("national") {
            // A country plays in many competitions: World Cup and its qualifying, Euros, Nations League, friendlies.
            // ESPN's lists are late for some, so UEFA's own feed adds the Nations League with later dates.
            async let espn = GameLookup.upcomingNational(espnId: source.id)
            async let uefa = UEFASchedule.upcoming(for: team)
            games = Self.merged(await espn, await uefa)
        } else {
            games = await GameLookup.upcoming(league: source.league, teamEspnId: source.id)
        }
        empty = games.isEmpty
        library.recordScheduleSearch(team, found: games.count)
    }

    /// One list, soonest first. The same match from both feeds (same day, same two sides) is kept once, UEFA's version.
    static func merged(_ espn: [FoundGame], _ uefa: [FoundGame]) -> [FoundGame] {
        func key(_ g: FoundGame) -> String {
            let day = Calendar(identifier: .gregorian).dateComponents(in: .gmt, from: g.start)
            return "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)|" + [g.home.abbreviation, g.away.abbreviation].sorted().joined(separator: "-")
        }
        let uefaKeys = Set(uefa.map(key))
        return (uefa + espn.filter { !uefaKeys.contains(key($0)) }).sorted { $0.start < $1.start }
    }

    /// ESPN sometimes leaves the league's name out and only the path is left ("basketball/nba"): show "NBA".
    static func leagueLabel(_ game: FoundGame) -> String {
        guard game.leagueName.contains("/") else { return game.leagueName }
        let code = game.leagueName.split(separator: "/").last.map(String.init) ?? game.leagueName
        return code.replacingOccurrences(of: ".", with: " ").uppercased()
    }

    private func isPlanned(_ game: FoundGame) -> Bool {
        library.plans.contains { $0.source?.eventId == game.eventId && $0.source?.league == game.league }
    }

    private func row(_ game: FoundGame) -> some View {
        let mine = library.team(teamId)?.abbreviation
        let isHome = game.home.espnId == teamEspnId || (mine != nil && game.home.abbreviation == mine)
        let other = isHome ? game.away : game.home
        let tz = GameLookup.venue(of: game, in: library.venues)?.tz ?? .current
        let planned = isPlanned(game)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.day, .month, .weekday], from: game.start)
        let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        return Button {
            let wasPlanned = isPlanned(game)
            guard let entry = library.addPlan(game) else { return }
            if !wasPlanned { tentative.insert(entry.id) }
            // Ask for the forecast now, so the plan page has it by the time it opens.
            if let venue = library.venue(entry.venueId) { Task { _ = await WeatherLookup.forecast(venue: venue, date: entry.date) } }
            openPlanId = entry.id
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(weekdays[((c.weekday ?? 1) - 1) % 7]).font(.condensed(.caption2, weight: .heavy)).tracking(1.5).foregroundStyle(Color.textSecondary)
                    Text("\(c.day ?? 1)").font(.condensed(.title2, weight: .heavy)).monospacedDigit()
                    Text(months[((c.month ?? 1) - 1) % 12]).font(.condensed(.caption2, weight: .heavy)).tracking(1.5).foregroundStyle(Color.textSecondary)
                }
                .frame(width: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(isHome ? "vs" : "at") \(other.location)").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).lineLimit(1)
                    Text("\(Self.leagueLabel(game)) \u{00B7} \(Fmt.time(game.start, in: tz)) \u{00B7} \(game.venueName)").font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(planned ? "Planned" : "Plan it")
                    .font(.condensed(.caption, weight: .heavy)).textCase(.uppercase).tracking(1)
                    .foregroundStyle(planned ? Color.black : Color.textSecondary)
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(planned ? Color.signal : Color.panelRaised, in: .capsule)
            }
            .foregroundStyle(Color.primaryText)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.panel, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan-game-\(game.eventId)")
    }
}

// MARK: - A planned game

struct PlanView: View {
    let planId: String
    /// Set when the plan was just picked from a schedule: the page asks to confirm with "Plan" instead of offering check-in.
    var onConfirm: (() -> Void)? = nil
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var forecast: Weather?
    @State private var forecastChecked = false
    @State private var seat = ""
    @State private var reminderDenied = false
    @State private var calendarState: CalendarState = .idle

    private enum CalendarState { case idle, added, denied }

    var body: some View {
        if let plan = library.plan(planId) {
            content(plan)
        } else {
            ContentUnavailableView("Plan not found", systemImage: "calendar").inkBackground()
        }
    }

    private func content(_ plan: GameEntry) -> some View {
        let venue = library.venue(plan.venueId)
        let tz = venue?.tz ?? .current
        let days = PlanText.daysAway(plan, tz: tz)
        let home = library.team(plan.homeTeamId)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [(home?.primary ?? Color.panelRaised).opacity(0.85), Color.ink], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Planned").font(.condensed(.caption, weight: .heavy)).textCase(.uppercase).tracking(1.4)
                            .foregroundStyle(Color.black).padding(.horizontal, 10).frame(height: 24)
                            .background(Color.signal, in: .capsule)
                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            Text(days > 0 ? "\(days)" : (days == 0 ? "Today" : "\u{2014}"))
                                .displayFont(days > 0 ? 96 : 64)
                                .accessibilityIdentifier("plan-countdown")
                            if days > 0 { Text(days == 1 ? "Day\nto go" : "Days\nto go").displayFont(22, relativeTo: .title2).textCase(.uppercase) }
                        }
                        Text(PlanText.title(plan, library).uppercased()).displayFont(30, relativeTo: .title).lineLimit(2).minimumScaleFactor(0.7)
                        Text("\(venue?.name ?? "") \u{00B7} \(Fmt.dayTitle(plan.date, in: tz)) \u{00B7} \(Fmt.time(plan.date, in: tz))")
                            .font(.subheadline).foregroundStyle(Color.textSecondary)
                    }
                    .foregroundStyle(Color.primaryText)
                    .gutter().padding(.bottom, 12).padding(.top, 90)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    infoRow("sun.max", "Forecast", forecast.map { "\($0.condition) \u{00B7} \(Fmt.temperature($0.temperatureF))" } ?? forecastNote(plan))
                    HStack(spacing: 12) {
                        Image(systemName: "ticket").foregroundStyle(Color.signal).frame(width: 24)
                        TextField("Section, row, seat", text: $seat)
                            .onSubmit { save(plan) }
                            .accessibilityIdentifier("plan-seat")
                    }
                    .padding(14).background(Color.panel, in: .rect(cornerRadius: 16))
                    Button { Task { await addToCalendar(plan) } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: calendarState == .added ? "checkmark.circle.fill" : "calendar.badge.plus")
                                .foregroundStyle(Color.signal).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add to Calendar").font(.subheadline.weight(.semibold))
                                Text(calendarState == .added ? "Added to your calendar"
                                     : calendarState == .denied ? "Allow calendar access in Settings"
                                     : "Saves it to your calendar")
                                    .font(.footnote).foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                        }
                        .foregroundStyle(Color.primaryText)
                        .padding(14).background(Color.panel, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(calendarState == .added)
                    .accessibilityIdentifier("plan-calendar")
                    Toggle(isOn: Binding(get: { plan.planAutoPhotos ?? true }, set: { value in
                        guard var p = library.plan(plan.id) else { return }
                        p.planAutoPhotos = value
                        Analytics.shared.track(.settingChanged, ["setting": "plan_auto_photos", "value": value ? "on" : "off"])
                        library.updatePlan(p)
                    })) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled").foregroundStyle(Color.signal).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add my photos automatically").font(.subheadline.weight(.semibold))
                                Text("Photos from the stadium around game time")
                                    .font(.footnote).foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                    .tint(Color.signal)
                    .padding(14).background(Color.panel, in: .rect(cornerRadius: 16))
                    .accessibilityIdentifier("plan-auto-photos")
                    Toggle(isOn: Binding(get: { plan.planReminder ?? false }, set: { setReminder($0, plan) })) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell").foregroundStyle(Color.signal).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Game-day reminder").font(.subheadline.weight(.semibold))
                                Text(reminderDenied ? "Turn on notifications in Settings" : "Noon on game day")
                                    .font(.footnote).foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                    .tint(Color.signal)
                    .padding(14).background(Color.panel, in: .rect(cornerRadius: 16))
                    .accessibilityIdentifier("plan-reminder")
                }
                .gutter()

                if let onConfirm {
                    Button {
                        save(plan)
                        onConfirm()
                    } label: {
                        Label("Plan", systemImage: "calendar.badge.checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle(fill: .signal, onFill: .black))
                    .gutter()
                    .accessibilityIdentifier("plan-confirm")
                } else {
                    Button {
                        save(plan)
                        library.attend(plan: plan.id)
                        cancelReminder(plan)
                        dismiss()
                    } label: {
                        Label("I\u{2019}m at the game", systemImage: "checkmark")
                    }
                    .buttonStyle(.primary)
                    .gutter()
                    .accessibilityIdentifier("plan-attend")
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .lightStatusBar()
        .inkBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        cancelReminder(plan)
                        library.removePlan(plan.id)
                        dismiss()
                    } label: { Label("Remove plan", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.body.weight(.bold)).foregroundStyle(Color.primaryText)
                        .frame(width: 36, height: 36).background(.ultraThinMaterial, in: .circle)
                        .frame(width: 44, height: 44).contentShape(.circle)
                }
                .accessibilityLabel("More")
                .accessibilityIdentifier("plan-menu")
            }
        }
        .task(id: plan.id) {
            seat = plan.seat ?? ""
            if let venue {
                forecast = WeatherLookup.cachedForecast(venue: venue, date: plan.date)
                if forecast == nil { forecast = await WeatherLookup.forecast(venue: venue, date: plan.date) }
            }
            forecastChecked = true
        }
        .onDisappear { save(plan) }
    }

    private func infoRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Color.signal).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(14).background(Color.panel, in: .rect(cornerRadius: 16))
    }

    /// What the forecast row says before there is a forecast.
    private func forecastNote(_ plan: GameEntry) -> String {
        guard WeatherLookup.inForecastRange(plan.date) else { return "Shows up about two weeks before the game" }
        return forecastChecked ? "No forecast yet. Check back closer to the game" : "Checking the forecast\u{2026}"
    }

    private func save(_ plan: GameEntry) {
        guard var p = library.plan(plan.id) else { return }
        let text = seat.trimmingCharacters(in: .whitespacesAndNewlines)
        p.seat = text.isEmpty ? nil : text
        if p != plan { library.updatePlan(p) }
    }

    // MARK: Calendar

    /// Writes the game into the fan's calendar. Write-only access: the app never reads their events.
    private func addToCalendar(_ plan: GameEntry) async {
        let store = EKEventStore()
        guard (try? await store.requestWriteOnlyAccessToEvents()) == true else { calendarState = .denied; return }
        let venue = library.venue(plan.venueId)
        let event = EKEvent(eventStore: store)
        event.title = PlanText.title(plan, library)
        event.startDate = plan.date
        event.endDate = plan.date.addingTimeInterval(3 * 3600)
        event.timeZone = venue?.tz
        event.location = [venue?.name, venue?.cityLine].compactMap { $0 }.joined(separator: ", ")
        event.notes = plan.seat.map { "Seat: \($0)" }
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            calendarState = .added
        } catch {
            calendarState = .denied
        }
    }

    // MARK: Reminder

    private func setReminder(_ on: Bool, _ plan: GameEntry) {
        guard var p = library.plan(plan.id) else { return }
        if !on {
            p.planReminder = false
            library.updatePlan(p)
            cancelReminder(plan)
            return
        }
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            reminderDenied = !granted
            guard granted else { return }
            let tz = library.venue(plan.venueId)?.tz ?? .current
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            var when = cal.date(bySettingHour: 12, minute: 0, second: 0, of: plan.date) ?? plan.date
            if when >= plan.date { when = plan.date.addingTimeInterval(-3600) }
            guard when > .now else { return }
            let content = UNMutableNotificationContent()
            content.title = "Game day"
            content.body = "\(PlanText.title(plan, library)) at \(library.venue(plan.venueId)?.name ?? "the stadium"). Open Witness when you get there."
            let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: when)
            let request = UNNotificationRequest(identifier: "plan-\(plan.id)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await UNUserNotificationCenter.current().add(request)
            p.planReminder = true
            library.updatePlan(p)
        }
    }

    private func cancelReminder(_ plan: GameEntry) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["plan-\(plan.id)"])
    }
}

// MARK: - On the Timeline

/// The next planned game as a banner, the others as dashed rows, and on game day a prompt to confirm.
struct UpcomingSection: View {
    @Environment(Library.self) private var library
    @State private var dismissed: Set<String> = []

    var body: some View {
        let plans = PlanText.coming(library)
        if !plans.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(plans.filter { isToday($0) && !dismissed.contains($0.id) }) { dayPrompt($0) }
                HStack {
                    Text("Upcoming \u{00B7} \(plans.count)").font(.condensed(.caption, weight: .heavy)).textCase(.uppercase)
                        .tracking(1.6).foregroundStyle(Color.signal)
                    Spacer()
                }
                .accessibilityIdentifier("upcoming-header")
                ForEach(Array(plans.enumerated()), id: \.element.id) { i, plan in
                    NavigationLink(value: Route.plan(plan.id)) {
                        i == 0 ? AnyView(banner(plan)) : AnyView(dashedRow(plan))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("plan-card-\(plan.id)")
                }
            }
        }
    }

    private func tz(_ plan: GameEntry) -> TimeZone { library.venue(plan.venueId)?.tz ?? .current }
    private func isToday(_ plan: GameEntry) -> Bool { PlanText.daysAway(plan, tz: tz(plan)) == 0 }

    private func banner(_ plan: GameEntry) -> some View {
        let home = library.team(plan.homeTeamId)
        let venue = library.venue(plan.venueId)
        let days = PlanText.daysAway(plan, tz: tz(plan))
        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: [(home?.primary ?? Color.panelRaised).opacity(0.9), Color.photoInk], startPoint: .topLeading, endPoint: .bottomTrailing)
            // A bright team color (Sweden's yellow) would wash out the white text, so the card is always a little darker at the edge.
            Color.photoInk.opacity(0.3)
            VStack(alignment: .leading, spacing: 8) {
                Text(PlanText.countdown(days)).font(.condensed(.caption, weight: .heavy)).textCase(.uppercase).tracking(1.2)
                    .foregroundStyle(Color.photoInk).padding(.horizontal, 10).frame(height: 24).background(Color(hex: "FFB547"), in: .capsule)
                Text(PlanText.title(plan, library).uppercased()).font(.condensed(.title, weight: .heavy)).lineLimit(2).minimumScaleFactor(0.7)
                Text("\(venue?.name ?? "") \u{00B7} \(Fmt.dayTitle(plan.date, in: tz(plan))) \u{00B7} \(Fmt.time(plan.date, in: tz(plan)))")
                    .font(.footnote).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .clipShape(.rect(cornerRadius: 18))
    }

    private func dashedRow(_ plan: GameEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(PlanText.title(plan, library).uppercased()).font(.condensed(.headline, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                Text("\(library.venue(plan.venueId)?.name ?? "") \u{00B7} \(Fmt.dayTitle(plan.date, in: tz(plan)))")
                    .font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary)
        }
        .foregroundStyle(Color.primaryText)
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primaryText.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
    }

    private func dayPrompt(_ plan: GameEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.black)
                    .frame(width: 36, height: 36).background(Color.signal, in: .rect(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("It\u{2019}s game day").font(.condensed(.caption, weight: .heavy)).textCase(.uppercase).tracking(1.2).foregroundStyle(Color.textSecondary)
                    Text("Are you at \(library.venue(plan.venueId)?.name ?? "the game")?").font(.subheadline.weight(.semibold))
                }
            }
            Text("\(PlanText.title(plan, library)), \(Fmt.time(plan.date, in: tz(plan))). We\u{2019}ll add the photos from this stadium around game time.")
                .font(.footnote).foregroundStyle(Color.textSecondary)
            HStack(spacing: 10) {
                Button { library.attend(plan: plan.id) } label: { Text("Yes, add my photos").frame(maxWidth: .infinity) }
                    .buttonStyle(.primary).accessibilityIdentifier("plan-day-yes")
                Button { dismissed.insert(plan.id) } label: {
                    Text("Not today").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primaryText.opacity(0.25), lineWidth: 1.5))
                }
                .accessibilityIdentifier("plan-day-no")
            }
        }
        .foregroundStyle(Color.primaryText)
        .padding(14)
        .background(Color.panel, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primaryText.opacity(0.12)))
    }
}
