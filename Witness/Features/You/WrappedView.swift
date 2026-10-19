import SwiftUI

/// 11 · A season as one story card.
struct WrappedView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    let year: Int

    var body: some View {
        let shownYear = resolvedYear
        ZStack(alignment: .top) {
            background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Wrapped \(String(shownYear))")
                        .font(.condensed(.title3, weight: .heavy))
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.18), in: .circle)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("wrapped-close")
                }
                .padding(.top, 8)

                WrappedCard(year: shownYear, compact: false)
                    .padding(.top, 8)

                Spacer(minLength: Spacing.inner)

                ShareCardSheetLink(kind: "wrapped", title: "Wrapped \(String(shownYear))", format: .story, key: String(shownYear), variants: { await shareVariants(shownYear) }) {
                    Label("Share to story", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("wrapped-share")
                .padding(.bottom, 8)
            }
            .gutter()
            .foregroundStyle(.white)
        }
    }

    private var background: Color {
        let team = library.profile.favoriteTeamIds.compactMap { library.team($0) }.first { $0.sport == .football }
        return (team?.accent ?? Color(hex: "F05A1A")).deepenedForWhiteText
    }

    /// The requested year, or the most recent year with games.
    private var resolvedYear: Int {
        let years = Set(library.games.map { Fmt.year($0.date) })
        if years.contains(year) { return year }
        return years.max() ?? year
    }

    @MainActor
    private func shareVariants(_ y: Int) async -> [ShareCardVariant] {
        let games = library.games.filter { Fmt.year($0.date) == y }
        guard !games.isEmpty else { return [] }
        let stats = Stats(library: library, games: games)
        let year = String(y)
        let tint = background
        let played = games.filter { !$0.isVisit }
        let ordered = games.sorted { $0.date < $1.date }
        var cityList: [String] = []
        for g in ordered {
            if let c = library.venue(g.venueId)?.city, !c.isEmpty, !cityList.contains(c) { cityList.append(c) }
        }
        let cities = cityList
        var out: [ShareCardVariant] = []

        // 1 Record
        if stats.record.decided > 0 {
            var loaded: UIImage?
            if let ref = WrappedCopy.bestPhoto(games, library) { loaded = await PhotoLoader.load(ref) }
            let photo = loaded
            let record = stats.record.text
            let claim = WrappedCopy.claim(stats, games: games.count, library: library)
            out.append(ShareCardVariant("Record") {
                RecordShareCard(year: year, record: record, claim: claim, photo: photo, tint: tint)
            })
        }

        // 2 Games
        var counts: [WrapStat] = []
        if games.count > 1 {
            if stats.venues > 0 {
                counts.append(WrapStat(value: "\(stats.venues)", label: stats.venues == 1 ? "Stadium" : "Stadiums"))
            }
            if cities.count > 0 {
                counts.append(WrapStat(value: "\(cities.count)", label: cities.count == 1 ? "City" : "Cities"))
            }
            if stats.countries > 0 {
                counts.append(WrapStat(value: "\(stats.countries)", label: stats.countries == 1 ? "Country" : "Countries"))
            }
        }
        let countRow = counts
        let gameCount = games.count
        out.append(ShareCardVariant("Games") {
            GamesShareCard(year: year, games: gameCount, stats: countRow, tint: tint)
        })

        // 3 Miles
        if stats.miles > 0 {
            let miles = Fmt.number(stats.miles)
            let farName = stats.farthestVenue?.name ?? ""
            let farCity = stats.farthestVenue?.cityLine ?? ""
            let route = Array(cities.prefix(6))
            let extra = max(0, cities.count - 6)
            out.append(ShareCardVariant("Miles") {
                MilesShareCard(year: year, miles: miles, farName: farName, farCity: farCity, route: route, extra: extra, tint: tint)
            })
        }

        // 4 Home Ground
        let byVenue = Dictionary(grouping: games, by: { $0.venueId })
        var topVenueId: String?
        var topVisits: [GameEntry] = []
        for (id, list) in byVenue {
            let newest = list.map { $0.date }.max() ?? Date.distantPast
            let bestNewest = topVisits.map { $0.date }.max() ?? Date.distantPast
            if list.count > topVisits.count || (list.count == topVisits.count && newest > bestNewest) {
                topVenueId = id
                topVisits = list
            }
        }
        if let vid = topVenueId, topVisits.count >= 2, let venue = library.venue(vid) {
            let sortedVisits = topVisits.sorted { $0.date < $1.date }
            if let first = sortedVisits.first, let last = sortedVisits.last {
                var loaded: UIImage?
                if let ref = sortedVisits.first(where: { $0.heroPhoto != nil })?.heroPhoto { loaded = await PhotoLoader.load(ref) }
                let photo = loaded
                let visits = sortedVisits.count
                let firstText = Fmt.short(first.date, in: venue.tz)
                let lastText = Fmt.short(last.date, in: venue.tz)
                let name = venue.name
                let city = venue.cityLine
                out.append(ShareCardVariant("Home Ground") {
                    HomeGroundShareCard(year: year, venue: name, city: city, visits: visits, first: firstText, last: lastText, photo: photo, tint: tint)
                })
            }
        }

        // 5 Big Game
        let candidates = played.filter { $0.bigGame != nil || ($0.homeScore != nil && $0.awayScore != nil) }
        if let big = WrapData.best(candidates, byMargin: true).first {
            let row = WrapData.row(big, library)
            var stage = row.stage
            if stage.isEmpty { stage = played.count > 1 ? "Closest game of the year" : "Your game of the year" }
            let isTitle = big.bigGame?.kind == .championship
            var loaded: UIImage?
            if let ref = big.heroPhoto { loaded = await PhotoLoader.load(ref) }
            let photo = loaded
            let stageText = stage
            out.append(ShareCardVariant("Big Game") {
                BigGameShareCard(year: year, row: row, stage: stageText, isTitle: isTitle, photo: photo, tint: tint)
            })
        }

        // 6 Coldest (or hottest, when the coldest game was still warm)
        var weatherGame: GameEntry?
        var isCold = true
        if let cold = stats.coldestGame, let t = cold.weather?.temperatureF {
            weatherGame = cold
            if t > 60, let hot = stats.hottestGame, (hot.weather?.temperatureF ?? 0) >= 80 {
                weatherGame = hot
                isCold = false
            }
        }
        if let wg = weatherGame, let w = wg.weather {
            let venue = library.venue(wg.venueId)
            let tz = venue?.tz ?? TimeZone.current
            let temp = "\(Int(w.temperatureF.rounded()))°F"
            let condition = w.condition
            let name = venue?.name ?? ""
            let city = venue?.cityLine ?? ""
            let dateText = Fmt.short(wg.date, in: tz)
            let timeText = Fmt.time(wg.date, in: tz)
            let cold = isCold
            out.append(ShareCardVariant("Coldest") {
                WeatherShareCard(year: year, isCold: cold, temp: temp, condition: condition, venue: name, city: city, dateText: dateText, timeText: timeText)
            })
        }

        // 7 Calendar
        var monthDots = Array(repeating: [Bool](), count: 12)
        let cal = Calendar.current
        for g in ordered {
            let m = cal.component(.month, from: g.date) - 1
            if m >= 0 && m < 12 { monthDots[m].append(library.outcome(g) == .win) }
        }
        let months = monthDots
        let busiest = months.map { $0.count }.max() ?? 1
        out.append(ShareCardVariant("Calendar") {
            CalendarShareCard(year: year, games: gameCount, months: months, busiest: busiest)
        })

        // 8 Top Five
        if played.count >= 3 {
            let rows = WrapData.best(played, byMargin: false).prefix(5).map { WrapData.row($0, library) }
            out.append(ShareCardVariant("Top Five") {
                TopFiveShareCard(year: year, rows: rows, tint: tint)
            })
        }
        return out
    }
}

