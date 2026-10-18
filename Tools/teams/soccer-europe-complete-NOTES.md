# soccer-europe-complete notes (season 2026-27, researched 2026-10-17/18)
Files: soccer-europe-complete-{teams,leagues,missing-venues,fixes}.json. Nothing in the existing soccer-europe-* files was edited.
Validator: `validate.py soccer-europe-complete` = 55 teams, 11 leagues, 29 missing venues, 0 errors; venues/validate.py 0 errors, 0 warnings. Fixes: 179 `{file,id,field,old,new,source}` rows.
Apply order: fixes first (they carry the full new teamIds / passport arrays for fro.1 and mda.1), then merge the complete-* files. `field:"__delete__"` (new=null) means remove that whole team record (fro1-suu, fro1-ttv).
Leagues file: 3 new leagues (and.1, smr.1, gib.1) + 8 DELTA records (`"delta":true`: geo.1, blr.1, srb.1, srb.2, cyp.1, fro.1, cro.2, bih.2) that only list the NEW teamIds/venueIds; teamCount there = number of new clubs only (validator rule), so the merge must union teamIds/venueIds and recompute teamCount.

## Membership check (job a)
Every top flight in the existing file (50 leagues + FRO/MNE/KOS/...) was compared with Transfermarkt's 26/27 (2026 for spring-autumn leagues) club lists and with en/ro/es Wikipedia. All matched except:
- Cyprus: 14 clubs, file had 12 -> added Aris Limassol, Krasava ENY Ypsonas (Karmiotissa + Krasava share Tsirion; Apollon, Aris, AEL share Alphamega).
- Faroe: 2026 season = B36, HB, KI, NSI, B68, Vikingur, 07 Vestur, EB/Streymur + promoted AB Argir, Skala IF. The old file had the 2025 line-up: Sudhuroy and TB Tvoroyri (relegated) removed by fix, 2 added. No Wikipedia 2026 page exists yet; source is Transfermarkt Meistaradeildin 2026.
- Montenegro: 10 clubs confirmed for 2026-27 (Transfermarkt Meridianbet 1. CFL lists Otrant-Olympic, not Jedinstvo). Existing grounds checked against en.wikipedia/club pages (Decic = Tusko Polje, Otrant = Stadion Olympic; Transfermarkt differs, treated as stale).
- Dropped clubs now present: Zeleznicar Pancevo (SRB), Meshakhte Tkibuli + Samgurali Tsqaltubo (GEO), Arsenal Dzerzhinsk (BLR), plus 2nd tiers: Hrvace, Zmijavci (CRO2); Capljina, Jedinstvo Bihac, Radnik Hadzici, Rudar Kakanj, Tomislav, TOSK Tesanj (BIH2); OFK Vrsac, Jedinstvo Ub (SRB2). Nomme United was already in the file (est.1 has all 10).
- NOT added: NK Jadran Luka Ploce (CRO2): the ground (Stadion Jadranovo, Ploce) cannot be located in OSM/Wikipedia/Wikidata; left out per rule.
- Andorra (10 clubs; UE Santa Coloma and Pas de la Casa are out): confirmed by es.wikipedia 2026-27 + Transfermarkt. No club owns a ground; the FAF schedules rounds at Estadi Nacional and Centre d'Entrenament de la FAF (Atletic Escaldes listed there by Transfermarkt), so 9 clubs -> estadi-nacional, Atletic Escaldes -> FAF centre.
- San Marino (16 clubs, same as 2025-26; no 2026-27 article yet). Grounds follow en.wikipedia 2025-26 venue column (Murata/Cailungo/Tre Penne at Fonte dell'Ovo, Folgore at Serravalle B, San Giovanni uses Borgo Maggiore per Wikidata). Sources disagree for Murata, Cosmos, Folgore, Cailungo; village pitches are +-150 m.
- Gibraltar (11 clubs; Manchester 62 folded): en.wikipedia says all games stay at Europa Sports Park this season because Victoria Stadium is being rebuilt, so every club has europa-sports-park (temporary). League name on Wikipedia/Transfermarkt is now "Gibraltar Football League" (ex National League).
- Liechtenstein: no league. FC Vaduz won the 2025-26 Swiss Challenge League (1st of 10) and plays the 2026-27 Swiss Super League (already sui1-vad, rheinpark-stadion). The Liechtenstein Cup (Vaduz 4-3 USV Eschen/Mauren in 2025-26, winner enters the Conference League) feeds no league record. Fixes set sui1-vad and Rheinpark Stadion to Liechtenstein/LI (they were Switzerland/CH).

## Grounds found wrong or temporary (job d)
- Moldova (ro.wikipedia Liga Moldovei 2026-27): Dacia Buiucani -> Zimbru complex (Zimbru-2; mapped to zimbru-stadium, exact pitch not located), Politehnica UTM -> Suruceni, Real Sireti -> Stadionul Nicolae Simatoc (Sireti school pitch in OSM, medium confidence). nisporeni-stadium city was "Chisinau" (fixed to Nisporeni).
- Serbia 2nd tier: Jedinstvo Ub plays at Stadion Dragan Dzajic (Zemun), Bor 1919 temporarily at Kraljevica (= zajecar-city-stadium), Zeleznicar Pancevo at SC Mladost (OSM stadium on Milosa Obrenovica, medium confidence).
- Kosovo: Drita and Gjilani play at the "Gjilan Synthetic Grass Stadium" while Gjilan City Stadium is rebuilt; its location is not in OSM, so both stay on gjilan-city-stadium (UNVERIFIED). Vushtrria is "various" on Wikipedia (kept Vushtrri City Stadium).
- Georgia: Meshakhte plays temporarily at the 26 May Stadium in Tskaltubo (shared with Samgurali); own Vladimer Bochorishvili Stadium (Tkibuli) added as a venue.
- Others: Kazan Arena now Ak Bars Arena; Iceland Fram moved to Lambhagavollur (Ulfarsardalur, coordinates were the old Safamyri ground); Suduva now Marijampole Football Arena (Arvi Arena); Ukraine temporary homes re-confirmed (Bukovyna 3 games at Kamianets-Podilskyi). Malta: Wikipedia gives no per-club grounds (Ta' Qali shared, Hibernians Paola, Hamrun Victor Tedesco) - unchanged.
- 18 existing venue records lacked tenants (e.g. Real Betis at La Cartuja, 10 Maltese clubs at Ta' Qali) plus the new Andorra/San Marino/Cyprus/Serbia sharers: 27 `homeTeams` rows. 53 alias fixes record current/sponsor stadium names from the 2026-27 Wikipedia tables.

## Coordinates (job b)
All 531 existing soccer-europe missing venues were checked against OpenStreetMap (Nominatim): 375 have an OSM feature of the same name within 300 m, 146 more sit on a stadium/pitch/sports-centre or within 250 m of one, 10 were wrong or unverifiable.
Corrected (36 venues, lat+lon rows): Ammanford, Metallurg Jezkazgan (was 40 km off), BSK Krupa na Vrbasu (17 km), Ogre (was Salaspils, 20 km), Rumelange (2 km, was Tetange), Bissen, Bascharage, Sisian, Imishli, Surdulica (town-centre guess), ZELPO Arena, Zemplin Michalovce, Arouca, Fram, Suduva + 21 grounds that had <=3 decimals (refined to OSM/Wikipedia centres) (incl. the validate.py warnings Wildparkstadion 49.02, Juegos Mediterraneos 36.84). Skredelis, Coleraine Showgrounds and Briton Ferry Old Road verified as already right (Skredelis/Ogre city fields fixed).
Still weak: FK Transinvest stadionas (Galine, not in OSM, kept +-500 m), Terrain ZAC Klengbousbierg (zone centroid, +-300 m), Metallurg/Sisian/Imishli (single OSM stadium in town, medium), Dzerzhinsk City Stadium (placed on Stadionnaya street, +-300 m, low), Skala/Sireti/San Marino village pitches (+-150 m).

## Colours (job c)
Replaced 8 of the 9 grey ids (rou1-arg 4E2784/FFF, ukr1-pol FFF/000, svk1-ska 007711/FFF, mkd1-s77 F00/000, arm1-sar 9F3004/322D53, wal1-tbg F00/000, lux1-hos 036F01/FFF, lux1-rwa 00F/FFF). LOW confidence: arm1-sar (website theme colours), mkd1-s77 (inferred from KF Shkendija Tetovo), ukr1-pol (kits white/black but club colours green-yellow).
mda1-rsi (FC Real Sireti) stays grey 5B6770: no Wikipedia/Wikidata/club-site source exists.
New clubs: kit colours from en/de/es Wikipedia infoboxes (primary = home shirt, secondary = first contrasting shorts/socks/sleeve or away shirt); colour names only (hex approximate): and1-cdp (rot-blau), smr1-lfi, smr1-lib, smr1-tpe, gib1-c75, geo1-mes, bih2-tom (blue/white from bs.wikipedia).

## Riskiest data
Moldova Dacia/Zimbru-2 and Real Sireti ground; Kosovo temporary stadium; San Marino club-to-pitch allocation; Dzerzhinsk and Transinvest coordinates; Faroe 2026 line-up (single source).
