#!/usr/bin/env python3
"""Applies research agents' correction files: arrays of {file, id, field, old, new, source}.

  python3 Tools/packs/apply_fixes.py Tools/teams/us-pro-history-fixes.json [--dry-run]

A fix is applied only when the record's current value equals `old`; anything else is reported and left alone. Each target file is
rewritten in the formatting it already has (so diffs stay small); a file that does not round-trip byte for byte is skipped.
"""
import argparse, json, os, sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STYLES = [dict(ensure_ascii=False, indent=1), dict(ensure_ascii=True, indent=1), dict(ensure_ascii=False, indent=2),
          dict(ensure_ascii=True, indent=2), dict(ensure_ascii=False, separators=(",", ":")), dict(ensure_ascii=True, separators=(",", ":")),
          dict(ensure_ascii=False), dict(ensure_ascii=True)]

def detect_style(text, data):
    for style in STYLES:
        for tail in ("", "\n"):
            if json.dumps(data, **style) + tail == text:
                return style, tail
    return None, None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fixes")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    fixes = json.load(open(args.fixes))
    by_file = {}
    for fx in fixes:
        by_file.setdefault(fx["file"], []).append(fx)
    applied = skipped = 0
    for rel, items in by_file.items():
        path = os.path.join(REPO, rel)
        if not os.path.exists(path):
            print(f"missing file {rel}: {len(items)} fixes skipped"); skipped += len(items); continue
        text = open(path).read()
        data = json.loads(text)
        style, tail = detect_style(text, data)
        if style is None:
            print(f"{rel}: formatting does not round-trip, {len(items)} fixes skipped"); skipped += len(items); continue
        records = data if isinstance(data, list) else None
        if records is None:
            print(f"{rel}: not an array, skipped"); skipped += len(items); continue
        index = {}
        for r in records:
            for k in ("id", "key"):
                if r.get(k) is not None:
                    index.setdefault(r[k], r)
        for fx in items:
            rec = index.get(fx["id"])
            if rec is None:
                print(f"  {rel} {fx['id']}: no such record"); skipped += 1; continue
            if fx["field"] == "__delete__":
                # an earlier fix in the same file may already have changed the record, so the id alone decides
                records.remove(rec)
                index.pop(fx["id"], None)
                applied += 1
                continue
            # "passport.venueIds" reaches into nested objects
            parts = fx["field"].split(".")
            holder = rec
            for part in parts[:-1]:
                holder = holder.get(part) if isinstance(holder, dict) else None
            if not isinstance(holder, dict) or holder.get(parts[-1]) != fx["old"]:
                print(f"  {rel} {fx['id']}.{fx['field']}: current value differs from `old`, left alone"); skipped += 1; continue
            holder[parts[-1]] = fx["new"]
            applied += 1
        if not args.dry_run:
            with open(path, "w") as f:
                f.write(json.dumps(data, **style) + tail)
    print(f"{applied} applied, {skipped} skipped{' (dry run)' if args.dry_run else ''}")

if __name__ == "__main__":
    main()
