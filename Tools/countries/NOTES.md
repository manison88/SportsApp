# Countries reference data: notes

Files: countries.json (253), us-states.json (56: 50 states, DC, 5 territories), canada-provinces.json (13), validate.py (`python3 validate.py`, 0 errors).
Sources: mledoze/countries (names, ISO codes, centre point, currency, languages), Wikidata SPARQL (population 2018+, capital
coordinates, FIFA codes and football-association labels, ISO 639 map), Natural Earth 50m admin-0/admin-1 (bbox, state centroids),
system tzdata zone.tab (time zones), hand tables for UEFA/EU/Schengen/euro and European association names.

- Records: 249 ISO 3166 entries (Antarctica omitted) + England, Scotland, Wales, Northern Ireland (`GB-ENG|SCT|WLS|NIR`, `parent` "GB",
  code3 ENG/SCT/WLS/NIR). Kosovo is `XK`/`XKX`. Gibraltar and Faroes have `parent` GB / DK.
- UEFA = 55 flagged `uefa:true` (England, Scotland, Wales, NI separate; GB itself is not). All UEFA members have `continent: "Europe"`,
  including TR, IL, KZ, AM, AZ, GE, CY (football geography, not strict geography). 63 Europe records in total (adds VA, MC, AX, GG, JE, IM, SJ).
- EU 27, Schengen 29 (BG, RO, HR included), euro 21 states plus de-facto users (AD, MC, SM, VA, ME, XK, AX). `confederation` is derived from continent.
- The team data uses "GB" (not GB-ENG...) as countryCode for England/Scotland/Wales/Northern Ireland; "GB" exists in countries.json so it passes.
  Country names in team data resolve by `name` (spellings adopted: Turkey, Ivory Coast, Cape Verde, DR Congo, Republic of Ireland,
  South Korea, Russia, Iran, Moldova, Czechia, Curaçao, Bolivia, Venezuela, Taiwan, North Macedonia). Extra spellings live in `aliases`.
- Aliased / non-country team values (allowed by validate.py, not records): codes AFC CAF CONCACAF CONMEBOL OFC EU XX and names Africa, Asia,
  Europe, North America, South America, Oceania, International.
- Centre (latitude/longitude) = mledoze country centre point for countries (bbox centre if outside bbox); area-weighted polygon centroid for states.
- bbox is [south, west, north, east], mainland only for FR, ES, PT, NO, NL, DK, GB, CL, EC, AU (overseas parts excluded); RU/US/NZ/FJ/KI never cross
  the antimeridian (RU east clipped at 180, US/AK exclude the Aleutians west of 180). `bboxApprox: true` only on UM.
- Uncertain: non-European `fifaCode`/`footballAssociation` come from Wikidata (213/200 filled; English labels, some outdated names);
  HK has no capital coordinates; BV/HM/TF/UM have null population; Scotland population 5,439,842 is approximate; hand bboxes for micro-states.
- Populations are Wikidata latest (2018+) values, so years differ by country; states use 2020 census-era values.
