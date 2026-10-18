from common import *
STUB_CSS = """
.stub{height:100px;--m:radial-gradient(circle at 0 0,transparent 8px,#000 8.5px),radial-gradient(circle at 100% 0,transparent 8px,#000 8.5px),radial-gradient(circle at calc(100% - 96px) 0,transparent 7px,#000 7.5px),radial-gradient(circle at calc(100% - 96px) 100%,transparent 7px,#000 7.5px)}
.main{position:absolute;left:0;top:0;bottom:0;right:96px;padding:2px 12px 0 18px;display:flex;flex-direction:column;justify-content:center}
.r1{display:flex;justify-content:space-between;align-items:baseline}
.date{font:700 16px/1 var(--f-tight);letter-spacing:.2px;text-transform:uppercase;color:var(--text)}
.date small{font:600 9.5px/1 var(--f-ui);letter-spacing:1.3px;color:var(--text-3);margin-left:7px}
.seat{white-space:nowrap;font:600 10.5px/1 var(--f-ui);letter-spacing:1.1px;text-transform:uppercase;color:var(--text-2)}
.seat b{color:var(--text);font-weight:700}
.r2{margin-top:13px;padding-top:11px;border-top:1px solid var(--line);display:flex;align-items:center}
.f{display:flex;align-items:center;gap:5px;font:600 11.5px/1 var(--f-ui);font-variant-numeric:tabular-nums;color:var(--text-2);white-space:nowrap;padding:0 9px;border-left:1px solid var(--line-2);height:14px}
.f:first-child{padding-left:0;border-left:0}
.f.tk{color:var(--signal);margin-left:auto;padding-right:0}
.f svg{color:var(--text-3)} .f.tk svg{color:var(--signal)}
.perf{position:absolute;right:96px;top:12px;bottom:12px;border-left:1.5px dashed rgba(255,255,255,.2)}
.tear{position:absolute;right:0;top:0;bottom:0;width:96px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;padding-top:2px}
.fin{font:700 9px/1 var(--f-ui);letter-spacing:1.6px;color:var(--text-3);margin-bottom:3px}
.fin b{color:var(--signal)} .fin b.l{color:var(--text-2)}
.row{display:flex;align-items:center;gap:6px;width:76px;justify-content:space-between}
.sc{font:800 21px/1 var(--f-cond);font-variant-numeric:tabular-nums;color:var(--text-2);text-align:right}
.row.me .tile{box-shadow:0 0 0 1.5px var(--stub),0 0 0 3px var(--signal)}
.row.me .sc{color:#fff}
"""
def bug(away, as_, home, hs, me, res):
    r = lambda c, s: f'<div class="row{" me" if c==me else ""}">{tile(c)}<span class="sc tnum">{s}</span></div>'
    return f'<div class="tear"><div class="fin">FINAL · <b class="{"l" if res=="L" else ""}">{res}</b></div>{r(away,as_)}{r(home,hs)}</div>'
def stub(c):
    f = f'<span class="f">{ICON["sun"]}{c["wx"]}</span>' if c['wx'] else f'<span class="f">{ICON["roof"]}Indoors</span>'
    f += f'<span class="f">{ICON["people"]}{c["att"]}</span><span class="f">{ICON["clock"]}{c["len"]}</span>'
    if c['tk']: f += f'<span class="f tk">{ICON["ticket"]}</span>'
    return f'<div class="stub"><div class="main"><div class="r1"><span class="date">{c["time"]}</span><span class="seat">{c["seat"]}</span></div><div class="r2">{f}</div></div><div class="perf"></div>{bug(*c["bug"])}</div>'
def photo(c, ph_h):
    if c['photo'] == 'cc': return '<canvas class="photo" data-style="arena" data-seed="11" data-accent="#e8213f" data-secondary="#552583"></canvas>'
    if c['photo'] == 'score': return f'<img class="ph graded" src="{P}wrigley-scoreboard.jpg" style="object-position:35% 50%">'
    return f'<div style="position:absolute;inset:0;{bg("wrigley-night",361,ph_h,.70,.70,.40)}"></div>'
BASE = dict(
 c1=dict(photo='score', time='1:20 PM', tlabel='FIRST PITCH', seat='<b>Sec 314</b> · Row 8', wx='84°F', att='41,203', len='2h 58m', tk=True, bug=('MIL',4,'CHC',5,'CHC','W'),
   venue='Wrigley Field', city='Chicago', day='4', mon='Jul', wk='Sat', yr='2026', chip='Sat · Jul 4, 2026', occ='Independence<br>Day Game', big=False),
 c2=dict(photo='night', time='7:08 PM', tlabel='FIRST PITCH', seat='<b>Sec 314</b> · Row 6', wx='63°F', att='41,711', len='3h 21m', tk=True, bug=('CLE',2,'CHC',3,'CHC','W'),
   venue='Wrigley Field', city='Chicago', day='30', mon='Oct', wk='Sun', yr='2016', chip='Sun · Oct 30, 2016', occ='World Series<br>· Game 5', big=True, badge='World Series', badge14='Down 3–1'),
 c3=dict(photo='cc', time='7:00 PM', tlabel='TIP-OFF', seat='<b>Sec 105</b> · Row 14', wx=None, att='20,589', len='2h 21m', tk=False, bug=('LAL',118,'CHI',104,'CHI','L'),
   venue='United Center', city='Chicago', day='3', mon='Jan', wk='Fri', yr='2025', chip='Fri · Jan 3, 2025', occ='Home Game 21', big=False, quiet=True),
)
STAR = '<svg width="11" height="11" viewBox="0 0 24 24" fill="#2a2008"><path d="M12 2l2.9 6.6 7.1.6-5.4 4.7 1.6 7L12 17.3 5.8 20.9l1.6-7L2 9.2l7.1-.6z"/></svg>'
