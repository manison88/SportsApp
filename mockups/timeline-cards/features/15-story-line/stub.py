from common import *
STUB_CSS = open(__file__.replace('stub.py','stub.css')).read() if False else """
.stub{height:100px;--m:radial-gradient(circle at 0 0,transparent 8px,#000 8.5px),radial-gradient(circle at 100% 0,transparent 8px,#000 8.5px),radial-gradient(circle at calc(100% - 96px) 0,transparent 7px,#000 7.5px),radial-gradient(circle at calc(100% - 96px) 100%,transparent 7px,#000 7.5px)}
.main{position:absolute;left:0;top:0;bottom:0;right:96px;padding:2px 12px 0 18px;display:flex;flex-direction:column;justify-content:center}
.r1{display:flex;justify-content:space-between;align-items:baseline}
.date{font:700 16px/1 var(--f-tight);letter-spacing:.2px;text-transform:uppercase;color:var(--text)}
.seat{font:600 10.5px/1 var(--f-ui);letter-spacing:1.1px;text-transform:uppercase;color:var(--text-2)}
.seat b{color:var(--text);font-weight:700}
.r2{margin-top:13px;padding-top:11px;border-top:1px solid var(--line);display:flex;align-items:center}
.f{display:flex;align-items:center;gap:5px;font:600 11.5px/1 var(--f-ui);font-variant-numeric:tabular-nums;color:var(--text-2);white-space:nowrap;padding:0 9px;border-left:1px solid var(--line-2);height:14px}
.f:first-child{padding-left:0;border-left:0}
.f.tk{color:var(--signal);margin-left:auto;padding-right:0}
.f svg{color:var(--text-3)}
.f.tk svg{color:var(--signal)}
.perf{position:absolute;right:96px;top:12px;bottom:12px;border-left:1.5px dashed rgba(255,255,255,.2)}
.tear{position:absolute;right:0;top:0;bottom:0;width:96px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;padding-top:2px}
.fin{font:700 9px/1 var(--f-ui);letter-spacing:1.6px;color:var(--text-3);margin-bottom:3px}
.fin b{color:var(--signal)} .fin b.l{color:var(--text-2)}
.row{display:flex;align-items:center;gap:6px;width:76px;justify-content:space-between}
.sc{font:800 21px/1 var(--f-cond);font-variant-numeric:tabular-nums;color:var(--text-2);text-align:right}
.row.me .tile{box-shadow:0 0 0 1.5px var(--stub),0 0 0 3px var(--signal)}
.row.me .sc{color:#fff}
.chip{position:absolute;z-index:6;left:14px;top:14px;height:26px;padding:0 10px;border-radius:13px;display:flex;align-items:center;font:700 11px/1 var(--f-ui);letter-spacing:1.3px;color:#fff;background:rgba(24,24,28,.55);backdrop-filter:blur(18px) saturate(1.4);-webkit-backdrop-filter:blur(18px) saturate(1.4);border:.5px solid rgba(255,255,255,.2)}
.badge{left:auto;right:14px}
.eb{position:absolute;z-index:6;left:20px;font:700 11px/1 var(--f-ui);letter-spacing:2.2px;color:rgba(255,255,255,.85);text-shadow:0 1px 10px rgba(0,0,0,.6);text-transform:uppercase}
.scrim.top{background:linear-gradient(180deg,rgba(5,5,6,.45) 0,rgba(5,5,6,0) 22%),linear-gradient(180deg,rgba(5,5,6,0) 40%,rgba(5,5,6,.6) 66%,rgba(5,5,6,.95) 100%)}
"""
def bug(away, as_, home, hs, me, res):
    r = lambda c, s: f'<div class="row{" me" if c==me else ""}">{tile(c)}<span class="sc tnum">{s}</span></div>'
    return f'<div class="tear"><div class="fin">FINAL · <b class="{"l" if res=="L" else ""}">{res}</b></div>{r(away,as_)}{r(home,hs)}</div>'
def stub(c):
    facts = f'<span class="f">{ICON["sun"]}{c["wx"]}</span>' if c['wx'] else f'<span class="f">{ICON["roof"]}Indoors</span>'
    facts += f'<span class="f">{ICON["people"]}{c["att"]}</span><span class="f">{ICON["clock"]}{c["len"]}</span>'
    if c['tk']: facts += f'<span class="f tk">{ICON["ticket"]}</span>'
    return f"""<div class="stub"><div class="main"><div class="r1"><span class="date">{c['date']}</span><span class="seat">{c['seat']}</span></div><div class="r2">{facts}</div></div><div class="perf"></div>{bug(*c['bug'])}</div>"""
def img(photo, w, h, cx, cy, wf):
    return lambda ph: f'<div style="position:absolute;inset:0;{bg(photo,361,ph,cx,cy,wf)}"></div>'
def shell(c, top, ph_h, overlay):
    badge = f'<div class="badge"><svg width="11" height="11" viewBox="0 0 24 24" fill="#2a2008"><path d="M12 2l2.9 6.6 7.1.6-5.4 4.7 1.6 7L12 17.3 5.8 20.9l1.6-7L2 9.2l7.1-.6z"/></svg>{c["badge"]}</div>' if c.get('badge') else ''
    return f"""<div class="card{' big' if c.get('badge') else ''}" style="top:{top}px"><div class="clip">
<div class="photo" style="height:{ph_h}px">{c['photo'](ph_h)}<div class="scrim top"></div><div class="chip">{c['chip']}</div>{badge}{overlay}</div>
{stub(c)}</div></div>"""
BASE = {
 1: dict(date='Jul 4, 2026', chip='SAT · JUL 4', venue='Wrigley Field', seat='<b>Sec 314</b> · Row 8', wx='84°F', att='41,203', len='2h 58m', tk=True,
         photo=lambda ph: f'<img class="ph graded" src="{P}wrigley-scoreboard.jpg" style="object-position:35% 50%">', bug=('MIL',4,'CHC',5,'CHC','W')),
 2: dict(date='Oct 30, 2016', chip='SUN · OCT 30', venue='Wrigley Field', seat='<b>Sec 314</b> · Row 6', wx='63°F', att='41,711', len='3h 21m', tk=True, badge='World Series',
         photo=img('wrigley-night',361,0,.70,.70,.40), bug=('CLE',2,'CHC',3,'CHC','W')),
 3: dict(date='Jan 3, 2025', chip='FRI · JAN 3', venue='United Center', seat='<b>Sec 105</b> · Row 14', wx=None, att='20,589', len='2h 21m', tk=False,
         photo=lambda ph: '<canvas class="photo" data-style="arena" data-seed="11" data-accent="#e8213f" data-secondary="#552583" data-board="LAL 118|CHI 104"></canvas>', bug=('LAL',118,'CHI',104,'CHI','L')),
}
