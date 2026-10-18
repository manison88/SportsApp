from common import *
from stubcss import *
CSS = STUB + CHIP + """
.scrim.lt{background:linear-gradient(180deg,rgba(5,5,6,.34) 0,rgba(5,5,6,0) 18%),linear-gradient(180deg,rgba(5,5,6,0) 74%,rgba(5,5,6,.5) 100%)}
.vl{position:absolute;left:16px;bottom:14px;font:600 12px/1 var(--f-ui);letter-spacing:.3px;color:rgba(255,255,255,.92);text-shadow:0 1px 8px rgba(0,0,0,.55)}
.vl i{font-style:normal;color:rgba(255,255,255,.6)}
.mu{font:700 16px/1 var(--f-tight);letter-spacing:.2px;color:var(--text);white-space:nowrap}
.mu small{font:600 10.5px/1 var(--f-ui);letter-spacing:1.1px;text-transform:uppercase;color:var(--text-3);margin-right:6px}
"""
def card(c, top, ph_h):
    facts = f'<span class="f">{ICON["sun"]}{c["wx"]}</span>' if c['wx'] else f'<span class="f">{ICON["roof"]}Indoors</span>'
    facts += f'<span class="f">{ICON["people"]}{c["att"]}</span><span class="f">{ICON["clock"]}{c["len"]}</span>'
    if c['tk']: facts += f'<span class="f tk">{ICON["ticket"]}</span>'
    badge = f'<div class="badge"><svg width="11" height="11" viewBox="0 0 24 24" fill="#2a2008"><path d="M12 2l2.9 6.6 7.1.6-5.4 4.7 1.6 7L12 17.3 5.8 20.9l1.6-7L2 9.2l7.1-.6z"/></svg>{c["badge"]}</div>' if c.get('badge') else ''
    return f"""<div class="card{' big' if c.get('badge') else ''}" style="top:{top}px"><div class="clip">
<div class="photo" style="height:{ph_h}px">{c['photo'](ph_h)}<div class="scrim lt"></div><div class="chip">{c['chip']}</div>{badge}<div class="vl">{c['venue']} <i>·</i> {c['city']}</div></div>
<div class="stub"><div class="main"><div class="r1"><span class="mu"><small>{c['pre']}</small>{c['opp']}</span><span class="seat">{c['seat']}</span></div><div class="r2">{facts}</div></div><div class="perf"></div>
{bug(*c['bug'])}</div></div></div>"""
def img(photo, w, h, cx, cy, wf):
    return lambda ph: f'<div style="position:absolute;inset:0;{bg(photo,361,ph,cx,cy,wf)}"></div>'
CARDS = {
 1: dict(venue='Wrigley Field', city='Chicago', chip='SAT · JUL 4', pre='vs', opp='Milwaukee', seat='<b>Sec 314</b> · Row 8', wx='84°F', att='41,203', len='2h 58m', tk=True,
         photo=lambda ph: f'<img class="ph graded" src="{P}wrigley-scoreboard.jpg" style="object-position:35% 50%">', bug=('MIL',4,'CHC',5,'CHC','W')),
 2: dict(venue='Wrigley Field', city='Chicago', chip='SUN · OCT 30', pre='vs', opp='Cleveland', seat='<b>Sec 314</b> · Row 6', wx='63°F', att='41,711', len='3h 21m', tk=True, badge='World Series',
         photo=img('wrigley-night',361,0,.70,.70,.40), bug=('CLE',2,'CHC',3,'CHC','W')),
 3: dict(venue='United Center', city='Chicago', chip='FRI · JAN 3', pre='vs', opp='Los Angeles', seat='<b>Sec 105</b> · Row 14', wx=None, att='20,589', len='2h 21m', tk=False,
         photo=lambda ph: '<canvas class="photo" data-style="arena" data-seed="11" data-accent="#e8213f" data-secondary="#552583" data-board="LAL 118|CHI 104"></canvas>', bug=('LAL',118,'CHI',104,'CHI','L')),
}
H=360
v1 = head() + card(CARDS[1], 157, H) + card(CARDS[2], 157+H+100+24, H)
open('v1-main.html','w').write(page('Clean photo', CSS, v1))
v2 = card(CARDS[2], 68, 270) + card(CARDS[3], 68+270+100+22, 270)
open('v2-states.html','w').write(page('Clean photo states', CSS, v2))
