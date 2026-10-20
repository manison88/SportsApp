"""The competitions of the tournament layer (ids are the schedule keys: ESPN league paths where ESPN has the competition, the
Tools/schedules folder names otherwise). Facts as of Oct 20, 2026, from the Wikipedia pages and federation pages cited in
docs/TOURNAMENTS.md. "feed": {"espn": path} when the app's game lookup can ask ESPN; {"espn": None, "pack": slug} when a schedule
pack exists in Tools/schedules (FIBA-sourced packs are held back from publishing, see Tools/packs/build_packs.py HELD_SOURCES);
{"espn": None, "pack": None} when there is no schedule feed at all.
"""

TZ = {"RO": "Europe/Bucharest", "IT": "Europe/Rome", "ES": "Europe/Madrid", "BG": "Europe/Sofia", "BA": "Europe/Sarajevo",
      "CZ": "Europe/Prague", "TR": "Europe/Istanbul", "GR": "Europe/Athens", "AZ": "Asia/Baku", "IL": "Asia/Jerusalem",
      "PL": "Europe/Warsaw", "RS": "Europe/Belgrade", "AT": "Europe/Vienna", "PT": "Europe/Lisbon", "CH": "Europe/Zurich",
      "DK": "Europe/Copenhagen", "SK": "Europe/Bratislava", "FI": "Europe/Helsinki", "BE": "Europe/Brussels", "CY": "Asia/Nicosia",
      "HU": "Europe/Budapest", "XK": "Europe/Belgrade", "EE": "Europe/Tallinn", "FR": "Europe/Paris", "MK": "Europe/Skopje",
      "SN": "Africa/Dakar", "AO": "Africa/Luanda", "EG": "Africa/Cairo", "CN": "Asia/Shanghai", "US": "America/Los_Angeles",
      "QA": "Asia/Qatar", "DE": "Europe/Berlin", "SE": "Europe/Stockholm", "LT": "Europe/Vilnius", "LV": "Europe/Riga",
      "SI": "Europe/Ljubljana", "NO": "Europe/Oslo"}

# Grounds the upcoming tournaments use that venues.json lacks. Coordinates: OpenStreetMap Nominatim, checked against the ground's
# Wikipedia page; sports/leagues say which competitions play there.
VENUES = [
    {"id": "intuit-dome", "name": "Intuit Dome", "aliases": [], "city": "Inglewood", "region": "California", "country": "United States",
     "countryCode": "US", "latitude": 33.94426, "longitude": -118.34217, "sports": ["basketball"],
     "leagues": ["basketball/nba", "basketball/mens-olympics-basketball", "basketball/womens-olympics-basketball"],
     "homeTeams": ["Los Angeles Clippers"], "timeZone": "America/Los_Angeles", "capacity": 18000, "opened": 2024},
    {"id": "al-janoub-stadium", "name": "Al Janoub Stadium", "aliases": ["Al Wakrah Stadium"], "city": "Al Wakrah", "region": None,
     "country": "Qatar", "countryCode": "QA", "latitude": 25.15971, "longitude": 51.57423, "sports": ["soccer", "basketball"],
     "leagues": ["basketball/fiba.worldcup"], "homeTeams": [], "timeZone": "Asia/Qatar", "capacity": 40000, "opened": 2019},
    # NFL International Series: the Mexico City game returns in 2026 (Estadio Azteca, renamed Estadio Banorte after renovation)
    {"id": "estadio-azteca", "name": "Estadio Azteca", "aliases": ["Estadio Banorte"], "city": "Mexico City", "region": None,
     "country": "Mexico", "countryCode": "MX", "latitude": 19.30306, "longitude": -99.15056, "sports": ["football"],
     "leagues": ["football/nfl"], "homeTeams": [], "timeZone": "America/Mexico_City", "capacity": 83264, "opened": 1966},
]

def _v(id, name, city, country, cc, lat, lon, sports, leagues, tz, aliases=(), capacity=None):
    return {"id": id, "name": name, "aliases": list(aliases), "city": city, "region": None, "country": country, "countryCode": cc,
            "latitude": lat, "longitude": lon, "sports": sports, "leagues": leagues, "homeTeams": [], "timeZone": tz, "capacity": capacity, "opened": None}


