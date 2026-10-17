import os, math, random
ROOT='/home/user/SportsApp/mockups/scan-waiting/features'
CHAMP='#d9c38f'
CSS='''
body.b{--b-text-3:rgba(255,255,255,.62)}
.cnt .n{display:flex;align-items:baseline;gap:10px}
.cnt .n b{font:800 40px/1 var(--b-cond);font-variant-numeric:tabular-nums;letter-spacing:.2px}
.cnt .n span{font:500 15px/1 var(--b-ui);color:rgba(255,255,255,.68)}
.cnt .n em{margin-left:auto;font:700 17px/1 var(--b-cond);letter-spacing:1px;text-transform:uppercase;color:#fff;font-style:normal}
.cnt .b-bar{margin-top:12px;height:4px}
.cnt .sub{margin-top:10px;font:500 13px/1.2 var(--b-ui);color:rgba(255,255,255,.68)}
.cnt .sub b{color:#fff;font-weight:700}
.priv{position:absolute;left:20px;right:20px;bottom:44px;display:flex;gap:8px;align-items:center;justify-content:center;font:500 13px/1.2 var(--b-ui);color:rgba(255,255,255,.62)}
.priv svg{width:14px;height:14px;stroke:currentColor;fill:none;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round;flex:none}
.empty{font:500 15px/1.4 var(--b-ui);color:rgba(255,255,255,.62)}
.num{width:30px;height:30px;border-radius:50%;display:grid;place-items:center;background:var(--c);color:#fff;font:800 15px/1 var(--b-cond);flex:none}
.num.dk{color:#111}
.num.pend{background:none;box-shadow:inset 0 0 0 2px rgba(255,255,255,.5);color:#fff}
.f-item .end.sc{font:800 20px/1 var(--b-cond);letter-spacing:.4px;font-variant-numeric:tabular-nums}
.f-item .end.mu{font:500 13px/1.2 var(--b-ui);color:rgba(255,255,255,.62)}
'''
LOCK='<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>'
PAUSE='<svg viewBox="0 0 24 24"><path d="M9 5v14M15 5v14"/></svg>'
CHECK='<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
def page(title, body, css='', nav_title='Scanning', right=PAUSE):
    return f'''<!doctype html><html><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="../../../kit/kit.css">
<link rel="stylesheet" href="../../../round2/system/broadcast.css">
<link rel="stylesheet" href="../../../final/system/final.css">
<style>{CSS}{css}</style></head>
<body class="phone b">
<div class="b-nav"><div class="f-title">{nav_title}</div><div class="b-icon-btn">{right}</div></div>
{body}
<div class="priv">{LOCK}Checked on this iPhone. Nothing leaves it.</div>
<script src="../../../kit/kit.js"></script></body></html>'''
def counter(c,t,month,sub=''):
    pct=c/t*100
    return f'''<div class="cnt"><div class="n"><b>{c:,}</b><span>of {t:,} photos</span><em>{month}</em></div>
<div class="b-bar"><i style="width:{pct:.1f}%;background:#fff"></i></div>{('<div class="sub">'+sub+'</div>') if sub else ''}</div>'''
def write(folder,name,html):
    d=os.path.join(ROOT,folder); os.makedirs(d,exist_ok=True)
    open(os.path.join(d,name),'w').write(html)
TOTAL=41280
CHC='#2f6bff';GB='#ffb612';CLE='#e31937';MIL='#ffc52f';CHI='#f05a1a'

