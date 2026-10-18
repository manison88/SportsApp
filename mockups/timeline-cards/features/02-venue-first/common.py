# shared helpers for the timeline-card mockups (copied into each tweak folder)
RATIO = {'wrigley-scoreboard': 719/1280, 'wrigley-night': 2560/1920}

def crop(photo, w, h, cx, cy, frac):
    """Return inline style placing a crop window (cx,cy centre, frac = share of image width) in a w x h box."""
    r = RATIO[photo]
    frac = min(frac, w * r / h)          # make sure it covers
    W = w / frac; H = W * r
    left = min(0, max(-(W - w), -(cx * W - w / 2)))
    top = min(0, max(-(H - h), -(cy * H - h / 2)))
    return f"position:absolute;left:{left:.1f}px;top:{top:.1f}px;width:{W:.1f}px;height:{H:.1f}px;max-width:none"

def tile(code, bg, fg='#fff', ring=False, w=40, h=24, fs=15):
    ring_css = 'box-shadow:0 0 0 1.5px rgba(255,255,255,.9);' if ring else ''
    return (f'<span class="tile" style="background:{bg};color:{fg};width:{w}px;height:{h}px;font-size:{fs}px;{ring_css}">{code}</span>')

CHC = dict(code='CHC', bg='#2f6bff', fg='#fff')
MIL = dict(code='MIL', bg='#f4c24b', fg='#1a1405')
CLE = dict(code='CLE', bg='#e8344a', fg='#fff')
CHI = dict(code='CHI', bg='#e8213f', fg='#fff')
LAL = dict(code='LAL', bg='#7a4fd0', fg='#fff')

CARDS = [
 dict(id=1, photo='wrigley-scoreboard', crop=(0.55, 0.5, 0.45), res='W',
      headline='CHICAGO 5,<br>MILWAUKEE 4.', date_chip='JUL 4, 2026', day_chip='SAT · JUL 4',
      venue='WRIGLEY FIELD · CHICAGO', section='SEC 314', time='1:20 PM', time_label='FIRST PITCH',
      wx_icon='sun', wx='84°F', wx_label='Sunny', away=(MIL, 4), home=(CHC, 5), rooted='home',
      stripe='#2f6bff', big=None,
      lucky_num='12–5', lucky='Chicago is 12–5 at Wrigley with you'),
 dict(id=2, photo='wrigley-night', crop=(0.42, 0.7, 0.42), res='W',
      headline='CHICAGO 3,<br>CLEVELAND 2.', date_chip='OCT 30, 2016', day_chip='SUN · OCT 30',
      venue='WRIGLEY FIELD · CHICAGO', section='SEC 314', time='7:08 PM', time_label='FIRST PITCH',
      wx_icon='moon', wx='63°F', wx_label='Clear', away=(CLE, 2), home=(CHC, 3), rooted='home',
      stripe='#2f6bff', big='WORLD SERIES',
      lucky_num='3–1', lucky='Game 5, down 3–1. You saw the comeback start'),
 dict(id=3, photo=None, res='L',
      headline='LOS ANGELES 118,<br>CHICAGO 104.', date_chip='JAN 3, 2025', day_chip='FRI · JAN 3',
      venue='UNITED CENTER · CHICAGO', section='SEC 105', time='7:30 PM', time_label='TIP-OFF',
      wx_icon='roof', wx='Indoors', wx_label='72°F', away=(LAL, 118), home=(CHI, 104), rooted='home',
      stripe='#7d8798', big=None,
      lucky_num='2–3', lucky='Chicago is 2–3 at United Center with you'),
]

ICON = {
 'sun': '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4.2"/><path d="M12 2.5v2.4M12 19.1v2.4M2.5 12h2.4M19.1 12h2.4M5.3 5.3l1.7 1.7M17 17l1.7 1.7M5.3 18.7L7 17M17 7l1.7-1.7"/></svg>',
 'moon': '<svg viewBox="0 0 24 24"><path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5z"/></svg>',
 'roof': '<svg viewBox="0 0 24 24"><path d="M3 11l9-7 9 7M5.5 9.5V20h13V9.5M10 20v-5h4v5"/></svg>',
}

