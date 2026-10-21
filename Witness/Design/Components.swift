import SwiftUI
import Photos
import AVKit
import UniformTypeIdentifiers

// MARK: - Formatting

enum Fmt {
    /// "OCT 30, 2016"
    static func day(_ date: Date, in tz: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date).uppercased()
    }

    /// "Jan 5, 2025"
    static func dayTitle(_ date: Date, in tz: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    /// "FEB 20"
    static func short(_ date: Date, in tz: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "MMM d"
        return f.string(from: date).uppercased()
    }

    /// "10:43 PM"
    static func time(_ date: Date, in tz: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    static func number(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }

    /// Fahrenheit only where the phone's region uses US units; Celsius everywhere else (including the UK, which keeps miles).
    static var fahrenheit: Bool { Locale.current.measurementSystem == .us }
    /// A temperature stored in Fahrenheit, shown in the unit this phone's region uses: "54°F" or "12°C".
    static func temperature(_ f: Double, fahrenheit: Bool = Fmt.fahrenheit) -> String {
        fahrenheit ? "\(Int(f.rounded()))\u{00B0}F" : "\(Int(((f - 32) * 5 / 9).rounded()))\u{00B0}C"
    }

    /// Kilometers where the phone's region uses the metric system, miles elsewhere (the US and the UK keep miles).
    static var metric: Bool { Locale.current.measurementSystem == .metric }
    /// "Miles" or "Km", for a stat label.
    static var distanceUnit: String { metric ? "Km" : "Miles" }
    /// "miles" or "kilometers", for a sentence.
    static var distanceWord: String { metric ? "kilometers" : "miles" }
    /// A distance in meters as a short sentence part: "3.2 miles" or "5.1 km".
    static func distance(meters: Double) -> String {
        let value = metric ? meters / 1000 : meters / 1609.344
        let unit = metric ? "km" : "miles"
        return (value < 10 ? String(format: "%.1f", value) : "\(Int(value))") + " " + unit
    }

    static func year(_ date: Date) -> Int { Calendar.current.component(.year, from: date) }
}

// MARK: - Routes

enum Route: Hashable {
    case game(String)
    case youWereThere(String)
    case venue(String)
    case trip(String)
    case lucky
    case bigGames
    case photos(String)
    case plan(String)
}

/// Full-screen and sheet presentations reachable from anywhere.
enum Modal: Identifiable, Hashable {
    case addGame
    case planGame
    case importTicket
    case importAlbum
    case discovery
    case live
    case recap(String)
    case wrapped(Int)

    var id: String {
        switch self {
        case .addGame: "add"
        case .planGame: "plan"
        case .importTicket: "import"
        case .importAlbum: "album"
        case .discovery: "discovery"
        case .live: "live"
        case .recap(let id): "recap-\(id)"
        case .wrapped(let y): "wrapped-\(y)"
        }
    }
}

@Observable
@MainActor
final class Presenter {
    var modal: Modal?
    var tab: AppTab = .timeline
    /// The photo scan that onboarding starts. It outlives the screen, so it can keep running in the background.
    var scan = ScanModel()
}

enum AppTab: Hashable { case timeline, map, passport, you }

// MARK: - Team marks (codes and color only, never logos)

/// Rounded team-color tile with the team's code, e.g. a blue "CHC".
struct TeamTile: View {
    let team: Team?
    var compact = false

    var body: some View {
        Text(team?.abbreviation ?? "—")
            .font(.condensed(compact ? .caption : .subheadline, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle((team?.accent ?? .gray).readableInk)
            .padding(.horizontal, compact ? 6 : 8)
            .frame(minHeight: compact ? 22 : 28)
            .background(team?.accent ?? .gray, in: .rect(cornerRadius: compact ? 5 : 7))
            .fixedSize()
            .accessibilityLabel(team?.locationName ?? "Unknown team")
    }
}

/// Broadcast score bug: CHC 3 · CLE 2.
struct ScoreBug: View {
    @Environment(Library.self) private var library
    let game: GameEntry
    var showFinal = false

    var body: some View {
        HStack(spacing: 6) {
            if game.sport == .motorsport {
                Text(game.podium.first.map { $0.split(separator: " ").prefix(2).joined(separator: " ") } ?? "Race")
                    .font(.condensed(.subheadline, weight: .heavy))
            } else {
                side(game.awayTeamId, game.awayScore)
                side(game.homeTeamId, game.homeScore)
                if showFinal {
                    Text("Final").unitLabel()
                }
            }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private func side(_ teamId: String?, _ score: Int?) -> some View {
        HStack(spacing: 5) {
            if let team = library.team(teamId) {
                TeamTile(team: team, compact: true)
            }
            if let score {
                Text("\(score)").font(.condensed(.subheadline, weight: .heavy)).monospacedDigit()
            }
        }
    }
}

// MARK: - People

struct Avatar: View {
    let person: Person
    var size: CGFloat = 28

    var body: some View {
        Text(person.initials.prefix(1))
            .font(.condensed(.caption, weight: .heavy))
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .background(person.color, in: .circle)
            .overlay(Circle().strokeBorder(Color.ink, lineWidth: 2))
            .accessibilityLabel(person.name)
    }
}

struct AvatarStack: View {
    let people: [Person]
    var body: some View {
        HStack(spacing: -8) {
            ForEach(people) { Avatar(person: $0) }
        }
    }
}

extension Array where Element == Person {
    /// "Maya & Leo", "Maya, Leo & Dana"
    var namesText: String {
        let names = map(\.name)
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " & " + names.last!
    }
}

// MARK: - Stats row

/// Two or three equal stats separated by hairlines. No boxes.
struct StatRow: View {
    struct Item: Identifiable {
        let value: String
        let label: String
        var id: String { label }
    }
    let items: [Item]
    var size: CGFloat = 34
    /// Makes each number a button (the Map's Venues, Countries and Games open their lists).
    var onSelect: ((Int) -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                cell(item, tappable: onSelect != nil) { onSelect?(i) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, i == 0 ? 0 : 16)
                .overlay(alignment: .leading) {
                    if i > 0 { Rectangle().fill(Color.hairline).frame(width: 1) }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("stat-\(item.label.lowercased())")
            }
        }
    }

    @ViewBuilder
    private func cell(_ item: Item, tappable: Bool, action: @escaping () -> Void) -> some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            Text(item.value).displayFont(size, relativeTo: .title)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(item.label).unitLabel()
        }
        if tappable {
            Button(action: action) { content.contentShape(.rect) }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

// MARK: - Photos

/// Loads any PhotoRef: an asset-catalog image, a PhotoKit asset, or a file.
struct PhotoView: View {
    let ref: PhotoRef
    var contentMode: ContentMode = .fill
    /// Shows a play badge with the length on a video.
    var showsMediaBadge = false
    @State private var image: UIImage?
    @State private var failed = false

    init(ref: PhotoRef, contentMode: ContentMode = .fill, showsMediaBadge: Bool = false) {
        self.ref = ref
        self.contentMode = contentMode
        self.showsMediaBadge = showsMediaBadge
        // A photo already loaded shows on the first frame: no blank flash when a card switches to its cover.
        _image = State(initialValue: PhotoLoader.cached(ref))
    }

    var body: some View {
        // A clear base takes the proposed size, so a filled photo never widens its parent.
        Color.clear
            .overlay {
                switch ref {
                case .bundled(let name):
                    Image(name).resizable().aspectRatio(contentMode: contentMode)
                default:
                    if let image {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                    } else if failed {
                        ZStack {
                            Color.panel
                            Image(systemName: "photo").foregroundStyle(Color.textTertiary)
                        }
                    } else {
                        Color.panel
                    }
                }
            }
            .clipped()
            // A filled photo is bigger than its frame; without this the overflow still takes taps meant for what is above it.
            .contentShape(.rect)
            .overlay(alignment: .bottomLeading) {
                if showsMediaBadge, MediaInfo.info(ref).isVideo {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text(MediaInfo.clock(MediaInfo.info(ref).duration))
                    }
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).frame(height: 22)
                    .background(.black.opacity(0.6), in: .capsule)
                    .padding(6)
                }
            }
            .task(id: ref) {
                // Reset first so a reused cell never shows the previous photo; a cached one shows at once.
                image = PhotoLoader.cached(ref)
                failed = false
                if image != nil { return }
                image = await PhotoLoader.load(ref)
                failed = image == nil
            }
        .accessibilityHidden(true)
    }
}

/// Whether a library item is a video, and how long. PhotoKit answers instantly, so it is looked up as needed and kept.
@MainActor
enum MediaInfo {
    struct Info { let isVideo: Bool; let duration: TimeInterval }
    private static var cache: [String: Info] = [:]

    static func info(_ ref: PhotoRef) -> Info {
        guard case .library(let id) = ref else { return Info(isVideo: false, duration: 0) }
        if let hit = cache[id] { return hit }
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        let info = Info(isVideo: asset?.mediaType == .video, duration: asset?.duration ?? 0)
        if asset != nil { cache[id] = info }
        return info
    }

    /// The photos among a mix of photos and videos.
    static func stills(_ refs: [PhotoRef]) -> [PhotoRef] { refs.filter { !info($0).isVideo } }

    /// "0:42", "1:05".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}

enum PhotoLoader {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 160
        return c
    }()

    /// A library photo already in memory at this size, without waiting.
    static func cached(_ ref: PhotoRef, size: CGSize = CGSize(width: 1400, height: 1400)) -> UIImage? {
        guard case .library(let id) = ref else { return nil }
        return cache.object(forKey: "\(id)@\(Int(size.width))" as NSString)
    }

    static func load(_ ref: PhotoRef, size: CGSize = CGSize(width: 1400, height: 1400)) async -> UIImage? {
        switch ref {
        case .bundled(let name):
            return UIImage(named: name)
        case .file(let name):
            let url = URL.documentsDirectory.appending(path: name)
            return UIImage(contentsOfFile: url.path)
        case .library(let id):
            let key = "\(id)@\(Int(size.width))" as NSString
            if let hit = cache.object(forKey: key) { return hit }
            // A request can come back empty while Photos is busy (a big scan) or while the original is still in
            // iCloud, so ask again a couple of times before giving up.
            var standIn: UIImage?
            for attempt in 0..<3 {
                let got = await request(id, size: size)
                if let image = got.image, !got.standIn {
                    cache.setObject(image, forKey: key)
                    return image
                }
                standIn = got.image ?? standIn
                // A stalled request still gave a low-quality picture: show it now (uncached, so the next look tries again).
                if standIn != nil || Task.isCancelled { return standIn }
                try? await Task.sleep(for: .milliseconds(500 * (attempt + 1)))
            }
            return standIn
        }
    }

    /// Resumes a continuation exactly once, however many times Photos calls back.
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func take() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }

    /// A low-quality stand-in kept until the real image arrives, so a stalled request still has something to show.
    private final class Stand: @unchecked Sendable {
        private let lock = NSLock()
        private var image: UIImage?
        func set(_ i: UIImage) { lock.lock(); image = i; lock.unlock() }
        func get() -> UIImage? { lock.lock(); defer { lock.unlock() }; return image }
    }

    /// Asks Photos for one image. Photos can sit on a request indefinitely (a stalled iCloud download, or a queue full of
    /// scan requests), so after `timeout` the request is cancelled and the low-quality stand-in, if any, is used instead.
    private static func request(_ id: String, size: CGSize, timeout: TimeInterval = 8) async -> (image: UIImage?, standIn: Bool) {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return (nil, false) }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let once = Once()
        let stand = Stand()
        return await withCheckedContinuation { (cont: CheckedContinuation<(UIImage?, Bool), Never>) in
            let requestId = PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, info in
                // A low-quality stand-in is followed by the real image; keep it, and wait for that one.
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                    if let image { stand.set(image) }
                    return
                }
                guard once.take() else { return }
                if let image { cont.resume(returning: (image, false)) } else { cont.resume(returning: (stand.get(), true)) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard once.take() else { return }
                PHImageManager.default().cancelImageRequest(requestId)
                cont.resume(returning: (stand.get(), true))
            }
        }
    }
}

