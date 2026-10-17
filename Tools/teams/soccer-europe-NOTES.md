# soccer-europe notes (season 2026-27, built 2026-10-17)
Counts: 886 teams (831 clubs in 57 league records + 55 UEFA national teams), 60 leagues, 531 missing venues, validator 0 errors.
Covered top flights: ENG SCO WAL NIR IRL ESP FRA GER ITA NED BEL POR SUI AUT DEN NOR SWE FIN ISL FRO POL CZE SVK HUN ROU BUL GRE CYP TUR ISR
 CRO SRB BIH SVN MNE MKD ALB KOS UKR RUS BLR MDA GEO ARM AZE KAZ EST LVA LTU LUX MLT. Second tiers: ENG ESP GER ITA FRA (full), SRB/CRO/BIH-FBiH (partial).
Not covered: Andorra, San Marino, Gibraltar (clubs share a few tiny grounds, no per-club ground data); Liechtenstein has no league (FC Vaduz is in the Swiss league).
Sources: membership = ESPN teams endpoint + en.wikipedia 2026-27 season pages (raw wikitext); ESPN was stale for Romania, Israel, Cyprus, Switzerland, so those use Wikipedia.
Montenegro, Faroe Islands, Andorra pages for 2026-27 did not exist: Montenegro = 2025-26 table minus Jedinstvo plus Otrant-Olympic (promoted); Faroe = 2025 season (UNVERIFIED for 2026).
ESPN ids/abbreviations/colors used for 466 teams (duplicate or invalid ESPN abbreviations were replaced: Dundee DND/DUU, Austria Wien AUT/Rapid RAP, Lausanne LAU/Luzern LUZ, Viking VIK, Orgryte ORG, Tiberias TIB).
Colors for non-ESPN clubs and ESPN placeholder values (000000/C60000) come from the home-kit colors in the Wikipedia club infobox (primary = shirt base, secondary = first contrasting shorts/socks/sleeve);
 stripes/pattern shirts only expose one base color, so some secondaries are approximate. Brand colors typed in by hand (blue/gold etc.): Birzebbuga, Osijek, Omonia 29M, Samsunspor, Viborg, Flora Tallinn.
 Neutral grey placeholder 5B6770 (colors unknown, no source found): rou1-arg, ukr1-pol, svk1-ska, mkd1-s77, mda1-rsi, arm1-sar, wal1-tbg, lux1-hos, lux1-rwa.
 National team colors are ESPN's; NED, NOR (ESPN primary==secondary) and RUS (not on ESPN) use Wikipedia kit colors.
Venues: matched to venues.json by name, then by coordinates (<400 m). New grounds: coordinates from Wikidata P625, cross-checked against OpenStreetMap (Nominatim/Photon);
 disagreements >500 m resolved by hand. Venue ids derive from the name; capacity/opened from Wikidata when present (else null).
Approximate coordinates (league location map, may be 300 m+ off): kaz1 Metallurg/Jezkazgan, wal1 Ammanford Recreation Ground, bih1 BSK Stadion Krupa, lva1 Ogre/Skredelis, ltu1 Transinvest, nir1 Coleraine Showgrounds, lux1 Bissen/Bascharage/Rumelange, arm1 Sisian.
Dropped clubs (ground coordinates could not be verified): Zeleznicar Pancevo (SRB), Meshakhte Tkibuli + Samgurali Tsqaltubo (GEO), Arsenal Dzerzhinsk (BLR), Nomme United (EST), plus second-tier: Croatia Zmijavci, Hrvace, Jadran Ploce (CRO2), Capljina, Jedinstvo Bihac, Radnik Hadzici, Rudar Kakanj, Tomislav, TOSK Tesanj (BIH2), OFK Vrsac, Jedinstvo Ub (SRB2). Those league records therefore have teamCount below the real size.
Judgement calls: Real Betis -> la-cartuja and Rayo Vallecano -> Butarque (Wikipedia 2026-27 lists temporary grounds); Ukrainian clubs displaced by the war use the ground Wikipedia lists (Shakhtar Arena Lviv, Zorya Lobanovskyi, Kharkiv Livyi Bereh, Bukovyna Ukraina Stadium);
 Maltese clubs mostly share Ta' Qali (Hamrun = Victor Tedesco, Hibernians = Tony Bezzina); Azerbaijan Shafa home is "TBD" on Wikipedia, Shafa Stadium assumed; Komarno uses ViOn Arena (Zlate Moravce) per Wikipedia.
National teams: Switzerland has no fixed home (St. Jakob-Park chosen); Russia included (suspended) with Luzhniki; Czechia -> letna; Italy -> stadio-olimpico; ids are uefa-<abbr>, leagueKey soccer/fifa.worldq.uefa. New national grounds added: Andorra, Belarus (Dinamo), Faroe (Torsvollur), Gibraltar, Latvia (Skonto), Liechtenstein, Moldova (Zimbru), San Marino.
Existing teams.json ids (53 US teams) are not re-recorded. Uncertain: Wikidata-only coordinates for ~130 grounds had no OSM cross-check; 2026-27 membership of the Faroe Islands and Montenegro as above.
