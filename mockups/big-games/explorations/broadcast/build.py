#!/usr/bin/env python3
"""Broadcast lockup: big-game badge system + screens.
Generates features/badges/v1..v9. Our own type, color fields and slashes only. No marks, no trophies."""
import os, json

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "features", "badges")
UP = "../../../../../"  # badges -> features -> broadcast -> explorations -> big-games -> mockups

SILVER = "linear-gradient(90deg,#7f8990 0%,#f1f4f6 42%,#a3acb2 58%,#e3e7ea 100%)"
GOLD = "linear-gradient(90deg,#9c7412 0%,#ffe9a6 42%,#c0951f 58%,#f4d47c 100%)"

# ---------------------------------------------------------------- themes (data only)
THEMES = {
    "ws16": dict(field="#0C2340", ink="#F4EFE3", num="#F4EFE3", metal=GOLD,
                 bars=[("#C8102E", 13), ("#F4EFE3", 4)],
                 name=["World", "Series"], short="World Series", detail="Game 5 · Chicago", numeral="’16"),
    "scf15": dict(field="#0B0D10", ink="#FFFFFF", num="metal", metal=SILVER,
                  bars=[(SILVER, 13), ("#FFFFFF", 4)],
                  name=["Stanley Cup", "Final"], short="Cup Final", detail="Game 6 · Chicago", numeral="’15"),
    "ucl99": dict(field="#081548", ink="#FFFFFF", num="#FFFFFF", metal=SILVER,
                  bars=[(SILVER, 13), ("#5E6FA8", 4)],
                  name=["Champions", "League"], short="UCL Final", detail="Final · Barcelona", numeral="’99"),
    "wc94": dict(field="#002868", ink="#FFFFFF", num="#FFFFFF", metal=GOLD,
                 bars=[("#C8102E", 13), ("#FFFFFF", 4)],
                 name=["World", "Cup"], short="World Cup", detail="Opener · Chicago", numeral="’94"),
    "sb59": dict(field="#4B2A7B", ink="#FFFFFF", num="#F2B705", metal=GOLD,
                 bars=[("#F2B705", 13), ("#0B7A3E", 6)],
                 name=["Super", "Bowl"], short="Super Bowl", detail="New Orleans · 2025", numeral="LIX"),
}

def rivalry(home, away, name, short, detail, numeral):
    """Derive a rivalry theme from two clubs: field = home primary, slash = home 2nd, away 1st, away 2nd."""
    def lum(h):
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
        f = lambda c: c / 12.92 if c <= .03928 else ((c + .055) / 1.055) ** 2.4
        return .2126 * f(r) + .7152 * f(g) + .0722 * f(b)
    ink = "#FFFFFF" if lum(home[0]) < .18 else "#0B0D10"
    return dict(field=home[0], ink=ink, num=ink, metal=SILVER,
                bars=[(home[1], 9), (away[0], 5), (away[1], 9)],
                name=name, short=short, detail=detail, numeral=numeral)

THEMES["clasico10"] = rivalry(("#004D98", "#A50044"), ("#FFFFFF", "#FEBE10"),
                              ["El", "Clásico"], "El Clásico", "FCB v RMA", "’10")

def generic(tier, team_color, name, short, detail, numeral):
    """No theme on file: graphite field, home-team slash, metal by tier (title=gold, playoff/tournament=silver)."""
    return dict(field="#1A1D24", ink="#FFFFFF", num="#FFFFFF", metal=GOLD if tier == "title" else SILVER,
                bars=[(team_color, 13), ("rgba(255,255,255,.55)", 4)],
                name=name, short=short, detail=detail, numeral=numeral)

THEMES["nlcs16"] = generic("playoff", "#2f6bff", ["NLCS"], "NLCS", "Game 6 · Chicago", "’16")

ORDER = ["ws16", "scf15", "ucl99", "wc94", "sb59", "clasico10"]

def vars_(t):
    return f"--field:{t['field']};--ink:{t['ink']};--num:{t['num'] if t['num'] != 'metal' else t['ink']};--metal:{t['metal']}"

def bars(t, x0, scale=1.0, gap=5):
    out, x = "", x0
    for c, w in t["bars"]:
        w2 = max(2, round(w * scale))
        out += f'<i class="bar" style="left:{x}px;width:{w2}px;background:{c}"></i>'
        x += w2 + round(gap * scale)
    return out

def num(t, fit):
    metal = ' data-metal' if t["num"] == "metal" else ''
    return f'<div class="num"{metal} data-fit="{fit}">{t["numeral"]}</div>'