/// A game's lead photo, or a team-color field when it has none.
struct GameBackdrop: View {
    @Environment(Library.self) private var library
    let game: GameEntry
    var index = 0

    var body: some View {
        if index == 0, let hero = game.heroPhoto {
            // The cover can change after a game is added (the best photo is picked a moment later): cross-fade to it.
            ZStack {
                PhotoView(ref: hero)
                    .id(hero)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.6), value: hero)
        } else if game.photos.indices.contains(index) {
            PhotoView(ref: game.photos[index])
        } else {
            let team = library.team(library.rootingTeam(game))
            Color.clear.overlay {
                LinearGradient(colors: [(team?.accent ?? .gray).opacity(0.55), Color.photoInk],
                               startPoint: .topTrailing, endPoint: .bottomLeading)
                Image(systemName: game.sport.symbol)
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(.white.opacity(0.07))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 70, y: -20)
            }
            .clipped()
            .accessibilityHidden(true)
        }
    }
}

/// Broadcast scrim over a photo: dark at the top for the bar, darker at the foot for type.
struct Scrim: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: Color.photoInk.opacity(0.6), location: 0),
            .init(color: Color.photoInk.opacity(0), location: 0.22),
            .init(color: Color.photoInk.opacity(0), location: 0.5),
            .init(color: Color.photoInk.opacity(0.9), location: 0.86),
            .init(color: Color.photoInk, location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }
}

