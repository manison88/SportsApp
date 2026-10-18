import random, os
HERE=os.path.dirname(os.path.abspath(__file__))
K='../../../'
SZ={'soldier-soccer':(1280,1707),'soldier-skyline':(1280,853),'soldier-aerial':(1280,960)}
SAM,CHR,JOR='#ffb547','#f4e04d','#6fd3ff'
COL={'Sam':SAM,'Chris':CHR,'Jordan':JOR}
def crop(tw,th,cx,cy,wf,p='soldier-soccer'):
    iw,ih=SZ[p]; s=max(tw/(wf*iw),th/ih,tw/iw); W,H=iw*s,ih*s
    x=min(0,max(tw-W,tw/2-cx*W)); y=min(0,max(th-H,th/2-cy*H))
    return f"background:url({K}photos/{p}.jpg) {x:.1f}px {y:.1f}px/{W:.1f}px {H:.1f}px no-repeat"
# named crops (cx,cy,wf)
C={'bowl':(.5,.38,.9),'bowlR':(.8,.42,.5),'bowlL':(.2,.4,.5),'crowd':(.45,.545,.45),'crowdR':(.85,.55,.4),
 'play':(.6,.68,.35),'playR':(.92,.72,.25),'playL':(.4,.7,.3),'grass':(.5,.86,.5),'tunnel':(.92,.56,.25),
 'wide':(.5,.62,.8),'pair':(.93,.71,.18),'mid':(.55,.7,.5),'crowdL':(.15,.55,.4),'seats':(.6,.45,.35),'sky':(.5,.5,.9)}
def ph(tw,th,k,cls='',style='',extra=''):
    cx,cy,wf=C[k][:3]
    p='soldier-soccer'
    return f'<i class="th {cls}" style="width:{tw}px;height:{th}px;{crop(tw,th,cx,cy,wf,p)};{style}">{extra}</i>'
def av(n,s=28,ring=False,fs=None):
    c=COL.get(n,'#b79cff'); ini={'Sam':'SO','Chris':'CD','Jordan':'JP'}[n]
    fs=fs or round(s*.38)
    return f'<span class="av" style="width:{s}px;height:{s}px;background:{c};font-size:{fs}px;{"box-shadow:0 0 0 2px #050506;" if ring else ""}">{ini}</span>'
CAM='<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8.5A2.5 2.5 0 0 1 5.5 6H8l1.5-2h5L16 6h2.5A2.5 2.5 0 0 1 21 8.5v9a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5z"/><circle cx="12" cy="13" r="3.6"/></svg>'
LOCK='<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/></svg>'
CHECK='<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#1a1204" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
SHARE='<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3.5M7.5 8 12 3.5 16.5 8"/><path d="M6 11.5H5.5A1.5 1.5 0 0 0 4 13v6.5A1.5 1.5 0 0 0 5.5 21h13a1.5 1.5 0 0 0 1.5-1.5V13a1.5 1.5 0 0 0-1.5-1.5H18"/></svg>'
BACK='<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 5.5 8 12l6.5 6.5"/></svg>'
CLOSE='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>'
BASE='''<!doctype html>
<html><head><meta charset="utf-8"><title>%s</title>
<link rel="stylesheet" href="../../../kit/kit.css">
<style>
html,body{background:#050506}
.abs{position:absolute}
i{font-style:normal}
.av{display:inline-flex;align-items:center;justify-content:center;border-radius:50%%;font:700 11px/1 var(--f-ui);color:#1a1204;flex:none;letter-spacing:.2px}
.th{display:block;border-radius:8px;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.14);position:relative;flex:none}
.dot{position:absolute;right:3px;top:3px;width:9px;height:9px;border-radius:50%%;box-shadow:0 0 0 1.5px rgba(5,5,6,.92)}
.eyebrow{font:600 9.5px/1 var(--f-ui);letter-spacing:1.5px;text-transform:uppercase;color:var(--text-3)}
.nav{position:absolute;top:56px;left:16px;right:16px;height:40px;display:flex;align-items:center;justify-content:space-between;z-index:30}
.bug{display:flex;align-items:center;height:36px;padding:0 14px;border-radius:18px;gap:10px;font:700 15px/1 var(--f-cond);letter-spacing:.6px;background:rgba(30,30,36,.72);backdrop-filter:blur(20px);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.14)}
.bug .t{color:var(--text-2);font-size:14px;letter-spacing:1px}
.bug b{font:700 20px/1 var(--f-cond);color:var(--text)}
.bug b.dim{color:var(--text-3)}
.bug .sep{width:1px;height:14px;background:var(--line-2)}
.bug .fin{font:600 10.5px/1 var(--f-ui);letter-spacing:1.6px;color:var(--signal)}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;height:50px;border-radius:25px;font:600 16px/1 var(--f-ui);letter-spacing:-.1px}
.btn.pri{background:var(--signal);color:#1a1204;box-shadow:0 8px 28px rgba(255,181,71,.28)}
.btn.sec{background:rgba(255,255,255,.08);color:var(--text);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.16)}
%s
</style></head>
<body class="phone">
%s
<script src="../../../kit/kit.js"></script>
</body></html>'''
def write(n,title,css,body): open(os.path.join(HERE,n),'w').write(BASE%(title,css,body))