# ---------------- 1 map ----------------
US=[(-124.7,48.4),(-117,49),(-95,49),(-95,49.4),(-89,48),(-84.5,46.5),(-82.5,45.3),(-82.4,43),(-83,42),(-79,43.2),(-76,44),(-75,45),(-71.5,45),(-69.2,47.4),(-67.8,47),(-67,44.8),(-70,43.7),(-70.7,42.7),(-70,41.7),(-72,41),(-74,40.5),(-74,39),(-75.5,38),(-76,37),(-75.7,35.5),(-77,34.5),(-79,33.3),(-81,31.5),(-80.2,28),(-80.2,25.5),(-81.2,25.2),(-82.7,27.5),(-82.8,29.5),(-84,30),(-85.5,29.7),(-88,30.3),(-89.5,30),(-89.3,29),(-91,29.2),(-93.8,29.7),(-97,27.8),(-97.2,25.9),(-99,26.4),(-101,29.7),(-103,29),(-104.7,30.2),(-106.5,31.8),(-108.2,31.8),(-111,31.3),(-114.8,32.5),(-117.1,32.5),(-118.5,34),(-120.6,34.6),(-121.9,36.6),(-122.5,37.7),(-123.8,39.5),(-124.3,40.4),(-124,42),(-124.5,43),(-124,46)]
# Michigan lakes cut-out approx (Lake Michigan) so the Great Lakes read
LAKE=[(-87.8,41.7),(-87.5,42.5),(-87.8,43.5),(-87.5,45),(-86.2,45.8),(-85.6,45),(-86.3,44),(-86.5,42.8),(-86.9,41.8)]
def inside(pt,poly):
    x,y=pt;c=False;n=len(poly)
    for i in range(n):
        x1,y1=poly[i];x2,y2=poly[(i+1)%n]
        if (y1>y)!=(y2>y) and x<(x2-x1)*(y-y1)/(y2-y1)+x1: c=not c
    return c
LON0,LON1,LATT=-108,-66,50.0
SX=393/(LON1-LON0);SY=SX/0.79
def proj(lon,lat): return ((lon-LON0)*SX,(LATT-lat)*SY)
def mapsvg(pins,h=300,top=0,spacing=7,glow=95,base=.2,extra=''):
    P=[proj(*p[:2]) for p in pins]
    dots=[]
    y=4
    row=0
    while y<h:
        x=3.5+(spacing/2 if row%2 else 0)
        while x<393:
            lon=LON0+x/SX;lat=LATT-y/SY
            if inside((lon,lat),US) and not inside((lon,lat),LAKE):
                d=min([math.hypot(x-px,y-py) for px,py in P] or [999])
                a=base+.7*max(0,1-d/glow)**1.4
                dots.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="1.6" fill="#fff" fill-opacity="{a:.2f}"/>')
            x+=spacing
        y+=spacing*0.86;row+=1
    return P,'\n'.join(dots)
def pin(p,n,color,dark=False,pulse=False):
    x,y=p
    r=f'<circle cx="{x:.1f}" cy="{y:.1f}" r="19" fill="none" stroke="{color}" stroke-width="2" opacity=".55"/>' if pulse else ''
    return f'''{r}<circle cx="{x:.1f}" cy="{y:.1f}" r="12.5" fill="{color}" stroke="#07080a" stroke-width="3"/>
<text x="{x:.1f}" y="{y+5:.1f}" text-anchor="middle" font-family="Barlow Condensed" font-weight="800" font-size="15" fill="{'#111' if dark else '#fff'}">{n}</text>'''
VEN=[(-87.63,41.95,CHC,'1',False),(-88.06,44.50,GB,'2',True),(-81.69,41.49,CLE,'3',False)]
def map_state(mid):
    pins=VEN if mid else []
    P,dots=mapsvg(pins)
    pp=''.join(pin(P[i],v[3],v[2],v[4],pulse=(i==2)) for i,v in enumerate(pins))
    svg=f'<svg style="position:absolute;left:0;top:104px" width="393" height="300" viewBox="0 0 393 300">{dots}{pp}</svg>'
    if mid:
        body=svg+'<div class="f-col" style="top:424px;gap:22px">'+counter(18930,TOTAL,'Mar 2019','<b>212</b> near a stadium')+'''
<div class="f-list">
<div class="f-item"><div class="num" style="--c:#2f6bff">1</div><div><div class="t">Wrigley Field</div><div class="s">Chicago, Oct 30, 2016</div></div><div class="end sc">CHC 3-2 CLE</div></div>
<div class="f-item"><div class="num dk" style="--c:#ffb612">2</div><div><div class="t">Lambeau Field</div><div class="s">Green Bay, Sep 9, 2018</div></div><div class="end sc">GB 24-23 CHI</div></div>
<div class="f-item"><div class="num" style="--c:#e31937">3</div><div><div class="t">Progressive Field</div><div class="s">Cleveland</div></div><div class="end mu">Matching game</div></div>
</div></div>'''
    else:
        body=svg+'<div class="f-col" style="top:424px;gap:22px">'+counter(1204,TOTAL,'Feb 2012','<b>0</b> near a stadium')+'<div class="empty">No venues yet. Pins land here as they are found.</div></div>'
    return page('Scan map',body)
