# sched-hockey notes (fetched 2026-10-17)

Sources
- hockey/nhl, hockey/mens-college-hockey, hockey/womens-college-hockey: ESPN site API scoreboard, one request per day (date ranges return 400 for hockey), team ids = ESPN ids. Preseason, All-Star and exhibition events dropped.
- hockey/ahl and hockey/echl: official HockeyTech "modulekit" JSON feed behind theahl.com / echl.com (public site key, view=schedule per season id; ESPN has no AHL/ECHL). Team ids are HockeyTech ids, venue ids are HockeyTech "location" ids. Kept: regular season + Calder Cup / Kelly Cup playoffs; dropped preseason/all-star/exhibition and unplayed "if necessary" games. Times come from GameDateISO8601 converted to UTC.
- Season = year the season starts (2026 = 2026-27, partly scheduled "S"). Playoffs belong to the season they close.

Counts: NHL 20,995; AHL 18,338; ECHL 15,811; NCAA men 17,591; NCAA women 1,657; total 74,392 games, 80 season files, validator 0 errors.
Venues: 397 distinct (venues-seen.json, records merged within a league when same site/renamed, aliases listed); 136 in the app catalog, 192 physical venues in missing-venues.json (validator 0 errors).

NHL notes
- Identity: ESPN id 28 = Winnipeg Jets throughout (2011 is the Jets' first season; Thrashers' 2010-11 is out of range). Id 24 = Phoenix (PHX, through 2013) then Arizona (ARI), last season 2023; Utah (id 129764, "UTAH") from 2024; Seattle 124292 from 2021; Vegas 37 from 2017.
- Special games are included with real venues (Winter Classics, Stadium Series, Heritage Classics, Global Series, Lake Tahoe 2021, 2011 Helsinki/Stockholm/Berlin openers, 2020 Edmonton/Toronto bubble, 4 Nations Face-Off 2025 as 7 games with ids 47836-47844 at Bell Centre / TD Garden; season 2024). Six outdoor games had no ESPN venue and were patched by hand (venue ids "x-..."): 2016 WC Gillette, 2016 SS TCF Bank and Coors Field, 2019 Heritage Mosaic Stadium, 2020 WC Cotton Bowl, 2020 SS Falcon Stadium.
- 2012 (lockout) = 720 + 89 playoff games; 2019 contains 189 cancelled (C) COVID games and the Aug-Sep 2020 bubble playoffs; 2020 = 56-game season; 2021 has 99 postponed (P) COVID games (replayed under new ids). Every team has 82 regular-season games in full seasons.
- ESPN returned NCAA events inside hockey/nhl for Oct 2012; they are filtered out.

AHL / ECHL
- AHL 2019 is the cancelled-by-COVID season (941 games, no playoffs); 2020 is the shortened 2020-21 season. ECHL 2019/2020 likewise. Outliers: AHL Portland 2013 (37 games), ECHL Orlando 2012-16 and Kalamazoo 2012 / Stockton 2013 (40-60 games, expansion/relocation or feed gaps, not verified).

NCAA
- ESPN has NO venue for college hockey before roughly 2022. Men: venue is INFERRED as the home team's rink (rinks_men table by team and era, note "home rink inferred"); neutral/tournament games use the known site where certain (Beanpot TD Garden, Frozen Four/regional host arenas, Hockey East final TD Garden, Friendship Four Belfast, Connecticut Ice Bridgeport), otherwise venue is null (18 games, note "venue unknown"). Sacred Heart (Webster Bank Arena) and Stonehill (Bridgewater Ice Arena to 2024, Warrior Ice Arena from 2025) eras are uncertain; non-D1 home teams have null venue. Men's conference and NCAA tournaments before 2021 are mostly missing in ESPN (about 15 postseason games per season from 2021; earlier tournament games flagged only by notes).
- Women: ESPN coverage is essentially only the NCAA tournament (5-10 games) for 2011-2024 (no venue) and full schedules from 2025 (with ESPN venues). 2019 empty (season cancelled). This is a real source gap; no other free stable women's feed was found.

Coordinates: catalog venues copied from the catalog; others OSM Nominatim (checked within 30 km of the city) or Wikidata P625. Approximate (city/campus level, flagged coordSource "approx..."): Class of 1965 Arena, Centene Community Ice Center, Mayo Clinic Health System Event Center, Wichita Ice Center, RWJ Barnabas Hockey House, MHG Ice Centre, Lindenwood Ice Arena, Freitas Ice Forum; Taffy Abel Arena has 2-decimal WD coordinates. OSM/Wikidata picks were not all individually surveyed; renamed arenas were resolved by current name.
