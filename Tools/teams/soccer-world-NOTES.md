# soccer-world notes
Counts: 327 teams (291 clubs, 36 national), 21 league records, 128 missing venues. validate.py soccer-world: 0 errors (venues/validate.py on the missing file: 0 errors, 0 warnings).
Leagues covered (ESPN ids/abbreviations/colors first): MLS 30, NWSL 16, Liga MX 18, Brasileirao 20, Argentina 30, Chile 16, Colombia 20, Uruguay 16, Peru 18, Ecuador 16, Paraguay 11 of 12, Venezuela 14, Bolivia 16, Saudi Pro League 18, J1 20 (2026-27), A-League Men 12.
National teams: 32 non-UEFA 2026 World Cup teams + Bolivia, Chile, Peru, Venezuela (CONMEBOL members with catalog stadiums). 5 confederation league records (soccer/nat.conmebol|concacaf|caf|afc|ofc, espnPath null); passport = home stadiums.
Existing catalog ids kept untouched: mls-chi, mls-mia, mls-clb, mls-ne, mls-stl (all fields/colors/abbreviations as in catalog; espn ids and venues added).
Venue sourcing: catalog first (all MLS/NWSL/CPL-adjacent US grounds, 8 venues per South American country); the rest from Wikidata P625 (SPARQL) with capacity/opened. Stadium assignments come from the 2026 / 2026-27 Wikipedia season pages (current grounds, incl. temporary ones: Aguilas Doradas at Cincuentenario, Guarani + Rubio Nu at La Arboleda, Olimpia + Luqueno at Erico Galeano, Metropolitanos/Caracas/La Guaira/UCV at Olimpico UCV, Liverpool (UY) at Parque Viera).
Hand-placed coordinates (no Wikidata hit): Estadio Olimpico Jaime Teran (Atuntaqui) and Complejo Deportivo Socialista/La Bombonerita (Puerto Cabello) from OpenStreetMap; Estadio Dr. Carlos Villegas (Entre Rios) from its Wikipedia coordinates.
Skipped, with reason:
- Sportivo Ameliano (Paraguay): new Villeta ground (opened 2025) could not be geolocated reliably.
- Canadian Premier League (no ESPN coverage, colors unverifiable), USL Championship (no USL venues in catalog), K League 1 (no ESPN feed), China CSL, Egypt, Morocco, South Africa, Israel: not verified in the time available. Skipped rather than guessed.
Mexico: catalog had no Mexican venues, so all 16 distinct Liga MX grounds are in the missing file. Atlante and Cruz Azul both play at Estadio Azteca (Banorte) in the Apertura 2026 (news search); Atlante's later arrangement is unconfirmed.
Colors: from ESPN where plausible (MLS, NWSL, Liga MX, Saudi, Aus). South American ESPN colors are mostly placeholders, so primary/secondary are well-known club colors. For about 60 lesser clubs the value is taken from the Wikipedia home-kit template (body/shorts hexes) or its prose. Treat these as medium confidence.
Lowest-confidence colors (no kit data found, ESPN/memory used): Gimnasia Mendoza, Central Cordoba SdE, Real Oruro, ABB, Abha, Al-Fateh, Al-Hazem, Al-Taawoun, San Lorenzo (PY), Albion/Cobresal only partly corroborated, Boston Legacy, San Diego FC, Bay FC.
Other uncertain entries:
- National home grounds are conventional choices: USA (SoFi, no fixed home), Australia (Accor), Ghana (Baba Yara), Iraq (Basra), Qatar (Khalifa), Saudi (King Fahd), Uzbekistan (Milliy), NZ (Eden Park), Haiti (Sylvio Cator).
- Abha plays at Prince Sultan bin Abdulaziz Sports City Stadium (also called Al-Mahalah); Saudi teams with two grounds use the first-listed one.
- Argentina: abbreviation RIV is River Plate; Independiente Rivadavia uses IRI (ESPN also says RIV).
- externalIds.wikidata filled only where a club label matched exactly (205 clubs); theSportsDb null except the 5 kept MLS teams. Venue `leagues` are ESPN paths (ksa.1, jpn.1, aus.1 verified via the teams endpoint).
- Chicago Stars (NWSL) home is Martin Stadium (Evanston) per catalog; NYCFC still at Yankee Stadium.
