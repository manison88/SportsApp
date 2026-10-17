#!/usr/bin/env python3
"""Generates the event-theme mockups: one Game memory screen per big event.
Event colors and our own drawn motifs only. No event logos, trophies or marks."""
import os, json
OUT = os.path.join(os.path.dirname(__file__), "features", "event-themes")

SIZES = {"wrigley-night.jpg": (1920, 2560), "united-center-court.jpg": (1280, 853), "camp-nou-aerial.jpg": (1280, 960),
         "soldier-soccer.jpg": (1280, 1707), "lambeau-concourse.jpg": (1920, 1288)}

HEAD = """<html><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="../../../kit/kit.css">
<link rel="stylesheet" href="../../../round2/system/broadcast.css">
<link rel="stylesheet" href="../../../final/system/final.css">
<style>
  body.b {{ --b-text-3: rgba(255,255,255,.6); {vars} }}
  .f-hero {{ height: 470px; }}
  .f-hero .crop {{ position: absolute; inset: 0; overflow: hidden; }}
  .f-hero .crop img {{ filter: {grade}; }}
  .f-hero::after {{ background: linear-gradient(180deg, rgba(7,8,10,.55) 0%, rgba(7,8,10,0) 22%, rgba(7,8,10,0) 42%, rgba(7,8,10,.7) 76%, #07080a 100%); z-index: 2; }}
  .motif {{ position: absolute; inset: 0; z-index: 3; pointer-events: none; }}
  .head {{ top: 300px; z-index: 6; gap: 12px !important; }}
  .head .b-display {{ font-size: 56px; }}
  .head .where {{ font: 500 15px/1.3 var(--b-ui); color: rgba(255,255,255,.78); }}
  .chip {{ display: inline-flex; align-self: flex-start; align-items: center; gap: 8px; height: 30px; padding: 0 12px;
          border-radius: 15px; font: 800 13px/1 var(--b-cond); letter-spacing: 1.6px; text-transform: uppercase; }}
  .chip svg {{ width: 14px; height: 14px; }}
  .body {{ top: 506px; }}
  .ls {{ width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; }}
  .ls th {{ font: 700 12px/1 var(--b-cond); letter-spacing: 2px; color: var(--b-text-3); text-align: center; padding-bottom: 8px; }}
  .ls td {{ height: 48px; box-shadow: inset 0 1px 0 var(--b-line); text-align: center; font: 600 20px/1 var(--b-cond); color: var(--b-text-2); width: 30px; }}
  .ls td.tm {{ text-align: left; width: auto; }}
  .ls td.tm div {{ display: flex; align-items: center; gap: 12px; font: 700 20px/1 var(--b-cond); letter-spacing: .4px; text-transform: uppercase; color: #fff; }}
  .ls td.t {{ width: 56px; text-align: right; font: 800 32px/1 var(--b-cond); color: var(--win, #fff); }}
  .ls tr.lose td.tm div, .ls tr.lose td.t {{ color: rgba(255,255,255,.55); }}
  .strip {{ height: 6px; border-radius: 3px; }}
  .cta {{ position: absolute; left: 20px; right: 20px; bottom: 40px; }}
  .cta .b-btn {{ width: 100%; height: 54px; font-size: 17px; }}
  .cta svg {{ width: 16px; height: 16px; fill: currentColor; }}
  {css}
</style></head>
<body class="phone b">
"""

NAV = """<div class="b-nav" style="z-index:7">
  <div class="b-icon-btn"><svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg></div>
  <div class="b-icon-btn"><svg viewBox="0 0 24 24"><path d="M12 15V3M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg></div>
</div>"""

TROPHY = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 3h10v3h3v2a4 4 0 0 1-4 4h-.3A5 5 0 0 1 13 14.9V18h3v3H8v-3h3v-3.1A5 5 0 0 1 8.3 12H8a4 4 0 0 1-4-4V6h3zm0 5V6H6v2a2 2 0 0 0 1 1.7zm10 0a2 2 0 0 0 1-1.7V6h-1z"/></svg>'
GLOBE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.4 3 14.6 0 18M12 3c-3 3.4-3 14.6 0 18"/></svg>'
FLAME = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2c1 4 6 6 6 12a6 6 0 0 1-12 0c0-3 2-5 3-6 0 2 1 3 2 3 0-4-1-6 1-9z"/></svg>'