def hero(key, h=176, extra=""):
    t = THEMES[key]
    name = "".join(f'<div class="name" data-fit="20">{l}</div>' for l in t["name"])
    bw = sum(w for _, w in t["bars"]) + 5 * (len(t["bars"]) - 1)
    return (f'<div class="lk hero" style="{vars_(t)};--h:{h}px;{extra}">{bars(t, 168)}{num(t, 60)}'
            f'<div class="side" style="left:{max(216, 168 + bw + 28)}px"><div>{name}</div><div><div class="rule"></div>'
            f'<div class="detail" data-fit="12">{t["detail"]}</div></div></div></div>')

def stamp(key, extra=""):
    t = THEMES[key]
    return (f'<div class="lk stamp" style="{vars_(t)};{extra}">{bars(t, 80, .55, 4)}{num(t, 24)}'
            f'<div class="rule"></div><div class="name" data-fit="12">{t["short"]}</div></div>')

def chip(key, extra=""):
    t = THEMES[key]
    return (f'<span class="lk chip" style="{vars_(t)};{extra}">{num(t, 14).replace("<div", "<span").replace("</div>", "</span>")}'
            f'<span class="sl">{bars(t, 7, .45, 3)}</span><span class="name">{t["short"]}</span></span>')

# ---------------------------------------------------------------- page shell
FIT_JS = """<script>
(function () {
  function fit() {
    document.querySelectorAll('[data-fit]').forEach(el => {
      const min = +el.dataset.fit; let s = parseFloat(getComputedStyle(el).fontSize);
      while (el.scrollWidth > el.clientWidth + 0.5 && s > min) { s -= 0.5; el.style.fontSize = s + 'px'; }
    });
  }
  document.fonts.ready.then(fit);
})();
</script>"""

CROP_JS = """<script>
(function () {
  const N = { 'wrigley-night.jpg': [1920, 2560], 'united-center-court.jpg': [1280, 853], 'camp-nou-aerial.jpg': [1280, 960],
              'soldier-soccer.jpg': [1280, 1707], 'lambeau-concourse.jpg': [1920, 1288] };
  document.querySelectorAll('[data-crop]').forEach(b => {
    const [src, sx, sy, sw, sh] = b.dataset.crop.split(/\\s+/).map((v, i) => i ? +v : v);
    const [nw, nh] = N[src], bw = b.clientWidth, bh = b.clientHeight, s = Math.max(bw / sw, bh / sh);
    const i = document.createElement('img');
    i.src = '""" + UP + """photos/' + src;
    i.style.cssText = `position:absolute;max-width:none;width:${nw * s}px;height:${nh * s}px;left:${bw / 2 - (sx + sw / 2) * s}px;top:${bh / 2 - (sy + sh / 2) * s}px`;
    b.prepend(i);
  });
})();
</script>"""

def head(title, css, body_attrs=""):
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="{UP}kit/kit.css">
<link rel="stylesheet" href="{UP}round2/system/broadcast.css">
<link rel="stylesheet" href="{UP}final/system/final.css">
<link rel="stylesheet" href="../../system/lockup.css">
<style>
  body.b {{ --b-text-3: rgba(255,255,255,.62); }}
  .crop {{ position: absolute; inset: 0; overflow: hidden; }}
{css}
</style></head>
<body class="phone b"{body_attrs}>
"""

def tail():
    return f"\n{CROP_JS}\n{FIT_JS}\n<script src=\"{UP}kit/kit.js\"></script>\n</body></html>\n"

def write(fn, html):
    with open(os.path.join(OUT, fn), "w") as f:
        f.write(html)

ICON = {
    "back": '<svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg>',
    "share": '<svg viewBox="0 0 24 24"><path d="M12 15V3M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>',
    "camera": '<svg viewBox="0 0 24 24"><path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/></svg>',
    "search": '<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/></svg>',
    "play": '<svg viewBox="0 0 24 24" style="fill:currentColor;stroke:none"><path d="M7 4.5v15l12.5-7.5z"/></svg>',
}

TABS = """<nav class="b-tabs">
  <span{0}><svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="9" rx="2"/><path d="M4 17h16M4 21h10"/></svg>Timeline</span>
  <span><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3.2 3.4 3.2 14.6 0 18M12 3c-3.2 3.4-3.2 14.6 0 18"/></svg>Map</span>
  <span{1}><svg viewBox="0 0 24 24"><rect x="5" y="3" width="14" height="18" rx="2"/><circle cx="12" cy="11" r="3.5"/><path d="M9 17.5h6"/></svg>Passport</span>
  <span><svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.4-4 4.4-6 8-6s6.6 2 8 6"/></svg>You</span>
