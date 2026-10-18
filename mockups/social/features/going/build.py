import os
here=os.path.dirname(os.path.abspath(__file__))
P={'Chris':('C','#ffd36e'),'Jordan':('J','#6fd3ff'),'Dana':('D','#b79cff'),'Ray':('R','#8fe3a0'),'Priya':('P','#ff7a8a'),'Marcus':('M','#ff9f5a'),'Sam':('S','#ffb547')}
def av(n,s=28,ring='#0b0b0e',ml=0):
    i,c=P[n]
    return f'<span class="av" style="width:{s}px;height:{s}px;background:{c};font-size:{round(s*.43)}px;box-shadow:0 0 0 2px {ring};margin-left:{ml}px">{i}</span>'
def stack(names,s=28,ring='#0b0b0e'):
    return '<span class="stk">'+''.join(av(n,s,ring,0 if k==0 else -s//4) for k,n in enumerate(names))+'</span>'
CSS='''
<link rel="stylesheet" href="../../../kit/kit.css">
<style>
body{background:var(--ink)}
.av{display:inline-grid;place-items:center;border-radius:50%;color:#1a1305;font-weight:800;font-family:var(--f-ui);flex:none}
.stk{display:inline-flex;align-items:center}
.cond{font-family:var(--f-cond);font-weight:800;letter-spacing:.2px}
.mono{display:inline-grid;place-items:center;border-radius:8px;font:900 13px/1 var(--f-cond);letter-spacing:.3px;color:#fff;width:30px;height:30px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.2)}
.chi{background:linear-gradient(135deg,#0b162a 55%,#f05a1a 55%)}
.gb{background:linear-gradient(135deg,#203731 55%,#ffb612 55%);color:#fff}
.chc{background:linear-gradient(135deg,#0e3386 55%,#cc3433 55%)}
.pill{display:inline-flex;align-items:center;gap:6px;height:36px;padding:0 14px;border-radius:18px;font:600 13px/1 var(--f-ui);color:var(--text);background:rgba(255,255,255,.1);border:.5px solid rgba(255,255,255,.18)}
.pill svg{width:15px;height:15px;stroke:currentColor;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
.crop{position:absolute;left:0;width:100%;bottom:0;height:175%;object-fit:cover;object-position:55% 100%}
.pill{white-space:nowrap}
.hero img,.inv img{z-index:0!important}
.hero:after,.inv:after{z-index:1}
.pill.amb{background:var(--signal);color:#1a1305;border-color:transparent}
</style>'''
def page(title,body,name):
    open(os.path.join(here,name),'w').write(f'<!doctype html>\n<html><head><meta charset="utf-8"><title>{title}</title>{CSS}\n</head>\n<body class="phone">\n{body}\n<script src="../../../kit/kit.js"></script>\n</body></html>')
SV={'cal':'<svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="15" rx="3"/><path d="M4 10h16M9 3v4M15 3v4"/></svg>',
'tix':'<svg viewBox="0 0 24 24"><path d="M3 9V7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v2a3 3 0 0 0 0 6v2a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-2a3 3 0 0 0 0-6z"/><path d="M14 5v14" stroke-dasharray="2 2.5"/></svg>',
'inv':'<svg viewBox="0 0 24 24"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.5-3.6 3.2-5.5 6.5-5.5s6 1.9 6.5 5.5M19 8v6M16 11h6"/></svg>',
'plus':'<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
'back':'<svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg>',
'share':'<svg viewBox="0 0 24 24"><path d="M12 15V4M8 8l4-4 4 4M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>',
'chk':'<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'}

# ---------------- v1
rows=''
def row(img,pos,mono,t1,t2,when,names,state,sc):
    return f'''<div class="row"><div class="th" style="background:url({img}) {pos}/cover"></div>
<div class="rm"><div class="rt">{t1}</div><div class="rs">{t2}</div>
<div class="rf">{stack(names,20,'#121215')}<span class="rw">{when}</span></div></div>
<div class="rr"><span class="st" style="color:{sc};border-color:{sc}55">{state}</span><div class="dd"><b>{when_d[t1]}</b><i>days</i></div></div></div>'''
when_d={'Chicago vs Denver':'22','Milwaukee at Chicago':'97'}
rows=row('../../../photos/united-center-court.jpg','50% 55%','','Chicago vs Denver','United Center · Jan 17','Priya going',['Priya'],'Interested','#ffd9a0')
rows+=row('../../../photos/wrigley-night.jpg','50% 50%','','Milwaukee at Chicago','Wrigley Field · Apr 2',' Dana, Ray going',['Dana','Ray'],'Going','#8fe3a0')
b1=f'''<style>
.hd{{position:absolute;left:20px;right:20px;top:56px;display:flex;justify-content:space-between;align-items:flex-end}}
.hd h1{{font:400 38px/1 var(--f-serif);letter-spacing:-.5px;margin-top:6px}}
.hd h1 em{{color:var(--signal)}}
.hero{{position:absolute;left:16px;right:16px;top:130px;height:368px;border-radius:28px;overflow:hidden;background:#111;box-shadow:0 0 0 .5px rgba(255,255,255,.14)}}
.hero img{{filter:saturate(.85) brightness(.85)}}
.hero:after{{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,6,.3) 0%,rgba(5,5,6,0) 25%,rgba(5,5,6,.78) 52%,rgba(5,5,6,.96) 100%)}}
.hero>*{{z-index:2}}
.hero .top{{position:absolute;left:20px;right:20px;top:18px;display:flex;justify-content:space-between;align-items:center}}
.next{{font:700 11px/1 var(--f-ui);letter-spacing:1.8px;color:#fff;text-transform:uppercase}}
.tag{{font:700 10px/1 var(--f-ui);letter-spacing:1.4px;padding:6px 9px;border-radius:12px;background:rgba(143,227,160,.18);color:#8fe3a0;border:.5px solid rgba(143,227,160,.5)}}
.cd{{position:absolute;left:20px;top:50px;display:flex;align-items:flex-end;gap:10px}}
.cd b{{font:400 128px/.8 var(--f-anton);color:var(--signal);letter-spacing:-2px;text-shadow:0 6px 30px rgba(0,0,0,.45)}}
.cd span{{font:800 22px/1 var(--f-cond);letter-spacing:3px;color:#fff;padding-bottom:6px}}
.mt{{position:absolute;left:20px;right:20px;top:166px}}
.mt .tm{{display:flex;align-items:center;gap:10px}}
.mt h2{{font:800 28px/1.02 var(--f-tight);letter-spacing:-.7px;margin-top:10px}}
.mt p{{font:500 14px/1.3 var(--f-ui);color:var(--text-2);margin-top:6px}}
.who{{position:absolute;left:20px;right:20px;top:272px;display:flex;align-items:center;gap:10px;font:600 14px/1 var(--f-ui)}}
.who small{{color:var(--text-2);font-weight:500}}
.acts{{position:absolute;left:16px;right:16px;bottom:18px;display:flex;gap:6px}}
.acts .pill{{height:38px;padding:0 10px;font-size:12px;gap:5px}}
.sec{{position:absolute;left:20px;right:20px;top:516px;display:flex;justify-content:space-between;align-items:baseline}}
.row{{position:relative;display:flex;gap:12px;align-items:center;background:var(--surface);border:.5px solid var(--line-2);border-radius:20px;padding:10px 14px 10px 10px;height:88px;margin-bottom:10px}}
.th{{width:68px;height:68px;border-radius:14px;flex:none}}
.rm{{flex:1;min-width:0}}
.rt{{font:700 16px/1.1 var(--f-tight);letter-spacing:-.2px}}
.rs{{font:500 12.5px/1.2 var(--f-ui);color:var(--text-2);margin-top:4px}}
.rf{{display:flex;align-items:center;margin-top:8px}}
.rw{{font:500 12px/1 var(--f-ui);color:var(--text-2);margin-left:8px}}
.rr{{display:flex;flex-direction:column;align-items:flex-end;gap:8px}}
.st{{font:700 10px/1 var(--f-ui);letter-spacing:1.2px;text-transform:uppercase;padding:5px 8px;border:.5px solid;border-radius:10px}}
.dd{{display:flex;align-items:baseline;gap:3px}}.dd b{{font:800 26px/1 var(--f-cond)}}.dd i{{font:600 10px/1 var(--f-ui);font-style:normal;letter-spacing:1px;color:var(--text-3);text-transform:uppercase}}
.list{{position:absolute;left:16px;right:16px;top:542px}}
.foot{{position:absolute;left:24px;right:24px;top:758px;display:flex;gap:10px;align-items:flex-start;font:500 12.5px/1.4 var(--f-ui);color:var(--text-2)}}
.foot svg{{width:16px;height:16px;flex:none;margin-top:1px;stroke:var(--signal);fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}}
</style>
<div class="hd"><div><div class="eyebrow">Timeline &middot; Upcoming</div><h1>Going <em>soon</em></h1></div>
<div class="btn-circle glass" style="background:var(--signal);border:0">{SV['plus'].replace('<svg','<svg style="stroke:#1a1305"')}</div></div>
<div class="hero"><img class="crop" src="../../../photos/lambeau-concourse.jpg" alt="">
<div class="top"><span class="next">Next game</span><span class="tag">YOU'RE GOING</span></div>
<div class="cd"><b>9</b><span>DAYS</span></div>
<div class="mt"><div class="tm"><span class="mono chi">CHI</span><span class="cond" style="font-size:16px;color:var(--text-2)">AT</span><span class="mono gb">GB</span></div>
<h2>Chicago at Green Bay</h2><p>Lambeau Field &middot; Jan 4 &middot; 12:00 PM</p></div>
<div class="who">{stack(['Chris','Jordan'],30,'#0c0c0e')}<span>Chris, Jordan going <small>&middot; Sec 112</small></span></div>
<div class="acts"><span class="pill amb">{SV['tix']}Add ticket</span><span class="pill">{SV['inv']}Invite</span><span class="pill">{SV['cal']}Add to calendar</span></div></div>
<div class="sec"><span class="eyebrow">Later this season</span><span class="eyebrow" style="color:var(--text-3)">2 games</span></div>
<div class="list">{rows}</div>
<div class="foot"><svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg><span>Games you go to become a Together memory automatically. Only friends you invite see your plans.</span></div>'''
page('Upcoming',b1,'v1-upcoming.html')

# ---------------- v2
def rsvp(n,state,col,sub=''):
    return f'''<div class="gp"><div class="gpa">{av(n,36,'#121215')}<i class="bd" style="background:{col}">{state[0]}</i></div><b>{n}</b><span style="color:{col}">{state}</span></div>'''
G='#8fe3a0';M='#ffd9a0';C='#ff8a80'
b2=f'''<style>
.hero{{position:absolute;left:0;right:0;top:0;height:250px;overflow:hidden}}
.hero img{{filter:saturate(.85) brightness(.82)}}
.hero:after{{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,6,.55) 0%,rgba(5,5,6,0) 30%,rgba(5,5,6,.55) 72%,var(--ink) 100%)}}
.nb{{position:absolute;top:60px;z-index:5}}
.ht{{position:absolute;left:20px;right:20px;top:108px;z-index:4}}
.ht .ey{{font:700 11px/1 var(--f-ui);letter-spacing:1.8px;color:var(--signal)}}
.ht h1{{font:400 38px/1 var(--f-serif);letter-spacing:-.8px;margin-top:6px}}
.ht p{{font:500 14px/1.3 var(--f-ui);color:var(--text-2);margin-top:8px}}
.cdrow{{position:absolute;left:20px;right:20px;top:200px;z-index:4;display:flex;gap:8px;align-items:center}}
.cdp{{display:flex;align-items:baseline;gap:6px;height:40px;padding:0 14px;border-radius:20px;background:var(--signal);color:#1a1305}}
.cdp b{{font:800 26px/1 var(--f-cond)}}.cdp span{{font:800 11px/1 var(--f-ui);letter-spacing:1.4px}}
.cdt{{white-space:nowrap;font:600 13px/1 var(--f-ui);color:var(--text-2)}}
.card{{background:var(--surface);border:.5px solid var(--line-2);border-radius:20px;padding:14px 16px}}
.pl{{position:absolute;left:16px;right:16px;top:252px;display:flex;flex-direction:column;gap:8px}}
.pl .card{{padding:12px 16px}}
.lbl{{font:700 11px/1 var(--f-ui);letter-spacing:1.6px;color:var(--text-3);text-transform:uppercase}}
.seg{{display:flex;background:rgba(255,255,255,.07);border-radius:12px;padding:3px;margin-top:10px}}
.seg span{{flex:1;text-align:center;font:600 13.5px/32px var(--f-ui);color:var(--text-2);border-radius:9px}}
.seg .on{{background:var(--signal);color:#1a1305}}
.gps{{display:flex;justify-content:space-between;margin-top:12px;padding:0 4px}}
.gp{{display:flex;flex-direction:column;align-items:center;gap:3px;font:500 12px/1.1 var(--f-ui);width:70px}}
.gp b{{font-weight:700;font-size:13px;margin-top:4px}}
.gpa{{position:relative}}.bd{{position:absolute;right:-3px;bottom:-3px;width:17px;height:17px;border-radius:50%;display:grid;place-items:center;font:800 9px/1 var(--f-ui);font-style:normal;color:#10130f;box-shadow:0 0 0 2px #121215}}
.srow{{display:flex;justify-content:space-between;align-items:center;height:30px;border-top:.5px solid var(--line)}}
.srow:first-of-type{{border-top:0}}
.srow .l{{display:flex;gap:10px;align-items:center;font:600 14px/1 var(--f-ui)}}
.srow .r{{font:500 13.5px/1 var(--f-ui);color:var(--text-2)}}
.srow .r b{{color:var(--text);font-weight:700}}
.two{{display:flex;gap:10px;margin-top:10px}}
.two .card{{flex:1;padding:12px 14px!important}}
.big{{font:800 30px/1 var(--f-cond);margin-top:6px;letter-spacing:.2px}}
.big small{{font:600 14px/1 var(--f-ui);color:var(--text-2);letter-spacing:0;margin-left:2px}}
.sub{{font:500 12.5px/1.3 var(--f-ui);color:var(--text-2);margin-top:5px}}
.note{{background:#201a0e;border:.5px solid rgba(255,181,71,.35);position:relative}}
.note p{{font:400 23px/1.05 var(--f-hand);color:#ffe7bd;margin-top:6px}}
.note .by{{display:flex;align-items:center;gap:6px;font:500 12px/1 var(--f-ui);color:var(--text-2);margin-top:8px}}
.rep{{height:66px;flex:none;border-radius:18px;background:linear-gradient(100deg,rgba(255,181,71,.2),rgba(255,181,71,.06));border:.5px solid rgba(255,181,71,.4);display:flex;align-items:center;gap:12px;padding:0 16px;font:600 13px/1.25 var(--f-ui)}}
.rep svg{{width:22px;height:22px;flex:none;stroke:var(--signal);fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}}
.rep small{{display:block;color:var(--text-2);font-weight:500;font-size:12px;margin-top:2px}}
</style>
<div class="hero"><img class="crop" src="../../../photos/lambeau-concourse.jpg" alt=""></div>
<div class="btn-circle glass nb" style="left:16px">{SV['back']}</div><div class="btn-circle glass nb" style="right:16px">{SV['share']}</div>
<div class="ht"><div class="ey">WEEK 18 &middot; GAME PLAN</div><h1>Chicago at Green Bay</h1><p>Lambeau Field &middot; Jan 4 &middot; 12:00 PM CT</p></div>
<div class="cdrow"><div class="cdp"><b>9</b><span>DAYS</span></div><span class="cdt">Gate meet 11:00 &middot; kickoff 12:00</span></div>
<div class="pl">
<div class="card"><div style="display:flex;justify-content:space-between;align-items:center"><span class="lbl">Who's going &middot; 2 of 4</span><span style="font:600 13px/1 var(--f-ui);color:var(--signal)">+ Invite</span></div>
<div class="seg"><span class="on">Going</span><span>Maybe</span><span>Can't</span></div>
<div class="gps">{rsvp('Chris','Going',G)}{rsvp('Jordan','Going',G)}{rsvp('Priya','Maybe',M)}{rsvp('Dana',"Can't",C)}</div></div>
<div class="card" style="padding:4px 16px!important"><div class="srow"><div class="l">{SV['tix'].replace('<svg','<svg width=18 height=18 style="stroke:var(--signal);fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round"')}Seats</div><div class="r"><b>Sam</b> Sec 112 Row 41</div></div>
<div class="srow"><div class="l" style="opacity:0"> </div><div class="r"><b>Chris</b> Sec 114</div></div></div>
<div class="card note"><div style="display:flex;justify-content:space-between;align-items:center"><span class="lbl" style="color:var(--signal)">Meeting plan</span><div class="by" style="margin:0">{av('Sam',18,'#201a0e')}Sam &middot; today</div></div><p>Meet at the Packers Hall of Fame gate, 11:00</p></div>
<div class="two" style="margin:0"><div class="card"><span class="lbl">Drive</span><div class="big">3h 25<small>min</small></div><div class="sub">209 mi &middot; leave by 7:15</div></div>
<div class="card"><span class="lbl">Forecast</span><div class="big">19&deg;<small>F &middot; light snow</small></div><div class="sub">Pack the heavy gloves.</div></div></div>
<div class="rep"><svg viewBox="0 0 24 24"><path d="M6 3h9l4 4v14H6z"/><path d="M14 3v5h5M9 13h7M9 17h5"/></svg><div>Everyone going gets the shared<br>match report after<small>Only photos each of you chooses to add.</small></div></div></div>'''
page('Game plan',b2,'v2-game-plan.html')

# ---------------- v3
b3=f'''<style>
.back{{position:absolute;left:22px;right:22px;top:56px;height:150px;border-radius:26px 26px 0 0;background:#17171b;border:.5px solid var(--line-2);padding:16px 18px;filter:brightness(.7);transform-origin:top}}
.back .tt{{display:flex;justify-content:space-between;font:700 15px/1 var(--f-ui)}}
.srch{{margin-top:12px;height:38px;border-radius:12px;background:rgba(255,255,255,.09);display:flex;align-items:center;gap:8px;padding:0 12px;font:500 15px/1 var(--f-ui)}}
.srch svg{{width:16px;height:16px;stroke:var(--text-3);fill:none;stroke-width:2}}
.srch u{{text-decoration:none;width:1.5px;height:17px;background:var(--signal);margin-left:-6px}}
.gm{{margin-top:10px;display:flex;align-items:center;gap:10px;padding:9px 10px;border-radius:14px;background:rgba(255,181,71,.16);border:.5px solid rgba(255,181,71,.6)}}
.gm .t{{font:700 14px/1.1 var(--f-ui)}}.gm .s{{font:500 11.5px/1 var(--f-ui);color:var(--text-2);margin-top:4px}}
.gm .ck{{margin-left:auto;width:22px;height:22px;border-radius:50%;background:var(--signal);display:grid;place-items:center}}
.gm .ck svg{{width:13px;height:13px;stroke:#1a1305;fill:none;stroke-width:3;stroke-linecap:round;stroke-linejoin:round}}
.sheet{{position:absolute;left:0;right:0;top:214px;bottom:0;border-radius:30px 30px 0 0;background:#101013;border-top:.5px solid rgba(255,255,255,.22);box-shadow:0 -20px 60px rgba(0,0,0,.7)}}
.grab{{width:38px;height:5px;border-radius:3px;background:rgba(255,255,255,.28);margin:8px auto 0}}
.sh{{display:flex;justify-content:space-between;align-items:center;padding:12px 20px 0}}
.sh b{{font:700 17px/1 var(--f-ui)}}.sh span{{font:600 14px/1 var(--f-ui);color:var(--text-2)}}
.inv{{position:absolute;left:26px;right:26px;top:52px;height:236px;border-radius:24px;overflow:hidden;background:#0c0c0e;box-shadow:0 18px 40px rgba(0,0,0,.6),0 0 0 .5px rgba(255,255,255,.25);transform:rotate(-1.2deg)}}
.inv img{{filter:saturate(.9) brightness(.9)}}
.inv:after{{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,6,.5),rgba(5,5,6,.4) 40%,rgba(5,5,6,.93) 85%)}}
.inv>*{{position:absolute;z-index:2}}
.inv .a{{left:18px;top:16px;display:flex;align-items:center;gap:8px;font:800 11px/1 var(--f-ui);letter-spacing:1.8px}}
.inv .w{{right:16px;top:16px;font:400 15px/1 var(--f-serif);font-style:italic;color:rgba(255,255,255,.85)}}
.inv h3{{left:18px;right:18px;top:84px;font:400 34px/.98 var(--f-serif);letter-spacing:-.5px}}
.inv h3 em{{color:var(--signal)}}
.inv .d{{left:18px;top:146px;font:500 13px/1.3 var(--f-ui);color:rgba(255,255,255,.8)}}
.inv .j{{right:16px;bottom:14px;height:36px;padding:0 18px;border-radius:18px;background:var(--signal);color:#1a1305;font:800 14px/36px var(--f-ui)}}
.inv .g{{left:18px;bottom:16px;display:flex;align-items:center;gap:8px;font:600 12px/1 var(--f-ui);color:rgba(255,255,255,.85)}}
.to{{position:absolute;left:20px;right:20px;top:306px}}
.to .lb{{font:700 11px/1 var(--f-ui);letter-spacing:1.6px;color:var(--text-3);text-transform:uppercase}}
.fr{{display:flex;gap:14px;margin-top:12px}}
.f1{{display:flex;flex-direction:column;align-items:center;gap:6px;font:500 12px/1 var(--f-ui);color:var(--text-2);position:relative}}
.f1.sel{{color:var(--text)}}.f1.sel .av{{box-shadow:0 0 0 2px #101013,0 0 0 4px var(--signal)!important}}
.f1 .tk{{position:absolute;right:-2px;top:34px;width:18px;height:18px;border-radius:50%;background:var(--signal);display:grid;place-items:center;box-shadow:0 0 0 2px #101013}}
.f1 .tk svg{{width:10px;height:10px;stroke:#1a1305;fill:none;stroke-width:3.4;stroke-linecap:round;stroke-linejoin:round}}
.apps{{display:flex;gap:10px;margin-top:16px}}
.ap{{flex:1;height:44px;border-radius:14px;background:rgba(255,255,255,.08);display:flex;align-items:center;justify-content:center;gap:7px;font:600 13px/1 var(--f-ui)}}
.ap svg{{width:16px;height:16px;stroke:currentColor;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}}
.priv{{margin-top:12px;display:flex;gap:8px;font:500 12px/1.4 var(--f-ui);color:var(--text-2)}}
.priv svg{{width:14px;height:14px;flex:none;margin-top:1px;stroke:var(--signal);fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}}
.cta{{position:absolute;left:20px;right:20px;top:538px;height:52px;border-radius:26px;background:var(--signal);color:#1a1305;font:800 16px/52px var(--f-ui);text-align:center}}
</style>
<div class="back"><div class="tt"><span style="color:var(--text-2);font-weight:600">Cancel</span><span>Pick a game</span><span style="opacity:0">Cancel</span></div>
<div class="srch"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/></svg>Green Bay<u></u></div>
<div class="gm"><span class="mono chi" style="width:26px;height:26px;font-size:11px">CHI</span><div><div class="t">Chicago at Green Bay</div><div class="s">Lambeau Field &middot; Jan 4 &middot; 12:00 PM</div></div><span class="ck">{SV['chk']}</span></div></div>
<div class="sheet"><div class="grab"></div>
<div class="sh"><b>Invite to the game</b><span>Step 2 of 2</span></div>
<div class="inv"><img class="crop" src="../../../photos/lambeau-concourse.jpg" alt="">
<div class="a"><span class="av" style="width:22px;height:22px;background:#ffb547;font-size:10px">S</span><span style="color:var(--signal)">SAM IS GOING</span></div><div class="w">witness</div>
<h3>Chicago at <em>Green Bay</em></h3><div class="d">Jan 4 &middot; Lambeau Field &middot; 12:00 PM<br>19&deg;F, light snow in the forecast</div>
<div class="g">{stack(['Sam','Chris','Jordan'],22,'#0c0c0e')}<span>3 going</span></div><div class="j">Join?</div></div>
<div class="to"><div class="lb">Send to</div>
<div class="fr">
<div class="f1 sel">{av('Chris',46,'#101013')}<i class="tk">{SV['chk']}</i>Chris</div>
<div class="f1 sel">{av('Jordan',46,'#101013')}<i class="tk">{SV['chk']}</i>Jordan</div>
<div class="f1">{av('Priya',46,'#101013')}Priya</div><div class="f1">{av('Marcus',46,'#101013')}Marcus</div><div class="f1">{av('Dana',46,'#101013')}Dana</div></div>
<div class="apps"><span class="ap">{SV['share'].replace('<svg','<svg ')}Messages</span><span class="ap"><svg viewBox="0 0 24 24"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h8"/></svg>Copy link</span><span class="ap">More</span></div>
<div class="priv"><svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg><span>The card shows the game and who's going. No photos, no location.</span></div></div>
<div class="cta">Send invite to 2 friends</div></div>'''
page('Invite flow',b3,'v3-invite.html')
