# sched2-baseball NOTES (fetched 2026-10-19)
Audit (catalog baseball teams, 736 rows): before round 2 = 165 with data (MLB 30, MiLB-named leagues 119, LMB 14, ALPB 2; all from round 1).
After = 666 (adds 495 college teams, 1 LMB, 5 ALPB). Teams without data: Frontier 17, AAPB 9, Pioneer 11, NPB 12, KBO 10, CPBL 6, ALPB 2 (Staten Island, one more), LMB 1 (Nuevo Laredo), college softball 1 (id not served).
MiLB-named leagues (International, PCL, Eastern, Southern, Texas, Midwest, NWL, SAL, California, Carolina, FSL) have no separate folders: they are the statsapi levels baseball/milb-11..14 (round 1 convention); join by name via team-names.json.
Files: 74 season files, 144,564 games, validator 0 errors.
Sources: statsapi.mlb.com (MLB, MiLB, ALPB, Mexican League); ESPN site API team schedules (college baseball/softball). No other source used.
Covered:
- baseball/mlb 2006-2010 (ids = ESPN ids, same mapping as round 1; venue ids statsapi). 30 teams, 161-162 regular games each; playoff rounds noted.
- baseball/milb-11,12,13,14,16 2006-2010 (statsapi team ids; Triple-A includes Mexican League 2006-2010 as in round 1). Rookie includes only sportId 16; short-season A not included. Per-team counts normal (Triple-A 140-152, A 138-150).
- baseball/alpb (Atlantic League) 2010-2023 only. statsapi has no ALPB schedule before 2010 or after 2023. 2020 = 504 games all status C (statsapi lists them cancelled).
- baseball/mex.lmb (Liga Mexicana) 2021-2026 from statsapi sport 23. 2006-2019 LMB games live in milb-11 (round 1 for 2011-2019, this scope 2006-2010). Per-team finals 63-115 per season; statsapi looks incomplete for the 120-game LMB schedule (uncertain).
- baseball/college-baseball and baseball/college-softball 2015-2026 (ESPN team schedules, seasontype 2 and 3, deduped by event id; opponents outside the catalog included). Season = calendar year of the spring season. 2020 is the COVID-shortened year.
ESPN college limit: nothing before 2015 exists in ESPN (empty responses 2006-2014, checked). 2015-2017 are partial (median about 7 games per team, no venues); full schedules start 2018-2019; venues mostly from 2019 (statuses F or P only, no future games in 2026).
Counts: ESPN's college `neutralSite` flag sets note "Neutral site"; postseason note from ESPN headline or "Postseason".
Gaps and why (all allowed-source checks done):
- NPB, KBO, CPBL: statsapi sports 31/32 return 0 games, ESPN has no baseball/jpn.npb, kor.kbo, twn.cpbl scoreboard; no allowed open source found.
- Frontier League, American Association, Pioneer League (independent era), ALPB 2006-09 and 2024-26: statsapi has teams but zero games.
Unlockable: NPB (12 teams), KBO (10), CPBL (6) via a licensed feed (e.g. Sportradar / API-Baseball, paid) or each league's site if reuse terms permit; Frontier (17), AAPB (9), Pioneer (11), ALPB 2024+ (9) via league sites or paid feeds (Sportradar, paid); college baseball/softball 2006-2014 via NCAA/conference sites or Warren Nolan style sources (terms unclear, not used).
Venues: venues-seen.json = 798 rows (506 matched to the app catalog by name+city or <=400 m, or via round 1); missing-venues.json = 247 (validator 0 errors). 236 venues with no reliable coordinates were left out of the tables and their games have venueId null (mainly low-volume college parks and a few Mexican/ALPB parks).
Coordinates: statsapi 155; catalog 327; round-1 values reused where the same statsapi venue id exists; 293 coordSource nominatim-approx (OSM name+city, city must appear in the result; not individually verified; college ones least certain); 6 Wikidata (P625, within 25 km of the city); manual approximate: Shea Stadium, old Yankee Stadium, Metrodome, RFK, Staten Island ballpark. Two wrong Nominatim hits were rejected.
Venue ids: college venue ids are synthetic slugs of name+city (ESPN gives none). College venue region is a US postal code.
Team ids: MLB = ESPN ids; MiLB, LMB, ALPB = statsapi ids (team-names.json maps ids to statsapi names, including round-1 ids); college = ESPN ids.
Neutral site rule for statsapi leagues as in round 1 (home venue <8% of a team's home games).
Raw responses are cached in the scratchpad; scripts re-runnable there.
