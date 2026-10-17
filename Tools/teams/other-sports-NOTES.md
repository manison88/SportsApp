# other-sports notes
Scope reached: tiers 1-5, tiers 1 and 5 complete, tiers 2-4 partial (see skipped). Validator: 482 teams, 44 leagues, 181 missing venues, 0 errors.
Counts: MLB 30, NFL 32, NBA 30, NHL 32 (incl. Utah Mammoth), WNBA 15 (Portland Fire, Toronto Tempo), CFL 9; EuroLeague 20 (ESPN current list);
ACB 11, BSL 7, LBA 8, BBL 8, LNB 8, Greek 5, ABA 7, LKL 4, KLS 2, Israel 4, NBL 10 (clubs also in EuroLeague are in the domestic league's teamIds, one record each);
FIBA national 28 (top 24 + HR, IL, GB, RO); KHL 22, SHL 13, Liiga 15, DEL 14, Swiss NL 14, Czech 14, IIHF national 12;
handball: HBL 14, LNH 7, ASOBAL 5, Denmark 7, Poland 6, Hungary 5, PT 2, NO 2, HR 1, SI 1, RO 1, EHF CL 18 (crossref), national 24; NPB 12, KBO 10, CPBL 6, LMB 16; F1 11.
Existing ids kept unchanged: all 40 MLB/NFL/NBA/NHL ids and the 3 F1 ids (abbreviation, colors, monogram, teamName, locationName, externalIds untouched; new fields added).
Mismatches are why the app needs id matching: existing CWS/TBL/GSW/NYK vs ESPN CHW/TB/GS/NY. US majors keep the catalog's convention locationName=city, teamName=nickname.
Non-US clubs follow SPEC (locationName short club name, teamName full name).
Sources: ESPN teams endpoint (ids, abbreviations, colors for MLB/NFL/NBA/NHL/WNBA; CFL and EuroLeague have no colors or valid abbreviations there, so colors and 3-letter codes are mine).
Everything else (membership, colors, founding years) is from my own knowledge, NOT verified on the web: treat non-ESPN colors as approximate (every KHL, Swiss, Czech, Finnish, Israeli, Mexican colors are least certain).
Venue coordinates: OpenStreetMap Nominatim (ways/nodes of the arena itself) for 170 venues; 17 from Wikipedia/Wikidata; Sydney Qudos Bank Arena (-33.8469, 151.0638) is from memory.
Approximate coordinates (not the building itself): cairo-stadium-indoor-halls (Cairo Stadium centre), racing-bulls-faenza (street), F1 bases are factories, not visit targets.
Wikidata ids: 415 of 482 matched by Wikipedia title and short description, rest null. theSportsDb is null for all new records.
Skipped, venue not located: Azoty-Puławy, GOG, Skanderborg AGF, HBC Nantes, Balatonfüredi KSE, Timrå IK, Saraperos de Saltillo, Bravos de León.
Skipped, uncertain 2026-27 membership: ACB beyond 11 (Zaragoza, Murcia, Breogan, Andorra, Granada...), LBA/BBL/LNB/Greek/BSL mid-table clubs, KLS beyond the two EuroLeague clubs,
Hapoel Be'er Sheva/Eilat, Mega, Slovenian/Croatian/Romanian/Norwegian leagues beyond their EHF CL clubs, remaining LMB clubs, Slavia Praha (venue), Modo.
Uncertain entries: Dubai Basketball colors/venue, Besiktas home arena, Hapoel Tel Aviv arena, Efes (BGM vs Sinan Erdem Dome), Admiral/Amur/Neftekhimik colors, Brose Bamberg colors,
KHL membership (Dinamo Minsk, Lada), Liiga K-Espoo, SHL 13 (Timrå dropped), IIHF top-12 list (Norway and Austria over Kazakhstan), CPBL TSG Hawks home park.
National team home venues are symbolic (a main international arena, e.g. USA basketball = T-Mobile Arena), not a real home; the passport for national, EHF CL and F1 leagues
(team bases) should not be shown as a checklist (see GAPS.md). League ids use sport-specific prefixes to avoid clashes (hdel, hnl, hcze, hbnor, ...).
Venue fixes found in venues.json: Canucks listed at BC Place (added rogers-arena); gran-canaria is the football stadium; estadio-do-dragao has FC Porto handball.
Two missing venues sit near existing ones on purpose: dragao-arena (205 m from estadio-do-dragao) and arena-nuernberger-versicherung (248 m from max-morlock-stadion).
