#!/usr/bin/env python3
"""Builds the Timeline view-mode mockups (HTML) from the canonical sample library.
Run: python3 build.py   (then render with render.cjs, see NOTES.md)"""
import json, os, math, calendar, hashlib, shutil
from datetime import datetime, timedelta
try:
    from zoneinfo import ZoneInfo
    CT = ZoneInfo('America/Chicago')
except Exception:
    CT = None

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(HERE, '..', '..', 'Witness', 'Resources', 'Sample', 'library.json')
FEAT = os.path.join(HERE, 'features')
K = '../../../'  # features/<folder>/ -> mockups/

SPORT = {'baseball': '#FF5A4F', 'football': '#3DDC84', 'basketball': '#FFA42E', 'hockey': '#5AC8FA',
         'soccer': '#E6F05A', 'motorsport': '#BF7BFF', 'handball': '#FF7AD1'}
SNAME = {'baseball': 'Baseball', 'football': 'Football', 'basketball': 'Basketball', 'hockey': 'Hockey',
         'soccer': 'Soccer', 'motorsport': 'Motorsport'}
IMG = {'camp-nou-aerial': (1280, 960), 'fenway-day': (1280, 853), 'fenway-night': (1280, 1707), 'lambeau-concourse': (1920, 1288),
       'lambeau-exterior': (1920, 1050), 'soldier-aerial': (1280, 960), 'soldier-skyline': (1280, 1019), 'soldier-soccer': (1280, 1707),
       'united-center-court': (1280, 853), 'wrigley-bleachers': (1280, 853), 'wrigley-night-2': (1920, 2560), 'wrigley-night': (1920, 2560),
       'wrigley-scoreboard-wide': (1280, 831), 'wrigley-scoreboard': (1280, 719)}
# crop windows (cx, cy, width as fraction of image width). Chosen to keep the "209" seat sign, team banners and sponsor logos out.
WIN = {
 'wrigley-night': [(0.73, 0.525, 0.40), (0.27, 0.475, 0.47), (0.53, 0.53, 0.40)],
 'wrigley-night-2': [(0.67, 0.67, 0.47), (0.25, 0.62, 0.40), (0.5, 0.64, 0.5)],
 'lambeau-concourse': [(0.62, 0.47, 0.38), (0.62, 0.63, 0.42)],
 'wrigley-bleachers': [(0.5, 0.5, 0.95), (0.3, 0.5, 0.55), (0.72, 0.5, 0.55), (0.5, 0.42, 0.5)],
 'united-center-court': [(0.5, 0.45, 0.95), (0.3, 0.5, 0.55), (0.7, 0.45, 0.55), (0.5, 0.5, 0.45)],
 'soldier-skyline': [(0.5, 0.5, 0.95), (0.3, 0.45, 0.55), (0.75, 0.55, 0.55)],
 'soldier-aerial': [(0.5, 0.5, 0.95), (0.35, 0.5, 0.55), (0.7, 0.45, 0.5)],
 'wrigley-scoreboard': [(0.5, 0.5, 0.95), (0.35, 0.5, 0.55), (0.7, 0.5, 0.55)],
 'wrigley-scoreboard-wide': [(0.5, 0.5, 0.95), (0.3, 0.55, 0.55), (0.72, 0.5, 0.5)],
 'fenway-night': [(0.5, 0.5, 0.9)], 'soldier-soccer': [(0.5, 0.55, 0.8), (0.5, 0.4, 0.55)], 'camp-nou-aerial': [(0.5, 0.5, 0.95), (0.4, 0.5, 0.55)],
}

# ------------------------------------------------------------------ data
def code(tid):
    if not tid: return ''
    s = tid.split('-', 1)[1].upper()
    return s
def local(d):
    t = datetime.strptime(d, '%Y-%m-%dT%H:%M:%SZ')
    if CT: return t.replace(tzinfo=ZoneInfo('UTC')).astimezone(CT).replace(tzinfo=None)
    return t - timedelta(hours=5)
BIGKEYS = ['Stanley Cup Final', 'World Series', 'NLDS', 'NLCS', 'ALDS', 'Wild Card', 'Clásico', 'Revierderby', 'Grand Prix']
def tier(comp):
    if not comp: return 0
    if any(k in comp for k in ('World Series', 'Stanley Cup Final', 'Clásico')): return 2
    if any(k in comp for k in BIGKEYS): return 1
    return 0
def palette(comp):
    c = comp or ''
    if 'World Series' in c: return ['#0C2340', '#C8102E', '#F4EFE3']
    if 'Stanley Cup' in c: return ['#15181d', '#C9CED6', '#8C939E']
    if 'Clásico' in c: return ['#004D98', '#A50044', '#FEBE10']
    if 'Revier' in c: return ['#FDE100', '#111111', '#004D9D']
    if 'Grand Prix' in c: return ['#BF7BFF', '#F4EFE3', '#1b1030']
    return ['#1b2a41', '#E3B341', '#F4EFE3']  # generic playoff
VENUES = {'wrigley': ('Wrigley Field', 41.948, -87.656), 'united-center': ('United Center', 41.880, -87.674), 'soldier': ('Soldier Field', 41.862, -87.617),
          'rate-field': ('Rate Field', 41.830, -87.634), 'amfam': ('American Family Field', 43.028, -87.971), 'busch': ('Busch Stadium', 38.623, -90.193),
          'target-field': ('Target Field', 44.982, -93.278), 'fenway': ('Fenway Park', 42.346, -71.097), 'comerica': ('Comerica Park', 42.339, -83.049),
          'progressive': ('Progressive Field', 41.496, -81.685), 'pnc': ('PNC Park', 40.447, -80.006), 'kauffman': ('Kauffman Stadium', 39.051, -94.480),
          'gabp': ('Great American Ball Park', 39.097, -84.507), 'yankee': ('Yankee Stadium', 40.829, -73.926), 'dodger': ('Dodger Stadium', 34.074, -118.240),
          'oracle': ('Oracle Park', 37.779, -122.389), 'lambeau': ('Lambeau Field', 44.501, -88.062), 'cota': ('Circuit of the Americas', 30.135, -97.641),
          'camp-nou': ('Camp Nou', 41.381, 2.123), 'bernabeu': ('Santiago Bernabéu', 40.453, -3.688), 'signal-iduna': ('Signal Iduna Park', 51.493, 7.452)}

G = []
for g in json.load(open(LIB)):
    d = local(g['date'])
    ph = g['photos'][0]['bundled']['_0'] if g['photos'] else None
    h, a = g['homeTeamId'], g['awayTeamId']
    root = g.get('rootingForTeamId') or h
    if root == a:
        me, op, ms, os_ = a, h, g['awayScore'], g['homeScore']
    else:
        me, op, ms, os_ = h, a, g['homeScore'], g['awayScore']
    res = None
    if ms is not None: res = 'W' if ms > os_ else ('L' if ms < os_ else 'T')
    comp = g['competition']
    G.append(dict(id=g['id'], sport=g['sport'], dt=d, y=d.year, m=d.month, day=d.day, photo=ph, me=code(me), op=code(op), ms=ms, os=os_, res=res,
                  comp=comp, tier=tier(comp), pal=palette(comp), head=g['headline'], venue=VENUES[g['venueId']][0], vid=g['venueId'], seat=g['seat'],
                  color=SPORT[g['sport']]))