// MARK: - Misc

/// The 44pt circular icon button used in the custom bars of modal screens.
struct CircleButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.bold))
                .foregroundStyle(Color.primaryText)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(label)
    }
}

extension View {
    /// Standard page padding.
    func gutter() -> some View { padding(.horizontal, Spacing.gutter) }

    /// Ink page background behind scroll content.
    func inkBackground() -> some View {
        background(Color.ink.ignoresSafeArea())
    }
}

/// Short words for a result.
extension Outcome {
    var color: Color {
        switch self {
        case .win: .primaryText
        case .loss: .textSecondary
        case .draw: .textSecondary
        case .none: .textTertiary
        }
    }
}

/// Text describing who played, "Chicago vs Cleveland" or the race name.
@MainActor
func matchupText(_ game: GameEntry, _ library: Library) -> String {
    if game.sport == .motorsport { return game.competition ?? "Race" }
    if game.isVisit { return library.venue(game.venueId)?.name ?? "Stadium visit" }
    let home = library.team(game.homeTeamId)?.locationName
    let away = library.team(game.awayTeamId)?.locationName
    switch (away, home) {
    case let (a?, h?): return "\(a) at \(h)"
    case let (nil, h?): return h
    case let (a?, nil): return a
    default:
        let venue = library.venue(game.venueId)?.name
        if game.sport == .other { return venue.map { "\(game.sportName) at \($0)" } ?? game.sportName }
        return venue ?? "Game"
    }
}

/// The big line for a game: its headline, else the score in words.
@MainActor
func headlineText(_ game: GameEntry, _ library: Library) -> String {
    if let h = game.headline, !h.isEmpty { return h }
    guard let hs = game.homeScore, let as_ = game.awayScore else { return matchupText(game, library) }
    guard let home = library.team(game.homeTeamId)?.locationName,
          let away = library.team(game.awayTeamId)?.locationName else {
        let venue = library.venue(game.venueId)?.name ?? "the game"
        return "\(max(hs, as_))–\(min(hs, as_)) at \(venue)."
    }
    // One team per line, the winner first.
    return hs >= as_ ? "\(home) \(hs)\n\(away) \(as_)" : "\(away) \(as_)\n\(home) \(hs)"
}

/// The game page title: one line per team, name left and score right, the winner first. A long name scales down to fit
/// instead of wrapping ("Bosnia and Herzegovina 3" stays on one line).
struct ScoreLinesTitle: View {
    let game: GameEntry
    @Environment(Library.self) private var library

    private struct Row: Identifiable { let id: String; let name: String; let score: Int }

