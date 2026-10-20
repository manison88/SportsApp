import Foundation
import os

/// Every number and word list the photo scan judges by, in one place, so they can change over the air without an App Store
/// release. The built-in `defaults` are today's values; a `settings/scan` pack in the signed manifest (`Tools/packs/scan-settings.json`,
/// built by `build_packs.py`) replaces them when its `version` is newer than the built-in one, after the manifest's Ed25519
/// signature and the pack's SHA-256 have been checked like any other pack (`PackStore`). A pack that fails either check, or
/// that is older than the app's own defaults, changes nothing. Every value is clamped to a sane range (`clamped()`), so a typo
/// in the file cannot turn the scan off or make it place a visit a mile from a ground.
///
/// Pure functions take a `settings:` parameter (tests pass their own); `ScanModel` and the other entry points read `.current`.
///
/// Units are in the names: metres, m/s, minutes, hours, photo counts, shares 0...1. Ranges, applied by `clamped()`:
///   fences and reaches 50–5,000 m (a metro 1–200 km) · speeds 5–120 m/s · counts 1–50 (caps on days/albums 1–1,000; photos in an
///   album 1–100,000) · minutes 1–600 (0–600 where 0 is meaningful) · hours 0–48 · shares 0–1 · capacities 0–500,000 ·
///   lookup attempts 1–10, backoff 0–60 s, timeout 1–120 s · word lists at most 1,000 entries, empty words dropped ·
///   the matchup separator must compile as a regular expression, else the default stays.
struct ScanSettings: Codable, Equatable, Sendable {
    /// Compared with the built-in `defaults.version`: only a newer pack is applied. A pack with no version reads as 0.
    var version = 1

    // MARK: Fences and places

    /// A stadium's fence: how far from its point a photo can be and still be inside. Bigger bowls get more (`Venue.geofence`);
    /// a venue's own `geofenceMeters` (circuits) always wins.
    var fenceMeters: Double = 200
    var fenceBigMeters: Double = 260
    var fenceHugeMeters: Double = 300
    var fenceBigCapacity = 65_000
    var fenceHugeCapacity = 90_000
    /// The smallest lat/lon box a venue is checked against before the true distance (`VenueIndex`), and how much over the
    /// fence the box reaches so flat-earth arithmetic never clips a true distance.
    var indexBoxMeters: Double = 320
    var indexBoxSlack: Double = 1.02
    /// Photos this close to a stadium on a visit's day join the visit (the pub, the walk in); they never start one.
    var matchdayReachMeters: Double = 500
    /// Grounds this close are neighbours: the same photos could belong to either (Lumen Field and T-Mobile Park, 440 m).
    var neighborMeters: Double = 1_000

    // MARK: The move rule (`TransitCheck`)

    /// A fix faster than this is a plane (a car on the motorway does 40 m/s at most).
    var vehicleSpeed: Double = 40
    /// Consecutive located photos at least `movingDistanceMeters` apart within `movingWindowMinutes`, at this speed or more, were on the move.
    var movingSpeed: Double = 20
    var movingDistanceMeters: Double = 1_000
    var movingWindowMinutes: Double = 5

    // MARK: Visits (`VisitGrouping`, `PhotoCluster`)

    /// A visit from library discovery needs its photos spread over this long (a drive-by is one photo).
    var visitStayMinutes: Double = 15
    /// Photos at one venue on consecutive days no more than this apart are one visit (a night game); up to `askGapHours` we ask.
    var overnightGapHours: Double = 6
    var askGapHours: Double = 12
    /// A visit with no game on the schedule is offered as a stadium visit when this many photos inside the fence span this long.
    var dwellPhotos = 3
    var dwellMinutes: Double = 20

    // MARK: Schedule windows (`GameLookup`, `ScanModel`)

    /// A game counts for a visit when it started between this long before the first photo and this long after the last.
    var scheduleBeforeHours: Double = 5
    var scheduleAfterHours: Double = 1
    /// A day around a ground (no photo inside the fence) is a possible game only with a photo from this long before kickoff to this long after.
    var nearbyBeforeHours: Double = 2
    var nearbyAfterHours: Double = 3

    // MARK: Lookups

    /// Schedule requests in flight at once; how many tries each gets, the backoff base (× attempt²) and the request timeout.
    var lookupConcurrency = 6
    var lookupAttempts = 3
    var lookupBackoffMilliseconds = 600
    var lookupTimeoutSeconds: Double = 15
    /// Visits matched against the schedule at once in the first pass.
    var matchBatch = 4

    // MARK: Around a ground (`PhotoMatcher.found`)

