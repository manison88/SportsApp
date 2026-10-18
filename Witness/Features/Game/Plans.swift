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

/// Pick a team, see its coming games, plan one.
struct PlanGameView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var teamId: String?
    @State private var games: [FoundGame] = []
    @State private var loading = false
    @State private var empty = false
    @State private var noSource = false
    @State private var teamEspnId: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NavigationLink {
                        TeamPickerView(selection: $teamId, sport: .baseball)
                    } label: {
                        HStack(spacing: 12) {
                            if let team = library.team(teamId) {
                                TeamTile(team: team)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(team.locationName).font(.condensed(.title3, weight: .heavy)).textCase(.uppercase)
                                    Text(team.league).font(.footnote).foregroundStyle(Color.textSecondary)
                                }
                            } else {
                                Image(systemName: "magnifyingglass").foregroundStyle(Color.textSecondary)
                                Text("Choose a team").foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary)
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color.panel, in: .rect(cornerRadius: 16))
                    }
                    .accessibilityIdentifier("plan-team")

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
                }
                .gutter()
                .padding(.top, 8)
            }
            .inkBackground()
            .navigationTitle("Plan a game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("plan-close")
                }
            }
            .onChange(of: teamId) { _, _ in Task { await load() } }
        }
    }

    private func load() async {
        games = []
        empty = false
        noSource = false
        guard let team = library.team(teamId) else { return }
        loading = true
        defer { loading = false }
        guard let source = await TeamDirectory.shared.resolve(team) else { noSource = true; return }
        teamEspnId = source.id
        games = await GameLookup.upcoming(league: source.league, teamEspnId: source.id)
        empty = games.isEmpty
    }

    private func isPlanned(_ game: FoundGame) -> Bool {
        library.plans.contains { $0.source?.eventId == game.eventId && $0.source?.league == game.league }
    }

    private func row(_ game: FoundGame) -> some View {
        let isHome = game.home.espnId == teamEspnId
        let other = isHome ? game.away : game.home
        let tz = GameLookup.venue(of: game, in: library.venues)?.tz ?? .current
        let planned = isPlanned(game)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.day, .month, .weekday], from: game.start)
        let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        return Button {
            if !planned { library.addPlan(game) }
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
                    Text("\(Fmt.time(game.start, in: tz)) \u{00B7} \(game.venueName)").font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(planned ? "Planned" : "Plan it")
                    .font(.condensed(.caption, weight: .heavy)).textCase(.uppercase).tracking(1)
                    .foregroundStyle(planned ? Color.black : Color.textSecondary)
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(planned ? Color.signal : Color.panelRaised, in: .capsule)
            }
            .foregroundStyle(.white)
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
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var forecast: Weather?
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
                    .foregroundStyle(.white)
                    .gutter().padding(.bottom, 12).padding(.top, 90)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    infoRow("sun.max", "Forecast", forecast.map { "\($0.condition) \u{00B7} \(Int($0.temperatureF.rounded()))\u{00B0}F" } ?? "Shows up within about two weeks of the game")
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
                        .foregroundStyle(.white)
                        .padding(14).background(Color.panel, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(calendarState == .added)
                    .accessibilityIdentifier("plan-calendar")
                    Toggle(isOn: Binding(get: { plan.planAutoPhotos ?? true }, set: { value in
                        guard var p = library.plan(plan.id) else { return }
                        p.planAutoPhotos = value
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
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
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
                    Image(systemName: "ellipsis").font(.body.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 36, height: 36).background(.ultraThinMaterial, in: .circle)
                        .frame(width: 44, height: 44).contentShape(.circle)
                }
                .accessibilityLabel("More")
                .accessibilityIdentifier("plan-menu")
            }
        }
        .task(id: plan.id) {
            seat = plan.seat ?? ""
            if let venue { forecast = await WeatherLookup.at(venue: venue, date: plan.date) }
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
            LinearGradient(colors: [(home?.primary ?? Color.panelRaised).opacity(0.9), Color.panel], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 8) {
                Text(PlanText.countdown(days)).font(.condensed(.caption, weight: .heavy)).textCase(.uppercase).tracking(1.2)
                    .foregroundStyle(Color.black).padding(.horizontal, 10).frame(height: 24).background(Color.signal, in: .capsule)
                Text(PlanText.title(plan, library).uppercased()).font(.condensed(.title, weight: .heavy)).lineLimit(2).minimumScaleFactor(0.7)
                Text("\(venue?.name ?? "") \u{00B7} \(Fmt.dayTitle(plan.date, in: tz(plan))) \u{00B7} \(Fmt.time(plan.date, in: tz(plan)))")
                    .font(.footnote).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
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
        .foregroundStyle(.white)
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
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
                    Text("Not today").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5))
                }
                .accessibilityIdentifier("plan-day-no")
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(Color.panel, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.12)))
    }
}
