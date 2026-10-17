#!/usr/bin/env python3
"""Heritage badge exploration: commemorative crests, medals and pennants drawn as inline SVG.
Generates features/badges/v1..v9. No event logos, trophies or marks: generic shapes only."""
import os, json, math

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "features", "badges")
UP = "../../../../../"  # badges -> features -> heritage -> explorations -> big-games -> mockups

# ---------------------------------------------------------------- metals
METAL = {
    "gold": dict(rim=["#6e4f17", "#e9cf86", "#a77d2c", "#fff0c2", "#c79a3e", "#7a5a1c"],
                 txt=["#fff3cf", "#e6c46c", "#fbe7ad", "#d9b45a"], ink="#F1D88E",
                 btn="linear-gradient(180deg,#f8e6b0 0%,#dcb862 52%,#f0d48a 100%)"),
    "silver": dict(rim=["#5f656c", "#e8ecf0", "#9aa1a8", "#ffffff", "#b9c0c6", "#6b7178"],
                   txt=["#ffffff", "#cdd3d9", "#f4f6f8", "#bcc3ca"], ink="#DCE1E7",
                   btn="linear-gradient(180deg,#f7f9fa 0%,#c4cbd1 52%,#e6eaed 100%)"),
    "platinum": dict(rim=["#7d868f", "#eef2f5", "#aeb7bf", "#fbfdff", "#c9d1d8", "#86909a"],
                     txt=["#ffffff", "#d6dde3", "#f7f9fb", "#c3cbd2"], ink="#E4E9EE",
                     btn="linear-gradient(180deg,#fbfdff 0%,#c9d1d8 52%,#eef2f5 100%)"),
}

# ---------------------------------------------------------------- colour helpers (rivalry derivation)
def lum(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [v / 12.92 if v <= .03928 else ((v + .055) / 1.055) ** 2.4 for v in c]
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]

def contrast(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True); return (la + .05) / (lb + .05)

