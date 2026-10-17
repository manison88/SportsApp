import Foundation
import CoreLocation

// Codable models shaped like the future real sources. Field names follow the
// upstream APIs where one exists (see README "Data mapping"), so swapping the
// JSON loader for a network client is a decoder change, not a UI change.

// MARK: - Sport

enum Sport: String, Codable, CaseIterable, Hashable {
    case baseball, football, basketball, hockey, soccer, motorsport

    var displayName: String {
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

    /// Noun for a unit of scoring, used in lifetime stats.
    var scoringNoun: String {
        switch self {
        case .baseball: "runs"
        case .football, .basketball: "points"
        case .hockey, .soccer: "goals"
        case .motorsport: "laps"
        }
    }

    /// How a "the moment it ended" phrase reads for this sport.
    var finalPhrase: String {
        switch self {
        case .baseball: "the final out"
        case .football, .soccer: "the final whistle"
        case .basketball: "the final buzzer"
        case .hockey: "the final horn"
        case .motorsport: "the chequered flag"
        }
    }
}

// MARK: - Team  (MLB /teams, NHL, TheSportsDB lookupteam, Jolpica /constructors)

struct Team: Codable, Identifiable, Hashable {
    let id: String
    let sport: Sport
    let league: String
    let abbreviation: String
    let locationName: String
    let teamName: String
    /// Typographic monogram drawn instead of any logo.
    let monogram: String
    let colors: TeamColors
    let externalIds: ExternalIDs

    /// What the UI shows. City names only, never marks.
    var displayName: String { locationName }
}

struct TeamColors: Codable, Hashable {
    let primary: String
    let secondary: String
    let accent: String
}

struct ExternalIDs: Codable, Hashable {
    var mlbStatsApi: Int? = nil
    var nhlTriCode: String? = nil
    var theSportsDb: String? = nil
    var jolpicaConstructorId: String? = nil
    var jolpicaCircuitId: String? = nil
    var statsBombTeamId: Int? = nil
    var statsBombStadiumId: Int? = nil
}

// MARK: - Venue  (MLB /venues, TheSportsDB lookupvenue)

struct Venue: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let region: String?
    let country: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let elevationMeters: Double?
    let capacity: Int?
    let opened: Int?
    let sports: [Sport]
    let timeZone: String
    let externalIds: ExternalIDs

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    var tz: TimeZone { TimeZone(identifier: timeZone) ?? .current }
    var cityLine: String { [city, region ?? country].joined(separator: ", ") }
}

// MARK: - Game

struct Game: Codable, Identifiable, Hashable {
    let id: String
    let sport: Sport
    let league: String
    let season: String
    let competition: String?
    let startTime: Date
    let endTime: Date
    let venueId: String
    let home: Competitor?
    let away: Competitor?
    let race: RaceResult?
    let statusDetail: String
    let attendance: Int?
    let headline: String
    let provenance: Provenance
    let isIndoor: Bool
    let periods: [PeriodMarker]
    let events: [GameEvent]
    /// MLB /game/{pk}/winProbability shape: percent 0...100 for the home team.
    let winProbability: [WinProbabilityPoint]
    /// Open-Meteo historical archive, hour of first pitch.
    let weather: WeatherSnapshot?
    let memory: Memory
    let source: SourceRef

    var isDraw: Bool { (home?.score ?? 0) == (away?.score ?? 0) && race == nil }
    var homeWon: Bool { (home?.score ?? 0) > (away?.score ?? 0) }
    var duration: TimeInterval { endTime.timeIntervalSince(startTime) }
    var keyMoments: [GameEvent] { events.filter(\.isKeyMoment) }
}

enum Provenance: String, Codable, Hashable {
    /// Real date, venue and final score.
    case verified
    /// Plausible filler for the persona.
    case illustrative
}

struct Competitor: Codable, Hashable {
    let teamId: String
    let score: Int
}

/// Jolpica-F1 /{season}/{round}/results shape, trimmed to the podium.
struct RaceResult: Codable, Hashable {
    let raceName: String
    let round: Int
    let laps: Int
    let results: [RaceResultRow]
}

struct RaceResultRow: Codable, Hashable {
    let position: Int
    let driverCode: String
    let driverName: String
    let constructorId: String
    let time: String?
}

struct PeriodMarker: Codable, Hashable {
    let label: String
    let timestamp: Date
}

