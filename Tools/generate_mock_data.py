#!/usr/bin/env python3
"""
Generates Witness mock data (Witness/MockData/*.json).

The JSON is shaped like the future real sources so the Codable models can
swap to live data without UI changes:

  teams.json    MLB Stats API /teams, NHL api-web.nhle.com, TheSportsDB lookupteam,
                Jolpica-F1 /constructors, StatsBomb teams
  venues.json   MLB Stats API /venues, TheSportsDB lookupvenue
  games.json    MLB /game/{pk}/feed/live + /winProbability, NHL /gamecenter/{id}/play-by-play,
                TheSportsDB lookupevent, Jolpica-F1 /results, StatsBomb events,
                Open-Meteo archive (weather)
  photos.json   PhotoKit PHAsset metadata (localIdentifier, creationDate, location, ...)
  people.json, trips.json, profile.json   app-owned data

Run:  python3 Tools/generate_mock_data.py
Deterministic: the same seed always produces the same files.
"""
import json
import math
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

OUT = Path(__file__).resolve().parent.parent / "Witness" / "MockData"
RNG = random.Random(1908)


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# Teams. Colors are approximations used only as color pairs; the UI never
# renders logos or wordmarks, only typographic monograms.
# accent = the screen-safe, vivid color used for gradients on black.
# ---------------------------------------------------------------------------
TEAMS = [
    # id, sport, league, abbr, location, name, monogram, primary, secondary, accent, ext
    ("mlb-chc", "baseball", "MLB", "CHC", "Chicago", "Cubs", "C", "0E3386", "CC3433", "2F6BFF", {"mlbStatsApi": 112, "theSportsDb": "135269"}),
    ("mlb-stl", "baseball", "MLB", "STL", "St. Louis", "Cardinals", "STL", "C41E3A", "0C2340", "E8384F", {"mlbStatsApi": 138}),
    ("mlb-lad", "baseball", "MLB", "LAD", "Los Angeles", "Dodgers", "LA", "005A9C", "EF3E42", "3D8BFF", {"mlbStatsApi": 119}),
    ("mlb-cle", "baseball", "MLB", "CLE", "Cleveland", "Indians", "CLE", "0C2340", "E31937", "E8344A", {"mlbStatsApi": 114}),
    ("mlb-bos", "baseball", "MLB", "BOS", "Boston", "Red Sox", "B", "BD3039", "0C2340", "E0443F", {"mlbStatsApi": 111}),
    ("mlb-nyy", "baseball", "MLB", "NYY", "New York", "Yankees", "NY", "0C2340", "C4CED3", "8FA3C7", {"mlbStatsApi": 147}),
    ("mlb-mil", "baseball", "MLB", "MIL", "Milwaukee", "Brewers", "M", "12284B", "FFC52F", "FFC52F", {"mlbStatsApi": 158}),
    ("mlb-min", "baseball", "MLB", "MIN", "Minnesota", "Twins", "TC", "002B5C", "D31145", "E2245A", {"mlbStatsApi": 142}),
    ("mlb-det", "baseball", "MLB", "DET", "Detroit", "Tigers", "D", "0C2340", "FA4616", "FA6A2E", {"mlbStatsApi": 116}),
    ("mlb-pit", "baseball", "MLB", "PIT", "Pittsburgh", "Pirates", "P", "27251F", "FDB827", "FDB827", {"mlbStatsApi": 134}),
    ("mlb-kc", "baseball", "MLB", "KC", "Kansas City", "Royals", "KC", "004687", "BD9B60", "3E8EDE", {"mlbStatsApi": 118}),
    ("mlb-cin", "baseball", "MLB", "CIN", "Cincinnati", "Reds", "C", "C6011F", "000000", "E8203A", {"mlbStatsApi": 113}),
    ("mlb-sf", "baseball", "MLB", "SF", "San Francisco", "Giants", "SF", "FD5A1E", "27251F", "FD5A1E", {"mlbStatsApi": 137}),
    ("mlb-cws", "baseball", "MLB", "CWS", "Chicago", "White Sox", "SOX", "27251F", "C4CED4", "C4CED4", {"mlbStatsApi": 145}),
    ("mlb-nym", "baseball", "MLB", "NYM", "New York", "Mets", "NY", "002D72", "FF5910", "FF6A26", {"mlbStatsApi": 121}),
    ("mlb-sd", "baseball", "MLB", "SD", "San Diego", "Padres", "SD", "2F241D", "FFC425", "FFC425", {"mlbStatsApi": 135}),
    ("mlb-atl", "baseball", "MLB", "ATL", "Atlanta", "Braves", "A", "13274F", "CE1141", "E0284F", {"mlbStatsApi": 144}),
    ("mlb-phi", "baseball", "MLB", "PHI", "Philadelphia", "Phillies", "P", "E81828", "002D72", "F0303A", {"mlbStatsApi": 143}),
    ("mlb-wsh", "baseball", "MLB", "WSH", "Washington", "Nationals", "W", "AB0003", "14225A", "E3242B", {"mlbStatsApi": 120}),
    ("mlb-ari", "baseball", "MLB", "ARI", "Arizona", "Diamondbacks", "A", "A71930", "E3D4AD", "D8304A", {"mlbStatsApi": 109}),
    ("nfl-chi", "football", "NFL", "CHI", "Chicago", "Bears", "C", "0B162A", "C83803", "F05A1A", {"theSportsDb": "134938"}),
    ("nfl-gb", "football", "NFL", "GB", "Green Bay", "Packers", "G", "203731", "FFB612", "FFB612", {"theSportsDb": "134940"}),
    ("nfl-lar", "football", "NFL", "LAR", "Los Angeles", "Rams", "LA", "003594", "FFA300", "FFA300", {"theSportsDb": "135907"}),
    ("nfl-phi", "football", "NFL", "PHI", "Philadelphia", "Eagles", "P", "004C54", "A5ACAF", "1E9AA4", {"theSportsDb": "134936"}),
    ("nfl-det", "football", "NFL", "DET", "Detroit", "Lions", "D", "0076B6", "B0B7BC", "2F9BE0", {"theSportsDb": "134939"}),
    ("nfl-min", "football", "NFL", "MIN", "Minnesota", "Vikings", "M", "4F2683", "FFC62F", "8E5AE0", {"theSportsDb": "134941"}),
    ("nfl-dal", "football", "NFL", "DAL", "Dallas", "Cowboys", "D", "041E42", "869397", "4E7ACF", {"theSportsDb": "134934"}),
    ("nba-chi", "basketball", "NBA", "CHI", "Chicago", "Bulls", "CHI", "CE1141", "000000", "E8213F", {"theSportsDb": "134870"}),
    ("nba-bos", "basketball", "NBA", "BOS", "Boston", "Celtics", "B", "007A33", "BA9653", "17A34A", {"theSportsDb": "134860"}),
    ("nba-gsw", "basketball", "NBA", "GSW", "Golden State", "Warriors", "GS", "1D428A", "FFC72C", "FFC72C", {"theSportsDb": "134865"}),
    ("nba-mia", "basketball", "NBA", "MIA", "Miami", "Heat", "M", "98002E", "F9A01B", "F9A01B", {"theSportsDb": "134882"}),
    ("nba-lal", "basketball", "NBA", "LAL", "Los Angeles", "Lakers", "LA", "552583", "FDB927", "FDB927", {"theSportsDb": "134867"}),
    ("nba-nyk", "basketball", "NBA", "NYK", "New York", "Knicks", "NY", "006BB6", "F58426", "F58426", {"theSportsDb": "134862"}),
    ("nba-mil", "basketball", "NBA", "MIL", "Milwaukee", "Bucks", "M", "00471B", "EEE1C6", "2FA35A", {"theSportsDb": "134874"}),
    ("nhl-chi", "hockey", "NHL", "CHI", "Chicago", "Blackhawks", "C", "CF0A2C", "000000", "E8243C", {"nhlTriCode": "CHI"}),
    ("nhl-tbl", "hockey", "NHL", "TBL", "Tampa Bay", "Lightning", "TB", "002868", "FFFFFF", "3D74E0", {"nhlTriCode": "TBL"}),
    ("nhl-stl", "hockey", "NHL", "STL", "St. Louis", "Blues", "STL", "002F87", "FCB514", "FCB514", {"nhlTriCode": "STL"}),
    ("nhl-det", "hockey", "NHL", "DET", "Detroit", "Red Wings", "D", "CE1126", "FFFFFF", "E8243C", {"nhlTriCode": "DET"}),
    ("nhl-nsh", "hockey", "NHL", "NSH", "Nashville", "Predators", "N", "FFB81C", "041E42", "FFB81C", {"nhlTriCode": "NSH"}),
    ("nhl-min", "hockey", "NHL", "MIN", "Minnesota", "Wild", "MN", "154734", "A6192E", "2E8B57", {"nhlTriCode": "MIN"}),
    ("mls-chi", "soccer", "MLS", "CHI", "Chicago", "Fire", "CF", "AF2626", "0A174A", "E0362E", {"theSportsDb": "135651"}),
    ("mls-mia", "soccer", "MLS", "MIA", "Miami", "Inter Miami", "M", "F7B5CD", "231F20", "F7B5CD", {"theSportsDb": "140079"}),
    ("mls-clb", "soccer", "MLS", "CLB", "Columbus", "Crew", "C", "FEDD00", "000000", "FEDD00", {"theSportsDb": "135647"}),
    ("mls-ne", "soccer", "MLS", "NE", "New England", "Revolution", "NE", "0A2240", "CE0E2D", "E02A42", {"theSportsDb": "135653"}),
    ("mls-stl", "soccer", "MLS", "STL", "St. Louis", "City SC", "STL", "EC1458", "001544", "EC1458", {"theSportsDb": "140303"}),
    ("lal-bar", "soccer", "LaLiga", "BAR", "Barcelona", "Barcelona", "FCB", "A50044", "004D98", "D3125E", {"theSportsDb": "133739", "statsBombTeamId": 217}),
    ("lal-rma", "soccer", "LaLiga", "RMA", "Madrid", "Real Madrid", "RM", "FFFFFF", "FEBE10", "FEBE10", {"theSportsDb": "133738", "statsBombTeamId": 220}),
    ("lal-eib", "soccer", "LaLiga", "EIB", "Eibar", "Eibar", "E", "A6192E", "0047AB", "2E6BD8", {"theSportsDb": "133740"}),
    ("bun-bvb", "soccer", "Bundesliga", "BVB", "Dortmund", "Dortmund", "09", "FDE100", "000000", "FDE100", {"theSportsDb": "133650"}),
    ("bun-s04", "soccer", "Bundesliga", "S04", "Gelsenkirchen", "Schalke", "S04", "004D9D", "FFFFFF", "2F7FE0", {"theSportsDb": "133602"}),
    ("f1-rbr", "motorsport", "F1", "RBR", "Milton Keynes", "Red Bull", "RB", "1B2A4E", "E30118", "3B5BDB", {"jolpicaConstructorId": "red_bull"}),
    ("f1-mer", "motorsport", "F1", "MER", "Brackley", "Mercedes", "M", "00A19C", "C0C0C0", "00C2B8", {"jolpicaConstructorId": "mercedes"}),
    ("f1-mcl", "motorsport", "F1", "MCL", "Woking", "McLaren", "M", "FF8000", "47C7FC", "FF8000", {"jolpicaConstructorId": "mclaren"}),
]

