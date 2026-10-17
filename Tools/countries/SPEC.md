# Countries (and US states): reference records

Deliverable: `/home/user/SportsApp/Tools/countries/countries.json` (array), `us-states.json` (array), `NOTES.md` (<= 25 lines),
and `validate.py` (checks both files; must print 0 errors). Do not edit anything outside Tools/countries/. No git commands.

COUNTRY record (every UN member, UEFA/FIFA/IOC members and territories the app may meet: England, Scotland, Wales and Northern
Ireland are separate football nations; give them `countryCode` "GB-ENG", "GB-SCT", "GB-WLS", "GB-NIR" and a `parent` of "GB"):
`{ "code": "ES", "code3": "ESP", "name": "Spain", "officialName": "Kingdom of Spain", "continent": "Europe",
"subregion": "Southern Europe", "capital": "Madrid", "capitalLatitude": 40.4168, "capitalLongitude": -3.7038,
"latitude": 40.2, "longitude": -3.6, "bbox": [south, west, north, east], "population": 47400000, "flag": "🇪🇸",
"fifaCode": "ESP", "uefa": true, "eu": true, "schengen": true, "euro": true, "currency": "EUR", "languages": ["es"],
"timeZones": ["Europe/Madrid", "Atlantic/Canary"], "footballAssociation": "Real Federación Española de Fútbol" }`.
`latitude/longitude` is a sensible centre (population-weighted or geographic, same method for all). Europe (every UEFA member plus
Liechtenstein, Vatican, Kosovo, Gibraltar, Faroe Islands, Andorra, San Marino, Monaco) must be complete and double-checked; the rest
of the world needs the same fields where known (null otherwise). Sources: Wikidata, restcountries-style data, Natural Earth, FIFA/UEFA lists.
US STATE record: `{ "code": "IL", "name": "Illinois", "type": "state"|"district"|"territory", "capital": "Springfield",
"latitude": 40.0, "longitude": -89.2, "bbox": [..], "population": 12600000, "timeZones": ["America/Chicago"] }` for 50 states, DC,
and the 5 inhabited territories; also include the 10 Canadian provinces and 3 territories in `canada-provinces.json` with the same shape.
The validator checks required fields, unique codes, coordinates in range, bbox contains the centre, and Europe completeness (>= 55 UEFA members).
