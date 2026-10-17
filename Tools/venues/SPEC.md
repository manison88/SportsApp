# Venue research spec (shared by every research agent)

Write ONE file: `/home/user/SportsApp/Tools/venues/<region>.json`, a JSON array of venues. Validate it with
`python3 /home/user/SportsApp/Tools/venues/validate.py /home/user/SportsApp/Tools/venues/<region>.json`; it must pass with 0 errors.

## Fields (one object per venue)
```json
{
  "id": "lambeau-field",                 // lowercase slug, unique. REUSE the existing id if the venue is already in
                                          // /home/user/SportsApp/Witness/Resources/Catalog/venues.json (e.g. "wrigley", "lambeau", "camp-nou", "mlb-ari")
  "name": "Lambeau Field",               // current official name
  "aliases": ["Lambeau"],                // other names fans/ESPN/tickets use: former sponsor names, short names, local-language names
  "city": "Green Bay",
  "region": "Wisconsin",                 // state/province/region, or null
  "country": "United States",
  "countryCode": "US",                   // ISO 3166-1 alpha-2
  "latitude": 44.50139, "longitude": -88.06222,  // THE STADIUM ITSELF, >= 4 decimals, from Wikidata P625 or Wikipedia
  "sports": ["football"],                // only: baseball, football (American/Canadian/college), basketball, hockey, soccer, motorsport, handball
  "leagues": ["football/nfl"],           // ESPN API paths for leagues whose home games are played here (see list), [] if none
  "homeTeams": ["Green Bay Packers"],    // current primary tenants, full names
  "timeZone": "America/Chicago",         // IANA
  "capacity": 81441,                     // integer or null
  "opened": 1957                         // year or null
}
```

## ESPN league paths (use only these; they're verified)
football/nfl, football/college-football, football/cfl, basketball/nba, basketball/wnba,
basketball/mens-college-basketball, basketball/womens-college-basketball, basketball/euroleague, hockey/nhl,
baseball/mlb, soccer/usa.1 (MLS), soccer/usa.nwsl, soccer/mex.1, soccer/eng.1, soccer/esp.1, soccer/ger.1,
soccer/ita.1, soccer/fra.1, soccer/ned.1, soccer/por.1, soccer/sco.1, soccer/bel.1, soccer/tur.1, soccer/aut.1,
soccer/sui.1, soccer/gre.1, soccer/den.1, soccer/nor.1, soccer/swe.1, soccer/bra.1, soccer/arg.1, soccer/chi.1,
soccer/col.1, soccer/uru.1, soccer/per.1, soccer/ecu.1, soccer/par.1, soccer/ven.1, soccer/bol.1,
soccer/uefa.champions, soccer/conmebol.libertadores.
If unsure a path exists, test it: `curl -s "https://site.api.espn.com/apis/site/v2/sports/<path>/scoreboard" | head -c 300`
(valid paths return JSON with a "leagues" array). Handball has no ESPN coverage: leave leagues [].

## Rules
- Accuracy over volume. Coordinates are used for 600 m photo geofences, so they must be the venue, not the city.
  Best source: Wikidata SPARQL (https://query.wikidata.org/sparql?format=json&query=...) for coordinates (P625),
  capacity (P1083), opened (P1619), country (P17), occupants (P466). Batch queries; don't fetch one page per venue.
  Cross-check anything that looks off (e.g. two venues with identical coordinates, a point in the sea).
- Current venues only (where teams play now), plus famous still-standing venues if the brief asks for them.
- One object per physical venue. A venue shared by several teams/sports has all of them in sports/leagues/homeTeams.
- Don't edit any other file. Don't commit.
- Finish with: the validator output, the venue count, and a 3-line note on gaps or uncertain entries.