G.sort(key=lambda x: x['dt'])
for i, g in enumerate(G): g['n'] = i + 1
BYID = {g['id']: g for g in G}
NEW = sorted(G, key=lambda x: x['dt'], reverse=True)
MON = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC']
MONF = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
DOW = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
def dstr(g, y=True): return f"{MON[g['m']-1].title()} {g['day']}" + (f", {g['y']}" if y else '')

# ------------------------------------------------------------------ html helpers
def crop(photo, tw, th, k=0):
    iw, ih = IMG[photo]
    cx, cy, wf = WIN.get(photo, [(0.5, 0.5, 0.95)])[k % len(WIN.get(photo, [1]))]
    s = tw / (wf * iw)
    s = max(s, th / ih, tw / iw)
    W, H = iw * s, ih * s
    x = min(0, max(tw - W, tw / 2 - cx * W)); y = min(0, max(th - H, th / 2 - cy * H))
    return f"background:url({K}photos/{photo}.jpg) {x:.1f}px {y:.1f}px/{W:.1f}px {H:.1f}px no-repeat"
def hsh(s): return int(hashlib.md5(s.encode()).hexdigest()[:6], 16)
def ph_style(g, tw, th):
    if not g['photo']: return None
    return crop(g['photo'], tw, th, hsh(g['id']))
def cover_bg(g, tw, th):
    s = ph_style(g, tw, th)
    if s: return s, ''
    c = g['color']
    return (f"background:linear-gradient(155deg,{c}55 0%,#14161c 62%),#14161c", 'np')

def pin(pal, w=12):
    h = round(w * 1.25)
    return (f'<svg class="pn" width="{w}" height="{h}" viewBox="0 0 12 15"><path d="M1 1h10v7c0 3-3 5-5 6-2-1-5-3-5-6z" fill="{pal[0]}" stroke="rgba(255,255,255,.55)" stroke-width=".8"/>'
            f'<rect x="1.4" y="6" width="9.2" height="2" fill="{pal[1]}"/></svg>')
def ribbon(pal, w=30):
    return f'<span class="rb" style="width:{w}px"><i style="background:{pal[0]}"></i><i style="background:{pal[1]}"></i><i style="background:{pal[2]}"></i></span>'
def evname(g):
    return (g['comp'] or '').replace('Game ', 'G').replace(' · ', ' · ').upper()
def evmark(g):
    return f'<div class="ev">{pin(g["pal"],12)}<span>{evname(g)}</span></div>'
def bug(g, cls=''):
    if g['ms'] is None:
        return f'<span class="sb {cls}" style="--c:{g["color"]}"><i class="d"></i><span class="t">USGP</span><b class="w">P3</b></span>'
    w, l = ('w', 'l') if g['ms'] > g['os'] else (('l', 'w') if g['ms'] < g['os'] else ('w', 'w'))
    return (f'<span class="sb {cls}" style="--c:{g["color"]}"><i class="d"></i><span class="t">{g["me"]}</span><b class="{w}">{g["ms"]}</b>'
            f'<span class="t">{g["op"]}</span><b class="{l}">{g["os"]}</b></span>')
def scoretxt(g):
    if g['ms'] is None: return 'USGP'
    return f"{g['me']} {g['ms']}–{g['os']}"

ICON = {
 'seasons': '<rect x="3" y="3" width="8" height="10" rx="1.6"/><rect x="13" y="3" width="8" height="6" rx="1.6"/><rect x="13" y="11" width="8" height="10" rx="1.6"/><rect x="3" y="15" width="8" height="6" rx="1.6"/>',
 'calendar': '<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
 'mosaic': '<rect x="3" y="3" width="4.5" height="4.5" rx="1"/><rect x="9.8" y="3" width="4.5" height="4.5" rx="1"/><rect x="16.5" y="3" width="4.5" height="4.5" rx="1"/><rect x="3" y="9.8" width="4.5" height="4.5" rx="1"/><rect x="9.8" y="9.8" width="4.5" height="4.5" rx="1"/><rect x="16.5" y="9.8" width="4.5" height="4.5" rx="1"/><rect x="3" y="16.5" width="4.5" height="4.5" rx="1"/><rect x="9.8" y="16.5" width="4.5" height="4.5" rx="1"/><rect x="16.5" y="16.5" width="4.5" height="4.5" rx="1"/>',
 'tickets': '<rect x="3" y="7" width="18" height="12" rx="2.2"/><path d="M15 7v12" stroke-dasharray="1.6 2.2"/><path d="M6 4h12"/>',
 'map': '<path d="M12 21s-6-5.4-6-10a6 6 0 0 1 12 0c0 4.6-6 10-6 10z"/><circle cx="12" cy="11" r="2.2"/>',
 'strip': '<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M8 6v12M16 6v12M3 10h18"/>',
 'cards': '<rect x="4" y="4" width="16" height="9" rx="2"/><path d="M4 17h16M4 21h10"/>',
}
def ico(k, cls=''): return f'<svg class="{cls}" viewBox="0 0 24 24">{ICON[k]}</svg>'
VIEWS = [('seasons', 'Seasons', 'Posters by year'), ('calendar', 'Calendar', 'Every day of a year'), ('mosaic', 'Mosaic', 'Pinch: years, months, all'),
         ('tickets', 'Tickets', 'Fan through your stubs'), ('map', 'Map', 'Scrub through time and places'), ('strip', 'Strip', 'Scoreboard bugs by month')]

CSS = """
body.b{--b-text-3:rgba(255,255,255,.62)}
.vpill{height:40px;padding:0 11px 0 12px;border-radius:12px;display:flex;align-items:center;gap:8px;background:var(--b-panel-2);box-shadow:inset 0 0 0 1px var(--b-line);font:800 15px/1 var(--b-cond);letter-spacing:1.3px;text-transform:uppercase}
.vpill svg{width:19px;height:19px;stroke:#fff;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
.vpill svg.chev{width:12px;height:12px;opacity:.65;stroke-width:2.6}
.vpill.open{background:#fff;color:#000}.vpill.open svg{stroke:#000}.vpill.open svg.chev{transform:rotate(180deg);opacity:1}
.chips{position:absolute;top:108px;left:20px;right:0;display:flex;gap:8px;white-space:nowrap;overflow:hidden;z-index:5}
.chip{height:32px;padding:0 12px;border-radius:16px;display:inline-flex;align-items:center;gap:7px;background:var(--b-panel-2);box-shadow:inset 0 0 0 1px var(--b-line);font:700 13px/1 var(--b-cond);letter-spacing:1px;text-transform:uppercase;color:rgba(255,255,255,.8);flex:none}
.chip i{width:8px;height:8px;border-radius:50%;background:var(--c)}
.chip em{font-style:normal;opacity:.62;font-weight:600}
.chip.on{background:#fff;color:#000}.chip.on em{opacity:.6}
.sb{display:inline-flex;align-items:center;gap:6px;font:700 15px/1 var(--b-cond);letter-spacing:.6px;text-transform:uppercase;white-space:nowrap;color:rgba(255,255,255,.82)}
.sb .d{width:7px;height:7px;border-radius:50%;background:var(--c);flex:none;margin-right:1px}
.sb .w{color:#fff;font-weight:800;margin-right:4px}.sb .l{color:rgba(255,255,255,.58);font-weight:700}
.sb.lg{font-size:18px;gap:7px}.sb.lg .d{width:9px;height:9px}
.sb.sm{font-size:13px;gap:5px}.sb.sm .d{width:6px;height:6px}
.pn{display:block;flex:none}
.ev{display:flex;align-items:center;gap:6px;font:800 12px/1 var(--b-cond);letter-spacing:1.6px;text-transform:uppercase;color:#fff}
.rb{display:flex;height:3px;border-radius:2px;overflow:hidden}.rb i{flex:1}
.tile{position:relative;overflow:hidden;border-radius:10px;background-color:#12141a}
.tile.np{display:grid;place-items:center}
.tile .np-t{font:800 15px/1 var(--b-cond);letter-spacing:.5px;color:rgba(255,255,255,.9);text-align:center;position:relative}
.tile .sp{position:absolute;left:0;right:0;bottom:0;height:3px;background:var(--c)}
.tile .scr{position:absolute;inset:0;background:linear-gradient(180deg,rgba(7,8,10,0) 38%,rgba(7,8,10,.9))}
.tile .tx{position:absolute;left:9px;right:9px;bottom:10px}
.tile .dt{font:700 12px/1 var(--b-cond);letter-spacing:1.5px;text-transform:uppercase;color:rgba(255,255,255,.82);margin-bottom:5px}
.tile .tpin{position:absolute;top:8px;left:8px;filter:drop-shadow(0 1px 3px rgba(0,0,0,.7))}
.tile.bm .ttl{font-size:21px;line-height:.95;display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:3;overflow:hidden;margin:6px 0 0}.tile.bm .f-between .dt{display:none}.tile.bm .f-between{justify-content:flex-start;margin-top:8px}.tile .ttl{font:800 26px/.92 var(--b-cond);text-transform:uppercase;margin:8px 0 9px}
.lbl{font:700 12px/1 var(--b-cond);letter-spacing:2px;text-transform:uppercase;color:rgba(255,255,255,.62)}
.abs{position:absolute}
.fade-b{position:absolute;left:0;right:0;bottom:84px;height:60px;background:linear-gradient(180deg,rgba(7,8,10,0),#07080a);z-index:6;pointer-events:none}
"""

