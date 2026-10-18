from stub import *
CSS = STUB_CSS + """
.av{display:flex}
.av i{width:30px;height:30px;border-radius:50%;display:grid;place-items:center;font:800 14px/1 var(--f-ui);font-style:normal;color:#10101a;box-shadow:0 0 0 2px rgba(12,13,18,.9);margin-left:-9px}
.av i:first-child{margin-left:0}
.av i.ghost{background:rgba(255,255,255,.08);border:1.5px dashed rgba(255,255,255,.4);color:var(--text-2);box-shadow:none;backdrop-filter:blur(8px)}
.av i.ghost svg{width:14px;height:14px}
.who{position:absolute;z-index:6;left:20px;right:16px;bottom:18px;display:flex;align-items:center;gap:9px}
.who .t{font:600 25px/1 var(--f-cond);letter-spacing:.3px;color:#fff;text-shadow:0 1px 12px rgba(0,0,0,.4);white-space:nowrap}
.who .t small{display:block;font:600 12.5px/1 var(--f-ui);letter-spacing:0;color:var(--signal);margin-top:7px;text-shadow:none}
.who .t small svg{width:12px;height:12px;vertical-align:-2px;margin-right:4px;stroke-width:2.4}
.who .t.solo{font-size:28px}
.ph-chip{margin-left:auto;white-space:nowrap;flex:none;align-self:flex-end;height:26px;padding:0 10px 0 8px;border-radius:13px;display:flex;align-items:center;gap:6px;font:700 11.5px/1 var(--f-ui);font-variant-numeric:tabular-nums;color:#fff;background:rgba(24,24,28,.55);backdrop-filter:blur(18px) saturate(1.4);-webkit-backdrop-filter:blur(18px) saturate(1.4);border:.5px solid rgba(255,255,255,.2)}
.ph-chip svg{width:14px;height:14px;color:rgba(255,255,255,.85)}
"""
DANA=('D','#b79cff'); DAD=('R','#8fe3a0')
W = {1:([DANA,DAD],'With Dana and Dad',63), 2:([DAD],'With Dad',63), 3:([],None,0)}
def card(n, top, ph_h):
    c = BASE[n]; who, txt, cnt = W[n]
    if who:
        av = ''.join(f'<i style="background:{col}">{ini}</i>' for ini,col in who)
        main = f'<span class="av">{av}</span><span class="t">{txt}</span>'
        eb_b = 18+32+13
    else:
        main = f'<span class="av"><i class="ghost">{ICON["people"]}</i></span><span class="t">Just you<small>{ICON["plus"]}Add who came</small></span>'
        eb_b = 18+44+14
    chip = f'<span class="ph-chip">{ICON["camera"]}{cnt} photos</span>' if cnt else ''
    body = f'<div class="eb" style="bottom:{eb_b}px">{c["venue"]}</div><div class="who">{main}{chip}</div>'
    return shell(c, top, ph_h, body)
open('v1-main.html','w').write(page('People first', CSS, head()+card(1,157,420)+card(2,157+420+100+24,420)))
open('v2-states.html','w').write(page('People first states', CSS, card(2,68,260)+card(3,68+260+100+22,260)))
