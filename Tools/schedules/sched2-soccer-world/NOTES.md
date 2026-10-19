# sched2-soccer-world notes (fetched 2026-10-19; all data from ESPN's public site API, source "espn")
Scope: soccer outside Europe. Audit script compared the catalog (teams.json, teams-more.json incl. history teams) against every Tools/schedules/sched*/ file (incl. sched3-espn).
Teams in scope 805: with data before 337, after 768. Still no data: MLS NEXT Pro 27, MASL 10 (see Unlockable).
Audit result per league: arg, aus, bol, bra, chi, col, ecu, jpn, ksa, mex, par, per, uru, ven, MLS, NWSL, USL Championship, USL League One already had every team
covered by round 1 / sched3-espn. NCAA men (164 teams) and women (259) and USL Super League (8) had nothing.
I re-queried ESPN's yearly feeds for all 18 non-NCAA leagues 2005-2026 and compared with existing files: ESPN holds nothing more than round 1 has, so no 2006-2010 refetch was needed
(only bol.1 2016, mex.1 2022 and usa.nwsl 2014 differ, and those are ESPN season-label splits, not missing games). Nothing under sched-*/ or sched3-espn/ was changed.
## What was written (37 season files, 24,407 games, 3.2 MB)
- soccer-usa.ncaa.m.1 / soccer-usa.ncaa.w.1: seasons 2006, 2014-2026. Fetched day by day (Aug 1 to Jan 15; 2020 to Jun 1 2021 for the spring-moved season). One folder per ESPN feed (the
  catalog's conference keys such as soccer/usa.ncaa.m.1/acc all point at this feed via externalIds.espnLeague, so teams join on espn id + league soccer/usa.ncaa.m.1).
- soccer-usa.w.usl.1 = USL Super League (catalog key soccer/usa.uslsl): 2025 (2025-26, 129 games) and 2026 (2026-27, 56 games, 23 scheduled). Catalog teams have no espn ids, so team-names.json maps
  id to name; join by name (catalog "Sporting Club Jacksonville" = ESPN "Sporting Jax"). Spokane Zephyr FC is in the feed but not in the catalog.
- soccer-usa.usl.l1.cup (USL League One cup, 2024-2026, 225 games) and soccer-usa.nwsl.cup (NWSL Challenge Cup 2020-2023, 140 games): cups of leagues the catalog has; team ids are the
  ESPN ids of usa.usl.l1 / usa.usl.1 / usa.nwsl, names in team-names.json. The USL cup includes USL Championship clubs.
## Quality / uncertain (read before using NCAA)
- ESPN's NCAA soccer feed is PARTIAL before 2025: about 450-520 men's and 600-850 women's games per season (a real D1 season is ~1,750 / ~2,300), only games ESPN tracked; 2007-2013 is
  empty in ESPN (no games at all) and 2006 looks like a one-off load. 2025 and 2026 are near complete (1,950 / 3,393 and 1,794 / 3,154). Do not read a team's games per season as its full schedule.
  "Teams with data" therefore means at least one game, not a full season.
- Excluded: ESPN preseason events and TBD placeholder teams (conference-tournament slots). Non-D1 opponents are kept with their ESPN ids.
- NCAA venues: ESPN gives a venue only for ~1,500 of the 2025-26 games and none earlier. Where it gave none, the home team's catalog home stadium is used ONLY if the catalog lists that
  venue as a soccer venue, the game is not neutral, and the home team is a catalog team; those 14,924 games carry "venue = home team stadium (inferred)" in the note. about 3,950 other games (all seasons, all five folders) have venueId null.
- venues-seen.json: 962 records. coordQuality: catalog 809 (coordinates copied from the app catalog), osm 55 (Nominatim hit, only accepted within 8 km of the home team's catalog campus, or
  with the city name in the hit), campus-approx 33 (APPROXIMATE: the home team's catalog stadium, probably within 1 km), city-approx 65 (APPROXIMATE: city centre, kilometres off).
  85 ESPN venues have no usable coordinates (ESPN city missing or ambiguous); they stay in the game rows (venues table) but are not in venues-seen.
  "Patriots Point" (Mount Pleasant SC) resolved to the museum, a few hundred metres from the athletics complex.
- missing-venues.json: 35 venues, only the osm-quality ones (approximate ones are left out on purpose so no wrong photo geofence enters the catalog). Validated with Tools/venues/validate.py (0 errors).
  Time zones by state (Kentucky, Indiana, Tennessee, Texas split by longitude), capacity/opened null, homeTeams empty. Venue names are ESPN's current names.
## Gaps and why
- NWSL 2006-2012: the league started 2013 (WPS/WUSA are not catalog leagues). USL Championship 2006-07 and 2010-16, League One 2006-2019, Saudi Pro League 2006-2021: ESPN has no feed
  before 2008/2017/2020/2022 and no allowed source with dates and venues was found (Wikipedia season pages carry only results matrices, no dates or venues).
- USL Super League 2024-25 (inaugural) is not in ESPN. Canada, Korea, China, Africa and the Gulf beyond Saudi have no catalog teams, so nothing was fetched there.
## Unlockable
- MLS NEXT Pro: 27 teams, no ESPN feed (slug rejected) and no allowed per-match source; mlsnextpro.com/MLS data terms not cleared. Would unlock: API-Football (paid) or an MLS data agreement.
- MASL (indoor): 10 teams, no ESPN feed; masl.com schedules, terms not cleared. API-Football does not carry it; a league agreement would.
- NCAA soccer 2007-2013 and the missing games 2006-2024: NCAA stats site is login/scraped (not allowed); conference sites would need one-by-one terms checks; paid API-Football/Sportradar would unlock.
- Saudi Pro League 2006-2021 (18 current clubs): API-Football (paid).  USL Championship pre-2017 (25 clubs) and League One pre-2020: API-Football (paid) or the leagues' own data feeds.
Validator: python3 Tools/schedules/validate.py sched2-soccer-world -> 0 errors (warnings are only the intentionally missing seasons).
