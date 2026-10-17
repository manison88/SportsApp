# Team and league "records" spec (shared by every research agent)

## Why
Witness gives USA teams a full record: a team entry (code, colors, ESPN id), a home venue, and a league checklist for the
Passport ("17 of 30 MLB parks"). Teams elsewhere (clubs in Europe, South America, Asia; national teams; basketball, handball
and hockey leagues outside the USA) have none of this, so they show as bare names with a gray tile and earn no checklist.
Your job is to produce the same records for every professional team in your scope.

## Deliverables (three files per agent, in /home/user/SportsApp/Tools/teams/)
1. `<scope>-teams.json`: array of TEAM records.
2. `<scope>-leagues.json`: array of LEAGUE records, each with its Passport checklist.
3. `<scope>-missing-venues.json`: array of venues from `Tools/venues/SPEC.md` format for any home ground that is NOT already in
   `/home/user/SportsApp/Witness/Resources/Catalog/venues.json` (954 venues; match by name/aliases/city first).
Validate with `python3 /home/user/SportsApp/Tools/teams/validate.py <scope>` (checks the three files together). It must print 0 errors.
Also write `<scope>-NOTES.md` (<= 30 lines): scope covered, counts, what you skipped and why, uncertain entries.

## TEAM record
```json
{
  "id": "eng1-ars",                      // "<league short>-<code>" lowercase, unique across ALL files
  "kind": "club",                        // "club" or "national"
  "sport": "soccer",                     // baseball, football, basketball, hockey, soccer, motorsport, handball
  "league": "Premier League",            // display name of the league the team plays in (national teams: the confederation or "National teams")
  "leagueKey": "soccer/eng.1",           // ESPN path when one exists (see below), else "<sport>/<slug>" such as "handball/ger.hbl"
  "country": "England", "countryCode": "GB",
  "abbreviation": "ARS",                 // 2-4 letters/digits; use ESPN's when ESPN lists the team; unique within leagueKey
  "locationName": "Arsenal",             // the short name shown in the app: city or club short name; national team: the country
  "teamName": "Arsenal FC",              // full name
  "monogram": "A",
  "colors": { "primary": "EF0107", "secondary": "FFFFFF", "accent": "EF0107" },   // hex, no '#'
  "externalIds": { "espn": "359", "espnLeague": "soccer/eng.1", "wikidata": "Q9617", "theSportsDb": null },
  "homeVenueId": "emirates-stadium",     // an id in venues.json, or in your missing-venues file
  "founded": 1886,                       // year or null
  "tier": 1                              // 1 = top division, 2 = second, ... national teams: 1
}
```
Color rules: primary and secondary are the club's real kit/brand colors. `accent` is the most recognizable color of the two that
stays readable on a near-black background (contrast >= 3:1 against #0B0C10); if both are too dark, use a lighter tint of the
primary. The app draws team tiles in `accent` with white or black text chosen automatically.
ESPN is the best source for abbreviations and colors: `curl -s "https://site.api.espn.com/apis/site/v2/sports/<path>/teams?limit=500"`
returns every team with `id`, `abbreviation`, `location`, `name`, `displayName`, `color`, `alternateColor`. USE THIS FIRST for every league it covers.
Never use or copy logos or crests; the app shows only codes and colors.

## LEAGUE record
```json
{
  "key": "soccer/eng.1", "name": "Premier League", "sport": "soccer",
  "country": "England", "countryCode": "GB",
  "tier": 1, "teamCount": 20, "season": "Aug-May",
  "espnPath": "soccer/eng.1",            // or null when ESPN has no coverage
  "teamIds": ["eng1-ars", "..."],
  "passport": { "label": "Premier League grounds", "venueIds": ["emirates-stadium", "..."] }   // one entry per distinct home venue, current season
}
```
The passport checklist is what the Passport screen counts ("4 of 20 Premier League grounds"). It lists each current home venue once
(a ground shared by two teams appears once). Use the league's CURRENT membership (this season).

## ESPN league paths known to work
football/nfl, football/cfl, basketball/nba, basketball/wnba, basketball/euroleague, hockey/nhl, baseball/mlb, soccer/usa.1,
soccer/usa.nwsl, soccer/mex.1, soccer/eng.1, soccer/eng.2, soccer/esp.1, soccer/ger.1, soccer/ita.1, soccer/fra.1, soccer/ned.1,
soccer/por.1, soccer/sco.1, soccer/bel.1, soccer/tur.1, soccer/aut.1, soccer/sui.1, soccer/gre.1, soccer/den.1, soccer/nor.1,
soccer/swe.1, soccer/bra.1, soccer/arg.1, soccer/chi.1, soccer/col.1, soccer/uru.1, soccer/per.1, soccer/ecu.1, soccer/par.1,
soccer/ven.1, soccer/bol.1, soccer/uefa.champions, soccer/conmebol.libertadores, soccer/fifa.world, soccer/fifa.worldq.uefa.
Test any other path before using it (`.../scoreboard` returns a JSON with a "leagues" array when valid); if it fails use null.

## Rules
- Accuracy over volume. Verify with a second source when a value looks odd (two teams with the same abbreviation, a color that is
  near-white on white, a venue far from the team's city).
- Current season only. A relegated or promoted club belongs to its current league.
- Reuse existing ids: `/home/user/SportsApp/Witness/Resources/Catalog/teams.json` already has 53 teams with ids like "mlb-chc"; keep those ids
  and values for teams you re-record (do not change them), and mention it in NOTES.
- Do not edit any file outside Tools/teams/. Do not commit.
- Finish with the validator output and counts (teams, leagues, missing venues).
