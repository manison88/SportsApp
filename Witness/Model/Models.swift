import Foundation
import CoreLocation
import SwiftUI

// MARK: - Sport

enum Sport: String, Codable, CaseIterable, Identifiable, Hashable {
    case baseball, football, basketball, hockey, soccer, motorsport

    var id: String { rawValue }

    var name: String {
        switch self {
        case .baseball: "Baseball"
        case .football: "Football"
        case .basketball: "Basketball"
        case .hockey: "Hockey"
        case .soccer: "Soccer"
        case .motorsport: "Motorsport"
        }
    }

    var symbol: String {
        switch self {
        case .baseball: "baseball.fill"
        case .football: "football.fill"
        case .basketball: "basketball.fill"
        case .hockey: "hockey.puck.fill"
        case .soccer: "soccerball"
        case .motorsport: "flag.checkered"
        }
    }

    /// What a unit of scoring is called.
    var scoringNoun: String {
        switch self {
        case .baseball: "runs"
        case .football, .basketball: "points"
        case .hockey, .soccer: "goals"
        case .motorsport: "laps"
        }
    }

    /// Column labels for a line score.
    var periodLabels: [String] {
        switch self {
        case .baseball: (1...9).map(String.init)
        case .football, .basketball: ["1", "2", "3", "4"]
        case .hockey: ["1", "2", "3"]
        case .soccer: ["1H", "2H"]
        case .motorsport: []
        }
    }
}

// MARK: - Team

struct Team: Codable, Hashable, Identifiable {
    struct Colors: Codable, Hashable { var primary: String; var secondary: String; var accent: String }
    struct ExternalIds: Codable, Hashable { var mlbStatsApi: Int?; var theSportsDb: String? }

    let id: String
    let sport: Sport
    let league: String
    let abbreviation: String
    let locationName: String
    let teamName: String
    let monogram: String
    let colors: Colors
    var externalIds: ExternalIds?

    /// UI shows city names and codes only, never marks or nicknames.
    var displayName: String { locationName }
    var accent: Color { Color(hex: colors.accent) }
    var primary: Color { Color(hex: colors.primary) }
}

// MARK: - Venue

struct Venue: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var city: String
    var region: String?
    var country: String
    var countryCode: String
    var latitude: Double
    var longitude: Double
    var sports: [Sport]
    var timeZone: String
    var capacity: Int?
    var opened: Int?
    /// Set for venues the user created or found through Apple Maps.
    var isCustom: Bool?

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    var tz: TimeZone { TimeZone(identifier: timeZone) ?? .current }
    var cityLine: String { [city, region ?? country].filter { !$0.isEmpty }.joined(separator: ", ") }
}

/// One of the 30 MLB ballparks, for the passport. `venueId` links to a catalog venue.
struct Ballpark: Codable, Hashable, Identifiable {
    let code: String
    let name: String
    let city: String
    let latitude: Double
    let longitude: Double
    let venueId: String
    var id: String { venueId }
}

// MARK: - People

struct Person: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var relation: String
    var initials: String
    var colorHex: String
    var color: Color { Color(hex: colorHex) }
}

struct Profile: Codable, Hashable {
    var displayName: String
    var homeCity: String
    var homeLatitude: Double
    var homeLongitude: Double
    var favoriteTeamIds: [String]
    var homeLocation: CLLocation { CLLocation(latitude: homeLatitude, longitude: homeLongitude) }
}

struct Trip: Codable, Hashable, Identifiable {
    struct Stop: Codable, Hashable {
        enum Kind: String, Codable { case depart, city, game, `return` }
        var city: String
        var latitude: Double
        var longitude: Double
        var date: Date
        var kind: Kind
        var venueId: String?
    }
    let id: String
    var title: String
    var gameIds: [String]
    var startDate: Date
    var endDate: Date
    var stops: [Stop]
}

// MARK: - Game

enum PhotoRef: Codable, Hashable {
    /// An image in the app's asset catalog (sample library).
    case bundled(String)
    /// A PhotoKit asset, by local identifier. Never copied out of the library.
    case library(String)
    /// A file the user imported (ticket scan), stored in the app's documents.
    case file(String)
}

struct Play: Codable, Hashable, Identifiable {
    var id: String
    var time: Date
    var period: String
    var text: String
    var homeScore: Int
    var awayScore: Int
    var isKey: Bool
}

struct ProbPoint: Codable, Hashable {
    var time: Date
    /// Home team win probability, 0...1.
    var home: Double
}

struct Weather: Codable, Hashable {
    var temperatureF: Double
    var condition: String
    var symbol: String
}

struct GameEntry: Codable, Hashable, Identifiable {
    enum Origin: String, Codable { case sample, manual, ticket, photos, live }

    var id: String = UUID().uuidString
    var sport: Sport
    var date: Date
    var venueId: String
    var homeTeamId: String?
    var awayTeamId: String?
    var homeScore: Int?
    var awayScore: Int?
    /// Which side the fan was there for. Defaults to a favorite team, else home.
    var rootingForTeamId: String?
    var competition: String?
    var headline: String?
    var seat: String?
    var companionIds: [String] = []
    var note: String?
    var photos: [PhotoRef] = []
    var origin: Origin
    var tripId: String?
    var weather: Weather?
    var attendance: Int?
    var plays: [Play] = []
    var winProbability: [ProbPoint] = []
    /// Runs/goals/points per period, home and away.
    var lineHome: [Int] = []
    var lineAway: [Int] = []
    /// Times the fan tapped "Save this moment" during a live check-in.
    var savedMoments: [Date] = []
    /// Motorsport podium, e.g. ["P1 VER", "P2 HAM"].
    var podium: [String] = []

    var hasScore: Bool { homeScore != nil && awayScore != nil }
    var isDraw: Bool { hasScore && homeScore == awayScore }
}

enum Outcome: String { case win = "W", loss = "L", draw = "D", none = "–" }