    private var rows: [Row]? {
        guard game.headline?.isEmpty != false, let hs = game.homeScore, let a = game.awayScore,
              let home = library.team(game.homeTeamId)?.locationName,
              let away = library.team(game.awayTeamId)?.locationName else { return nil }
        let h = Row(id: "home", name: home, score: hs), v = Row(id: "away", name: away, score: a)
        return hs >= a ? [h, v] : [v, h]
    }

    var body: some View {
        if let rows {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(row.name.uppercased())
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(row.score)")
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                            .frame(minWidth: 64, alignment: .trailing)
                    }
                    .displayFont(52)
                }
            }
            .foregroundStyle(Color.primaryText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rows.map { "\($0.name) \($0.score)" }.joined(separator: ", "))
        } else {
            Text(headlineText(game, library).uppercased().replacingOccurrences(of: ". ", with: ".\n"))
                .displayFont(52)
                .lineLimit(4)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Color.primaryText)
        }
    }
}

extension View {
    /// Tab-screen title, as in the mockups: compressed title left, one action right,
    /// on the same row. The system title still names the screen for back buttons.
    func tabTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(title.uppercased())
                        .displayFont(30, relativeTo: .title)
                        .foregroundStyle(Color.primaryText)
                        .fixedSize()
                        .accessibilityAddTraits(.isHeader)
                }
                .withoutGlass()
                ToolbarItem(placement: .principal) {
                    Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
                }
                .withoutGlass()
            }
    }
}

/// The glyph of a toolbar button over a photo hero (the bar's own background hidden). iOS 26 draws every toolbar item in its
/// own glass capsule, so the glyph goes in bare, like every other toolbar button in the app: a material disc of our own inside
/// that capsule read as an off-centre blob in a pill. Earlier systems draw nothing behind a hidden bar, so there the disc stays
/// to keep the glyph readable on the photo.
struct HeroToolbarIcon: View {
    var systemName: String
    var body: some View {
        if #available(iOS 26.0, *) {
            // The same 44 pt cell as the disc below and as a play button beside it, so a row of these spaces out evenly.
            Image(systemName: systemName)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        } else {
            Image(systemName: systemName)
                .font(.body.weight(.bold))
                .foregroundStyle(Color.primaryText)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
    }
}

