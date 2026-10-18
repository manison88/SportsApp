from stub import *
CSS = STUB_CSS + """
.badge{left:auto;right:14px}
.blk{position:absolute;left:22px;right:20px;bottom:20px;display:flex;align-items:flex-end;gap:15px}
.dt{display:flex;flex-direction:column;align-items:flex-start}
.dd{font:800 var(--ds)/.8 var(--f-cond);letter-spacing:-1px;color:#fff;text-shadow:0 2px 18px rgba(0,0,0,.4);font-variant-numeric:tabular-nums}
.big .dd{color:var(--trophy)}
.mm{font:800 21px/1 var(--f-cond);letter-spacing:6px;text-transform:uppercase;color:#fff;margin-top:11px;padding-bottom:9px;border-bottom:1.5px solid var(--signal);align-self:stretch}
.big .mm{border-color:var(--trophy)}
.wk{font:700 10px/1 var(--f-ui);letter-spacing:2px;text-transform:uppercase;color:rgba(255,255,255,.75);margin-top:9px}
.vn{padding:0 0 2px 15px;border-left:1px solid rgba(255,255,255,.28);display:flex;flex-direction:column;gap:7px;text-shadow:0 1px 10px rgba(0,0,0,.6)}
.vn b{font:700 11px/1 var(--f-ui);letter-spacing:2.2px;text-transform:uppercase;color:rgba(255,255,255,.92)}
.vn span{font:600 10px/1 var(--f-ui);letter-spacing:2px;text-transform:uppercase;color:rgba(255,255,255,.6)}
.scrim.top{background:linear-gradient(180deg,rgba(5,5,6,.45) 0,rgba(5,5,6,0) 22%),linear-gradient(180deg,rgba(5,5,6,0) 30%,rgba(5,5,6,.6) 58%,rgba(5,5,6,.94) 100%)}
"""
def card(c, top, ph_h, ds):
    badge = f'<div class="badge">{STAR}{c["badge"]}</div>' if c['big'] else ''
    return f"""<div class="card{' big' if c['big'] else ''}" style="top:{top}px"><div class="clip">
<div class="photo" style="height:{ph_h}px">{photo(c,ph_h)}<div class="scrim top"></div>{badge}
<div class="blk" style="--ds:{ds}px"><div class="dt"><div class="dd">{c['day']}</div><div class="mm">{c['mon']}</div><div class="wk">{c['wk']} · {c['yr']}</div></div>
<div class="vn"><b>{c['venue']}</b><span>{c['city']}</span></div></div></div>{stub(c)}</div></div>"""
v1 = head() + card(BASE['c1'], 157, 420, 104) + card(BASE['c2'], 157+420+100+24, 420, 104)
open('v1-main.html','w').write(page('Date block', CSS, v1))
v2 = card(BASE['c2'], 68, 260, 84) + card(BASE['c3'], 68+260+100+22, 260, 84)
open('v2-states.html','w').write(page('Date block states', CSS, v2))