# ============================================================ V1
css1='''
.glow{position:absolute;left:-40px;right:-40px;top:-60px;height:420px;background:radial-gradient(60% 55% at 50% 38%,rgba(255,181,71,.16),transparent 70%),radial-gradient(40% 40% at 88% 30%,rgba(111,211,255,.10),transparent 70%);}
.close{position:absolute;top:56px;left:16px}
.top{position:absolute;top:56px;left:0;right:0;height:40px;display:flex;align-items:center;justify-content:center;font:600 10.5px/1 var(--f-ui);letter-spacing:1.6px;color:var(--text-2)}
.top i{display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--signal);margin-right:8px;box-shadow:0 0 8px var(--signal)}
.gm{position:absolute;left:16px;right:16px;top:108px;height:68px;border-radius:18px;background:var(--surface);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.09);display:flex;align-items:center;gap:12px;padding:0 12px 0 10px}
.gm .sc{font:700 20px/1 var(--f-cond);letter-spacing:.3px;color:var(--text)}
.gm .sc .l{color:var(--text-3)}
.gm .meta{font:500 11.5px/1.3 var(--f-ui);color:var(--text-2);margin-top:5px}
.gm .found{margin-left:auto;font:600 9px/1 var(--f-ui);letter-spacing:1.3px;color:var(--text-3);text-align:right;line-height:1.5}
.trio{position:absolute;left:16px;top:200px;display:flex}
.trio .av{margin-right:-10px;box-shadow:0 0 0 3px #050506}
h1{position:absolute;left:16px;right:16px;top:268px;font:400 35px/1.04 var(--f-serif);letter-spacing:-.4px;color:var(--text)}
h1 em{font-style:italic;color:var(--signal)}
.lbl{position:absolute;left:16px;right:16px;display:flex;justify-content:space-between;align-items:baseline}
.lbl a{font:600 12px/1 var(--f-ui);color:var(--signal)}
.card{position:absolute;left:16px;right:16px;border-radius:20px;background:var(--surface);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.09)}
.pr{display:flex;align-items:center;gap:12px;height:62px;padding:0 14px;position:relative}
.pr+.pr:before{content:"";position:absolute;left:62px;right:0;top:0;border-top:.5px solid var(--line)}
.pr b{display:block;font:600 16px/1.1 var(--f-tight);letter-spacing:-.15px}
.pr span.s{display:block;font:400 12px/1.25 var(--f-ui);color:var(--text-2);margin-top:3px}
.pr .cb{margin-left:auto;width:24px;height:24px;border-radius:50%;background:var(--signal);display:flex;align-items:center;justify-content:center;flex:none}
.opt{display:flex;align-items:center;gap:12px;padding:0 14px;height:68px;position:relative}
.opt+.opt{border-top:.5px solid var(--line)}
.opt b{display:block;font:600 15.5px/1.1 var(--f-tight)}
.opt span.s{display:block;font:400 12px/1.3 var(--f-ui);color:var(--text-2);margin-top:3px}
.rad{width:22px;height:22px;border-radius:50%;box-shadow:inset 0 0 0 1.5px var(--text-4);flex:none}
.rad.on{background:radial-gradient(circle,#1a1204 0 4px,var(--signal) 4.5px);box-shadow:none}
.opt.sel{background:rgba(255,181,71,.08);border-radius:20px;box-shadow:inset 0 0 0 1px rgba(255,181,71,.5)}
.priv{position:absolute;left:16px;right:16px;top:714px;display:flex;gap:10px;font:400 11.5px/1.4 var(--f-ui);color:var(--text-2)}
.priv svg{flex:none;margin-top:1px;color:var(--text-2)}
.priv b{color:var(--text);font-weight:600}
.cta{position:absolute;left:16px;right:16px;top:770px}
'''
body1=f'''<div class="glow"></div>
<div class="top"><i></i>GAME FOUND IN YOUR PHOTOS</div>
<div class="btn-circle glass close">{CLOSE}</div>
<div class="gm">{ph(46,46,'wide',style='border-radius:12px')}<div><div class="sc">QAT <span>1</span> <span class="l">·</span> BIH <span>3</span></div><div class="meta">World Cup · Wed Jun 24 · Lumen Field</div></div><div class="found">104<br>PHOTOS</div></div>
<div class="trio">{av('Sam',52,fs=18)}{av('Chris',52,fs=18)}{av('Jordan',52,fs=18)}</div>
<h1>Chris and Jordan were at this game too. <em>Make it a Together memory?</em></h1>
<div class="lbl" style="top:410px"><span class="eyebrow">Who was there</span><a>Add someone</a></div>
<div class="card" style="top:432px;height:124px">
 <div class="pr">{av('Chris',34)}<div><b>Chris Dunn</b><span class="s">Your companion · at the 2021 US Grand Prix with you</span></div><span class="cb">{CHECK}</span></div>
 <div class="pr">{av('Jordan',34)}<div><b>Jordan Park</b><span class="s">Opened your invite link · has this game too</span></div><span class="cb">{CHECK}</span></div>
</div>
<div class="lbl" style="top:576px"><span class="eyebrow">What you share</span></div>
<div class="card" style="top:598px;height:137px;overflow:hidden;background:transparent;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.09)">
 <div class="opt sel"><span class="rad on"></span><div><b>Nothing yet</b><span class="s">You're in the memory. Your photos stay private.</span></div></div>
 <div class="opt" style="border:0"><span class="rad"></span><div><b>Pick photos to share</b><span class="s">Choose from your 104. Default is none.</span></div></div>
</div>
'''
body1=body1.replace('top:714px','top:714px')
body1+=f'''<div class="priv" style="top:744px">{LOCK}<div><b>Your photos never leave your phone</b> unless you pick them. Only Chris and Jordan can see what you share, and you can remove it any time.</div></div>
<div class="cta"><div class="btn pri">Start Together memory</div></div>'''
# adjust: layout vertical budget handled by css positions
css1=css1.replace('.cta{position:absolute;left:16px;right:16px;top:770px}','.cta{position:absolute;left:16px;right:16px;top:782px}')
write('v1-invite.html','Together invite',css1,body1)

