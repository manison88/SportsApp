# sched2-hockey notes (fetched 2026-10-19)

Audit (SPEC-2 step 1; abbreviation-synonym matched against round 1 sched-hockey): 413 hockey catalog teams in scope.
Covered by round 1 before: 197 (NHL 36/36, AHL 25/25, ECHL 28/29, NCAA men 64/64, NCAA women 43/44; all other leagues 0).
Covered after this round: 209 (+12 IIHF national teams). 2006-2010 now exists for NHL, NCAA men/women and the IIHF teams.
Still no data (204 teams): see "Unlockable". ECHL Greensboro and Delaware women have no round-1 or ESPN data (not in the ESPN/HockeyTech feeds round 1 used).

Sources and seasons (season = year the season starts; national files = calendar year of the event)
- hockey/nhl 2006-2010: ESPN site API, one request per day, preseason/All-Star dropped. 6,582 games, every team 82 regular-season games each season.
  Outdoor/abroad games: ESPN lacked a venue for 5 games, patched by hand (Helsinki 2009 CHI-FLA, Fenway 2010 WC, Heinz Field 2011 WC, McMahon 2011 Heritage; ids x-*). London/Stockholm/Helsinki games noted "At <city>; Neutral site", outdoor home-city games "Outdoor game".
  One game is P (STL-COL 2011-02-02, postponed, replayed). ESPN id 28 = Atlanta Thrashers in 2006-2010 (franchise became the Winnipeg Jets the catalog uses); id 24 is Phoenix.
- hockey/mens-college-hockey 2006-2010: ESPN, 5,511 games (regular season only; ESPN has no postseason or venue for these years). Venue is INFERRED as the home team's rink (note "home rink inferred", taken from round 1's rink per team). Left null ("venue unknown"): non-D1 hosts, and Notre Dame (Joyce Center era), Sacred Heart, American International, Bemidji State before 2010 (rink changed or unverified). Beanpot Monday games between BC/BU/Harvard/Northeastern put at TD Garden (inferred from date and teams). Early-season holiday tournaments are not detectable, so some inferred rinks may be wrong for those games.
- hockey/womens-college-hockey 2006-2010: ESPN, 843 games (2006 and 2010 only the NCAA tournament; 2007-2009 partial). Venue null (ESPN has none). Real source gap.
- hockey/national 2006-2026 (no 2020, cancelled): Wikipedia API (descriptive User-Agent, ~1 req/s, source "wikipedia"): IIHF World Championship top division (all 20 held editions) plus Olympic men's tournaments 2006/2010/2014/2018/2022/2026 (qualification excluded). 1,418 games. Parsed from the Ice hockey box templates; team ids are IIHF 3-letter codes (SLO normalised to SVN, 2018 Olympic Athletes from Russia = OAR, RUS in 2022 = ROC players); names in team-names.json. All games noted "Neutral site".
  Times are Wikipedia's local times converted with the host city's time zone (not cross-checked against IIHF). 2008 WC has 54 games parsed (nominal 56; Wikipedia's page lists 54, not investigated further).

Counts: 35 season files, 14,354 games, validator 0 errors. Venues: 137 distinct (venues-seen.json), 56 in the app catalog, 81 in missing-venues.json (venues validator 0 errors).
Coordinates: catalog copies; round-1 records reused by name; new ones from OSM Nominatim or Wikidata P625 (coordSource says which). Approximate: Milano Rho Ice Hockey Arena (Rho Fiera complex), PalaItalia Santa Giulia (district level, unverified), Taffy Abel Arena (2 decimals inherited from round 1), Mellon Arena (demolished, Wikipedia coordinates).

Unlockable (not fetched; no allowed source)
- AHL 2006-2010 (25 teams) and ECHL 2006-2010 (29): only source is HockeyTech/LeagueStat, not allowed. NOTE: round 1's AHL/ECHL files also came from HockeyTech; the pack builder should hold them back by source if their `source` field says hockeytech. Unlock: an AHL/ECHL data licence, or API-Hockey (paid).
- PWHL (4), SPHL (12), FPHL (17): HockeyTech/league-site feeds; no open licence found. Unlock: league permission or paid API.
- KHL (22), SHL (14), Liiga (15), DEL (14), National League CH (14), Czech Extraliga (14), ICE Hockey League (12), Slovak (11), Norway (10), Poland (9), Denmark (9), EIHL (9), Ligue Magnus (8), Latvia (4), Belarus (4): no ESPN coverage, Wikipedia has standings not game lists, no openly licensed schedule found. Unlock: Sportradar / API-Hockey / Stats Perform (paid) or written permission from each league.
- NHL, ESPN and Wikipedia are the only sources used; api-web.nhle.com works but was not needed for 2006-2010.
- 2011-2026 national-team games (friendlies, Euro Hockey Tour, Four Nations) are not included; only IIHF top-division WC and the Olympics.