    /// How far outside the fence a day of photos can be and still be offered when the schedule had a game there.
    var nearbyReachMeters: Double = 600
    var nearbyPhotos = 3
    /// Days around stadiums looked up per scan, newest first.
    var nearbyMaxDays = 40

    // MARK: Days with no location in one city (`CityDays`)

    var cityGapMinutes: Double = 60
    var cityPhotos = 5
    var citySpanMinutes: Double = 30
    /// The located photos before and after a stretch must be within this of it.
    var cityAnchorHours: Double = 12
    /// One city: every located photo within this of every other, and of each stadium asked.
    var cityMetroMeters: Double = 40_000
    var cityMinCapacity = 10_000
    var cityMaxVenues = 6
    var cityMaxDays = 12
    /// A stretch is left alone when the library has something from this long before it to this long after.
    var citySavedBeforeHours: Double = 4
    var citySavedAfterHours: Double = 2
    /// A game's window: this long before kickoff to this long after.
    var cityBeforeMinutes: Double = 60
    var cityAfterMinutes: Double = 210
    /// Photos looked at per day, and what the look must show: venue photos, their share, photos of the ground itself, and at most this share elsewhere.
    var citySample = 16
    var cityMinVenue = 3
    var cityVenueShare: Double = 0.3
    var cityMinStructure = 2
    var cityElsewhereShare: Double = 0.25

    // MARK: The background search (`GameSuggester`)

    var suggestMinPhotos = 3
    var suggestMaxDays = 150
    var suggestMaxAlbums = 60
    var suggestMaxOffered = 12
    /// A located photo this close to a stadium could be a game whose fix drifted.
    var suggestReachMeters: Double = 2_000
    /// Albums bigger than this are never read (a camera roll, not an outing).
    var albumMaxPhotos = 3_000
    /// An album with this many photos whose middle 80% span more than this many days is a collection, unless its title is about sport.
    var collectionPhotos = 5
    var collectionDays: Double = 60
    /// A day's busiest stretch: up to this long, holding this many photos and this share of the day's, over this many minutes.
    var outingWindowHours: Double = 4
    var outingPhotos = 3
    var outingShare: Double = 0.5
    var outingMinutes: Double = 20
    /// A game fits the stretch when it started between this long before its first photo and this long after its last.
    var outingBeforeHours: Double = 4
    var outingAfterHours: Double = 1
    /// Trips read per search; the smallest ground a trip or the fan's home can point at; how far from the trip's centre.
    var tripMaxCount = 20
    var suggestVenueCapacity = 5_000
    var tripReachMeters: Double = 40_000
    /// The fan's home grounds, for days with no location and no title.
    var homeReachMeters: Double = 50_000
    var homeVenues = 4
    /// Photos looked at to decide whether an untitled album or trip is about sport at all, and what the look must show.
    var sourceLookPhotos = 20
    var sourceLookMinVenue = 2
    var sourceLookMinShare: Double = 0.05
    /// Photos looked at per day of the busiest stretch.
    var dayLookPhotos = 24
    var sportTitleWords = ["game", "games", "match", "matchday", "stadium", "ballpark", "arena", "baseball", "football",
                           "soccer", "hockey", "basketball", "nfl", "nba", "mlb", "nhl", "mls", "playoffs", "season", "tickets"]
    var appAlbums = ["instagram", "whatsapp", "facebook", "messenger", "snapchat", "tiktok", "telegram", "twitter", "pinterest",
                     "reddit", "youtube", "discord", "wechat", "viber", "slack", "gmail", "google photos",
                     "screenshot", "screen recording", "meta ai", "chatgpt", "gemini", "midjourney", "generated", "ai", "saved", "downloads", "imported", "received", "shared", "memes", "meme",
                     "camera roll", "recents", "snapseed", "lightroom", "vsco", "photoshop", "capcut", "inshot", "canva"]

    // MARK: Albums titled for a game (`MatchupAlbums`)