/// The wording behind Wrapped, shared by the screen card and the story image.
@MainActor
private enum WrappedCopy {
    static func record(_ stats: Stats, games: Int) -> String {
        stats.record.decided > 0 ? stats.record.text : "\(games)"
    }

    static func city(_ library: Library) -> String {
        library.profile.favoriteTeamIds.compactMap { library.team($0) }.first?.locationName ?? "Your teams"
    }

    static func claim(_ stats: Stats, games: Int, library: Library) -> String {
        let r = stats.record
        guard r.decided > 0 else { return "\(games) games. Every one of them yours." }
        let won = r.wins
        let n = r.decided
        let frac = Double(won) / Double(n)
        let phrase: String
        if won == n { phrase = "every game" }
        else if won == 0 { phrase = "none of the \(n) games" }
        else if abs(frac - 2.0 / 3.0) < 0.04 { phrase = "two of every three games" }
        else if abs(frac - 0.5) < 0.02 { phrase = "half the games" }
        else if abs(frac - 0.75) < 0.03 { phrase = "three of every four games" }
        else if abs(frac - 1.0 / 3.0) < 0.03 { phrase = "one of every three games" }
        else { phrase = "\(won) of the \(n) games" }
        return "\(city(library)) won \(phrase) you walked into."
    }