VENUES = [
    # id, name, city, region, country, cc, lat, lon, elevation m, capacity, opened, sports, tz, ext
    ("wrigley", "Wrigley Field", "Chicago", "Illinois", "United States", "US", 41.9484, -87.6553, 181, 41649, 1914, ["baseball"], "America/Chicago", {"mlbStatsApi": 17}),
    ("soldier", "Soldier Field", "Chicago", "Illinois", "United States", "US", 41.8623, -87.6167, 180, 61500, 1924, ["football", "soccer"], "America/Chicago", {"theSportsDb": "15872"}),
    ("united-center", "United Center", "Chicago", "Illinois", "United States", "US", 41.8807, -87.6742, 181, 20917, 1994, ["basketball", "hockey"], "America/Chicago", {"theSportsDb": "16165"}),
    ("rate-field", "Guaranteed Rate Field", "Chicago", "Illinois", "United States", "US", 41.8299, -87.6338, 180, 40615, 1991, ["baseball"], "America/Chicago", {"mlbStatsApi": 4}),
    ("fenway", "Fenway Park", "Boston", "Massachusetts", "United States", "US", 42.3467, -71.0972, 6, 37755, 1912, ["baseball"], "America/New_York", {"mlbStatsApi": 3}),
    ("lambeau", "Lambeau Field", "Green Bay", "Wisconsin", "United States", "US", 44.5013, -88.0622, 194, 81441, 1957, ["football"], "America/Chicago", {"theSportsDb": "15876"}),
    ("amfam", "American Family Field", "Milwaukee", "Wisconsin", "United States", "US", 43.0280, -87.9712, 193, 41900, 2001, ["baseball"], "America/Chicago", {"mlbStatsApi": 32}),
    ("busch", "Busch Stadium", "St. Louis", "Missouri", "United States", "US", 38.6226, -90.1928, 142, 44383, 2006, ["baseball"], "America/Chicago", {"mlbStatsApi": 2889}),
    ("target-field", "Target Field", "Minneapolis", "Minnesota", "United States", "US", 44.9817, -93.2776, 247, 38544, 2010, ["baseball"], "America/Chicago", {"mlbStatsApi": 3312}),
    ("comerica", "Comerica Park", "Detroit", "Michigan", "United States", "US", 42.3390, -83.0485, 183, 41083, 2000, ["baseball"], "America/Detroit", {"mlbStatsApi": 2394}),
    ("progressive", "Progressive Field", "Cleveland", "Ohio", "United States", "US", 41.4962, -81.6852, 199, 34830, 1994, ["baseball"], "America/New_York", {"mlbStatsApi": 5}),
    ("pnc", "PNC Park", "Pittsburgh", "Pennsylvania", "United States", "US", 40.4469, -80.0057, 223, 38747, 2001, ["baseball"], "America/New_York", {"mlbStatsApi": 31}),
    ("kauffman", "Kauffman Stadium", "Kansas City", "Missouri", "United States", "US", 39.0517, -94.4803, 262, 37903, 1973, ["baseball"], "America/Chicago", {"mlbStatsApi": 7}),
    ("gabp", "Great American Ball Park", "Cincinnati", "Ohio", "United States", "US", 39.0979, -84.5082, 150, 42319, 2003, ["baseball"], "America/New_York", {"mlbStatsApi": 2602}),
    ("yankee", "Yankee Stadium", "New York", "New York", "United States", "US", 40.8296, -73.9262, 17, 46537, 2009, ["baseball"], "America/New_York", {"mlbStatsApi": 3313}),
    ("dodger", "Dodger Stadium", "Los Angeles", "California", "United States", "US", 34.0739, -118.2400, 157, 56000, 1962, ["baseball"], "America/Los_Angeles", {"mlbStatsApi": 22}),
    ("oracle", "Oracle Park", "San Francisco", "California", "United States", "US", 37.7786, -122.3893, 3, 41915, 2000, ["baseball"], "America/Los_Angeles", {"mlbStatsApi": 2395}),
    ("cota", "Circuit of the Americas", "Austin", "Texas", "United States", "US", 30.1328, -97.6411, 160, 120000, 2012, ["motorsport"], "America/Chicago", {"jolpicaCircuitId": "americas"}),
    ("camp-nou", "Camp Nou", "Barcelona", "Catalonia", "Spain", "ES", 41.3809, 2.1228, 48, 99354, 1957, ["soccer"], "Europe/Madrid", {"theSportsDb": "16217", "statsBombStadiumId": 342}),
    ("bernabeu", "Santiago Bernabéu", "Madrid", "Community of Madrid", "Spain", "ES", 40.4531, -3.6883, 667, 81044, 1947, ["soccer"], "Europe/Madrid", {"theSportsDb": "16220", "statsBombStadiumId": 4}),
    ("signal-iduna", "Signal Iduna Park", "Dortmund", "North Rhine-Westphalia", "Germany", "DE", 51.4926, 7.4519, 86, 81365, 1974, ["soccer"], "Europe/Berlin", {"theSportsDb": "16263"}),
]
VENUE = {v[0]: v for v in VENUES}
TEAM = {t[0]: t for t in TEAMS}