# Hosts of the next big editions (Wikipedia: venue and bid sections; coordinates from OpenStreetMap Nominatim / the ground's Wikipedia page)
VENUES += [
    _v("sportpaleis-antwerp", "Sportpaleis", "Antwerp", "Belgium", "BE", 51.23184, 4.44091, ["basketball"], ["basketball/fiba.eurobasket.w"], "Europe/Brussels", [], 20000),
    _v("unibet-arena-tallinn", "Unibet Arena", "Tallinn", "Estonia", "EE", 59.42598, 24.64737, ["basketball"], ["basketball/fiba.eurobasket"], "Europe/Tallinn", ["Tallinn Arena", "Saku Suurhall"], 10000),
    _v("ali-bin-hamad-al-attiyah-arena", "Ali Bin Hamad Al Attiyah Arena", "Doha", "Qatar", "QA", 25.27004, 51.48983, ["basketball", "handball"], ["basketball/fiba.worldcup"], "Asia/Qatar", ["Al Attiyah Arena"]),
    _v("duhail-handball-sports-hall", "Duhail Handball Sports Hall", "Doha", "Qatar", "QA", 25.3711, 51.4706, ["basketball", "handball"], ["basketball/fiba.worldcup"], "Asia/Qatar", ["Duhail Arena"]),
]

# Grounds the catalog has that these tournaments also use: only what to add (sports, league keys). Others (name, coordinates) come from venues.json.
ENRICH = {
    "lusail-sports-arena": (["basketball"], ["basketball/fiba.worldcup"]),
    "oaka-indoor-hall": ([], ["basketball/fiba.eurobasket"]),
    "stozice-stadium": ([], ["basketball/fiba.eurobasket"]),
    "movistar-arena-madrid": ([], ["basketball/fiba.eurobasket"]),
    "nokia-arena": (["basketball"], ["basketball/fiba.eurobasket"]),
    "metro-areena": (["basketball"], ["basketball/fiba.eurobasket.w"]),
    "accor-arena": (["hockey", "basketball"], ["hockey/iihf.worlds"]),
    "ldlc-arena": (["hockey"], ["hockey/iihf.worlds"]),
    "psd-bank-dome": ([], ["hockey/iihf.worlds"]),
    "sap-arena": ([], ["hockey/iihf.worlds"]),
    "lanxess-arena": ([], ["handball/ihf.worldchamp"]),
    "dodger": ([], ["baseball/olympics-baseball"]),
}

BODY = {"bb": "FIBA", "hk": "IIHF", "hb": "IHF"}


def comp(id, name, sport, gender, kind, level, body, cadence, last=None, next=None, feed=None, aliases=(), sources=(), note=None):
    return {"id": id, "name": name, "aliases": list(aliases), "sport": sport, "gender": gender, "kind": kind, "level": level,
            "governingBody": body, "cadence": cadence, "lastEdition": last, "nextEdition": next, "feed": feed or {"espn": None, "pack": None},
            "sources": list(sources), "note": note, "teamIds": []}


WP = "https://en.wikipedia.org/wiki/"