def chips(active=('all',), counts=None):
    cnt = {'all': 60, 'baseball': 31, 'football': 10, 'soccer': 7, 'hockey': 6, 'basketball': 5, 'motorsport': 1}
    if counts: cnt.update(counts)
    out = f'<span class="chip {"on" if "all" in active else ""}">All <em>{cnt["all"]}</em></span>'
    for s in ['baseball', 'football', 'soccer', 'hockey', 'basketball', 'motorsport']:
        out += f'<span class="chip {"on" if s in active else ""}" style="--c:{SPORT[s]}"><i></i>{SNAME[s]} <em>{cnt[s]}</em></span>'
    return f'<div class="chips">{out}</div>'

TABS = ('<nav class="b-tabs"><span class=on><svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="9" rx="2"/><path d="M4 17h16M4 21h10"/></svg>Timeline</span>'
        '<span><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3.2 3.4 3.2 14.6 0 18M12 3c-3.2 3.4-3.2 14.6 0 18"/></svg>Map</span>'
        '<span><svg viewBox="0 0 24 24"><rect x="5" y="3" width="14" height="18" rx="2"/><circle cx="12" cy="11" r="3.5"/><path d="M9 17.5h6"/></svg>Passport</span>'
        '<span><svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.4-4 4.4-6 8-6s6.6 2 8 6"/></svg>You</span></nav>')
CHEV = '<svg class="chev" viewBox="0 0 12 12"><path d="M2 4.2l4 4 4-4" fill="none"/></svg>'
def vpill(view, open_=False):
    lab = dict((k, n) for k, n, _ in VIEWS).get(view, 'Cards')
    return f'<div class="vpill {"open" if open_ else ""}">{ico(view)}{lab}{CHEV}</div>'
def nav(view, open_=False, pill=True):
    return f'<div class="b-nav"><div class="f-title">Timeline</div>{vpill(view, open_) if pill else ""}</div>'

def page(title, body, extra_css='', scripts_before='', ):
    return (f'<!doctype html><html><head><meta charset="utf-8"><title>{title}</title>'
            f'<link rel="stylesheet" href="{K}kit/kit.css"><link rel="stylesheet" href="{K}round2/system/broadcast.css"><link rel="stylesheet" href="{K}final/system/final.css">'
            f'<style>{CSS}{extra_css}</style></head><body class="phone b">{body}{scripts_before}<script src="{K}kit/kit.js"></script></body></html>')

def tile_html(g, tw, th, style_extra='', mode='small', show_pin=True):
    bg, cls = cover_bg(g, tw, th)
    inner = ''
    if cls == 'np': inner += f'<div class="np-t">{scoretxt(g)}</div>'
    pn = f'<span class="tpin">{pin(g["pal"], 12 if mode != "big" else 16)}</span>' if (g['tier'] and show_pin) else ''
    if mode == 'big':
        cls += ' bm' if tw < 260 else ''
        tx = (f'<div class="scr"></div><div class="tx">{evmark(g)}<div style="margin-top:7px">{ribbon(g["pal"], 34)}</div>'
              f'<div class="ttl">{g["head"].rstrip(".")}.</div><div class="f-between"><span class="dt" style="margin:0">{MON[g["m"]-1]} {g["day"]}, {g["y"]}</span>{bug(g)}</div></div>')
        pn = ''
    elif mode == 'small':
        tx = f'<div class="scr"></div><div class="tx"><div class="dt">{MON[g["m"]-1]} {g["day"]}</div>{bug(g, "sm")}</div>'
    else:
        tx = ''
    return f'<div class="tile {cls}" style="--c:{g["color"]};{bg};{style_extra}">{inner}{tx}{pn}<i class="sp"></i></div>'

# ------------------------------------------------------------------ year rail
def year_rail(sel, top):
    years = sorted(set(g['y'] for g in G))
    cnt = {y: [g for g in G if g['y'] == y] for y in years}
    mx = max(len(v) for v in cnt.values())
    out = f'<div class="abs" style="left:20px;right:20px;top:{top}px"><div class="lbl" style="margin-bottom:10px">Seasons · {len(G)} games</div><div style="display:flex;gap:7px;height:76px;align-items:flex-end">'
    for y in years:
        gs = cnt[y]; on = y == sel
        bars = ''.join(f'<i style="display:block;height:{ (56/mx) - 2:.1f}px;margin-top:2px;border-radius:2px;background:{g["color"]};opacity:{1 if on else .5}"></i>' for g in sorted(gs, key=lambda x: x['sport']))
        out += (f'<div style="width:20px;display:flex;flex-direction:column;align-items:center"><div style="width:20px;display:flex;flex-direction:column-reverse">{bars}</div>'
                f'<div style="margin-top:6px;font:{800 if on else 700} 12px/1 var(--b-cond);letter-spacing:.3px;color:{"#fff" if on else "rgba(255,255,255,.55)"}">’{str(y)[2:]}</div>'
                f'<div style="height:2px;width:14px;margin-top:4px;border-radius:1px;background:{"#fff" if on else "transparent"}"></div></div>')
    return out + '</div></div>'