PEOPLE = [
    {"id": "me", "name": "Sam Okafor", "relation": "You", "initials": "SO", "colorHex": "FFB547", "birthYear": 1981},
    {"id": "maya", "name": "Maya", "relation": "Daughter", "initials": "M", "colorHex": "FF7A8A", "birthYear": 2010},
    {"id": "leo", "name": "Leo", "relation": "Son", "initials": "L", "colorHex": "6FD3FF", "birthYear": 2012},
    {"id": "dana", "name": "Dana", "relation": "Partner", "initials": "D", "colorHex": "B79CFF", "birthYear": 1983},
    {"id": "ray", "name": "Dad", "relation": "Father", "initials": "R", "colorHex": "8FE3A0", "birthYear": 1952},
    {"id": "chris", "name": "Chris", "relation": "Friend", "initials": "C", "colorHex": "FFD36E", "birthYear": 1981},
]

PROFILE = {
    "id": "me",
    "displayName": "Sam",
    "homeCity": "Chicago",
    "homeNeighborhood": "Logan Square",
    "homeLatitude": 41.9227,
    "homeLongitude": -87.7083,
    "memberSince": "2026-09-01T00:00:00Z",
    "favoriteTeamIds": ["mlb-chc", "nfl-chi", "nba-chi", "nhl-chi", "mls-chi", "lal-bar"],
}

# Sport timing model: (real minutes of a typical game, period labels)
SPORT_SHAPE = {
    "baseball": (182, [f"{i}" for i in range(1, 10)]),
    "football": (192, ["Q1", "Q2", "Q3", "Q4"]),
    "basketball": (138, ["Q1", "Q2", "Q3", "Q4"]),
    "hockey": (152, ["P1", "P2", "P3"]),
    "soccer": (112, ["1H", "2H"]),
    "motorsport": (98, ["Lap 1", "Lap 20", "Lap 40", "Lap 56"]),
}

# ---------------------------------------------------------------------------
# Games. provenance "verified" = real date, venue and final score;
# "illustrative" = plausible filler for the persona.
# companions use person ids. note = the fan's own words.
# ---------------------------------------------------------------------------
G = []


def game(gid, date, time_, venue, home, away, hs, as_, *, comp=None, verified=False,
         who=(), note=None, headline=None, seat=None, trip=None, rating=None,
         events=None, photos=None, weather=None, attendance=None, status="Final",
         race=None, season=None):
    G.append(dict(id=gid, date=date, time=time_, venue=venue, home=home, away=away, hs=hs, as_=as_,
                  comp=comp, verified=verified, who=list(who), note=note, headline=headline, seat=seat,
                  trip=trip, rating=rating, events=events, photos=photos, weather=weather,
                  attendance=attendance, status=status, race=race, season=season))


# --- Hero: 2016 World Series Game 5 (the "You were there" game) ------------
WS5_EVENTS = [
    # minute, period, clock, team, description, short, phrase, home, away, key
    (0, "1", "Top", None, "First pitch under the lights on Sheffield and Waveland.", "First pitch", "first pitch", 0, 0, False),
    (24, "2", "Top", "mlb-cle", "Ramírez lines a solo home run to left. Cleveland leads.", "CLE HR", "Ramírez's home run", 0, 1, True),
    (79, "4", "Bot", "mlb-chc", "Bryant crushes a solo shot to left-center. Tie game.", "Bryant HR", "Bryant's home run", 1, 1, True),
    (86, "4", "Bot", "mlb-chc", "Russell beats out an infield single. Chicago takes the lead.", "Go-ahead", "the go-ahead single", 2, 1, True),
    (90, "4", "Bot", "mlb-chc", "Ross lifts a sacrifice fly to center. 3–1.", "Sac fly", "Ross's sac fly", 3, 1, False),
    (124, "6", "Top", "mlb-cle", "Lindor singles home a run after a stolen base. 3–2.", "CLE RBI", "Lindor's RBI single", 3, 2, True),
    (148, "7", "Top", "mlb-chc", "Chapman enters with one out in the seventh. Eight outs to go.", "Chapman in", "Chapman's entrance", 3, 2, True),
    (161, "7", "Mid", None, "Seventh-inning stretch. Forty-one thousand voices.", "Stretch", "the stretch", 3, 2, False),
    (207, "9", "Top", "mlb-chc", "Ramírez grounds out. Chicago lives. Series heads back to Cleveland.", "Final out", "the final out", 3, 2, True),
]
WS5_PHOTOS = [
    # minute offset (float), style, favorite
    (-34.0, "concourse", False),
    (1.2, "diamond", False),
    (79.5, "crowd", False),
    (148.8, "scoreboard", False),
    (161.6, "lightTower", False),
    (207.67, "celebration", True),
    (219.0, "nightField", True),
]

