from stub import *
CSS = STUB_CSS + """
.badge{left:auto;right:14px}
.chip{position:absolute;left:14px;top:14px;height:26px;padding:0 11px;border-radius:13px;display:flex;align-items:center;font:700 11px/1 var(--f-ui);letter-spacing:1.3px;text-transform:uppercase;color:#fff;background:rgba(24,24,28,.55);backdrop-filter:blur(18px) saturate(1.4);-webkit-backdrop-filter:blur(18px) saturate(1.4);border:.5px solid rgba(255,255,255,.2)}
.tb{position:absolute;left:22px;right:20px;bottom:22px}
.ey{font:700 11px/1 var(--f-ui);letter-spacing:2.2px;text-transform:uppercase;color:rgba(255,255,255,.85);text-shadow:0 1px 10px rgba(0,0,0,.6);margin-bottom:11px;display:flex;align-items:center;gap:8px}
.ey i{width:16px;height:1.5px;background:var(--signal);display:block}
.big .ey i{background:var(--trophy)}
.tt{font:800 52px/.92 var(--f-cond);text-transform:uppercase;letter-spacing:.2px;color:#fff;text-shadow:0 2px 18px rgba(0,0,0,.45)}
.big .tt{color:var(--trophy);text-shadow:0 2px 22px rgba(230,201,135,.25),0 2px 18px rgba(0,0,0,.5)}
.big .tt em{display:block;font-style:normal;color:#fff}
.tt.q{font:600 28px/1 var(--f-cond);letter-spacing:2.6px;color:rgba(255,255,255,.82)}
.big .ey{color:var(--trophy)}
.scrim.top{background:linear-gradient(180deg,rgba(5,5,6,.45) 0,rgba(5,5,6,0) 22%),linear-gradient(180deg,rgba(5,5,6,0) 32%,rgba(5,5,6,.6) 60%,rgba(5,5,6,.94) 100%)}
"""
def card(c, top, ph_h, fs):
    badge = f'<div class="badge">{STAR}{c["badge14"]}</div>' if c['big'] else ''
    if c['big']:
        t = '<div class="tt">World Series<em>Game 5</em></div>'
        t = t.replace('<em>','<em style="color:var(--trophy)">') if False else '<div class="tt" style="font-size:%dpx"><span style="font-size:.62em;letter-spacing:3px;display:block;margin-bottom:4px">World Series</span>Game 5</div>' % (fs+14)
    elif c.get('quiet'): t = f'<div class="tt q">{c["occ"]}</div>'
    else: t = f'<div class="tt" style="font-size:{fs}px">{c["occ"]}</div>'
    return f"""<div class="card{' big' if c['big'] else ''}" style="top:{top}px"><div class="clip">
<div class="photo" style="height:{ph_h}px">{photo(c,ph_h)}<div class="scrim top"></div><div class="chip">{c['chip']}</div>{badge}
<div class="tb"><div class="ey"><i></i>{c['venue']} · {c['city']}</div>{t}</div></div>{stub(c)}</div></div>"""
v1 = head() + card(BASE['c1'], 157, 420, 52) + card(BASE['c2'], 157+420+100+24, 420, 52)
open('v1-main.html','w').write(page('Occasion title', CSS, v1))
v2 = card(BASE['c2'], 68, 260, 46) + card(BASE['c3'], 68+260+100+22, 260, 46)
open('v2-states.html','w').write(page('Occasion title states', CSS, v2))