# ------------------------------------------------------------------ 01 season shelf
def season_page(year, one_game=False):
    gs = [g for g in G if g['y'] == year]
    if one_game:
        gs = [BYID['mlb-2026-0704']]
    big = sorted([g for g in gs if g['tier'] == 2], key=lambda x: x['dt'], reverse=True)[:1] or sorted(gs, key=lambda x: (-x['tier'], -x['n']))[:1]
    rest = sorted([g for g in gs if g not in big], key=lambda x: x['dt'], reverse=True)
    wins = sum(1 for g in gs if g['res'] == 'W'); loss = sum(1 for g in gs if g['res'] == 'L')
    u = (353 - 16) / 3
    hero = (f'<div class="abs" style="left:20px;right:20px;top:152px;display:flex;align-items:flex-end;justify-content:space-between">'
            f'<div style="font:800 92px/.78 var(--b-cond);letter-spacing:-2px;font-variant-numeric:tabular-nums">{year}</div>'
            f'<div class="f-stats" style="padding-bottom:2px"><div style="padding-right:16px"><b>{len(gs)}</b><span>{"Game" if len(gs)==1 else "Games"}</span></div><div><b style="white-space:nowrap">{wins}–{loss}</b><span>Record</span></div></div></div>')
    grid = '<div class="abs" style="left:20px;top:258px;width:353px;height:%dpx">' % (3 * u + 16)
    b = big[0]
    if one_game:
        bw, bh = 353, 353
        grid = f'<div class="abs" style="left:20px;top:258px;width:353px">{tile_html(b, bw, bh, "width:353px;height:353px;border-radius:14px", "big")}'
        grid += (f'<div style="margin-top:12px;height:64px;border-radius:12px;border:1.5px dashed rgba(255,255,255,.22);display:flex;align-items:center;gap:12px;padding:0 16px;color:rgba(255,255,255,.72)">'
                 f'<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>'
                 f'<span class="b-h2" style="font-size:19px">Next game goes here</span></div></div>')
    else:
        grid += f'<div class="abs" style="left:0;top:0;width:{2*u+8}px;height:{2*u+8}px">{tile_html(b, 2*u+8, 2*u+8, "width:100%;height:100%;border-radius:14px", "big")}</div>'
        pos = [(2*u+16, 0), (2*u+16, u+8)] + [(i*(u+8), 2*(u+8)) for i in range(3)]
        for g, (x, y) in zip(rest, pos):
            grid += f'<div class="abs" style="left:{x:.1f}px;top:{y:.1f}px;width:{u:.1f}px;height:{u:.1f}px">{tile_html(g, u, u, "width:100%;height:100%")}</div>'
        grid += '</div>'
    # next page peek (2017 / none)
    peek = ''
    if not one_game:
        nxt = [g for g in G if g['y'] == year + 1][:3]
        for i, g in enumerate(nxt):
            peek += f'<div class="abs" style="left:381px;top:{258+i*(u+8):.1f}px;width:{u:.1f}px;height:{u:.1f}px;opacity:.55">{tile_html(g, u, u, "width:100%;height:100%", "none")}</div>'
        peek += f'<div class="abs" style="left:381px;top:258px;width:12px;height:{3*u+16:.1f}px;background:linear-gradient(90deg,transparent,rgba(7,8,10,.55))"></div>'
    body = nav('seasons') + chips() + hero + grid + peek + year_rail(year, 652 if not one_game else 652) + TABS
    return body

# ------------------------------------------------------------------ 02 calendar
def calendar_page(year, sel_id):
    gs = {(g['m'], g['day']): g for g in G if g['y'] == year}
    sg = BYID[sel_id]
    n = len(gs); sports = len(set(g['sport'] for g in gs.values()))
    head = (f'<div class="abs" style="left:20px;right:20px;top:152px;display:flex;align-items:center;justify-content:space-between">'
            f'<div style="display:flex;align-items:center;gap:12px"><svg width="14" height="14" viewBox="0 0 12 12" fill="none" stroke="rgba(255,255,255,.6)" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 2L4 6l4 4"/></svg>'
            f'<span style="font:800 40px/1 var(--b-cond);letter-spacing:-.5px">{year}</span>'
            f'<svg width="14" height="14" viewBox="0 0 12 12" fill="none" stroke="rgba(255,255,255,.6)" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 2l4 4-4 4"/></svg></div>'
            f'<span class="lbl" style="font-size:13px">{n} games · {sports} sports</span></div>')
    months = '<div class="abs" style="left:20px;top:206px;width:353px;display:grid;grid-template-columns:repeat(3,113px);column-gap:7px;row-gap:12px">'
    for m in range(1, 13):
        first, nd = calendar.monthrange(year, m)  # Monday=0
        first = (first + 1) % 7  # Sunday-first
        has = any(k[0] == m for k in gs)
        cells = ''
        for i in range(first): cells += '<i></i>'
        for d in range(1, nd + 1):
            g = gs.get((m, d))
            if g:
                sel = g is sg
                cells += (f'<i style="display:grid;place-items:center"><b style="display:block;width:13px;height:13px;border-radius:50%;background:{g["color"]};'
                          f'box-shadow:0 0 9px {g["color"]}99{",0 0 0 2px #07080a,0 0 0 3.5px #fff" if sel else ""}"></b></i>')
            else:
                cells += '<i style="display:grid;place-items:center"><b style="display:block;width:4px;height:4px;border-radius:50%;background:rgba(255,255,255,.2)"></b></i>'
        months += (f'<div><div style="font:800 13px/1 var(--b-cond);letter-spacing:2px;color:{"#fff" if has else "rgba(255,255,255,.45)"};margin-bottom:6px">{MON[m-1]}</div>'
                   f'<div style="display:grid;grid-template-columns:repeat(7,16px);grid-auto-rows:14px">{cells}</div></div>')
    months += '</div>'
    ph = ph_style(sg, 92, 92)
    peek = (f'<div class="abs" style="left:20px;right:20px;top:652px;height:96px;border-radius:14px;overflow:hidden;background:var(--b-panel);box-shadow:inset 0 0 0 1px var(--b-line);display:flex;--c:{sg["color"]}">'
            f'<div style="width:96px;flex:none;position:relative;{ph}"><i style="position:absolute;left:0;top:0;bottom:0;width:4px;background:{sg["color"]}"></i></div>'
            f'<div style="flex:1;padding:12px 14px;display:flex;flex-direction:column;justify-content:space-between;min-width:0">'
            f'<div class="lbl">{DOW[sg["dt"].weekday()]} · {MON[sg["m"]-1]} {sg["day"]} · {sg["venue"]}</div>'
            f'<div class="b-h2" style="font-size:20px;line-height:1">{sg["head"]}</div><div>{bug(sg)}</div></div></div>')
    # caret from selected day to card
    return nav('calendar') + chips() + head + months + peek + TABS

# ------------------------------------------------------------------ 03 mosaic
def zoom_pill(level):
    items = ''.join(f'<span style="padding:0 16px;height:34px;display:grid;place-items:center;border-radius:17px;font:800 13px/1 var(--b-cond);letter-spacing:1.6px;text-transform:uppercase;'
                    f'{"background:#fff;color:#000" if l==level else "color:rgba(255,255,255,.78)"}">{l}</span>' for l in ['Years', 'Months', 'All'])
    return (f'<div class="abs" style="left:50%;transform:translateX(-50%);bottom:100px;z-index:20;padding:3px;border-radius:21px;display:flex;background:rgba(24,26,32,.86);'
            f'backdrop-filter:blur(18px);box-shadow:inset 0 0 0 1px var(--b-line),0 10px 30px rgba(0,0,0,.5)">{items}</div>')