extension ToolbarContent {
    /// iOS 26 wraps every toolbar item in a glass capsule; a screen title should sit on the page, not in a button.
    @ToolbarContentBuilder
    func withoutGlass() -> some ToolbarContent {
        // The iOS 26 SDK ships with Swift 6.2; older toolchains (CI on Xcode 16) do not know this API.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - Big games

extension GameEntry.Stage.Kind {
    var symbol: String {
        switch self {
        case .championship: "trophy.fill"
        case .playoff: "medal.fill"
        case .tournament: "globe.europe.africa.fill"
        case .rivalry: "flame.fill"
        case .allStar: "star.fill"
        }
    }

    var tint: Color { self == .championship ? .trophy : Color.primaryText }

    var name: String {
        switch self {
        case .championship: "Title game"
        case .playoff: "Playoffs"
        case .tournament: "Tournament"
        case .rivalry: "Rivalry"
        case .allStar: "All-Star"
        }
    }
}

/// Broadcast-style chip for a big game: symbol and the event's own name, no marks.
/// The subtle big-game mark: a small pin in the event's colors, the event name and a short palette ribbon.
/// The photo stays clean; nothing here is a logo, only our own shapes and the event's name as text.
struct EventMark: View {
    @Environment(Library.self) private var library
    let game: GameEntry
    let stage: GameEntry.Stage

    var body: some View {
        let theme = EventThemes.theme(for: game, library: library)
        let field = theme?.field ?? Color.panelRaised
        let ink = theme?.ink ?? stage.kind.tint
        let accent = theme?.accent ?? stage.kind.tint
        HStack(spacing: 10) {
            Image(systemName: stage.kind.symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: 44, height: 44)
                .background(field, in: .circle)
                .overlay(Circle().strokeBorder(accent, lineWidth: 2))
                .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(stage.label)
                    .font(.condensed(.caption, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                HStack(spacing: 0) {
                    Rectangle().fill(field)
                    Rectangle().fill(accent)
                    Rectangle().fill(theme?.secondary ?? accent)
                }
                .frame(width: 64, height: 3)
                .clipShape(.capsule)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stage.kind.name): \(stage.label)")
        .accessibilityIdentifier("big-game-badge")
    }
}


// MARK: - Sport colors

extension Sport {
    /// The sport's line and dot color on the map. Chosen to stay apart from each other on a dark map.
    var lineColor: Color {
        switch self {
        case .baseball: Color(hex: "FF5A4F")
        case .football: Color(hex: "3DDC84")
        case .basketball: Color(hex: "FFA42E")
        case .hockey: Color(hex: "5AC8FA")
        case .soccer: Color(hex: "E6F05A")
        case .motorsport: Color(hex: "BF7BFF")
        case .handball: Color(hex: "FF7AD1")
        case .other: Color(hex: "9AA3B2")
        }
    }
}

// MARK: - Score as two lines

/// The final score, one team per line: tile, city, score.
struct ScoreStack: View {
    @Environment(Library.self) private var library
    let game: GameEntry

    var body: some View {
        VStack(spacing: 0) {
            row(game.awayTeamId, game.awayScore, other: game.homeScore)
            Rectangle().fill(Color.hairline).frame(height: 1)
            row(game.homeTeamId, game.homeScore, other: game.awayScore)
            Text("Final").unitLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("score-stack")
    }

    private func row(_ teamId: String?, _ score: Int?, other: Int?) -> some View {
        let team = library.team(teamId)
        let won = (score ?? 0) > (other ?? 0)
        return HStack(spacing: 12) {
            TeamTile(team: team, compact: true)
            Text(team?.displayName ?? "")
                .font(.condensed(.title3, weight: .heavy))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(won ? Color.primaryText : Color.textSecondary)
            Spacer(minLength: 8)
            Text(score.map(String.init) ?? "")
                .font(.condensed(.title2, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(won ? Color.primaryText : Color.textSecondary)
        }
        .frame(minHeight: 48)
    }
}

// MARK: - Photos

struct PhotoViewerItem: Identifiable { let id: Int }

/// Full-screen photos for a game: swipe between them, pinch or double-tap to zoom.
struct PhotoPager: View {
    let photos: [PhotoRef]
    var cover: PhotoRef?
    var onSetCover: ((PhotoRef) -> Void)?
    /// Takes a photo off the game (never out of the Photos library). Shows a trash button when set.
    var onDelete: ((PhotoRef) -> Void)?
    @State var index: Int
    @State private var confirmDelete = false
    @State private var reelPosition: Int?
    @State private var zoomed = false
    @Environment(\.dismiss) private var dismiss

    init(photos: [PhotoRef], start: Int, cover: PhotoRef? = nil, onSetCover: ((PhotoRef) -> Void)? = nil,
         onDelete: ((PhotoRef) -> Void)? = nil) {
        self.photos = photos
        self.cover = cover
        self.onSetCover = onSetCover
        self.onDelete = onDelete
        _index = State(initialValue: start)
    }

    private func removeCurrent() {
        guard photos.indices.contains(index) else { return }
        let ref = photos[index]
        if photos.count <= 1 {
            onDelete?(ref)
            dismiss()
            return
        }
        index = min(index, photos.count - 2)
        onDelete?(ref)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea().accessibilityIdentifier("photo-viewer")
            // A camera-roll reel: swipe sideways from photo to photo; pinch to zoom, and while zoomed a drag pans.
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { i, ref in
                        ZoomablePhoto(ref: ref, zoomed: $zoomed)
                            .containerRelativeFrame(.horizontal)
                            .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $reelPosition)
            .scrollDisabled(zoomed)
            .ignoresSafeArea()
            .onAppear { reelPosition = index }
            .onChange(of: reelPosition) { _, new in
                if let new, new != index { index = new; zoomed = false }
            }
            .onChange(of: index) { _, new in
                if reelPosition != new { reelPosition = new }
            }
            HStack {
                CircleButton(systemName: "xmark", label: "Close") { dismiss() }
                    .accessibilityIdentifier("photo-viewer-close")
                Spacer()
                Text("\(index + 1) / \(photos.count)")
                    .font(.condensed(.subheadline, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(minHeight: 32)
                    .background(.black.opacity(0.55), in: .capsule)
                if onDelete != nil {
                    CircleButton(systemName: "trash", label: "Remove photo") { confirmDelete = true }
                        .accessibilityIdentifier("photo-viewer-delete")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .confirmationDialog("Remove this photo from the game?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove photo", role: .destructive) { removeCurrent() }
        } message: {
            Text("It stays in your Photos library.")
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 14) {
                if photos.count > 1 { filmstrip }
                coverButton
            }
        }
        // A black screen: white clock and battery, and dark controls, in Light too.
        .preferredColorScheme(.dark)
    }

    /// Small thumbnails along the bottom: shows how many there are and jumps to any of them.
    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { i, ref in
                        Button { withAnimation(.snappy) { index = i } } label: {
                            Color.panel.frame(width: 44, height: 44)
                                .overlay { PhotoView(ref: ref) }
                                .clipShape(.rect(cornerRadius: 6))
                                .overlay { RoundedRectangle(cornerRadius: 6).stroke(i == index ? Color.signal : .clear, lineWidth: 2) }
                                .opacity(i == index ? 1 : 0.65)
                        }
                        .buttonStyle(.plain)
                        .id(i)
                        .accessibilityLabel("Photo \(i + 1)")
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 48)
            .onChange(of: index) { _, new in withAnimation { proxy.scrollTo(new, anchor: .center) } }
            .onAppear { proxy.scrollTo(index, anchor: .center) }
        }
        .accessibilityIdentifier("photo-viewer-strip")
    }

    @ViewBuilder
    private var coverButton: some View {
            if let onSetCover, photos.indices.contains(index) {
                let isCover = (coverSet ?? cover) == photos[index]
                Button {
                    coverSet = photos[index]
                    onSetCover(photos[index])
                } label: {
                    Label(isCover ? "Cover photo" : "Use as cover", systemImage: isCover ? "checkmark.circle.fill" : "photo.badge.checkmark")
                        .font(.condensed(.headline, weight: .heavy))
                        .foregroundStyle(isCover ? Color.signal : .white)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(.black.opacity(0.6), in: .capsule)
                }
                .disabled(isCover)
                .padding(.bottom, 24)
                .accessibilityIdentifier("photo-viewer-cover")
            }
    }

    @State private var coverSet: PhotoRef?
}

/// A video from the library, played in the full-screen viewer with the system controls.
private struct VideoAssetView: View {
    let id: String
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player { VideoPlayer(player: player) } else { ProgressView().tint(.white) }
        }
        .task(id: id) { player = await Self.makePlayer(id) }
        .onDisappear { player?.pause() }
        .accessibilityIdentifier("photo-viewer-video")
    }

    private static func makePlayer(_ id: String) async -> AVPlayer? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                continuation.resume(returning: item.map { AVPlayer(playerItem: $0) })
            }
        }
    }
}

private struct ZoomablePhoto: View {
    let ref: PhotoRef
    @Binding var zoomed: Bool
    @State private var scale: CGFloat = 1
    @State private var base: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero

    var body: some View {
        if MediaInfo.info(ref).isVideo, case .library(let id) = ref {
            VideoAssetView(id: id)
        } else {
            still
        }
    }

    private var still: some View {
        PhotoView(ref: ref, contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(MagnifyGesture()
                .onChanged { scale = min(max(base * $0.magnification, 1), 6) }
                .onEnded { _ in
                    base = scale
                    if scale <= 1.01 { reset() }
                })
            .simultaneousGesture(DragGesture()
                .onChanged { if scale > 1 { offset = CGSize(width: dragStart.width + $0.translation.width, height: dragStart.height + $0.translation.height) } }
                .onEnded { _ in dragStart = offset },
                including: scale > 1 ? .all : .none)
            .onChange(of: scale) { _, new in zoomed = new > 1.01 }
            .onTapGesture(count: 2) {
                withAnimation(.smooth(duration: 0.25)) {
                    if scale > 1 { reset() } else { scale = 2.5; base = 2.5 }
                }
            }
    }

    private func reset() {
        scale = 1; base = 1; offset = .zero; dragStart = .zero
    }
}

// MARK: - Share cards

/// Where a card will be posted. `story` fills a phone (Instagram/TikTok stories); `feed` is the 4:5 post.
enum ShareCardFormat {
    case story, feed

    var size: CGSize {
        switch self {
        case .story: CGSize(width: 1080, height: 1920)
        case .feed: CGSize(width: 1080, height: 1350)
        }
    }
}

/// Which look a share card is drawn in. Set from outside by the share sheet; the card's root applies it with `.shareSurface()`,
/// so an export never depends on the live UI's appearance.
private struct ShareSchemeKey: EnvironmentKey { static let defaultValue: ColorScheme = .dark }

extension EnvironmentValues {
    var shareScheme: ColorScheme {
        get { self[ShareSchemeKey.self] }
        set { self[ShareSchemeKey.self] = newValue }
    }
}

private struct ShareSurface: ViewModifier {
    @Environment(\.shareScheme) private var scheme
    func body(content: Content) -> some View { content.environment(\.colorScheme, scheme) }
}

extension View {
    /// Draws a share card in the chosen look (light or dark). Palette colors and `Color.primaryText` follow it.
    func shareSurface() -> some View { modifier(ShareSurface()) }
    /// Keeps a photo-led part of a card dark whichever look was chosen: white type on a photo or team color.
    func shareOnPhoto() -> some View { environment(\.colorScheme, .dark) }
}

extension Color {
    /// The "paper" share look: warm paper with black type in the light card, warm black with paper type in the dark one.
    static func sharePaper(_ scheme: ColorScheme) -> Color { scheme == .light ? Color(hex: "F4F1EA") : Color(hex: "17160F") }
    static func sharePaperInk(_ scheme: ColorScheme) -> Color { scheme == .light ? Color(hex: "0B0B0C") : Color(hex: "F4F1EA") }
}

/// The frame every share card sits in: ink background (light or dark), a wash of the accent color at the top, margins that
/// keep content clear of story chrome, and the Witness mark at the bottom. Cards are drawn at full pixel size
/// (1080 wide), so type is big: hero 300-420pt `.display`, labels 36-44pt condensed with tracking, one idea per card.
/// Cards take plain values and `UIImage`s, never `@Environment`, so they render the same anywhere.
struct ShareCardFrame<Content: View>: View {
    let format: ShareCardFormat
    var accent: Color = .signal
    @ViewBuilder var content: Content
    @Environment(\.shareScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.ink
            LinearGradient(colors: [accent.opacity(scheme == .dark ? 0.4 : 0.28), .clear], startPoint: .top, endPoint: .center)
            VStack(alignment: .leading, spacing: 0) {
                content
                Spacer(minLength: 40)
                Text("WITNESS")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .tracking(10)
                    .foregroundStyle(Color.primaryText.opacity(0.9))
            }
            .padding(.horizontal, 84)
            .padding(.top, format == .story ? 230 : 96)
            .padding(.bottom, format == .story ? 250 : 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: format.size.width, height: format.size.height)
        .shareSurface()
    }
}

/// A card drawn to a real file: an opaque sRGB image at the format's exact pixel size, written under a readable name.
/// Share the file, not an in-memory image: Messages and Mail need a file with a name and a type, and show a black
/// placeholder for anonymous image data. The temp folder lives as long as this object, which the share sheet holds.
final class ShareCardExport: @unchecked Sendable {
    let image: UIImage
    let pngURL: URL
    /// A JPEG of the same card, written only when the PNG is large (photo-heavy cards); Messages prefers it.
    let jpegURL: URL?
    let name: String
    private let folder: URL

    var prefersJPEG: Bool { jpegURL != nil }

    /// A PNG larger than this goes out as a JPEG.
    static let pngLimit = 4_000_000

    /// A file-safe name: "Witness-<title>-<style>".
    static func fileName(_ parts: [String]) -> String {
        let text = (["Witness"] + parts).joined(separator: "-")
        var out = ""
        var dash = false
        for u in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(u) { out.unicodeScalars.append(u); dash = false }
            else if !dash { out.append("-"); dash = true }
        }
        out = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String(out.prefix(60))
    }

    /// Redraws the card opaque in sRGB at exactly `size` pixels (ImageRenderer can hand back alpha and wide color).
    static func flatten(_ ui: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(Color.photoInk).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ui.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    init?(rendered ui: UIImage, size: CGSize, name: String, pngLimit: Int = ShareCardExport.pngLimit) {
        let flat = Self.flatten(ui, size: size)
        guard let png = flat.pngData() else { return nil }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("share-" + UUID().uuidString, isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else { return nil }
        let pngURL = folder.appendingPathComponent(name + ".png")
        guard (try? png.write(to: pngURL)) != nil else { return nil }
        var jpegURL: URL?
        if png.count > pngLimit, let jpeg = flat.jpegData(compressionQuality: 0.92) {
            let url = folder.appendingPathComponent(name + ".jpg")
            if (try? jpeg.write(to: url)) != nil { jpegURL = url }
        }
        self.image = flat
        self.pngURL = pngURL
        self.jpegURL = jpegURL
        self.name = name
        self.folder = folder
    }

    deinit { try? FileManager.default.removeItem(at: folder) }
}

/// What the share sheet receives for a PNG: the file itself, with the image as a fallback.
struct ShareCardPNG: Transferable {
    let export: ShareCardExport
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { item in
            SentTransferredFile(item.export.pngURL, allowAccessingOriginalFile: true)
        }
        ProxyRepresentation { Image(uiImage: $0.export.image) }
    }
}

/// The JPEG of a large card.
struct ShareCardJPEG: Transferable {
    let export: ShareCardExport
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .jpeg) { item in
            SentTransferredFile(item.export.jpegURL ?? item.export.pngURL, allowAccessingOriginalFile: true)
        }
        ProxyRepresentation { Image(uiImage: $0.export.image) }
    }
}

/// A ShareLink for one exported card: the file (PNG, or JPEG when the PNG is large), previewed with its image.
struct ShareCardFileLink<Label: View>: View {
    let export: ShareCardExport
    let title: String
    @ViewBuilder var label: Label

