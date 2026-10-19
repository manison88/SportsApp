# COVERAGE (sched2-other-leagues, generated 2026-10-19)

Per sport and league: catalog teams, teams with ANY game in a round-1 folder (`Tools/schedules/sched-*`), and teams with any game in ANY schedule folder today (round 1, `sched2-*`, `sched3-espn`, including this scope). League = catalog `leagueKey`; college conferences are rolled up into their parent league. Team join: ESPN id + league file, catalog id, abbreviation (teams.json rows), then normalised team name via each folder's team-names.json. It is a best-effort join, so 'now' may undercount teams whose name could not be matched.

Caveats: (1) round-1 season files hold only source team ids and abbreviations, so MiLB (statsapi ids by level) and a few other leagues cannot be joined to catalog teams by id; their 'round-1 data' and 'data now' counts are lower bounds (MiLB: sched-baseball has levels 11-16 for 2011-2026). (2) 'data now' counts any game from 2006 on; many teams have only some seasons (see each scope's NOTES for seasons). (3) The owner column is the scope that was assigned the league in this round; sched2-other-leagues owns only leagues no other scope was given (the Australian NBL).

Totals: 4589 catalog teams; round 1 covers 2560; all folders cover 3806.


## baseball  (teams 739, round 1 33, now 625)

| league | owner scope | catalog teams | round-1 data | data now | still none |
|---|---|---:|---:|---:|---:|
| baseball/aapb | baseball | 9 | 0 | 0 | 9 |
| baseball/alpb | baseball | 9 | 0 | 8 | 1 |
| baseball/college-baseball | baseball | 295 | 0 | 295 | 0 |
| baseball/college-softball | baseball | 202 | 0 | 200 | 2 |
| baseball/frontier | baseball | 17 | 0 | 0 | 17 |
| baseball/jpn.npb | baseball | 12 | 0 | 0 | 12 |
| baseball/kor.kbo | baseball | 10 | 0 | 0 | 10 |
| baseball/mex.lmb | baseball | 16 | 0 | 15 | 1 |
| baseball/milb-cal | baseball | 8 | 0 | 6 | 2 |
| baseball/milb-car | baseball | 12 | 0 | 7 | 5 |
| baseball/milb-eas | baseball | 12 | 0 | 9 | 3 |
| baseball/milb-fsl | baseball | 10 | 0 | 7 | 3 |
| baseball/milb-int | baseball | 20 | 0 | 14 | 6 |
| baseball/milb-mid | baseball | 12 | 0 | 6 | 6 |
| baseball/milb-nwl | baseball | 5 | 0 | 0 | 5 |
| baseball/milb-pcl | baseball | 10 | 0 | 7 | 3 |
| baseball/milb-sal | baseball | 12 | 0 | 8 | 4 |
| baseball/milb-sou | baseball | 8 | 0 | 4 | 4 |
| baseball/milb-tex | baseball | 10 | 0 | 6 | 4 |
| baseball/mlb | baseball | 30 | 30 | 30 | 0 |
| baseball/pioneer | baseball | 11 | 0 | 0 | 11 |
| baseball/twn.cpbl | baseball | 6 | 0 | 0 | 6 |
| history/mlb | baseball | 3 | 3 | 3 | 0 |

## basketball  (teams 1019, round 1 857, now 872)

| league | owner scope | catalog teams | round-1 data | data now | still none |
|---|---|---:|---:|---:|---:|
| basketball/aba | EU basketball/handball | 7 | 0 | 0 | 7 |
| basketball/aus.nbl | other-leagues (this scope) | 10 | 0 | 10 | 0 |
| basketball/aut.bsl | EU basketball/handball | 1 | 0 | 0 | 1 |
| basketball/bel.bnxt | EU basketball/handball | 7 | 0 | 0 | 7 |
| basketball/bih.prem | EU basketball/handball | 2 | 0 | 0 | 2 |
| basketball/bul.nbl | EU basketball/handball | 2 | 0 | 0 | 2 |
| basketball/cro.hks | EU basketball/handball | 3 | 0 | 0 | 3 |
| basketball/cyp.d1 | EU basketball/handball | 2 | 0 | 0 | 2 |
| basketball/cze.nbl | EU basketball/handball | 3 | 0 | 0 | 3 |
| basketball/den.bsl | EU basketball/handball | 3 | 0 | 0 | 3 |
| basketball/esp.acb | EU basketball/handball | 13 | 0 | 0 | 13 |
| basketball/est.kk | EU basketball/handball | 2 | 0 | 0 | 2 |
| basketball/euroleague | EU basketball/handball | 20 | 20 | 20 | 0 |
| basketball/fin.kor | EU basketball/handball | 3 | 0 | 0 | 3 |
| basketball/fra.lnb | EU basketball/handball | 14 | 0 | 0 | 14 |
| basketball/gbr.bbl | EU basketball/handball | 4 | 0 | 0 | 4 |
| basketball/geo.sl | EU basketball/handball | 2 | 0 | 0 | 2 |
| basketball/ger.bbl | EU basketball/handball | 17 | 0 | 5 | 12 |
| basketball/gre.gbl | EU basketball/handball | 3 | 0 | 0 | 3 |
| basketball/hun.nb1 | EU basketball/handball | 3 | 0 | 0 | 3 |
| basketball/isl.dom | EU basketball/handball | 1 | 0 | 0 | 1 |
| basketball/isr.bsl | EU basketball/handball | 2 | 0 | 0 | 2 |
| basketball/ita.lba | EU basketball/handball | 12 | 0 | 0 | 12 |
| basketball/kos.sl | EU basketball/handball | 2 | 0 | 0 | 2 |
| basketball/ltu.lkl | EU basketball/handball | 7 | 0 | 0 | 7 |
| basketball/lva.lbl | EU basketball/handball | 4 | 0 | 0 | 4 |
| basketball/mens-college-basketball | US football/basketball | 365 | 365 | 365 | 0 |
| basketball/national | national teams | 28 | 28 | 28 | 0 |
| basketball/nba | US football/basketball | 30 | 30 | 30 | 0 |
| basketball/nba-development | US football/basketball | 29 | 29 | 29 | 0 |
| basketball/ned.dbl | EU basketball/handball | 4 | 0 | 0 | 4 |
| basketball/pol.plk | EU basketball/handball | 8 | 0 | 0 | 8 |
| basketball/por.lpb | EU basketball/handball | 3 | 0 | 0 | 3 |
| basketball/rou.lnbm | EU basketball/handball | 1 | 0 | 0 | 1 |
| basketball/rus.vtb | EU basketball/handball | 2 | 0 | 0 | 2 |
| basketball/slo.ks | EU basketball/handball | 1 | 0 | 0 | 1 |
| basketball/srb.kls | EU basketball/handball | 2 | 0 | 0 | 2 |
| basketball/swe.sbl | EU basketball/handball | 4 | 0 | 0 | 4 |
| basketball/tur.bsl | EU basketball/handball | 7 | 0 | 0 | 7 |
| basketball/ukr.suleague | EU basketball/handball | 1 | 0 | 0 | 1 |
| basketball/wnba | US football/basketball | 15 | 15 | 15 | 0 |
| basketball/womens-college-basketball | US football/basketball | 363 | 363 | 363 | 0 |
| history/nba | US football/basketball | 4 | 4 | 4 | 0 |
| history/wnba | US football/basketball | 3 | 3 | 3 | 0 |

## football  (teams 345, round 1 295, now 317)

| league | owner scope | catalog teams | round-1 data | data now | still none |
|---|---|---:|---:|---:|---:|
| football/af1 | US football/basketball | 9 | 0 | 3 | 6 |
| football/cfl | US football/basketball | 9 | 9 | 9 | 0 |
| football/college-football | US football/basketball | 265 | 248 | 250 | 15 |
| football/ifl | US football/basketball | 18 | 0 | 11 | 7 |
| football/nfl | US football/basketball | 32 | 32 | 32 | 0 |
| football/ufl | US football/basketball | 6 | 0 | 6 | 0 |
| history/cfl | US football/basketball | 1 | 1 | 1 | 0 |
| history/nfl | US football/basketball | 5 | 5 | 5 | 0 |

## handball  (teams 150, round 1 24, now 39)

| league | owner scope | catalog teams | round-1 data | data now | still none |
|---|---|---:|---:|---:|---:|
| handball/aut.hla | EU basketball/handball | 5 | 0 | 0 | 5 |
| handball/bel.league | EU basketball/handball | 2 | 0 | 0 | 2 |
| handball/bih.premier | EU basketball/handball | 2 | 0 | 0 | 2 |
| handball/cro.premijer | EU basketball/handball | 3 | 0 | 0 | 3 |
| handball/cze.extraliga | EU basketball/handball | 3 | 0 | 0 | 3 |
| handball/den.hld | EU basketball/handball | 11 | 0 | 0 | 11 |
| handball/esp.asobal | EU basketball/handball | 9 | 0 | 0 | 9 |
| handball/fra.lnh | EU basketball/handball | 13 | 0 | 0 | 13 |
| handball/ger.hbl | EU basketball/handball | 16 | 0 | 15 | 1 |
| handball/hun.nb1 | EU basketball/handball | 8 | 0 | 0 | 8 |
| handball/isl.olis | EU basketball/handball | 7 | 0 | 0 | 7 |
| handball/mkd.superliga | EU basketball/handball | 1 | 0 | 0 | 1 |
| handball/mne.league | EU basketball/handball | 1 | 0 | 0 | 1 |
| handball/national | national teams | 24 | 24 | 24 | 0 |
| handball/nor.rema | EU basketball/handball | 4 | 0 | 0 | 4 |
| handball/pol.superliga | EU basketball/handball | 10 | 0 | 0 | 10 |
| handball/por.andebol1 | EU basketball/handball | 4 | 0 | 0 | 4 |
| handball/rou.lnm | EU basketball/handball | 4 | 0 | 0 | 4 |
| handball/slo.1nlb | EU basketball/handball | 1 | 0 | 0 | 1 |
| handball/srb.superliga | EU basketball/handball | 2 | 0 | 0 | 2 |
| handball/sui.nla | EU basketball/handball | 7 | 0 | 0 | 7 |
| handball/svn.1nlb | EU basketball/handball | 5 | 0 | 0 | 5 |
| handball/swe.hl | EU basketball/handball | 8 | 0 | 0 | 8 |

## hockey  (teams 413, round 1 194, now 195)

| league | owner scope | catalog teams | round-1 data | data now | still none |
|---|---|---:|---:|---:|---:|
| history/nhl | hockey | 4 | 4 | 4 | 0 |
| hockey/ahl | hockey | 25 | 20 | 20 | 5 |
| hockey/aut.icehl | hockey | 12 | 0 | 0 | 12 |
| hockey/blr.extraliga | hockey | 4 | 0 | 0 | 4 |
| hockey/cze.extraliga | hockey | 14 | 0 | 0 | 14 |
| hockey/den.metal | hockey | 9 | 0 | 0 | 9 |
| hockey/echl | hockey | 29 | 19 | 19 | 10 |
| hockey/fin.liiga | hockey | 15 | 0 | 0 | 15 |
| hockey/fphl | hockey | 17 | 0 | 0 | 17 |
| hockey/fra.magnus | hockey | 8 | 0 | 0 | 8 |
| hockey/gbr.eihl | hockey | 9 | 0 | 0 | 9 |
| hockey/ger.del | hockey | 14 | 0 | 0 | 14 |
| hockey/khl | hockey | 22 | 0 | 0 | 22 |
| hockey/lat.ohl | hockey | 4 | 0 | 0 | 4 |
| hockey/mens-college-hockey | hockey | 64 | 64 | 64 | 0 |
| hockey/national | hockey | 12 | 12 | 12 | 0 |
| hockey/nhl | hockey | 32 | 32 | 32 | 0 |
| hockey/nor.eliteserien | hockey | 10 | 0 | 0 | 10 |
| hockey/pol.phl | hockey | 9 | 0 | 0 | 9 |
| hockey/pwhl | hockey | 4 | 0 | 0 | 4 |
| hockey/sphl | hockey | 12 | 0 | 0 | 12 |
| hockey/sui.nl | hockey | 14 | 0 | 0 | 14 |
| hockey/svk.extraliga | hockey | 11 | 0 | 0 | 11 |
| hockey/swe.shl | hockey | 14 | 0 | 0 | 14 |
| hockey/womens-college-hockey | hockey | 45 | 43 | 44 | 1 |

## motorsport  (teams 11, round 1 0, now 0)

| league | owner scope | catalog teams | round-1 data | data now | still none |
|---|---|---:|---:|---:|---:|
| motorsport/f1 | motorsport (handled elsewhere) | 11 | 0 | 0 | 11 |

## soccer  (teams 1912, round 1 1157, now 1758)

| league | owner scope | catalog teams | round-1 data | data now | still none |
|---|---|---:|---:|---:|---:|
| history/mls | soccer outside Europe | 2 | 2 | 2 | 0 |
| history/nwsl | soccer outside Europe | 8 | 8 | 8 | 0 |
| soccer/alb.1 | European soccer | 10 | 7 | 10 | 0 |
| soccer/and.1 | European soccer | 10 | 8 | 9 | 1 |
| soccer/arg.1 | soccer outside Europe | 30 | 30 | 30 | 0 |
| soccer/arm.1 | European soccer | 12 | 9 | 11 | 1 |
| soccer/aus.1 | soccer outside Europe | 12 | 12 | 12 | 0 |
| soccer/aut.1 | European soccer | 12 | 12 | 12 | 0 |
| soccer/aze.1 | European soccer | 12 | 9 | 12 | 0 |
| soccer/bel.1 | European soccer | 18 | 18 | 18 | 0 |
| soccer/bih.1 | European soccer | 10 | 9 | 10 | 0 |
| soccer/bih.2 | European soccer | 16 | 0 | 0 | 16 |
| soccer/blr.1 | European soccer | 16 | 6 | 16 | 0 |
| soccer/bol.1 | soccer outside Europe | 16 | 16 | 16 | 0 |
| soccer/bra.1 | soccer outside Europe | 20 | 20 | 20 | 0 |
| soccer/bul.1 | European soccer | 14 | 9 | 13 | 1 |
| soccer/chi.1 | soccer outside Europe | 16 | 16 | 16 | 0 |
| soccer/col.1 | soccer outside Europe | 20 | 20 | 20 | 0 |
| soccer/cro.1 | European soccer | 10 | 10 | 10 | 0 |
| soccer/cro.2 | European soccer | 15 | 0 | 0 | 15 |
| soccer/cyp.1 | European soccer | 14 | 10 | 14 | 0 |
| soccer/cze.1 | European soccer | 16 | 15 | 16 | 0 |
| soccer/den.1 | European soccer | 12 | 12 | 12 | 0 |
| soccer/ecu.1 | soccer outside Europe | 16 | 16 | 16 | 0 |
| soccer/eng.1 | European soccer | 20 | 20 | 20 | 0 |
| soccer/eng.2 | European soccer | 24 | 24 | 24 | 0 |
| soccer/esp.1 | European soccer | 21 | 21 | 21 | 0 |
| soccer/esp.2 | European soccer | 21 | 0 | 21 | 0 |
| soccer/est.1 | European soccer | 10 | 6 | 10 | 0 |
| soccer/fifa.world | national teams | 216 | 216 | 216 | 0 |
| soccer/fifa.worldq.uefa | national teams | 1 | 1 | 1 | 0 |
| soccer/fin.1 | European soccer | 12 | 4 | 4 | 8 |
| soccer/fra.1 | European soccer | 18 | 18 | 18 | 0 |
| soccer/fra.2 | European soccer | 18 | 0 | 18 | 0 |
| soccer/fro.1 | European soccer | 10 | 7 | 10 | 0 |
| soccer/geo.1 | European soccer | 10 | 7 | 9 | 1 |
| soccer/ger.1 | European soccer | 19 | 18 | 18 | 1 |
| soccer/ger.2 | European soccer | 18 | 0 | 18 | 0 |
| soccer/gib.1 | European soccer | 11 | 7 | 11 | 0 |
| soccer/gre.1 | European soccer | 14 | 14 | 14 | 0 |
| soccer/hun.1 | European soccer | 12 | 11 | 12 | 0 |
| soccer/irl.1 | European soccer | 10 | 5 | 5 | 5 |
| soccer/isl.1 | European soccer | 12 | 0 | 11 | 1 |
| soccer/isr.1 | European soccer | 14 | 13 | 13 | 1 |
| soccer/ita.1 | European soccer | 20 | 20 | 20 | 0 |
| soccer/ita.2 | European soccer | 20 | 0 | 20 | 0 |
| soccer/jpn.1 | soccer outside Europe | 20 | 20 | 20 | 0 |
| soccer/kaz.1 | European soccer | 16 | 6 | 6 | 10 |
| soccer/kos.1 | European soccer | 10 | 10 | 10 | 0 |
| soccer/ksa.1 | soccer outside Europe | 18 | 18 | 18 | 0 |
| soccer/ltu.1 | European soccer | 10 | 7 | 10 | 0 |
| soccer/lux.1 | European soccer | 16 | 0 | 12 | 4 |
| soccer/lva.1 | European soccer | 10 | 10 | 10 | 0 |
| soccer/masl | soccer outside Europe | 10 | 0 | 0 | 10 |
| soccer/mda.1 | European soccer | 8 | 3 | 6 | 2 |
| soccer/mex.1 | soccer outside Europe | 18 | 18 | 18 | 0 |
| soccer/mkd.1 | European soccer | 10 | 5 | 9 | 1 |
| soccer/mlt.1 | European soccer | 12 | 6 | 6 | 6 |
| soccer/mne.1 | European soccer | 10 | 8 | 10 | 0 |
| soccer/ned.1 | European soccer | 18 | 18 | 18 | 0 |
| soccer/nir.1 | European soccer | 12 | 6 | 6 | 6 |
| soccer/nor.1 | European soccer | 16 | 16 | 16 | 0 |
| soccer/par.1 | soccer outside Europe | 11 | 11 | 11 | 0 |
| soccer/per.1 | soccer outside Europe | 18 | 18 | 18 | 0 |
| soccer/pol.1 | European soccer | 18 | 18 | 18 | 0 |
| soccer/por.1 | European soccer | 18 | 18 | 18 | 0 |
| soccer/rou.1 | European soccer | 16 | 16 | 16 | 0 |
| soccer/rus.1 | European soccer | 16 | 16 | 16 | 0 |
| soccer/sco.1 | European soccer | 12 | 12 | 12 | 0 |
| soccer/smr.1 | European soccer | 16 | 14 | 16 | 0 |
| soccer/srb.1 | European soccer | 14 | 13 | 14 | 0 |
| soccer/srb.2 | European soccer | 16 | 0 | 0 | 16 |
| soccer/sui.1 | European soccer | 12 | 12 | 12 | 0 |
| soccer/svk.1 | European soccer | 12 | 11 | 12 | 0 |
| soccer/svn.1 | European soccer | 10 | 10 | 10 | 0 |
| soccer/swe.1 | European soccer | 16 | 16 | 16 | 0 |
| soccer/tur.1 | European soccer | 18 | 18 | 18 | 0 |
| soccer/ukr.1 | European soccer | 16 | 12 | 15 | 1 |
| soccer/uru.1 | soccer outside Europe | 16 | 16 | 16 | 0 |
| soccer/usa.1 | soccer outside Europe | 30 | 30 | 30 | 0 |
| soccer/usa.mlsnp | soccer outside Europe | 27 | 0 | 0 | 27 |
| soccer/usa.ncaa.m.1 | soccer outside Europe | 164 | 0 | 164 | 0 |
| soccer/usa.ncaa.w.1 | soccer outside Europe | 259 | 0 | 259 | 0 |
| soccer/usa.nwsl | soccer outside Europe | 16 | 16 | 16 | 0 |
| soccer/usa.usl.1 | soccer outside Europe | 25 | 25 | 25 | 0 |
| soccer/usa.usl.l1 | soccer outside Europe | 16 | 0 | 16 | 0 |
| soccer/usa.uslsl | soccer outside Europe | 8 | 0 | 0 | 8 |
| soccer/ven.1 | soccer outside Europe | 14 | 14 | 14 | 0 |
| soccer/wal.1 | European soccer | 16 | 4 | 4 | 12 |
