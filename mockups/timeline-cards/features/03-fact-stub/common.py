# shared helpers for timeline-card mockups (kept inside each feature folder)
P = '../../../photos/'
IMG = {'wrigley-night': (1920, 2560), 'wrigley-night-2': (1920, 2560), 'wrigley-scoreboard': (1280, 719),
       'wrigley-bleachers': (1280, 853), 'wrigley-scoreboard-wide': (1280, 831)}

def bg(photo, w, h, cx, cy, wf):
    iw, ih = IMG[photo]
    W = w / wf; H = W * ih / iw
    x = -(cx * W - w / 2); y = -(cy * H - h / 2)
    x = min(0, max(x, w - W)); y = min(0, max(y, h - H))
    return f"background:url({P}{photo}.jpg) {x:.0f}px {y:.0f}px/{W:.0f}px {H:.0f}px no-repeat"

TEAMS = {
 'CHC': ('#2f6bff', '#fff'), 'MIL': ('#f4c24b', '#1a1405'), 'CLE': ('#0c2340', '#ff5a6e'),
 'LAL': ('#552583', '#fdb927'), 'CHI': ('#e8213f', '#fff')}

def tile(code, big=False):
    b, t = TEAMS[code]
    return f'<span class="tile{" big" if big else ""}" style="background:{b};color:{t}">{code}</span>'

BASE_CSS = """
:root{--trophy:#e6c987;--stub:#171926}
.hdr h1{position:absolute;left:16px;top:56px;font:800 36px/40px var(--f-cond);letter-spacing:.2px;text-transform:uppercase}
.hdr .plus{position:absolute;right:16px;top:60px;width:32px;height:32px;display:grid;place-items:center}
.search{position:absolute;left:16px;right:16px;top:99px;height:36px;border-radius:10px;background:rgba(118,118,128,.24);display:flex;align-items:center;gap:8px;padding:0 10px;color:var(--text-3);font:400 16px var(--f-ui)}
.card{position:absolute;left:16px;width:361px;border-radius:22px}
.card.big{box-shadow:0 0 0 1.5px var(--trophy)}
.clip{border-radius:22px;overflow:hidden;position:relative;background:var(--ink)}
.photo{position:relative;width:100%;overflow:hidden;background:#0c0d12}
.photo canvas,.photo>.ph{position:absolute;inset:0;width:100%;height:100%}
.scrim{position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,6,0) 38%,rgba(5,5,6,.55) 62%,rgba(5,5,6,.94) 100%)}
.scrim.top{background:linear-gradient(180deg,rgba(5,5,6,.45) 0,rgba(5,5,6,0) 22%),linear-gradient(180deg,rgba(5,5,6,0) 38%,rgba(5,5,6,.55) 62%,rgba(5,5,6,.94) 100%)}
.hl{position:absolute;left:24px;right:24px;bottom:22px;font:800 54px/.93 var(--f-cond);text-transform:uppercase;letter-spacing:.2px;color:#fff}
.hl.sm{font-size:54px}
.badge{position:absolute;left:14px;top:14px;height:26px;padding:0 11px;border-radius:13px;display:flex;align-items:center;gap:6px;font:700 11px var(--f-ui);letter-spacing:1.3px;text-transform:uppercase;color:#2a2008;background:linear-gradient(180deg,#f3dba5,#d9b66a)}
.tile{display:inline-grid;place-items:center;height:22px;min-width:34px;padding:0 6px;border-radius:6px;font:800 13px/1 var(--f-cond);letter-spacing:.8px}
.stub{position:relative;background:var(--stub);
 -webkit-mask-image:var(--m);-webkit-mask-composite:source-in;mask-image:var(--m);mask-composite:intersect}
.stub::before{content:"";position:absolute;left:12px;right:12px;top:0;border-top:1.5px dashed rgba(255,255,255,.2)}
.tabs{}
svg.i{width:13px;height:13px;stroke:currentColor;fill:none;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round;flex:none}
"""

def head():
    return """<div class="hdr"><h1>Timeline</h1><div class="plus"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"><path d="M12 4v16M4 12h16"/></svg></div></div>
<div class="search"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg>Teams, places, years</div>"""

def page(title, css, body, extra=''):
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="../../../kit/kit.css">
<style>{BASE_CSS}{css}</style></head>
<body class="phone">
{body}
<script src="../../../kit/kit.js"></script>
</body></html>"""

ICON = {
 'sun': '<svg class="i" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
 'people': '<svg class="i" viewBox="0 0 24 24"><circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.5 2.7-5.5 6-5.5s6 2 6 5.5"/><path d="M16 5.2a3 3 0 0 1 0 5.6M18 14.8c2 .7 3.2 2.4 3.2 5.2"/></svg>',
 'clock': '<svg class="i" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.2 2"/></svg>',
 'roof': '<svg class="i" viewBox="0 0 24 24"><path d="M3 11l9-7 9 7"/><path d="M5.5 10v9.5h13V10"/></svg>',
 'ticket': '<svg class="i" viewBox="0 0 24 24"><path d="M3 8.5V7a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v1.5a3.5 3.5 0 0 0 0 7V17a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-1.5a3.5 3.5 0 0 0 0-7z"/><path d="M14 6.5v11" stroke-dasharray="1.6 2.2"/></svg>',
 'camera': '<svg class="i" viewBox="0 0 24 24"><path d="M4 8.5A1.5 1.5 0 0 1 5.5 7H8l1.4-2h5.2L16 7h2.5A1.5 1.5 0 0 1 20 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5z"/><circle cx="12" cy="13" r="3.4"/></svg>',
 'plus': '<svg class="i" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
}