# ============================================================ V2
W=313; X0=64
def ticks(seed,col,clusters,n=34,hmax=15):
    r=random.Random(seed); out=[]; used=set()
    for f,spread,cnt,h in clusters:
        for _ in range(cnt):
            x=round((f+(r.random()-.5)*spread)*W/3)*3
            if x in used or x<0 or x>W: continue
            used.add(x); hh=max(4,round(h*(.45+r.random()*.6)))
            out.append(f'<i class="tk" style="left:{x}px;height:{hh}px;background:{col}"></i>')
    return ''.join(out)
G=[.353,.38,.422,.714]
sam=[(.12,.16,5,8),(.353,.07,6,12),(.42,.05,8,15),(.55,.12,3,7),(.714,.1,8,13),(.82,.18,5,8),(.95,.04,2,6)]
chr_=[(.08,.12,3,7),(.36,.08,4,10),(.422,.04,4,14),(.62,.12,3,8),(.714,.06,6,12),(.88,.14,3,7)]
jor=[(.05,.08,2,6),(.27,.1,3,8),(.43,.05,4,12),(.714,.04,3,9),(.76,.08,3,7)]
PH=.428+.007
css2='''
.nav .tri{display:flex;align-items:center;height:36px;padding:0 10px 0 6px;border-radius:18px;background:rgba(30,30,36,.72);backdrop-filter:blur(20px);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.14)}
.nav .tri .av{margin-right:-7px;box-shadow:0 0 0 2px #1c1c22}
.nav .tri .av:last-child{margin-right:0}
.pin{position:absolute;left:0;right:0;top:104px;height:136px;z-index:20;background:linear-gradient(#050506 86%,rgba(5,5,6,0))}
.pin .rd{position:absolute;left:16px;right:16px;top:0;display:flex;justify-content:space-between;align-items:center}
.rd .now{font:600 11.5px/1 var(--f-ui);color:var(--text-2)}
.rd .now b{font:700 20px/1 var(--f-cond);color:var(--text);margin-right:6px;letter-spacing:.3px}
.rd .sc{font:700 13px/1 var(--f-cond);letter-spacing:.8px;color:var(--text-2)}.rd .sc b{color:var(--text)}
.trks{position:absolute;left:16px;right:16px;top:30px;height:98px}
.tr{position:absolute;left:0;right:0;height:22px}
.tr .nm{position:absolute;left:0;bottom:0;font:700 10.5px/1 var(--f-ui);letter-spacing:.2px;width:46px;display:flex;align-items:center;gap:5px}
.tr .nm i{width:6px;height:6px;border-radius:50%}
.tr .base{position:absolute;left:48px;width:__Wpx;bottom:3px;height:1.5px;background:var(--line-2);border-radius:1px}
.tr .tk{position:absolute;bottom:4px;width:2px;border-radius:1px;margin-left:48px}
.gl{position:absolute;top:0;width:9px;height:9px;margin-left:44px;border-radius:50%%;box-shadow:0 0 0 1.5px #050506}
.gline{position:absolute;top:8px;bottom:14px;width:0;border-left:1px dashed rgba(255,255,255,.18);margin-left:48px}
.head{position:absolute;top:2px;bottom:14px;width:1.5px;margin-left:48px;background:#fff;box-shadow:0 0 8px rgba(255,255,255,.5)}
.knob{position:absolute;top:-3px;width:10px;height:10px;margin-left:44px;border-radius:50%;background:#fff;box-shadow:0 0 0 3px #050506}
.ph-l{position:absolute;bottom:0;font:600 8.5px/1 var(--f-ui);letter-spacing:1.2px;color:var(--text-3);transform:translateX(-50%%);margin-left:48px;white-space:nowrap}
.feed{position:absolute;left:0;right:0;top:244px;bottom:0;overflow:hidden;z-index:5}
.feed:after{content:"";position:absolute;left:0;right:0;bottom:0;height:60px;background:linear-gradient(rgba(5,5,6,0),#050506 92%);z-index:9}
.spine{position:absolute;left:70px;top:0;bottom:0;width:1.5px;background:var(--line-2);margin-left:-.75px}
.row{position:absolute;left:0;right:0}
.min{position:absolute;left:10px;width:46px;text-align:right;top:13px}
.min b{display:block;font:700 22px/1 var(--f-cond);color:var(--text)}
.min i{display:block;font:500 9px/1 var(--f-mono);color:var(--text-3);margin-top:4px}
.node{position:absolute;left:64px;top:17px;width:13px;height:13px;border-radius:50%%}
.node.q{background:#d8456b;box-shadow:0 0 0 3px #050506,0 0 0 4px rgba(216,69,107,.5)}
.node.h{background:#050506;box-shadow:0 0 0 1.5px var(--text-3);top:7px}
.card{position:absolute;left:90px;right:16px;border-radius:18px;background:var(--surface);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.09);padding:12px}
.hd{display:flex;justify-content:space-between;align-items:flex-start}
.tag{font:700 9.5px/1 var(--f-ui);letter-spacing:1.5px;text-transform:uppercase;color:#ff8fa8}
.sc2{font:700 24px/.9 var(--f-cond);letter-spacing:.4px;white-space:nowrap}
.sc2 small{font:600 10px/1 var(--f-ui);letter-spacing:1.2px;color:var(--text-3);margin-right:5px;vertical-align:3px}.sc2 .l{color:var(--text-3)}
.card h3{font:600 17px/1.15 var(--f-tight);letter-spacing:-.2px;margin-top:7px}
.card p{font:400 12px/1.35 var(--f-ui);color:var(--text-2);margin-top:3px}
.best{display:flex;align-items:center;gap:7px;font:600 12px/1 var(--f-ui);margin-top:11px;color:#f4e04d}
.fp{position:relative;border-radius:12px;overflow:hidden;margin-top:8px;height:140px}
.fp .th{border-radius:0;box-shadow:none}
.fp .scr{position:absolute;inset:0;background:linear-gradient(0deg,rgba(0,0,0,.85),rgba(0,0,0,.1) 55%,transparent)}
.fp .who{position:absolute;left:8px;top:8px;display:flex;align-items:center;gap:6px;height:24px;padding:0 9px 0 4px;border-radius:12px;background:rgba(20,20,24,.72);backdrop-filter:blur(12px);font:600 11px/1 var(--f-ui)}
.fp .cap{position:absolute;left:10px;right:10px;bottom:9px;display:flex;justify-content:space-between;align-items:flex-end}
.fp .cap b{display:block;font:700 16px/1 var(--f-cond);letter-spacing:.4px;color:#fff2a6}
.fp .cap span{display:block;font:500 10px/1.3 var(--f-ui);color:rgba(255,255,255,.82);margin-top:3px}
.pill{display:flex;align-items:center;gap:5px;height:26px;padding:0 10px;border-radius:13px;font:600 10.5px/1 var(--f-ui);background:rgba(30,30,36,.7);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.22);color:#fff}
.strip{display:flex;gap:6px;margin-top:10px}
.strip .it{flex:1;min-width:0}
.strip .th{width:100%%!important}
.strip .t{font:500 8px/1 var(--f-mono);color:var(--text-2);margin-top:5px;text-align:center;letter-spacing:-.2px}
.it.sel .th{box-shadow:0 0 0 1.5px #121215,0 0 0 3px #f4e04d}.it.sel .t{color:#f4e04d;font-weight:600}
.more{display:flex;align-items:center;justify-content:center;font:700 14px/1 var(--f-cond);color:var(--text-2);background:var(--raised);height:44px;border-radius:8px}
.leg{display:flex;gap:12px;margin-top:11px;font:500 11px/1 var(--f-ui);color:var(--text-2);align-items:center}
.leg span{display:flex;align-items:center;gap:5px}.leg i{width:7px;height:7px;border-radius:50%%}
.leg b{color:var(--text);font-weight:600}
.www{left:90px;right:16px;border-radius:18px;background:var(--surface);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.09);padding:12px 12px 12px;position:absolute}
.www .h{display:flex;justify-content:space-between;align-items:baseline}
.www .cols{display:flex;margin-top:10px}
.www .c{flex:1;min-width:0}
.www .c .p{display:flex;align-items:center;gap:6px;font:600 12px/1 var(--f-tight)}
.www .c .s{font:700 18px/1 var(--f-cond);letter-spacing:.3px;margin-top:8px;color:var(--text)}
.www .c .d{font:500 10px/1.3 var(--f-ui);color:var(--text-3);margin-top:3px}
.bowl{margin-top:10px;height:5px;border-radius:3px;background:linear-gradient(90deg,#1c1c22,#24242a);position:relative}
.bowl i{position:absolute;top:-2px;width:9px;height:9px;border-radius:50%%;box-shadow:0 0 0 1.5px #121215}
'''.replace('%%','%').replace('__W',str(W-48))
CSS2=css2
trk=''
names=[('Sam',SAM,sam,1),('Chris',CHR,chr_,2),('Jordan',JOR,jor,3)]
for i,(n,c,cl,sd) in enumerate(names):
    trk+=f'<div class="tr" style="top:{14+i*26}px"><div class="nm" style="color:{c}"><i style="background:{c}"></i>{n}</div><i class="base"></i>{ticks(sd*7,c,cl)}</div>'