def mosaic_page(level, games=None, active=('all',), counts=None, filter_note=None):
    games = games if games is not None else NEW
    area = '<div class="abs" style="left:20px;right:20px;top:152px;bottom:84px;overflow:hidden">'
    if level == 'Months':
        cols, gap = 4, 4
        t = (353 - gap * (cols - 1)) / cols
        # scroll window starts at Oct 2016
        win = [g for g in games if g['dt'] <= datetime(2016, 10, 31, 23)]
        last_y = None; area += '<div style="display:flex;flex-direction:column;gap:14px">'
        groups = {}
        for g in win[:30]: groups.setdefault((g['y'], g['m']), []).append(g)
        for (y, m), gl in groups.items():
            yy = f'<span style="font:800 26px/1 var(--b-cond);letter-spacing:-.3px;margin-right:10px">{y}</span>' if y != last_y else ''
            last_y = y
            n = sum(1 for x in games if (x['y'], x['m']) == (y, m))
            area += f'<div><div style="display:flex;align-items:baseline;margin-bottom:7px">{yy}<span class="lbl" style="font-size:13px">{MONF[m-1]} · {n} {"game" if n==1 else "games"}</span></div>'
            area += '<div style="display:grid;grid-template-columns:repeat(4,%.2fpx);gap:%dpx;grid-auto-flow:dense;grid-auto-rows:%.2fpx">' % (t, gap, t)
            for g in gl:
                if g['tier'] == 2:
                    area += f'<div style="grid-column:span 2;grid-row:span 2">{tile_html(g, 2*t+gap, 2*t+gap, "width:100%;height:100%", "big")}</div>'
                else:
                    area += f'<div>{tile_html(g, t, t, "width:100%;height:100%;border-radius:8px", "tiny")}</div>'
            area += '</div></div>'
        area += '</div>'
    elif level == 'All':
        cols, gap = 5, 3
        t = (353 - gap * 4) / 5
        area += '<div style="display:grid;grid-template-columns:repeat(5,%.2fpx);gap:%dpx;grid-auto-flow:dense;grid-auto-rows:%.2fpx">' % (t, gap, t)
        ly = None
        for g in games[:60]:
            if g['y'] != ly:
                area += f'<div style="grid-column:1/-1;align-self:end;height:34px;margin-bottom:-{t-34:.2f}px;font:800 24px/1 var(--b-cond);padding:8px 0 4px">{g["y"]}</div>'; ly = g['y']
            if g['tier'] == 2:
                area += f'<div style="grid-column:span 2;grid-row:span 2">{tile_html(g, 2*t+gap, 2*t+gap, "width:100%;height:100%;border-radius:7px", "tiny")}</div>'
            else:
                area += f'<div>{tile_html(g, t, t, "width:100%;height:100%;border-radius:6px", "tiny")}</div>'
        area += '</div>'
    else:  # Years
        t = (353 - 16) / 3
        area += '<div style="display:grid;grid-template-columns:repeat(3,%.2fpx);gap:8px;grid-auto-rows:%.2fpx">' % (t, t * 1.22)
        years = sorted(set(g['y'] for g in games), reverse=True)
        for y in years:
            gs = [g for g in games if g['y'] == y]
            gsp = sorted(gs, key=lambda x: (-x['tier'], 0 if x['photo'] else 1, -x['n']))
            cg = gsp[0]
            bg, cls = cover_bg(cg, t, t * 1.22)
            dots = ''.join(f'<i style="width:6px;height:6px;border-radius:50%;background:{SPORT[s]}"></i>' for s in dict.fromkeys(x['sport'] for x in gs))
            pn = f'<span style="position:absolute;top:9px;left:9px;filter:drop-shadow(0 1px 3px rgba(0,0,0,.7))">{pin(cg["pal"], 12)}</span>' if cg['tier'] else ''
            area += (f'<div class="tile {cls}" style="{bg};border-radius:12px"><div class="scr"></div>{pn}<div style="position:absolute;top:10px;right:9px;display:flex;gap:4px">{dots}</div>'
                     f'<div class="tx"><div style="font:800 38px/.9 var(--b-cond);letter-spacing:-.5px">{y}</div><div class="dt" style="margin:4px 0 0">{len(gs)} {"game" if len(gs)==1 else "games"}</div></div></div>')
        area += '</div>'
    area += '</div>'
    return nav('mosaic') + chips(active, counts) + area + '<div class="fade-b"></div>' + zoom_pill(level) + TABS

# ------------------------------------------------------------------ 04 wallet
def barcode(seed):
    r = hsh(seed); x = 0; out = ''
    while x < 92:
        w = 1 + (r % 3); r = (r * 7 + 11) % 997
        out += f'<rect x="{x}" y="0" width="{w}" height="34"/>'; x += w + 1 + (r % 2)
    return f'<svg width="92" height="34" viewBox="0 0 92 34" fill="rgba(255,255,255,.75)">{out}</svg>'

def wallet_page():
    front = NEW[0]
    fc = front['color']
    ph = crop(front['photo'], 353, 132, 0)
    f = (f'<div class="abs" style="left:20px;top:152px;width:353px;height:290px;--c:{fc};filter:drop-shadow(0 18px 24px rgba(0,0,0,.55));z-index:10">'
         f'<div style="position:absolute;inset:0;border-radius:20px;overflow:hidden;background:#12151b;'
         f'-webkit-mask:radial-gradient(circle 10px at 0 206px,#0000 98%,#000) left/51% 100% no-repeat,radial-gradient(circle 10px at 100% 206px,#0000 98%,#000) right/51% 100% no-repeat;'
         f'mask:radial-gradient(circle 10px at 0 206px,#0000 98%,#000) left/51% 100% no-repeat,radial-gradient(circle 10px at 100% 206px,#0000 98%,#000) right/51% 100% no-repeat">'
         f'<div style="position:absolute;left:0;top:0;bottom:0;width:6px;background:{fc};z-index:3"></div>'
         f'<div style="height:132px;position:relative;{ph}"><div class="scr" style="background:linear-gradient(180deg,rgba(7,8,10,.15),rgba(18,21,27,.96))"></div>'
         f'<div class="abs" style="left:0;right:0;top:0;height:46px;background:linear-gradient(180deg,rgba(7,8,10,.75),transparent)"></div><div class="abs" style="left:22px;top:14px"><span class="lbl" style="color:#fff">№ {front["n"]:03d} · Baseball</span></div></div>'
         f'<div style="padding:4px 20px 0 22px;height:74px"><div class="lbl" style="font-size:12px">{DOW[front["dt"].weekday()]} · {dstr(front)} · {front["venue"]}</div>'
         f'<div class="b-h1" style="margin-top:9px;font-size:32px">{front["head"]}</div></div>'
         f'<div style="position:absolute;left:22px;right:22px;top:206px;border-top:2px dashed rgba(255,255,255,.2)"></div>'
         f'<div style="position:absolute;left:22px;right:20px;top:222px;display:flex;align-items:center;justify-content:space-between"><div>{bug(front,"lg")}<div class="lbl" style="margin-top:10px">Admit one · you were there</div></div>{barcode(front["id"])}</div>'
         f'</div></div>')
    strips = ''
    top = 428
    for i, g in enumerate(NEW[1:6]):
        c = g['color']
        strips += (f'<div class="abs" style="left:20px;top:{top + i*70}px;width:353px;height:260px;z-index:{11+i};border-radius:20px;background:linear-gradient(180deg,#171a21,#10131a);'
                   f'box-shadow:0 -10px 20px rgba(0,0,0,.55),inset 0 0 0 1px rgba(255,255,255,.08),inset 0 2px 0 {c}">'
                   f'<div style="position:absolute;left:0;top:18px;bottom:0;width:6px;background:{c};border-radius:0"></div>'
                   f'<div style="padding:13px 18px 0 24px"><div style="display:flex;justify-content:space-between;align-items:center"><div class="lbl">{MON[g["m"]-1]} {g["day"]}, {g["y"]} · № {g["n"]:03d}</div>{bug(g)}</div>'
                   f'<div class="b-h2" style="margin-top:9px;font-size:21px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{g["head"]}</div></div></div>')
    hint = ('<div class="abs" style="left:0;right:0;top:112px;text-align:center;z-index:2"><span class="lbl" style="font-size:12px">Newest on top · drag the stack to fan through</span></div>')
    return nav('tickets') + chips() + hint.replace('top:112px', 'top:0;display:none') + f + strips + '<div class="fade-b" style="z-index:40;bottom:84px"></div>' + TABS

