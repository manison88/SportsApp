#!/usr/bin/env python3
"""Uploads dist/packs through the Worker's /packs-admin endpoint: new pack files first, manifest.json last, so the app never
sees a manifest that points at a pack that is not there yet. Needs only the Worker's address and its dashboard password.

  PACKS_BASE_URL=https://witness-analytics.<you>.workers.dev PACKS_PASSWORD=... python3 Tools/packs/publish_worker.py [--dir dist/packs]

Pack files are named by content hash, so they are immutable (cached for a year); only manifest.json is short-lived.
"""
import argparse, base64, json, os, sys, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "dist", "packs"))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    base = os.environ.get("PACKS_BASE_URL", "").rstrip("/")
    password = os.environ.get("PACKS_PASSWORD", "")
    if not args.dry_run and not (base and password):
        sys.exit("set PACKS_BASE_URL and PACKS_PASSWORD")
    auth = "Basic " + base64.b64encode(f"admin:{password}".encode()).decode()

    def call(method, path, data=None, retries=4):
        for attempt in range(retries):
            req = urllib.request.Request(f"{base}/packs-admin/{path}", data=data, method=method,
                                         headers={"authorization": auth, "content-type": "application/json", "user-agent": "witness-pack-publisher/1.0"})
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    return r.read()
            except urllib.error.HTTPError as e:
                if e.code < 500 and e.code != 429:
                    raise
            except OSError:
                pass
            import time; time.sleep(2 ** attempt)
        raise RuntimeError(f"{method} {path} kept failing")

    envelope = json.load(open(os.path.join(args.dir, "manifest.json")))
    packs = json.loads(envelope["body"])["packs"]
    existing = set() if args.dry_run else set(json.loads(call("GET", "list")))
    new = [p for p in packs if p["path"] not in existing]
    print(f"{len(packs)} packs in the manifest, {len(new)} to upload ({sum(p['bytes'] for p in new) / 1e6:.1f} MB)")
    if args.dry_run:
        return

    def put(p):
        call("PUT", p["path"], open(os.path.join(args.dir, p["path"]), "rb").read())
        return p["path"]

    with ThreadPoolExecutor(6) as pool:
        for i, _ in enumerate(pool.map(put, new), 1):
            if i % 200 == 0:
                print(f"  {i}/{len(new)}")
    call("PUT", "manifest.json", open(os.path.join(args.dir, "manifest.json"), "rb").read())
    keep = {p["path"] for p in packs} | {"manifest.json"}
    stale = [k for k in existing if k not in keep]
    for k in stale:
        call("DELETE", k)
    print(f"uploaded {len(new)} packs and the manifest; removed {len(stale)} old packs")

if __name__ == "__main__":
    main()
