# sched2-basketball-handball-eu (fetched 2026-10-19)
Scope: 308 catalog club teams in European/other non-US basketball and handball leagues (national teams, NBA/WNBA/college excluded).
Audit (name-token join, pooled by sport across leagues; the catalog has no ESPN ids for these teams): before 53 teams with data, after 139 (+86).
Per-league before/after is in the scratchpad audit; leagues still at 0 are listed under Gaps.

## Sources (all allowed)
- EuroLeague official API api-live.euroleague.net/v2 (same free, keyless feed round 1 used, source "euroleague-api-v2"): EuroLeague 2006-2010 (1,026 games) and EuroCup 2006-2010 (938 games). Round 1 starts at 2011.
- api.openligadb.de (source "openligadb"): Handball-Bundesliga 2010-2015 full seasons plus 2016 and 2022 partial, EHF Champions League 2010-2016, Basketball Bundesliga 2010 partial.
- ESPN has no feed for any of these leagues (sched3-espn FETCH-LOG: "no usable feed"), so nothing was taken from ESPN. Wikipedia season pages only give results grids (no dates or venues) so were not used.
Totals: 5 leagues, 26 season files, 5,559 games, validator 0 errors.

## Files and counts
basketball/euroleague 2006-2010: 230/231/188/188/189 games. basketball/eurocup 2006-2010: 149/326/151/156/156.
handball/ger.hbl: 2010-2013 and 2015 = 306 each, 2014 = 342 (19 clubs, HSV Hamburg's insolvency season), 2016 = 162 (partial), 2022 = 278 (partial).
handball/ehf.cl: 148 per season 2010-2014, 200 in 2015, 172 in 2016 (groups and knockouts; Final Four rows noted "Neutral site").
basketball/ger.bbl 2010: 171 of ~306 games (partial).
team-names.json maps every source id to a club name (EuroLeague/EuroCup ids are club codes; openligadb ids are its teamIds).

## Uncertain / caveats
- openligadb has venue data for almost no handball games (about 9 of 4,000), so ger.hbl and ehf.cl games have venue null. Venue was not inferred from the home club.
- openligadb status "O" = past-dated game with no result recorded (2015 last 14 games, 2016, 2022, BBL 2010). They are real fixtures but whether they were played is unknown.
- EuroLeague API venue strings are noisy (typos, wrong cities such as "Andreas Papandreou Stadium, Kazan"); I remapped 135 distinct venue strings to 135 physical venues by hand (home-club context) and rewrote venue ids in the season files. The Siemens/Olivia/Palais des Sports/Zenith name clashes were split by home club.
- Coordinates: Nominatim/OSM cross-checked with round-1 records and the catalog. 47 venues match the catalog (name + sport + <=400 m, or <=60 m). APPROXIMATE (venues-seen "coordinates": "approximate"): ush-cska, khodynka, zalgirio-old (Kaunas Sports Hall), ayhan-sahenk, goldberg, malcha, cez-arena (Lysa nad Labem hall), azovmash, triumph, pala-del-mauro, makis-liougas, metro-west, panellinios, ataturk (Ankara), visnjik, tipsport-zgorzelec, ovarense, gmunden, weser-ems, rhein-energie/gew-dome (Cologne, hall identity unclear), olympic-bb-stadium (assumed OAKA). CITY-CENTRE ONLY: ahmet-comert, gan-ner, kfar-blum, lamia, olymp-krasnye, siauliai. Treat these as unverified.
- missing-venues.json: 88 venues not in the catalog (validator 0 errors); capacity/opened null, homeTeams empty (historic venues).

## Gaps and why
- No allowed source exists for: ACB, LNB Betclic Elite, Lega Basket, Greek/Turkish/Israeli/Adriatic (ABA), Polish, Baltic, Nordic and other domestic basketball leagues; StarLigue, Liga ASOBAL, Danish/Polish/Hungarian/Nordic/Swiss and other handball leagues; handball-bundesliga 2006-09, 2017-21, 2023-25 (openligadb has no/empty sets). EuroLeague 2026 gap: none (round 1 holds 2011-2026).
- Leagues with 0 teams covered after this run: basketball fin.kor, swe.sbl, den.bsl, hun.nb1, rou.lnbm, cro.hks, slo.ks, kos.sl, aut.bsl, isl.dom, est.kk, ukr.suleague; handball aut.hla, cze.extraliga, bel.league, isl.olis, bih.premier, mne.league.
- EuroCup is not a catalog league; kept because it adds games for catalog clubs.

## Unlockable
- All domestic basketball leagues (about 150 clubs): API-Football or SportRadar/Genius Sports (paid); official league sites (acb.com, lnb.fr, legabasket.it, easycredit-bbl.de) publish schedules but their terms do not clearly permit reuse; FIBA/sofascore are not allowed.
- Domestic handball (about 150 clubs): handball-bundesliga.de, lnh.fr, asobal.es, hbold.dk and EHF's site (terms unclear); EHF CL 2017-2025 and HBL 2017-2025: paid data (SportRadar/Genius) or written permission from the leagues.
- Venue-level data for HBL/EHF games 2010-2016: league match reports (not open).
- Unresolved ESPN venues in sched3-espn/unresolved-venues.json were not handled (out of this scope's data).