game("mlb-2016-ws5", "2016-10-30", "19:15", "wrigley", "mlb-chc", "mlb-cle", 3, 2,
     comp="World Series · Game 5", verified=True, who=["ray"], seat="Bleachers · Section 314",
     headline="Down 3–1. Still alive.",
     note="Dad waited 71 years for this and I waited 35. When the last out landed in Rizzo's glove he grabbed my arm so hard it bruised. Nobody left. Nobody wanted to.",
     rating=5, events=WS5_EVENTS, photos=WS5_PHOTOS,
     weather=dict(t=63.1, feels=61.0, code=0, wind=9.8, rh=58, precip=0.0), attendance=41711, season="2016")

# --- Hero: Bears at Packers, Week 18, Jan 5 2025 (detail screen) ----------
LAMBEAU_EVENTS = [
    (0, "Q1", "15:00", None, "Kickoff into a gray Green Bay sky.", "Kickoff", "kickoff", 0, 0, False),
    (17, "Q1", "6:12", "nfl-chi", "Touchdown, Chicago. A quiet road crowd suddenly isn't.", "CHI TD", "the opening touchdown", 0, 7, True),
    (46, "Q2", "11:03", "nfl-gb", "Touchdown, Green Bay. 7–7.", "GB TD", "Green Bay's answer", 7, 7, False),
    (71, "Q2", "0:31", "nfl-chi", "Touchdown, Chicago, just before the half.", "CHI TD", "the touchdown before the half", 7, 14, True),
    (118, "Q3", "4:20", "nfl-chi", "Touchdown, Chicago. 21–7 and the visitors' corner is loud.", "CHI TD", "the third touchdown", 7, 21, True),
    (148, "Q4", "9:48", "nfl-gb", "Touchdown, Green Bay. 21–14.", "GB TD", "Green Bay's comeback score", 14, 21, False),
    (176, "Q4", "1:52", "nfl-gb", "Touchdown and two-point try good. Green Bay leads 22–21.", "GB +2", "the two-point conversion", 22, 21, True),
    (188, "Q4", "0:00", "nfl-chi", "51-yard field goal as time expires. Chicago wins it.", "Walk-off FG", "the walk-off kick", 22, 24, True),
]
LAMBEAU_PHOTOS = [
    (-52.0, "snowGame", False),
    (1.5, "snowGame", True),
    (17.4, "crowd", False),
    (86.0, "concourse", False),
    (176.3, "scoreboard", False),
    (188.67, "celebration", True),
    (196.0, "lightTower", True),
]
game("nfl-2025-w18-gb", "2025-01-05", "12:00", "lambeau", "nfl-gb", "nfl-chi", 22, 24,
     comp="Week 18", verified=True, who=["maya", "leo"], seat="Section 112 · Row 41",
     headline="The kick that went through the snow.",
     note="Maya's first time at Lambeau. Leo wore three pairs of socks and still complained. When the kick went up nobody in our row breathed, and then the whole visitors' corner lost it. We drove home through the snow singing.",
     rating=5, events=LAMBEAU_EVENTS, photos=LAMBEAU_PHOTOS, trip="trip-lambeau-2025",
     weather=dict(t=19.4, feels=7.2, code=71, wind=14.6, rh=81, precip=0.3), attendance=77412, season="2024")

# --- Other verified games ------------------------------------------------
game("mlb-2015-opener", "2015-04-05", "19:17", "wrigley", "mlb-chc", "mlb-stl", 0, 3, verified=True, who=["chris"],
     comp="Opening Night", headline="Opening night, bleachers still under construction.",
     weather=dict(t=44.2, feels=38.0, code=2, wind=12.1, rh=62, precip=0.0), season="2015")
game("mlb-2015-nlds4", "2015-10-13", "15:37", "wrigley", "mlb-chc", "mlb-stl", 6, 4, verified=True, who=["ray", "chris"],
     comp="NLDS · Game 4", headline="First postseason clincher at Wrigley. Ever.",
     note="Champagne on the field at Wrigley. I didn't know that was allowed.",
     weather=dict(t=71.0, feels=71.0, code=1, wind=8.0, rh=48, precip=0.0), season="2015")
game("nhl-2015-scf6", "2015-06-15", "19:00", "united-center", "nhl-chi", "nhl-tbl", 2, 0, verified=True, who=["dana"],
     comp="Stanley Cup Final · Game 6", headline="The Cup, lifted at home.",
     note="First time since 1938 they won it on home ice. Dana cried at the anthem, I cried at the horn.", rating=5, season="2015")
game("mlb-2016-nlcs6", "2016-10-22", "19:08", "wrigley", "mlb-chc", "mlb-lad", 5, 0, verified=True, who=["ray"],
     comp="NLCS · Game 6", headline="The pennant, finally.",
     note="They played Go Cubs Go and an entire neighborhood sang it on the walk home.", rating=5,
     weather=dict(t=49.0, feels=45.0, code=0, wind=10.0, rh=52, precip=0.0), season="2016")
game("mlb-2016-ws3", "2016-10-28", "19:08", "wrigley", "mlb-chc", "mlb-cle", 0, 1, verified=True, who=["chris"],
     comp="World Series · Game 3", headline="First World Series game at Wrigley since 1945.",
     weather=dict(t=61.0, feels=59.0, code=1, wind=15.0, rh=60, precip=0.0), season="2016")
game("mlb-2018-alds1", "2018-10-05", "19:32", "fenway", "mlb-bos", "mlb-nyy", 5, 4, verified=True, who=["chris"],
     comp="ALDS · Game 1", headline="A rivalry in October, from the Monster seats.", trip="trip-boston-2018",
     weather=dict(t=58.0, feels=55.0, code=3, wind=11.0, rh=70, precip=0.0), season="2018")
game("nfl-2018-w14-lar", "2018-12-09", "19:20", "soldier", "nfl-chi", "nfl-lar", 15, 6, verified=True, who=["chris"],
     comp="Sunday Night", headline="Fifteen points. Six allowed. Pure defense.",
     weather=dict(t=29.0, feels=19.0, code=3, wind=13.0, rh=72, precip=0.0), season="2018")
game("nfl-2018-w15-gb", "2018-12-16", "12:00", "soldier", "nfl-chi", "nfl-gb", 24, 17, verified=True, who=["ray"],
     headline="Division clinched against the rival.",
     weather=dict(t=38.0, feels=31.0, code=2, wind=9.0, rh=66, precip=0.0), season="2018")
game("nfl-2019-wc-phi", "2019-01-06", "15:40", "soldier", "nfl-chi", "nfl-phi", 15, 16, verified=True, who=["ray", "chris"],
     comp="Wild Card", headline="The double doink.",
     note="Forty-one yards. The upright, the crossbar, the grass. 62,000 people went silent at once. I've never heard a sound like that silence.",
     weather=dict(t=35.0, feels=28.0, code=3, wind=10.0, rh=75, precip=0.0), season="2018")