gl=''.join(f'<i class="gline" style="left:{round(g*W)}px"></i>' for g in G)
gd=''.join(f'<i class="gl" style="left:{round(g*W)}px;background:{"#d8456b" if k==2 else "#2f6bff"}"></i>' for k,g in enumerate(G))
phx=round(PH*W)
labs=''.join(f'<span class="ph-l" style="left:{round(f*W)}px">{t}</span>' for f,t in [(.2,'1ST HALF'),(.5,'HT'),(.72,'2ND HALF'),(.95,'AFTER')])
cl=lambda n:COL[n]
def dt(n,k,t,sel=False):
    return f'<div class="it {"sel" if sel else ""}">{ph(40,44,k,extra=f"<i class=dot style=background:{COL[n]}></i>")}<div class="t">{t}</div></div>'
strip=dt('Jordan','crowd','12:45:24')+dt('Chris','play','12:45:31',True)+dt('Sam','wide','12:45:47')+dt('Sam','playR','12:46:02')+dt('Jordan','crowdR','12:46:19')+'<div class="it"><div class="more">+4</div><div class="t">more</div></div>'
body2=f'''<div class="nav"><div class="btn-circle glass">{BACK}</div><div class="bug"><span class="t">QAT</span><b class="dim">1</b><i class="sep"></i><span class="t">BIH</span><b>3</b><i class="sep"></i><span class="fin">FINAL</span></div><div class="tri">{av('Sam',24,fs=9)}{av('Chris',24,fs=9)}{av('Jordan',24,fs=9)}</div></div>
<div class="pin"><div class="rd"><div class="now"><b>42'</b>12:45 PM PT · Together, 9 photos here</div><div class="sc"><b>BIH 2</b> – QAT 1</div></div>
<div class="trks">{trk}{gl}{gd}<i class="head" style="left:{phx}px"></i><i class="knob" style="left:{phx}px"></i>{labs}</div></div>
<div class="feed"><div class="spine"></div>
<div class="abs" style="left:90px;right:16px;top:6px;display:flex;align-items:center;gap:8px;font:500 11.5px/1 var(--f-ui);color:var(--text-3)"><span>8 quiet minutes · no photos</span><i style="flex:1;border-top:1px dashed var(--line-2)"></i></div>
<div class="row" style="top:36px"><div class="min"><b>42'</b><i>12:45</i></div><div class="node q"></div>
 <div class="card" style="top:0;height:352px;box-shadow:inset 0 0 0 .5px rgba(244,224,77,.32)"><div class="hd"><span class="tag">Goal · Qatar</span><span class="sc2"><small>BIH</small>2<span class="l"> – </span>1<small style="margin:0 0 0 5px">QAT</small></span></div>
 <h3>Hassan Al Haydos</h3><p>From very close range</p>
 <div class="best"><svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.8l2.7 6 6.5.6-4.9 4.4 1.5 6.4L12 16.6l-5.8 3.6 1.5-6.4L2.8 9.4l6.5-.6z"/></svg>Chris took the best one</div>
 <div class="fp">{ph(263,140,'play',style='')}<div class="scr"></div><div class="who">{av('Chris',16,fs=7)}Chris</div>
  <div class="cap"><div><b>12:45:31 PM</b><span>11 seconds after the goal</span></div><div class="pill">{SHARE.format(s=12)}Share</div></div></div>
 <div class="strip">{strip}</div>
 <div class="leg"><span><b>9 photos</b></span><span><i style="background:{SAM}"></i>Sam 4</span><span><i style="background:{CHR}"></i>Chris 3</span><span><i style="background:{JOR}"></i>Jordan 2</span></div></div></div>
<div class="www" style="top:408px;height:104px"><div class="h"><span class="eyebrow">Who was where</span><span class="eyebrow" style="letter-spacing:1.2px">LUMEN FIELD</span></div>
 <div class="cols"><div class="c"><div class="p">{av('Sam',18,fs=7)}Sam</div><div class="s">Sec 121</div><div class="d">Row 14, near the goal</div></div>
 <div class="c"><div class="p">{av('Chris',18,fs=7)}Chris</div><div class="s">Sec 108</div><div class="d">Lower, by the corner</div></div>
 <div class="c"><div class="p">{av('Jordan',18,fs=7)}Jordan</div><div class="s">Sec 312</div><div class="d">Upper, halfway line</div></div></div>
</div>
<div class="row" style="top:536px"><div class="min"><b>HT</b><i>12:51</i></div><div class="node h"></div><div class="card" style="top:0;height:90px"><span class="tag" style="color:var(--text-2)">Halftime</span><h3 style="font-size:15px">Qatar 1, Bosnia and Herzegovina 3</h3></div></div>
</div>'''
write('v2-together-report.html','Together report',css2,body2)