write('scan-1','v1-early.html',map_state(False))
write('scan-1','v2-mid.html',map_state(True))

# done state
DONE=[(-87.63,41.95,CHC),(-88.06,44.50,GB),(-81.69,41.49,CLE),(-71.10,42.35,'#bd3039'),(-87.97,43.03,MIL),(-90.19,38.62,'#c41e3a'),(-73.93,40.83,'#ffffff'),(-83.05,42.34,'#ffffff'),(-93.26,44.97,'#7a5cff')]
P,dots=mapsvg(DONE,h=290,glow=60,base=.15)
arcs=''
hx,hy=P[0]
for (x,y) in P[1:]:
    mx=(hx+x)/2;my=min(hy,y)-30-abs(x-hx)*.12
    arcs+=f'<path d="M{hx:.1f} {hy:.1f} Q{mx:.1f} {my:.1f} {x:.1f} {y:.1f}" fill="none" stroke="#ffb547" stroke-width="1.6" stroke-opacity=".75"/>'
pp=''.join(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="7" fill="{DONE[i][2]}" stroke="#07080a" stroke-width="2.5"/>' for i,(x,y) in enumerate(P))
svg=f'<svg style="position:absolute;left:0;top:92px" width="393" height="290" viewBox="0 0 393 290">{dots}{arcs}{pp}</svg>'
body=svg+f'''<div class="f-col" style="top:400px;gap:24px">
<div class="f-stack" style="gap:8px"><div class="b-mega" style="font-size:150px">47</div><div style="font:700 26px/1 var(--b-cond);letter-spacing:.6px;text-transform:uppercase">Games in your photos</div></div>
<div class="f-stats"><div><b>9</b><span>Venues</span></div><div><b>41,280</b><span>Photos checked</span></div></div></div>
<div style="position:absolute;left:20px;right:20px;bottom:84px"><div class="b-btn" style="width:100%;height:54px;font-size:17px">Review games</div></div>'''
h=page('Scan done',body,css='.priv{display:none}',nav_title='Done',right=CHECK)
h=h.replace('<div class="b-icon-btn">','<div class="b-icon-btn" style="background:'+CHAMP+';box-shadow:none"><style>.b-icon-btn svg{}</style>',1).replace('stroke:#fff','stroke:#fff')
h=h.replace('</style></head>','.b-nav .b-icon-btn svg{stroke:#2a2112 !important}</style></head>')
write('scan-1','v3-done.html',h)

# ---------------- 2 timeline ----------------
def timeline(mid):
    rnd=random.Random(7)
    cur=(2019,3) if mid else (2012,2)
    games={(2016,10):CHC,(2018,9):GB} if mid else {}
    pend={(2017,7)} if mid else set()
    letters=''.join(f'<i>{c}</i>' for c in 'JFMAMJJASOND')
    rows=''
    for y in range(2012,2027):
        cells=''
        for m in range(1,13):
            if y==2012 and m==1 or (y==2026 and m>10):
                cells+='<u class="x"></u>';continue
            if (y,m)==cur: cls='cur'; st=''
            elif (y,m)<cur:
                d=rnd.random()**1.4; st=f'background:rgba(255,255,255,{.12+.42*d:.2f})'; cls=''
            else: cls='';st=''
            dot=''
            if (y,m) in games: dot=f'<s style="--c:{games[(y,m)]}"></s>'
            if (y,m) in pend: dot='<s class="pe"></s>'
            cells+=f'<u class="{cls}" style="{st}">{dot}</u>'
        yl='on' if y==cur[0] else ''
        rows+=f'<b class="{yl}">{y}</b>{cells}'
    css='''
.tl{display:grid;grid-template-columns:36px repeat(12,1fr);gap:4px;align-items:center}
.tl i{font:700 12px/1 var(--b-cond);color:rgba(255,255,255,.62);text-align:center;font-style:normal;letter-spacing:.5px}
.tl b{font:700 13px/1 var(--b-cond);color:rgba(255,255,255,.62);letter-spacing:.6px}
.tl b.on{color:#fff}
.tl u{height:21px;border-radius:5px;background:rgba(255,255,255,.055);display:grid;place-items:center;text-decoration:none}
.tl u.x{background:none}
.tl u.cur{background:rgba(255,181,71,.28);box-shadow:inset 0 0 0 2px #ffb547}
.tl u s{width:11px;height:11px;border-radius:50%;background:var(--c);box-shadow:0 0 0 2px #07080a,0 0 12px var(--c)}
.tl u s.pe{background:none;box-shadow:inset 0 0 0 2px #fff}
'''
    if mid:
        tail='''<div class="f-list"><div class="f-item"><div class="b-bug"><span class="team" style="--c:#ffb612;color:#111">GB</span><span class="score">24</span><span class="score" style="background:rgba(255,255,255,.05)">23</span></div><div><div class="t">Lambeau Field</div><div class="s">Sep 9, 2018</div></div><div class="end b-small">3 venues</div></div></div>'''
        c=counter(18930,TOTAL,'Mar 2019','<b>212</b> near a stadium')
    else:
        tail='<div class="empty">No games yet. Game days light up as they are found.</div>'
        c=counter(1204,TOTAL,'Feb 2012','<b>0</b> near a stadium')
    body=f'<div class="f-col" style="top:112px;gap:26px"><div class="tl">{"<span></span>"}{letters}{rows}</div>{c}{tail}</div>'
    return page('Scan timeline',body,css)
write('scan-2','v1-early.html',timeline(False))
write('scan-2','v2-mid.html',timeline(True))

# ---------------- 3 tickets ----------------
def ticket(a,b,sa,sb,ca,cb,title,place,date,stamp,yr,color,z,top,rot,dkA=False):
    return f'''<div class="tk" style="top:{top}px;z-index:{z};transform:rotate({rot}deg)"><div class="main">
<div class="hd"><div class="b-bug"><span class="team" style="--c:{ca};{'color:#111' if dkA else ''}">{a}</span><span class="score">{sa}</span><span class="score" style="background:rgba(255,255,255,.05)">{sb}</span><span class="team" style="--c:{cb}">{b}</span></div><div class="dt">{date}</div></div>
<div class="bd"><div class="t">{title}</div><div class="p">{place}</div></div></div>
<div class="stub"><div class="stamp" style="--c:{color};transform:rotate({-rot*5-6}deg)"><b>{stamp}</b><span>{yr}</span></div></div></div>'''
def tickets(mid):
    css='''
.stack{position:absolute;left:20px;right:20px;top:112px;height:330px}
.tk{position:absolute;left:0;right:0;height:150px;display:flex;border-radius:14px;background:#14171d;box-shadow:inset 0 0 0 1px rgba(255,255,255,.12),0 10px 24px rgba(0,0,0,.55);
 -webkit-mask-image:radial-gradient(circle 10px at 277px 0,#0000 9.5px,#000 10px),radial-gradient(circle 10px at 277px 100%,#0000 9.5px,#000 10px);-webkit-mask-composite:source-in;mask-composite:intersect}
.tk .main{flex:1;padding:14px 16px;display:flex;flex-direction:column;justify-content:space-between}
.tk .hd{display:flex;align-items:center;justify-content:space-between;gap:10px}
.tk .dt{white-space:nowrap;font:700 13px/1 var(--b-cond);letter-spacing:.5px;text-transform:uppercase;color:rgba(255,255,255,.72)}
.tk .t{font:800 28px/.95 var(--b-cond);text-transform:uppercase;letter-spacing:.2px}
.tk .p{font:500 13px/1.2 var(--b-ui);color:rgba(255,255,255,.62);margin-top:6px}
.tk .stub{width:76px;border-left:2px dashed rgba(255,255,255,.18);display:flex;justify-content:center;align-items:flex-start;padding-top:6px}
.stamp{width:50px;height:50px;border-radius:50%;box-shadow:inset 0 0 0 2px var(--c),inset 0 0 0 4px #14171d,inset 0 0 0 5px var(--c);display:grid;align-content:center;justify-items:center;gap:2px;color:var(--c)}
.stamp b{font:800 15px/1 var(--b-cond);letter-spacing:.8px}
.stamp span{font:700 12px/1 var(--b-cond);letter-spacing:.5px}
.tk.ghost{background:rgba(255,255,255,.03);box-shadow:none;border:2px dashed rgba(255,255,255,.3);display:grid;place-items:center;text-align:center}
.tk.ghost .g{font:500 15px/1.4 var(--b-ui);color:rgba(255,255,255,.68)}
.tk.ghost .g b{display:block;font:800 22px/1 var(--b-cond);text-transform:uppercase;color:#fff;margin-bottom:6px;letter-spacing:.4px}
'''
    if mid:
        st=ticket('CHC','CLE',3,2,CHC,CLE,'World Series Game 5','Wrigley Field, Chicago','Oct 30, 2016','CHC',"'16",CHC,1,0,-1.2)
        st+=ticket('GB','CHI',24,23,GB,CHI,'Week 1','Lambeau Field, Green Bay','Sep 9, 2018','GB',"'18",GB,2,70,.9,dkA=True)
        st+='<div class="tk ghost" style="top:230px;height:86px;z-index:3;-webkit-mask-image:none"><div class="g"><b>Progressive Field</b>Cleveland. Matching the game.</div></div>'
        top=f'<div class="stack">{st}</div>'
        stats='<div class="f-stats"><div><b>212</b><span>Near a stadium</span></div><div><b>3</b><span>Venues</span></div><div><b>2</b><span>Games</span></div></div>'
        c=counter(18930,TOTAL,'Mar 2019')
    else:
        top='<div class="stack"><div class="tk ghost" style="top:0;-webkit-mask-image:none"><div class="g"><b>No games yet</b>Your first ticket lands here.</div></div></div>'
        stats='<div class="f-stats"><div><b>0</b><span>Near a stadium</span></div><div><b>0</b><span>Venues</span></div><div><b>0</b><span>Games</span></div></div>'
        c=counter(1204,TOTAL,'Feb 2012')
    body=top+f'<div class="f-col" style="top:486px;gap:26px">{c}{stats}</div>'
    return page('Scan tickets',body,css)
write('scan-3','v1-early.html',tickets(False))
write('scan-3','v2-mid.html',tickets(True))

# ---------------- 4 radar ----------------
def radar(mid):
    cx,cy=196.5,262
    blips=''
    if mid:
        for (x,y,c) in [(cx-92,cy-58,CHC),(cx+70,cy-82,GB),(cx+112,cy+30,CLE)]:
            blips+=f'<circle cx="{x}" cy="{y}" r="15" fill="{c}" opacity=".22"/><circle cx="{x}" cy="{y}" r="6" fill="{c}" stroke="#fff" stroke-width="2"/>'
    svg=f'''<svg style="position:absolute;left:0;top:96px" width="393" height="330" viewBox="0 0 393 330">
<g transform="translate(0,-96)" fill="none" stroke="rgba(255,255,255,.2)" stroke-width="1.5">
<ellipse cx="{cx}" cy="{cy}" rx="168" ry="130"/>
<ellipse cx="{cx}" cy="{cy}" rx="132" ry="100" stroke="rgba(255,255,255,.14)"/>
<ellipse cx="{cx}" cy="{cy}" rx="96" ry="70" stroke="rgba(255,255,255,.28)"/>
<path d="M{cx} {cy+42} L{cx+52} {cy} L{cx} {cy-42} L{cx-52} {cy} Z" stroke="rgba(255,255,255,.34)"/>
<path d="M{cx-168} {cy}H{cx+168}M{cx} {cy-130}V{cy+130}" stroke="rgba(255,255,255,.07)"/>
</g>
<g transform="translate(0,-96)">{blips}</g></svg>
<div style="position:absolute;left:{cx-168}px;top:{96+cy-96-130}px;width:336px;height:260px;border-radius:50%;background:conic-gradient(from 20deg,rgba(255,255,255,0) 0deg,rgba(255,255,255,0) 250deg,rgba(255,255,255,.04) 300deg,rgba(255,255,255,.22) 360deg);-webkit-mask:radial-gradient(ellipse at center,#000 69%,transparent 71%);transform-origin:50% 50%"></div>
<div style="position:absolute;left:{cx-1}px;top:{cy-130}px;width:2px;height:0"></div>'''
    near=212 if mid else 0
    css='''
.mid{position:absolute;left:0;right:0;top:%dpx;text-align:center}
.mid b{display:block;font:800 40px/1 var(--b-cond);font-variant-numeric:tabular-nums}
.mid span{display:block;margin-top:4px;font:500 13px/1 var(--b-ui);color:rgba(255,255,255,.68)}
.big{position:absolute;left:20px;right:20px;top:438px;text-align:center}
.big b{display:block;font:800 76px/.9 var(--b-cond);font-variant-numeric:tabular-nums;letter-spacing:-.5px}
.big span{display:block;margin-top:8px;font:500 16px/1 var(--b-ui);color:rgba(255,255,255,.68)}
.big .b-bar{margin:18px auto 0;width:220px;height:4px}
.fact{position:absolute;left:20px;right:20px;top:640px;display:flex;gap:10px;justify-content:center;align-items:center;font:500 16px/1.3 var(--b-ui);color:#fff;text-align:center}
.fact svg{width:18px;height:18px;stroke:#fff;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;flex:none;opacity:.8}
.last{position:absolute;left:20px;right:20px;top:690px;text-align:center;font:500 13px/1.3 var(--b-ui);color:rgba(255,255,255,.62)}
.last b{color:#fff;font-weight:700}
''' % (cy-96+8-22+96-96+0)
    # center label sits in the inner field
    css+=f'.mid{{top:{cy-24+0}px}}'
    c,t=(18930,TOTAL) if mid else (1204,TOTAL)
    pct=c/t*100
    cal='<svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="15" rx="2.5"/><path d="M4 10h16M9 3v4M15 3v4"/></svg>'
    chk='<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
    fact='Checking dates against real schedules'
    last=f'Latest find: <b>Progressive Field</b>, Cleveland' if mid else 'Scanning Feb 2012'
    body=svg+f'''<div class="mid"><b>{near}</b><span>near a stadium</span></div>
<div class="big"><b>{c:,}</b><span>of {t:,} photos{' · Mar 2019' if mid else ''}</span><div class="b-bar"><i style="width:{pct:.1f}%;background:#fff"></i></div></div>
<div class="fact">{chk}{fact}</div><div class="last">{last}</div>'''
    return page('Scan radar',body,css)
write('scan-4','v1-early.html',radar(False))
write('scan-4','v2-mid.html',radar(True))
