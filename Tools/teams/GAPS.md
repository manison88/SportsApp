# What the app and seed pipeline need so every team gets a USA-style record (scope: other-sports)
Read: Models.swift, Library.swift, PassportView.swift, GameLookup.swift, Tools/build_seed.py, Catalog/ballparks.json. No app file was edited.

## (a) Merging teams.json and a new leagues.json in build_seed.py
Today `teams.json` is a plain `shutil.copy(SeedData/teams.json -> Catalog/teams.json)` (53 hand-kept teams); venues already merge research files.
1. Load SeedData/teams.json first (its 53 ids and values win), then glob `Tools/teams/*-teams.json`. Merge by `id`; on a clash keep the seed values and only fill the new fields
   (kind, leagueKey, country, countryCode, homeVenueId, founded, tier, externalIds.espn/espnLeague/wikidata). Fail the build on: duplicate id, duplicate (leagueKey, abbreviation),
   duplicate (espnLeague, espn), accent contrast < 3 on #0B0C10. ESPN ids repeat across leagues (id 5 is a Browns and a Guardians), so the key is always (espnLeague, espn).
2. Add `Tools/teams/*-missing-venues.json` to the existing `research` glob in the venue loop (same_place dedupe applies). A missing venue may merge into an existing venue with a
   different id, so the loop must record `remap[old_id] = kept_id` and rewrite every team `homeVenueId` and every league `passport.venueIds` through it before writing.
3. Glob `*-leagues.json`, merge by `key`: union teamIds, union passport.venueIds (order kept, deduped), recompute teamCount from the merged teamIds. Then validate: every teamId exists,
   every venueId exists in the final venues.json, every team's leagueKey has a league. A club in two leagues (EuroLeague + ACB, EHF CL + HBL) appears in both teamIds; its team record has one leagueKey.
4. Write compact JSON (`separators=(",", ":")`, drop null externalIds) to `Catalog/teams.json` and `Catalog/leagues.json`; keep `ballparks.json` generated from the MLB league (venueId + team code) until the app stops reading it.
5. Fixes found in venues.json while linking: Vancouver Canucks are listed under BC Place (Rogers Arena was missing; added in other-sports-missing-venues.json, BC Place tenants need a patch);
   `gran-canaria` is the football stadium (CB Gran Canaria plays at Gran Canaria Arena, added); `estadio-do-dragao` lists FC Porto handball (Dragão Arena added); hallenstadion, wiener-stadthalle,
   mvm-dome, avicii-arena have no homeTeams. `venues.leagues` is empty for every non-ESPN league, so GameLookup.clubLeagues(for:) falls back to guesses (see c).

## (b) GameLookup.team(from:) / apply: match a schedule team to the catalog instead of a gray custom team
Now: `team(from:)` always builds `Team(id: "espn-<league-slug>-<espnId>", colors: ESPN color or 3A4150)` and `Library.addTeam` reuses a catalog team only when sport + abbreviation + locationName all match.
That fails for every real mismatch: ESPN gives CHW/TB/GS/NY where the catalog has CWS/TBL/GSW/NYK, "Indians" vs "Guardians", "Red Blacks" vs "Redblacks", EuroLeague abbreviations like "AX ARMANI".
Proposed order in `Library.catalogTeam(league:espnId:abbreviation:name:)`, built from two dictionaries filled once in `loadCatalog()`:
1. `byEspn[espnLeague + "#" + espnId]` (the record's `externalIds.espnLeague` equals GameLookup's `game.league` path, e.g. "hockey/nhl"). National teams also go in `byEspnNational[sport + "#" + espn]` because ESPN uses one id across fifa.world, uefa.euro, nations league.
2. `byLeagueAbbr[leagueKey + "#" + ABBR]`, only when the abbreviation is unique in that league.
3. normalized `locationName + teamName` inside the same league (token compare like `tokens()`).
4. Otherwise create the custom team as today, but set `league`, a `leagueKey` and a computed accent (the existing luminance rule) so it still renders.
`apply` then uses `library.catalogTeam(...)` for home and away. One-time migration on `loadStore`: re-resolve each persisted `customTeams` entry; on a hit, rewrite `homeTeamId/awayTeamId/rootingForTeamId` in games and `profile.favoriteTeamIds`, and drop the custom entry.
Model changes (decoding is already tolerant, extra JSON keys are ignored today): `Team` gets `kind`, `leagueKey`, `countryCode`, `homeVenueId`, `founded`, `tier`; `ExternalIds` gets `espnLeague`, `wikidata`.
Leagues without ESPN coverage (handball, KHL, NPB...) have `espnPath: null`: no schedule lookup, games are logged manually, but the picker, colors, codes and passport still work.