game("nfl-2019-w1-gb", "2019-09-05", "19:20", "soldier", "nfl-chi", "nfl-gb", 3, 10, verified=True, who=["maya"],
     comp="Season opener", headline="Maya's first Bears game.",
     weather=dict(t=73.0, feels=73.0, code=0, wind=6.0, rh=55, precip=0.0), season="2019")
game("bun-2017-revierderby", "2017-11-25", "15:30", "signal-iduna", "bun-bvb", "bun-s04", 4, 4, verified=True, who=["chris"],
     comp="Revierderby", headline="4–0 at 25 minutes. 4–4 at the whistle.", trip="trip-ruhr-2017",
     note="The Yellow Wall was singing at 4–0 and still singing at 4–4. I don't speak German and I knew every word by the end.",
     weather=dict(t=41.0, feels=35.0, code=61, wind=12.0, rh=88, precip=1.1), season="2017-18")
game("lal-2020-bar-eib", "2020-02-22", "16:00", "camp-nou", "lal-bar", "lal-eib", 5, 0, verified=True, who=["dana", "maya", "leo"],
     headline="Four goals from one man, ten rows from the pitch.", trip="trip-spain-2020",
     note="Leo counted every goal out loud in Spanish. Cinco.",
     weather=dict(t=62.0, feels=62.0, code=0, wind=5.0, rh=56, precip=0.0), season="2019-20")
game("lal-2020-clasico", "2020-03-01", "16:00", "bernabeu", "lal-rma", "lal-bar", 2, 0, verified=True, who=["dana", "maya", "leo"],
     comp="El Clásico", headline="The last game before the world went quiet.", trip="trip-spain-2020",
     note="We didn't know it yet, but this was the last crowd any of us would stand in for a year and a half.",
     weather=dict(t=55.0, feels=53.0, code=1, wind=7.0, rh=50, precip=0.0), season="2019-20")
game("f1-2021-usgp", "2021-10-24", "14:00", "cota", None, None, 0, 0, verified=True, who=["leo", "chris"],
     comp="United States Grand Prix", headline="Turn 1 from the hill, with 140,000 others.", trip="trip-austin-2021",
     race=dict(raceName="United States Grand Prix", round=17, laps=56, results=[
         dict(position=1, driverCode="VER", driverName="M. Verstappen", constructorId="f1-rbr", time="1:34:36.552"),
         dict(position=2, driverCode="HAM", driverName="L. Hamilton", constructorId="f1-mer", time="+1.333"),
         dict(position=3, driverCode="PER", driverName="S. Pérez", constructorId="f1-rbr", time="+42.223"),
     ]),
     weather=dict(t=78.0, feels=79.0, code=1, wind=7.0, rh=58, precip=0.0), season="2021")
game("mls-2023-mia", "2023-10-04", "19:30", "soldier", "mls-chi", "mls-mia", 1, 4, verified=True, who=["maya", "leo"],
     headline="62,000 came for one player. He didn't play.",
     weather=dict(t=64.0, feels=64.0, code=2, wind=8.0, rh=61, precip=0.0), season="2023")

# --- Illustrative filler to round out 12 seasons ---------------------------
ILL = [
    # id, date, time, venue, home, away, hs, as, who, trip
    ("mlb-2014-0614", "2014-06-14", "13:20", "wrigley", "mlb-chc", "mlb-pit", 4, 2, ["chris"], None),
    ("mlb-2014-0802", "2014-08-02", "13:20", "wrigley", "mlb-chc", "mlb-sf", 1, 3, ["ray"], None),
    ("nfl-2014-1116", "2014-11-16", "12:00", "soldier", "nfl-chi", "nfl-min", 21, 13, ["ray"], None),
    ("nhl-2014-0321", "2014-03-21", "19:30", "united-center", "nhl-chi", "nhl-stl", 4, 3, ["dana"], None),
    ("nba-2014-1225", "2014-12-25", "13:00", "united-center", "nba-chi", "nba-lal", 113, 93, ["dana"], None),
    ("mlb-2015-0725", "2015-07-25", "15:05", "wrigley", "mlb-chc", "mlb-phi", 3, 5, ["chris"], None),
    ("mlb-2016-0619", "2016-06-19", "13:20", "wrigley", "mlb-chc", "mlb-pit", 4, 3, ["ray"], None),
    ("mlb-2016-0727", "2016-07-27", "19:10", "rate-field", "mlb-cws", "mlb-chc", 3, 1, ["chris"], None),
    ("nfl-2016-1009", "2016-10-09", "12:00", "soldier", "nfl-chi", "nfl-det", 17, 14, [], None),
    ("mlb-2017-0410", "2017-04-10", "19:08", "wrigley", "mlb-chc", "mlb-lad", 3, 2, ["ray", "dana"], None),
    ("mlb-2017-0923", "2017-09-23", "18:10", "amfam", "mlb-mil", "mlb-chc", 0, 4, ["chris"], "trip-milwaukee-2017"),
    ("nhl-2017-0218", "2017-02-18", "19:00", "united-center", "nhl-chi", "nhl-det", 5, 2, ["dana"], None),
    ("mlb-2018-0519", "2018-05-19", "13:15", "busch", "mlb-stl", "mlb-chc", 2, 6, ["ray"], "trip-stl-2018"),
    ("mlb-2018-0714", "2018-07-14", "13:20", "wrigley", "mlb-chc", "mlb-sd", 7, 3, ["maya", "leo"], None),
    ("mlb-2018-0811", "2018-08-11", "18:10", "target-field", "mlb-min", "mlb-cle", 5, 4, ["dana"], None),
    ("mlb-2019-0615", "2019-06-15", "13:10", "comerica", "mlb-det", "mlb-cws", 2, 5, ["chris"], None),
    ("mlb-2019-0824", "2019-08-24", "13:20", "wrigley", "mlb-chc", "mlb-wsh", 9, 4, ["maya", "leo"], None),
    ("mlb-2019-0810", "2019-08-10", "18:10", "progressive", "mlb-cle", "mlb-nyy", 6, 4, ["chris"], None),
    ("nhl-2019-1109", "2019-11-09", "19:00", "united-center", "nhl-chi", "nhl-nsh", 2, 3, ["leo"], None),
    ("nba-2019-0309", "2019-03-09", "19:00", "united-center", "nba-chi", "nba-nyk", 104, 98, ["chris"], None),
    ("mls-2021-0821", "2021-08-21", "19:30", "soldier", "mls-chi", "mls-ne", 2, 1, ["leo"], None),
    ("mlb-2021-0605", "2021-06-05", "13:20", "wrigley", "mlb-chc", "mlb-sd", 7, 1, ["maya", "leo"], None),
    ("mlb-2021-0717", "2021-07-17", "18:05", "pnc", "mlb-pit", "mlb-chc", 3, 8, ["leo"], "trip-pittsburgh-2021"),
    ("nfl-2021-1205", "2021-12-05", "12:00", "soldier", "nfl-chi", "nfl-dal", 20, 23, ["leo"], None),
    ("mlb-2022-0611", "2022-06-11", "18:10", "kauffman", "mlb-kc", "mlb-det", 4, 6, ["dana"], None),
    ("mlb-2022-0730", "2022-07-30", "13:20", "wrigley", "mlb-chc", "mlb-cin", 5, 2, ["maya", "leo"], None),
    ("mlb-2022-0904", "2022-09-04", "13:40", "gabp", "mlb-cin", "mlb-chc", 3, 4, ["leo"], None),
    ("nba-2022-1112", "2022-11-12", "19:00", "united-center", "nba-chi", "nba-bos", 121, 107, ["maya", "leo"], None),
    ("mls-2022-0618", "2022-06-18", "19:30", "soldier", "mls-chi", "mls-clb", 0, 0, ["leo"], None),
    ("mlb-2023-0707", "2023-07-07", "19:05", "yankee", "mlb-nyy", "mlb-chc", 0, 3, ["maya", "leo"], "trip-nyc-2023"),
    ("mlb-2023-0901", "2023-09-01", "19:05", "wrigley", "mlb-chc", "mlb-sf", 4, 3, ["dana"], None),
    ("nhl-2023-0128", "2023-01-28", "19:00", "united-center", "nhl-chi", "nhl-min", 3, 4, ["maya", "leo"], None),
    ("nfl-2023-1224", "2023-12-24", "12:00", "soldier", "nfl-chi", "nfl-det", 28, 13, ["maya", "leo"], None),
    ("mlb-2024-0615", "2024-06-15", "13:20", "wrigley", "mlb-chc", "mlb-stl", 6, 2, ["ray"], None),
    ("mlb-2024-0907", "2024-09-07", "18:10", "dodger", "mlb-lad", "mlb-chc", 5, 3, ["maya", "leo"], "trip-california-2024"),
    ("mls-2024-0525", "2024-05-25", "19:30", "soldier", "mls-chi", "mls-stl", 3, 2, ["leo"], None),
    ("nba-2024-0217", "2024-02-17", "19:00", "united-center", "nba-chi", "nba-gsw", 110, 118, ["leo"], None),
    ("nhl-2025-0301", "2025-03-01", "19:00", "united-center", "nhl-chi", "nhl-stl", 4, 1, ["maya", "leo"], None),
    ("mlb-2025-0614", "2025-06-14", "13:05", "oracle", "mlb-sf", "mlb-chc", 2, 5, ["leo"], "trip-california-2025"),
    ("mlb-2025-0809", "2025-08-09", "13:20", "wrigley", "mlb-chc", "mlb-atl", 8, 7, ["maya", "dana"], None),
    ("nfl-2025-1102", "2025-11-02", "12:00", "soldier", "nfl-chi", "nfl-min", 27, 24, ["leo"], None),
    ("nba-2026-0214", "2026-02-14", "19:00", "united-center", "nba-chi", "nba-mia", 112, 109, ["dana"], None),
    ("mlb-2026-0704", "2026-07-04", "13:20", "wrigley", "mlb-chc", "mlb-mil", 5, 4, ["maya", "leo", "dana"], None),
]
for row in ILL:
    gid, d, t, v, h, a, hs, as_, who, trip = row
    game(gid, d, t, v, h, a, hs, as_, who=who, trip=trip)