BASE_CSS = '''
:root{--trophy:#e6c887;--stub:#171a26;}
body.phone{background:var(--ink)}
.hdr{position:absolute;left:16px;right:16px;top:58px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{font:800 34px/1 var(--f-cond);letter-spacing:.2px}
.hdr svg{width:22px;height:22px;stroke:#fff;stroke-width:2.4;fill:none;stroke-linecap:round}
.search{position:absolute;left:16px;right:16px;top:104px;height:38px;border-radius:11px;background:#1b1c22;display:flex;align-items:center;gap:8px;padding:0 12px;color:var(--text-3);font:400 16px/1 var(--f-ui)}
.search svg{width:16px;height:16px;stroke:var(--text-3);stroke-width:2.2;fill:none;stroke-linecap:round}
.fade{position:absolute;left:0;right:0;top:0;height:60px;z-index:50;background:linear-gradient(var(--ink) 40%,transparent);pointer-events:none}
.card{position:absolute;left:16px;width:361px;border-radius:22px;overflow:hidden;background:var(--stub)}
.ph-wrap{position:relative;width:100%;overflow:hidden;background:#0b0c10}
.ph-wrap img{display:block}
.scrim{position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,8,.38) 0%,rgba(5,5,8,0) 22%,rgba(5,5,8,0) 42%,rgba(8,9,14,.72) 78%,var(--stub) 100%)}
.tint{position:absolute;inset:0;background:linear-gradient(160deg,rgba(125,135,152,.28),rgba(20,24,34,.55))}
.stub{position:relative;height:92px;background:var(--stub)}
.stub::before{content:"";position:absolute;left:16px;right:16px;top:0;border-top:1.5px dashed rgba(255,255,255,.2)}
.notch{position:absolute;top:-8px;width:16px;height:16px;border-radius:8px;background:var(--ink);z-index:5}
.notch.l{left:-8px}.notch.r{right:-8px}
.tile{display:inline-grid;place-items:center;border-radius:7px;font-family:var(--f-cond);font-weight:800;letter-spacing:.3px;line-height:1}
.chip{position:absolute;z-index:6;height:26px;padding:0 10px;border-radius:13px;display:flex;align-items:center;font:700 11px/1 var(--f-ui);letter-spacing:1.3px;color:#fff;background:rgba(24,24,28,.55);backdrop-filter:blur(18px) saturate(1.4);-webkit-backdrop-filter:blur(18px) saturate(1.4);border:.5px solid rgba(255,255,255,.2)}
.badge{position:absolute;z-index:6;height:26px;padding:0 10px;border-radius:13px;display:flex;align-items:center;gap:6px;font:800 10.5px/1 var(--f-ui);letter-spacing:1.4px;color:#1d1608;background:linear-gradient(135deg,#f3dba3,#d9b568)}
.badge i{width:6px;height:6px;border-radius:3px;background:#1d1608;display:block;transform:rotate(45deg)}
.keyline{position:absolute;inset:0;border-radius:22px;border:1.5px solid var(--trophy);pointer-events:none;z-index:20;box-shadow:inset 0 0 18px rgba(230,200,135,.14)}
h2.hl{position:absolute;z-index:6;left:18px;right:18px;font-family:var(--f-cond);font-weight:800;text-transform:uppercase;color:#fff;text-shadow:0 2px 18px rgba(0,0,0,.45)}
'''

def page(title, css, body, extra_attrs=''):
    return f'''<!doctype html>
<html><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="../../../kit/kit.css">
<style>{BASE_CSS}{css}</style></head>
<body class="phone"{extra_attrs}>
{body}
<script src="../../../kit/kit.js"></script>
</body></html>'''

HEADER = '''<div class="hdr"><h1>TIMELINE</h1><svg viewBox="0 0 24 24"><path d="M12 4v16M4 12h16"/></svg></div>
<div class="search"><svg viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5L21 21"/></svg>Teams, places, years</div>'''

def photo_html(c, w, h):
    if c['photo']:
        cx, cy, fr = c['crop']
        return f'<img class="ph graded" src="../../../photos/{c["photo"]}.jpg" style="{crop(c["photo"], w, h, cx, cy, fr)}">'
    return ('<canvas class="photo" data-style="arena" data-seed="11" data-accent="#e8213f" data-secondary="#7a4fd0"></canvas><div class="tint"></div>')