/// One play-by-play event. Mirrors MLB allPlays[].about / result, NHL plays[],
/// StatsBomb events. `shortLabel` and `phrase` are app-side enrichment.
struct GameEvent: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case start, score, moment, final }

    let id: String
    let timestamp: Date
    let period: String
    let clock: String?
    let kind: Kind
    let teamId: String?
    let description: String
    let shortLabel: String
    /// Reads naturally after "taken 40 seconds after …".
    let phrase: String
    let homeScore: Int
    let awayScore: Int
    let isKeyMoment: Bool
}

struct WinProbabilityPoint: Codable, Hashable {
    let timestamp: Date
    let atBatIndex: Int
    /// Percent, 0...100.
    let homeTeamWinProbability: Double
}

/// Open-Meteo archive API, hourly variables, imperial units.
struct WeatherSnapshot: Codable, Hashable {
    let time: Date
    let temperature2m: Double
    let apparentTemperature: Double
    /// WMO weather interpretation code.
    let weatherCode: Int
    let windSpeed10m: Double
    let relativeHumidity2m: Int
    let precipitation: Double

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
        case relativeHumidity2m = "relative_humidity_2m"
        case precipitation
    }

    var condition: String {
        switch weatherCode {
        case 0: "Clear"
        case 1: "Mostly clear"
        case 2: "Partly cloudy"
        case 3: "Overcast"
        case 45, 48: "Fog"
        case 51...57: "Drizzle"
        case 61...67: "Rain"
        case 71...77: "Snow"
        case 80...82: "Showers"
        case 95...99: "Storms"
        default: "—"
        }
    }

    var symbol: String {
        switch weatherCode {
        case 0: "moon.stars.fill"
        case 1: "cloud.moon.fill"
        case 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...67: "cloud.rain.fill"
        case 71...77: "cloud.snow.fill"
        case 80...82: "cloud.heavyrain.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "thermometer.medium"
        }
    }

    var temperatureText: String { "\(Int(temperature2m.rounded()))°" }
}

/// The fan's own layer on top of the game. App-owned, never from an API.
struct Memory: Codable, Hashable {
    let companionIds: [String]
    let note: String?
    let seat: String?
    let photoIds: [String]
    let rating: Int?
    let tripId: String?
}

struct SourceRef: Codable, Hashable {
    let provider: String
    let externalId: String
    let endpoint: String
}

// MARK: - Photo  (PhotoKit PHAsset metadata)

struct PhotoAsset: Codable, Identifiable, Hashable {
    let localIdentifier: String
    let creationDate: Date
    let location: PhotoLocation?
    let pixelWidth: Int
    let pixelHeight: Int
    let mediaType: String
    let mediaSubtypes: [String]
    let isFavorite: Bool
    /// Stands in for the real image until PhotoKit is wired up.
    let placeholder: PhotoPlaceholder

    var id: String { localIdentifier }
    var aspectRatio: CGFloat { CGFloat(pixelWidth) / CGFloat(max(pixelHeight, 1)) }
    var isLivePhoto: Bool { mediaSubtypes.contains("photoLive") }
}

struct PhotoLocation: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
}

struct PhotoPlaceholder: Codable, Hashable {
    let style: PhotoStyle
    let seed: UInt64
}

enum PhotoStyle: String, Codable, CaseIterable, Hashable {
    case diamond, nightField, dayGame, lightTower, crowd, celebration, scoreboard
    case concourse, snowGame, arena, pitch, skyline, trackside
}

// MARK: - People, trips, profile (app-owned)

struct Person: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let relation: String
    let initials: String
    let colorHex: String
    let birthYear: Int?
}

struct Trip: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let gameIds: [String]
    let startDate: Date
    let endDate: Date
    let stops: [TripStop]
}

struct TripStop: Codable, Hashable {
    enum Kind: String, Codable { case depart, city, game, `return` }
    let city: String
    let latitude: Double
    let longitude: Double
    let date: Date
    let kind: Kind
    let venueId: String?

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

struct Profile: Codable, Hashable {
    let id: String
    let displayName: String
    let homeCity: String
    let homeNeighborhood: String
    let homeLatitude: Double
    let homeLongitude: Double
    let memberSince: Date
    let favoriteTeamIds: [String]

    var homeCoordinate: CLLocationCoordinate2D { .init(latitude: homeLatitude, longitude: homeLongitude) }
    var homeLocation: CLLocation { CLLocation(latitude: homeLatitude, longitude: homeLongitude) }
}