    var body: some View {
        let preview = SharePreview(title, image: Image(uiImage: export.image))
        if export.prefersJPEG {
            ShareLink(item: ShareCardJPEG(export: export), preview: preview) { label }
        } else {
            ShareLink(item: ShareCardPNG(export: export), preview: preview) { label }
        }
    }
}

/// Draws a card to an image at its format's pixel size, in the given look.
@MainActor
func renderShareImage<V: View>(_ card: V, format: ShareCardFormat, scheme: ColorScheme = .dark, name: String = "card") -> ShareCardExport? {
    let renderer = ImageRenderer(content: card.environment(\.shareScheme, scheme).environment(\.colorScheme, scheme))
    renderer.scale = 1
    renderer.proposedSize = ProposedViewSize(format.size)
    guard let ui = renderer.uiImage else { return nil }
    return ShareCardExport(rendered: ui, size: format.size, name: name)
}

/// A share button that shares the card as a file. The card is built (load photos here) and drawn when the
/// button appears, and again when `key` changes; until it is ready the label shows dimmed and does nothing.
struct ShareCardLink<Card: View, Label: View>: View {
    let title: String
    let format: ShareCardFormat
    var key: String = ""
    var scheme: ColorScheme = .dark
    let card: () async -> Card
    @ViewBuilder var label: Label