assert len(G) == 60, len(G)

# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------

def sigmoid(x):
    return 1 / (1 + math.exp(-x))


def lead_weight(sport, f):
    if sport == "baseball":
        return 0.55 + 2.4 * f ** 2.2
    if sport == "football":
        return 0.07 + 0.32 * f ** 3
    if sport == "basketball":
        return 0.035 + 0.42 * f ** 3.2
    if sport == "hockey":
        return 0.8 + 2.8 * f ** 2.5
    if sport == "soccer":
        return 0.9 + 3.2 * f ** 2.5
    return 0.0


def decompose(sport, total, rng):
    """Split a final score into scoring plays."""
    if total == 0:
        return []
    if sport == "football":
        # Fewest plays that sum to the total, preferring touchdowns and field goals.
        options = [7, 3, 6, 8, 2]
        best = {0: []}
        for n in range(1, total + 1):
            cands = [best[n - o] + [o] for o in options if n - o in best]
            if cands:
                best[n] = min(cands, key=lambda c: (len(c), sum(1 for x in c if x in (2, 6, 8))))
        plays = list(best.get(total, [total]))
        rng.shuffle(plays)
        return plays
    if sport == "baseball":
        plays = []
        left = total
        while left > 0:
            r = rng.choice([1, 1, 1, 2, 2, 3])
            r = min(r, left)
            plays.append(r)
            left -= r
        return plays
    if sport == "basketball":
        return []  # handled as a continuous path
    return [1] * total


def synth_events(g, sport, duration, home_id, away_id, rng):
    periods = SPORT_SHAPE[sport][1]
    events = [(0, periods[0], "Start", None, "Underway.", "Start", "the opening", 0, 0, False)]
    if sport == "basketball":
        hs, as_ = g["hs"], g["as_"]
        for qi, q in enumerate(periods):
            minute = int(duration * (qi + 1) / len(periods)) - 2
            f = (qi + 1) / len(periods)
            h = round(hs * f + rng.randint(-4, 4) * (1 - f))
            a = round(as_ * f + rng.randint(-4, 4) * (1 - f))
            if qi == len(periods) - 1:
                h, a = hs, as_
            label = "Final" if qi == len(periods) - 1 else f"End {q}"
            desc = "Final buzzer." if qi == len(periods) - 1 else f"End of {q}. {h}–{a}."
            events.append((minute, q, "0:00", None, desc, label, "the final buzzer" if label == "Final" else f"the end of {q}", h, a, label == "Final"))
        return events
    plays = [(home_id, p) for p in decompose(sport, g["hs"], rng)] + [(away_id, p) for p in decompose(sport, g["as_"], rng)]
    rng.shuffle(plays)
    times = sorted(rng.uniform(0.04, 0.97) * duration for _ in plays)
    h = a = 0
    noun = {"baseball": "run", "football": "score", "hockey": "goal", "soccer": "goal"}[sport]
    for t, (tid, pts) in zip(times, plays):
        prev_leader = (h > a) - (h < a)
        if tid == home_id:
            h += pts
        else:
            a += pts
        leader = (h > a) - (h < a)
        city = TEAM[tid][4]
        pi = min(int(t / duration * len(periods)), len(periods) - 1)
        if sport == "baseball":
            desc = f"{city} scores {pts} {'run' if pts == 1 else 'runs'}."
        elif sport == "football":
            kind = {7: "Touchdown", 6: "Touchdown", 8: "Touchdown + 2", 3: "Field goal", 2: "Safety"}.get(pts, "Score")
            desc = f"{kind}, {city}."
        else:
            desc = f"Goal, {city}."
        key = leader != prev_leader
        short = f"{TEAM[tid][3]} {'lead' if key and leader != 0 else noun}"
        events.append((round(t), periods[pi], None, tid, desc, short, f"the {city} {noun}", h, a, key))
    final_phrase = {"baseball": "the final out", "football": "the final whistle", "hockey": "the final horn", "soccer": "the final whistle"}[sport]
    events.append((duration, periods[-1], "0:00", None, "Final.", "Final", final_phrase, g["hs"], g["as_"], True))
    return events