    static func bestPhoto(_ games: [GameEntry], _ library: Library) -> PhotoRef? {
        let wins = games.filter { library.outcome($0) == .win }.sorted { $0.date < $1.date }
        return (wins + games).first { !$0.photos.isEmpty }?.photos.first
    }

    static func credit(_ stats: Stats, library: Library) -> String {
        let name = library.isSample ? "Sam Okafor" : library.profile.displayName
        if let top = stats.companions.first {
            return "Starring \(name) · with \(top.person.name)"
        }
        return "Starring \(name)"
    }
}

// MARK: - Story share cards

/// One game as plain text, for the cards that list or feature a game.
private struct WrapRow: Identifiable {
    let id: String
    let matchup: String
    let score: String
    let dateText: String
    let timeText: String
    let venue: String
    let city: String
    let stage: String
}

private struct WrapStat: Identifiable {
    let value: String
    let label: String
    var id: String { label }
}

@MainActor
private enum WrapData {
    static func row(_ g: GameEntry, _ library: Library) -> WrapRow {
        let venue = library.venue(g.venueId)
        let tz = venue?.tz ?? TimeZone.current
        let home = library.team(g.homeTeamId)?.abbreviation
        let away = library.team(g.awayTeamId)?.abbreviation
        var matchup = venue?.name ?? "Game"
        if g.sport == .motorsport {
            matchup = g.competition ?? "Race"
        } else if let a = away, let h = home {
            matchup = "\(a) at \(h)"
        } else if let h = home {
            matchup = h
        } else if let a = away {
            matchup = a
        }
        var score = ""
        if g.sport != .motorsport, let hs = g.homeScore, let a = g.awayScore { score = "\(a)–\(hs)" }
        return WrapRow(id: g.id, matchup: matchup, score: score,
                       dateText: Fmt.short(g.date, in: tz), timeText: Fmt.time(g.date, in: tz),
                       venue: venue?.name ?? "", city: venue?.cityLine ?? "",
                       stage: g.bigGame?.label ?? "")
    }

    static func kindRank(_ g: GameEntry) -> Int {
        guard let kind = g.bigGame?.kind else { return 9 }
        switch kind {
        case .championship: return 0
        case .playoff: return 1
        case .tournament: return 2
        case .rivalry: return 3
        case .allStar: return 4
        }
    }

    static func margin(_ g: GameEntry) -> Int {
        guard let h = g.homeScore, let a = g.awayScore else { return 9999 }
        return abs(h - a)
    }