TAIL = """
<div class="cta"><div class="b-btn" style="{btn}"><svg viewBox="0 0 24 24"><path d="M7 4.5v15l12.5-7.5z"/></svg>Play recap</div></div>
<script>
(function () {{
  const N = {sizes};
  document.querySelectorAll('[data-crop]').forEach(b => {{
    const [src, sx, sy, sw, sh] = b.dataset.crop.split(/\\s+/).map((v, i) => i ? +v : v);
    const [nw, nh] = N[src], bw = b.clientWidth, bh = b.clientHeight, s = Math.max(bw / sw, bh / sh);
    const i = document.createElement('img');
    i.src = '../../../photos/' + src;
    i.style.cssText = `position:absolute;max-width:none;width:${{nw * s}}px;height:${{nh * s}}px;left:${{bw / 2 - (sx + sw / 2) * s}}px;top:${{bh / 2 - (sy + sh / 2) * s}}px`;
    b.prepend(i);
  }});
}})();
</script>
<script src="../../../kit/kit.js"></script>
</body></html>"""

def table(cols, rows):
    th = "".join(f"<th>{c}</th>" for c in cols)
    out = f'<table class="ls"><tr><th></th>{th}<th style="text-align:right">T</th></tr>'
    for code, color, ink, city, line, total, lose in rows:
        cells = "".join(f"<td>{v}</td>" for v in line)
        out += f'<tr class="{"lose" if lose else ""}"><td class="tm"><div><span class="f-mono" style="--c:{color};color:{ink}">{code}</span>{city}</div></td>{cells}<td class="t">{total}</td></tr>'
    return out + "</table>"

def page(n, title, vars_, grade, css, hero, motif, chip, headline, where, body, btn):
    html = HEAD.format(title=title, vars=vars_, grade=grade, css=css)
    html += f'<div class="f-hero">{hero}<div class="motif">{motif}</div></div>\n{NAV}\n'
    html += f'<div class="f-col head">{chip}<div class="b-display">{headline}</div><div class="where">{where}</div></div>\n'
    html += f'<div class="f-col body">{body}</div>\n'
    html += TAIL.format(btn=btn, sizes=json.dumps({k: list(v) for k, v in SIZES.items()}))
    with open(os.path.join(OUT, f"v{n}-{title.lower().replace(' ', '-').replace('·','').replace('--','-')}.html"), "w") as f:
        f.write(html)

def bunting(colors, n=6, w=393):
    """Patriotic half-fan bunting along the top edge (World Series facade decoration)."""
    seg = w / n
    out = f'<svg width="{w}" height="70" viewBox="0 0 {w} 70" style="position:absolute;top:96px;left:0">'
    for i in range(n):
        cx = seg * i + seg / 2
        r = seg / 2 - 2
        for k, c in enumerate(colors):
            rr = r * (1 - k / len(colors))
            out += f'<path d="M{cx - rr},0 A{rr},{rr} 0 0 0 {cx + rr},0 Z" fill="{c}"/>'
        out += f'<path d="M{cx - r},0 A{r},{r} 0 0 0 {cx + r},0" fill="none" stroke="rgba(0,0,0,.25)" stroke-width="1"/>'
    return out + "</svg>"

def stars(count, color, seed=7, top=0, h=470, size=(2, 5), opacity=(.35, .95)):
    import random
    rnd = random.Random(seed)
    out = f'<svg width="393" height="{h}" style="position:absolute;top:{top}px;left:0">'
    for _ in range(count):
        x, y = rnd.uniform(0, 393), rnd.uniform(0, h * .78)
        s = rnd.uniform(*size)
        o = rnd.uniform(*opacity)
        pts = []
        import math
        for k in range(10):
            r = s if k % 2 == 0 else s * .42
            a = math.pi / 5 * k - math.pi / 2
            pts.append(f"{x + r * math.cos(a):.1f},{y + r * math.sin(a):.1f}")
        out += f'<polygon points="{" ".join(pts)}" fill="{color}" opacity="{o:.2f}"/>'
    return out + "</svg>"

os.makedirs(OUT, exist_ok=True)

