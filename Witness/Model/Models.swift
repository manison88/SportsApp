import Foundation
import CoreLocation
import SwiftUI

// MARK: - Sport

enum Sport: String, Codable, CaseIterable, Identifiable, Hashable {
    case baseball, football, basketball, hockey, soccer, motorsport, handball

    var id: String { rawValue }

    var name: String {
        switch self {
        case .baseball: "Baseball"
        case .football: "Football"
        case .basketball: "Basketball"
        case .hockey: "Hockey"
        case .soccer: "Soccer"
        case .motorsport: "Motorsport"
        case .handball: "Handball"
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
        case .handball: "figure.handball"
        }
    }

    /// What a unit of scoring is called.
    var scoringNoun: String {
        switch self {
        case .baseball: "runs"
        case .football, .basketball: "points"
        case .hockey, .soccer, .handball: "goals"
        case .motorsport: "laps"
        }
    }

    /// Column labels for a line score.
    var periodLabels: [String] {
        switch self {
        case .baseball: (1...9).map(String.init)
        case .football, .basketball: ["1", "2", "3", "4"]
        case .hockey: ["1", "2", "3"]
        case .soccer, .handball: ["1H", "2H"]
        case .motorsport: []
        }
    }
}

// MARK: - Team

struct Team: Codable, Hashable, Identifiable {
    struct Colors: Codable, Hashable { var primary: String; var secondary: String; var accent: String }
    struct ExternalIds: Codable, Hashable { var mlbStatsApi: Int?; var theSportsDb: String?; var espn: String?; var espnLeague: String? }

    let id: String
    let sport: Sport
    let league: String
    let abbreviation: String
    let locationName: String
    let teamName: String
    let monogram: String
    let colors: Colors
    var externalIds: ExternalIds?
    /// The league path teams are matched on ("baseball/mlb"), with `externalIds.espn`.
    var leagueKey: String? = nil
    var countryCode: String? = nil
    /// The ground the team calls home, a catalog venue id.
    var homeVenueId: String? = nil
    /// Earlier names of the club (Cleveland Indians, Seattle SuperSonics), so searching the old name still finds it.
    var formerNames: [String]? = nil

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
    /// The year the ground stopped hosting games, for demolished or replaced stadiums. Nil while it is in use.
    var closed: Int? = nil
    /// Set for venues the user created or found through Apple Maps.
    var isCustom: Bool?
    /// Other names the venue goes by (former sponsors, local language), for matching schedules and tickets.
    var aliases: [String]?
    /// ESPN league paths with home games here, e.g. "football/nfl", "soccer/esp.1".
    var leagues: [String]?
    /// Current primary tenants, full names.
    var homeTeams: [String]?
    /// Set for circuits and other grounds where the default 200 m would miss the grandstands.
    var geofenceMeters: Double?

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    /// An arena: only indoor sports are played here. Domed stadiums count as outdoors, which is only a second opinion.
    var isIndoor: Bool { !sports.isEmpty && sports.allSatisfy { [.basketball, .hockey, .handball].contains($0) } }

    /// How far from the venue's center a photo can be and still count as inside: 200 m, a little more for the
    /// biggest bowls so their upper decks count (Michigan Stadium is ~300 m across). Tight enough to leave out
    /// the bar across the street.
    var geofence: Double {
        if let geofenceMeters { return geofenceMeters }
        switch capacity ?? 0 {
        case 90_000...: return 300
        case 65_000..<90_000: return 260
        default: return 200
        }
    }
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
    /// The real event this game was matched to, when it was verified against a schedule.
    var source: Source?
    /// Set for big games: finals, playoffs, tournaments, rivalries.
    var stage: Stage?
    /// The photo that heads this game on the Timeline and its own screen. The fan's pick, else chosen automatically.
    var coverPhoto: PhotoRef?
    /// True when the fan chose the cover, so automatic picking never replaces it.
    var coverChosenByFan: Bool?
    /// `.visit` for a stadium tour or a walk past the ground: photos at the venue, no game that day.
    var kind: Kind?
    /// A planned game: the fan asked for a game-day reminder.
    var planReminder: Bool?
    /// A planned game: add the photos from the game's day, time and stadium by themselves (on unless the fan turns it off).
    var planAutoPhotos: Bool?
    /// While this is in the future, the background game-day check keeps adding photos and videos from the stadium.
    var autoPhotosUntil: Date?
    /// True once videos from the stadium and game time have been looked for.
    var videosChecked: Bool?

    enum Kind: String, Codable { case visit }
    var isVisit: Bool { kind == .visit }

    /// The photo that heads the game: the cover, else the first photo.
    var heroPhoto: PhotoRef? { coverPhoto ?? photos.first }

    struct Stage: Codable, Hashable {
        enum Kind: String, Codable, Comparable {
            case championship, playoff, tournament, rivalry, allStar

            static func < (a: Kind, b: Kind) -> Bool { a.rank < b.rank }
            private var rank: Int {
                switch self {
                case .championship: 0
                case .playoff: 1
                case .tournament: 2
                case .rivalry: 3
                case .allStar: 4
                }
            }
        }
        var kind: Kind
        /// What the fan reads, e.g. "Super Bowl LIX", "Champions League · Semifinal".
        var label: String
    }

    struct Source: Codable, Hashable {
        var provider: String      // "espn"
        var league: String        // "football/nfl"
        var eventId: String
    }

    var hasScore: Bool { homeScore != nil && awayScore != nil }
    var isDraw: Bool { hasScore && homeScore == awayScore }
}

enum Outcome: String { case win = "W", loss = "L", draw = "D", none = "–" }

/// Two-letter country codes to the three-letter ones fans know (US to USA, BA to BIH).
enum CountryCodes {
    static func iso3(_ iso2: String) -> String? { table[iso2.uppercased()] }