def prob_series(sport, duration, events, start, rng, final_home, final_away):
    if sport == "motorsport":
        return []
    pts = []
    ev = sorted(events, key=lambda e: e[0])
    noise = 0.0
    step = 1.5
    t = 0.0
    idx = 0
    samples = []
    while t < duration:
        samples.append(t)
        t += step
    for e in ev:
        samples.append(e[0] + 0.25)
    samples = sorted(set(round(s, 2) for s in samples if s <= duration))
    for s in samples:
        h = a = 0
        for e in ev:
            if e[0] <= s:
                h, a = e[7], e[8]
        f = min(s / duration, 1.0)
        noise = noise * 0.85 + rng.uniform(-0.09, 0.09)
        x = (h - a) * lead_weight(sport, f) + 0.12 + noise * (1 - f)
        p = sigmoid(x)
        pts.append({"timestamp": iso(start + timedelta(minutes=s)), "atBatIndex": idx,
                    "homeTeamWinProbability": round(min(max(p * 100, 1.0), 99.0), 1)})
        idx += 1
    final_p = 100.0 if final_home > final_away else (0.0 if final_home < final_away else 50.0)
    pts.append({"timestamp": iso(start + timedelta(minutes=duration + 0.5)), "atBatIndex": idx,
                "homeTeamWinProbability": final_p})
    return pts


