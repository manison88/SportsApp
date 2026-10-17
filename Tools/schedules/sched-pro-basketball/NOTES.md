# sched-pro-basketball (fetched 2026-10-17)
Sources: ESPN site API scoreboard for basketball/nba, basketball/wnba, basketball/nba-development (G League). ESPN date ranges return HTTP 400 today, so the
fetcher pulls one day at a time (cached). EuroLeague: ESPN has NO schedule data (empty calendar, 0 events every day), so the official EuroLeague API
(api-live.euroleague.net/v2/competitions/E/seasons/E<yr>/games, free, no key, includes arena + UTC time) was used; source id = "euroleague-api-v2".
Counts (games): NBA 20,380 (2011-2026), WNBA 3,780, G League 6,100, EuroLeague 4,706; total 34,966. Largest season file 92 KB.
Included: NBA regular season, Play-In, playoffs, In-Season Tournament/NBA Cup (group + knockouts, note says which), Mexico City/Paris/London/Berlin/Manchester games
(note "Neutral site", real arena). WNBA regular season, playoffs, Commissioner's Cup final. G League regular season, Showcase Cup, playoffs. Preseason, All-Star, exhibitions excluded.
EuroLeague: regular season, Top 16 (2011-2015), play-in, playoffs, Final Four. Team ids in EuroLeague files are official club codes (map to ESPN ids: euroleague-team-map.json).
NBA/WNBA/G League team ids = ESPN ids (match externalIds.espn in Tools/teams/other-sports-teams.json; G League clubs are not in the app teams file).
GAPS
- G League 2011-2017 (NBA D-League era): NOT covered. ESPN has no D-League events before 2018-19 (0 events checked daily 2011-2018); official stats.gleague.nba.com,
  cdn.nba.com/cdn.wnba.com and gleague.nba.com return 403 from this network; basketball-reference/Wikipedia have standings only (no games or venues). Files for those seasons are absent.
- NBA 2026 (2026-27): ESPN lists 1,200 games (80 per team) as of 2026-10-17; the other ~30 are not published yet. All 2026 games are status S. G League 2026 and WNBA 2026 Finals (6 S) same.
- EuroLeague: 2019 (COVID, 54 games after Mar 2020) and 2021 (28 games of Russian clubs withdrawn Feb 2022) are status C. 2026 has 60 played, 320 S.
- ESPN returns the CURRENT arena name for old events (e.g. Staples Center shows as crypto.com Arena); former names are in venues-seen aliases for the main ones.
Data fixes made: duplicate legacy-id events (WNBA 2011) removed; postponed games that were replayed under another event id were dropped (kept as P only when not replayed:
NBA 2019 LAL-LAC, G League 2019/2021 COVID); NBA 2012 BOS-IND is C (Boston bombing). WNBA 2011-2012: ESPN has no venue for ~238 legacy-id games; venue was inferred from the home
team's single arena that season (or the next seasons') and tagged "Venue inferred" in the note (237 games). Nothing else is inferred.
Spot checks: NBA 82 games/team every normal season (66 in 2011, 72 in 2020; 2019 bubble 64-75; In-Season Tournament knockout teams show 80-81 counted, the rest are the knockout games);
WNBA 34/22/26/30/35/38-44 as scheduled; G League 50-51 (2018, 2022-2025), 2019 41-44 (COVID cut, 102 C), 2020 bubble 15; EuroLeague 30/34/38 RS (2011-15 RS 10 + Top16).
Venues: venues-seen.json 267 records (NBA 49, WNBA 53, G League 77, EuroLeague 88 incl. renamed buildings as separate source ids); 137 matched to the app catalog (name+city or <=60 m);
missing-venues.json has 119 physical venues (validator 0 errors). Coordinates: Nominatim/OSM (mostly arena polygons) cross-checked with catalog for matches; APPROXIMATE (maybe 200-500 m):
Antalya Sports Hall, Ayhan Sahenk Sports Hall (Istanbul), Caja Magica, Arena Nurnberger Versicherung, Rhenus Sport (matched to catalog), Sibur Arena, Sunel Arena, USH CSKA,
Yubileyny Sports Palace, BMO Harris Bradley Center, DeltaPlex Arena, Cox Convention Center, RP Funding Center, Lifetime Activities Center, UCLA Health Training Center, Corteva Coliseum.
Missing-venue capacity/opened are null; homeTeams filled only for venues still in use (>=8 home games, 2025+).
