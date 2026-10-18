import os
here=os.path.dirname(os.path.abspath(__file__))
CSS='''
:root{--trophy:#e8d3a2;--stub:#16171f}
.top{position:absolute;left:16px;right:16px;top:54px}
.top h1{font:800 34px/1 var(--f-cond);letter-spacing:.5px;text-transform:uppercase}
.top .plus{position:absolute;right:0;top:2px;width:26px;height:26px}
.search{position:absolute;left:16px;right:16px;top:104px;height:36px;border-radius:10px;background:var(--raised);display:flex;align-items:center;gap:8px;padding:0 10px;color:var(--text-3);font:400 16px var(--f-ui)}
.card{position:absolute;left:16px;width:361px;border-radius:22px;overflow:hidden;background:var(--stub)}
.card.big{box-shadow:0 0 0 1.5px var(--trophy),0 0 28px rgba(232,211,162,.2)}
.rib{height:36px;display:flex;align-items:center;justify-content:space-between;padding:0 16px;font:700 11px/1 var(--f-ui);letter-spacing:1.7px;text-transform:uppercase;white-space:nowrap;position:relative}
.rib.quiet{background:rgba(255,255,255,.04);color:var(--text-3);font-weight:600;border-bottom:.5px solid var(--line)}
.rib.quiet span:last-child{color:var(--text-4)}
.rib.ev{background:linear-gradient(100deg,#0b1a44 0%,#14265e 55%,#5a1626 100%);color:var(--trophy);border-bottom:1.5px solid var(--trophy)}
.rib.ev .l{display:flex;align-items:center;gap:8px}
.rib.ev .l svg{width:11px;height:11px;fill:var(--trophy)}
.rib.ev .yr{color:rgba(232,211,162,.7);font-weight:600}
.rib.ev .st{padding:5px 9px;border-radius:6px;background:rgba(232,211,162,.14);border:.5px solid rgba(232,211,162,.55);color:#f6e7c4;letter-spacing:1.3px}
.photo{position:relative;overflow:hidden;background:#000}
.photo img{position:absolute;display:block}
.photo canvas{position:absolute;inset:0}
.scrim{position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,6,0) 35%,rgba(5,5,6,.6) 62%,rgba(5,5,6,.94) 100%)}
.hl{position:absolute;left:20px;right:16px;bottom:16px;font:800 54px/.92 var(--f-cond);text-transform:uppercase;letter-spacing:.2px;color:#fff;text-shadow:0 2px 24px rgba(0,0,0,.5)}
.hl.sm{font-size:46px}
.stub{position:relative;border-top:1.5px dashed rgba(255,255,255,.16);display:flex;align-items:center;justify-content:space-between;padding:0 24px 0 24px}
.stub:before,.stub:after{content:"";position:absolute;top:-9px;width:16px;height:16px;border-radius:8px;background:var(--ink)}
.stub:before{left:-8px}.stub:after{right:-8px}
.st1{font:700 18px/1 var(--f-cond);letter-spacing:1px;text-transform:uppercase;color:#fff}
.st2{margin-top:6px;font:600 12px/1 var(--f-ui);letter-spacing:.9px;text-transform:uppercase;color:var(--text-2)}
.bug{display:flex;align-items:center;gap:8px;font:800 22px/1 var(--f-cond);font-variant-numeric:tabular-nums;color:#fff}
.bug .mono-badge{width:36px;height:28px;font-size:14px;border-radius:9px}
.bug .mono-badge.you{box-shadow:0 0 0 1.5px var(--signal)}
.bug .sp{width:2px}
'''
def mb(t,bg,fg,you=False): return f'<div class="mono-badge{" you" if you else ""}" style="background:{bg};color:{fg}">{t}</div>'
def bug(a,b): return f'<div class="bug">{a[0]}<span style="margin-left:-2px">{a[1]}</span><span class="sp"></span>{b[0]}<span style="margin-left:-2px">{b[1]}</span></div>'
STAR='<svg viewBox="0 0 24 24"><path d="M12 1l3 8 8 .5-6.3 5 2.3 8.5L12 18l-7 5 2.3-8.5L1 9.5 9 9z"/></svg>'
def ribbon(big,l,mid,r):
    if big: return f'<div class="rib ev"><div class="l">{STAR}<span>{l}</span><span class="yr">{mid}</span></div><span class="st">{r}</span></div>'
    return f'<div class="rib quiet"><span>{l}</span><span>{r}</span></div>'