    /// Best first: title game, playoff, tournament, rivalry; then (optionally) the closest margin; then most photos.
    static func best(_ games: [GameEntry], byMargin: Bool) -> [GameEntry] {
        games.sorted { a, b in
            let ka = kindRank(a)
            let kb = kindRank(b)
            if ka != kb { return ka < kb }
            if byMargin {
                let ma = margin(a)
                let mb = margin(b)
                if ma != mb { return ma < mb }
            }
            if a.photos.count != b.photos.count { return a.photos.count > b.photos.count }
            return a.date < b.date
        }
    }
}

/// Safe area for story chrome plus the Witness mark, matching `ShareCardFrame`.
private struct WrapSafe<Content: View>: View {
    let mark: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Spacer(minLength: 40)
            Text("WITNESS")
                .font(.system(size: 40, weight: .heavy).width(.compressed))
                .tracking(10)
                .foregroundStyle(mark)
        }
        .padding(.horizontal, 84)
        .padding(.top, 230)
        .padding(.bottom, 250)
        .frame(width: 1080, height: 1920, alignment: .topLeading)
    }
}

private struct WrapKicker: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 44, weight: .heavy).width(.condensed))
            .tracking(8)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func wrapText(_ s: String, size: CGFloat, color: Color, lines: Int = 1,
                      tracking: CGFloat = 0, weight: Font.Weight = .bold) -> some View {
    Text(s)
        .font(.system(size: size, weight: weight).width(.condensed))
        .tracking(tracking)
        .foregroundStyle(color)
        .lineLimit(lines)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
}

private func wrapNumeral(_ s: String, size: CGFloat, color: Color = .white) -> some View {
    Text(s)
        .font(.display(size))
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.3)
        .frame(maxWidth: .infinity, alignment: .leading)
}

private struct WrapStatRow: View {
    let stats: [WrapStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 3)
            HStack(alignment: .top, spacing: 24) {
                ForEach(stats) { s in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.value)
                            .font(.display(130))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        Text(s.label.uppercased())
                            .font(.system(size: 34, weight: .bold).width(.condensed))
                            .tracking(5)
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct WrapRoute: View {
    let cities: [String]
    let extra: Int

    var body: some View {
        let n = max(cities.count, 1)
        VStack(alignment: .leading, spacing: 22) {
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 2)
                    .padding(.horizontal, 456 / CGFloat(n))
                HStack(spacing: 0) {
                    ForEach(cities.indices, id: \.self) { _ in
                        Circle()
                            .fill(Color.signal)
                            .frame(width: 22, height: 22)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(cities.indices, id: \.self) { i in
                    Text(cities[i].uppercased())
                        .font(.system(size: 28, weight: .bold).width(.condensed))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)
                }
            }
            if extra > 0 {
                wrapText("+\(extra) more", size: 32, color: Color.white.opacity(0.55), tracking: 4)
            }
        }
    }
}

private struct WrapLedgerRow: View {
    let rank: Int
    let row: WrapRow

    var body: some View {
        let sub = [row.dateText, row.stage].filter { !$0.isEmpty }.joined(separator: " · ")
        VStack(spacing: 0) {
            Rectangle().fill(Color.black).frame(height: 3)
            HStack(alignment: .center, spacing: 24) {
                Text("\(rank)")
                    .font(.display(120))
                    .foregroundStyle(Color.black)
                    .frame(width: 80, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.matchup.uppercased())
                        .font(.system(size: 50, weight: .heavy).width(.condensed))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(sub.uppercased())
                        .font(.system(size: 32, weight: .bold).width(.condensed))
                        .tracking(3)
                        .foregroundStyle(Color.black.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !row.score.isEmpty {
                    Text(row.score)
                        .font(.display(76))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(height: 184)
        }
    }
}

// 1 Record: giant record on the team-color field, the claim, a framed print.
private struct RecordShareCard: View {
    let year: String
    let record: String
    let claim: String
    let photo: UIImage?
    let tint: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            tint
            LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .center, endPoint: .bottom)
            WrapSafe(mark: Color.white.opacity(0.9)) {
                WrapKicker(text: "Wrapped \(year)", color: Color.white.opacity(0.85))
                wrapNumeral(record, size: 340).padding(.top, 20)
                wrapText(claim.uppercased(), size: 60, color: .white, lines: 3, weight: .heavy).padding(.top, 28)
                Spacer(minLength: 36)
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 856, height: 470)
                        .clipped()
                        .padding(28)
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 16)
                }
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }
}