## (c) Passport: from MLB-only ballparks to per-league checklists
Now: sport chips come from `Sport.allCases` present in games (baseball always); labels are hard-coded in `league(_:)`; only `.baseball` has `library.ballparks` (30), the SegmentBar and ghost tiles; every other sport lists earned stamps only.
`stamps()` also scans `allTeams` with `first{}` per ballpark and `library.venue()` is a linear search, both run inside `body`.
Target:
- Add `League` (key, name, sport, countryCode, tier, teamCount, season, espnPath, teamIds, passport{label, venueIds}) and `Library.leagues`, `league(key)`, `earnedVenueDates: [venueId: Date]` (cached when games change).
- Selection state becomes `leagueKey`, not `Sport`. A visit counts for a league when the venue is in `passport.venueIds` AND the game belongs to that league: `game.source?.league == espnPath`, else the home team's `leagueKey`, else sport equality. This keeps Crypto.com Arena a stamp for the NHL only when you saw the Kings.
- Screen 1, Passport home: hero = distinct venues across all leagues; below it "collections" cards (name, "4 of 20 Premier League grounds" from `passport.label`, SegmentBar) for leagues with progress, your favorite teams' leagues, then "Add a collection".
- Screen 2, league checklist: today's grid (earned stamps + ghost tiles of unvisited venues, code = abbreviation of the first home team at that venue, shared venues show "A / B"), hero "4 of 20", SegmentBar for every league instead of baseball only.
- Screen 3, picker (sheet): search field, Sport segmented control, sections by country, rows "Name - N venues - 3/20". Needed because 100+ leagues cannot be chips: pin leagues automatically (leagues of favorite teams and leagues with games), remember the last one.
- Do not give checklists to `national` leagues, EHF Champions League or F1 as shipped: their `passport.venueIds` are symbolic home halls or team bases. Suggest an optional `passport.kind` ("homeVenues" | "circuits" | "none"); F1 should be the circuit calendar.
- `GameLookup.clubLeagues(for:)`: fill `venues.leagues` for the new espnPath leagues (EuroLeague already); non-ESPN leagues stay [] on purpose.

## (d) Data size and performance
This scope minified: teams 218 KB (482 teams, about 450 B each), leagues 25 KB (44), missing venues 59 KB (181). If all agents reach ~3,500 teams: teams.json about 1.5 MB, leagues about 200 KB, venues.json grows from 446 KB toward ~700 KB.
Decoding 4k small Codable structs is tens of ms but runs on the main actor in `Library.init`; move it to a detached task and show the shell first.
Ship minified, omit null externalIds, consider `teams-<sport>.json` loaded on demand (the catalog picker needs one sport at a time; the lookup indexes need all).
Replace `venues.first{}` and `teams(for:)` (sort per call) with dictionaries/sorted caches; Passport and pickers must filter by league, never list `allTeams`.
The bundle compresses about 5:1 in the IPA; the cost is memory and launch, not download size. No logos or crests are bundled (codes and colors only).

## (e) Prioritized work, sized (S < 0.5 d, M 1-2 d, L 3-5 d)
1. P0 build_seed.py: teams/leagues/missing-venues merge, id remap, validation, compact output (M).
2. P0 Models + Library: new Team/ExternalIds fields, League model, byEspn/byLeagueAbbr indexes, venue dictionary (M).
3. P0 GameLookup.team(from:) catalog-first matching and customTeams migration, unit tests with saved scoreboard JSON incl. CHW/CWS, TB/TBL, EuroLeague (M).
4. P1 Passport per-league checklist screen replacing ballparks.json (M) and the home/collections screen (L).
5. P1 League picker with search/sections/pins, favorites-driven defaults (M).
6. P1 Fix venue data flagged in (a)5 and fill `venues.leagues`/homeTeams for the new leagues (S).
7. P2 `passport.kind` for national/F1/EHF, F1 circuit calendar (M).
8. P2 Team picker for manual entry filtered by league with country grouping (M).
9. P3 Lazy per-sport loading and off-main decoding (S).