# ------------------------------------------------------------------ 05 map scrubber
def map_page(sel_id):
    sel = BYID[sel_id]
    t0, t1 = G[0]['dt'], G[-1]['dt']
    def X(g): return 20 + (g['dt'] - t0) / (t1 - t0) * 353
    visits = {}
    for g in G: visits.setdefault(g['vid'], []).append(g)
    vdata = []
    for vid, gl in visits.items():
        name, lat, lon = VENUES[vid]
        past = [g for g in gl if g['dt'] <= sel['dt']]
        vdata.append(dict(id=vid, name=name, lat=lat, lon=lon, n=len(gl), seen=len(past), sport=gl[0]['sport'], color=gl[0]['color']))
    ticks = ''
    for g in G:
        past = g['dt'] <= sel['dt']
        h = 22 if g['tier'] else 12
        ticks += f'<i style="position:absolute;left:{X(g)-1:.1f}px;bottom:0;width:2px;height:{h}px;border-radius:1px;background:{g["color"]};opacity:{1 if past else .3}"></i>'
    xs = X(sel)
    yrs = ''.join(f'<span class="abs" style="left:{max(20,20+(datetime(y,1,1)-t0).total_seconds()/(t1-t0).total_seconds()*353-14):.1f}px;top:46px;font:700 12px/1 var(--b-cond);letter-spacing:.5px;color:rgba(255,255,255,.58)">{y}</span>' for y in (2014, 2018, 2022, 2026))
    scrub = (f'<div class="abs" style="left:0;right:0;top:432px;height:80px">'
             f'<div class="abs" style="left:20px;width:353px;top:12px;height:24px">{ticks}</div>{yrs}'
             f'<div class="abs" style="left:{xs-1.5:.1f}px;top:4px;width:3px;height:36px;border-radius:2px;background:#fff;box-shadow:0 0 12px rgba(255,255,255,.6)"></div>'
             f'<div class="abs" style="left:{xs-52:.1f}px;top:-26px;width:104px;height:26px;border-radius:13px;background:#fff;color:#000;display:grid;place-items:center;font:800 13px/1 var(--b-cond);letter-spacing:1.2px">{MON[sel["m"]-1]} {sel["day"]} · {sel["y"]}</div></div>')
    ph = crop(sel['photo'], 353, 220, 0)
    card = (f'<div class="abs" style="left:20px;top:530px;width:353px;height:224px;border-radius:16px;overflow:hidden;box-shadow:inset 0 0 0 1px var(--b-line);{ph}">'
            f'<div class="scr" style="background:linear-gradient(180deg,rgba(7,8,10,.15) 20%,rgba(7,8,10,.96) 82%)"></div>'
            f'<div class="abs" style="left:16px;right:16px;bottom:14px">{evmark(sel)}<div style="margin-top:7px">{ribbon(sel["pal"],34)}</div>'
            f'<div class="b-h1" style="font-size:30px;margin:9px 0 10px">{sel["head"].rstrip(".")}.</div>'
            f'<div class="f-between"><span style="font:600 14px/1 var(--b-ui);color:rgba(255,255,255,.85)">{sel["venue"]} · {dstr(sel)}</span>{bug(sel)}</div></div></div>')
    js = ("<script src=\"%skit/vendor/d3.min.js\"></script><script src=\"%skit/vendor/topojson-client.min.js\"></script><script src=\"%skit/vendor/land-50m.js\"></script><script src=\"%skit/vendor/states-10m.js\"></script>" % (K, K, K, K))
    js += """<script>(function(){
const V=%s; const sel=%s;
const W=393,H=290,R=230,cx=196.5,cy=150;
const proj=d3.geoOrthographic().rotate([75,-27]).scale(R).translate([cx,cy]).clipAngle(90);
const path=d3.geoPath(proj);
const land=topojson.feature(window.__atlas['land-50m'],window.__atlas['land-50m'].objects.land);
const st=topojson.mesh(window.__atlas['states-10m'],window.__atlas['states-10m'].objects.states,(a,b)=>a!==b);
const grat=d3.geoGraticule10();
let s='<svg width="393" height="290" viewBox="0 0 393 290" style="position:absolute;left:0;top:0">';
s+='<defs><radialGradient id="gl" cx="50%%" cy="38%%" r="65%%"><stop offset="0" stop-color="#1c2230"/><stop offset="1" stop-color="#0a0c11"/></radialGradient></defs>';
s+='<circle cx="'+cx+'" cy="'+cy+'" r="'+R+'" fill="url(#gl)" stroke="rgba(255,255,255,.14)"/>';
s+='<path d="'+path(grat)+'" fill="none" stroke="rgba(255,255,255,.05)"/>';
s+='<path d="'+path(land)+'" fill="#202633" stroke="rgba(255,255,255,.16)" stroke-width=".6"/>';
s+='<path d="'+path(st)+'" fill="none" stroke="rgba(255,255,255,.1)" stroke-width=".5"/>';
let sp=null;
V.forEach(v=>{const p=proj([v.lon,v.lat]); if(!p) return; const seen=v.seen>0; if(v.id===sel.vid){sp=[p,v];return;}
 s+='<circle cx="'+p[0]+'" cy="'+p[1]+'" r="'+(seen?4.5:3.5)+'" fill="'+v.color+'" opacity="'+(seen?1:.28)+'"'+(seen?' stroke="#07080a" stroke-width="1.5"':'')+'/>';});
if(sp){const p=sp[0]; s+='<circle cx="'+p[0]+'" cy="'+p[1]+'" r="20" fill="none" stroke="#fff" stroke-opacity=".28"/><circle cx="'+p[0]+'" cy="'+p[1]+'" r="12" fill="'+sel.color+'" fill-opacity=".28"/><circle cx="'+p[0]+'" cy="'+p[1]+'" r="7" fill="'+sel.color+'" stroke="#fff" stroke-width="2.5"/>';
 s+='<text x="'+(p[0]+16)+'" y="'+(p[1]-18)+'" fill="#fff" font-family="Barlow Condensed" font-weight="800" font-size="14" letter-spacing="1.4" style="text-transform:uppercase;paint-order:stroke;stroke:#07080a;stroke-width:4px">'+sp[1].name.toUpperCase()+'</text>';}
s+='</svg>';
const el=document.getElementById('globe'); el.innerHTML=s;
})();</script>""" % (json.dumps(vdata), json.dumps(dict(vid=sel['vid'], name=VENUES[sel['vid']][0], color=sel['color'])))
    globe = ('<div id="globe" class="abs" style="left:0;top:146px;width:393px;height:282px;overflow:hidden;-webkit-mask:linear-gradient(180deg,#000 80%,transparent);mask:linear-gradient(180deg,#000 80%,transparent)"></div>'
             f'<div class="abs" style="left:20px;top:152px;z-index:3"><span class="lbl">{len(visits)} venues · 3 countries</span></div>')
    return nav('map') + chips() + globe + scrub + card + TABS, js