</nav>"""

os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- v1 · system sheet (board drawn at 2x, scaled to the phone frame)
LABEL = {"ws16": "World Series 2016 · G5", "scf15": "Stanley Cup Final 2015 · G6", "ucl99": "Champions League Final 1999",
         "wc94": "World Cup 1994 · Opener", "sb59": "Super Bowl LIX", "clasico10": "El Clásico 2010 · derived rivalry",
         "nlcs16": "Fallback · NLCS 2016, no theme on file"}
sheet_css = """
  .board { position: absolute; left: 0; top: 0; width: 786px; height: 1704px; transform: scale(.5); transform-origin: 0 0; padding: 56px 40px 0; }
  .board h1 { font: 800 56px/.9 var(--b-cond); text-transform: uppercase; letter-spacing: -.5px; }
  .board .sizes { display: flex; gap: 0; margin: 18px 0 30px; font: 700 15px/1 var(--b-cond); letter-spacing: 2px; text-transform: uppercase; color: rgba(255,255,255,.7); }
  .board .sizes span { width: 393px; }
  .board .sizes span + span { width: 136px; }
  .row { display: flex; align-items: flex-start; gap: 40px; margin-bottom: 30px; }
  .row .h { width: 353px; flex: none; }
  .row .s { width: 112px; flex: none; }
  .row .c { display: flex; flex-direction: column; gap: 14px; padding-top: 2px; }
  .row .c p { font: 600 15px/1.25 var(--b-ui); color: rgba(255,255,255,.72); max-width: 180px; }
  .row.fb { padding-top: 26px; box-shadow: inset 0 1px 0 rgba(255,255,255,.14); }
