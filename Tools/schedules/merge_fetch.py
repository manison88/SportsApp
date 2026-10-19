#!/usr/bin/env python3
"""Merges the per-group outputs of the ESPN fetch (downloaded CI artifacts) into Tools/schedules/sched3-espn/.
  python3 Tools/schedules/merge_fetch.py <dir holding one folder per group>"""
import json, os, shutil, sys

root = sys.argv[1]
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sched3-espn")
os.makedirs(out, exist_ok=True)
seen, unresolved, log = {}, {}, []
for group in sorted(os.listdir(root)):
    g = os.path.join(root, group)
    for name in os.listdir(g):
        src = os.path.join(g, name)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(out, name), dirs_exist_ok=True)
    for fname, bucket in (("venues-seen.json", seen), ("unresolved-venues.json", unresolved)):
        p = os.path.join(g, fname)
        if os.path.exists(p):
            for r in json.load(open(p)):
                bucket[(r["league"], r["sourceVenueId"])] = r
    p = os.path.join(g, "FETCH-LOG.txt")
    if os.path.exists(p):
        log += open(p).read().splitlines()
for fname, bucket in (("venues-seen.json", seen), ("unresolved-venues.json", unresolved)):
    json.dump(list(bucket.values()), open(os.path.join(out, fname), "w"), ensure_ascii=False, indent=0)
open(os.path.join(out, "FETCH-LOG.txt"), "w").write("\n".join(sorted(log)) + "\n")
print(f"merged {len(os.listdir(root))} groups: {len(seen)} matched venues, {len(unresolved)} unresolved venues, {len(log)} log lines")