    /// Between the two sides: "v", "vs", "vs.", "x", "versus", "against", "at", "@", "-", "–", "—", ":", "|", "/".
    var matchupSeparator = #"(?i)\s+(?:vs?\.?|x|versus|against|at)\s+|\s*[@–—:|/]\s*|\s+-\s+|(?<=\p{L})-(?=\p{L})"#
    /// Words a matchup title carries that are not a side.
    var matchupFiller = ["the", "world", "cup", "wc", "fifa", "uefa", "euro", "copa", "gold", "nations", "league",
                         "game", "games", "match", "matchday", "group", "stage", "final", "semi", "semifinal",
                         "quarter", "quarterfinal", "round", "friendly", "day", "trip", "national", "team", "fans",
                         "my", "our", "at", "in", "with", "and", "i", "of", "fc", "live", "stadium"]
    /// Other names a national side goes by (the native name, the short name), by its code.
    var nationalNames: [String: [String]] = [
        "BIH": ["bosnia", "bosna", "bosna hercegovina", "bosnia herzegovina", "bosnia hercegovina", "bih", "zmajevi"],
        "QAT": ["katar"], "GER": ["deutschland"], "ESP": ["espana"], "NED": ["holland", "nederland"], "CRO": ["hrvatska"],
        "SRB": ["srbija"], "SUI": ["schweiz", "suisse", "svizzera"], "KOR": ["korea"], "PRK": ["dpr korea"],
        "USA": ["usa", "usmnt", "us", "america"], "BRA": ["brasil"], "CZE": ["czech republic", "czech", "cesko"],
        "TUR": ["turkey", "turkiye"], "CIV": ["cote divoire"], "IRL": ["ireland"], "MAR": ["maroc"], "KSA": ["saudi"],
        "UAE": ["emirates", "uae"], "MEX": ["el tri"], "ITA": ["italia"], "POR": ["portugal"], "BEL": ["belgique", "belgie"],
        "AUT": ["osterreich"], "POL": ["polska"], "NOR": ["norge"], "SWE": ["sverige"], "DEN": ["danmark"], "JPN": ["nippon"],
        "MKD": ["macedonia"], "SVN": ["slovenija"], "SVK": ["slovensko"], "MNE": ["crna gora"], "ALB": ["shqiperia"],
    ]
    /// Titled albums read per pass; an outing is a run of photos with no gap over this; the last few outings of an album are looked
    /// up; the game must have started within this of the outing's photos.
    var matchupMaxAlbums = 20
    var matchupOutingGapHours: Double = 6
    var matchupMaxOutings = 4
    var matchupWindowHours: Double = 6

    // MARK: The scene check (`SceneCheck`)

    var sceneSportsWords = ["stadium", "arena", "sport", "baseball", "basketball", "football", "soccer", "hockey",
                            "athlet", "ballpark", "field", "court", "crowd", "scoreboard", "bleacher", "racing", "rink",
                            "tennis", "rugby", "cricket", "jersey", "team", "goal", "pitch", "audience"]
    /// The classifier's exact identifiers that only a real game venue or sport produces (matched whole).
    var sceneVenueLabels = ["stadium", "arena", "scoreboard", "bleachers", "baseball", "basketball", "football", "soccer",
                            "hockey", "rink", "rugby", "cricket_sport", "tennis", "softball", "motorsport", "nascar",
                            "formula_one_car"]
    /// The ground itself rather than a sport.
    var sceneStructureLabels = ["stadium", "arena", "scoreboard", "bleachers"]
    var sceneIndoorWords = ["indoor", "arena", "court", "rink", "ceiling", "gym", "hall", "stage"]
    var sceneOutdoorWords = ["outdoor", "sky", "grass", "field", "cloud", "lawn", "sunset", "daytime", "stadium", "ballpark"]
    var sceneEventWords = ["concert", "stage", "stadium", "arena", "crowd", "audience", "festival", "fireworks", "spotlight"]
    var sceneElsewhereWords = ["bar", "pub", "nightclub", "party", "cocktail", "wine", "restaurant", "dining", "dinner",
                               "concert", "stage", "dancing", "wedding", "kitchen", "living_room", "bedroom", "office",
                               "bathroom", "nursery", "playroom", "toy", "document", "bed", "desk", "furniture",
                               "beach", "sand", "shore", "ocean", "sea", "seascape", "lake", "waterfront", "swimming_pool", "pool",
                               "swimming", "swimsuit", "sunbathing", "surfing", "surfboard", "sandcastle", "water_body", "seafood", "museum",
                               "hiking", "skiing", "screenshot", "picnic", "camping", "food", "meal", "dessert", "cake", "dog", "cat", "pet"]
    /// Photos sampled for a visit's verdict; labels under this confidence are ignored; a label at or over this counts as clear.
    var sceneVerdictSample = 6
    var sceneLabelFloor: Double = 0.05
    var sceneKindThreshold: Double = 0.3
    /// A day's look is a game with this many venue photos at this share, under this share elsewhere; mostly elsewhere at this share.
    var lookMinVenue = 2
    var lookMinShare: Double = 0.25
    var lookMaxElsewhere: Double = 0.35
    var lookMostlyElsewhere: Double = 0.5

    // MARK: Progress and the scan check

