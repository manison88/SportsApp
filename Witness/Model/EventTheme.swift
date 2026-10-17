import SwiftUI

/// The look of a big event: its official colors and a motif we draw ourselves.
/// Never a logo; event names appear as text.
struct EventTheme: Codable, Hashable, Identifiable {
    struct Match: Codable, Hashable {
        var league: String?
        var noteContains: [String]?
        var year: Int?
        var stage: String?
    }

    struct Palette: Codable, Hashable {
        var field: String
        var ink: String
        var accent: String
        var secondary: String?
        var metal: String?
    }

    let id: String
    var name: String
    var edition: String?
    var year: Int?
    var match: Match
    var palette: Palette
    var motif: String?

    var field: Color { Color(hex: palette.field) }
    var ink: Color { Color(hex: palette.ink) }
    var accent: Color { Color(hex: palette.accent) }
    var secondary: Color { palette.secondary.map { Color(hex: $0) } ?? accent }
}

enum EventThemes {
    /// Bundled themes, loaded once.
    static let all: [EventTheme] = {
        let url = Bundle.main.url(forResource: "event-themes", withExtension: "json", subdirectory: "Catalog")
            ?? Bundle.main.url(forResource: "event-themes", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([EventTheme].self, from: data)) ?? []
    }()

    /// The best theme for a game: an edition-specific theme first, then the event's generic one,
    /// then (for rivalries) one built from the two clubs' colors.
    @MainActor
    static func theme(for game: GameEntry, library: Library, in themes: [EventTheme] = all) -> EventTheme? {
        guard let stage = game.bigGame else { return nil }
        if let found = best(for: game, stage: stage, in: themes) { return found }
        if stage.kind == .rivalry { return rivalry(game, stage: stage, library: library) }
        return nil
    }

    static func best(for game: GameEntry, stage: GameEntry.Stage, in themes: [EventTheme]) -> EventTheme? {
        let text = [stage.label, game.competition ?? ""].joined(separator: " ").lowercased()
        let year = Calendar(identifier: .gregorian).component(.year, from: game.date)
        let league = game.source?.league

        var best: (EventTheme, Int)?
        for theme in themes {
            var score = 0
            let phrases = theme.match.noteContains ?? []
            let phraseHit = phrases.contains { text.contains($0.lowercased()) }
            if !phrases.isEmpty {
                guard phraseHit else { continue }
                score += 10
            }
            if let l = theme.match.league {
                if let league {
                    guard l == league else { continue }
                    score += 5
                } else if phrases.isEmpty {
                    continue   // a league-only theme needs to know the league
                }
            }
            if let s = theme.match.stage {
                let ok = (s == "final" && stage.kind == .championship) || (s == "post-season" && stage.kind == .playoff)
                    || (s == "group-stage" && stage.kind == .tournament)
                guard ok else { continue }
                score += 3
            }
            if let y = theme.match.year ?? theme.year {
                // Seasons straddle New Year (a February Super Bowl, a December final): allow one year either way.
                guard abs(y - year) <= 1 else { continue }
                score += y == year ? 8 : 6
            }
            if phrases.isEmpty && theme.match.league == nil { continue }
            if score > (best?.1 ?? 0) { best = (theme, score) }
        }
        return best?.0
    }

    /// A derby wears both clubs: home club as the field, away club as the accent.
    @MainActor
    static func rivalry(_ game: GameEntry, stage: GameEntry.Stage, library: Library) -> EventTheme? {
        guard let home = library.team(game.homeTeamId), let away = library.team(game.awayTeamId) else { return nil }
        return EventTheme(id: "rivalry-\(home.id)-\(away.id)", name: stage.label, edition: nil, year: nil,
                          match: .init(), palette: .init(field: home.colors.primary, ink: "FFFFFF",
                                                         accent: away.colors.primary, secondary: home.colors.secondary,
                                                         metal: nil),
                          motif: "split")
    }
}
