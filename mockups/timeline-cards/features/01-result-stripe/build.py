from common import *
RES = {'W': 'WIN', 'L': 'LOSS', 'D': 'DRAW'}
CSS = '''
.card::before{content:"";position:absolute;left:0;top:0;bottom:0;width:5px;z-index:8;background:var(--sc)}
.tab{position:absolute;z-index:7;left:0;top:14px;width:58px;height:48px;border-radius:0 12px 12px 0;background:var(--sc);display:flex;flex-direction:column;align-items:center;justify-content:center;padding-left:5px;color:#fff;box-shadow:0 4px 14px rgba(0,0,0,.35)}
.tab b{font:800 27px/.9 var(--f-cond)}
.tab span{font:800 8.5px/1 var(--f-ui);letter-spacing:1.6px;margin-top:3px;padding-left:1.6px}
.card.loss .tab{color:#eef1f6;background:linear-gradient(160deg,#8c95a6,#6b7486)}
.card.loss::before{background:#7d8798}
h2.hl{font-size:44px;line-height:.92;letter-spacing:.1px;left:22px;bottom:14px}
.stub .lucky{position:absolute;left:22px;top:0;bottom:0;width:172px;display:flex;flex-direction:column;justify-content:center;gap:5px}
.lucky .eb{display:flex;align-items:center;gap:6px;font:700 9.5px/1 var(--f-ui);letter-spacing:1.6px;color:var(--signal)}
.lucky .eb svg{width:12px;height:12px;fill:var(--signal)}
.lucky p{font:600 12.5px/1.28 var(--f-ui);color:var(--text);letter-spacing:-.1px}
.lucky p em{font-style:normal;font-family:var(--f-cond);font-weight:800;font-size:17px;letter-spacing:.2px;color:var(--signal-soft);margin-right:1px}
.bug{position:absolute;right:16px;top:0;bottom:0;display:flex;align-items:center;gap:5px;font:800 21px/1 var(--f-cond)}
.bug .sc{min-width:14px}
.bug .lo{color:var(--text-2)}
.bug .gap{width:4px}
'''
STAR = '<svg viewBox="0 0 24 24"><path d="M12 2l2.9 6.6 7.1.7-5.4 4.8 1.6 7L12 17.3 5.8 21l1.6-7L2 9.3l7.1-.7z"/></svg>'

def card(c, top, ph_h):
    loss = c['res'] == 'L'
    (a, asc), (h, hsc) = c['away'], c['home']
    arooted = c['rooted'] == 'away'
    def side(t, sc, rooted, win):
        return (tile(t['code'], t['bg'], t['fg'], ring=rooted, w=34, h=22, fs=13) + f'<span class="sc tnum {"" if win else "lo"}" style="color:{"#fff" if win else ""}">{sc}</span>')
    bug = (side(a, asc, arooted, asc > hsc) + '<span class="gap"></span>' + side(h, hsc, not arooted, hsc > asc))
    badge = f'<div class="badge" style="left:70px;top:25px"><i></i>{c["big"]}</div>' if c['big'] else ''
    return f'''
<div class="card{' loss' if loss else ''}" style="top:{top}px;--sc:{c['stripe']}">
  <div class="ph-wrap" style="height:{ph_h}px">
    {photo_html(c, 361, ph_h)}
    <div class="scrim"></div>
    <div class="tab"><b>{c['res']}</b><span>{RES[c['res']]}</span></div>
    {badge}
    <div class="chip" style="right:14px;top:25px">{c['date_chip']}</div>
    <h2 class="hl">{c['headline']}</h2>
  </div>
  <div class="stub">
    <i class="notch l"></i><i class="notch r"></i>
    <div class="lucky"><div class="eb">{STAR}LUCKY CHARM</div><p>{c['lucky']}</p></div>
    <div class="bug">{bug}</div>
  </div>
  {'<div class="keyline"></div>' if c['big'] else ''}
</div>'''

c1, c2, c3 = CARDS
v1 = HEADER + card(c1, 164, 420) + card(c2, 700, 420)
open('v1-main.html', 'w').write(page('Result Stripe', CSS, v1))
v2 = card(c2, 62, 260) + card(c3, 434, 260) + '<div class="fade"></div>'
open('v2-states.html', 'w').write(page('Result Stripe States', CSS, v2))
