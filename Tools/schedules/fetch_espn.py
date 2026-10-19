#!/usr/bin/env python3
"""Fetches the games of ESPN leagues into SPEC.md season files (Tools/schedules/sched3-espn/<leagueSlug>/<season>.json).

  python3 Tools/schedules/fetch_espn.py --leagues soccer/esp.2,soccer/ita.2 [--first 2006] [--last 2026] [--today 2026-10-19]
  python3 Tools/schedules/fetch_espn.py --leagues-file group.json

Only (league, season) pairs with no usable file on disk are fetched. A calendar year comes back in one request (limit 1000); when a
year is cut off (1000 events) that year is fetched one day at a time. Files are written only when ESPN's feed looks complete.
"""
import argparse, datetime, json, os, sys, threading, time, urllib.error, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import espn_lib as L

BASE = "https://site.api.espn.com/apis/site/v2/sports/"
LOCK = threading.Semaphore(6)
GROUPS = {"football/college-football": ["80", "81"], "basketball/mens-college-basketball": ["50"], "basketball/womens-college-basketball": ["50"]}


def get(url, tries=5):
    for attempt in range(tries):
        try:
            with LOCK:
                req = urllib.request.Request(url, headers={"User-Agent": "WitnessScheduleResearch/1.0 (data gathering for a fan app)"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code in (400, 404):
                return None
            if e.code not in (429, 500, 502, 503, 504):
                return None
        except Exception:
            pass
        time.sleep(1.5 * 2 ** attempt)
    return None


def events_for(league, dates, group=None):
    q = {"dates": dates, "limit": "1000" if len(dates) == 4 else "500"}
    if group:
        q["groups"] = group
    d = get(f"{BASE}{league}/scoreboard?{urllib.parse.urlencode(q)}")
    return (d or {}).get("events", []) if d else []


def year_events(league, year):
    groups = GROUPS.get(league, [None])
    out = {}
    for g in groups:
        evs = events_for(league, str(year), g)
        if len(evs) >= 900:      # cut off: take the year one day at a time
            day = datetime.date(year, 1, 1)
            days = []
            while day.year == year:
                days.append(day.strftime("%Y%m%d")); day += datetime.timedelta(days=1)
            with ThreadPoolExecutor(6) as pool:
                for chunk in pool.map(lambda ds: events_for(league, ds, g), days):
                    for e in chunk:
                        out[e["id"]] = e
        else:
            for e in evs:
                out[e["id"]] = e
    return list(out.values())


STATUS = {"STATUS_POSTPONED": "P", "STATUS_CANCELED": "C", "STATUS_CANCELLED": "C"}


def status_of(e):
    t = (e.get("status") or {}).get("type") or {}
    if t.get("name") in STATUS:
        return STATUS[t["name"]]
    if t.get("state") == "post" and t.get("completed"):
        return "F"
    if t.get("state") == "pre":
        return "S"
    return "O"


def score(c):
    try:
        return int(float(c.get("score")))
    except (TypeError, ValueError):
        return None


def build(league, season, events, today, codes, catalog):
    teams, venues, seen_venues, rows = {}, {}, {}, []
    for e in events:
        comp = (e.get("competitions") or [None])[0]
        if not comp:
            continue
        cs = {c.get("homeAway"): c for c in comp.get("competitors", [])}
        if "home" not in cs or "away" not in cs:
            continue
        h, a = cs["home"], cs["away"]
        hid, aid = str(h["team"]["id"]), str(a["team"]["id"])
        if hid == aid:
            continue
        teams[hid] = h["team"].get("abbreviation") or h["team"].get("shortDisplayName") or hid
        teams[aid] = a["team"].get("abbreviation") or a["team"].get("shortDisplayName") or aid
        v = comp.get("venue") or {}
        vid = str(v["id"]) if v.get("id") is not None else None
        if vid:
            addr = v.get("address") or {}
            venues[vid] = [v.get("fullName", ""), addr.get("city", ""), addr.get("state", ""), codes.get((addr.get("country") or "").lower(), "")]
            seen_venues.setdefault(vid, 0)
            seen_venues[vid] += 1
        note = []
        for n in (comp.get("notes") or e.get("notes") or []):
            if n.get("headline"):
                note.append(n["headline"]); break
        if comp.get("neutralSite"):
            note.append("Neutral site")
        start = e["date"] if len(e["date"]) == 17 else e["date"][:16] + "Z"
        st = status_of(e)
        hs, as_ = (score(h), score(a)) if st == "F" else (None, None)
        rows.append([str(e["id"]), start, hid, aid, hs, as_, vid, st, " · ".join(note)])
    rows.sort(key=lambda r: r[1])
    return {"league": league, "season": season, "source": "espn", "fetched": today, "teams": teams, "venues": venues, "games": rows}, seen_venues


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--leagues", default="")
    ap.add_argument("--leagues-file", default="")
    ap.add_argument("--first", type=int, default=L.FIRST)
    ap.add_argument("--last", type=int, default=L.LAST)
    ap.add_argument("--today", default=datetime.date.today().isoformat())
    ap.add_argument("--out", default=os.path.join(L.SCHEDULES, L.OUT_SCOPE))
    args = ap.parse_args()
    leagues = [x for x in args.leagues.split(",") if x]
    if args.leagues_file:
        leagues += json.load(open(args.leagues_file))
    have, codes, catalog = L.on_disk(), L.country_codes(), L.CatalogVenues()
    report, venues_seen, unresolved = [], [], []
    for league in leagues:
        need = L.missing_seasons(league, have, args.first, args.last)
        if not need:
            continue
        years = sorted({y for s in need for y in (s, s + 1) if args.first <= y <= args.last})
        by_season = {}
        for y in years:
            for e in year_events(league, y):
                s = (e.get("season") or {}).get("year") or int(e["date"][:4])
                by_season.setdefault(s, {})[e["id"]] = e
        wrote = 0
        for s in need:
            events = list(by_season.get(s, {}).values())
            if len(events) < 8:
                continue
            data, seen = build(league, s, events, args.today, codes, catalog)
            prior = have.get(L.slug(league), {}).get(s)
            if prior and prior[0] and len(data["games"]) < 0.8 * prior[0]:
                report.append(f"{league} {s}: ESPN has {len(data['games'])}, existing file about {prior[0]}: kept the existing one")
                continue
            d = os.path.join(args.out, L.slug(league)); os.makedirs(d, exist_ok=True)
            with open(os.path.join(d, f"{s}.json"), "w") as f:
                json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
            wrote += 1
            for vid, n in seen.items():
                name, city, region, cc = data["venues"][vid]
                m = catalog.match(name, city, cc)
                key = (league, vid)
                if m:
                    venues_seen.append({"league": league, "sourceVenueId": vid, "name": name, "city": city, "region": region,
                                        "countryCode": cc, "catalogVenueId": m["id"], "latitude": m["latitude"], "longitude": m["longitude"],
                                        "firstSeason": s, "lastSeason": s, "games": n})
                else:
                    unresolved.append({"league": league, "sourceVenueId": vid, "name": name, "city": city, "region": region, "countryCode": cc, "season": s, "games": n})
        report.append(f"{league}: needed {len(need)} seasons, wrote {wrote}" + ("" if wrote else " (ESPN has no usable feed)"))
        print(report[-1], flush=True)
    os.makedirs(args.out, exist_ok=True)
    # Merge with what earlier runs left, keyed by league and source venue id.
    def merge(path, rows, key):
        old = json.load(open(path)) if os.path.exists(path) else []
        idx = {key(r): r for r in old}
        for r in rows:
            idx[key(r)] = r
        json.dump(list(idx.values()), open(path, "w"), ensure_ascii=False, indent=0)
    merge(os.path.join(args.out, "venues-seen.json"), venues_seen, lambda r: (r["league"], r["sourceVenueId"]))
    merge(os.path.join(args.out, "unresolved-venues.json"), unresolved, lambda r: (r["league"], r["sourceVenueId"]))
    with open(os.path.join(args.out, "FETCH-LOG.txt"), "a") as f:
        f.write("\n".join(report) + "\n")


if __name__ == "__main__":
    main()