# ------------------------------------------------------------------ 06 strip
def strip_page(sel_id):
    sel = BYID[sel_id]
    wins = [g for g in NEW if g['dt'] <= datetime(2016, 10, 31, 23) and g['dt'] >= datetime(2015, 6, 1)]
    groups = {}
    for g in wins: groups.setdefault((g['y'], g['m']), []).append(g)
    out = '<div class="abs" style="left:20px;right:0;top:152px;bottom:150px;overflow:hidden">'
    ly = None
    spr = 'background-image:radial-gradient(rgba(255,255,255,.2) 1.6px,transparent 2px);background-size:12px 8px;background-position:3px 0;height:8px'
    for (y, m), gl in sorted(groups.items(), reverse=True):
        if y != ly:
            tot = sum(1 for g in G if g['y'] == y)
            out += f'<div style="display:flex;align-items:baseline;gap:10px;margin:{0 if ly is None else 8}px 0 6px"><span style="font:800 28px/1 var(--b-cond);letter-spacing:-.3px">{y}</span><span class="lbl">{tot} games</span></div>'; ly = y
        out += f'<div style="margin-bottom:10px"><div class="lbl" style="margin-bottom:6px;font-size:12px">{MONF[m-1]}</div>'
        sh = max(0, len(gl) * 112 - 345)
        out += f'<div style="background:#0d0f13;border-radius:8px;box-shadow:inset 0 0 0 1px var(--b-line);overflow:hidden;display:inline-block;transform:translateX(-{sh}px)"><div style="{spr}"></div><div style="display:flex">'
        for g in sorted(gl, key=lambda x: x['dt']):
            on = g is sel
            ev = f'<span style="margin-left:auto">{pin(g["pal"],10)}</span>' if g['tier'] else ''
            out += (f'<div style="flex:none;width:112px;height:46px;padding:7px 10px 0;box-shadow:inset -1px 0 0 var(--b-line){",inset 0 0 0 2px #fff" if on else ""};background:{"#232733" if on else "transparent"}">'
                    f'<div style="display:flex;align-items:center;gap:6px;font:700 12px/1 var(--b-cond);letter-spacing:1.2px;color:rgba(255,255,255,.62)"><span>{DOW[g["dt"].weekday()]} {g["day"]}</span>{ev}</div>'
                    f'<div style="margin-top:6px">{bug(g)}</div></div>')
        out += f'</div><div style="{spr}"></div></div></div>'
    out += '</div>'
    ph = crop(sel['photo'], 76, 60, 0)
    readout = (f'<div class="abs" style="left:20px;right:20px;top:664px;height:84px;border-radius:14px;background:var(--b-panel);box-shadow:inset 0 0 0 1px var(--b-line);display:flex;align-items:center;gap:14px;padding:12px">'
               f'<div style="width:76px;height:60px;border-radius:8px;flex:none;{ph}"></div><div style="flex:1;min-width:0">{evmark(sel)}'
               f'<div class="b-h2" style="font-size:22px;margin:6px 0 6px">{sel["head"].rstrip(".")}.</div><div style="font:500 13px/1 var(--b-ui);color:rgba(255,255,255,.62)">{sel["venue"]} · {dstr(sel)}</div></div>'
               f'<svg width="14" height="14" viewBox="0 0 12 12" fill="none" stroke="rgba(255,255,255,.6)" stroke-width="2.2" stroke-linecap="round"><path d="M4 2l4 4-4 4"/></svg></div>')
    return nav('strip') + chips() + out + '<div class="fade-b" style="bottom:182px;height:50px"></div>' + readout + TABS

# ------------------------------------------------------------------ switcher
def menu_page():
    base = season_page(2016)
    rows = ''
    for k, n, s in VIEWS + [('cards', 'Cards', 'Classic big photo cards')]:
        on = k == 'seasons'
        sep = 'margin-top:6px;' if k == 'cards' else ''
        rows += (f'<div style="{sep}display:flex;align-items:center;gap:13px;height:56px;padding:0 16px;box-shadow:inset 0 -1px 0 rgba(255,255,255,.08)">'
                 f'<div style="width:34px;height:34px;border-radius:9px;display:grid;place-items:center;background:{"#fff" if on else "rgba(255,255,255,.09)"}">'
                 f'<svg viewBox="0 0 24 24" width="19" height="19" style="stroke:{"#000" if on else "#fff"};fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round">{ICON[k]}</svg></div>'
                 f'<div style="flex:1;min-width:0"><div style="font:700 17px/1 var(--b-cond);letter-spacing:.5px;text-transform:uppercase">{n}</div>'
                 f'<div style="font:500 13px/1 var(--b-ui);color:rgba(255,255,255,.62);margin-top:5px">{s}</div></div>'
                 + ('<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>' if on else '') + '</div>')
    menu = (f'<div class="abs" style="left:0;right:0;top:0;bottom:0;background:rgba(7,8,10,.62);backdrop-filter:blur(7px);z-index:40"></div>'
            f'<div class="abs" style="left:63px;right:20px;top:104px;z-index:50;border-radius:22px;background:rgba(30,32,40,.94);backdrop-filter:blur(30px);'
            f'box-shadow:inset 0 0 0 1px rgba(255,255,255,.12),0 24px 60px rgba(0,0,0,.6);overflow:hidden">'
            f'<div class="lbl" style="padding:16px 16px 8px">View as</div>{rows}</div>')
    nav_open = nav('seasons', True).replace('class="b-nav"', 'class="b-nav" style="z-index:60"')
    body = base.replace(nav('seasons'), nav_open) + menu
    return body