// 2 Games: monumental count on ink, three-stat row.
private struct GamesShareCard: View {
    let year: String
    let games: Int
    let stats: [WrapStat]
    let tint: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.ink
            LinearGradient(colors: [tint.opacity(0.45), .clear], startPoint: .top, endPoint: .center)
            WrapSafe(mark: Color.white.opacity(0.9)) {
                WrapKicker(text: "Wrapped \(year)", color: Color.white.opacity(0.85))
                Spacer(minLength: 20)
                wrapNumeral("\(games)", size: 640)
                wrapText(games == 1 ? "game in \(year)" : "games in \(year)", size: 56, color: Color.signal, tracking: 8, weight: .heavy)
                    .textCase(.uppercase)
                Spacer(minLength: 60)
                if !stats.isEmpty {
                    WrapStatRow(stats: stats)
                }
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }
}

// 3 Miles: distance as the hero, the farthest stadium, a thin route of cities.
private struct MilesShareCard: View {
    let year: String
    let miles: String
    let farName: String
    let farCity: String
    let route: [String]
    let extra: Int
    let tint: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.ink
            LinearGradient(colors: [.clear, tint.opacity(0.4)], startPoint: .center, endPoint: .bottom)
            WrapSafe(mark: Color.white.opacity(0.9)) {
                WrapKicker(text: "Wrapped \(year)", color: Color.white.opacity(0.85))
                Spacer(minLength: 20)
                wrapNumeral(miles, size: 440)
                wrapText("miles traveled", size: 56, color: Color.signal, tracking: 8, weight: .heavy)
                    .textCase(.uppercase)
                Spacer(minLength: 48)
                if !farName.isEmpty {
                    wrapText("Farthest from home", size: 34, color: Color.white.opacity(0.55), tracking: 5)
                        .textCase(.uppercase)
                    wrapText(farName.uppercased(), size: 76, color: .white, lines: 2, weight: .heavy).padding(.top, 8)
                    wrapText(farCity, size: 40, color: Color.white.opacity(0.7)).padding(.top, 6)
                }
                if route.count >= 2 {
                    Spacer(minLength: 48)
                    WrapRoute(cities: route, extra: extra)
                }
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }
}

// 4 Home Ground: the most-visited stadium, dimmed photo behind it.
private struct HomeGroundShareCard: View {
    let year: String
    let venue: String
    let city: String
    let visits: Int
    let first: String
    let last: String
    let photo: UIImage?
    let tint: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.ink
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 1080, height: 1920)
                    .clipped()
                Color.black.opacity(0.55)
            } else {
                LinearGradient(colors: [tint.opacity(0.5), .clear], startPoint: .top, endPoint: .center)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            WrapSafe(mark: Color.white.opacity(0.9)) {
                WrapKicker(text: "Wrapped \(year)", color: Color.white.opacity(0.85))
                Spacer(minLength: 20)
                wrapText("Most visited", size: 40, color: Color.signal, tracking: 8, weight: .heavy)
                    .textCase(.uppercase)
                Text(venue.uppercased())
                    .font(.display(210))
                    .foregroundStyle(Color.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.35)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                wrapText(city, size: 44, color: Color.white.opacity(0.75)).padding(.top, 12)
                Spacer(minLength: 48)
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    Text("\(visits)")
                        .font(.display(220))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("VISITS")
                        .font(.system(size: 60, weight: .heavy).width(.condensed))
                        .tracking(6)
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        wrapText("First", size: 32, color: Color.white.opacity(0.55), tracking: 5).textCase(.uppercase)
                        wrapText(first, size: 60, color: .white, weight: .heavy)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        wrapText("Last", size: 32, color: Color.white.opacity(0.55), tracking: 5).textCase(.uppercase)
                        wrapText(last, size: 60, color: .white, weight: .heavy)
                    }
                }
                .padding(.top, 28)
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }
}

