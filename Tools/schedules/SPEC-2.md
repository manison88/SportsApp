# Schedules, round 2: twenty seasons (2006 through 2026) and the teams round 1 missed

Read `Tools/schedules/SPEC.md` first. Everything there still applies (file layout, row format, venues-seen, missing-venues, NOTES, validator),
except the season range, which is now 2006 through 2026 (twenty-one seasons; the validator was updated). Round 1 data in `Tools/schedules/sched-*/`
is read-only for you. Write ONLY into your own scope folder `Tools/schedules/<scope>/` (scopes for this round start with `sched2-`).

## Goal
For every team the app knows (`Witness/Resources/Catalog/teams.json`, `teams-more.json`, `national-teams.json`) have the games it played from the
2006 season on, with the stadium. Round 1 already holds 2011-2026 for ~240 league folders; it is missing (a) 2006-2010 for most leagues and
(b) every season for the leagues whose teams have no data at all.

## Step 1: audit your scope before fetching
Write a small script (scratchpad) that lists, for your scope's catalog teams, which (league, season) have a round-1 file that contains that team
(match the team by `externalIds.espn` + league, or by abbreviation in the file's `teams` map) and which do not. Fetch only what is missing.
Print the audit's counts into NOTES.md (teams in scope, teams with data before, after).

## Sources: only these (we publish this data inside an app, so terms matter)
Allowed: ESPN's public site API; statsapi.mlb.com; api-web.nhle.com; openfootball (github.com/openfootball, CC0); api.openligadb.de; football-data.co.uk
CSV files; league and federation sites that publish schedules openly and permit reuse; Wikipedia/Wikidata via their official APIs with a descriptive
User-Agent and at most 1 request per second (set `source` to "wikipedia"); football-data.org only if its free tier works without a key.
NOT allowed (set aside, do not use): api.sofascore.com, FIBA's site APIs, HockeyTech/LeagueStat feeds, any login-gated or scraped-through-a-browser
source, anything that needs a paid key. If a league's only source is not allowed, do not fetch it; list the league, its team count and the allowed source
that would unlock it (for example "API-Football, paid") in NOTES under "Unlockable".
Set each season file's `source` to the real source name ("espn", "statsapi.mlb.com", "nhle", "openfootball", "openligadb", "football-data.co.uk",
"wikipedia", ...). The pack builder holds back sofascore, hockeytech and fiba by that field, so never mislabel a source.

## Rules that matter
- Accuracy over volume; never invent games, scores or venues. If a season is unavailable, leave it out and say so.
- A team's id in `games` must be the id the catalog uses for that team in that league (ESPN id for ESPN leagues). For non-ESPN sources, add a
  `team-names.json` `{league: {teamId: name}}` in your scope folder so each id can be joined to a catalog team by name.
- Neutral site, playoffs/knockouts and league cups follow SPEC.md. Exclude friendlies except in friendlies leagues.
- Politeness: at most ~6 requests in flight, exponential backoff on 429/5xx, cache raw responses in the scratchpad (not the repo).
- Do not run git. Do not touch app code. Do not edit files outside your scope folder.
- Finish with `python3 Tools/schedules/validate.py <scope>` printing 0 errors, then NOTES.md (<= 40 lines): sources, seasons and leagues covered,
  counts, teams covered before/after, gaps and why, "Unlockable", and anything uncertain.
