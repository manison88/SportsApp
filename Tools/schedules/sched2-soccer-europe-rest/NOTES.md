# sched2-soccer-europe-rest notes (built 2026-10-19)
Scope: European soccer, every catalog league not in sched2-soccer-europe-top (41 leagues, 520 catalog teams). Validator: 0 errors; missing-venues.json validates (0 errors).
Output: 88 season files in 30 league folders, 18,764 games. team-names.json maps ids to names (catalog id such as `pol1-leg` when the club is in the catalog, else `x-<cc>-<slug>`).

## Sources (allowed only)
- openfootball/europe (CC0, git clone): 70 files. Only 2023-2025 for most countries (plus cze 2018/2020/2026, hun 2018/2020). Local kickoff times converted to UTC; when OF omits a time the game is set to 12:00 local and the note says "kickoff time unknown".
- football-data.co.uk /new CSVs (POL, ROU; FIN, IRL, RUS were already covered): 18 files (pol 2012-2022, 2025, 2026; rou 2012-2015, 2026). CSV times are UK time, verified against openfootball (e.g. Poland 17:00 CSV = 18:00 CEST) and converted.
- Where both exist, the source with more games is used (one source per file). Sofascore (round 1) is not used; its files stay in sched-soccer-europe-east and are held back by the pack builder.
- ESPN returns HTTP 403 from this sandbox, and sched3-espn (CI) is the ESPN path, so no ESPN fetch was attempted. Wikipedia season pages were checked: results matrices carry no dates or venues, so no games were taken from them. football-data.org needs a key. Wikidata used only for venue coordinates (SPARQL/wbsearch, throttled).

## Audit (teams with a file from an allowed source; matched by catalog id or abbreviation)
Teams in scope 520. Before this scope: 77. After: 392 (+315). Per-league before/after is reproducible from the audit script (scratchpad). "Before" undercounts ESPN-fed leagues (fin, irl, isr, mlt, nir, wal) because abbreviations in ESPN files do not always equal catalog abbreviations.
Already covered by allowed sources elsewhere, so skipped here (61 league-seasons): rus 2006-2026 (ESPN), fin 2012-2026 (football-data.co.uk), irl 2009-2026, nir 2008-2025, wal 2008-2024, mlt 2016-2024, isr 2016-2024, rou 2016-2025 (ESPN, sched3-espn), cyp 2025.

## Coverage by league
- Full 21-season gap closed for none: allowed data does not reach back. Best: pol 2012-2026 (15 of 21 seasons, missing 2006-2011), rou 2012-2026 combined with ESPN (2011 missing), rus complete.
- Openfootball-only leagues have 2023-2025 (2-3 seasons): alb, and, arm, aze, bih.1, blr, bul, cro.1, cyp, est, fro, geo, gib, isl, kos, ltu, lux, lva, mda, mkd, mne, smr, srb.1, svk, svn, ukr. cze: 2018, 2020, 2023, 2024, 2026. hun: 2018, 2020, 2023, 2024.
- No 2025-26 season exists in openfootball for most countries (folders stop at 2024-25), so 2025/2026 are missing for many leagues. These are gaps, not errors.

## Unlockable (leagues/seasons with no allowed source)
- soccer/kaz.1 (16 teams, 0 files): API-Football (paid) or Sofascore (not allowed); Kazakhstan Premier League site not checked for reuse terms.
- soccer/cro.2 (15), soccer/srb.2 (16), soccer/bih.2 (16, only promoted clubs appear as opponents): API-Football (paid).
- soccer/isr.1 2006-2015 and 2025-2026 (14 teams): API-Football (paid); ESPN has 2016-2024 only.
- 2006-2022 for alb, and, arm, aze, bih.1, blr, bul, cro.1, est, fro, geo, gib, hun (except 2018/2020), isl, kos, ltu, lux, lva, mda, mkd, mne, smr, srb.1, svk, svn, ukr, cze (except 2018/2020) and cyp, and 2006-2011 pol: API-Football (paid) or football-data.org paid tier. Wikipedia could add results (not dates) only.
- 2025-26/2026-27 for the openfootball leagues: openfootball adds seasons over time; re-run the same builder (scratchpad/w/build.py is not in the repo) when new files land.

## Venues
- Openfootball and football-data.co.uk give no venues. Games are venue-null, except seasons >= 2024 (not ukr, rus) where the home team's catalog home ground is attached and the note says "venue inferred from home team current ground". Treat as likely, not certain (alternate grounds, renamed stadiums). 12,628 of 18,764 games therefore have venue null.
- venues-seen.json: catalog venues used for the inference, plus 33 records for unresolved sched3-espn venues (rus, wal, irl, nir, rou) geocoded from Wikidata P625 (coordinateSource field; one record per source venue id, flagged in `note`).
- missing-venues.json: 26 venues (coordinates from Wikidata P625, not cross-checked against Nominatim, which was rate-limited, so treat as approximate within about 150 m). Terryland Park uses its successor Eamonn Deacy Park (same site). Rodina Stadium and Tsentralnyi/Lokomotiv/Leon Arena were ambiguous and skipped.
- Not geocoded (28 source venues, ambiguous or obscure): wal Recreation Ground (Bath), Deeside, Latham Park, Remax, Llandarcy Park, Genquip; irl UCD Bowl, St Colman's Park, Regional Sports Centre; nir Newry Showgrounds, YMCA Ground; rou Dinamo, Sibiu, Sfantu Gheorghe, Botosani municipal stadiums, Arena Giulesti, Arcul de Triumf; rus Leon Arena, Tsentralnyi (x2), Lokomotiv, Petrovski, New Khimki, Noviye Khimki, Rodina, Khazar, Spartak Novosibirsk, Olimp-2.

## Uncertain
- Openfootball 2025 snapshots for blr, est, fro, geo, isl, lva, ltu and cze 2026 are partial: unplayed or unscored past games are status "O" (no score) or "S" (future). blr 2025: 232 of 240 have no score.
- Team identity across renames is by name matching with manual aliases (e.g. Fehervar/MOL Vidi, Politehnica Iasi, U Craiova 1948 vs FC U Craiova); a few lower-division clubs may be split in two ids.
- Spot check (games per team vs league length): matches for all full seasons; outliers are playoffs/split rounds (pol 2013-2019, cze, cyp, and, bul), rou 2015 (relegation playoff opponents with 2 games) and short leagues (gib, mda, smr).
