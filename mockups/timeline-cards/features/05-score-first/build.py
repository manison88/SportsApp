import os
here=os.path.dirname(os.path.abspath(__file__))
CSS='''
:root{--trophy:#e8d3a2;--stub:#16171f}
.top{position:absolute;left:16px;right:16px;top:54px}
.top h1{font:800 34px/1 var(--f-cond);letter-spacing:.5px;text-transform:uppercase}
.top .plus{position:absolute;right:0;top:2px;width:26px;height:26px}
.search{position:absolute;left:16px;right:16px;top:104px;height:36px;border-radius:10px;background:var(--raised);display:flex;align-items:center;gap:8px;padding:0 10px;color:var(--text-3);font:400 16px var(--f-ui)}
.card{position:absolute;left:16px;width:361px;border-radius:22px;overflow:hidden;background:var(--stub)}
.card.big{box-shadow:0 0 0 1.5px var(--trophy),0 0 28px rgba(232,211,162,.18)}
.photo{position:relative;overflow:hidden;background:#000}
.photo img{position:absolute;display:block}
.photo canvas{position:absolute;inset:0}
.scrim{position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,6,.28) 0%,rgba(5,5,6,0) 26%,rgba(5,5,6,.7) 50%,rgba(5,5,6,.95) 100%)}
.badge{position:absolute;left:14px;top:14px;padding:6px 10px;border-radius:8px;font:700 11px/1 var(--f-ui);letter-spacing:1.6px;color:var(--trophy);background:rgba(10,10,12,.55);backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px);border:.5px solid rgba(232,211,162,.55)}
.hero{position:absolute;left:0;right:0;bottom:18px;text-align:center}
.row{display:flex;align-items:center;justify-content:center;gap:14px}
.tile{width:52px;height:52px;border-radius:15px;font-size:19px;flex:none;position:relative}
.tile.you{box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.18),0 0 0 2px var(--ink),0 0 0 3.5px var(--signal)}
.score{font:400 150px/.8 var(--f-anton);font-variant-numeric:tabular-nums;letter-spacing:0;color:#fff;display:flex;align-items:baseline;text-shadow:0 4px 30px rgba(0,0,0,.5);padding-top:8px}
.score i{display:block;width:.2em;height:.05em;background:rgba(255,255,255,.45);margin:0 .12em;align-self:center;border-radius:2px;position:relative;top:.02em}
.score.s3{font-size:82px}.row.r3{gap:10px}.row.r3 .tile{width:40px;height:40px;font-size:15px;border-radius:13px}
.sup{margin-top:14px;font:600 17px/1 var(--f-tight);letter-spacing:.1px;color:rgba(245,241,234,.88)}
.sup b{font-weight:800;color:#fff}
.stub{position:relative;border-top:1.5px dashed rgba(255,255,255,.16);display:flex;align-items:center;justify-content:center;font:600 12px/1 var(--f-ui);letter-spacing:.9px;text-transform:uppercase;color:var(--text-2);white-space:nowrap}
.stub b{color:#fff;font-weight:700}
.stub u{text-decoration:none;color:var(--text-4);margin:0 8px}
.stub:before,.stub:after{content:"";position:absolute;top:-9px;width:16px;height:16px;border-radius:8px;background:var(--ink)}
.stub:before{left:-8px}.stub:after{right:-8px}
'''
def tile(t,bg,fg,you=False):
    return f'<div class="mono-badge tile{" you" if you else ""}" style="background:{bg};color:{fg}">{t}</div>'
def card(top,ph_h,stub_h,photo,badge,l,r,sc,sup,stub,big=False,cls=''):
    r3=' r3' if len(sc[0])>2 else ''
    s3=' s3' if len(sc[0])>2 or len(sc[1])>2 else ''
    return f'''<div class="card{' big' if big else ''}" style="top:{top}px"><div class="photo" style="height:{ph_h}px">{photo}<div class="scrim"></div>{badge}
<div class="hero"><div class="row{r3}">{l}<div class="score{s3}">{sc[0]}<i></i>{sc[1]}</div>{r}</div><div class="sup">{sup}</div></div></div>
<div class="stub" style="height:{stub_h}px">{stub}</div></div>'''
def st(d,v,s): return f'<b>{d}</b><u>&middot;</u>{v}<u>&middot;</u>{s}'
SB='<img class="ph graded" src="../../../photos/wrigley-scoreboard.jpg" style="left:-150px;top:-10px;width:auto;height:430px">'
def night(h): return f'<img class="ph graded" src="../../../photos/wrigley-night.jpg" style="left:-60px;top:-330px;width:480px;height:640px;filter:brightness(1.1) saturate(.95)">'
ARENA='<canvas class="photo" data-style="arena" data-seed="11" data-accent="#e8213f" data-secondary="#552583" data-board="LAL 118|CHI 104" data-sport="basketball"></canvas>'
CHC=tile('CHC','#2f6bff','#fff',True); MIL=tile('MIL','#f4c24b','#1b1400')
CLE=tile('CLE','#0c2340','#e8344a'); LAL=tile('LAL','#552583','#fdb927'); CHI=tile('CHI','#e8213f','#fff',True)
CHC2=tile('CHC','#2f6bff','#fff',True)
WS='<div class="badge">WORLD SERIES</div>'
def page(title,body):
    return f'<!doctype html><html><head><meta charset="utf-8"><title>{title}</title><link rel="stylesheet" href="../../../kit/kit.css"><style>{CSS}</style></head><body class="phone">{body}<script src="../../../kit/kit.js"></script></body></html>'
head='''<div class="top"><h1>Timeline</h1><svg class="plus" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round"><path d="M12 4v16M4 12h16"/></svg></div>
<div class="search"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg>Teams, places, years</div>'''
c1=lambda top:card(top,420,64,SB,'',CHC,MIL,('5','4'),'<b>Chicago</b> beat Milwaukee',st('Jul 4, 2026','Wrigley Field','Sec 314'))
c2=lambda top,h:card(top,h,64,night(h),WS,CHC2,CLE,('3','2'),'<b>Chicago</b> beat Cleveland',st('Oct 30, 2016','Wrigley Field','Sec 314'),big=True)
c3=lambda top,h:card(top,h,64,ARENA,'',LAL,CHI,('118','104'),'<b>Los Angeles</b> beat Chicago',st('Jan 3, 2025','United Center','Sec 105'))
peek=card(664,300,64,'<img class="ph graded" src="../../../photos/wrigley-night.jpg" style="left:-60px;top:-330px;width:480px;height:640px">',WS,CHC2,CLE,('3','2'),'<b>Chicago</b> beat Cleveland',st('Oct 30, 2016','Wrigley Field','Sec 314'),big=True)
open(here+'/v1-main.html','w').write(page('Score first',head+c1(160)+peek))
open(here+'/v2-states.html','w').write(page('Score first states',c2(60,300)+c3(440,300)))
