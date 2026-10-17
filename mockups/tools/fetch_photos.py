#!/usr/bin/env python3
"""Fetch candidate photos from Wikimedia Commons (free licenses only) for the mockups.

  python3 mockups/tools/fetch_photos.py candidates   # download candidates + contact sheets
  python3 mockups/tools/fetch_photos.py keep a b c   # promote chosen candidate ids into mockups/photos/

Credits for kept photos are written to mockups/photos/CREDITS.md (required by CC BY / BY-SA).
"""
import json, re, sys, time, urllib.error, urllib.parse, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAND = ROOT / "photo-candidates"
KEEP = ROOT / "photos"
UA = {"User-Agent": "WitnessMockups/1.0 (design mockups; contact manison88@gmail.com)"}
OK_LICENSES = re.compile(r"^(CC BY(-SA)? [0-9.]+|CC0|Public domain|PD.*)", re.I)

QUERIES = {
    "lambeau": "Lambeau Field",
    "lambeau-snow": "Lambeau Field snow game",
    "wrigley-night": "Wrigley Field night",
    "wrigley": "Wrigley Field scoreboard",
    "wrigley-crowd": "Wrigley Field bleachers",
    "soldier": "Soldier Field Chicago",
    "united-center": "United Center Chicago interior",
    "fenway": "Fenway Park night",
    "camp-nou": "Camp Nou stadium interior",
    "bernabeu": "Santiago Bernabeu stadium interior",
    "dortmund": "Signal Iduna Park Südtribüne",
    "cota": "Circuit of the Americas Formula 1",
    "stadium-lights": "stadium floodlights night",
    "baseball-night": "baseball stadium night lights",
    "football-snow": "American football snow game",
    "hockey": "ice hockey arena game",
    "basketball": "basketball arena game interior",
    "fireworks": "stadium fireworks",
    "chicago-skyline": "Chicago skyline night",
    "madrid": "Madrid Gran Via night",
    "barcelona": "Barcelona street evening",
    "green-bay-tailgate": "Lambeau Field tailgating",
    "ticket": "baseball ticket stub",
    "scorecard": "baseball scorecard",
}


def get(url, timeout=60):
    """GET with polite pacing and backoff on 429."""
    for attempt in range(6):
        time.sleep(1.2)
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            time.sleep(15 * (attempt + 1))
    raise RuntimeError("rate limited: " + url)


def api(params):
    return json.loads(get("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)))


def search(q, n=8):
    d = api({"action": "query", "format": "json", "generator": "search", "gsrnamespace": 6,
             "gsrsearch": f"{q} filetype:bitmap", "gsrlimit": 30, "prop": "imageinfo",
             "iiprop": "url|size|extmetadata", "iiurlwidth": 1280})
    out = []
    for p in sorted(d.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 0)):
        ii = p["imageinfo"][0]
        m = ii.get("extmetadata", {})
        lic = m.get("LicenseShortName", {}).get("value", "")
        if not OK_LICENSES.match(lic) or ii["width"] < 1200:
            continue
        artist = re.sub("<[^>]+>", "", m.get("Artist", {}).get("value", "Unknown")).strip()
        out.append({"title": p["title"], "thumb": ii["thumburl"], "page": ii["descriptionurl"],
                    "license": lic, "artist": artist, "w": ii["width"], "h": ii["height"]})
        if len(out) >= n:
            break
    return out


def candidates():
    CAND.mkdir(exist_ok=True)
    idx_path = CAND / "index.json"
    index = json.loads(idx_path.read_text()) if idx_path.exists() else {}
    for key, q in QUERIES.items():
        if any(k.startswith(key + "-") and k[len(key) + 1:].isdigit() for k in index):
            continue
        try:
            res = search(q)
        except Exception as e:
            print("search failed", key, e); continue
        for i, r in enumerate(res):
            cid = f"{key}-{i}"
            dest = CAND / f"{cid}.jpg"
            if not dest.exists():
                try:
                    dest.write_bytes(get(r["thumb"]))
                except Exception as e:
                    print("download failed", cid, e); continue
            index[cid] = r
        idx_path.write_text(json.dumps(index, indent=1))
        print(key, len(res), flush=True)


def keep(ids):
    KEEP.mkdir(exist_ok=True)
    index = json.loads((CAND / "index.json").read_text())
    credits = json.loads((KEEP / "credits.json").read_text()) if (KEEP / "credits.json").exists() else {}
    for cid in ids:
        src, name = (cid.split("=") + [None])[:2]
        name = name or src
        (KEEP / f"{name}.jpg").write_bytes((CAND / f"{src}.jpg").read_bytes())
        credits[name] = index[src]
    (KEEP / "credits.json").write_text(json.dumps(credits, indent=1))
    lines = ["# Photo credits", "", "Photos from Wikimedia Commons, used under their stated free licenses.", ""]
    for name, r in sorted(credits.items()):
        lines.append(f"- `{name}.jpg`: [{r['title'].removeprefix('File:')}]({r['page']}) by {r['artist']}, {r['license']}")
    (KEEP / "CREDITS.md").write_text("\n".join(lines) + "\n")
    print("kept", len(ids))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "candidates"
    candidates() if cmd == "candidates" else keep(sys.argv[2:])