"""
rows = ""
for k in ORDER + ["nlcs16"]:
    rows += (f'<div class="row{" fb" if k == "nlcs16" else ""}"><div class="h">{hero(k)}</div><div class="s">{stamp(k)}</div>'
             f'<div class="c"><div>{chip(k)}</div><p>{LABEL[k]}</p></div></div>\n')
write("v1-badge-system.html", head("Badge system", sheet_css, ' data-chrome="none"') +
      f'<div class="board"><h1>Broadcast lockup</h1><div class="sizes"><span>Hero · 176pt</span><span>Stamp · 72pt</span><span>Chip · 28pt</span></div>{rows}</div>' + tail())

# ---------------------------------------------------------------- v2–v7 · game memory
mem_css = """
  .f-hero { height: 520px; }
  .f-hero .crop img { filter: var(--grade, contrast(1.05) saturate(.9) brightness(.88)); }
  .f-hero::after { background: linear-gradient(180deg, rgba(7,8,10,.55) 0%, rgba(7,8,10,0) 20%, rgba(7,8,10,0) 40%, rgba(7,8,10,.72) 72%, #07080a 100%); z-index: 2; }
  .card { position: absolute; left: 20px; right: 20px; top: 300px; z-index: 6; box-shadow: 0 18px 40px rgba(0,0,0,.45); border-radius: 8px; }
  .head { top: 492px; gap: 8px !important; z-index: 6; }
  .head .b-h1 { font-size: 34px; white-space: nowrap; }
  .head .where { font: 500 15px/1.3 var(--b-ui); color: rgba(255,255,255,.72); }
  .ls { position: absolute; left: 20px; right: 20px; top: 584px; width: 353px; border-collapse: collapse; font-variant-numeric: tabular-nums; }
  .ls th { font: 700 12px/1 var(--b-cond); letter-spacing: 2px; color: rgba(255,255,255,.62); text-align: center; padding-bottom: 8px; }
  .ls td { height: 50px; box-shadow: inset 0 1px 0 var(--b-line); text-align: center; font: 600 19px/1 var(--b-cond); color: rgba(255,255,255,.68); width: 24px; }
  .ls td.tm { text-align: left; width: auto; }
  .ls td.tm div { display: flex; align-items: center; gap: 12px; font: 700 19px/1 var(--b-cond); letter-spacing: .4px; text-transform: uppercase; color: #fff; }
  .ls td.t { width: 52px; text-align: right; font: 800 34px/1 var(--b-cond); color: #fff; }
  .ls tr.lose td.tm div, .ls tr.lose td.t { color: rgba(255,255,255,.6); }
  .ls .f-mono { box-shadow: inset 0 0 0 1px rgba(255,255,255,.16); }
  .cta { position: absolute; left: 20px; right: 20px; bottom: 40px; }
  .cta .b-btn { width: 100%; height: 54px; font-size: 17px; }
  .cta svg { width: 16px; height: 16px; }
  .nophoto { position: absolute; inset: 0; background: var(--field); overflow: hidden; }
  .nophoto i { position: absolute; top: -40px; bottom: -40px; transform: skewX(-14deg); }
  .addph { position: absolute; left: 20px; top: 116px; z-index: 6; height: 36px; padding: 0 14px 0 12px; border-radius: 10px; display: inline-flex; align-items: center; gap: 8px;
    background: rgba(7,8,10,.55); box-shadow: inset 0 0 0 1px rgba(255,255,255,.22); font: 700 15px/1 var(--b-cond); letter-spacing: 1.2px; text-transform: uppercase; }
  .addph svg { width: 17px; height: 17px; stroke: #fff; fill: none; stroke-width: 2; stroke-linejoin: round; }
"""

def table(cols, rows):
    th = "".join(f"<th>{c}</th>" for c in cols)
    out = f'<table class="ls"><tr><th></th>{th}<th style="text-align:right">T</th></tr>'
    for code, color, ink, city, line, total, lose in rows:
        if len(line) > 4: city = ""
        cells = "".join(f"<td>{v}</td>" for v in line)
        out += (f'<tr class="{"lose" if lose else ""}"><td class="tm"><div><span class="f-mono" style="--c:{color};color:{ink}">{code}</span>{city}</div></td>'
                f'{cells}<td class="t">{total}</td></tr>')
    return out + "</table>"

def memory(n, key, title, hero_html, headline, where, tbl, grade=None, right="share"):
    t = THEMES[key]
    g = f' style="--grade:{grade}"' if grade else ""
    html = head(title, mem_css)
    html += f'<div class="f-hero"{g}>{hero_html}</div>\n'
    html += (f'<div class="b-nav" style="z-index:7"><div class="b-icon-btn">{ICON["back"]}</div>'
             f'<div class="b-icon-btn">{ICON[right]}</div></div>\n')
    html += f'<div class="card">{hero(key, 160)}</div>\n'
    html += f'<div class="f-col head"><div class="b-h1" data-fit="26">{headline}</div><div class="where">{where}</div></div>\n'
    html += tbl
    html += f'<div class="cta"><div class="b-btn">{ICON["play"]}Play recap</div></div>'
    write(f"v{n}-{title.lower().replace(' ', '-').replace('á', 'a')}.html", html + tail())

memory(2, "ws16", "World Series", '<div class="crop" data-crop="wrigley-night.jpg 0 370 860 1100"></div>',
       "Down 3–1. Still alive.", "Wrigley Field, Oct 30, 2016",
       table(range(1, 10), [("CLE", "#e31937", "#fff", "Cleveland", [0, 1, 0, 0, 0, 1, 0, 0, 0], 2, True),
                            ("CHC", "#2f6bff", "#fff", "Chicago", [0, 0, 0, 3, 0, 0, 0, 0, "x"], 3, False)]))
memory(3, "scf15", "Stanley Cup Final", '<div class="crop" data-crop="united-center-court.jpg 300 80 680 853"></div>',
       "Clinched on home ice.", "United Center, Jun 15, 2015",
       table([1, 2, 3], [("TB", "#0b3d91", "#fff", "Tampa Bay", [0, 0, 0], 0, True),
                         ("CHI", "#cf0a2c", "#fff", "Chicago", [0, 1, 1], 2, False)]),
       grade="grayscale(.4) contrast(1.1) brightness(.8)")
memory(4, "ucl99", "Champions League Final", '<div class="crop" data-crop="camp-nou-aerial.jpg 200 60 880 900"></div>',
       "Two goals. Injury time.", "Camp Nou, May 26, 1999",
       table(["1H", "2H"], [("BAY", "#dc052d", "#fff", "Bayern", [1, 0], 1, True),
                            ("MUN", "#da291c", "#fff", "Manchester Utd", [0, 2], 2, False)]),
       grade="grayscale(1) contrast(1.15) brightness(.7) sepia(1) hue-rotate(185deg) saturate(2)")
memory(5, "wc94", "World Cup 1994", '<div class="crop" data-crop="soldier-soccer.jpg 0 500 1280 1100"></div>',
       "The world came to Chicago.", "Soldier Field, Jun 17, 1994",
       table(["1H", "2H"], [("BOL", "#00843d", "#fff", "Bolivia", [0, 0], 0, True),
                            ("GER", "#2a2a2a", "#fff", "Germany", [0, 1], 1, False)]))
sb = THEMES["sb59"]
nophoto = (f'<div class="nophoto" style="--field:{sb["field"]}">'
           f'<i style="left:150px;width:120px;background:#F2B705"></i><i style="left:300px;width:46px;background:#0B7A3E"></i>'
           f'<i style="left:372px;width:12px;background:rgba(255,255,255,.5)"></i></div>'
           f'<div class="addph">{ICON["camera"]}Add photos</div>')
memory(6, "sb59", "Super Bowl LIX", nophoto, "Philly runs away.", "Caesars Superdome, Feb 9, 2025",
       table([1, 2, 3, 4], [("PHI", "#004c54", "#fff", "Philadelphia", [7, 17, 10, 6], 40, False),
                            ("KC", "#e31837", "#fff", "Kansas City", [0, 0, 6, 16], 22, True)]))
memory(7, "clasico10", "El Clásico", '<div class="crop" data-crop="camp-nou-aerial.jpg 380 230 600 660"></div>',
       "La Manita.", "Camp Nou, Nov 29, 2010",
       table(["1H", "2H"], [("FCB", "#A50044", "#fff", "Barcelona", [2, 3], 5, False),
                            ("RMA", "#FFFFFF", "#000", "Real Madrid", [0, 0], 0, True)]),
       grade="contrast(1.05) saturate(.85) brightness(.66)")

# ---------------------------------------------------------------- v8 · timeline
tl_css = """
  .card { position: absolute; left: 20px; right: 20px; }
  .card .b-frame { height: 212px; border-radius: 16px 16px 0 0; }
  .card .scrim { position: absolute; inset: 0; background: linear-gradient(180deg, rgba(7,8,10,.35) 0%, rgba(7,8,10,0) 32%, rgba(7,8,10,.5) 62%, rgba(7,8,10,.92) 100%); }
  .card .copy { position: absolute; left: 18px; right: 18px; bottom: 16px; }
  .card .copy .b-display { font-size: 46px; }
  .card .lk.chip { position: absolute; left: 14px; top: 14px; z-index: 2; box-shadow: 0 4px 14px rgba(0,0,0,.35), inset 0 0 0 1px rgba(255,255,255,.14); }
  .card .seam { position: absolute; left: 0; right: 0; bottom: 0; height: 2px; z-index: 2; }
  .stub { position: relative; height: 64px; background: var(--b-panel-2); border-radius: 0 0 16px 16px; display: flex; align-items: center; padding: 0 16px; gap: 18px;
    -webkit-mask: radial-gradient(circle 10px at 0 0, transparent 9.5px, #000 10px) top left / 51% 100% no-repeat, radial-gradient(circle 10px at 100% 0, transparent 9.5px, #000 10px) top right / 51% 100% no-repeat; }
  .stub::before { content: ""; position: absolute; left: 14px; right: 14px; top: 0; border-top: 1.5px dashed rgba(255,255,255,.18); }
  .stub b { font: 700 17px/1 var(--b-cond); letter-spacing: .4px; text-transform: uppercase; white-space: nowrap; }
  .stub .b-bug { margin-left: auto; height: 32px; font-size: 16px; flex: none; }
  .stub .b-bug .team { padding: 0 8px; }
  .stub .b-bug .score { padding: 0 9px; }
  .nophoto { position: absolute; inset: 0; background: #4B2A7B; overflow: hidden; }
  .nophoto i { position: absolute; top: -30px; bottom: -30px; transform: skewX(-14deg); }
  .c1 { top: 112px; } .c2 { top: 404px; } .c3 { top: 696px; }
"""
def bug(a, sa, ca, b, sb_, cb):
    return (f'<div class="b-bug"><span class="team" style="--c:{ca}">{a}</span><span class="score">{sa}</span>'
            f'<span class="team" style="--c:{cb}">{b}</span><span class="score">{sb_}</span></div>')

html = head("Timeline", tl_css)
html += f'<div class="b-nav"><div class="f-title">Timeline</div><div class="b-icon-btn">{ICON["search"]}</div></div>\n'
html += (f'<div class="card c1"><div class="b-frame"><div class="crop" data-crop="wrigley-night.jpg 0 640 860 600"></div><div class="scrim"></div>'
         f'{chip("ws16")}<div class="copy"><div class="b-display">Down 3–1.<br>Still alive.</div></div>'
         f'<div class="seam" style="background:{GOLD}"></div></div>'
         f'<div class="stub"><b>Oct 30, 2016</b><b>Sec 314</b>{bug("CHC", 3, "var(--chc)", "CLE", 2, "var(--cle)")}</div></div>\n')
html += (f'<div class="card c2"><div class="b-frame"><div class="nophoto"><i style="left:240px;width:70px;background:#F2B705"></i>'
         f'<i style="left:322px;width:24px;background:#0B7A3E"></i><i style="left:358px;width:8px;background:rgba(255,255,255,.5)"></i></div>'
         f'<div class="scrim"></div>{chip("sb59")}<div class="copy"><div class="b-display">Philly<br>runs away.</div></div>'
         f'<div class="seam" style="background:{GOLD}"></div></div>'
         f'<div class="stub"><b>Feb 9, 2025</b><b>Superdome</b>{bug("PHI", 40, "#004c54", "KC", 22, "#e31837")}</div></div>\n')
html += (f'<div class="card c3"><div class="b-frame"><div class="crop" data-crop="lambeau-concourse.jpg 1150 250 700 600"></div><div class="scrim"></div>'
         f'</div></div>\n')
html += TABS.format(' class="on"', "")
write("v8-timeline.html", html + tail())

# ---------------------------------------------------------------- v9 · passport
pp_css = """
  .main { top: 112px; gap: 26px; }
  .pills { display: flex; gap: 8px; }
  .pills .b-pill { white-space: nowrap; height: 36px; padding: 0 14px; border-radius: 8px; font-size: 14px; color: rgba(255,255,255,.72); }
  .pills .b-pill.on { background: #fff; color: #000; }
  .count { display: flex; align-items: flex-end; gap: 14px; }
  .count .b-mega { font-size: 120px; letter-spacing: -3px; margin-left: -4px; }
  .count .b-h1 { font-size: 34px; padding-bottom: 4px; }
  .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px 10px; }
  .grid .d { margin-top: 8px; font: 700 13px/1 var(--b-cond); letter-spacing: 1.2px; text-transform: uppercase; color: rgba(255,255,255,.66); font-variant-numeric: tabular-nums; }
  .ghost { height: 72px; border-radius: 10px; box-shadow: inset 0 0 0 1.5px rgba(255,255,255,.16); display: flex; align-items: flex-end; padding: 0 9px 10px; position: relative; overflow: hidden; }
  .ghost i { position: absolute; top: -12px; bottom: 26px; left: 80px; width: 7px; transform: skewX(-14deg); background: rgba(255,255,255,.12); }
  .ghost b { font: 800 12.5px/1 var(--b-cond); letter-spacing: .9px; text-transform: uppercase; color: rgba(255,255,255,.6); white-space: nowrap; }
"""
DATES = {"ws16": "Oct 30, 2016", "scf15": "Jun 15, 2015", "ucl99": "May 26, 1999", "wc94": "Jun 17, 1994",
         "sb59": "Feb 9, 2025", "clasico10": "Nov 29, 2010"}
html = head("Passport · big games", pp_css)
html += f'<div class="b-nav"><div class="f-title">Passport</div><div class="b-icon-btn">{ICON["share"]}</div></div>\n'
html += '<div class="f-col main"><div class="pills"><span class="b-pill">MLB</span><span class="b-pill">NFL</span><span class="b-pill">Soccer</span><span class="b-pill on">Big games</span></div>'
html += '<div class="count"><div class="b-mega">6</div><div class="b-h1">big<br>games</div></div><div class="grid">'
for k in ["wc94", "ucl99", "clasico10", "scf15", "ws16", "sb59"]:
    html += f'<div>{stamp(k)}<div class="d">{DATES[k]}</div></div>'
for g in ["NBA Finals", "All-Star", "Final Four"]:
    html += f'<div><div class="ghost"><i></i><b>{g}</b></div></div>'
html += '</div></div>\n' + TABS.format("", ' class="on"')
write("v9-passport.html", html + tail())

json.dump({"title": "Big games · broadcast lockup",
           "summary": "Field, numeral, slash, name, metal rule. One title card at three sizes, themed only by data."},
          open(os.path.join(OUT, "feature.json"), "w"))
print(sorted(os.listdir(OUT)))
