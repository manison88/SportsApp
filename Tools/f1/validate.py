#!/usr/bin/env python3
"""Validates Tools/f1/circuits.json, calendar.json and constructors-drivers.json.
Usage: python3 Tools/f1/validate.py [dir]      (defaults to this file's directory)
Exit code 0 only when there are 0 errors."""
import json, os, re, sys, datetime as dt
from zoneinfo import ZoneInfo

d = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
errors, warnings = [], []
def err(m): errors.append(m)
def warn(m): warnings.append(m)

def load(name):
    try:
        return json.load(open(os.path.join(d, name)))
    except Exception as e:
        err(f"{name}: cannot load: {e}"); return None

circuits = load('circuits.json'); calendar = load('calendar.json'); cd = load('constructors-drivers.json')

SLUG = re.compile(r'[a-z0-9]+(-[a-z0-9]+)*$')
HEX = re.compile(r'[0-9A-Fa-f]{6}$')

def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def valid_ll(p):
    return isinstance(p, (list, tuple)) and len(p) == 2 and all(isinstance(x, (int, float)) for x in p) and -90 <= p[0] <= 90 and -180 <= p[1] <= 180

def dist_m(a, b):
    import math
    R = 6371000; p1, p2 = math.radians(a[0]), math.radians(b[0]); dl = math.radians(b[1] - a[1]); dp = p2 - p1
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))

# ---------------- circuits
cids = {}
if circuits is not None:
    if not isinstance(circuits, list): err('circuits.json: top level must be an array'); circuits = []
    for i, c in enumerate(circuits):
        w = f"circuits[{i}] {c.get('id', '?')}"
        for k in ('id', 'name', 'city', 'country', 'countryCode', 'latitude', 'longitude', 'sports', 'timeZone', 'grandstandsLatLon', 'geofenceMeters', 'direction', 'aliases', 'firstGrandPrix', 'street', 'lapRecord', 'lengthKm', 'turns'):
            if k not in c: err(f"{w}: missing {k}")
        cid = c.get('id', '')
        if not SLUG.match(cid or ''): err(f"{w}: id must be a lowercase slug")
        if cid in cids: err(f"{w}: duplicate id")
        cids[cid] = c
        if not valid_ll([c.get('latitude'), c.get('longitude')]): err(f"{w}: coordinates out of range")
        if 'motorsport' not in c.get('sports', []) or any(s != 'motorsport' for s in c.get('sports', [])): err(f"{w}: sports must be ['motorsport']")
        try: ZoneInfo(c.get('timeZone', ''))
        except Exception: err(f"{w}: bad timeZone")
        if not re.fullmatch(r'[A-Z]{2}', c.get('countryCode') or ''): err(f"{w}: countryCode must be ISO alpha-2")
        for lg in c.get('leagues', []):
            if not re.fullmatch(r'[a-z]+/[a-z0-9.\-]+', lg): err(f"{w}: league '{lg}' not an ESPN path")
        gs = c.get('grandstandsLatLon') or []
        if not gs: err(f"{w}: grandstandsLatLon is empty")
        for p in gs:
            if not valid_ll(p): err(f"{w}: bad grandstand point {p}")
            elif dist_m(p, (c['latitude'], c['longitude'])) > 2500: err(f"{w}: grandstand point {p} is >2.5 km from the venue point")
        if len(c.get('grandstandLabels', gs)) != len(gs): err(f"{w}: grandstandLabels length != grandstandsLatLon length")
        if gs and valid_ll(gs[0]) and dist_m(gs[0], (c['latitude'], c['longitude'])) > 5: err(f"{w}: latitude/longitude must equal the first grandstand point")
        g = c.get('geofenceMeters')
        if not isinstance(g, int) or not 400 <= g <= 1500: err(f"{w}: geofenceMeters must be an int in 400..1500")
        if c.get('direction') not in ('clockwise', 'anticlockwise'): err(f"{w}: direction must be clockwise|anticlockwise")
        if not isinstance(c.get('street'), bool): err(f"{w}: street must be boolean")
        if not isinstance(c.get('firstGrandPrix'), int) or not 1900 <= c['firstGrandPrix'] <= 2026: err(f"{w}: firstGrandPrix must be a year")
        if c.get('lengthKm') is not None and not (1.0 < c['lengthKm'] < 8.0): err(f"{w}: lengthKm out of range")
        if c.get('turns') is not None and not (3 <= c['turns'] <= 30): err(f"{w}: turns out of range")
        lr = c.get('lapRecord')
        if lr is not None:
            if not (isinstance(lr, dict) and re.fullmatch(r'\d:\d\d\.\d{3}', lr.get('time', '')) and lr.get('driver') and isinstance(lr.get('year'), int)):
                err(f"{w}: lapRecord needs time m:ss.mmm, driver, year")
        on26 = c.get('onCalendar2026')
        if on26 or c.get('f1Status') == '2018-2025':
            for k in ('lengthKm', 'turns', 'lapRecord'):
                if c.get(k) is None: err(f"{w}: {k} is required for circuits used 2018-2026")
        if not isinstance(c.get('aliases'), list) or not all(isinstance(a, str) for a in c.get('aliases', [])): err(f"{w}: aliases must be a string array")
        if c.get('checks', {}).get('distToCityKm', 0) > 60: err(f"{w}: venue point is >60 km from the named city")
        if c.get('checks', {}).get('distToCenterlineM') and min(c['checks']['distToCenterlineM']) > 150: err(f"{w}: no grandstand point within 150 m of the track centerline")
        if c.get('coordConfidence') == 'low': warn(f"{w}: low coordinate confidence")
    # existing catalog id reuse
    try:
        cat = {v['id'] for v in json.load(open(os.path.join(d, '..', '..', 'Witness', 'Resources', 'Catalog', 'venues.json')))}
        for cid in cids:
            if cid in cat and not cids[cid].get('reusesCatalogId'): err(f"circuits {cid}: id exists in venues.json but is not marked reusesCatalogId")
        if 'cota' in cids and 'cota' not in cat: err('circuits cota: expected to reuse the existing catalog id')
    except Exception:
        warn('venues.json not found; skipped catalog id reuse check')

