import Foundation

/// Spots the games that matter more than most: finals, playoffs, tournaments, rivalries.
/// Reads what the schedule says (season type, round, notes) or, without a schedule, the game's own label.
enum BigGame {
    /// Competitions whose every match is an occasion.
    static let tournamentLeagues: [String: String] = [
        "soccer/fifa.world": "World Cup", "soccer/fifa.wwc": "Women's World Cup", "soccer/uefa.euro": "Euro",
        "soccer/conmebol.america": "Copa América", "soccer/concacaf.gold": "Gold Cup", "soccer/fifa.cwc": "Club World Cup",
    ]

    /// National-team qualifying: every match counts, the playoff rounds most of all.
    static let qualifierLeagues: [String: String] = [
        "soccer/fifa.worldq.uefa": "World Cup qualifying", "soccer/fifa.worldq.conmebol": "World Cup qualifying",
        "soccer/fifa.worldq.concacaf": "World Cup qualifying", "soccer/uefa.euroq": "Euro qualifying",
        "soccer/uefa.nations": "Nations League",
    ]

    /// Cup competitions: their final is a title game, their knockout rounds are playoffs.
    static let cupLeagues: [String: String] = [
        "soccer/uefa.champions": "Champions League", "soccer/uefa.europa": "Europa League",
        "soccer/uefa.europa.conf": "Conference League", "soccer/conmebol.libertadores": "Libertadores",
        "soccer/conmebol.sudamericana": "Sudamericana", "soccer/usa.1": "MLS",
    ]

    private static let titlePhrases = ["super bowl", "world series", "nba finals", "wnba finals", "stanley cup final",
                                       "national championship", "grey cup", "mls cup", "championship game"]
    private static let playoffPhrases = ["playoff", "wild card", "divisional", "conference final", "conference championship",
                                         "semifinal", "quarterfinal", "round of 16", "bowl", "alds", "nlds", "alcs", "nlcs",
                                         "first round", "second round", "elite eight", "elite 8", "sweet 16", "final four", "knockout"]
    private static let rivalryPhrases = ["clasico", "clásico", "derby", "derbi", "superclasico", "superclásico", "rivalry",
                                         "iron bowl", "red river", "egg bowl", "apple cup"]

    static func classify(league: String?, seasonSlug: String?, seasonType: Int?, notes: [String]) -> GameEntry.Stage? {
        let text = notes.joined(separator: " · ")
        let lower = text.lowercased()
        let slug = (seasonSlug ?? "").lowercased()
        let league = league ?? ""
        let note = notes.first { !$0.isEmpty }

        if lower.contains("all-star") || lower.contains("all star") {
            return .init(kind: .allStar, label: note ?? "All-Star Game")
        }
        if titlePhrases.contains(where: { lower.contains($0) }) && !lower.contains("semifinal") && !lower.contains("quarterfinal") {
            return .init(kind: .championship, label: tidy(note ?? text))
        }
        let cupName = cupLeagues[league] ?? tournamentLeagues[league] ?? qualifierLeagues[league]
        // Qualifying playoffs come as "playoff-semifinals", "playoff-final".
        if slug.hasPrefix("playoff-") {
            let round = String(slug.dropFirst("playoff-".count))
            let name = round == "final" ? "Playoff final" : "Playoff " + roundName(round).lowercased()
            return .init(kind: .playoff, label: [cupName, name].compactMap { $0 }.joined(separator: " · "))
        }
        if slug == "final" || slug == "mls-cup" {
            return .init(kind: .championship, label: slug == "mls-cup" ? "MLS Cup" : "\(cupName ?? "Cup") Final")
        }
        if ["semifinals", "quarterfinals", "round-of-16", "round-of-32", "knockout-round-playoffs", "playoffs",
            "third-place", "3rd-place"].contains(slug) {
            return .init(kind: .playoff, label: [cupName, roundName(slug)].compactMap { $0 }.joined(separator: " · "))
        }
        if seasonType == 3 || slug == "post-season" || playoffPhrases.contains(where: { lower.contains($0) }) {
            return .init(kind: .playoff, label: tidy(note ?? "Playoffs"))
        }
        if let name = tournamentLeagues[league] {
            return .init(kind: .tournament, label: slug == "group-stage" ? "\(name) · Group stage" : name)
        }
        let folded = lower.folding(options: .diacriticInsensitive, locale: nil)
        if rivalryPhrases.contains(where: { folded.contains($0) }) {
            return .init(kind: .rivalry, label: tidy(note ?? text))
        }
        return nil
    }

    /// For games with no schedule data: classify from the label the fan or the sample gave them.
    static func classify(_ game: GameEntry) -> GameEntry.Stage? {
        if let stage = game.stage { return stage }
        guard let label = game.competition, !label.isEmpty else { return nil }
        return classify(league: game.source?.league, seasonSlug: nil, seasonType: nil, notes: [label])
    }

    private static func roundName(_ slug: String) -> String {
        switch slug {
        case "semifinals": "Semifinal"
        case "quarterfinals": "Quarterfinal"
        case "round-of-16": "Round of 16"
        case "round-of-32": "Round of 32"
        case "third-place", "3rd-place": "Third place"
        default: "Knockout round"
        }
    }

    /// Drops sponsor tails ("… Presented by AT&T") and normalizes "GAME 5" to "Game 5".
    static func tidy(_ s: String) -> String {
        var out = s
        if let r = out.range(of: " presented by", options: .caseInsensitive) { out = String(out[..<r.lowerBound]) }
        out = out.replacingOccurrences(of: " - ", with: " · ")
        out = out.replacingOccurrences(of: "GAME ", with: "Game ")
        return out.trimmingCharacters(in: .whitespaces)
    }
}

extension GameEntry {
    /// The big-game stage, from the schedule or the game's label.
    var bigGame: Stage? { BigGame.classify(self) }
}
