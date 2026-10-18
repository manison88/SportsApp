#!/usr/bin/env python3
"""Generates v1-main.html and v2-states.html. Usage: python3 build.py 07|08 (default: from folder name)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
MODE = sys.argv[1] if len(sys.argv) > 1 else HERE.split('/')[-1][:2]
K = '../../../'
CW = 361

def crop(name, W0, H0, cx, cy, w, ph):
    W = CW / w; H = W * H0 / W0
    left = min(0, max(CW - W, CW / 2 - cx * W)); top = min(0, max(ph - H, ph / 2 - cy * H))
    return f'<img class="ph graded" src="{K}photos/{name}.jpg" style="position:absolute;width:{W:.0f}px;height:{H:.0f}px;left:{left:.0f}px;top:{top:.0f}px;max-width:none">'

ICON = {
 'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
 'people': '<circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.4 2.7-5.5 6-5.5s6 2.1 6 5.5"/><path d="M16 5.2a3 3 0 010 5.6M18 14.8c2 .7 3.2 2.4 3.2 5.2"/>',
 'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.2 2"/>',
 'camera': '<path d="M3 8.5A2.5 2.5 0 015.5 6H8l1.4-2h5.2L16 6h2.5A2.5 2.5 0 0121 8.5v9a2.5 2.5 0 01-2.5 2.5h-13A2.5 2.5 0 013 17.5z"/><circle cx="12" cy="13" r="3.6"/>',
 'pencil': '<path d="M4 20l1-4L16.5 4.5a2 2 0 013 0l0 0a2 2 0 010 3L8 19z"/><path d="M14.5 6.5l3 3"/>',
}
def ic(n, s=14): return f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{ICON[n]}</svg>'

def tile(code, bg, fg, rooted):
    return f'<span class="tile{" me" if rooted else ""}" style="background:{bg};color:{fg}">{code}</span>'

CARDS = {
 1: dict(head='Chicago 5,<br>Milwaukee 4.', date='JUL 4, 2026', venue='Wrigley Field, Chicago', sec='SEC 314',
         photo=lambda ph: crop('wrigley-scoreboard', 1280, 719, .5, .5, .45, ph),
         bug=(('MIL', 4, '#F4C24B', '#241a00', 0), ('CHC', 5, '#2F6BFF', '#fff', 1)),
         memory="Held on in the 9th. You were in the bleachers with Dana and Dad.",
         stats=[('sun', '84°'), ('people', '40,212'), ('clock', '2:51'), ('camera', '63')]),
 2: dict(head='Chicago 3,<br>Cleveland 2.', date='OCT 30, 2016', venue='Wrigley Field, Chicago', sec='SEC 314', big=True, badge='World Series',
         photo=lambda ph: crop('wrigley-night', 1920, 2560, .73, .525, .40, ph),
         bug=(('CLE', 2, '#E8344A', '#fff', 0), ('CHC', 3, '#2F6BFF', '#fff', 1)),
         memory="Down 3-1 in the series. Chapman got eight outs.",
         long="Down 3-1 in the series. Chapman got eight outs, Bryant went deep in the 4th, and you and Dad never sat down.",
         stats=[('sun', '63°'), ('people', '41,711'), ('camera', '63')]),
 3: dict(head='Los Angeles<br>118, Chicago 104.', date='JAN 3, 2025', venue='United Center, Chicago', sec='SEC 105', nophoto=True,
         bug=(('LAL', 118, '#7B4FC4', '#fff', 0), ('CHI', 104, '#E8213F', '#fff', 1)),
         memory=None, stats=[('people', '20,917'), ('clock', '2:21')]),
}

def card(i, ph=420, long=False, top=0):
    c = CARDS[i]
    big = c.get('big')
    if c.get('nophoto'):
        media = '<canvas class="photo" data-style="arena" data-seed="11" data-accent="#e8213f" data-secondary="#7B4FC4" data-board="LAL 118|CHI 104"></canvas>'
    else:
        media = c['photo'](ph)
    badge = f'<div class="badge glass"><i></i>{c["badge"]}</div>' if c.get('badge') else ''
    bug = ''.join(f'<span class="bt">{tile(t, bg, fg, r)}<b class="tnum">{s}</b></span>' for t, s, bg, fg, r in c['bug'])
    if MODE == '07':
        if c['memory']:
            txt = c['long'] if long and c.get('long') else c['memory']
            mem = f'<p class="mem">{txt}</p>'
        else:
            mem = f'<p class="mem prompt">{ic("pencil", 15)}<span>Add a note about this night</span></p>'
        body = f'<div class="txt"><h2>{c["head"]}</h2>{mem}</div>'
        left = f'<div class="d">{c["date"]}</div><div class="v">{c["venue"]}</div>'
    else:
        st = c['stats']
        items = ''.join(f'<span class="st">{ic(n)}<em class="tnum">{v}</em></span>' for n, v in st)
        rib = f'<div class="ribbon{" full" if len(st) == 4 else ""}">{items}</div>' if st else ''
        body = f'<div class="txt"><h2>{c["head"]}</h2></div>{rib}'
        left = f'<div class="d">{c["date"]}</div><div class="v sec">{c["sec"]}</div>'
    return f'''<div class="card{' big' if big else ''}" style="top:{top}px;height:{ph+92}px">
  <div class="photo" style="height:{ph}px">{media}<div class="scrim"></div>{badge}{body}</div>
  <div class="stub" style="top:{ph}px"><div class="perf"></div><div class="l">{left}</div><div class="bug">{bug}</div></div>
  <div class="frame"></div></div>'''

CSS = '''
:root{--trophy:#e6cd96}
body.phone{background:#050506}
.card{position:absolute;left:16px;width:361px;border-radius:22px;overflow:hidden;background:#181a23}
.card.big .frame{position:absolute;inset:0;border-radius:22px;border:1.5px solid var(--trophy);box-shadow:inset 0 0 0 1px rgba(230,205,150,.25);pointer-events:none;z-index:5}
.photo{position:relative;overflow:hidden;background:#0b0d10}
.scrim{position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,6,.28) 0%,rgba(5,5,6,0) 22%,rgba(5,5,6,.35) 48%,rgba(5,5,6,.9) 100%)}
.txt{position:absolute;left:20px;right:20px;bottom:18px}
h2{font:800 54px/.92 var(--f-cond);text-transform:uppercase;letter-spacing:-.5px;white-space:nowrap;color:#fff;text-shadow:0 2px 18px rgba(0,0,0,.45)}
.badge{position:absolute;left:16px;top:16px;height:28px;padding:0 12px 0 10px;border-radius:14px;display:flex;align-items:center;gap:7px;font:700 11px/1 var(--f-ui);letter-spacing:1.6px;text-transform:uppercase;color:var(--trophy);border-color:rgba(230,205,150,.45)}
.badge i{width:6px;height:6px;border-radius:3px;background:var(--trophy)}
.stub{position:absolute;left:0;right:0;height:92px;background:#181a23;padding:0 20px;display:flex;align-items:center;justify-content:space-between;
 -webkit-mask:radial-gradient(circle at 0 0,#0000 10px,#000 10.5px) left top/51% 100% no-repeat,radial-gradient(circle at 100% 0,#0000 10px,#000 10.5px) right top/51% 100% no-repeat}
.perf{position:absolute;left:14px;right:14px;top:0;border-top:1.5px dashed rgba(255,255,255,.16)}
.d{font:700 18px/1 var(--f-ui);letter-spacing:-.3px;color:#fff;font-variant-numeric:tabular-nums}
.v{font:500 12px/1 var(--f-ui);color:var(--text-3);margin-top:7px;letter-spacing:.1px}
.v.sec{font-weight:700;letter-spacing:1.4px;color:var(--text-2);font-size:11px}
.bug{display:flex;align-items:center;gap:12px}
.bt{display:flex;align-items:center;gap:7px}
.bt b{font:800 19px/1 var(--f-ui);color:#fff}
.tile{display:inline-grid;place-items:center;height:30px;padding:0 9px;min-width:40px;border-radius:9px;font:900 17px/1 var(--f-cond);letter-spacing:.6px;opacity:.78}
.tile.me{opacity:1;box-shadow:0 0 0 1.5px #181a23,0 0 0 3px var(--signal)}
/* 07 */
.mem{margin-top:12px;font:italic 400 19px/1.22 var(--f-serif);color:rgba(245,241,234,.82);display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;text-wrap:pretty}
.mem.prompt{display:flex;align-items:center;gap:8px;color:var(--signal);opacity:.92;font-size:19px}
.mem.prompt span{border-bottom:1px dashed rgba(255,181,71,.55);padding-bottom:1px}
/* 08 */
.ribbon{position:absolute;left:0;right:0;bottom:0;height:38px;padding:0 20px;display:flex;align-items:center;gap:20px;
 background:rgba(12,13,17,.46);backdrop-filter:blur(18px) saturate(1.3);-webkit-backdrop-filter:blur(18px) saturate(1.3);border-top:.5px solid rgba(255,255,255,.18);color:rgba(245,241,234,.92)}
.ribbon.full{justify-content:space-between;gap:0}
.st{display:flex;align-items:center;gap:6px}
.st svg{opacity:.7;flex:none}
.st em{font:600 12.5px/1 var(--f-ui);font-style:normal;letter-spacing:.1px}
body.m08 .txt{bottom:54px}
.title{position:absolute;left:16px;top:62px;font:900 34px/1 var(--f-cond);letter-spacing:.3px}
.plus{position:absolute;right:18px;top:64px}
.search{position:absolute;left:16px;right:16px;top:108px;height:38px;border-radius:12px;background:#1a1a1f;display:flex;align-items:center;gap:8px;padding:0 10px;color:var(--text-3);font:400 16px/1 var(--f-ui)}
'''

def page(title, inner, extra=''):
    return f'''<!doctype html>
<html><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="{K}kit/kit.css">
<style>{CSS}{extra}</style></head>
<body class="phone m{MODE}">
{inner}
<script src="{K}kit/kit.js"></script>
</body></html>
'''

header = '''<div class="title">TIMELINE</div>
<svg class="plus" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"><path d="M12 3v18M3 12h18"/></svg>
<div class="search"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg>Teams, places, years</div>'''

t = ('Memory line' if MODE == '07' else 'Stat ribbon')
open(os.path.join(HERE, 'v1-main.html'), 'w').write(page(t + ' main', header + card(1, top=164) + card(2, top=164 + 512 + 24)))
PH = 286
open(os.path.join(HERE, 'v2-states.html'), 'w').write(page(t + ' states', card(2, ph=PH, long=True, top=58) + card(3, ph=PH, top=58 + PH + 92 + 14)))