def photo_styles_for(sport, local_hour, month, rng, n):
    night = local_hour >= 17
    if sport == "baseball":
        base = ["diamond", "nightField", "lightTower", "crowd", "scoreboard", "concourse"] if night else ["dayGame", "diamond", "crowd", "scoreboard", "concourse", "skyline"]
    elif sport == "football":
        base = ["snowGame", "crowd", "lightTower", "scoreboard", "concourse"] if month in (11, 12, 1) else ["nightField", "crowd", "lightTower", "scoreboard"]
    elif sport in ("basketball", "hockey"):
        base = ["arena", "crowd", "scoreboard", "concourse", "arena"]
    elif sport == "soccer":
        base = ["pitch", "crowd", "lightTower", "celebration", "skyline"]
    else:
        base = ["trackside", "crowd", "trackside", "skyline"]
    rng.shuffle(base)
    return (base * 3)[:n]


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
games_out, photos_out = [], []
WMO = {0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast", 45: "Fog", 61: "Light rain", 63: "Rain", 71: "Light snow", 73: "Snow"}

for g in sorted(G, key=lambda x: x["date"]):
    v = VENUE[g["venue"]]
    tz = ZoneInfo(v[12])
    sport = TEAM[g["home"]][1] if g["home"] else "motorsport"
    duration, periods = SPORT_SHAPE[sport]
    rng = random.Random(g["id"])
    start = datetime.fromisoformat(f"{g['date']}T{g['time']}:00").replace(tzinfo=tz)

    if g["events"]:
        events = g["events"]
        duration = events[-1][0]
    elif sport == "motorsport":
        events = [(0, "Lap 1", None, None, "Lights out.", "Lights out", "lights out", 0, 0, True),
                  (3, "Lap 1", None, "f1-mer", "Hamilton takes the lead into Turn 1.", "T1 lead", "the Turn 1 move", 0, 0, True),
                  (78, "Lap 46", None, "f1-rbr", "Verstappen passes after the final stops.", "Lead", "the pass for the lead", 0, 0, True),
                  (96, "Lap 56", None, "f1-rbr", "Chequered flag. 1.3 seconds.", "Chequered", "the chequered flag", 0, 0, True)]
        duration = 96
    else:
        events = synth_events(g, sport, duration, g["home"], g["away"], rng)

    ev_out = []
    for i, e in enumerate(events):
        minute, period, clock, tid, desc, short, phrase, h, a, key = e
        ev_out.append({
            "id": f"{g['id']}-e{i}",
            "timestamp": iso(start + timedelta(minutes=minute)),
            "period": period, "clock": clock,
            "kind": "start" if i == 0 else ("final" if i == len(events) - 1 else ("score" if tid and (h, a) != (events[i - 1][7], events[i - 1][8]) else "moment")),
            "teamId": tid, "description": desc, "shortLabel": short, "phrase": phrase,
            "homeScore": h, "awayScore": a, "isKeyMoment": key,
        })

    period_markers = []
    for pi, p in enumerate(periods):
        minute = duration * pi / len(periods)
        period_markers.append({"label": p, "timestamp": iso(start + timedelta(minutes=minute))})

    # Photos
    photo_ids = []
    if g["photos"]:
        plist = g["photos"]
    else:
        n = rng.randint(3, 6)
        styles = photo_styles_for(sport, start.hour, start.month, rng, n)
        mins = sorted([rng.uniform(-30, duration + 10) for _ in range(n)])
        # pin one photo right after a key moment for the "taken Ns after" story
        keys = [e for e in events if e[9] and e[0] > 0]
        if keys:
            k = rng.choice(keys)
            mins[-1] = k[0] + rng.uniform(0.3, 1.5)
            mins.sort()
        plist = [(m, s, i == n - 1) for i, (m, s) in enumerate(zip(mins, styles))]
    for pi, (m, style, fav) in enumerate(plist):
        prng = random.Random(f"{g['id']}#{pi}")
        pid = f"{prng.getrandbits(32):08X}-{prng.getrandbits(16):04X}-4{prng.getrandbits(12):03X}-A{prng.getrandbits(12):03X}/L0/001"
        when = start + timedelta(minutes=m)
        landscape = rng.random() < 0.35
        photos_out.append({
            "localIdentifier": pid,
            "creationDate": iso(when),
            "location": {"latitude": round(v[6] + rng.uniform(-0.0006, 0.0006), 6),
                         "longitude": round(v[7] + rng.uniform(-0.0006, 0.0006), 6),
                         "altitude": v[8] + rng.uniform(4, 30), "horizontalAccuracy": round(rng.uniform(4, 25), 1)},
            "pixelWidth": 5712 if landscape else 4284, "pixelHeight": 4284 if landscape else 5712,
            "mediaType": "image",
            "mediaSubtypes": ["photoLive"] if rng.random() < 0.6 else [],
            "isFavorite": bool(fav),
            "placeholder": {"style": style, "seed": random.Random(pid).getrandbits(31)},
        })
        photo_ids.append(pid)

    home = {"teamId": g["home"], "score": g["hs"]} if g["home"] else None
    away = {"teamId": g["away"], "score": g["as_"]} if g["away"] else None
    w = g["weather"] or dict(
        t=round({1: 24, 2: 30, 3: 40, 4: 52, 5: 61, 6: 72, 7: 79, 8: 78, 9: 70, 10: 58, 11: 44, 12: 30}[start.month] + rng.uniform(-6, 6), 1),
        feels=None, code=rng.choice([0, 0, 1, 1, 2, 3]), wind=round(rng.uniform(4, 16), 1), rh=rng.randint(40, 75), precip=0.0)
    if w["feels"] is None:
        w["feels"] = round(w["t"] - (w["wind"] * 0.4 if w["t"] < 50 else 0), 1)
    if sport in ("basketball", "hockey"):
        indoor = True
    else:
        indoor = False

    if g["home"]:
        h_city, a_city = TEAM[g["home"]][4], TEAM[g["away"]][4]
        if g["hs"] == g["as_"]:
            auto_head = f"{h_city} and {a_city} draw {g['hs']}–{g['as_']}."
        else:
            wcity, lcity = (h_city, a_city) if g["hs"] > g["as_"] else (a_city, h_city)
            hi, lo = max(g["hs"], g["as_"]), min(g["hs"], g["as_"])
            auto_head = f"{wcity} {hi}, {lcity} {lo}."
    else:
        auto_head = "Race day."

    league = TEAM[g["home"]][2] if g["home"] else "F1"
    provider = {"MLB": "mlb-stats-api", "NHL": "nhl-api-web", "F1": "jolpica-f1"}.get(league, "thesportsdb")
    if g["id"] in ("lal-2020-clasico", "lal-2020-bar-eib"):
        provider = "statsbomb-open-data"
    endpoint = {
        "mlb-stats-api": "https://statsapi.mlb.com/api/v1.1/game/{id}/feed/live",
        "nhl-api-web": "https://api-web.nhle.com/v1/gamecenter/{id}/play-by-play",
        "jolpica-f1": "https://api.jolpi.ca/ergast/f1/{season}/{round}/results.json",
        "thesportsdb": "https://www.thesportsdb.com/api/v1/json/{key}/lookupevent.php?id={id}",
        "statsbomb-open-data": "https://raw.githubusercontent.com/statsbomb/open-data/master/data/events/{id}.json",
    }[provider]

    games_out.append({
        "id": g["id"],
        "sport": sport,
        "league": league,
        "season": g["season"] or str(start.year),
        "competition": g["comp"],
        "startTime": iso(start),
        "endTime": iso(start + timedelta(minutes=duration + 4)),
        "venueId": g["venue"],
        "home": home, "away": away, "race": g["race"],
        "statusDetail": g["status"],
        "attendance": g["attendance"] or (int(VENUE[g["venue"]][9] * rng.uniform(0.82, 0.99)) if sport != "motorsport" else 140000),
        "headline": g["headline"] or auto_head,
        "provenance": "verified" if g["verified"] else "illustrative",
        "isIndoor": indoor,
        "periods": period_markers,
        "events": ev_out,
        "winProbability": prob_series(sport, duration, events, start, rng, g["hs"], g["as_"]),
        "weather": {
            "time": iso(start.replace(minute=0)),
            "temperature_2m": w["t"], "apparent_temperature": w["feels"],
            "weather_code": w["code"], "wind_speed_10m": w["wind"],
            "relative_humidity_2m": w["rh"], "precipitation": w["precip"],
        },
        "memory": {
            "companionIds": g["who"], "note": g["note"], "seat": g["seat"],
            "photoIds": photo_ids, "rating": g["rating"], "tripId": g["trip"],
        },
        "source": {"provider": provider, "externalId": g["id"], "endpoint": endpoint},
    })

# Shared-passport target: Maya appears in exactly 17 games.
maya = sum(1 for g in games_out if "maya" in g["memory"]["companionIds"])
assert maya == 17, f"Maya count {maya}"

teams_out = [{
    "id": t[0], "sport": t[1], "league": t[2], "abbreviation": t[3], "locationName": t[4],
    "teamName": t[5], "monogram": t[6],
    "colors": {"primary": t[7], "secondary": t[8], "accent": t[9]},
    "externalIds": t[10],
} for t in TEAMS]

venues_out = [{
    "id": v[0], "name": v[1], "city": v[2], "region": v[3], "country": v[4], "countryCode": v[5],
    "latitude": v[6], "longitude": v[7], "elevationMeters": v[8], "capacity": v[9], "opened": v[10],
    "sports": v[11], "timeZone": v[12], "externalIds": v[13],
} for v in VENUES]


def trip(tid, title, subtitle, stops):
    gids = [g["id"] for g in games_out if g["memory"]["tripId"] == tid]
    dates = sorted(g["startTime"] for g in games_out if g["id"] in gids)
    return {"id": tid, "title": title, "subtitle": subtitle, "gameIds": gids,
            "startDate": stops[0]["date"], "endDate": stops[-1]["date"], "stops": stops}


def stop(city, lat, lon, date, kind, venue=None):
    return {"city": city, "latitude": lat, "longitude": lon, "date": date, "kind": kind, "venueId": venue}


trips_out = [
    trip("trip-spain-2020", "Spain, before the quiet", "Barcelona → Madrid · Feb–Mar 2020", [
        stop("Chicago", 41.9786, -87.9048, "2020-02-20T22:00:00Z", "depart"),
        stop("Barcelona", 41.3851, 2.1734, "2020-02-21T14:00:00Z", "city"),
        stop("Camp Nou", 41.3809, 2.1228, "2020-02-22T15:00:00Z", "game", "camp-nou"),
        stop("Valencia", 39.4699, -0.3763, "2020-02-25T11:00:00Z", "city"),
        stop("Madrid", 40.4168, -3.7038, "2020-02-27T12:00:00Z", "city"),
        stop("Santiago Bernabéu", 40.4531, -3.6883, "2020-03-01T15:00:00Z", "game", "bernabeu"),
        stop("Chicago", 41.9786, -87.9048, "2020-03-02T20:00:00Z", "return"),
    ]),
    trip("trip-lambeau-2025", "North to Lambeau", "Chicago → Green Bay · Jan 2025", [
        stop("Chicago", 41.9227, -87.7083, "2025-01-05T12:30:00Z", "depart"),
        stop("Lambeau Field", 44.5013, -88.0622, "2025-01-05T18:00:00Z", "game", "lambeau"),
        stop("Chicago", 41.9227, -87.7083, "2025-01-06T03:30:00Z", "return"),
    ]),
    trip("trip-ruhr-2017", "Derby day in the Ruhr", "Düsseldorf → Dortmund · Nov 2017", [
        stop("Düsseldorf", 51.2277, 6.7735, "2017-11-24T09:00:00Z", "city"),
        stop("Signal Iduna Park", 51.4926, 7.4519, "2017-11-25T14:30:00Z", "game", "signal-iduna"),
    ]),
    trip("trip-austin-2021", "Austin, race weekend", "Chicago → Austin · Oct 2021", [
        stop("Chicago", 41.9786, -87.9048, "2021-10-22T13:00:00Z", "depart"),
        stop("Austin", 30.2672, -97.7431, "2021-10-22T17:00:00Z", "city"),
        stop("Circuit of the Americas", 30.1328, -97.6411, "2021-10-24T19:00:00Z", "game", "cota"),
    ]),
]

for name, data in [("teams", teams_out), ("venues", venues_out), ("games", games_out), ("photos", photos_out),
                   ("people", PEOPLE), ("trips", trips_out), ("profile", PROFILE)]:
    (OUT / f"{name}.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {name}.json ({len(data) if isinstance(data, list) else 1})")