def build(x):
    S, out = x["S"], []

    def add(c, ids):
        c["teamIds"] = list(ids)
        out.append(c)

    bbm, bbw = x["bb_men"], x["bb_women"]
    PACK = lambda slug: {"espn": None, "pack": slug, "held": True}
    # ------------------------------------------------------------------ basketball, men
    add(comp("basketball/fiba.worldcup", "FIBA Basketball World Cup", "basketball", "men", "national", "world", "FIBA", "every 4 years",
             last={"year": 2023, "host": "Philippines, Japan, Indonesia", "champion": "Germany"},
             next={"year": 2027, "dates": "2027-08-27/2027-09-12", "hosts": ["Qatar"], "venues": ["Lusail Sports Arena", "Al Attiyah Arena", "Duhail Arena", "Al Janoub Stadium"]},
             feed=PACK("basketball-fiba.worldcup"), aliases=["World Cup", "FIBA World Cup", "Basketball World Cup", "FIBA WC"],
             sources=[WP + "2027_FIBA_Basketball_World_Cup"],
             note="Teams are the 80 teams of the 2027 qualifiers (Qatar, the host, among them); 32 will play."), bbm(S.WQ_2027))
    add(comp("basketball/fiba.worldcupq", "FIBA World Cup qualifiers", "basketball", "men", "national", "world", "FIBA",
             "six windows per cycle", last=None,
             next={"year": 2026, "dates": "2026-11-23/2026-12-01", "note": "window 5; window 6 is 2027-02-22/2027-03-02"},
             feed=PACK("basketball-fiba.worldcupq"), aliases=["World Cup qualifying", "FIBA qualifiers", "WC qualifiers", "Window"],
             sources=[WP + "2027_FIBA_Basketball_World_Cup_qualification"]), bbm(S.WQ_2027))
    zones = [("eurobasket", "EuroBasket", "FIBA Europe", "E", {"year": 2025, "host": "Cyprus, Finland, Latvia, Poland", "champion": "Germany"},
              {"year": 2029, "dates": "2029-09-04/2029-09-21", "hosts": ["Estonia", "Greece", "Slovenia", "Spain"]}, ["European Championship", "FIBA EuroBasket", "Eurobasket"]),
             ("americup", "FIBA AmeriCup", "FIBA Americas", "A", {"year": 2025, "host": "Nicaragua (Managua)", "champion": "Brazil"},
              {"year": 2029, "dates": None, "hosts": [], "note": "four-year cycle since 2017; host not confirmed in the sources read"}, ["AmeriCup", "Americas Championship"]),
             ("afrobasket", "AfroBasket", "FIBA Africa", "F", {"year": 2025, "host": "Angola (Luanda)", "champion": "Angola"},
              {"year": 2029, "dates": None, "hosts": [], "note": "host not confirmed in the sources read"}, ["FIBA AfroBasket", "African Championship"]),
             ("asiacup", "FIBA Asia Cup", "FIBA Asia", "S", {"year": 2025, "host": "Saudi Arabia (Jeddah)", "champion": "Australia"},
              {"year": 2029, "dates": None, "hosts": [], "note": "host not confirmed in the sources read; Australia and New Zealand play in it"}, ["Asia Cup", "FIBA Asia Championship"])]
    for slug, name, body, z, last, nxt, al in zones:
        add(comp(f"basketball/fiba.{slug}", name, "basketball", "men", "national", "continental", body, "every 4 years", last=last, next=nxt,
                 feed=PACK(f"basketball-fiba.{slug}"), aliases=al, sources=[WP + {"eurobasket": "EuroBasket_2025", "americup": "2025_FIBA_AmeriCup", "afrobasket": "AfroBasket_2025", "asiacup": "2025_FIBA_Asia_Cup"}[slug]],
                 note=f"Teams are every FIBA {z} member the catalog lists (zone {z}); 12 to 24 play each edition."),
            bbm(S.zone(S.MEN_BB, z)))
    add(comp("basketball/fiba.eurobasketq", "EuroBasket qualifiers", "basketball", "men", "national", "continental", "FIBA Europe", "2025-2029 cycle",
             next={"year": 2026, "dates": "2026-11-23/2026-12-01", "note": "pre-qualifiers round 2 and the World Cup window; EuroBasket 2029 qualifiers run Feb 2028 to Feb 2029"},
             feed=PACK("basketball-fiba.eurobasketq"), aliases=["EuroBasket pre-qualifiers"], sources=[WP + "EuroBasket_2029_qualification"]), bbm(S.zone(S.MEN_BB, "E")))
    add(comp("basketball/fiba.americupq", "AmeriCup qualifiers", "basketball", "men", "national", "continental", "FIBA Americas", "cycle", feed=PACK("basketball-fiba.americupq"),
             aliases=["AmeriCup pre-qualifiers"]), bbm(S.zone(S.MEN_BB, "A")))
    add(comp("basketball/fiba.afrobasketq", "AfroBasket qualifiers", "basketball", "men", "national", "continental", "FIBA Africa", "cycle", feed=PACK("basketball-fiba.afrobasketq")), bbm(S.zone(S.MEN_BB, "F")))
    add(comp("basketball/fiba.asiacupq", "Asia Cup qualifiers", "basketball", "men", "national", "continental", "FIBA Asia", "cycle", feed=PACK("basketball-fiba.asiacupq")), bbm(S.zone(S.MEN_BB, "S")))
    add(comp("basketball/mens-olympics-basketball", "Olympic basketball (men)", "basketball", "men", "national", "multi-sport", "FIBA / IOC", "every 4 years",
             last={"year": 2024, "host": "Paris", "champion": "United States"}, next={"year": 2028, "dates": "2028-07-14/2028-07-30", "hosts": ["Los Angeles"], "venues": ["Intuit Dome"]},
             feed={"espn": "basketball/mens-olympics-basketball", "pack": "basketball-mens-olympics-basketball"}, aliases=["Olympics", "Olympic Games basketball", "5x5"],
             sources=[WP + "Basketball_at_the_2028_Summer_Olympics"], note="Teams are the 12 of Paris 2024; the 2028 field is decided by the 2027 World Cup and the qualifying tournaments."), bbm(S.BB_OLY_2024))
    # ------------------------------------------------------------------ basketball, women
    add(comp("basketball/fiba.worldcup.w", "FIBA Women's Basketball World Cup", "basketball", "women", "national", "world", "FIBA", "every 4 years",
             last={"year": 2026, "host": "Germany (Berlin)", "champion": "United States", "dates": "2026-09-04/2026-09-13"},
             next={"year": 2030, "dates": None, "hosts": []}, feed={"espn": "basketball/fiba", "pack": "basketball-fiba.worldcup.w", "held": True},
             aliases=["Women's World Cup", "FIBA Women's World Cup"], sources=[WP + "2026_FIBA_Women's_Basketball_World_Cup"]), bbw(S.WBB_WC_2026))
    wz = [("eurobasket.w", "EuroBasket Women", "FIBA Europe", "E", {"year": 2025, "champion": "Belgium"}, {"year": 2027, "dates": "2027-06-16/2027-06-27", "hosts": ["Belgium", "Finland", "Lithuania", "Sweden"]}, "every 2 years", ["Women's EuroBasket", "FIBA Women's EuroBasket"]),
          ("americup.w", "FIBA Women's AmeriCup", "FIBA Americas", "A", {"year": 2025}, {"year": 2027, "dates": None, "hosts": [], "note": "biennial; host not confirmed in the sources read"}, "every 2 years", ["Women's AmeriCup"]),
          ("afrobasket.w", "Women's AfroBasket", "FIBA Africa", "F", {"year": 2025}, {"year": 2027, "dates": None, "hosts": [], "note": "biennial; host not confirmed in the sources read"}, "every 2 years", ["AfroBasket Women", "FIBA Women's AfroBasket"]),
          ("asiacup.w", "FIBA Women's Asia Cup", "FIBA Asia", "S", {"year": 2025}, {"year": 2027, "dates": None, "hosts": []}, "every 2 years", ["Women's Asia Cup"])]
    for slug, name, body, z, last, nxt, cad, al in wz:
        add(comp(f"basketball/fiba.{slug}", name, "basketball", "women", "national", "continental", body, cad, last=last, next=nxt,
                 feed=PACK(f"basketball-fiba.{slug}"), aliases=al, note=f"Teams are every FIBA {z} member with a women's team in the catalog.",
                 sources=[WP + "EuroBasket_Women_2027"] if slug == "eurobasket.w" else []), bbw(S.zone(S.WOMEN_BB, z)))
    add(comp("basketball/womens-olympics-basketball", "Olympic basketball (women)", "basketball", "women", "national", "multi-sport", "FIBA / IOC", "every 4 years",
             last={"year": 2024, "host": "Paris", "champion": "United States"}, next={"year": 2028, "dates": "2028-07-14/2028-07-30", "hosts": ["Los Angeles"], "venues": ["Intuit Dome"]},
             feed={"espn": "basketball/womens-olympics-basketball", "pack": "basketball-womens-olympics-basketball"}, aliases=["Olympics women's basketball"]), bbw(S.WBB_OLY_2024))
    # ------------------------------------------------------------------ basketball, clubs
    cl = x["clubs_in"]
    eurol = [i for i in x["catalog"] if i.startswith("eurol-")]
    add(comp("basketball/euroleague", "EuroLeague", "basketball", "men", "club", "continental", "Euroleague Basketball", "annual (Sep to May)",
             last={"year": 2026, "champion": "Olympiacos"}, next={"year": 2026, "dates": "2026-09-24/2027-04-16", "note": "2026-27 regular season; Final Four May 2027"},
             feed={"espn": "basketball/euroleague", "pack": "basketball-euroleague"}, aliases=["Euroleague", "Turkish Airlines EuroLeague"],
             sources=[WP + "2026–27_EuroLeague"]), eurol)
    add(comp("basketball/eurocup", "EuroCup", "basketball", "men", "club", "continental", "Euroleague Basketball", "annual (Sep to Apr)",
             last={"year": 2026, "champion": "Cosea JL Bourg"}, next={"year": 2026, "note": "2026-27 season, 32 clubs in four groups of eight, started 2026-09-29"},
             feed={"espn": None, "pack": "basketball-eurocup"}, aliases=["Eurocup", "BKT EuroCup"], sources=[WP + "2026–27_EuroCup_Basketball"]), cl("EC"))
    add(comp("basketball/fiba.bcl", "Basketball Champions League", "basketball", "men", "club", "continental", "FIBA Europe", "annual (Sep to May)",
             last={"year": 2026, "champion": "Rytas"}, next={"year": 2026, "note": "2026-27 season, 54 clubs; the two finalists get places in the planned NBA Europe"},
             feed=PACK("basketball-fiba.bcl"), aliases=["BCL", "Champions League basketball"], sources=[WP + "2026–27_Basketball_Champions_League"]), cl("CL"))
    add(comp("basketball/fiba.europecup", "FIBA Europe Cup", "basketball", "men", "club", "continental", "FIBA Europe", "annual (Sep to Apr)",
             next={"year": 2026, "note": "2026-27 season: 48 clubs in the regular season from 2026-10-06"}, feed=PACK("basketball-fiba.europecup"),
             aliases=["Europe Cup"], sources=[WP + "2026–27_FIBA_Europe_Cup"]), cl("EU"))
    add(comp("basketball/fiba.bal", "Basketball Africa League", "basketball", "men", "club", "continental", "NBA Africa / FIBA", "annual (Mar to Jun)",
             last={"year": 2026, "champion": "RSSB Tigers", "host": "Kigali (BK Arena)"}, feed=PACK("basketball-fiba.bal"), aliases=["BAL"],
             sources=[WP + "2026_BAL_season"], note="The 2026 clubs the catalog lists; APR withdrew."), cl("BAL"))
    add(comp("basketball/fiba.intercontinental", "FIBA Intercontinental Cup", "basketball", "men", "club", "world", "FIBA", "annual",
             last={"year": 2026, "host": "Beijing (National Indoor Stadium)", "dates": "2026-09"}, feed=PACK("basketball-fiba.intercontinental"),
             aliases=["Intercontinental Cup basketball"], sources=[WP + "2026_FIBA_Intercontinental_Cup"]), cl("IC") + ["lkl-ryt"])
    # ------------------------------------------------------------------ hockey
    hk, hkw = x["hk_men"], x["hk_women"]
    add(comp("hockey/iihf.worlds", "IIHF World Championship", "hockey", "men", "national", "world", "IIHF", "annual (May)",
             last={"year": 2026, "host": "Switzerland (Zurich, Fribourg)", "champion": "Finland", "dates": "2026-05-15/2026-05-31"},
             next={"year": 2027, "dates": "2027-05-13/2027-05-30", "hosts": ["Germany (Dusseldorf, Mannheim, Gelsenkirchen)"], "note": "2028: Paris and Lyon, 2028-05-12/2028-05-28"},
             feed={"espn": None, "pack": "hockey-iihf.worlds", "held": True}, aliases=["World Championship", "IIHF Worlds", "Ice Hockey World Championships", "Worlds"],
             sources=[WP + "2027_IIHF_World_Championship", WP + "2026_IIHF_World_Championship"], note="Teams: the Top Division of 2026 and 2027 and Divisions I A and I B of 2026."), hk(S.HK_MEN))
    add(comp("hockey/olympics-mens-ice-hockey", "Olympic ice hockey (men)", "hockey", "men", "national", "multi-sport", "IIHF / IOC", "every 4 years",
             last={"year": 2026, "host": "Milan", "champion": "United States"}, next={"year": 2030, "hosts": ["French Alps"], "dates": None},
             feed={"espn": "hockey/olympics-mens-ice-hockey", "pack": "hockey-olympics-mens-ice-hockey"}, aliases=["Olympics hockey"], sources=[WP + "Ice_hockey_at_the_2026_Winter_Olympics_–_Men's_tournament"]), hk(S.HK_OLY_2026))
    add(comp("hockey/olympics-womens-ice-hockey", "Olympic ice hockey (women)", "hockey", "women", "national", "multi-sport", "IIHF / IOC", "every 4 years",
             last={"year": 2026, "host": "Milan"}, feed={"espn": "hockey/olympics-womens-ice-hockey", "pack": "hockey-olympics-womens-ice-hockey"}), hkw(S.HK_W_OLY_2026))
    add(comp("hockey/iihf.worlds.w", "IIHF Women's World Championship", "hockey", "women", "national", "world", "IIHF", "annual (spring), 2026 moved to November",
             next={"year": 2026, "dates": "2026-11-06/2026-11-16", "hosts": ["Denmark (Herning, Esbjerg)"]}, feed={"espn": None, "pack": "hockey-iihf.worlds.w", "held": True},
             aliases=["Women's Worlds"], sources=[WP + "2026_IIHF_Women's_World_Championship"]), hkw(S.HK_WOMEN))
    add(comp("hockey/hockey-world-cup", "World Cup of Hockey", "hockey", "men", "national", "world", "NHL / NHLPA / IIHF", "irregular",
             last={"year": 2016, "champion": "Canada"}, next={"year": 2028, "dates": "2028-02", "note": "eight teams, three host cities"},
             feed={"espn": "hockey/hockey-world-cup", "pack": "hockey-hockey-world-cup"}, sources=[WP + "2028_World_Cup_of_Hockey"]), hk(S.HK_WCH_2028))
    add(comp("hockey/4-nations-face-off", "4 Nations Face-Off", "hockey", "men", "national", "world", "NHL / NHLPA", "one-off (Feb 2025)",
             last={"year": 2025, "host": "Montreal, Boston", "champion": "Canada"}, sources=[WP + "2025_4_Nations_Face-Off"]), hk(["CAN", "USA", "SWE", "FIN"]))
    add(comp("hockey/chl", "Champions Hockey League", "hockey", "men", "club", "continental", "CHL / IIHF", "annual (Aug to Feb)",
             next={"year": 2026, "note": "2026-27 season, 24 clubs"}, aliases=["CHL", "Champions League hockey"], sources=[WP + "2026–27_Champions_Hockey_League"],
             note="Clubs the catalog could match by name; the rest are listed in unmatchedClubs."), x["chl"])
    out[-1]["unmatchedClubs"] = x["chl_missing"]
    # ------------------------------------------------------------------ handball
    hb, hbw = x["hb_men"], x["hb_women"]
    add(comp("handball/ihf.worldchamp", "IHF Men's World Championship", "handball", "men", "national", "world", "IHF", "every 2 years",
             last={"year": 2025, "host": "Croatia, Denmark, Norway", "champion": "Denmark"}, next={"year": 2027, "dates": "2027-01-13/2027-01-31", "hosts": ["Germany"], "note": "final in Cologne (Lanxess Arena)"},
             feed={"espn": None, "pack": "handball-ihf.worldchamp", "held": True}, aliases=["World Championship handball", "Handball World Cup"], sources=[WP + "2027_World_Men's_Handball_Championship"]), hb(S.HB_WORLDS_2027))
    add(comp("handball/ehf.euro", "EHF European Men's Championship", "handball", "men", "national", "continental", "EHF", "every 2 years",
             last={"year": 2026, "host": "Denmark, Norway, Sweden", "dates": "2026-01-15/2026-02-01"}, next={"year": 2028, "dates": "2028-01-13/2028-01-30", "hosts": ["Portugal", "Spain", "Switzerland"]},
             feed={"espn": None, "pack": "handball-ehf.euro", "held": True}, aliases=["Euro handball", "EHF Euro", "European Championship handball"], sources=[WP + "2026_European_Men's_Handball_Championship"]), hb(S.HB_EURO_2026))
    add(comp("handball/ihf.worldchamp.w", "IHF Women's World Championship", "handball", "women", "national", "world", "IHF", "every 2 years",
             last={"year": 2025, "host": "Germany, Netherlands", "dates": "2025-11-26/2025-12-14"}, next={"year": 2027, "dates": "2027-11-30/2027-12-19", "hosts": ["Hungary"]},
             feed={"espn": None, "pack": "handball-ihf.worldchamp.w", "held": True}, sources=[WP + "2027_World_Women's_Handball_Championship"]), hbw(S.HB_W_WORLDS_2025))
    add(comp("handball/ehf.euro.w", "EHF European Women's Championship", "handball", "women", "national", "continental", "EHF", "every 2 years",
             next={"year": 2026, "dates": "2026-12-03/2026-12-20", "hosts": ["Czechia", "Poland", "Romania", "Slovakia", "Turkey"], "note": "final in Katowice"},
             feed={"espn": None, "pack": "handball-ehf.euro.w", "held": True}, sources=[WP + "2026_European_Women's_Handball_Championship"]), hbw(S.HB_W_EURO_2026))
    add(comp("handball/olympics.mens", "Olympic handball (men)", "handball", "men", "national", "multi-sport", "IHF / IOC", "every 4 years",
             last={"year": 2024, "host": "Paris", "champion": "Denmark"}, next={"year": 2028, "hosts": ["Los Angeles"]}, feed={"espn": None, "pack": "handball-olympics.mens"}), hb(S.HB_OLY_2024))
    add(comp("handball/olympics.womens", "Olympic handball (women)", "handball", "women", "national", "multi-sport", "IHF / IOC", "every 4 years",
             last={"year": 2024, "host": "Paris", "champion": "Norway"}, next={"year": 2028, "hosts": ["Los Angeles"]}, feed={"espn": None, "pack": "handball-olympics.womens"}), hbw(S.HB_W_OLY_2024))
    # ------------------------------------------------------------------ baseball
    bs = x["bsb"]
    add(comp("baseball/world-baseball-classic", "World Baseball Classic", "baseball", "men", "national", "world", "WBSC / MLB", "every 3 to 4 years",
             last={"year": 2026, "host": "Tokyo, San Juan, Houston, Miami", "champion": "Venezuela"}, next={"year": 2029, "dates": None},
             feed={"espn": "baseball/world-baseball-classic", "pack": "baseball-world-baseball-classic"}, aliases=["WBC", "Classic"], sources=[WP + "2026_World_Baseball_Classic"],
             note="Teams: the 20 of 2026 plus the four 2026 qualifier teams that missed it (China, Germany, Spain, South Africa)."), bs(S.WBC_2026 + ["CHN", "GER", "ESP", "RSA"]))
    add(comp("baseball/premier12", "WBSC Premier12", "baseball", "men", "national", "world", "WBSC", "every 4 years",
             last={"year": 2024}, next={"year": 2027, "dates": "2027-11", "note": "also the Olympic qualifier"}, aliases=["Premier 12"], sources=[WP + "WBSC_Premier12"]), bs(S.PREMIER12_2024))
    add(comp("baseball/olympics-baseball", "Olympic baseball", "baseball", "men", "national", "multi-sport", "WBSC / IOC", "when on the program",
             last={"year": 2021, "host": "Tokyo", "champion": "Japan"}, next={"year": 2028, "hosts": ["Los Angeles (Dodger Stadium)"], "note": "six teams; United States, Dominican Republic and Venezuela qualified so far"},
             feed={"espn": "baseball/olympics-baseball", "pack": "baseball-olympics-baseball"}, sources=[WP + "Baseball_at_the_2028_Summer_Olympics"]), bs(["USA", "DOM", "VEN"]))
    # ------------------------------------------------------------------ soccer (ESPN keys)
    mn, wn = x["men_nat"], x["women_nat"]
    SOC = [("fifa.world", "FIFA World Cup", "world", "FIFA", "every 4 years", {"year": 2026, "host": "Canada, Mexico, United States"}, {"year": 2030, "hosts": ["Morocco", "Portugal", "Spain"]}, ["World Cup"]),
           ("uefa.euro", "UEFA European Championship", "continental", "UEFA", "every 4 years", {"year": 2024, "host": "Germany"}, {"year": 2028, "hosts": ["England", "Scotland", "Wales", "Ireland", "Northern Ireland"]}, ["Euros", "Euro"]),
           ("uefa.nations", "UEFA Nations League", "continental", "UEFA", "every 2 years", None, {"year": 2026, "note": "2026-27 league phase"}, ["Nations League"]),
           ("conmebol.america", "Copa America", "continental", "CONMEBOL", "every 4 years", {"year": 2024, "host": "United States"}, {"year": 2028, "hosts": ["United States"]}, ["Copa América"]),
           ("concacaf.gold", "CONCACAF Gold Cup", "continental", "CONCACAF", "every 2 years", {"year": 2025}, {"year": 2027}, ["Gold Cup"]),
           ("concacaf.nations.league", "CONCACAF Nations League", "continental", "CONCACAF", "every 2 years", None, None, []),
           ("caf.nations", "Africa Cup of Nations", "continental", "CAF", "every 2 years", {"year": 2025, "host": "Morocco"}, {"year": 2027, "hosts": ["Kenya", "Tanzania", "Uganda"]}, ["AFCON"]),
           ("afc.asian.cup", "AFC Asian Cup", "continental", "AFC", "every 4 years", {"year": 2023, "host": "Qatar"}, {"year": 2027, "hosts": ["Saudi Arabia"]}, ["Asian Cup"]),
           ("global.finalissima", "CONMEBOL-UEFA Cup of Champions", "world", "UEFA / CONMEBOL", "irregular", None, None, ["Finalissima"]),
           ("fifa.worldq.uefa", "World Cup qualifying, UEFA", "continental", "UEFA", "every 4 years", None, None, []),
           ("fifa.worldq.conmebol", "World Cup qualifying, CONMEBOL", "continental", "CONMEBOL", "every 4 years", None, None, []),
           ("fifa.worldq.concacaf", "World Cup qualifying, CONCACAF", "continental", "CONCACAF", "every 4 years", None, None, []),
           ("fifa.worldq.afc", "World Cup qualifying, AFC", "continental", "AFC", "every 4 years", None, None, []),
           ("fifa.worldq.caf", "World Cup qualifying, CAF", "continental", "CAF", "every 4 years", None, None, []),
           ("fifa.worldq.ofc", "World Cup qualifying, OFC", "continental", "OFC", "every 4 years", None, None, []),
           ("uefa.euroq", "European Championship qualifying", "continental", "UEFA", "every 4 years", None, None, [])]
    for lg, name, lvl, body, cad, last, nxt, al in SOC:
        add(comp(f"soccer/{lg}", name, "soccer", "men", "national", lvl, body, cad, last=last, next=nxt, feed={"espn": f"soccer/{lg}", "pack": f"soccer-{lg}"}, aliases=al), mn(lg))
    SOCW = [("fifa.wwc", "FIFA Women's World Cup", "world", "FIFA", "every 4 years", {"year": 2023, "host": "Australia, New Zealand"}, {"year": 2027, "hosts": ["Brazil"]}, ["Women's World Cup"]),
            ("uefa.weuro", "UEFA Women's Euro", "continental", "UEFA", "every 4 years", {"year": 2025, "host": "Switzerland"}, None, ["Women's Euros"]),
            ("uefa.w.nations", "UEFA Women's Nations League", "continental", "UEFA", "every 2 years", None, None, []),
            ("concacaf.w.gold", "CONCACAF W Gold Cup", "continental", "CONCACAF", "every 4 years", {"year": 2024}, None, []),
            ("conmebol.america.femenina", "Copa America Femenina", "continental", "CONMEBOL", "every 4 years", {"year": 2025}, None, []),
            ("caf.w.nations", "Women's Africa Cup of Nations", "continental", "CAF", "every 2 years", {"year": 2024}, None, ["WAFCON"]),
            ("afc.w.asian.cup", "AFC Women's Asian Cup", "continental", "AFC", "every 4 years", {"year": 2026}, None, []),
            ("fifa.w.olympics", "Olympic football (women)", "multi-sport", "FIFA / IOC", "every 4 years", {"year": 2024}, {"year": 2028}, []),
            ("fifa.shebelieves", "SheBelieves Cup", "world", "US Soccer", "annual", None, None, []),
            ("fifa.wworldq.uefa", "Women's World Cup qualifying, UEFA", "continental", "UEFA", "every 4 years", None, None, []),
            ("fifa.wwcq.ply", "Women's World Cup play-offs", "world", "FIFA", "every 4 years", None, None, []),
            ("fifa.friendly.w", "Women's international friendlies", "world", "FIFA", "ongoing", None, None, ["Friendlies"])]
    for lg, name, lvl, body, cad, last, nxt, al in SOCW:
        add(comp(f"soccer/{lg}", name, "soccer", "women", "national", lvl, body, cad, last=last, next=nxt, feed={"espn": f"soccer/{lg}", "pack": None}, aliases=al), wn(lg))
    CLUBC = [("uefa.champions", "UEFA Champions League", "UEFA", ["UCL", "Champions League"]), ("uefa.europa", "UEFA Europa League", "UEFA", ["UEL"]),
             ("uefa.europa.conf", "UEFA Conference League", "UEFA", ["UECL"]), ("conmebol.libertadores", "Copa Libertadores", "CONMEBOL", []),
             ("conmebol.sudamericana", "Copa Sudamericana", "CONMEBOL", []), ("concacaf.champions", "CONCACAF Champions Cup", "CONCACAF", ["CCC"]),
             ("concacaf.leagues.cup", "Leagues Cup", "CONCACAF / MLS / Liga MX", []), ("afc.champions", "AFC Champions League Elite", "AFC", ["ACL"]),
             ("afc.cup", "AFC Champions League Two", "AFC", ["AFC Cup"]), ("caf.champions", "CAF Champions League", "CAF", []),
             ("caf.confed", "CAF Confederation Cup", "CAF", []), ("fifa.cwc", "FIFA Club World Cup", "FIFA", ["Club World Cup"]),
             ("uefa.wchampions", "UEFA Women's Champions League", "UEFA", ["UWCL"])]
    for lg, name, body, al in CLUBC:
        add(comp(f"soccer/{lg}", name, "soccer", "women" if "wchamp" in lg else "men", "club", "continental" if lg != "fifa.cwc" else "world", body,
                 "annual" if lg != "fifa.cwc" else "every 4 years", feed={"espn": f"soccer/{lg}", "pack": f"soccer-{lg}"}, aliases=al,
                 last={"year": 2025, "host": "United States"} if lg == "fifa.cwc" else None, next={"year": 2029} if lg == "fifa.cwc" else None),
            x["club_comp"](lg))
    # ------------------------------------------------------------------ american football
    nfl = [t["id"] for t in x["catalog"].values() if t["sport"] == "football" and (t.get("leagueKey") == "football/nfl" or t["id"].startswith("nfl-"))]
    add(comp("football/nfl-international-series", "NFL International Series", "football", "men", "club", "world", "NFL", "annual (regular-season games abroad)",
             last={"year": 2025, "host": "Dublin, Berlin, Madrid, Sao Paulo, London"},
             next={"year": 2026, "note": "regular-season games at Wembley and Tottenham, Munich (Allianz Arena), Madrid, Paris (Stade de France), Rio (Maracana), Melbourne (MCG) and Mexico City; Germany continues to 2029, up to ten games in 2027"},
             feed={"espn": "football/nfl", "pack": None}, aliases=["NFL London", "NFL Germany", "NFL Brazil", "NFL Madrid", "NFL Paris", "NFL Australia", "NFL Mexico"],
             sources=[WP + "NFL_International_Series"],
             note="Games are NFL games (ESPN football/nfl) at the grounds the venues list carries league football/nfl for. National-team American football has no scheduled tournament: the IFAF World Championship has not been held since 2015, and flag football's Olympic debut (Los Angeles 2028, BMO Stadium) has no qualified field yet."), nfl)
    # ------------------------------------------------------------------ motorsport
    f1 = [t["id"] for t in x["catalog"].values() if t.get("leagueKey") == "motorsport/f1"] + [t["id"] for t in x["teams"] if t.get("leagueKey") == "motorsport/f1"]
    add(comp("motorsport/f1", "Formula 1 World Championship", "motorsport", "mixed", "club", "world", "FIA", "annual (Mar to Dec)",
             last={"year": 2026}, next={"year": 2027}, feed={"espn": None, "pack": None, "calendar": "Catalog/f1-calendar.json"},
             aliases=["F1", "Formula One", "Grand Prix"], sources=[WP + "2026_Formula_One_World_Championship"],
             note="Races come from the bundled calendar (Catalog/f1-calendar.json); circuits are the venues (Catalog/f1-circuits.json)."), f1)
    return out
