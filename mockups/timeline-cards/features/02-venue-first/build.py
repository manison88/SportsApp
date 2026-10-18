from common import *
CSS = '''
.eyebrow-v{position:absolute;z-index:6;left:18px;font:700 11px/1 var(--f-ui);letter-spacing:2.2px;color:rgba(255,255,255,.85);text-shadow:0 1px 10px rgba(0,0,0,.6)}
h2.hl{font-size:50px;line-height:.9;letter-spacing:.1px;left:18px;bottom:16px}
.cells{position:absolute;left:18px;top:0;bottom:0;display:flex;align-items:center}
.cell{padding:0 13px;border-left:1px solid rgba(255,255,255,.1);display:flex;flex-direction:column;gap:6px}
.cell:first-child{padding-left:0;border-left:0}
.cell small{font:700 8.5px/1 var(--f-ui);letter-spacing:1.5px;color:var(--text-3)}
.cell b{font:700 17px/1 var(--f-cond);letter-spacing:.4px;color:var(--text);display:flex;align-items:center;gap:5px;white-space:nowrap}
.cell b svg{width:16px;height:16px;stroke:var(--signal);fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}
.bug{position:absolute;right:16px;top:0;bottom:0;display:flex;flex-direction:column;justify-content:center;gap:6px;border-left:1px solid rgba(255,255,255,.1);padding-left:12px}
.bug .r{display:flex;align-items:center;justify-content:space-between;gap:8px;font:800 21px/1 var(--f-cond);min-width:74px}
.bug .lo{color:var(--text-2)}
'''
def card(c, top, ph_h):
    (a, asc), (h, hsc) = c['away'], c['home']
    def row(t, sc, win):
        return f'<div class="r">{tile(t["code"], t["bg"], t["fg"], ring=False, w=34, h=22, fs=13)}<span class="tnum {"" if win else "lo"}">{sc}</span></div>'
    badge = f'<div class="badge" style="right:14px;top:14px"><i></i>{c["big"]}</div>' if c['big'] else ''
    hl_bottom = 16
    return f'''
<div class="card" style="top:{top}px">
  <div class="ph-wrap" style="height:{ph_h}px">
    {photo_html(c, 361, ph_h)}
    <div class="scrim"></div>
    <div class="chip" style="left:14px;top:14px">{c['day_chip']}</div>
    {badge}
    <div class="eyebrow-v" style="bottom:{{eb}}px">{c['venue']}</div>
    <h2 class="hl">{c['headline']}</h2>
  </div>
  <div class="stub">
    <i class="notch l"></i><i class="notch r"></i>
    <div class="cells">
      <div class="cell"><small>{c['time_label']}</small><b>{c['time']}</b></div>
      <div class="cell"><small>SECTION</small><b>{c['section'].replace('SEC ','')}</b></div>
      <div class="cell"><small>WEATHER</small><b>{ICON[c['wx_icon']]}{c['wx']}</b></div>
    </div>
    <div class="bug">{row(a, asc, asc > hsc)}{row(h, hsc, hsc > asc)}</div>
  </div>
  {'<div class="keyline"></div>' if c['big'] else ''}
</div>'''.replace('{eb}', str(16 + 54*2*0.9 + 12 if False else 0))

def build(c, top, ph_h):
    lines = c['headline'].count('<br>') + 1
    eb = 16 + round(50*.9*lines) + 12
    return card(c, top, ph_h).replace('bottom:0px', f'bottom:{eb}px')

c1, c2, c3 = CARDS
v1 = HEADER + build(c1, 164, 420) + build(c2, 700, 420)
open('v1-main.html', 'w').write(page('Venue First', CSS, v1))
v2 = build(c2, 62, 260) + build(c3, 434, 260) + '<div class="fade"></div>'
open('v2-states.html', 'w').write(page('Venue First States', CSS, v2))
