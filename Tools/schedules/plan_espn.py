#!/usr/bin/env python3
"""Plans the ESPN fetch: which catalog leagues still miss seasons, split into groups the CI matrix runs in parallel.

  python3 Tools/schedules/plan_espn.py            # prints the matrix JSON: [{"name": "soccer-1", "leagues": [...]}, ...]
Baseball and hockey are left to their own agents (sched2-baseball, sched2-hockey).
"""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import espn_lib as L

SKIP_SPORTS = ("baseball/", "hockey/")
CHUNK = {"soccer": 12, "basketball": 10, "football": 6, "handball": 8}


def main():
    have = L.on_disk()
    todo = {}
    for league, n in sorted(L.catalog_leagues().items()):
        if league.startswith(SKIP_SPORTS):
            continue
        miss = L.missing_seasons(league, have)
        if miss:
            todo[league] = len(miss)
    groups, by_sport = [], {}
    for league in todo:
        by_sport.setdefault(league.split("/")[0], []).append(league)
    for sport, leagues in by_sport.items():
        size = CHUNK.get(sport, 8)
        for i in range(0, len(leagues), size):
            groups.append({"name": f"{sport}-{i // size + 1}", "leagues": leagues[i:i + size]})
    print(json.dumps(groups))
    print(f"{len(todo)} leagues with missing seasons, {sum(todo.values())} league-seasons, {len(groups)} groups", file=sys.stderr)


if __name__ == "__main__":
    main()