    @State private var export: ShareCardExport?

    var body: some View {
        Group {
            if let export {
                ShareCardFileLink(export: export, title: title) { label }
            } else {
                label.opacity(0.4)
            }
        }
        .task(id: key) { export = renderShareImage(await card(), format: format, scheme: scheme, name: ShareCardExport.fileName([title])) }
    }
}

// MARK: - Share card variations

/// One look for a share card: a name and the full-size card (drawn at `ShareCardFormat.size`).
struct ShareCardVariant: Identifiable {
    let id: String
    let name: String
    let card: AnyView

    init<V: View>(_ name: String, @ViewBuilder card: () -> V) {
        self.id = name
        self.name = name
        self.card = AnyView(card())
    }
}

/// The sheet behind every Share button: swipe through the variations, then share the one you like as an image.
struct ShareCardSheet: View {
    /// Which share this is (game, passport, venue...), for the usage events.
    var kind: String = "card"
    let title: String
    let format: ShareCardFormat
    var key: String = ""
    let variants: () async -> [ShareCardVariant]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var appScheme
    @State private var built: [ShareCardVariant] = []
    @State private var rendered: [ShareCardExport] = []
    @State private var selection = 0
    /// The look the cards are drawn in: starts as the app's current one (Auto resolved by the system), then the fan's choice.
    @State private var scheme: ColorScheme?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(title)
                    .font(.condensed(.title3, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.primaryText)
                        .frame(width: 40, height: 40)
                        .background(Color.panelRaised, in: .circle)
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, 20)

