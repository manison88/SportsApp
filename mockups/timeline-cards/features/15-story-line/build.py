from stub import *
CSS = STUB_CSS + """
.story{position:absolute;z-index:6;left:20px;right:24px;bottom:20px;font:italic 400 27px/1.12 var(--f-serif);color:#fff;text-shadow:0 1px 14px rgba(0,0,0,.45);letter-spacing:.1px;text-wrap:balance}
.story.sm{font-size:25px}
.add{position:absolute;z-index:6;left:20px;bottom:20px;display:flex;align-items:center;gap:8px;height:34px;padding:0 14px 0 11px;border-radius:17px;border:1.5px dashed rgba(255,181,71,.6);background:rgba(255,181,71,.1);color:var(--signal);font:600 14px/1 var(--f-ui)}
.add svg{width:15px;height:15px;stroke-width:2.2}
.fade{position:absolute;left:0;right:0;bottom:0;height:60px;background:linear-gradient(transparent,var(--ink))}
"""
S = {1:'Bryant went deep in the 4th, and you were in the bleachers with Dana and Dad.',
     2:'Down 3-1. Chapman got eight outs. Dad cried.'}
def card(n, top, ph_h):
    c = BASE[n]
    if n in S: body = f'<div class="eb" style="bottom:{20+ (3 if n==1 else 2)*30+14}px">{c["venue"]}</div><div class="story">{S[n]}</div>'
    else: body = f'<div class="eb" style="bottom:{20+34+14}px">{c["venue"]}</div><div class="add">{ICON["plus"]}Add a note about this night</div>'
    return shell(c, top, ph_h, body)
open('v1-main.html','w').write(page('Story line', CSS, head()+card(1,157,420)+card(2,157+420+100+24,420)))
open('v2-states.html','w').write(page('Story line states', CSS, card(2,68,260)+card(3,68+260+100+22,260)))