# ============================================================ V3 sheet
css3='''
.bgfeed{position:absolute;inset:0;filter:blur(3px) brightness(.5);opacity:.9}
.dim{position:absolute;inset:0;background:rgba(0,0,0,.5)}
.sheet{position:absolute;left:0;right:0;top:92px;bottom:0;border-radius:28px 28px 0 0;background:#101014;box-shadow:inset 0 .5px 0 rgba(255,255,255,.16),0 -20px 60px rgba(0,0,0,.6);overflow:hidden}
.grab{position:absolute;left:50%;top:8px;width:38px;height:5px;margin-left:-19px;border-radius:3px;background:rgba(255,255,255,.22)}
.sh{position:absolute;left:16px;right:16px;top:28px;display:flex;justify-content:space-between;align-items:flex-start}
.sh h2{font:400 29px/1 var(--f-serif);letter-spacing:-.3px}
.sh .sub{font:400 12.5px/1.35 var(--f-ui);color:var(--text-2);margin-top:6px}
.sh .x{width:30px;height:30px;border-radius:50%;background:rgba(255,255,255,.1);display:flex;align-items:center;justify-content:center;flex:none}
.vis{position:absolute;left:16px;right:16px;top:100px;display:flex;align-items:center;gap:8px;font:500 11.5px/1 var(--f-ui);color:var(--text-2)}
.vis .a{display:flex}.vis .a .av{margin-right:-6px;box-shadow:0 0 0 2px #101014}
.chips{position:absolute;left:16px;right:16px;top:132px;display:flex;gap:8px}
.chip{height:30px;padding:0 12px;border-radius:15px;display:flex;align-items:center;gap:6px;font:600 12px/1 var(--f-ui);background:rgba(255,255,255,.07);color:var(--text-2)}
.chip.on{background:var(--text);color:#111}
.chip small{font:600 11px/1 var(--f-ui);opacity:.65}
.grid{position:absolute;left:16px;right:16px;top:176px}
.gh{display:flex;justify-content:space-between;align-items:baseline;height:26px;padding-top:2px}
.gh span{font:600 9.5px/1 var(--f-ui);letter-spacing:1.5px;text-transform:uppercase;color:var(--text-3)}
.gh em{font:500 10.5px/1 var(--f-ui);font-style:normal;color:var(--text-3)}
.gr{display:grid;grid-template-columns:repeat(4,1fr);gap:4px}
.tile{position:relative;aspect-ratio:1;border-radius:8px;overflow:hidden}
.tile .th{width:100%!important;height:100%!important;border-radius:0}
.tile .tm{position:absolute;left:5px;bottom:5px;font:600 8.5px/1 var(--f-mono);color:#fff;text-shadow:0 1px 3px rgba(0,0,0,.8)}
.tile .ck{position:absolute;right:5px;top:5px;width:20px;height:20px;border-radius:50%;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.85);background:rgba(0,0,0,.18)}
.tile.on{box-shadow:inset 0 0 0 2.5px var(--signal)}
.tile.on:after{content:"";position:absolute;inset:0;box-shadow:inset 0 0 0 2.5px var(--signal);border-radius:8px}
.tile.on .ck{background:var(--signal);box-shadow:none;display:flex;align-items:center;justify-content:center}
.tile:not(.on) .th{filter:brightness(.8)}
.bar{position:absolute;left:0;right:0;bottom:0;height:176px;background:linear-gradient(rgba(16,16,20,0),#101014 26%);padding:46px 16px 0}
.note{display:flex;gap:10px;font:400 11.5px/1.4 var(--f-ui);color:var(--text-2);margin-bottom:12px}
.note svg{flex:none;margin-top:1px}.note b{color:var(--text);font-weight:600}
'''
def tile(k,t,on,n=None):
    return f'<div class="tile {"on" if on else ""}">{ph(88,88,k)}<span class="tm">{t}</span><span class="ck">{CHECK if on else ""}</span></div>'
