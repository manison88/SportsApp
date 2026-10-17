#!/usr/bin/env python3
"""Subtle big-game treatment: the photo stays clean. A small heritage pin and the event name sit above the
headline, and the event's colors appear only as a short ribbon rule. Reuses the heritage badge drawing."""
import os, json, importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("heritage", os.path.join(HERE, "..", "heritage", "build.py"))
H = importlib.util.module_from_spec(spec); spec.loader.exec_module(H)
H.OUT = os.path.join(HERE, "features", "badges")
os.makedirs(H.OUT, exist_ok=True)

CSS = H.MEM_CSS + """
  .head { gap: 10px !important; }
  .mark { display: flex; align-items: center; gap: 10px; }
  .mark .hx-badge { filter: drop-shadow(0 3px 6px rgba(0,0,0,.6)); }
  .mark .name { font: 800 14px/1.1 var(--b-cond); letter-spacing: 1.8px; text-transform: uppercase; }
  .mark .sub { font: 600 12px/1.2 var(--b-cond); letter-spacing: 1.6px; text-transform: uppercase; color: rgba(255,255,255,.7); margin-top: 3px; }
  .ribbon { height: 3px; width: 64px; border-radius: 2px; margin-top: 2px; }
"""

def ribbon(t):
    a, b = t.get("accent", t["field"]), t.get("accent2", t.get("accent", t["field"]))
    return f'<div class="ribbon" style="background:linear-gradient(90deg,{t["field"]} 0 34%,{a} 34% 67%,{b} 67%)"></div>'

def mark(key, size=44):
    t = H.T[key]; ink = H.METAL[t["metal"]]["ink"]
    name = t.get("chip") or t["name"]
    return (f'<div class="mark">{H.badge(key, "stamp", size)}<div><div class="name" style="color:{ink}">{name}</div>'
            f'<div class="sub">{t.get("sub", "")}</div></div></div>')

def memory(n, key, slug, crop, grade, headline, where, cols, rows, tint="", nophoto=False, top=296, hsize=54):
    t = H.T[key]
    css = CSS + f"\n  body.b {{ --grade: {grade}; }}\n  .head {{ top: {top - 20}px; }}\n  .head .b-display {{ font-size: {hsize}px; }}"
    if nophoto:
        css += f"\n  .f-hero {{ background: radial-gradient(120% 90% at 50% 30%, {t['field']} 0%, #1a1426 70%, #07080a 100%); }}"
    h = H.head(t["name"], css)
    if nophoto:
        h += f'<div class="f-hero">{H.guilloche_bg(t["ink"], cx=196, cy=196, op=.10)}</div>'
        h += f'<div class="pin" style="left:50%;top:110px;transform:translateX(-50%)">{H.badge(key, "stamp", 120)}</div>'
    else:
        h += f'<div class="f-hero"><div class="crop" data-crop="{crop}"></div></div>'
    h += f'<div class="b-nav" style="z-index:7">{H.BACK}{H.SHARE}</div>'
    h += (f'<div class="f-col head">{mark(key)}<div class="b-display">{headline}</div>'
          f'<div class="where">{where}</div>{ribbon(t)}</div>')
    h += f'<div class="f-col body">{H.table(cols, rows)}</div>'
    h += f'<div class="cta"><div class="b-btn">{H.PLAY}Play recap</div></div>'
    H.write(f"v{n}-{slug}.html", h + H.tail())

H.memory = memory
H.memories()   # same six real games, subtle treatment

# Timeline: small stamps in the card corner, no rings, photos untouched.
def timeline():
    css = """
  .feed { position: absolute; top: 112px; left: 20px; right: 20px; display: flex; flex-direction: column; gap: 16px; }
  .card { position: relative; border-radius: 16px; overflow: hidden; height: 214px; box-shadow: inset 0 0 0 1px var(--b-line); }
  .card .crop img { filter: contrast(1.05) saturate(.9) brightness(.85); }
  .card .scrim { position: absolute; inset: 0; background: linear-gradient(180deg, rgba(7,8,10,0) 35%, rgba(7,8,10,.9) 100%); }
  .card .stamp { position: absolute; top: 12px; right: 12px; }
  .card .stamp .hx-badge { filter: drop-shadow(0 3px 6px rgba(0,0,0,.6)); }
  .card .txt { position: absolute; left: 16px; right: 16px; bottom: 14px; }
  .card .ev { font: 800 12px/1 var(--b-cond); letter-spacing: 1.8px; text-transform: uppercase; margin-bottom: 8px; }
  .card .ttl { font: 800 30px/.92 var(--b-cond); text-transform: uppercase; }
  .card .meta { margin-top: 10px; display: flex; align-items: center; justify-content: space-between; }
  .card .date { font: 600 14px/1 var(--b-ui); color: rgba(255,255,255,.82); }
  .b-bug { height: 30px; font-size: 16px; }
"""
    h = H.head("Timeline", css)
    h += '<div class="b-nav"><div class="f-title">Timeline</div><div class="b-icon-btn"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg></div></div>'
    def bug(a, ac, sa, b, bc, sb_):
        return f'<div class="b-bug"><span class="team" style="--c:{ac}">{a}</span><span class="score">{sa}</span><span class="team" style="--c:{bc}">{b}</span><span class="score">{sb_}</span></div>'
    def card(crop, key, title, date, bugh, bg=""):
        ev = ""
        stamp = ""
        if key:
            t = H.T[key]
            stamp = f'<div class="stamp">{H.badge(key, "stamp", 46)}</div>'
            ev = f'<div class="ev" style="color:{H.METAL[t["metal"]]["ink"]}">{t.get("chip") or t["name"]}</div>'
        media = f'<div class="crop" data-crop="{crop}"></div>' if crop else ""
        return (f'<div class="card" style="{bg}">{media}<div class="scrim"></div>{stamp}'
                f'<div class="txt">{ev}<div class="ttl">{title}</div><div class="meta"><span class="date">{date}</span>{bugh}</div></div></div>')
    sb = H.T["sb"]
    h += '<div class="feed">'
    h += card("wrigley-night.jpg 0 640 860 1024", "ws", "Down 3–1.<br>Still alive.", "Oct 30, 2016", bug("CLE", "#e31937", 2, "CHC", "#2f6bff", 3))
    h += card("wrigley-bleachers.jpg 200 150 900 500", None, "Walk-off<br>in the ninth.", "Aug 18, 2024", bug("MIL", "#c8960f", 4, "CHC", "#2f6bff", 5))
    h += card(None, "sb", "Philly<br>runs away.", "Feb 9, 2025", bug("PHI", "#004c54", 40, "KC", "#e31837", 22),
              bg=f"background:radial-gradient(120% 120% at 80% 0%, {sb['field']} 0%, #1a1426 70%, #0e0814 100%)")
    h += "</div>" + H.tabs("Timeline")
    H.write("v8-timeline.html", h + H.tail())

timeline()
H.v9()  # Passport stamps are already pin-sized
json.dump({"title": "Big games · subtle", "summary": "Clean photo. A small pin and the event name above the headline; event colors as a short ribbon."},
          open(os.path.join(H.OUT, "feature.json"), "w"))
print(sorted(os.listdir(H.OUT)))
