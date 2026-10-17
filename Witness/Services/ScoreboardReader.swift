import Foundation
import UIKit

/// What text recognition saw in a photo: words and numbers, in reading order.
struct ScoreboardReading: Hashable {
    let tokens: [String]

    var words: Set<String> { Set(tokens.filter { Int($0) == nil }) }
    var numbers: [Int] { tokens.compactMap { Int($0) } }
}

/// Reads scoreboards and jumbotrons in the fan's photos and checks them against real game stats.
/// Everything runs on the phone (Vision text recognition).
enum ScoreboardReader {
    /// Splits recognized text into uppercase word and number tokens ("CHC 3 CLE 2" -> ["CHC","3","CLE","2"]).
    static func reading(from text: String) -> ScoreboardReading {
        let folded = text.folding(options: [.diacriticInsensitive], locale: nil).uppercased()
        var tokens: [String] = []
        var current = ""
        func flush() { if !current.isEmpty { tokens.append(current); current = "" } }
        for ch in folded {
            if ch.isLetter || ch.isNumber {
                // A letter-digit boundary splits too: "CHC3" reads as CHC, 3.
                if let last = current.last, last.isNumber != ch.isNumber { flush() }
                current.append(ch)
            } else {
                flush()
            }
        }
        flush()
        return ScoreboardReading(tokens: tokens)
    }

    /// The scores a reading shows for a game's two teams: the first number within three tokens after each team's
    /// code or name. Nil unless both teams are on the board.
    static func scores(in reading: ScoreboardReading, home: FoundGame.Side, away: FoundGame.Side) -> (home: Int?, away: Int?)? {
        let homeAt = position(of: home, in: reading.tokens)
        let awayAt = position(of: away, in: reading.tokens)
        guard let h = homeAt, let a = awayAt else { return nil }
        return (number(after: h, in: reading.tokens), number(after: a, in: reading.tokens))
    }

    /// How strongly a reading supports a game: 0 none, 1 both teams on the board, 2 teams and the final score.
    static func support(_ reading: ScoreboardReading, for game: FoundGame) -> Int {
        guard let s = scores(in: reading, home: game.home, away: game.away) else { return 0 }
        if let hs = s.home, let aw = s.away, hs == game.home.score, aw == game.away.score { return 2 }
        // A board read mid-game: scores no higher than the final still fit.
        if let hs = s.home, let aw = s.away, let fh = game.home.score, let fa = game.away.score, hs <= fh, aw <= fa { return 1 }
        return s.home == nil && s.away == nil ? 1 : 0
    }

    // MARK: Reading photos

    /// Text-recognizes up to `limit` photos, newest first, keeping only readings that look like a board
    /// (at least one short word and one number).
    static func read(_ refs: [PhotoRef], limit: Int = 8) async -> [ScoreboardReading] {
        var out: [ScoreboardReading] = []
        for ref in refs.suffix(limit).reversed() {
            guard let image = await PhotoLoader.load(ref, size: CGSize(width: 1600, height: 1600)),
                  let text = try? await TextRecognizer.text(in: image) else { continue }
            let r = reading(from: text)
            if !r.numbers.isEmpty, r.tokens.contains(where: { $0.count <= 4 && Int($0) == nil }) { out.append(r) }
        }
        return out
    }

    /// Finds the game a scoreboard shows when we don't know the stadium: checks the schedules around the photos'
    /// times for a game whose two teams are both on the board, preferring one whose score matches too.
    static func findGame(around times: [Date], boards: [ScoreboardReading],
                         leagues: [String] = commonLeagues) async -> FoundGame? {
        guard !boards.isEmpty, let first = times.min(), let last = times.max() else { return nil }
        // A game starts up to ~5 h before a photo of its final; schedules are keyed by US dates, so a window
        // (not a calendar day) avoids missing late games that cross midnight UTC.
        let from = first.addingTimeInterval(-6 * 3600), to = last.addingTimeInterval(3600)
        var candidates: [FoundGame] = []
        await withTaskGroup(of: [FoundGame].self) { group in
            for league in leagues {
                group.addTask { await GameLookup.schedule(league: league, from: from, to: to) }
            }
            for await games in group { candidates += games }
        }
        let scored = candidates.filter { $0.start >= from && $0.start <= to }
            .map { game in (game, boards.map { support($0, for: game) }.max() ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        return scored.first?.0
    }

    static let commonLeagues = [
        "baseball/mlb", "football/nfl", "basketball/nba", "hockey/nhl", "soccer/usa.1", "basketball/wnba",
        "football/college-football", "basketball/mens-college-basketball", "football/cfl", "soccer/eng.1",
        "soccer/esp.1", "soccer/ger.1", "soccer/ita.1", "soccer/fra.1", "soccer/uefa.champions", "soccer/mex.1",
    ]

    // MARK: Helpers

    private static func position(of side: FoundGame.Side, in tokens: [String]) -> Int? {
        let code = side.abbreviation.uppercased()
        let names = [side.location, side.name].map { $0.folding(options: .diacriticInsensitive, locale: nil).uppercased() }
            .flatMap { $0.split(separator: " ").map(String.init) }
            .filter { $0.count >= 4 }
        if let i = tokens.firstIndex(of: code) { return i }
        return tokens.firstIndex { names.contains($0) }
    }

    private static func number(after index: Int, in tokens: [String]) -> Int? {
        for t in tokens.dropFirst(index + 1).prefix(3) {
            if let n = Int(t), n < 200 { return n }
        }
        return nil
    }
}
