import Foundation

/// The weather at a stadium at the hour a game started: 7 PM kickoff, 7 PM temperature.
/// Open-Meteo (free, no key) answers for a latitude, longitude and day. Only the stadium's public location is sent, never
/// anything about the fan or their photos.
enum WeatherLookup {
    /// Temperature and sky at the venue at the hour of `date`. Nil for indoor venues, games that have not started,
    /// or when the service cannot be reached (the caller tries again another time).
    static func at(venue: Venue, date: Date, now: Date = .now) async -> Weather? {
        guard !venue.likelyIndoor, date < now else { return nil }
        return await fetch(venue: venue, date: date, now: now)
    }

    /// How far ahead the forecast service answers.
    static let forecastDays = 15

    /// The forecast for a planned game, indoors or out (the trip there is outside), once it is within the forecast's reach.
    static func forecast(venue: Venue, date: Date, now: Date = .now) async -> Weather? {
        guard inForecastRange(date, now: now) else { return nil }
        let key = "\(venue.id)|\(Int(date.timeIntervalSince1970))" as NSString
        if let hit = forecastCache.object(forKey: key), now.timeIntervalSince(hit.fetched) < 3600 { return hit.weather }
        guard let weather = await fetch(venue: venue, date: date, now: now) else { return nil }
        forecastCache.setObject(Cached(weather: weather, fetched: now), forKey: key)
        return weather
    }

    /// A forecast fetched in the last hour, without waiting: the plan page shows it at once when the schedule row already asked.
    static func cachedForecast(venue: Venue, date: Date, now: Date = .now) -> Weather? {
        let key = "\(venue.id)|\(Int(date.timeIntervalSince1970))" as NSString
        guard let hit = forecastCache.object(forKey: key), now.timeIntervalSince(hit.fetched) < 3600 else { return nil }
        return hit.weather
    }

    static func inForecastRange(_ date: Date, now: Date = .now) -> Bool {
        date > now.addingTimeInterval(-6 * 3600) && date.timeIntervalSince(now) < Double(forecastDays) * 86_400
    }

    private final class Cached: @unchecked Sendable {
        let weather: Weather, fetched: Date
        init(weather: Weather, fetched: Date) { self.weather = weather; self.fetched = fetched }
    }
    nonisolated(unsafe) private static let forecastCache = NSCache<NSString, Cached>()

    private static func fetch(venue: Venue, date: Date, now: Date) async -> Weather? {
        guard let url = requestURL(latitude: venue.latitude, longitude: venue.longitude, date: date, now: now) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return parse(data, at: date, venueTimeZone: venue.tz)
    }

    /// The archive covers finished days; the forecast service also answers for the last few weeks, which the archive lags.
    static func requestURL(latitude: Double, longitude: Double, date: Date, now: Date) -> URL? {
        let recent = now.timeIntervalSince(date) < 8 * 86_400
        var components = URLComponents(string: recent ? "https://api.open-meteo.com/v1/forecast"
                                                      : "https://archive-api.open-meteo.com/v1/archive")
        let first = utcDay(date.addingTimeInterval(-3600)), last = utcDay(date.addingTimeInterval(3600))
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "start_date", value: first),
            URLQueryItem(name: "end_date", value: last),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: "GMT"),
        ]
        return components?.url
    }

    /// The hourly reading nearest the start time (a 7:40 PM start reads the 8 PM hour).
    static func parse(_ data: Data, at date: Date, venueTimeZone: TimeZone) -> Weather? {
        struct Response: Decodable {
            struct Hourly: Decodable {
                let time: [String]
                let temperature_2m: [Double?]
                let weather_code: [Int?]
            }
            let hourly: Hourly
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else { return nil }
        let hour = utcHour(Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 3600).rounded() * 3600))
        guard let i = response.hourly.time.firstIndex(of: hour),
              i < response.hourly.temperature_2m.count, let temperature = response.hourly.temperature_2m[i] else { return nil }
        let code = i < response.hourly.weather_code.count ? (response.hourly.weather_code[i] ?? 0) : 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = venueTimeZone
        let local = calendar.component(.hour, from: date)
        let (condition, symbol) = describe(code: code, night: local >= 20 || local < 6)
        return Weather(temperatureF: (temperature * 10).rounded() / 10, condition: condition, symbol: symbol)
    }

    /// WMO weather codes, in words and an SF Symbol.
    static func describe(code: Int, night: Bool) -> (String, String) {
        switch code {
        case 0: return ("Clear", night ? "moon.stars.fill" : "sun.max.fill")
        case 1, 2: return ("Partly cloudy", night ? "cloud.moon.fill" : "cloud.sun.fill")
        case 3: return ("Overcast", "cloud.fill")
        case 45, 48: return ("Fog", "cloud.fog.fill")
        case 51...67, 80...82: return ("Rain", "cloud.rain.fill")
        case 71...77, 85, 86: return ("Snow", "cloud.snow.fill")
        default: return ("Storms", "cloud.bolt.rain.fill")
        }
    }

    private static func utcFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }

    private static func utcDay(_ date: Date) -> String { utcFormatter("yyyy-MM-dd").string(from: date) }
    private static func utcHour(_ date: Date) -> String { utcFormatter("yyyy-MM-dd'T'HH:00").string(from: date) }
}

extension Weather {
    /// "54°F · Clear", the reading at the game's start time.
    var summary: String { "\(Fmt.temperature(temperatureF)) · \(condition)" }
}

extension Venue {
    /// Arenas and domes: the weather outside says nothing about the game. A guess from the sports played and the name;
    /// retractable roofs count as open.
    var likelyIndoor: Bool {
        let indoorSports: Set<Sport> = [.basketball, .hockey, .handball]
        if !sports.isEmpty, Set(sports).isSubset(of: indoorSports) { return true }
        let n = name.lowercased()
        let fixedRoofs = ["dome", "tropicana field", "u.s. bank stadium", "ford field", "allegiant stadium", "lucas oil",
                          "at&t stadium", "mercedes-benz stadium", "sofi stadium", "rogers centre", "globe life field"]
        return fixedRoofs.contains { n.contains($0) }
    }
}

extension Fmt {
    /// "7:05 PM · 54°F · Clear": the start time in the stadium's time zone and the weather at that hour. The time is
    /// left out when it was only a default typed into a hand-made entry; nil when there is nothing to say.
    static func kickoff(_ game: GameEntry, in tz: TimeZone) -> String? {
        var parts: [String] = []
        if game.source != nil || game.origin != .manual { parts.append(Fmt.time(game.date, in: tz)) }
        if let weather = game.weather { parts.append(weather.summary) }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    /// The day, then the kickoff line when there is one: "Jun 24, 2026 · 7:05 PM · 54°F · Clear".
    static func dayAndKickoff(_ game: GameEntry, in tz: TimeZone) -> String {
        [Fmt.dayTitle(game.date, in: tz), kickoff(game, in: tz)].compactMap { $0 }.joined(separator: " \u{00B7} ")
    }
}