# ---------------- constructors / drivers
team_ids, codes = set(), {}
if cd is not None:
    for t in cd.get('teams', []):
        w = f"team {t.get('id', '?')}"
        if not SLUG.match(t.get('id', '')): err(f"{w}: bad id")
        if t['id'] in team_ids: err(f"{w}: duplicate id")
        team_ids.add(t['id'])
        if t.get('sport') != 'motorsport' or t.get('league') != 'Formula 1' or t.get('leagueKey') != 'racing/f1': err(f"{w}: sport/league/leagueKey wrong")
        co = t.get('colors', {})
        for k in ('primary', 'secondary', 'accent'):
            if not HEX.match(co.get(k, '')): err(f"{w}: colors.{k} must be 6 hex digits")
        if HEX.match(co.get('accent', '')) and (lum(co['accent']) + 0.05) / (lum('0B0C10') + 0.05) < 3: err(f"{w}: accent contrast < 3:1 on #0B0C10")
        if not 2 <= len(t.get('abbreviation', '')) <= 4: err(f"{w}: abbreviation must be 2-4 chars")
    abbr = [t['abbreviation'] for t in cd.get('teams', [])]
    if len(set(abbr)) != len(abbr): err('teams: duplicate abbreviation')
    for dr in cd.get('drivers', []):
        w = f"driver {dr.get('id', '?')}"
        if not re.fullmatch(r'[A-Z]{3}', dr.get('code', '')): err(f"{w}: code must be 3 capital letters")
        if dr.get('code') in codes: err(f"{w}: duplicate code {dr.get('code')}")
        codes[dr.get('code')] = dr
        if dr.get('constructorId') not in team_ids: err(f"{w}: constructorId {dr.get('constructorId')} is not a team")
        if not dr.get('seasons') or not all(2018 <= s <= 2026 for s in dr['seasons']): err(f"{w}: seasons must be within 2018..2026")
        for y, lst in dr.get('constructorBySeason', {}).items():
            for x in lst:
                if x not in team_ids: err(f"{w}: constructorBySeason {y} has unknown team {x}")