    private static let table: [String: String] = ["AD": "AND", "AE": "ARE", "AF": "AFG", "AG": "ATG", "AI": "AIA", "AL": "ALB", "AM": "ARM", "AO": "AGO", "AQ": "ATA", "AR": "ARG", "AS": "ASM", "AT": "AUT", "AU": "AUS", "AW": "ABW", "AX": "ALA", "AZ": "AZE", "BA": "BIH", "BB": "BRB", "BD": "BGD", "BE": "BEL", "BF": "BFA", "BG": "BGR", "BH": "BHR", "BI": "BDI", "BJ": "BEN", "BL": "BLM", "BM": "BMU", "BN": "BRN", "BO": "BOL", "BQ": "BES", "BR": "BRA", "BS": "BHS", "BT": "BTN", "BV": "BVT", "BW": "BWA", "BY": "BLR", "BZ": "BLZ", "CA": "CAN", "CC": "CCK", "CD": "COD", "CF": "CAF", "CG": "COG", "CH": "CHE", "CI": "CIV", "CK": "COK", "CL": "CHL", "CM": "CMR", "CN": "CHN", "CO": "COL", "CR": "CRI", "CU": "CUB", "CV": "CPV", "CW": "CUW", "CX": "CXR", "CY": "CYP", "CZ": "CZE", "DE": "DEU", "DJ": "DJI", "DK": "DNK", "DM": "DMA", "DO": "DOM", "DZ": "DZA", "EC": "ECU", "EE": "EST", "EG": "EGY", "EH": "ESH", "ER": "ERI", "ES": "ESP", "ET": "ETH", "FI": "FIN", "FJ": "FJI", "FK": "FLK", "FM": "FSM", "FO": "FRO", "FR": "FRA", "GA": "GAB", "GB": "GBR", "GD": "GRD", "GE": "GEO", "GF": "GUF", "GG": "GGY", "GH": "GHA", "GI": "GIB", "GL": "GRL", "GM": "GMB", "GN": "GIN", "GP": "GLP", "GQ": "GNQ", "GR": "GRC", "GS": "SGS", "GT": "GTM", "GU": "GUM", "GW": "GNB", "GY": "GUY", "HK": "HKG", "HM": "HMD", "HN": "HND", "HR": "HRV", "HT": "HTI", "HU": "HUN", "ID": "IDN", "IE": "IRL", "IL": "ISR", "IM": "IMN", "IN": "IND", "IO": "IOT", "IQ": "IRQ", "IR": "IRN", "IS": "ISL", "IT": "ITA", "JE": "JEY", "JM": "JAM", "JO": "JOR", "JP": "JPN", "KE": "KEN", "KG": "KGZ", "KH": "KHM", "KI": "KIR", "KM": "COM", "KN": "KNA", "KP": "PRK", "KR": "KOR", "KW": "KWT", "KY": "CYM", "KZ": "KAZ", "LA": "LAO", "LB": "LBN", "LC": "LCA", "LI": "LIE", "LK": "LKA", "LR": "LBR", "LS": "LSO", "LT": "LTU", "LU": "LUX", "LV": "LVA", "LY": "LBY", "MA": "MAR", "MC": "MCO", "MD": "MDA", "ME": "MNE", "MF": "MAF", "MG": "MDG", "MH": "MHL", "MK": "MKD", "ML": "MLI", "MM": "MMR", "MN": "MNG", "MO": "MAC", "MP": "MNP", "MQ": "MTQ", "MR": "MRT", "MS": "MSR", "MT": "MLT", "MU": "MUS", "MV": "MDV", "MW": "MWI", "MX": "MEX", "MY": "MYS", "MZ": "MOZ", "NA": "NAM", "NC": "NCL", "NE": "NER", "NF": "NFK", "NG": "NGA", "NI": "NIC", "NL": "NLD", "NO": "NOR", "NP": "NPL", "NR": "NRU", "NU": "NIU", "NZ": "NZL", "OM": "OMN", "PA": "PAN", "PE": "PER", "PF": "PYF", "PG": "PNG", "PH": "PHL", "PK": "PAK", "PL": "POL", "PM": "SPM", "PN": "PCN", "PR": "PRI", "PS": "PSE", "PT": "PRT", "PW": "PLW", "PY": "PRY", "QA": "QAT", "RE": "REU", "RO": "ROU", "RS": "SRB", "RU": "RUS", "RW": "RWA", "SA": "SAU", "SB": "SLB", "SC": "SYC", "SD": "SDN", "SE": "SWE", "SG": "SGP", "SH": "SHN", "SI": "SVN", "SJ": "SJM", "SK": "SVK", "SL": "SLE", "SM": "SMR", "SN": "SEN", "SO": "SOM", "SR": "SUR", "SS": "SSD", "ST": "STP", "SV": "SLV", "SX": "SXM", "SY": "SYR", "SZ": "SWZ", "TC": "TCA", "TD": "TCD", "TF": "ATF", "TG": "TGO", "TH": "THA", "TJ": "TJK", "TK": "TKL", "TL": "TLS", "TM": "TKM", "TN": "TUN", "TO": "TON", "TR": "TUR", "TT": "TTO", "TV": "TUV", "TW": "TWN", "TZ": "TZA", "UA": "UKR", "UG": "UGA", "UM": "UMI", "US": "USA", "UY": "URY", "UZ": "UZB", "VA": "VAT", "VC": "VCT", "VE": "VEN", "VG": "VGB", "VI": "VIR", "VN": "VNM", "VU": "VUT", "WF": "WLF", "WS": "WSM", "XK": "KOS", "YE": "YEM", "YT": "MYT", "ZA": "ZAF", "ZM": "ZMB", "ZW": "ZWE"]
}