    /// Photos kept for the scan screen's strip; how often the waiting screen hears from the scan.
    var progressRecentPhotos = 40
    var progressEveryPhotos = 1_000
    /// Photos listed one by one in the scan check; the rest are counted.
    var scanCheckListed = 150
    /// Photos read to find where a game's own photos were taken.
    var photoLocationSample = 24

    static let defaults = ScanSettings()

    /// The manifest entry that carries these settings.
    static let packKind = "settings"
    static let packId = "settings/scan"

    // MARK: Decoding: a missing or malformed key keeps its default; unknown keys are ignored

    enum CodingKeys: String, CodingKey, CaseIterable {
        case version
        case fenceMeters, fenceBigMeters, fenceHugeMeters, fenceBigCapacity, fenceHugeCapacity, indexBoxMeters, indexBoxSlack
        case matchdayReachMeters, neighborMeters
        case vehicleSpeed, movingSpeed, movingDistanceMeters, movingWindowMinutes
        case visitStayMinutes, overnightGapHours, askGapHours, dwellPhotos, dwellMinutes
        case scheduleBeforeHours, scheduleAfterHours, nearbyBeforeHours, nearbyAfterHours
        case lookupConcurrency, lookupAttempts, lookupBackoffMilliseconds, lookupTimeoutSeconds, matchBatch
        case nearbyReachMeters, nearbyPhotos, nearbyMaxDays
        case cityGapMinutes, cityPhotos, citySpanMinutes, cityAnchorHours, cityMetroMeters, cityMinCapacity, cityMaxVenues, cityMaxDays
        case citySavedBeforeHours, citySavedAfterHours, cityBeforeMinutes, cityAfterMinutes
        case citySample, cityMinVenue, cityVenueShare, cityMinStructure, cityElsewhereShare
        case suggestMinPhotos, suggestMaxDays, suggestMaxAlbums, suggestMaxOffered, suggestReachMeters, albumMaxPhotos
        case collectionPhotos, collectionDays, outingWindowHours, outingPhotos, outingShare, outingMinutes, outingBeforeHours, outingAfterHours
        case tripMaxCount, suggestVenueCapacity, tripReachMeters, homeReachMeters, homeVenues
        case sourceLookPhotos, sourceLookMinVenue, sourceLookMinShare, dayLookPhotos, sportTitleWords, appAlbums
        case matchupSeparator, matchupFiller, nationalNames, matchupMaxAlbums, matchupOutingGapHours, matchupMaxOutings, matchupWindowHours
        case sceneSportsWords, sceneVenueLabels, sceneStructureLabels, sceneIndoorWords, sceneOutdoorWords, sceneEventWords, sceneElsewhereWords
        case sceneVerdictSample, sceneLabelFloor, sceneKindThreshold, lookMinVenue, lookMinShare, lookMaxElsewhere, lookMostlyElsewhere
        case progressRecentPhotos, progressEveryPhotos, scanCheckListed, photoLocationSample
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self.defaults
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        version = get(.version, 0)
        fenceMeters = get(.fenceMeters, d.fenceMeters)
        fenceBigMeters = get(.fenceBigMeters, d.fenceBigMeters)
        fenceHugeMeters = get(.fenceHugeMeters, d.fenceHugeMeters)
        fenceBigCapacity = get(.fenceBigCapacity, d.fenceBigCapacity)
        fenceHugeCapacity = get(.fenceHugeCapacity, d.fenceHugeCapacity)
        indexBoxMeters = get(.indexBoxMeters, d.indexBoxMeters)
        indexBoxSlack = get(.indexBoxSlack, d.indexBoxSlack)
        matchdayReachMeters = get(.matchdayReachMeters, d.matchdayReachMeters)
        neighborMeters = get(.neighborMeters, d.neighborMeters)
        vehicleSpeed = get(.vehicleSpeed, d.vehicleSpeed)
        movingSpeed = get(.movingSpeed, d.movingSpeed)
        movingDistanceMeters = get(.movingDistanceMeters, d.movingDistanceMeters)
        movingWindowMinutes = get(.movingWindowMinutes, d.movingWindowMinutes)
        visitStayMinutes = get(.visitStayMinutes, d.visitStayMinutes)
        overnightGapHours = get(.overnightGapHours, d.overnightGapHours)
        askGapHours = get(.askGapHours, d.askGapHours)
        dwellPhotos = get(.dwellPhotos, d.dwellPhotos)
        dwellMinutes = get(.dwellMinutes, d.dwellMinutes)
        scheduleBeforeHours = get(.scheduleBeforeHours, d.scheduleBeforeHours)
        scheduleAfterHours = get(.scheduleAfterHours, d.scheduleAfterHours)
        nearbyBeforeHours = get(.nearbyBeforeHours, d.nearbyBeforeHours)
        nearbyAfterHours = get(.nearbyAfterHours, d.nearbyAfterHours)
        lookupConcurrency = get(.lookupConcurrency, d.lookupConcurrency)
        lookupAttempts = get(.lookupAttempts, d.lookupAttempts)
        lookupBackoffMilliseconds = get(.lookupBackoffMilliseconds, d.lookupBackoffMilliseconds)
        lookupTimeoutSeconds = get(.lookupTimeoutSeconds, d.lookupTimeoutSeconds)
        matchBatch = get(.matchBatch, d.matchBatch)
        nearbyReachMeters = get(.nearbyReachMeters, d.nearbyReachMeters)
        nearbyPhotos = get(.nearbyPhotos, d.nearbyPhotos)
        nearbyMaxDays = get(.nearbyMaxDays, d.nearbyMaxDays)
        cityGapMinutes = get(.cityGapMinutes, d.cityGapMinutes)
        cityPhotos = get(.cityPhotos, d.cityPhotos)
        citySpanMinutes = get(.citySpanMinutes, d.citySpanMinutes)
        cityAnchorHours = get(.cityAnchorHours, d.cityAnchorHours)
        cityMetroMeters = get(.cityMetroMeters, d.cityMetroMeters)
        cityMinCapacity = get(.cityMinCapacity, d.cityMinCapacity)
        cityMaxVenues = get(.cityMaxVenues, d.cityMaxVenues)
        cityMaxDays = get(.cityMaxDays, d.cityMaxDays)
        citySavedBeforeHours = get(.citySavedBeforeHours, d.citySavedBeforeHours)
        citySavedAfterHours = get(.citySavedAfterHours, d.citySavedAfterHours)
        cityBeforeMinutes = get(.cityBeforeMinutes, d.cityBeforeMinutes)
        cityAfterMinutes = get(.cityAfterMinutes, d.cityAfterMinutes)
        citySample = get(.citySample, d.citySample)
        cityMinVenue = get(.cityMinVenue, d.cityMinVenue)
        cityVenueShare = get(.cityVenueShare, d.cityVenueShare)
        cityMinStructure = get(.cityMinStructure, d.cityMinStructure)
        cityElsewhereShare = get(.cityElsewhereShare, d.cityElsewhereShare)
        suggestMinPhotos = get(.suggestMinPhotos, d.suggestMinPhotos)
        suggestMaxDays = get(.suggestMaxDays, d.suggestMaxDays)
        suggestMaxAlbums = get(.suggestMaxAlbums, d.suggestMaxAlbums)
        suggestMaxOffered = get(.suggestMaxOffered, d.suggestMaxOffered)
        suggestReachMeters = get(.suggestReachMeters, d.suggestReachMeters)
        albumMaxPhotos = get(.albumMaxPhotos, d.albumMaxPhotos)
        collectionPhotos = get(.collectionPhotos, d.collectionPhotos)
        collectionDays = get(.collectionDays, d.collectionDays)
        outingWindowHours = get(.outingWindowHours, d.outingWindowHours)
        outingPhotos = get(.outingPhotos, d.outingPhotos)
        outingShare = get(.outingShare, d.outingShare)
        outingMinutes = get(.outingMinutes, d.outingMinutes)
        outingBeforeHours = get(.outingBeforeHours, d.outingBeforeHours)
        outingAfterHours = get(.outingAfterHours, d.outingAfterHours)
        tripMaxCount = get(.tripMaxCount, d.tripMaxCount)
        suggestVenueCapacity = get(.suggestVenueCapacity, d.suggestVenueCapacity)
        tripReachMeters = get(.tripReachMeters, d.tripReachMeters)
        homeReachMeters = get(.homeReachMeters, d.homeReachMeters)
        homeVenues = get(.homeVenues, d.homeVenues)
        sourceLookPhotos = get(.sourceLookPhotos, d.sourceLookPhotos)
        sourceLookMinVenue = get(.sourceLookMinVenue, d.sourceLookMinVenue)
        sourceLookMinShare = get(.sourceLookMinShare, d.sourceLookMinShare)
        dayLookPhotos = get(.dayLookPhotos, d.dayLookPhotos)
        sportTitleWords = get(.sportTitleWords, d.sportTitleWords)
        appAlbums = get(.appAlbums, d.appAlbums)
        matchupSeparator = get(.matchupSeparator, d.matchupSeparator)
        matchupFiller = get(.matchupFiller, d.matchupFiller)
        nationalNames = get(.nationalNames, d.nationalNames)
        matchupMaxAlbums = get(.matchupMaxAlbums, d.matchupMaxAlbums)
        matchupOutingGapHours = get(.matchupOutingGapHours, d.matchupOutingGapHours)
        matchupMaxOutings = get(.matchupMaxOutings, d.matchupMaxOutings)
        matchupWindowHours = get(.matchupWindowHours, d.matchupWindowHours)
        sceneSportsWords = get(.sceneSportsWords, d.sceneSportsWords)
        sceneVenueLabels = get(.sceneVenueLabels, d.sceneVenueLabels)
        sceneStructureLabels = get(.sceneStructureLabels, d.sceneStructureLabels)
        sceneIndoorWords = get(.sceneIndoorWords, d.sceneIndoorWords)
        sceneOutdoorWords = get(.sceneOutdoorWords, d.sceneOutdoorWords)
        sceneEventWords = get(.sceneEventWords, d.sceneEventWords)
        sceneElsewhereWords = get(.sceneElsewhereWords, d.sceneElsewhereWords)
        sceneVerdictSample = get(.sceneVerdictSample, d.sceneVerdictSample)
        sceneLabelFloor = get(.sceneLabelFloor, d.sceneLabelFloor)
        sceneKindThreshold = get(.sceneKindThreshold, d.sceneKindThreshold)
        lookMinVenue = get(.lookMinVenue, d.lookMinVenue)
        lookMinShare = get(.lookMinShare, d.lookMinShare)
        lookMaxElsewhere = get(.lookMaxElsewhere, d.lookMaxElsewhere)
        lookMostlyElsewhere = get(.lookMostlyElsewhere, d.lookMostlyElsewhere)
        progressRecentPhotos = get(.progressRecentPhotos, d.progressRecentPhotos)
        progressEveryPhotos = get(.progressEveryPhotos, d.progressEveryPhotos)
        scanCheckListed = get(.scanCheckListed, d.scanCheckListed)
        photoLocationSample = get(.photoLocationSample, d.photoLocationSample)
    }

