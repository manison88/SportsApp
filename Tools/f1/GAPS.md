# Formula 1 in Witness: what the app needs (data is in this folder)

Data here: `circuits.json` (48), `calendar.json` (200 events 2018-2026, ESPN ids), `constructors-drivers.json` (11 teams, 44 drivers, passport list).
App files read: GameLookup.swift, AddGameView.swift, VisitGrouping.swift, Models.swift (`Venue.geofence`, `GameEntry.podium`).

## 1. A race weekend is one visit, not three
Today `VisitGrouping.group` keys a visit as `venueId|local day`. A Friday-Sunday trip becomes 3 visits, 3 lookups, 3 empty "games".
- Bundle calendar.json and look up the weekend from it: for a motorsport venue, a photo whose local day is in
  `[weekendStartLocalDate ... raceLocalDate]` (sessions[0].localDate to raceLocalDate) gets key `circuitId|eventId` (e.g. `monza|2025-italian`).
  Fallback to `venueId|day` outside race weekends (track day, museum, pre-season testing, tour) and make that a `kind: .visit`.
- Las Vegas races at local Saturday 22:00 and Singapore/Qatar/Abu Dhabi finish after dark: always use the circuit time zone (`raceLocalDate`
  is already computed in it), never the phone's. Late-night photos belong to the day they were taken, then join the weekend window.
- One `GameEntry` per weekend: `date` = race start (calendar `raceStartUtc`), `competition` = `name` ("Heineken Dutch Grand Prix"; use `shortName`
  for display), `podium` = `results.podium`, `headline` = "{winner} won from pole {pole}" or a note ("Title decider"), `source` =
  (espn, racing/f1, espnEventId). `homeTeamId/awayTeamId/scores` stay nil, `lineHome` empty (already how AddGameView saves motorsport).
- Back-to-back events at one circuit (2020 Bahrain + Sakhir, Austria x2, Silverstone x2) never overlap: the closest are 5 days apart (checked in
  calendar.json), so a weekend window picks exactly one event.

## 2. Circuits are kilometres wide
`Venue.geofence` is derived from capacity (>=90k = 300 m) so every F1 circuit gets 300 m, and `VenueIndex.nearest` pre-filters with a 320 m box
before the geofence check. A bigger fence would be silently clipped. Changes:
- Optional `geofenceMeters: Double?` and `grandstandsLatLon: [[Double]]?` on `Venue`; `geofence` returns `geofenceMeters ?? capacityRule`.
- `nearest()` measures the minimum distance to the centre and every grandstand point; the pre-filter box must use `max(v.geofence)` (<= 1500 m).
  Index each venue under its grandstand points too (cell 0.02 deg = 2.2 km, so a 3x3 scan covers 1500 m; points that straddle cells need both).