KS=['play','crowd','wide','playR','bowlR','mid','pair','crowdR','playL','tunnel','seats','grass','bowl','crowdL','play','bowlL']
KS[2:]=['wide','playR','pair','mid','crowdR','playL','tunnel','seats','crowdL','grass','bowl','bowlL','crowd','playR']
times=['12:29:12','12:29:40','12:30:05','12:33:40','12:34:15','12:34:51','12:45:41','12:45:47','12:46:02','12:46:19','12:46:44','12:47:30','12:48:05','12:52:10','1:13:22','1:14:02']
offs={3,7,12,14}
t1=''.join(tile(KS[i%len(KS)] if i!=0 else 'play',times[i],i not in offs) for i in range(16))
KS2=['bowl','sky','grass','crowdL','seats','bowlL','tunnel','mid']
t2=''.join(tile(KS2[i],['2:01:10','2:02:44','2:04:30','2:06:15','2:09:02','2:10:40','2:14:18','2:18:50'][i],False) for i in range(8))
bg=''.join(f'<i class="abs" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;border-radius:14px;background:#17171c"></i>' for x,y,w,h in [(16,120,361,160),(16,300,361,200),(16,520,361,180)])
body3=f'''<div class="bgfeed"><div class="abs" style="left:0;right:0;top:0;height:852px;background:#0b0b0d"></div>{ph(361,200,'wide',style='position:absolute;left:16px;top:300px;border-radius:14px')}{ph(361,160,'bowl',style='position:absolute;left:16px;top:120px;border-radius:14px')}{ph(361,180,'crowd',style='position:absolute;left:16px;top:520px;border-radius:14px')}</div><div class="dim"></div>
<div class="sheet"><div class="grab"></div>
<div class="sh"><div><h2>Pick photos to share</h2><div class="sub">Qatar 1, Bosnia and Herzegovina 3 · 104 on your phone</div></div><span class="x">{CLOSE.replace('width="20" height="20"','width="14" height="14"')}</span></div>
<div class="vis"><span class="a">{av('Chris',20,fs=8)}{av('Jordan',20,fs=8)}</span><span style="margin-left:6px">Visible to Chris and Jordan</span></div>
<div class="chips"><span class="chip on">Suggested <small>16</small></span><span class="chip">During play <small>38</small></span><span class="chip">All <small>104</small></span></div>
<div class="grid"><div class="gh"><span>Near the goals</span><em>12 selected</em></div><div class="gr">{t1}</div><div class="gh" style="margin-top:6px"><span>Second half</span><em>0 selected</em></div><div class="gr">{t2}</div></div>
<div class="bar"><div class="note">{LOCK}<div><b>Everyone sees only what each person shares.</b> Remove any time.</div></div><div class="btn pri">Share 12 of your 104 photos</div></div>
</div>'''
write('v3-pick-photos.html','Pick photos',css3,body3)

