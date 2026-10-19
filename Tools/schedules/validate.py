#!/usr/bin/env python3
"""Validates Tools/schedules/<scope>/: season files, venues-seen.json and missing-venues.json references."""
import json, os, re, sys
from datetime import datetime

ROOT = os.path.dirname(os.path.abspath(__file__))
STATUSES = {"F", "S", "P", "C", "O"}
FIRST, LAST = 2006, 2026

def main(scope):
    base = os.path.join(ROOT, scope)
    errors, warnings = [], []
    if not os.path.isdir(base):
        print(f"no such scope: {scope}"); return 1
    leagues = {}
    games_total = 0
    for slug in sorted(os.listdir(base)):
        d = os.path.join(base, slug)
        if not os.path.isdir(d):
            continue
        seasons = []
        for name in sorted(os.listdir(d)):
            m = re.fullmatch(r"(\d{4})(?:-[\w]+)?\.json", name)
            if not m:
                errors.append(f"{slug}/{name}: file name must be <season>.json"); continue
            season = int(m.group(1))
            path = os.path.join(d, name)
            if os.path.getsize(path) > 5_000_000:
                warnings.append(f"{slug}/{name}: over 5 MB")
            try:
                data = json.load(open(path))
            except Exception as e:
                errors.append(f"{slug}/{name}: invalid JSON ({e})"); continue
            if data.get("league", "").replace("/", "-") != slug:
                errors.append(f"{slug}/{name}: league {data.get('league')!r} does not match folder")
            if data.get("season") != season:
                errors.append(f"{slug}/{name}: season field {data.get('season')!r} != file name")
            teams, venues = data.get("teams", {}), data.get("venues", {})
            seen, last_start = set(), ""
            for i, g in enumerate(data.get("games", [])):
                where = f"{slug}/{name} game[{i}]"
                if not isinstance(g, list) or len(g) != 9:
                    errors.append(f"{where}: must be a 9-item array"); continue
                eid, start, home, away, hs, as_, ven, status, note = g
                if eid in seen: errors.append(f"{where}: duplicate eventId {eid}")
                seen.add(eid)
                try:
                    datetime.strptime(start, "%Y-%m-%dT%H:%MZ")
                except Exception:
                    errors.append(f"{where}: bad startUTC {start!r}")
                if start < last_start: errors.append(f"{where}: not sorted by start time")
                last_start = start
                if home not in teams or away not in teams: errors.append(f"{where}: team id missing from teams table")
                if home == away: errors.append(f"{where}: home equals away")
                if ven is not None and ven not in venues: errors.append(f"{where}: venue id {ven!r} missing from venues table")
                if status not in STATUSES: errors.append(f"{where}: bad status {status!r}")
                for s in (hs, as_):
                    if s is not None and not isinstance(s, int): errors.append(f"{where}: score must be int or null")
                if status == "F" and (hs is None or as_ is None): warnings.append(f"{where}: final without a score")
                if not isinstance(note, str): errors.append(f"{where}: note must be a string")
                games_total += 1
            seasons.append(season)
        leagues[slug] = seasons
        missing = [s for s in range(FIRST, LAST + 1) if s not in seasons]
        if missing:
            warnings.append(f"{slug}: seasons missing {missing[0]}..{missing[-1]} ({len(missing)})" if len(missing) > 3 else f"{slug}: seasons missing {missing}")
    vs = os.path.join(base, "venues-seen.json")
    if not os.path.exists(vs):
        errors.append("venues-seen.json is missing")
    else:
        try:
            for i, v in enumerate(json.load(open(vs))):
                for k in ("league", "sourceVenueId", "name", "latitude", "longitude"):
                    if v.get(k) in (None, ""): errors.append(f"venues-seen[{i}] {v.get('name')}: missing {k}")
        except Exception as e:
            errors.append(f"venues-seen.json invalid ({e})")
    if not os.path.exists(os.path.join(base, "NOTES.md")):
        warnings.append("NOTES.md is missing")
    for w in warnings[:60]: print("  warn ", w)
    for e in errors[:60]: print("  ERROR", e)
    print(f"{len(leagues)} leagues, {sum(len(s) for s in leagues.values())} season files, {games_total} games, "
          f"{len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1]) if len(sys.argv) > 1 else print("usage: validate.py <scope>") or 1)