- Recommended radii are in `geofenceMeters` (400-1500, reasoning in each circuit's `notes`): Silverstone, Spa, Miami, Las Vegas, Indianapolis 1500;
  Monaco, Monza, Mexico City, COTA 1200; most autodromes 900-1100. `matchdayReach` (500 m) can stay for pubs/hotels near the gate.
- Camping and hotels are often 2-5 km away. Rule: a GPS photo within 5 km of a circuit on a weekend day joins that weekend (like the existing
  "photos without a fix join the visit day" rule) but can never start a visit.
- Street circuits (Monaco, Singapore, Baku, Jeddah, Las Vegas, Melbourne: `street: true`) have a temporary paddock; fans move along 4-6 km of
  public road. Expect more false positives (tourists in Monaco on a non-race day): require >= 3 photos or the `minimumStay` and a weekend date.
- Miami is built around Hard Rock Stadium (its own venue): resolve by weekend window first, then nearest venue.

## 3. Finding the race (GameLookup)
- `venue.leagues` is `["racing/f1"]` for every circuit, so `leagues(for:)` already returns it; the work is the parser. F1 events have no
  home/away: `parseScoreboard` returns `[]`. Add `parseRaceEvent` (new `FoundRace`): id, name, shortName, date (first session), endDate (race start),
  `circuit.fullName`, `competitions[]` (type FP1/FP2/FP3/SS/SR/Qual/Race with UTC dates) and the Race `competitors[]` sorted by `order` (athlete id,
  displayName; `winner: true` on P1). Map athlete id to the 3-letter code with `constructors-drivers.json` (`externalIds.espnAthleteId`).
- Query: `racing/f1/scoreboard?dates=yyyyMMdd` for each local day of the photos. Verified: one date inside the weekend (even the Thursday before) returns the
  whole event (`dates=20231118` returns the Las Vegas GP). Season-wide `?dates=2024` lists every race. Single event: `/scoreboard/{eventId}`.
- `/summary?event=` returns 404 for F1, so `detail()` must skip plays/win probability for racing/f1; keep `stage` from tags instead.
- Match on ESPN event id, never on circuit name: ESPN labels every Spanish GP 2018-2025 as "Madring" (Barcelona), the 2020 Sakhir GP as "Outer Track",
  the 2026 Bahrain GP as Sepang, and calendar.json carries `dataQuality` for these. Use the bundled calendar for 2018-2026, ESPN for newer seasons
  (compare `circuit.fullName` with `circuits.json` names and `aliases`).
- ESPN lists cancelled events (Russia 2022, Imola 2023, Bahrain and Saudi 2026): skip `status: STATUS_CANCELED`.
- Results (podium, pole, fastest lap) come from the bundled calendar; ESPN `competitors` has no fastest lap or codes. Refresh via `Tools/f1`.

## 4. Which days the fan attended and the Passport
- Auto-infer from photo local days against `sessions[].localDate`: Fri = FP1/FP2, Sat = FP3/Qualifying (+Sprint on sprint weekends: `sprintWeekend`),
  Sun = Race. Sprint weekends and the 2020 Imola two-day format differ, so read the session list, do not hardcode.
- Ask once on the new weekend entry: chips `Fri  Sat  Sun` (pre-selected from photos, plus Thu for pit-lane walks). Store
  `GameEntry.attendedDays: [String]` (local dates). Copy: "You were there Saturday (Qualifying, pole: NOR)". Show the race result to everyone,
  but only claim "You saw it win" when Sunday is attended.
- Passport: count distinct circuits, not weekends. `constructors-drivers.json` `league.passport.venueIds` is the 2026 list (23 circuits; Bahrain and
  Jeddah dropped from 2026). Label "Formula 1 circuits: 4 of 23"; an all-time tab counts any circuit in circuits.json (48), a stamp per circuit with
  the years attended. Weekends in the Timeline stay one entry each; a Sunday-only and Friday-only trip are both a stamp.
- Team/driver chips: import `teams` into teams.json (ids `f1-xxx`, colors readable on dark) so podium codes ("P1 VER") render as driver tiles.

## 5. Big-race theming (Stage mapping in BigGame.swift)
`tags` in calendar.json drive it: `title-decider`/`title-clinched` -> `.championship` ("2025 Abu Dhabi, Title decider"); `season-finale` and `season-opener`
-> `.playoff`/`.tournament` label "Season finale"; `marquee` (Monaco every year, finales, deciders) -> `.tournament` with the race name; `first-at-circuit`,
`return`, `farewell`, `maiden-win`, `milestone` -> chip text only; `wet`, `red-flag`, `shortened` -> weather badge and a "Rain delay" line. Circuit palette: use the
winning constructor's `colors.accent`. Unfinished 2026 races have `results: null` (still show the weekend and the countdown).

## 6. Work list (S < 1 day, M 1-3 days, L > 3 days)
P0: merge circuits.json into venues.json, strip unknown keys or add optional fields (S). `Venue.geofenceMeters` + grandstand points + index box fix (M).
P0: weekend grouping in `VisitGrouping` with calendar windows and tests (M). P0: `parseRaceEvent` + `FoundRace` -> `GameEntry` mapping, skip cancelled (M).
P1: AddGameView race picker (calendar filtered by venue and date) instead of free text, fills date, podium, headline (M). P1: attended-days chips and
Timeline/Game screen copy (M). P1: Passport F1 section, 23-circuit checklist (S).
P2: BigGame/theming from tags, weather badge (S). P2: teams.json + driver codes for podium tiles (S). P2: yearly refresh script for calendar.json from ESPN +
Jolpica (M). P3: grandstand points from OSM Overpass (it was unreachable here) and per-circuit verification on device (L).
