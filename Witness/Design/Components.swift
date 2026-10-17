import SwiftUI
import Photos

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

    static func year(_ date: Date) -> Int { Calendar.current.component(.year, from: date) }
}

// MARK: - Routes

enum Route: Hashable {
    case game(String)
    case youWereThere(String)
    case venue(String)
    case trip(String)
    case person(String)
    case lucky
}

/// Full-screen and sheet presentations reachable from anywhere.
enum Modal: Identifiable, Hashable {
    case addGame
    case importTicket
    case discovery
    case live
    case recap(String)
    case wrapped(Int)

    var id: String {
        switch self {
        case .addGame: "add"
        case .importTicket: "import"
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
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 6 : 8)
            .frame(minHeight: compact ? 22 : 28)
            .background(team?.accent ?? .gray, in: .rect(cornerRadius: compact ? 5 : 7))
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
                Text(game.podium.first ?? "Race")
                    .font(.condensed(.subheadline, weight: .heavy))
            } else {
                side(game.awayTeamId, game.awayScore)
                side(game.homeTeamId, game.homeScore)
                if showFinal {
                    Text("Final").unitLabel()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func side(_ teamId: String?, _ score: Int?) -> some View {
        HStack(spacing: 5) {
            TeamTile(team: library.team(teamId), compact: true)
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

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.value).displayFont(size, relativeTo: .title)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(item.label).unitLabel()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, i == 0 ? 0 : 16)
                .overlay(alignment: .leading) {
                    if i > 0 { Rectangle().fill(Color.hairline).frame(width: 1) }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Photos

/// Loads any PhotoRef: an asset-catalog image, a PhotoKit asset, or a file.
struct PhotoView: View {
    let ref: PhotoRef
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?

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
                    } else {
                        Color.panel
                    }
                }
            }
            .clipped()
            .task(id: ref) { image = await PhotoLoader.load(ref) }
        .accessibilityHidden(true)
    }
}

enum PhotoLoader {
    static func load(_ ref: PhotoRef, size: CGSize = CGSize(width: 1400, height: 1400)) async -> UIImage? {
        switch ref {
        case .bundled(let name):
            return UIImage(named: name)
        case .file(let name):
            let url = URL.documentsDirectory.appending(path: name)
            return UIImage(contentsOfFile: url.path)
        case .library(let id):
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            guard let asset = assets.firstObject else { return nil }
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            return await withCheckedContinuation { cont in
                PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { img, _ in
                    cont.resume(returning: img)
                }
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
        if game.photos.indices.contains(index) {
            PhotoView(ref: game.photos[index])
        } else {
            let team = library.team(library.rootingTeam(game))
            Color.clear.overlay {
                LinearGradient(colors: [(team?.accent ?? .gray).opacity(0.55), Color.ink],
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
            .init(color: Color.ink.opacity(0.6), location: 0),
            .init(color: Color.ink.opacity(0), location: 0.22),
            .init(color: Color.ink.opacity(0), location: 0.5),
            .init(color: Color.ink.opacity(0.9), location: 0.86),
            .init(color: Color.ink, location: 1),
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
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
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
        case .win: .white
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
    let home = library.team(game.homeTeamId)?.locationName
    let away = library.team(game.awayTeamId)?.locationName
    switch (away, home) {
    case let (a?, h?): return "\(a) at \(h)"
    case let (nil, h?): return h
    case let (a?, nil): return a
    default: return library.venue(game.venueId)?.name ?? "Game"
    }
}

/// The big line for a game: its headline, else the score in words.
@MainActor
func headlineText(_ game: GameEntry, _ library: Library) -> String {
    if let h = game.headline, !h.isEmpty { return h }
    guard let hs = game.homeScore, let as_ = game.awayScore else { return matchupText(game, library) }
    let home = library.team(game.homeTeamId)?.locationName ?? "Home"
    let away = library.team(game.awayTeamId)?.locationName ?? "Away"
    return hs >= as_ ? "\(home) \(hs), \(away) \(as_)." : "\(away) \(as_), \(home) \(hs)."
}