// 5 Big Game: stage, hero photo, score, date and kickoff.
private struct BigGameShareCard: View {
    let year: String
    let row: WrapRow
    let stage: String
    let isTitle: Bool
    let photo: UIImage?
    let tint: Color

    var body: some View {
        let stageColor: Color = isTitle ? Color.trophy : Color.white
        let when = [row.dateText, row.timeText.isEmpty ? "" : "\(row.timeText) kickoff"].filter { !$0.isEmpty }.joined(separator: " · ")
        ZStack(alignment: .topLeading) {
            Color.ink
            LinearGradient(colors: [tint.opacity(0.45), .clear], startPoint: .top, endPoint: .center)
            WrapSafe(mark: Color.white.opacity(0.9)) {
                WrapKicker(text: "Game of \(year)", color: Color.white.opacity(0.85))
                wrapText(stage.uppercased(), size: 56, color: stageColor, lines: 2, tracking: 4, weight: .heavy)
                    .padding(.top, 36)
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 912, height: 480)
                        .clipped()
                        .clipShape(.rect(cornerRadius: 28))
                        .padding(.top, 36)
                }
                if !row.score.isEmpty {
                    wrapNumeral(row.score, size: photo == nil ? 420 : 260).padding(.top, 12)
                }
                wrapText(row.matchup.uppercased(), size: 64, color: .white, lines: 2, weight: .heavy).padding(.top, 12)
                wrapText(when.uppercased(), size: 44, color: Color.white.opacity(0.85), tracking: 3).padding(.top, 24)
                if !row.venue.isEmpty {
                    wrapText(row.venue, size: 36, color: Color.white.opacity(0.6)).padding(.top, 8)
                }
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }
}

// 6 Coldest (or hottest): the temperature as the hero.
private struct WeatherShareCard: View {
    let year: String
    let isCold: Bool
    let temp: String
    let condition: String
    let venue: String
    let city: String
    let dateText: String
    let timeText: String