def card(top,ph_h,stub_h,photo,rib,hl,s1,s2,bg,big=False,sm=False):
    return f'''<div class="card{' big' if big else ''}" style="top:{top}px">{rib}<div class="photo" style="height:{ph_h}px">{photo}<div class="scrim"></div><div class="hl{' sm' if sm else ''}">{hl}</div></div>
<div class="stub" style="height:{stub_h}px"><div><div class="st1">{s1}</div><div class="st2">{s2}</div></div>{bg}</div></div>'''
def page(title,body):
    return f'<!doctype html><html><head><meta charset="utf-8"><title>{title}</title><link rel="stylesheet" href="../../../kit/kit.css"><style>{CSS}</style></head><body class="phone">{body}<script src="../../../kit/kit.js"></script></body></html>'
head='''<div class="top"><h1>Timeline</h1><svg class="plus" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round"><path d="M12 4v16M4 12h16"/></svg></div>
<div class="search"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg>Teams, places, years</div>'''
CHC=mb('CHC','#2f6bff','#fff',True);MIL=mb('MIL','#f4c24b','#1b1400');CLE=mb('CLE','#0c2340','#e8344a');LAL=mb('LAL','#552583','#fdb927');CHI=mb('CHI','#e8213f','#fff',True)
SB='<img class="ph graded" src="../../../photos/wrigley-scoreboard.jpg" style="left:-150px;top:-10px;width:auto;height:430px">'
NIGHT='<img class="ph graded" src="../../../photos/wrigley-night.jpg" style="left:-60px;top:-330px;width:480px;height:640px;filter:brightness(1.1)">'
ARENA='<canvas class="photo" data-style="arena" data-seed="11" data-accent="#e8213f" data-secondary="#552583" data-board="LAL 118|CHI 104" data-sport="basketball"></canvas>'
c1=lambda t,ph=420:card(t,ph,92,SB,ribbon(False,'Regular season &middot; Game 87','','MLB'),'Chicago 5,<br>Milwaukee 4.','Jul 4, 2026','Sec 314',bug((MIL,'4'),(CHC,'5')))
c1=lambda t,ph=420:card(t,ph,92,SB,ribbon(False,'Regular season &middot; Game 87','','MLB'),'Chicago 5,<br>Milwaukee 4.','Jul 4, 2026','Sec 314',f'<div class="bug">{MIL}4<span class="sp"></span>{CHC}5</div>')
c2=lambda t,ph=420:card(t,ph,92,NIGHT,ribbon(True,'World Series','2016','Game 5 &middot; Down 3&ndash;1'),'Chicago 3,<br>Cleveland 2.','Oct 30, 2016','Sec 314',f'<div class="bug">{CLE}2<span class="sp"></span>{CHC}3</div>',big=True)
c3=lambda t,ph=420:card(t,ph,92,ARENA,ribbon(False,'Regular season &middot; Game 34','','NBA'),'Los Angeles 118,<br>Chicago 104.','Jan 3, 2025','Sec 105',f'<div class="bug">{LAL}118<span class="sp"></span>{CHI}104</div>',sm=True)
open(here+'/v1-main.html','w').write(page('Big-game ribbon',head+c1(160)+c2(160+36+420+92+20)))
open(here+'/v2-states.html','w').write(page('Ribbon states',c2(60,226)+c3(60+36+226+92+16,226)))