def sat(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return (max(c) - min(c)) / (max(c) or 1)

def hue(h):
    import colorsys
    h = h.lstrip("#"); r, g, b = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return colorsys.rgb_to_hsv(r, g, b)[0] * 360

def derive_rivalry(name, home, away, numeral, sub):
    """field = darkest saturated club colour (home wins ties); sashes = the most saturated remaining colour
    of each club; metal = gold if either club carries a yellow/gold, else silver; ink = white or black by contrast."""
    pool = [(c, 0) for c in home] + [(c, 1) for c in away]
    darks = [p for p in pool if lum(p[0]) < .15 and sat(p[0]) > .3]
    field = sorted(darks, key=lambda p: (p[1], lum(p[0])))[0][0]
    def pick(side):
        cs = [c for c, s in pool if s == side and c != field and sat(c) > .3]
        return max(cs, key=sat) if cs else ("#FFFFFF" if side else "#C8102E")
    gold = any(30 <= hue(c) <= 55 and sat(c) > .5 and lum(c) > .3 for c, _ in pool)
    ink = "#FFFFFF" if contrast("#FFFFFF", field) >= 4.5 else "#0B0B0D"
    return dict(name=name, chip=name, shape="pennant", metal="gold" if gold else "silver", field=field, ink=ink,
                accent=pick(0), accent2=pick(1), motif="sash", numeral=numeral, top=name.upper(), sub=sub)

# ---------------------------------------------------------------- themes as data
T = {
    "ws": dict(name="World Series", chip="World Series", shape="shield", metal="gold", field="#0C2340",
               ink="#F4EFE3", accent="#C8102E", motif="stars", numeral="2016", top=["WORLD SERIES"], sub="GAME 5"),
    "scf": dict(name="Stanley Cup Final", chip="Stanley Cup Final", shape="shield", metal="platinum",
                field="#121418", ink="#E4E9EE", accent="#8E989F", motif="hatch", numeral="2015",
                top=["STANLEY CUP", "FINAL"], sub="GAME 6"),
    "ucl": dict(name="Champions League Final", chip="Champions League", shape="medal", metal="silver",
                field="#081548", ink="#DCE1E7", accent="#D3D8E0", motif="guilloche", numeral="1999",
                top="CHAMPIONS", bottom="LEAGUE FINAL", ribbon=["#081548", "#D3D8E0", "#081548", "#D3D8E0", "#081548"]),
    "wc": dict(name="World Cup", chip="World Cup", shape="roundel", metal="silver", field="#002868",
               ink="#FFFFFF", accent="#C8102E", motif="stars", numeral="1994", top="WORLD CUP", bottom="OPENING MATCH"),
    "sb": dict(name="Super Bowl LIX", chip="Super Bowl LIX", shape="medal", metal="gold", field="#4B2A7B",
               ink="#F2B705", accent="#0B7A3E", motif="laurel", numeral="LIX", top="SUPER BOWL", sub="2025",
               ribbon=["#4B2A7B", "#F2B705", "#0B7A3E", "#F2B705", "#4B2A7B"]),
    "ec": derive_rivalry("El Clásico", ["#004D98", "#A50044"], ["#FFFFFF", "#FEBE10"], "5–0", "2010"),
}

VB = {"shield": (120, 160), "medal": (120, 160), "roundel": (160, 160), "pennant": (104, 160)}

# ---------------------------------------------------------------- drawing primitives
def star(cx, cy, r, fill):
    pts = []
    for k in range(10):
        rr = r if k % 2 == 0 else r * .42
        a = math.pi / 5 * k - math.pi / 2
        pts.append(f"{cx + rr * math.cos(a):.2f},{cy + rr * math.sin(a):.2f}")
    return f'<polygon points="{" ".join(pts)}" fill="{fill}"/>'

def laurel(cx, cy, r, a0, a1, n, fill):
    """A laurel sprig along an arc from angle a0 to a1 (degrees, 90 = straight down)."""
    out = []
    d = 1 if a1 > a0 else -1
    A0, A1 = math.radians(a0), math.radians(a1)
    x0, y0 = cx + r * math.cos(A0), cy + r * math.sin(A0)
    x1, y1 = cx + r * math.cos(A1), cy + r * math.sin(A1)
    out.append(f'<path d="M{x0:.2f},{y0:.2f} A{r},{r} 0 0 {1 if d > 0 else 0} {x1:.2f},{y1:.2f}" fill="none" stroke="{fill}" stroke-width=".9"/>')
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(a0 + (a1 - a0) * t)
        px, py = cx + r * math.cos(a), cy + r * math.sin(a)
        tang = math.degrees(a) + 90 * d
        s = 1 - .35 * t
        for side in (-1, 1):
            ang = tang + side * 38
            ox, oy = 3.6 * s * math.cos(math.radians(ang)), 3.6 * s * math.sin(math.radians(ang))
            out.append(f'<ellipse cx="{px + ox:.2f}" cy="{py + oy:.2f}" rx="{4.4 * s:.2f}" ry="{1.75 * s:.2f}" '
                       f'transform="rotate({ang:.1f} {px + ox:.2f} {py + oy:.2f})" fill="{fill}"/>')
    tx, ty = cx + r * math.cos(A1), cy + r * math.sin(A1)
    out.append(f'<circle cx="{tx:.2f}" cy="{ty:.2f}" r="1.4" fill="{fill}"/>')
    return "".join(out)

_uid = [0]
def uid():
    _uid[0] += 1; return f"hx{_uid[0]}"

def grad(id_, stops):
    n = len(stops) - 1
    s = "".join(f'<stop offset="{i / n:.3f}" stop-color="{c}"/>' for i, c in enumerate(stops))
    return f'<linearGradient id="{id_}" x1="0" y1="0" x2="1" y2="1">{s}</linearGradient>'

def numeral(x, y, text, size, txt_grad):
    common = (f'x="{x}" y="{y}" text-anchor="middle" font-family="Fraunces" font-weight="600" font-size="{size}" '
              f'letter-spacing="{size * .02:.2f}" style="font-variation-settings:\'opsz\' 72"')
    return (f'<text {common} fill="rgba(0,0,0,.6)" transform="translate(0 1.3)">{text}</text>'
            f'<text {common} fill="url(#{txt_grad})">{text}</text>')

def label(x, y, text, size, fill, ls=1.4):
    return (f'<text x="{x}" y="{y}" text-anchor="middle" font-family="Barlow Condensed" font-weight="700" '
            f'font-size="{size}" letter-spacing="{ls}" fill="{fill}">{text}</text>')

def arc_text(u, cx, cy, r, text, size, fill, bottom=False, ls=1.4):
    pid = f"{u}-arc{'b' if bottom else 't'}"
    d = (f"M{cx - r},{cy} A{r},{r} 0 0 0 {cx + r},{cy}" if bottom else f"M{cx - r},{cy} A{r},{r} 0 0 1 {cx + r},{cy}")
    return (f'<path id="{pid}" d="{d}" fill="none"/>'
            f'<text font-family="Barlow Condensed" font-weight="700" font-size="{size}" letter-spacing="{ls}" fill="{fill}">'
            f'<textPath href="#{pid}" startOffset="50%" text-anchor="middle">{text}</textPath></text>')

# ---------------------------------------------------------------- the badge
def badge(key, level="hero", h=160, cls="hx-badge", style=""):
    """level: hero (name + numeral + sub + motif) · stamp (numeral + motif) · glyph (shape + motif, no text)."""
    t = T[key]; m = METAL[t["metal"]]; u = uid()
    vw, vh = VB[t["shape"]]; w = h * vw / vh
    rim, txt = f"{u}-rim", f"{u}-txt"
    defs = grad(rim, m["rim"]) + grad(txt, m["txt"])
    body = []
    f, ink, met = t["field"], t["ink"], m["ink"]
    hero, stamp = level == "hero", level == "stamp"
    shape = t["shape"]

    if shape == "shield":
        outer = "M10,3 H110 Q117,3 117,10 V78 C117,117 91,141 60,157 C29,141 3,117 3,78 V10 Q3,3 10,3 Z"
        field = "M14,10 H106 Q110,10 110,14 V78 C110,112 87,133 60,149 C33,133 10,112 10,78 V14 Q10,10 14,10 Z"
        key_ = "M18,14.5 H102 Q105.5,14.5 105.5,18 V78 C105.5,109 84,128 60,143 C36,128 14.5,109 14.5,78 V18 Q14.5,14.5 18,14.5 Z"
        defs += f'<clipPath id="{u}-c"><path d="{field}"/></clipPath>'
        body.append(f'<path d="{outer}" fill="url(#{rim})"/>')
        body.append(f'<path d="{field}" fill="{f}" stroke="rgba(0,0,0,.55)" stroke-width="1"/>')
        inner = []
        if t["motif"] == "hatch":
            region = "y" if hero else "y"
            lines = "".join(f'<line x1="{c}" y1="0" x2="{c + 160}" y2="160" stroke="{met}" stroke-width=".6"/>' for c in range(-160, 130, 4))
            inner.append(f'<g opacity=".16"><clipPath id="{u}-hr"><rect x="0" y="{124 if hero else 116}" width="120" height="40"/>'
                         f'{"" if hero else "<rect x=0 y=0 width=120 height=44/>"}</clipPath><g clip-path="url(#{u}-hr)">{lines}</g></g>')
        if t["motif"] == "stars":
            # chief stripe in accent under the stars, then a band for the sub label
            by, bh = (104, 17) if hero else (106, 13)
            inner.append(f'<rect x="0" y="{by}" width="120" height="{bh}" fill="{t["accent"]}"/>')
            inner.append(f'<rect x="0" y="{by - 2.2}" width="120" height="1" fill="{met}" opacity=".8"/>'
                         f'<rect x="0" y="{by + bh + 1.2}" width="120" height="1" fill="{met}" opacity=".8"/>')
        body.append(f'<g clip-path="url(#{u}-c)">{"".join(inner)}</g>')
        body.append(f'<path d="{key_}" fill="none" stroke="url(#{rim})" stroke-width=".9" opacity=".85"/>')
        if t["motif"] == "stars":
            sy = 51 if hero else 47
            sr = 3.8 if hero else 6
            gap = 12 if hero else 17
            body += [star(60 - gap, sy, sr, f"url(#{txt})"), star(60, sy - (1 if hero else 1.5), sr * 1.2, f"url(#{txt})"), star(60 + gap, sy, sr, f"url(#{txt})")]
            if hero: body.append(star(60, 134, 4.2, f"url(#{txt})"))
        if hero:
            for i, line in enumerate(t["top"]):
                body.append(label(60, (33 if len(t["top"]) == 1 else 30) + i * 14, line, 12.5, ink if t["motif"] == "stars" else met, 1.5))
            body.append(numeral(60, 94, t["numeral"], 36, txt))
            body.append(label(60, 117, t["sub"], 12.5, ink, 2.2))
        elif stamp:
            body.append(numeral(60, 94, t["numeral"], 32, txt))

    elif shape == "medal":
        cx, cy = 60, 101
        rb = t["ribbon"]; sw = 52 / len(rb)
        ribbon = "".join(f'<rect x="{34 + i * sw:.2f}" y="0" width="{sw + .3:.2f}" height="60" fill="{c}"/>' for i, c in enumerate(rb))
        body.append(f'<g>{ribbon}<rect x="34" y="0" width="52" height="60" fill="url(#{u}-rs)"/></g>')
        defs += (f'<linearGradient id="{u}-rs" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#000" stop-opacity=".35"/>'
                 f'<stop offset=".5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></linearGradient>')
        body.append(f'<rect x="44" y="36" width="32" height="10" rx="3" fill="url(#{rim})"/>')
        body.append(f'<circle cx="{cx}" cy="{cy}" r="57" fill="url(#{rim})"/>')
        body.append(f'<circle cx="{cx}" cy="{cy}" r="51" fill="{f}" stroke="rgba(0,0,0,.55)" stroke-width="1"/>')
        defs += f'<clipPath id="{u}-c"><circle cx="{cx}" cy="{cy}" r="51"/></clipPath>'
        if t["motif"] == "guilloche":
            g = "".join(f'<ellipse cx="{cx}" cy="{cy}" rx="46" ry="15" transform="rotate({k * 10} {cx} {cy})" fill="none" stroke="{met}" stroke-width=".45"/>' for k in range(18))
            body.append(f'<g clip-path="url(#{u}-c)" opacity="{.2 if hero else .26}">{g}</g>')
        body.append(f'<circle cx="{cx}" cy="{cy}" r="47" fill="none" stroke="url(#{rim})" stroke-width=".9" opacity=".85"/>')
        if t["motif"] == "laurel":
            lr = 40 if hero else 41
            n = 7 if hero else 6
            body.append(laurel(cx, cy, lr, 98, 168, n, f"url(#{txt})") + laurel(cx, cy, lr, 82, 12, n, f"url(#{txt})"))
        if hero:
            body.append(arc_text(u, cx, cy, 38, t["top"], 12, met if t["metal"] != "gold" else ink, ls=2.0))
            if t.get("bottom"):
                body.append(arc_text(u, cx, cy, 46.5, t["bottom"], 12, met, bottom=True, ls=1.6))
            if t["numeral"].isdigit():
                body.append(numeral(cx, cy + 9.5, t["numeral"], 27, txt))
            else:
                body.append(numeral(cx, cy + 6, t["numeral"], 34, txt))
                body.append(label(cx, cy + 24, t["sub"], 12.5, ink, 2.2))
        elif stamp:
            if t["numeral"].isdigit():
                body.append(numeral(cx, cy + 10, t["numeral"], 30, txt))
            else:
                body.append(numeral(cx, cy + 13, t["numeral"], 40, txt))

    elif shape == "roundel":
        cx = cy = 80
        body.append(f'<circle cx="80" cy="80" r="77" fill="url(#{rim})"/>')
        body.append(f'<circle cx="80" cy="80" r="70" fill="{f}" stroke="rgba(0,0,0,.55)" stroke-width="1"/>')
        body.append(f'<circle cx="80" cy="80" r="65" fill="none" stroke="url(#{rim})" stroke-width=".9" opacity=".85"/>')
        sy = 98 if hero else 100
        for i, c in enumerate([t["accent"], "#FFFFFF", t["accent"]]):
            body.append(f'<rect x="{56 if hero else 50}" y="{sy + i * 4.6:.1f}" width="{48 if hero else 60}" height="3" fill="{c}"/>')
        if hero:
            body.append(arc_text(u, cx, cy, 52, t["top"], 13, ink, ls=2.6))
            body.append(arc_text(u, cx, cy, 60.5, t["bottom"], 12, met, bottom=True, ls=1.6))
            body += [star(80 - 56, 80, 3.4, f"url(#{txt})"), star(80 + 56, 80, 3.4, f"url(#{txt})")]
            body.append(numeral(80, 88, t["numeral"], 38, txt))
        elif stamp:
            body += [star(80 - 52, 80, 6, f"url(#{txt})"), star(80 + 52, 80, 6, f"url(#{txt})")]
            body.append(numeral(80, 89, t["numeral"], 36, txt))
        else:
            body += [star(80, 62, 12, f"url(#{txt})")]

    elif shape == "pennant":
        outer = "M6,6 H98 V156 L52,130 L6,156 Z"
        field = "M12,12 H92 V145.5 L52,123 L12,145.5 Z"
        key_ = "M16,16 H88 V139 L52,118.5 L16,139 Z"
        defs += f'<clipPath id="{u}-c"><path d="{field}"/></clipPath>'
        body.append(f'<path d="{outer}" fill="url(#{rim})"/>')
        body.append(f'<path d="{field}" fill="{f}" stroke="rgba(0,0,0,.55)" stroke-width="1"/>')
        o = 0 if hero else -8
        body.append(f'<g clip-path="url(#{u}-c)">'
                    f'<polygon points="0,{126 + o} 104,{100 + o} 104,{111 + o} 0,{137 + o}" fill="{t["accent"]}"/>'
                    f'<polygon points="0,{141 + o} 104,{115 + o} 104,{124 + o} 0,{150 + o}" fill="{t["accent2"]}"/></g>')
        body.append(f'<path d="{key_}" fill="none" stroke="url(#{rim})" stroke-width=".9" opacity=".85"/>')
        body.append(f'<rect x="1" y="2" width="102" height="7" rx="3.5" fill="url(#{rim})"/>')
        if hero:
            body.append(label(52, 36, t["top"], 12.5, ink, 1.5))
            body.append(numeral(52, 80, t["numeral"], 34, txt))
            body.append(label(52, 99, t["sub"], 12.5, ink, 2.4))
        elif stamp:
            body.append(numeral(52, 76, t["numeral"], 34, txt))

    return (f'<svg class="{cls}" style="{style}" width="{w:.1f}" height="{h}" viewBox="0 0 {vw} {vh}" '
            f'xmlns="http://www.w3.org/2000/svg"><defs>{defs}</defs>{"".join(body)}</svg>')

def chip(key):
    t = T[key]
    bg = "#1b1e23" if key == "scf" else t["field"]
    ink = METAL[t["metal"]]["ink"] if key in ("scf", "ucl") else t["ink"]
    return f'<span class="hx-chip" style="background:{bg};color:{ink}">{badge(key, "glyph", 20, "hx-glyph")}{t["chip"]}</span>'

def ghost(shape, h=72):
    vw, vh = VB[shape]; w = h * vw / vh
    d = {"shield": '<path d="M10,3 H110 Q117,3 117,10 V78 C117,117 91,141 60,157 C29,141 3,117 3,78 V10 Q3,3 10,3 Z"/>',
         "roundel": '<circle cx="80" cy="80" r="76"/>',
         "pennant": '<path d="M6,6 H98 V156 L52,130 L6,156 Z"/>',
         "medal": '<circle cx="60" cy="101" r="56"/>'}[shape]
    return (f'<svg width="{w:.1f}" height="{h}" viewBox="0 0 {vw} {vh}"><g fill="none" stroke="rgba(255,255,255,.28)" '
            f'stroke-width="2.2" stroke-dasharray="5 5">{d}</g></svg>')

# ---------------------------------------------------------------- page scaffolding
SIZES = {"wrigley-night.jpg": (1920, 2560), "united-center-court.jpg": (1280, 853), "camp-nou-aerial.jpg": (1280, 960),
         "soldier-soccer.jpg": (1280, 1707), "wrigley-bleachers.jpg": (1280, 853)}

CSS = """
  body.b { --b-text-3: rgba(255,255,255,.62); }
  .crop { position: absolute; inset: 0; overflow: hidden; }
  .hx-badge { display: block; filter: drop-shadow(0 12px 18px rgba(0,0,0,.55)) drop-shadow(0 1px 1px rgba(0,0,0,.7)); overflow: visible; }
  .hx-glyph { display: block; flex: none; }
  .hx-chip { display: inline-flex; align-items: center; gap: 7px; height: 28px; padding: 0 12px 0 6px; border-radius: 14px;
             font: 700 12.5px/1 var(--b-cond); letter-spacing: 1.1px; text-transform: uppercase; white-space: nowrap;
             box-shadow: inset 0 0 0 1px rgba(255,255,255,.16); }
  .ls { width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; }
  .ls th { font: 700 12px/1 var(--b-cond); letter-spacing: 2px; color: var(--b-text-3); text-align: center; padding-bottom: 8px; }
  .ls td { height: 48px; box-shadow: inset 0 1px 0 var(--b-line); text-align: center; font: 600 20px/1 var(--b-cond); color: var(--b-text-2); width: 28px; }
  .ls td.tm { text-align: left; width: auto; }
  .ls td.tm div { display: flex; align-items: center; gap: 12px; font: 700 20px/1 var(--b-cond); letter-spacing: .4px; text-transform: uppercase; color: #fff; }
  .ls td.t { width: 52px; text-align: right; font: 800 32px/1 var(--b-cond); color: #fff; }
  .ls tr.lose td.tm div, .ls tr.lose td.t { color: rgba(255,255,255,.58); }
  .cta { position: absolute; left: 20px; right: 20px; bottom: 40px; }
  .cta .b-btn { width: 100%; height: 54px; font-size: 17px; box-shadow: inset 0 1px 0 rgba(255,255,255,.7), inset 0 -1px 0 rgba(0,0,0,.25); }
  .cta svg { width: 16px; height: 16px; fill: currentColor; }
"""

def head(title, css=""):
    return f"""<html><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="{UP}kit/kit.css">
<link rel="stylesheet" href="{UP}round2/system/broadcast.css">
<link rel="stylesheet" href="{UP}final/system/final.css">
<style>{CSS}{css}</style></head>
<body class="phone b">
"""

def tail():
    return """<script>
(function () {
  const N = %s;
  document.querySelectorAll('[data-crop]').forEach(b => {
    const [src, sx, sy, sw, sh] = b.dataset.crop.split(/\\s+/).map((v, i) => i ? +v : v);
    const [nw, nh] = N[src], bw = b.clientWidth, bh = b.clientHeight, s = Math.max(bw / sw, bh / sh);
    const i = document.createElement('img');
    i.src = '%sphotos/' + src;
    i.style.cssText = `position:absolute;max-width:none;width:${nw * s}px;height:${nh * s}px;left:${bw / 2 - (sx + sw / 2) * s}px;top:${bh / 2 - (sy + sh / 2) * s}px`;
    b.prepend(i);
  });
})();
</script>
<script src="%skit/kit.js"></script>
</body></html>""" % (json.dumps({k: list(v) for k, v in SIZES.items()}), UP, UP)

def write(name, html):
    with open(os.path.join(OUT, name), "w") as fh:
        fh.write(html)

BACK = '<div class="b-icon-btn"><svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg></div>'
SHARE = '<div class="b-icon-btn"><svg viewBox="0 0 24 24"><path d="M12 15V3M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg></div>'
PLAY = '<svg viewBox="0 0 24 24"><path d="M7 4.5v15l12.5-7.5z"/></svg>'

def tabs(on):
    items = [("Timeline", '<rect x="4" y="4" width="16" height="9" rx="2"/><path d="M4 17h16M4 21h10"/>'),
             ("Map", '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3.2 3.4 3.2 14.6 0 18M12 3c-3.2 3.4-3.2 14.6 0 18"/>'),
             ("Passport", '<rect x="5" y="3" width="14" height="18" rx="2"/><circle cx="12" cy="11" r="3.5"/><path d="M9 17.5h6"/>'),
             ("You", '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.4-4 4.4-6 8-6s6.6 2 8 6"/>')]
    return '<nav class="b-tabs">' + "".join(
        f'<span{" class=on" if n == on else ""}><svg viewBox="0 0 24 24">{p}</svg>{n}</span>' for n, p in items) + "</nav>"

def table(cols, rows):
    th = "".join(f"<th>{c}</th>" for c in cols)
    out = f'<table class="ls"><tr><th></th>{th}<th style="text-align:right">T</th></tr>'
    for code, color, city, line, total, lose in rows:
        cells = "".join(f"<td>{v}</td>" for v in line)
        out += (f'<tr class="{"lose" if lose else ""}"><td class="tm"><div><span class="f-mono" style="--c:{color};box-shadow:inset 0 0 0 1px rgba(255,255,255,.14)">{code}</span>'
                f'{city}</div></td>{cells}<td class="t">{total}</td></tr>')
    return out + "</table>"

def guilloche_bg(color, cx=196, cy=230, n=36, rx=260, ry=70, op=.14):
    g = "".join(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({k * 180 / n:.2f} {cx} {cy})"/>' for k in range(n))
    rings = "".join(f'<circle cx="{cx}" cy="{cy}" r="{r}"/>' for r in range(40, 420, 14))
    return (f'<svg width="100%" height="100%" style="position:absolute;inset:0"><g fill="none" stroke="{color}" stroke-width=".6" opacity="{op}">{g}</g>'
            f'<g fill="none" stroke="{color}" stroke-width=".5" opacity="{op * .6:.3f}">{rings}</g></svg>')

# ---------------------------------------------------------------- v1 system sheet
def v1():
    css = """
  .sheet { position: absolute; top: 106px; left: 16px; right: 16px; display: grid; grid-template-columns: 1fr 1fr; column-gap: 16px; row-gap: 14px; }
  .cell { display: flex; flex-direction: column; align-items: center; gap: 8px; }
  .cell .hx-badge { filter: drop-shadow(0 6px 10px rgba(0,0,0,.5)); }
  .stamps { position: absolute; top: 732px; left: 16px; right: 16px; height: 72px; display: flex; justify-content: space-between; align-items: flex-end; }
  .stamps .hx-badge { filter: drop-shadow(0 4px 6px rgba(0,0,0,.5)); }
"""
    h = head("Badge system", css)
    h += '<div class="b-nav"><div class="f-title">Badges</div></div>'
    h += '<div class="sheet">' + "".join(f'<div class="cell">{badge(k, "hero", 160)}{chip(k)}</div>' for k in T) + "</div>"
    h += '<div class="stamps">' + "".join(badge(k, "stamp", 72) for k in T) + "</div>"
    write("v1-badge-system.html", h + tail())

# ---------------------------------------------------------------- v2-v7 game memory
MEM_CSS = """
  .f-hero { height: 470px; }
  .f-hero .crop img { filter: var(--grade); }
  .f-hero::after { background: linear-gradient(180deg, rgba(7,8,10,.55) 0%, rgba(7,8,10,0) 20%, rgba(7,8,10,0) 40%, rgba(7,8,10,.72) 74%, #07080a 100%); z-index: 2; }
  .tint { position: absolute; inset: 0; z-index: 1; }
  .pin { position: absolute; left: 20px; top: 104px; z-index: 5; }
  .head { top: 296px; z-index: 6; gap: 10px !important; }
  .head .b-display { font-size: 54px; }
  .head .where { font: 500 15px/1.3 var(--b-ui); color: rgba(255,255,255,.8); }
  .body { top: 506px; }
"""

def memory(n, key, slug, crop, grade, headline, where, cols, rows, tint="", nophoto=False, top=296, hsize=54):
    t = T[key]; m = METAL[t["metal"]]
    css = MEM_CSS + f"\n  body.b {{ --grade: {grade}; }}\n  .head {{ top: {top}px; }}\n  .head .b-display {{ font-size: {hsize}px; }}"
    if nophoto:
        css += f"""
  .f-hero {{ background: radial-gradient(120% 90% at 50% 30%, {t['field']} 0%, #1d1030 70%, #07080a 100%); }}
  .pin {{ left: 50%; top: 92px; transform: translateX(-50%); }}"""
    h = head(t["name"], css)
    if nophoto:
        h += f'<div class="f-hero">{guilloche_bg(t["ink"], cx=196, cy=196, op=.16)}</div>'
        h += f'<div class="pin">{badge(key, "hero", 196)}</div>'
    else:
        h += f'<div class="f-hero"><div class="crop" data-crop="{crop}"></div>{tint}</div>'
        h += f'<div class="pin">{badge(key, "hero", 168)}</div>'
    h += f'<div class="b-nav" style="z-index:7">{BACK}{SHARE}</div>'
    h += f'<div class="f-col head"><div class="b-display">{headline}</div><div class="where">{where}</div></div>'
    h += f'<div class="f-col body">{table(cols, rows)}</div>'
    h += f'<div class="cta"><div class="b-btn" style="background:{m["btn"]};color:{t["field"] if key != "scf" else "#0b0d10"}">{PLAY}Play recap</div></div>'
    write(f"v{n}-{slug}.html", h + tail())

def memories():
    memory(2, "ws", "world-series", "wrigley-night.jpg 0 640 860 1024", "contrast(1.05) saturate(.9) brightness(.9)",
           "Down 3–1.<br>Still alive.", "Wrigley Field, Oct 30, 2016", list(range(1, 10)),
           [("CLE", "#e31937", "Cleveland", [0, 1, 0, 0, 0, 1, 0, 0, 0], 2, True),
            ("CHC", "#2f6bff", "Chicago", [0, 0, 0, 3, 0, 0, 0, 0, 0], 3, False)])
    memory(3, "scf", "stanley-cup-final", "united-center-court.jpg 300 120 680 853", "grayscale(.45) contrast(1.1) brightness(.82)",
           "Clinched<br>on home ice.", "United Center, Jun 15, 2015", [1, 2, 3],
           [("TB", "#0b3d91", "Tampa Bay", [0, 0, 0], 0, True), ("CHI", "#cf0a2c", "Chicago", [0, 1, 1], 2, False)])
    memory(4, "ucl", "champions-league-final", "camp-nou-aerial.jpg 200 60 880 900",
           "grayscale(1) contrast(1.15) brightness(.7) sepia(1) hue-rotate(185deg) saturate(2.2)",
           "Two goals.<br>Injury time.", "Camp Nou, May 26, 1999", ["1H", "2H"],
           [("BAY", "#dc052d", "Munich", [1, 0], 1, True), ("MUN", "#da291c", "Manchester", [0, 2], 2, False)],
           tint='<div class="tint" style="background:linear-gradient(180deg,#081548cc,#08154833 60%,transparent)"></div>')
    memory(5, "wc", "world-cup-1994", "soldier-soccer.jpg 0 500 1280 1100", "contrast(1.05) saturate(.85) brightness(.85)",
           "The world<br>came to<br>Chicago.", "Soldier Field, Jun 17, 1994", ["1H", "2H"],
           [("BOL", "#00843d", "Bolivia", [0, 0], 0, True), ("GER", "#2b2b30", "Germany", [0, 1], 1, False)],
           top=292, hsize=50)
    memory(6, "sb", "super-bowl-lix", "", "none", "Philly<br>runs away.", "Caesars Superdome, Feb 9, 2025", [1, 2, 3, 4],
           [("PHI", "#004c54", "Philadelphia", [7, 17, 10, 6], 40, False), ("KC", "#e31837", "Kansas City", [0, 0, 6, 16], 22, True)],
           nophoto=True, top=318)
    memory(7, "ec", "el-clasico", "camp-nou-aerial.jpg 380 300 600 660", "contrast(1.05) saturate(.85) brightness(.8)",
           "La Manita.", "Camp Nou, Nov 29, 2010", ["1H", "2H"],
           [("FCB", "#a50044", "Barcelona", [2, 3], 5, False), ("RMA", "#3a3a40", "Real Madrid", [0, 0], 0, True)],
           top=340)

# ---------------------------------------------------------------- v8 timeline
def v8():
    css = """
  .feed { position: absolute; top: 112px; left: 20px; right: 20px; display: flex; flex-direction: column; gap: 16px; }
  .card { position: relative; border-radius: 16px; overflow: hidden; box-shadow: inset 0 0 0 1px var(--b-line); }
  .card.big { height: 240px; }
  .card.small { height: 132px; }
  .card .crop img { filter: contrast(1.05) saturate(.9) brightness(.85); }
  .card .scrim { position: absolute; inset: 0; background: linear-gradient(180deg, rgba(7,8,10,0) 30%, rgba(7,8,10,.88) 100%); }
  .card .ring { position: absolute; inset: 0; border-radius: 16px; pointer-events: none; }
  .card .stamp { position: absolute; top: 14px; right: 14px; }
  .card .stamp .hx-badge { filter: drop-shadow(0 6px 10px rgba(0,0,0,.6)); }
  .card .txt { position: absolute; left: 16px; right: 16px; bottom: 14px; }
  .card .ttl { font: 800 30px/.92 var(--b-cond); text-transform: uppercase; letter-spacing: -.2px; }
  .card.small .ttl { font-size: 24px; }
  .card .meta { margin-top: 10px; display: flex; align-items: center; justify-content: space-between; }
  .card .date { font: 600 14px/1 var(--b-ui); color: rgba(255,255,255,.82); }
  .b-bug { height: 30px; font-size: 16px; }
"""
    h = head("Timeline", css)
    h += '<div class="b-nav"><div class="f-title">Timeline</div><div class="b-icon-btn"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg></div></div>'
    sb, ws = T["sb"], T["ws"]
    def bug(a, ac, sa, b, bc, sb_):
        return f'<div class="b-bug"><span class="team" style="--c:{ac}">{a}</span><span class="score">{sa}</span><span class="team" style="--c:{bc}">{b}</span><span class="score">{sb_}</span></div>'
    h += '<div class="feed">'
    h += (f'<div class="card big" style="background:radial-gradient(120% 120% at 80% 0%, {sb["field"]} 0%, #1d1030 70%, #0e0814 100%)">'
          f'{guilloche_bg(sb["ink"], cx=300, cy=60, n=30, rx=200, ry=56, op=.14)}<div class="scrim"></div>'
          f'<div class="ring" style="box-shadow:inset 0 0 0 1px rgba(242,183,5,.45)"></div>'
          f'<div class="stamp">{badge("sb", "stamp", 72)}</div>'
          f'<div class="txt"><div class="ttl">Philly<br>runs away.</div><div class="meta"><span class="date">Feb 9, 2025</span>'
          f'{bug("PHI", "#004c54", 40, "KC", "#e31837", 22)}</div></div></div>')
    h += ('<div class="card small"><div class="crop" data-crop="wrigley-bleachers.jpg 200 150 900 500"></div><div class="scrim"></div>'
          '<div class="txt"><div class="ttl">Walk-off in the ninth.</div><div class="meta"><span class="date">Aug 18, 2024</span>'
          f'{bug("MIL", "#c8960f", 4, "CHC", "#2f6bff", 5)}</div></div></div>')
    h += ('<div class="card big"><div class="crop" data-crop="wrigley-night.jpg 0 640 860 1024"></div><div class="scrim"></div>'
          '<div class="ring" style="box-shadow:inset 0 0 0 1px rgba(241,216,142,.45)"></div>'
          f'<div class="stamp">{badge("ws", "stamp", 72)}</div>'
          '<div class="txt"><div class="ttl">Down 3–1.<br>Still alive.</div><div class="meta"><span class="date">Oct 30, 2016</span>'
          f'{bug("CLE", "#e31937", 2, "CHC", "#2f6bff", 3)}</div></div></div>')
    h += "</div>" + tabs("Timeline")
    write("v8-timeline.html", h + tail())

# ---------------------------------------------------------------- v9 passport
def v9():
    css = """
  .hero { position: absolute; top: 118px; left: 20px; right: 20px; display: flex; align-items: flex-end; gap: 14px; }
  .hero .b-mega { font-size: 120px; }
  .hero .unit { font: 800 22px/1 var(--b-cond); letter-spacing: 1.5px; text-transform: uppercase; color: rgba(255,255,255,.72); padding-bottom: 8px; }
  .grid { position: absolute; top: 290px; left: 20px; right: 20px; display: grid; grid-template-columns: repeat(3, 1fr); row-gap: 34px; }
  .st { display: flex; flex-direction: column; align-items: center; gap: 10px; }
  .st .art { height: 76px; display: flex; align-items: flex-end; }
  .st .hx-badge { filter: drop-shadow(0 3px 5px rgba(0,0,0,.55)); }
  .st .cap { font: 600 13px/1.2 var(--b-ui); color: rgba(255,255,255,.72); text-align: center; white-space: nowrap; }
  .st.ghost .cap { color: rgba(255,255,255,.55); }
"""
    h = head("Passport", css)
    h += '<div class="b-nav"><div class="f-title">Passport</div><div class="b-icon-btn"><svg viewBox="0 0 24 24"><path d="M12 15V3M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg></div></div>'
    h += '<div class="hero"><div class="b-mega">6</div><div class="unit">Big games<br>witnessed</div></div>'
    caps = {"ws": "Wrigley Field", "scf": "United Center", "ucl": "Camp Nou", "wc": "Soldier Field", "sb": "Superdome", "ec": "Camp Nou"}
    h += '<div class="grid">'
    for k in ["sb", "ws", "scf", "wc", "ucl", "ec"]:
        h += f'<div class="st"><div class="art">{badge(k, "stamp", 72)}</div><div class="cap">{caps[k]}</div></div>'
    for shape, cap in [("shield", "Title series"), ("roundel", "Tournament"), ("pennant", "Rivalry")]:
        h += f'<div class="st ghost"><div class="art">{ghost(shape, 72)}</div><div class="cap">{cap}</div></div>'
    h += "</div>" + tabs("Passport")
    write("v9-passport.html", h + tail())

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "feature.json"), "w") as fh:
        json.dump({"title": "Big games · Heritage badges",
                   "summary": "Commemorative crests, medals and pennants: event colours, metal rims, engraved numerals. No event logos or trophies."}, fh)
    v1(); memories(); v8(); v9()
    print("ec theme derived:", T["ec"])