    var body: some View {
        let wash: Color = isCold ? Color(hex: "4FA3E0") : Color(hex: "F0782A")
        ZStack(alignment: .topLeading) {
            Color.ink
            LinearGradient(colors: [wash.opacity(0.6), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.75))
            WrapSafe(mark: Color.white.opacity(0.9)) {
                WrapKicker(text: "Wrapped \(year)", color: Color.white.opacity(0.85))
                Spacer(minLength: 20)
                wrapText(isCold ? "Coldest game" : "Hottest game", size: 48, color: Color.signal, tracking: 8, weight: .heavy)
                    .textCase(.uppercase)
                wrapNumeral(temp, size: 520).padding(.top, 8)
                if !condition.isEmpty {
                    wrapText(condition.uppercased(), size: 72, color: .white, lines: 2, tracking: 4, weight: .heavy)
                }
                Spacer(minLength: 60)
                Rectangle().fill(Color.white.opacity(0.3)).frame(height: 3)
                if !venue.isEmpty {
                    wrapText(venue.uppercased(), size: 60, color: .white, lines: 2, weight: .heavy).padding(.top, 28)
                }
                if !city.isEmpty {
                    wrapText(city, size: 40, color: Color.white.opacity(0.7)).padding(.top, 6)
                }
                wrapText("\(dateText) · \(timeText) kickoff".uppercased(), size: 44, color: Color.white.opacity(0.85), tracking: 3)
                    .padding(.top, 20)
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }
}

// 7 Calendar: twelve months, one dot per game. Amber for wins.
private struct CalendarShareCard: View {
    let year: String
    let games: Int
    let months: [[Bool]]
    let busiest: Int

    private let names = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    var body: some View {
        let m = max(busiest, 1)
        let dot = min(34, max(8, (770 - 10 * CGFloat(m - 1)) / CGFloat(m)))
        ZStack(alignment: .topLeading) {
            Color.ink
            WrapSafe(mark: Color.white.opacity(0.9)) {
                WrapKicker(text: "Wrapped \(year)", color: Color.white.opacity(0.85))
                wrapNumeral("\(games)", size: 260).padding(.top, 12)
                wrapText(games == 1 ? "game" : "games", size: 48, color: Color.white.opacity(0.7), tracking: 8, weight: .heavy)
                    .textCase(.uppercase)
                Spacer(minLength: 28)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<12, id: \.self) { i in
                        HStack(spacing: 0) {
                            Text(names[i])
                                .font(.system(size: 30, weight: .bold).width(.condensed))
                                .tracking(4)
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(width: 120, alignment: .leading)
                            HStack(spacing: 10) {
                                if i < months.count && !months[i].isEmpty {
                                    ForEach(months[i].indices, id: \.self) { j in
                                        Circle()
                                            .fill(months[i][j] ? Color.signal : Color.white)
                                            .frame(width: dot, height: dot)
                                    }
                                } else {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(height: 66)
                    }
                }
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }
}

// 8 Top Five: a ruled ledger on paper.
private struct TopFiveShareCard: View {
    let year: String
    let rows: [WrapRow]
    let tint: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "F4F1EA")
            WrapSafe(mark: Color.black) {
                WrapKicker(text: "Wrapped \(year)", color: Color.black.opacity(0.55))
                Text(rows.count == 5 ? "TOP FIVE" : "TOP \(rows.count)")
                    .font(.display(190))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
                Rectangle().fill(tint).frame(width: 140, height: 12).padding(.top, 8)
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { i in
                        WrapLedgerRow(rank: i + 1, row: rows[i])
                    }
                    Rectangle().fill(Color.black).frame(height: 3)
                }
                .padding(.top, 36)
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .light)
    }
}


/// The card content, shared by the screen and the rendered story image.
private struct WrappedCard: View {
    @Environment(Library.self) private var library
    let year: Int
    let compact: Bool

    var body: some View {
        let games = library.games.filter { Fmt.year($0.date) == year }
        let stats = Stats(library: library, games: games)
        VStack(alignment: .leading, spacing: Spacing.block - 8) {
            if compact {
                Text("Wrapped \(String(year))")
                    .font(.condensed(.title3, weight: .heavy))
                    .textCase(.uppercase)
            }
            Text(stats.record.decided > 0 ? stats.record.text : "\(games.count)")
                .displayFont(compact ? 120 : 150)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("wrapped-record")

            Text(claim(stats, games: games.count))
                .displayFont(30, relativeTo: .title)
                .textCase(.uppercase)
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)

            if let photo = bestPhoto(games) {
                Color.black.opacity(0.2)
                    .frame(height: compact ? 170 : 190)
                    .overlay { PhotoView(ref: photo) }
                    .clipShape(.rect(cornerRadius: 14))
            }

            Text(credit(stats))
                .font(.condensed(.footnote, weight: .heavy))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
        }
    }

    private func claim(_ stats: Stats, games: Int) -> String {
        WrappedCopy.claim(stats, games: games, library: library)
    }

    private func bestPhoto(_ games: [GameEntry]) -> PhotoRef? {
        WrappedCopy.bestPhoto(games, library)
    }

    private func credit(_ stats: Stats) -> String {
        WrappedCopy.credit(stats, library: library)
    }
}