# ============================================================ V4 recap card
def rt(f,c,cl,sd):
    return ticks(sd,c,cl)
css4='''
.nav .tt{font:600 15px/1 var(--f-ui)}
.card{position:absolute;left:36px;right:36px;top:110px;height:566px;border-radius:26px;overflow:hidden;background:#0d0c0b;box-shadow:inset 0 0 0 .5px rgba(255,255,255,.14),0 24px 60px rgba(0,0,0,.6),0 0 80px rgba(255,181,71,.10);padding:20px 18px 0}
.card:before{content:"";position:absolute;inset:0;background:radial-gradient(80% 40% at 15% 0%,rgba(255,181,71,.16),transparent 70%),radial-gradient(60% 30% at 100% 100%,rgba(111,211,255,.10),transparent 70%)}
.card>*{position:relative}
.ey{display:flex;justify-content:space-between;font:600 9px/1 var(--f-ui);letter-spacing:1.5px;color:var(--text-3)}
.ey b{color:var(--signal);font-weight:700}
.card h1{font:400 33px/1 var(--f-serif);letter-spacing:-.4px;margin-top:12px}
.card h1 em{font-style:italic;color:var(--signal)}
.mos{display:grid;grid-template-columns:repeat(3,1fr);grid-template-rows:repeat(3,1fr);gap:4px;height:262px;margin-top:14px}
.mos .t{position:relative;border-radius:10px;overflow:hidden}
.mos .t .th{width:100%!important;height:100%!important;border-radius:0}
.mos .big{grid-column:1/3;grid-row:1/3}
.mos .wide{grid-column:1/4}
.mos .dot{width:10px;height:10px;right:6px;top:6px}
.mos .big .dot{width:12px;height:12px}
.mos .by{position:absolute;left:8px;bottom:8px;display:flex;align-items:center;gap:6px;height:22px;padding:0 9px 0 4px;border-radius:11px;background:rgba(15,15,18,.72);font:600 10px/1 var(--f-ui)}
.tl{position:relative;height:50px;margin-top:14px}
.tl .tr{position:absolute;left:0;right:0;height:14px}
.tl .base{position:absolute;left:0;right:0;bottom:2px;height:1px;background:rgba(255,255,255,.14)}
.tl .tk{position:absolute;bottom:3px;width:2px;border-radius:1px}
.tl .g{position:absolute;top:-2px;width:7px;height:7px;border-radius:50%;margin-left:-3px}
.cap{font:500 10.5px/1.3 var(--f-ui);color:var(--text-2);margin-top:5px}
.foot{position:absolute;left:18px;right:18px;bottom:0;height:98px;border-top:.5px solid var(--line-2);display:flex;align-items:center;gap:12px}
.foot .a{display:flex}.foot .a .av{margin-right:-8px;box-shadow:0 0 0 2.5px #0d0c0b}
.foot .n{font:600 13.5px/1.2 var(--f-tight);margin-left:6px}
.foot .n span{display:block;font:400 11px/1.2 var(--f-ui);color:var(--text-2);margin-top:3px}
.foot .st{margin-left:auto;text-align:right}
.foot .st b{font:700 30px/.9 var(--f-cond);color:var(--text);display:block}
.foot .st span{font:600 8.5px/1 var(--f-ui);letter-spacing:1.3px;color:var(--text-3)}
.mk{position:absolute;right:18px;top:20px;display:none}
.acts{position:absolute;left:16px;right:16px;top:698px;display:flex;gap:10px}
.acts .btn{flex:1}
.fine{position:absolute;left:24px;right:24px;top:760px;text-align:center;font:400 11.5px/1.4 var(--f-ui);color:var(--text-3)}
'''
def mt(cls,k,n):
    return f'<div class="t {cls}">{ph(10,10,k,extra=f"<i class=dot style=background:{COL[n]}></i>")}'+(f'<span class="by">{av(n,14,fs=6)}Chris, 12:45:31 PM</span>' if cls=='big' else '')+'</div>'
