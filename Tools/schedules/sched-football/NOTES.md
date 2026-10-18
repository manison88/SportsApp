# sched-football notes (fetched 2026-10-17)
Leagues/seasons: football/nfl 2011-2026, football/cfl 2011-2026 (no 2020), football/college-football (FBS) 2011-2026, football/college-football-fcs (FCS) 2011-2026.
Total 32,401 games: NFL 4,369, CFL 1,240, FBS 13,848, FCS 12,944. Largest season file ~76 KB, no season needed splitting.
Sources: ESPN site API (NFL, college, CFL 2021-22); Wikipedia team season pages (CFL 2011-19, 2023-26: ESPN has no CFL data outside 2021-22).
ESPN quirks handled: date ranges are rejected (400), so NFL/CFL use `dates=<year>&seasontype&week`, college uses weekly queries plus one query per day (groups 80 and 81) merged.
 `limit=1000` silently truncates to 25 events from 2024 on (limit=300 used there). Some scoreboard days contain empty `{}` events; the missing games were recovered from each team's schedule endpoint.
College classification: a game is in the FBS file if either team's conference is an FBS conference that season, in the FCS file if either is FCS (FBS vs FCS games are in both files; D2/D3-only games are excluded).
 The 2020 FCS spring season (Feb-May 2021, ESPN seasontype 5/6) is stored as season 2020. 2020 has many P/C games (COVID) kept as P/C.
NFL: regular season + playoffs + Super Bowl, incl. London, Mexico City, Frankfurt, Munich, Sao Paulo, Madrid, Dublin, Berlin, Paris, Melbourne, Toronto (BUF). Pro Bowl and TBD placeholder playoff games excluded. 2022 BUF-CIN is status C.
CFL: 2020 cancelled (no file). CFL 2011-19/2023-26 event ids are synthetic ("wp<date><home><away>"); team ids are ESPN CFL ids. Parser cross-checked against ESPN 2021/22: same games and venues except 3 score diffs and the Grey Cup venue (ESPN used for those years).
 Wikipedia pages without kickoff times (2011-13 and a few later rows) get 19:00 local with note "Kickoff time approximate". 2011-13 pages without a venue column use the home team's stadium (Hamilton 2013 = Guelph, Moncton games from the neutral-site list).
 2021 ESPN ghost events (EDM@TOR 8/26, MTL@HAM 11/21, never played) removed; 2022 Grey Cup venue corrected to Mosaic Stadium (ESPN had Winnipeg).
Spot checks: NFL 16 games/team (17 from 2021) in every season; FBS teams 12-16 games, FCS 9-16 (2020 excluded); CFL 18 (14 in 2021, 72/77 games in 2011-13 with 8 teams). Outliers: none except 2020.
Venues: ESPN had no venue for ~215 early college games (2011-13 mainly). 85 were filled with the home team's dominant stadium from the nearest season (note "Venue inferred from home stadium"), ~213 remain null.
Status "O" = game in progress when fetched (2026-10-17). Statuses P/C are kept when not replayed; postponed games that were replayed are dropped.
venues-seen.json: 637 records (per league + ESPN venue id); 419 matched to the app catalog (name+city, or hand-reviewed distance matches), 191 physical venues in missing-venues.json (validator 0 errors).
Coordinates: catalog copy (393), Wikidata P625 agreeing with OSM Nominatim within 250 m (131), manual (13). 74 records are approximate (OSM only 49, OSM generic/city-level 10, Wikidata/OSM disagreement 14):
 mostly small FCS/D2 venues (e.g. Jahna Field is only the city centre of Winter Haven, J.W. Babb Stadium and Grande Stadium approximate). Demolished stadiums (Georgia Dome, Candlestick, Ivor Wynne, Taylor Field, Canad Inns, Empire Field, SDCCU, Robertson, Metrodome) are listed separately, not merged into their successors.
ESPN reuses names with sponsors; `name` is the latest, older names are in `aliases`.
