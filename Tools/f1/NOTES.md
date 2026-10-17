# F1 dataset notes (built 2026-10-17)

Counts: circuits 48 (25 on the 2026 calendar incl. cancelled Bahrain + Jeddah, 8 used only 2018-2025, 15 historic still standing);
calendar 200 events 2018-2026 (190 completed, 6 scheduled, 4 cancelled); teams 11; drivers 44 (everyone who started a race 2018-2026).
Validator: `python3 Tools/f1/validate.py` prints 0 errors (1 warning: 2021 Belgian GP has no fastest lap, only 1 racing lap was run).

Sources: ESPN `racing/f1` scoreboard (events, sessions, ids, teams, 2026 standings), Jolpica/Ergast (results, qualifying, sprints, fastest laps,
driver codes), Wikipedia infoboxes + race intros (length, turns, lap record, wet/red-flag facts), Wikidata P625, OSM track centerlines
(github bacinger/f1-circuits), Nominatim cross-checks. Weather API quota was exhausted, Overpass was unreachable.

Cross-checks: 189 of 189 ESPN podiums equal Jolpica's (2018 Belgian lacks an ESPN `order` but names match); season points leaders after the last race equal
ESPN's 2026 standings (Antonelli 340, Russell 238) and the known 2018-2025 finals; lap records agree between Wikipedia and Jolpica wherever a record was set since 2018.

Uncertain / read before shipping:
- `grandstandsLatLon` is NOT surveyed: points are Ergast/Wikidata/centerline-node positions (checked <=150 m from the OSM centerline, <60 km
  from the city). Monaco, Sochi, Estoril use hand-picked centerline points. Expect +/-150 m. Refine from OSM building=grandstand when Overpass works.
- `coordConfidence` medium/low: Madring, Miami, Estoril, Yeongam, Anderstorp, Buenos Aires, Watkins Glen and old venues without a centerline.
- Paul Ricard direction (anticlockwise) comes from the OSM centerline only; Marina Bay and Yeongam overridden from Wikipedia text.
- Historic lap records are for the F1-era layout (see `layoutNote`); Dijon, Brands Hatch, Buenos Aires, Watkins Glen have none (null). Estoril 4.360 km / 13 turns
  and Zolder 4.262 km, Jarama 3.404 km, Kyalami 4.261 km, Indianapolis 4.192 km / 13 turns are from memory of the F1 layouts.
- Pole = Jolpica qualifying P1, except Mexico 2019 and Sao Paulo 2021 (ESPN's pole after penalty/disqualification).
- `notes` entries record origin in `notesSource` (computed, wikipedia, espn-jolpica, knowledge). "knowledge" lines are from memory (e.g. Typhoon Hagibis,
  Hulkenberg's 239th start); wet/red-flag tags exist only where the Wikipedia intro says so, so some damp races (e.g. 2025 Australia) are untagged.
- ESPN data faults: all Spanish GPs 2018-2025 are labelled "Madring"; 2018 Australian FP2 dated 2018-02-23 (fixed to 03-23); 2020/2021 duplicate
  event names ("Austrian Grand Prix 2") renamed Styrian/70th Anniversary. See `dataQuality` on those events.
- Teams: abbreviations are timing-style (MER, FER) because ESPN's codes (JK, SCS, DH) are internal; `homeVenueId` null (factories are not catalog venues);
  `founded` is the first F1 season of the lineage (`foundedNote`); Red Bull's blue accent is only 3.03:1 on #0B0C10. Driver `number` is the latest race number.
- Skipped: Long Beach, Valencia, Adelaide (street layouts that no longer exist as a circuit), demolished Jacarepagua, pre-1960 road courses, reserve drivers
  who never started. 2026 results end at round 17 (Singapore); rounds 18-23 are scheduled, `results: null`.
- `cota` reuses the existing venues.json record (same id, coordinates, capacity 120000, opened 2012); no other circuit id exists in the catalog.