# 1 · World Series: Fall Classic navy and red, facade bunting
navy, red, cream = "#0C2340", "#C8102E", "#F4EFE3"
page(1, "World Series", f"--win:{cream};", "contrast(1.05) saturate(.9) brightness(.9)", "",
     '<div class="crop" data-crop="wrigley-night.jpg 0 640 860 1024"></div>',
     bunting([red, cream, navy]),
     f'<span class="chip" style="background:{navy};color:{cream};box-shadow:inset 3px 0 0 {red}">{TROPHY}World Series · Game 5</span>',
     "Down 3–1.<br>Still alive.", "Wrigley Field, Oct 30, 2016",
     table(list(range(1, 10)), [("CLE", "#e31937", "#fff", "Cleveland", [0,1,0,0,0,1,0,0,0], 2, True),
                                ("CHC", "#2f6bff", "#fff", "Chicago", [0,0,0,3,0,0,0,0,0], 3, False)])
     + f'<div class="strip" style="background:linear-gradient(90deg,{red} 0 33%,{cream} 33% 66%,{navy} 66%)"></div>',
     f"background:{cream};color:{navy}")

# 2 · Stanley Cup Final: platinum and black, engraved silver bands
plat = "linear-gradient(180deg,#F4F6F8 0%,#C3CBD1 45%,#8E989F 55%,#DDE2E6 100%)"
rings = "".join(
    f'<div style="position:absolute;left:0;right:0;top:{y}px;height:15px;background:{plat};opacity:.9;'
    f'font:700 9px/15px var(--b-cond);letter-spacing:3px;color:rgba(20,24,28,.55);white-space:nowrap;overflow:hidden;text-indent:{(i*37)%60}px">'
    + "CHICAGO · 2015 · " * 12 + "</div>" for i, y in enumerate([118, 136])
)
page(2, "Stanley Cup Final", "--win:#E3E8EC;", "grayscale(.35) contrast(1.1) brightness(.85)", "",
     '<div class="crop" data-crop="united-center-court.jpg 300 120 680 853"></div>',
     rings,
     f'<span class="chip" style="background:{plat};color:#0b0d10">{TROPHY}Stanley Cup Final · Game 6</span>',
     "Clinched<br>on home ice.", "United Center, Jun 15, 2015",
     table([1, 2, 3], [("TB", "#0b3d91", "#fff", "Tampa Bay", [0,0,0], 0, True),
                       ("CHI", "#cf0a2c", "#fff", "Chicago", [0,1,1], 2, False)])
     + f'<div class="strip" style="background:{plat}"></div>',
     f"background:{plat};color:#0b0d10")

# 3 · Champions League Final: midnight navy, silver, a field of stars
mid, silver = "#081548", "#D3D8E0"
page(3, "Champions League Final", "--win:#fff;",
     "grayscale(1) contrast(1.15) brightness(.7) sepia(1) hue-rotate(185deg) saturate(2.2)",
     "", '<div class="crop" data-crop="camp-nou-aerial.jpg 200 60 880 900"></div>',
     f'<div style="position:absolute;inset:0;background:linear-gradient(180deg,{mid}cc,{mid}40 60%,transparent)"></div>' + stars(46, "#fff", seed=3),
     f'<span class="chip" style="background:{mid};color:{silver};box-shadow:inset 0 0 0 1px {silver}66">{TROPHY}Champions League Final</span>',
     "Two goals.<br>Injury time.", "Camp Nou, May 26, 1999",
     table(["1H", "2H"], [("BAY", "#dc052d", "#fff", "Munich", [1,0], 1, True),
                          ("MUN", "#da291c", "#fff", "Manchester", [0,2], 2, False)])
     + f'<div class="strip" style="background:linear-gradient(90deg,{mid},{silver},{mid})"></div>',
     f"background:{silver};color:{mid}")

# 4 · World Cup '94 opener: host-nation red, white and blue, stripes and stars
r94, b94 = "#C8102E", "#002868"
stripes = "".join(f'<div style="position:absolute;left:-60px;right:-60px;top:{100+i*18}px;height:9px;background:{r94 if i%2==0 else "#fff"};transform:rotate(-8deg);opacity:.85"></div>' for i in range(3))
page(4, "World Cup 1994", "--win:#fff;", "contrast(1.05) saturate(.85) brightness(.85)", "",
     '<div class="crop" data-crop="soldier-soccer.jpg 0 500 1280 1100"></div>',
     stripes + f'<div style="position:absolute;right:0;top:86px;width:150px;height:96px;background:{b94};opacity:.92;clip-path:polygon(18% 0,100% 0,100% 100%,0 100%)"></div>'
     + stars(14, "#fff", seed=11, top=86, h=110, size=(3, 5), opacity=(.9, 1)).replace('left:0', 'left:230px'),
     f'<span class="chip" style="background:{b94};color:#fff;box-shadow:inset 3px 0 0 {r94}">{GLOBE}World Cup · Opening match</span>',
     "The world<br>came to Chicago.", "Soldier Field, Jun 17, 1994",
     table(["1H", "2H"], [("BOL", "#00843d", "#fff", "Bolivia", [0,0], 0, True),
                          ("GER", "#1f1f1f", "#fff", "Germany", [0,1], 1, False)])
     + f'<div class="strip" style="background:linear-gradient(90deg,{r94} 0 33%,#fff 33% 66%,{b94} 66%)"></div>',
     f"background:#fff;color:{b94}")