    // MARK: Clamping

    /// Every field inside its range (see the type's note). Word lists lose empty entries and are capped; a separator that does
    /// not compile falls back to the default.
    func clamped() -> ScanSettings {
        var s = self
        func m(_ v: Double, _ lo: Double = 50, _ hi: Double = 5_000) -> Double { v.isFinite ? min(max(v, lo), hi) : lo }
        func n(_ v: Int, _ lo: Int = 1, _ hi: Int = 50) -> Int { min(max(v, lo), hi) }
        func share(_ v: Double) -> Double { m(v, 0, 1) }
        func hours(_ v: Double) -> Double { m(v, 0, 48) }
        func minutes(_ v: Double, _ lo: Double = 1) -> Double { m(v, lo, 600) }
        func words(_ list: [String]) -> [String] { Array(list.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(1_000)) }
        s.version = max(s.version, 0)
        s.fenceMeters = m(s.fenceMeters)
        s.fenceBigMeters = m(s.fenceBigMeters)
        s.fenceHugeMeters = m(s.fenceHugeMeters)
        s.fenceBigCapacity = n(s.fenceBigCapacity, 1_000, 500_000)
        s.fenceHugeCapacity = n(s.fenceHugeCapacity, 1_000, 500_000)
        s.indexBoxMeters = m(s.indexBoxMeters)
        s.indexBoxSlack = m(s.indexBoxSlack, 1, 1.5)
        s.matchdayReachMeters = m(s.matchdayReachMeters)
        s.neighborMeters = m(s.neighborMeters)
        s.vehicleSpeed = m(s.vehicleSpeed, 5, 120)
        s.movingSpeed = m(s.movingSpeed, 5, 120)
        s.movingDistanceMeters = m(s.movingDistanceMeters, 50, 20_000)
        s.movingWindowMinutes = minutes(s.movingWindowMinutes)
        s.visitStayMinutes = minutes(s.visitStayMinutes)
        s.overnightGapHours = m(s.overnightGapHours, 1, 48)
        s.askGapHours = m(s.askGapHours, 1, 48)
        s.dwellPhotos = n(s.dwellPhotos)
        s.dwellMinutes = minutes(s.dwellMinutes)
        s.scheduleBeforeHours = hours(s.scheduleBeforeHours)
        s.scheduleAfterHours = hours(s.scheduleAfterHours)
        s.nearbyBeforeHours = hours(s.nearbyBeforeHours)
        s.nearbyAfterHours = hours(s.nearbyAfterHours)
        s.lookupConcurrency = n(s.lookupConcurrency)
        s.lookupAttempts = n(s.lookupAttempts, 1, 10)
        s.lookupBackoffMilliseconds = n(s.lookupBackoffMilliseconds, 0, 60_000)
        s.lookupTimeoutSeconds = m(s.lookupTimeoutSeconds, 1, 120)
        s.matchBatch = n(s.matchBatch)
        s.nearbyReachMeters = m(s.nearbyReachMeters)
        s.nearbyPhotos = n(s.nearbyPhotos)
        s.nearbyMaxDays = n(s.nearbyMaxDays, 1, 1_000)
        s.cityGapMinutes = minutes(s.cityGapMinutes)
        s.cityPhotos = n(s.cityPhotos)
        s.citySpanMinutes = minutes(s.citySpanMinutes)
        s.cityAnchorHours = m(s.cityAnchorHours, 1, 48)
        s.cityMetroMeters = m(s.cityMetroMeters, 1_000, 200_000)
        s.cityMinCapacity = n(s.cityMinCapacity, 0, 500_000)
        s.cityMaxVenues = n(s.cityMaxVenues)
        s.cityMaxDays = n(s.cityMaxDays, 1, 1_000)
        s.citySavedBeforeHours = hours(s.citySavedBeforeHours)
        s.citySavedAfterHours = hours(s.citySavedAfterHours)
        s.cityBeforeMinutes = minutes(s.cityBeforeMinutes, 0)
        s.cityAfterMinutes = minutes(s.cityAfterMinutes, 0)
        s.citySample = n(s.citySample, 1, 200)
        s.cityMinVenue = n(s.cityMinVenue)
        s.cityVenueShare = share(s.cityVenueShare)
        s.cityMinStructure = n(s.cityMinStructure, 0, 50)
        s.cityElsewhereShare = share(s.cityElsewhereShare)
        s.suggestMinPhotos = n(s.suggestMinPhotos)
        s.suggestMaxDays = n(s.suggestMaxDays, 1, 1_000)
        s.suggestMaxAlbums = n(s.suggestMaxAlbums, 1, 1_000)
        s.suggestMaxOffered = n(s.suggestMaxOffered)
        s.suggestReachMeters = m(s.suggestReachMeters, 50, 20_000)
        s.albumMaxPhotos = n(s.albumMaxPhotos, 1, 100_000)
        s.collectionPhotos = n(s.collectionPhotos)
        s.collectionDays = m(s.collectionDays, 1, 3_650)
        s.outingWindowHours = m(s.outingWindowHours, 1, 48)
        s.outingPhotos = n(s.outingPhotos)
        s.outingShare = share(s.outingShare)
        s.outingMinutes = minutes(s.outingMinutes)
        s.outingBeforeHours = hours(s.outingBeforeHours)
        s.outingAfterHours = hours(s.outingAfterHours)
        s.tripMaxCount = n(s.tripMaxCount, 1, 1_000)
        s.suggestVenueCapacity = n(s.suggestVenueCapacity, 0, 500_000)
        s.tripReachMeters = m(s.tripReachMeters, 1_000, 200_000)
        s.homeReachMeters = m(s.homeReachMeters, 1_000, 200_000)
        s.homeVenues = n(s.homeVenues)
        s.sourceLookPhotos = n(s.sourceLookPhotos, 1, 200)
        s.sourceLookMinVenue = n(s.sourceLookMinVenue)
        s.sourceLookMinShare = share(s.sourceLookMinShare)
        s.dayLookPhotos = n(s.dayLookPhotos, 1, 200)
        s.sportTitleWords = words(s.sportTitleWords)
        s.appAlbums = words(s.appAlbums)
        if (try? NSRegularExpression(pattern: s.matchupSeparator)) == nil { s.matchupSeparator = Self.defaults.matchupSeparator }
        s.matchupFiller = words(s.matchupFiller)
        s.nationalNames = Dictionary(uniqueKeysWithValues: s.nationalNames.prefix(1_000).map { ($0.key.uppercased(), words($0.value)) })
        s.matchupMaxAlbums = n(s.matchupMaxAlbums, 1, 1_000)
        s.matchupOutingGapHours = m(s.matchupOutingGapHours, 1, 48)
        s.matchupMaxOutings = n(s.matchupMaxOutings)
        s.matchupWindowHours = hours(s.matchupWindowHours)
        s.sceneSportsWords = words(s.sceneSportsWords)
        s.sceneVenueLabels = words(s.sceneVenueLabels)
        s.sceneStructureLabels = words(s.sceneStructureLabels)
        s.sceneIndoorWords = words(s.sceneIndoorWords)
        s.sceneOutdoorWords = words(s.sceneOutdoorWords)
        s.sceneEventWords = words(s.sceneEventWords)
        s.sceneElsewhereWords = words(s.sceneElsewhereWords)
        s.sceneVerdictSample = n(s.sceneVerdictSample, 1, 200)
        s.sceneLabelFloor = share(s.sceneLabelFloor)
        s.sceneKindThreshold = share(s.sceneKindThreshold)
        s.lookMinVenue = n(s.lookMinVenue)
        s.lookMinShare = share(s.lookMinShare)
        s.lookMaxElsewhere = share(s.lookMaxElsewhere)
        s.lookMostlyElsewhere = share(s.lookMostlyElsewhere)
        s.progressRecentPhotos = n(s.progressRecentPhotos, 1, 200)
        s.progressEveryPhotos = n(s.progressEveryPhotos, 1, 100_000)
        s.scanCheckListed = n(s.scanCheckListed, 1, 2_000)
        s.photoLocationSample = n(s.photoLocationSample, 1, 200)
        return s
    }