tl=''
for i,(n,c,cs,sd) in enumerate(names):
    s=ticks(sd*7,c,cs).replace('margin-left:48px','')
    tl+=f'<div class="tr" style="top:{8+i*14}px"><i class="base"></i>{s}</div>'
def scale(html):
    return html
tl2=''
W2=277
for i,(n,c,cs,sd) in enumerate(names):
    r=random.Random(sd*7);out=''
    for f,spread,cnt,h in cs:
        for _ in range(cnt):
            x=round((f+(r.random()-.5)*spread)*W2/3)*3
            if 0<=x<=W2: out+=f'<i class="tk" style="left:{x}px;height:{max(3,round(h*.6*(.5+r.random()*.6)))}px;background:{c}"></i>'
    tl2+=f'<div class="tr" style="top:{8+i*14}px"><i class="base"></i>{out}</div>'
gd2=''.join(f'<i class="g" style="left:{round(g*W2)}px;background:{"#d8456b" if k==2 else "#2f6bff"}"></i>' for k,g in enumerate(G))
body4=f'''<div class="nav"><div class="btn-circle glass">{BACK}</div><span class="tt">Together recap</span><div class="btn-circle glass" style="opacity:0"></div></div>
<div class="card"><div class="ey"><b>TOGETHER</b><span>WED JUN 24 2026 · LUMEN FIELD</span></div>
<h1>One night, <em>three phones.</em></h1>
<div class="mos">{mt('big','play','Chris')}{mt('','crowd','Jordan')}{mt('','playR','Sam')}{mt('','wide','Sam')}{mt('','pair','Jordan')}{mt('','mid','Chris')}</div>
<div class="tl">{tl2}{gd2}</div>
<div class="cap">Qatar 1, Bosnia and Herzegovina 3 · 66,925 there</div>
<div class="foot"><div class="a">{av('Sam',34,fs=12)}{av('Chris',34,fs=12)}{av('Jordan',34,fs=12)}</div><div class="n">Sam, Chris &amp; Jordan<span>Made with Witness</span></div><div class="st"><b>38</b><span>PHOTOS</span></div></div></div>
<div class="acts"><div class="btn pri">{SHARE.format(s=18)}Share card</div><div class="btn sec">Save image</div></div>
<div class="fine">The card shows only photos each of you chose to share.</div>'''
body4=body4.replace('<div class="mos">','<div class="mos">')
write('v4-recap-card.html','Together recap',css4,body4)