            if rendered.isEmpty {
                ProgressView().tint(Color.primaryText).frame(maxHeight: .infinity)
            } else {
                Picker("Look", selection: Binding(get: { scheme ?? appScheme }, set: { scheme = $0 })) {
                    Text("Light").tag(ColorScheme.light)
                    Text("Dark").tag(ColorScheme.dark)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .accessibilityIdentifier("share-card-look")

                TabView(selection: $selection) {
                    ForEach(rendered.indices, id: \.self) { i in
                        Image(uiImage: rendered[i].image)
                            .resizable()
                            .aspectRatio(format.size.width / format.size.height, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.hairline))
                            .padding(.horizontal, 36)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 10) {
                    Text(built[min(selection, built.count - 1)].name)
                        .unitLabel()
                    HStack(spacing: 8) {
                        ForEach(rendered.indices, id: \.self) { i in
                            Circle()
                                .fill(i == selection ? Color.primaryText : Color.textTertiary)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .accessibilityHidden(true)
                }

                let current = rendered[min(selection, rendered.count - 1)]
                let currentName = built[min(selection, built.count - 1)].name
                ShareCardFileLink(export: current, title: title) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.primary)
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, 12)
                .simultaneousGesture(TapGesture().onEnded {
                    Analytics.shared.track(.shareTapped, ["kind": kind, "style": currentName, "look": (scheme ?? appScheme) == .light ? "light" : "dark"])
                })
                .accessibilityIdentifier("share-card-share")
            }
        }
        .background(Color.ink.ignoresSafeArea())
        .presentationDetents([.large])
        .onAppear { Analytics.shared.track(.shareOpened, ["kind": kind]) }
        .task(id: key) {
            built = await variants()
            await renderAll()
            selection = 0
        }
        .task(id: scheme) {
            // The look changed: draw every card again (the cards are already built).
            guard !built.isEmpty, scheme != nil else { return }
            await renderAll()
        }
    }

    @MainActor
    private func renderAll() async {
        let look = scheme ?? appScheme
        var out: [ShareCardExport] = []
        for v in built {
            if let export = renderShareImage(v.card, format: format, scheme: look, name: ShareCardExport.fileName([title, v.name, look == .light ? "light" : "dark"])) {
                out.append(export)
            }
            await Task.yield()
        }
        rendered = out
        #if DEBUG
        // Review builds: -uitest runs copy each export to REVIEW_OUT so the cards can be checked as files.
        if let folder = ProcessInfo.processInfo.environment["REVIEW_OUT"] {
            let dir = URL(fileURLWithPath: folder).appendingPathComponent("export", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for e in out { try? FileManager.default.copyItem(at: e.pngURL, to: dir.appendingPathComponent(e.pngURL.lastPathComponent)) }
        }
        #endif
    }
}

extension View {
    /// Presents the share sheet (a swipeable set of variations) when `isPresented` is true.
    /// Use this when the Share button lives inside a Menu: set a @State flag from the button, attach this to the screen.
    func shareCardSheet(isPresented: Binding<Bool>, kind: String = "card", title: String, format: ShareCardFormat, key: String = "",
                        variants: @escaping () async -> [ShareCardVariant]) -> some View {
        sheet(isPresented: isPresented) {
            ShareCardSheet(kind: kind, title: title, format: format, key: key, variants: variants)
        }
    }
}

/// A Share button that opens the variations sheet. For a toolbar or any place that is not inside a Menu.
struct ShareCardSheetLink<Label: View>: View {
    var kind: String = "card"
    let title: String
    let format: ShareCardFormat
    var key: String = ""
    let variants: () async -> [ShareCardVariant]
    @ViewBuilder var label: Label

    @State private var showing = false

    var body: some View {
        Button { showing = true } label: { label }
            .shareCardSheet(isPresented: $showing, kind: kind, title: title, format: format, key: key, variants: variants)
    }
}

/// What a found game shows in a review card: both teams and the score, or for a Formula 1 race its name and winner.
struct FoundGameChip: View {
    let game: FoundGame
    var font: Font = .condensed(.subheadline, weight: .heavy)

    var body: some View {
        if let race = game.race {
            HStack(spacing: 6) {
                Image(systemName: "flag.checkered").accessibilityHidden(true)
                Text(race.shortName).lineLimit(1)
                if let winner = race.results?.winner?.code { Text(winner).foregroundStyle(Color.textSecondary) }
            }
            .font(font)
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: 5) {
                TeamTile(team: GameLookup.team(from: game.away, game: game), compact: true)
                Text(game.away.score.map(String.init) ?? "").font(font).monospacedDigit()
                TeamTile(team: GameLookup.team(from: game.home, game: game), compact: true)
                Text(game.home.score.map(String.init) ?? "").font(font).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(game.away.location) \(game.away.score ?? 0), \(game.home.location) \(game.home.score ?? 0)")
        }
    }
}

// MARK: - Status bar over photo heroes

/// A page that opens on a full-bleed dark photo needs the clock and battery in white, even in Light. The system draws the
/// status bar from the navigation controller's bar style, so this sets it while the page is on screen and restores it after.
private struct LightStatusBar: UIViewControllerRepresentable {
    final class Probe: UIViewController {
        private var previous: UIBarStyle?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let nav = navigationController else { return }
            if previous == nil { previous = nav.navigationBar.barStyle }
            nav.navigationBar.barStyle = .black
            nav.setNeedsStatusBarAppearanceUpdate()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let nav = navigationController, let previous else { return }
            nav.navigationBar.barStyle = previous
            self.previous = nil
            nav.setNeedsStatusBarAppearanceUpdate()
        }
    }

    func makeUIViewController(context: Context) -> Probe { Probe() }
    func updateUIViewController(_ controller: Probe, context: Context) {}
}

extension View {
    /// Light clock and battery while this page, which starts with a dark photo, is showing.
    func lightStatusBar() -> some View {
        background { LightStatusBar().frame(width: 0, height: 0).allowsHitTesting(false) }
    }
}