    // MARK: Differences, for the scan check

    /// "dwellMinutes: 60 (default 20)" for every field that differs from `base`; word lists and tables by size.
    func differences(from base: ScanSettings = .defaults) -> [String] {
        func fields(_ s: ScanSettings) -> [String: Any] {
            guard let data = try? JSONEncoder().encode(s), let any = try? JSONSerialization.jsonObject(with: data) else { return [:] }
            return any as? [String: Any] ?? [:]
        }
        func show(_ v: Any?) -> String {
            switch v {
            case let list as [Any]: "\(list.count) entries"
            case let table as [String: Any]: "\(table.count) entries"
            case let text as String: "\u{201C}\(text)\u{201D}"
            case let v?: "\(v)"
            case nil: "none"
            }
        }
        let mine = fields(self), theirs = fields(base)
        return CodingKeys.allCases.compactMap { key in
            if key == .version { return nil }  // the Settings line already names it
            let a = mine[key.rawValue], b = theirs[key.rawValue]
            if let a = a as? NSObject, let b = b as? NSObject, a.isEqual(b) { return nil }
            if a == nil && b == nil { return nil }
            return "\(key.rawValue): \(show(a)) (default \(show(b)))"
        }
    }
}

// MARK: - Loading from the signed packs

extension ScanSettings {
    enum Source: String, Sendable { case builtIn = "built-in", pack }

