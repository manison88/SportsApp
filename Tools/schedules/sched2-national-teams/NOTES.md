# sched2-national-teams (fetched 2026-10-19)

Audit (SPEC-2 step 1, over every sched*/ folder incl. sched3-espn): 216 soccer national sides (national-teams.json) + 28 FIBA + 24 handball + 12 IIHF catalog entries.
- Soccer: 216/216 sides had at least one game before (World Cup files, sched3 added WC 2006/2010) and 216/216 after. Real gap was per year: team-years 2006-2026 with no game: 1,617 of 4,536 before, 844 after (what is left is ESPN's own gap, mostly small nations' friendlies and qualifiers before 2015).
- Basketball 28/28 and handball 24/24 had no data before (only held-back FIBA); now covered (partially, see below). Hockey 12 IIHF teams: already done by sched2-hockey, not repeated.

Sources: ESPN site API (soccer, source "espn"; one request per year, per day when a year is cut off) and Wikipedia API (basketball/handball, source "wikipedia", descriptive User-Agent, ~1 req/s). No FIBA, sofascore or HockeyTech data used.

Soccer files (ESPN league keys, season = calendar year of the match; tournaments = edition year):
- 2006-2010 added for: fifa.friendly, fifa.worldq.concacaf/afc/caf/conmebol/ofc (2007-2009), uefa.euro 2008, uefa.euroq 2006-2007, concacaf.gold 2007/2009, conmebol.america 2007, caf.nations 2006/2008/2010, afc.asian.cup 2007, fifa.olympics 2008, fifa.confederations 2009. Already on disk and skipped: fifa.world 2006/2010, fifa.worldq.uefa 2008/2009, uefa.euroq 2010.
- fifa.friendly 2011-2026 rewritten as complete ESPN years (16 files): round 1 held only 41-155 games/year, ESPN has 127-458. Same league/season file name as round 1, so the merge should prefer this scope's file (superset of the round-1 ids).
- caf.nations_qual 2016 and 2020 added with only the games missing from round 1 (23 and 96).
- ESPN returned nothing for: fifa.worldq.uefa 2006/2007/2010 (WC 2010 UEFA qualifying started Aug 2008), fifa.wcq.ply, concacaf.gold_qual and caf.nations_qual before 2011, uefa.nations, concacaf.nations.league, Olympic qualifiers 2006-2010. Youth and women's sides were out of scope.
Basketball/handball files (basketball-national 18 files, handball-national 21), all rows "Neutral site" tournament games, qualification excluded; season = calendar year, 2020 Olympics are in 2021:
- Handball: IHF World Championship 2007-2025 (all 10), EHF Euro 2006-2026 (all 11), Olympics 2008-2024. Box counts look complete (EHF Euro 47 or 65 games per edition, WCh 84-112) but were not checked game by game; Olympics 2016 has 0 (page not parsed).
- Basketball: FIBA World Cup 2006/2010/2014/2019/2023, EuroBasket 2007-2025, Olympics 2008-2024. INCOMPLETE: WC 2006 (20 of ~80, wikitable page not parsed), WC 2014 68, 2023 78 (of 92), Olympics 2020/2024 only 26 of 38 (knockouts missing), EuroBasket 2015/2017/2022/2025 partial. Not invented; missing games are simply absent.
- Team ids are 3-letter codes (SPA->ESP, SER->SRB, LIT->LTU etc. normalised); names in team-names.json join to the catalog ("Spain men's national basketball team").
- Kick-off times are Wikipedia's local times converted with the host city's zone (approximate, no UTC offset in most boxes; 12:00 local when no time).

Counts: 87 season files, 10,117 games, validator 0 errors (16 warnings = leagues with few seasons, expected). Cleaned from ESPN: placeholder fixtures (bracket slots), two replayed postponements, Togo-Ghana AFCON 2010 set to C; 401 past fixtures ESPN never resulted are status O, 224 C (ESPN-cancelled), 18 S (2026 future).
Venues: venues-seen.json 1,532 records, 623 in the catalog, missing-venues.json 681 (venues validator 0 errors, 4 low-decimal warnings from sibling records). Coordinates: catalog, sibling agents' records by ESPN venue id, else Wikipedia coordinates cross-checked with OSM Nominatim (agree within 400 m), else single source; 180 records are flagged approximate:true (single-source OSM or sources disagree). 102 venues (224 games, ~1% of rows, mostly ESPN grounds with no city such as Estadio Nacional Jose Diaz, Shanghai/Shenyang Olympic grounds, small African/Asian stadiums) could not be located: listed in unresolved-venues.json, absent from venues-seen.json; their games keep the venue id/name. sched3-espn/unresolved-venues.json (club venues) was not geocoded here.
Uncertain: ESPN friendly coverage is itself incomplete (many fixtures of small nations absent); 2006-2008 friendlies include B-teams/club-like sides (e.g. "England B", "Melbourne Victory") as ESPN lists them; Asian Cup 2007 and CAF 2008 qualifying have a few unresulted fixtures (status O).

Unlockable
- Basketball national teams beyond the Wikipedia box pages (full qualification windows, AmeriCup/AfroBasket/Asia Cup, 2006 World Cup tables, Olympics 2020/2024 knockouts): FIBA's own APIs are not allowed; unlock = FIBA data licence or API-Basketball (paid), or extend the Wikipedia parser to table pages.
- Handball national: friendlies, qualification, Golden League and Olympic 2016 men (parser gap): EHF/IHF permission or a paid API.
- Soccer friendlies 2006-2014 for small nations and OFC/Asian qualifiers: API-Football (paid) or football-data.org with a key.