# 5 · Super Bowl LIX: no photo needed; host-city purple, gold and green, harlequin, giant numerals
pur, gold, grn = "#4B2A7B", "#F2B705", "#0B7A3E"
harle = (f"background-color:{pur};background-image:linear-gradient(45deg,{grn}55 25%,transparent 25%,transparent 75%,{grn}55 75%),"
         f"linear-gradient(45deg,{grn}55 25%,transparent 25%,transparent 75%,{grn}55 75%);background-size:56px 56px;background-position:0 0,28px 28px")
page(5, "Super Bowl LIX", f"--win:{gold};", "none",
     ".lix{position:absolute;left:14px;top:96px;font:900 210px/.8 var(--b-cond);letter-spacing:-6px;color:transparent;-webkit-text-stroke:2px " + gold + ";opacity:.9}",
     f'<div style="position:absolute;inset:0;{harle}"></div><div style="position:absolute;inset:0;background:linear-gradient(180deg,transparent 30%,{pur}aa 60%,#07080a)"></div>',
     '<div class="lix">LIX</div>',
     f'<span class="chip" style="background:{gold};color:#1a0f2e">{TROPHY}Super Bowl LIX</span>',
     "Philly<br>runs away.", "Caesars Superdome, Feb 9, 2025",
     table([1, 2, 3, 4], [("PHI", "#004c54", "#fff", "Philadelphia", [7,17,10,6], 40, False),
                          ("KC", "#e31837", "#fff", "Kansas City", [0,0,6,16], 22, True)])
     + f'<div class="strip" style="background:linear-gradient(90deg,{pur} 0 33%,{gold} 33% 66%,{grn} 66%)"></div>',
     f"background:{gold};color:#1a0f2e")

# 6 · El Clásico: the rivalry split, each club in its own colors
bla, gra, rmw, rmg = "#004D98", "#A50044", "#FFFFFF", "#FEBE10"
page(6, "El Clasico", f"--win:#fff;", "contrast(1.05) saturate(.9) brightness(.8)", "",
     '<div class="crop" data-crop="camp-nou-aerial.jpg 380 300 600 660"></div>',
     f'<div style="position:absolute;inset:0;-webkit-mask-image:linear-gradient(180deg,#000 35%,transparent 72%)">'
     f'<div style="position:absolute;left:-40px;top:70px;width:260px;height:26px;background:{bla};transform:rotate(-24deg)"></div>'
     f'<div style="position:absolute;left:-40px;top:104px;width:260px;height:26px;background:{gra};transform:rotate(-24deg)"></div>'
     f'<div style="position:absolute;right:-40px;top:70px;width:260px;height:26px;background:{rmw};transform:rotate(24deg)"></div>'
     f'<div style="position:absolute;right:-40px;top:104px;width:260px;height:26px;background:{rmg};transform:rotate(24deg)"></div></div>',
     f'<span class="chip" style="background:linear-gradient(90deg,{bla},{gra});color:#fff;box-shadow:inset -4px 0 0 {rmg}">{FLAME}El Clásico</span>',
     "La Manita.", "Camp Nou, Nov 29, 2010",
     table(["1H", "2H"], [("FCB", gra, "#fff", "Barcelona", [2,3], 5, False),
                          ("RMA", rmw, "#000", "Real Madrid", [0,0], 0, True)])
     + f'<div class="strip" style="background:linear-gradient(90deg,{bla} 0 25%,{gra} 25% 50%,{rmw} 50% 75%,{rmg} 75%)"></div>',
     f"background:linear-gradient(90deg,{bla},{gra});color:#fff")

json.dump({"title": "Big games · event themes", "subtitle": "Official event colors and our own drawn motifs. No event logos or trophies."},
          open(os.path.join(OUT, "feature.json"), "w"))
print(sorted(os.listdir(OUT)))