# ---------------- calendar
if calendar is not None:
    if not isinstance(calendar, list): err('calendar.json: top level must be an array'); calendar = []
    ids = set(); prev = None; per_season = {}
    for i, e in enumerate(calendar):
        w = f"calendar[{i}] {e.get('id', '?')}"
        if e.get('id') in ids: err(f"{w}: duplicate id")
        ids.add(e.get('id'))
        if e.get('circuitId') not in cids: err(f"{w}: circuitId {e.get('circuitId')} not in circuits.json")
        try:
            t = dt.datetime.strptime(e['raceStartUtc'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=dt.timezone.utc)
        except Exception:
            err(f"{w}: raceStartUtc invalid"); continue
        if prev is not None and t <= prev: err(f"{w}: dates not strictly ascending ({e['raceStartUtc']} after {prev.isoformat()})")
        prev = t
        if t.year != e.get('season') and not (t.year == e.get('season')): err(f"{w}: season {e.get('season')} != race year {t.year}")
        c = cids.get(e.get('circuitId'))
        if c:
            ld = t.astimezone(ZoneInfo(c['timeZone'])).strftime('%Y-%m-%d')
            if ld != e.get('raceLocalDate'): err(f"{w}: raceLocalDate {e.get('raceLocalDate')} != {ld} computed from {c['timeZone']}")
        if e.get('status') not in ('completed', 'scheduled', 'cancelled'): err(f"{w}: bad status")
        if e.get('espnLeague') != 'racing/f1' or not e.get('espnEventId'): err(f"{w}: missing ESPN event id / league")
        if not e.get('name') or not e.get('shortName'): err(f"{w}: missing name/shortName")
        ss = e.get('sessions') or []
        if not ss or ss[-1].get('name') != 'Race': err(f"{w}: sessions must end with the Race")
        times = [s['startUtc'] for s in ss]
        if times != sorted(times): err(f"{w}: sessions not in time order")
        if ss and (t - dt.datetime.strptime(ss[0]['startUtc'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=dt.timezone.utc)).days > 5: err(f"{w}: first session is more than 5 days before the race")
        if ss and ss[-1].get('startUtc') != e['raceStartUtc']: err(f"{w}: Race session start != raceStartUtc")
        for s in ss:
            if s['name'] not in ('FP1', 'FP2', 'FP3', 'Sprint Qualifying', 'Sprint', 'Qualifying', 'Race'): err(f"{w}: unknown session {s['name']}")
        r = e.get('results')
        if e.get('status') == 'completed':
            if not r: err(f"{w}: completed race without results"); continue
            p = r.get('podium', [])
            if len(p) != 3: err(f"{w}: podium must have 3 entries")
            for n, x in enumerate(p):
                m = re.fullmatch(r'P(\d) ([A-Z]{3})', x)
                if not m or int(m.group(1)) != n + 1: err(f"{w}: podium entry '{x}' malformed")
                elif codes and m.group(2) not in codes: err(f"{w}: podium code {m.group(2)} not in drivers")
            if p and r.get('winner', {}).get('code') != p[0][3:]: err(f"{w}: winner != P1")
            if not r.get('pole'): err(f"{w}: missing pole")
            if not r.get('fastestLap'): warn(f"{w}: missing fastest lap")
            if e.get('round') is None: err(f"{w}: completed race without round")
        else:
            if r: err(f"{w}: non-completed race must have results null")
        if e.get('status') == 'cancelled' and e.get('round') is not None: err(f"{w}: cancelled race should have round null")
        if e.get('round') is not None:
            per_season.setdefault(e['season'], []).append(e['round'])
    for y, rs in per_season.items():
        if rs != list(range(1, len(rs) + 1)): err(f"season {y}: rounds are not 1..{len(rs)} in order: {rs}")
    seasons = {e['season'] for e in calendar}
    if seasons != set(range(2018, 2027)): err(f"calendar must cover 2018..2026, has {sorted(seasons)}")
    # every circuit marked on the 2026 calendar must have a 2026 event, and vice versa
    c26 = {e['circuitId'] for e in calendar if e['season'] == 2026}
    for cid, c in cids.items():
        if bool(c.get('onCalendar2026')) != (cid in c26): err(f"circuit {cid}: onCalendar2026 inconsistent with calendar")
    used = {e['circuitId'] for e in calendar}
    for cid, c in cids.items():
        if c.get('f1Status') != 'historic' and cid not in used: err(f"circuit {cid}: marked used 2018-2026 but absent from calendar")

n_c = len(circuits or []); n_e = len(calendar or [])
print(f"circuits: {n_c}  calendar events: {n_e}  teams: {len((cd or {}).get('teams', []))}  drivers: {len((cd or {}).get('drivers', []))}")
for m in warnings: print('warning:', m)
for m in errors: print('ERROR:', m)
print(f"{len(errors)} errors, {len(warnings)} warnings")
sys.exit(1 if errors else 0)
