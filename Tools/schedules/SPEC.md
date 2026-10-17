# Schedules: every game, last 15 seasons (shared by every schedule agent)

Goal: for every team the app knows (Tools/teams/*-teams.json, Witness/Resources/Catalog/teams.json) have the full list of games
played (or scheduled) from the 2011 season through the current 2026 season, with the stadium each was played in. This is
offline reference data for matching photos to games and for the Passport; it is not bundled into the app yet.

## Layout (one scope per agent, in /home/user/SportsApp/Tools/schedules/<scope>/)
- `<leagueSlug>/<season>.json`: one file per league per season. `leagueSlug` is the league key with "/" replaced by "-"
  (`baseball/mlb` -> `baseball-mlb`, `soccer/eng.1` -> `soccer-eng.1`). `season` is the year the season STARTS (2011 = 2011 or
  2011-12). Seasons 2011 through 2026 (2026 = the current season; its unplayed games are status "S").
- `venues-seen.json`: every distinct stadium that hosted a game in your files (see below).
- `missing-venues.json`: venues from `venues-seen.json` that are not in `/home/user/SportsApp/Witness/Resources/Catalog/venues.json`
  (match by name/alias/city first, and by distance <= 400 m), in the `Tools/venues/SPEC.md` format, with real coordinates.
  Validate with `python3 /home/user/SportsApp/Tools/venues/validate.py Tools/schedules/<scope>/missing-venues.json`.
- `NOTES.md` (<= 30 lines): source(s) used, seasons/leagues covered, counts, gaps and why, anything uncertain.
Validate everything with `python3 /home/user/SportsApp/Tools/schedules/validate.py <scope>`. It must print 0 errors.

## Season file (minified JSON, one line; keep each file under 5 MB, split by month only if you must and say so in NOTES)
```json
{"league":"baseball/mlb","season":2011,"source":"espn","fetched":"2026-10-17",
 "teams":{"16":"CHC"},
 "venues":{"17":["Wrigley Field","Chicago","IL","US"]},
 "games":[["310402016","2011-04-01T20:05Z","16","29",4,3,"17","F","Opening Day"]]}
```
- `teams`: source team id -> abbreviation, for every team that appears in `games`. Use the SOURCE's team ids (ESPN ids for ESPN
  leagues; they match `externalIds.espn` + `externalIds.espnLeague` in the teams files). ESPN ids repeat across leagues, so ids
  are only meaningful together with `league`.
- `venues`: source venue id -> [name, city, region or "", ISO country code], for every venue that appears.
- `games`: array of `[eventId, startUTC, homeId, awayId, homeScore, awayScore, venueId, status, note]`, sorted by start time.
  - `eventId` string, unique within the file. `startUTC` ISO "YYYY-MM-DDTHH:MMZ". `homeId`/`awayId` strings in `teams`.
  - scores integers, or null when not final. `venueId` string in `venues`, or null if the source has none.
  - `status`: "F" final, "S" scheduled (future), "P" postponed (not replayed), "C" cancelled, "O" other/unknown.
  - `note`: short string ("" if none): playoff round, group stage, "Neutral site", "Bowl game", cup round.
  - Neutral-site games: `home` is the source's designated home side; put "Neutral site" in `note`.
  - Include regular season, playoffs/knockouts/finals and league cups of that competition. Exclude preseason/exhibitions/friendlies
    unless the league IS friendlies. Do not include duplicates (the same eventId twice).

## venues-seen.json
Array of `{ "league": "...", "sourceVenueId": "...", "name": "...", "city": "...", "region": "...", "countryCode": "US",
"catalogVenueId": "wrigley" | null, "latitude": 41.9484, "longitude": -87.6553, "firstSeason": 2011, "lastSeason": 2026,
"games": 812 }`. Coordinates for every venue (catalog venues: copy from the catalog; others: Wikidata P625 cross-checked with
OpenStreetMap Nominatim, within ~100 m; say in NOTES which are approximate). Venues that were renamed (naming rights) keep one
record with the names that appeared; list renamed names in `aliases`. Demolished stadiums count: they are exactly what this is for.

## Sources, in order of preference
ESPN's public site API: `https://site.api.espn.com/apis/site/v2/sports/<path>/scoreboard?dates=YYYYMMDD-YYYYMMDD&limit=1000`
(ESPN now rejects date ranges with HTTP 400: query ONE day, `dates=YYYYMMDD`; college leagues may need
`&groups=<id>` such as 80 for FBS, 50 for D1 basketball; check the response's event count). Event fields: `id`, `date`, `status.type.state`
("pre"/"in"/"post") and `completed`, `competitions[0].competitors[]` (`homeAway`, `team.id`, `team.abbreviation`, `score`),
`competitions[0].venue` (`id`, `fullName`, `address.city/state/country`), `competitions[0].neutralSite`, `season.slug`/`notes`.
Other free public APIs when ESPN does not cover a league: statsapi.mlb.com (MLB and MiLB schedules and venues, includes coordinates),
api-web.nhle.com (NHL), the NBA/WNBA CDN schedules, football-data.org, Wikipedia season pages. No scraping behind logins, no paid keys.
Be polite: at most ~6 requests in flight, retry with backoff, cache raw responses in your scratchpad (not in the repo), and write a script
you can re-run (keep scripts in your scratchpad, not in the repo).

## Rules
- Accuracy over volume. Spot-check: games per team per season against the known season length (MLB 162, NFL 17, NBA 82, NHL 82,
  top European leagues 34-38) and report outliers in NOTES.
- Never use or store logos. Do not edit files outside `Tools/schedules/<scope>/` (plus nothing else). Do not run git commands.
- If a source is unreachable or rate-limited, say so in NOTES and cover what you can; do not invent games.