    struct Loaded: Sendable {
        var settings: ScanSettings
        var source: Source
    }

    private static let state = OSAllocatedUnfairLock<Loaded?>(initialState: nil)

    /// What the scan judges by right now: the built-in defaults, or the settings pack on the phone when it is newer. Read once
    /// at the start of a scan and passed down, so one scan sees one set.
    static var current: ScanSettings { loaded.settings }
    static var source: Source { loaded.source }

    private static var loaded: Loaded {
        state.withLock { stored in
            if let stored { return stored }
            let fresh = loaded(from: PackStore.defaultDirectory)
            stored = fresh
            return fresh
        }
    }

    /// Reads the settings pack from the packs on disk again (after `PackStore` has adopted a new manifest).
    static func reload(from directory: URL = PackStore.defaultDirectory) {
        let fresh = loaded(from: directory)
        state.withLock { $0 = fresh }
    }

    /// Makes `current` these settings until the next `reload`. For tests.
    static func install(_ settings: ScanSettings, source: Source = .builtIn) {
        state.withLock { $0 = Loaded(settings: settings, source: source) }
    }

    /// The settings pack a verified manifest on disk names, when its file is there, its hash matches the manifest, it decodes
    /// and its version is newer than `builtIn`; else `builtIn`. Pure apart from reading the two files.
    static func loaded(from directory: URL, publicKey: String = PackConfig.publicKey, builtIn: ScanSettings = .defaults) -> Loaded {
        let fallback = Loaded(settings: builtIn, source: .builtIn)
        guard let manifestData = try? Data(contentsOf: directory.appending(path: "manifest.json")),
              let manifest = PackStore.verified(manifestData, publicKey: publicKey),
              let pack = manifest.packs.first(where: { $0.kind == packKind && $0.id == packId }),
              let data = try? Data(contentsOf: directory.appending(path: PackStore.fileName(for: pack))),
              PackStore.matches(data, pack),
              let settings = fromPack(data, builtIn: builtIn) else { return fallback }
        return Loaded(settings: settings, source: .pack)
    }

    /// Pure: the pack's settings, clamped, when they decode and are newer than the built-in ones.
    static func fromPack(_ data: Data, builtIn: ScanSettings = .defaults) -> ScanSettings? {
        guard let decoded = try? JSONDecoder().decode(ScanSettings.self, from: data), decoded.version > builtIn.version else { return nil }
        return decoded.clamped()
    }
}