def options_page():
    def frame(label, verdict, inner, h=150):
        return (f'<div style="margin-bottom:18px"><div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:8px"><span class="b-h2" style="font-size:20px">{label}</span></div>'
                f'<div style="height:{h}px;border-radius:14px;background:#0b0d11;box-shadow:inset 0 0 0 1px var(--b-line);position:relative;overflow:hidden">{inner}</div>'
                f'<div style="font:500 13px/1.35 var(--b-ui);color:rgba(255,255,255,.7);margin-top:8px">{verdict}</div></div>')
    # A: segmented icons
    seg = ''.join(f'<span style="width:32px;height:32px;border-radius:9px;display:grid;place-items:center;{"background:#fff" if k=="seasons" else ""}"><svg viewBox="0 0 24 24" width="17" height="17" style="stroke:{"#000" if k=="seasons" else "#fff"};fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round">{ICON[k]}</svg></span>' for k, _, _ in VIEWS)
    A = (f'<div class="abs" style="left:14px;right:14px;top:14px;display:flex;justify-content:space-between;align-items:center"><span class="f-title" style="font-size:26px">Timeline</span>'
         f'<div style="display:flex;padding:3px;border-radius:12px;background:var(--b-panel-2);box-shadow:inset 0 0 0 1px var(--b-line)">{seg}</div></div>'
         f'<div class="abs" style="left:14px;top:76px">{chips_inline()}</div>')
    # B: pull-down (chosen)
    B = (f'<div class="abs" style="left:14px;right:14px;top:14px;display:flex;justify-content:space-between;align-items:center"><span class="f-title" style="font-size:26px">Timeline</span>{vpill("seasons")}</div>'
         f'<div class="abs" style="left:14px;top:76px">{chips_inline()}</div>')
    # C: floating pill
    cl = ''.join(f'<span style="width:38px;height:36px;border-radius:18px;display:grid;place-items:center;{"background:#fff" if k=="seasons" else ""}"><svg viewBox="0 0 24 24" width="18" height="18" style="stroke:{"#000" if k=="seasons" else "#fff"};fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round">{ICON[k]}</svg></span>' for k, _, _ in VIEWS)
    C = (f'<div class="abs" style="left:14px;right:14px;top:14px;display:flex;justify-content:space-between;align-items:center"><span class="f-title" style="font-size:26px">Timeline</span><span class="b-icon-btn" style="width:34px;height:34px"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg></span></div>'
         f'<div class="abs" style="left:14px;top:62px">{chips_inline()}</div>'
         f'<div class="abs" style="left:50%;transform:translateX(-50%);bottom:10px;padding:3px;border-radius:22px;display:flex;background:rgba(36,38,46,.95);box-shadow:inset 0 0 0 1px var(--b-line)">{cl}</div>')
    return (nav('seasons', pill=False).replace('<div class="f-title">Timeline</div>', '<div class="f-title">View switcher</div>') +
            '<div class="abs" style="left:20px;right:20px;top:112px">'
            + frame('A · Segmented icons in the nav bar', 'Always visible, but six unlabeled icons take 204pt, crowd the title, and cap us at six views.', A)
            + frame('B · Pull-down menu (recommended)', 'One 40pt button shows the current view by name. Opens a labeled list with room for hints and for a seventh view. Native Menu in SwiftUI.', B)
            + frame('C · Bottom floating pill', 'Thumb-reachable, but it sits on the tab bar, collides with the Mosaic zoom control and the wallet stack.', C, 156)
            + '</div>' + TABS)
def chips_inline():
    return ('<div style="display:flex;gap:8px;white-space:nowrap">' + ''.join(
        f'<span class="chip {"on" if s=="all" else ""}" style="--c:{SPORT.get(s,"#fff")};height:28px;font-size:12px">' + ('' if s == 'all' else '<i></i>') + f'{s.title()}</span>' for s in ['all', 'baseball', 'football', 'hockey']) + '</div>')

# ------------------------------------------------------------------ empty
def empty_page():
    ghosts = ''
    u = (353 - 16) / 3
    pos = [(0, 0, 2 * u + 8, 2 * u + 8), (2 * u + 16, 0, u, u), (2 * u + 16, u + 8, u, u)]
    for x, y, w, h in pos:
        ghosts += f'<div class="abs" style="left:{x:.1f}px;top:{y:.1f}px;width:{w:.1f}px;height:{h:.1f}px;border-radius:14px;border:1.5px dashed rgba(255,255,255,.14);background:rgba(255,255,255,.025)"></div>'
    body = (f'<div class="b-nav"><div class="f-title">Timeline</div></div>'
            f'<div class="abs" style="left:20px;top:152px;font:800 92px/.78 var(--b-cond);letter-spacing:-2px;color:rgba(255,255,255,.16)">2026</div>'
            f'<div class="abs" style="left:20px;top:258px;width:353px;height:{2*u+8:.0f}px">{ghosts}</div>'
            f'<div class="abs" style="left:20px;right:20px;top:{258+2*u+8+32:.0f}px"><div class="b-display" style="font-size:44px">Your seasons start here.</div>'
            f'<div class="b-body" style="margin-top:12px;font-size:16px">Add a game, or let Witness find the ones already in your photos. Views like Calendar and Map unlock after your second game.</div>'
            f'<div style="display:flex;flex-direction:column;gap:10px;margin-top:24px"><div class="b-btn">Find games in my photos</div><div class="b-btn ghost">Add a game by hand</div></div></div>' + TABS)
    return body

# ------------------------------------------------------------------ write
def write(folder, fname, title, body, summary=None, js=''):
    d = os.path.join(FEAT, folder); os.makedirs(d, exist_ok=True)
    open(os.path.join(d, fname), 'w').write(page(title, body, scripts_before=js))
def meta(folder, title, summary):
    json.dump({'title': title, 'summary': summary}, open(os.path.join(FEAT, folder, 'feature.json'), 'w'), ensure_ascii=False)

if __name__ == '__main__':
    shutil.rmtree(FEAT, ignore_errors=True)
    write('00-switcher', 'v1-menu-open.html', 'Switcher · open', menu_page())
    base = mosaic_page('Months', games=[g for g in NEW if g['sport'] == 'baseball'], active=('baseball',), counts={'all': 60})
    write('00-switcher', 'v2-closed-with-filter.html', 'Switcher · closed + filter', base)
    write('00-switcher', 'v3-control-options.html', 'Switcher · options', options_page())
    meta('00-switcher', 'View switcher', 'Pull-down button in the nav bar (recommended), shown open, closed beside the sport chips, and against two alternatives.')
    write('01-season-shelf', 'v1-season-2016.html', 'Season shelf', season_page(2016))
    meta('01-season-shelf', 'Season shelf', 'Horizontal pages by season; each page is a poster grid of that year\'s covers with the big game promoted.')
    write('02-calendar-heatmap', 'v1-year-2014.html', 'Calendar heat map', calendar_page(2014, 'nba-2014-1225'))
    meta('02-calendar-heatmap', 'Calendar heat map', 'A year of days; game days glow in sport colors; tap a day to peek the card.')
    write('03-cover-mosaic', 'v1-months.html', 'Mosaic · Months', mosaic_page('Months'))
    write('03-cover-mosaic', 'v2-years.html', 'Mosaic · Years', mosaic_page('Years'))
    write('03-cover-mosaic', 'v3-all.html', 'Mosaic · All', mosaic_page('All'))
    meta('03-cover-mosaic', 'Cover mosaic', 'Pinch between Years, Months and All; finals get 2x2 tiles.')
    write('04-ticket-wallet', 'v1-stack.html', 'Ticket wallet', wallet_page())
    meta('04-ticket-wallet', 'Ticket wallet', 'Newest stub expanded on top; older stubs stacked wallet-style with sport-colored edges.')
    b, js = map_page('mlb-2016-ws5')
    write('05-map-scrubber', 'v1-scrub-2016.html', 'Map scrubber', b, js=js)
    meta('05-map-scrubber', 'Map-linked scrubber', 'Globe on top, time scrubber under it, one card below; scrubbing moves the pin and the card.')
    write('06-scoreboard-strip', 'v1-by-month.html', 'Scoreboard strip', strip_page('mlb-2016-ws5'))
    meta('06-scoreboard-strip', 'Scoreboard strip', 'Film strips of score bugs grouped by month; the compact way to scan hundreds.')
    write('07-states', 'v1-one-game.html', 'State · one game', season_page(2026, one_game=True))
    write('07-states', 'v2-empty.html', 'State · empty', empty_page())
    meta('07-states', 'Edge states', 'First game and no games.')
    print('built', sum(len(f) for _, _, f in os.walk(FEAT)), 'files')
