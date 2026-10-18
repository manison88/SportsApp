#!/usr/bin/env python3
import os
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'features/mosaic')
P='../../../photos/'
IMG=['wrigley-night','soldier-skyline','fenway-night','lambeau-concourse','soldier-soccer','wrigley-bleachers','fenway-day','united-center-court','wrigley-scoreboard','lambeau-exterior','camp-nou-aerial','wrigley-night-2','fenway-postcard','soldier-aerial','wrigley-scoreboard-wide']
def im(i,cls='',st=''): return f'<div class="p {cls}" style="background-image:url({P}{IMG[i%len(IMG)]}.jpg);{st}"></div>'

CSS='''
html,body{margin:0;background:#000}
.phone{position:relative;width:393px;height:852px;overflow:hidden;background:#050506;color:#f5f1ea;font-family:-apple-system,Inter,sans-serif}
.cover{position:absolute;left:0;right:0;top:0;height:CH;background:url(../../../photos/soldier-skyline.jpg) center 30%/cover}
.cover::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,6,.7),rgba(5,5,6,0) 30%),linear-gradient(0deg,#050506 0,rgba(5,5,6,.85) 30%,rgba(5,5,6,0) 70%)}
.sb{position:absolute;top:18px;left:30px;right:30px;display:flex;justify-content:space-between;font:600 15px Inter,sans-serif;z-index:6}
.nav{position:absolute;top:56px;left:16px;right:16px;display:flex;justify-content:space-between;z-index:6}
.nav .r{display:flex;gap:10px}
.c{width:40px;height:40px;border-radius:50%;background:rgba(18,18,22,.55);backdrop-filter:blur(14px);border:1px solid rgba(255,255,255,.16);display:flex;align-items:center;justify-content:center}
.c svg{width:19px;height:19px;stroke:#fff;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
.c.more svg{fill:#fff;stroke:none}
.c.play{background:#fff}.c.play svg{fill:#050506;stroke:none;margin-left:2px}
.info{position:absolute;left:20px;right:20px;top:calc(CH - 128px);z-index:4}
.ln{display:flex;justify-content:space-between;align-items:baseline;font:800 SZpx/.94 "Barlow Condensed","Arial Narrow",sans-serif;text-transform:uppercase}
.meta{display:flex;align-items:center;margin-top:10px;font:500 13.5px -apple-system,Inter,sans-serif;color:rgba(245,241,234,.64)}
.meta .v{color:#ffb547;font-weight:600;display:flex;align-items:center;gap:6px}
.meta svg{width:16px;height:16px;stroke:#ffb547;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}
.meta .y{margin-left:auto;display:flex}
.meta .y svg{width:24px;height:24px}
.tabs{position:absolute;left:16px;right:16px;bottom:20px;height:68px;border-radius:34px;background:rgba(28,28,32,.92);border:1px solid rgba(255,255,255,.1);display:flex;align-items:center;justify-content:space-around;z-index:9;font:600 11px Inter,sans-serif;color:#cfcac0}
.tabs span{display:flex;flex-direction:column;align-items:center;gap:4px}
.tabs .on{color:#fff}
.tabs i{width:22px;height:20px;border-radius:5px;background:#cfcac0;display:block}
.tabs .on i{background:#fff}
.body{position:absolute;left:0;right:0;top:BT;bottom:0;overflow:hidden}
.fade{position:absolute;left:0;right:0;bottom:0;height:120px;background:linear-gradient(0deg,#050506 25%,rgba(5,5,6,0));z-index:7;pointer-events:none}
.p{background-size:cover;background-position:center;border-radius:6px}
.sec{display:flex;align-items:baseline;justify-content:space-between;padding:0 20px;margin-bottom:10px;font:800 17px "Barlow Condensed",sans-serif;letter-spacing:.5px;text-transform:uppercase}
.sec small{font:600 12px Inter,sans-serif;color:rgba(245,241,234,.4);margin-left:8px;letter-spacing:1px}
.sec a{font:600 13px Inter,sans-serif;color:#ffb547;text-transform:none;letter-spacing:0}
'''
IC={'back':'<path d="M15 5l-7 7 7 7"/>','play':'<path d="M7 4.5v15l13-7.5z"/>','more':'<circle cx="5.5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="18.5" cy="12" r="1.6"/>','bld':'<path d="M3 9.5 12 4l9 5.5M4.5 20h15M6 10.5v7M10 10.5v7M14 10.5v7M18 10.5v7"/>','ywt':'<path d="M2 12h4l2.5-6 4 13 3-9 1.5 2H22"/>'}
def svg(n): return f'<svg viewBox="0 0 24 24">{IC[n]}</svg>'

def page(title,body,ch=330,sz=44,bt=None,ib=16,extra=''):
    bt=bt or ch+14
    css=CSS.replace('CH',f'{ch}px').replace('IB',f'{ib}px').replace('SZ',str(sz)).replace('BT',f'{bt}px')
    return f'''<!doctype html><html><head><meta charset="utf-8"><title>{title}</title><link rel="stylesheet" href="../../../kit/kit.css"><style>{css}{extra}</style></head><body>
<div class="phone"><div class="cover"></div>
<div class="sb"><span>9:41</span><span>●●● 100</span></div>
<div class="nav"><div class="c">{svg('back')}</div><div class="r"><div class="c play">{svg('play')}</div><div class="c more">{svg('more')}</div></div></div>
<div class="info"><div class="ln"><span>Toronto</span><span>8</span></div><div class="ln"><span>New York</span><span style="color:rgba(245,241,234,.64)">5</span></div>
<div class="meta"><span class="v">{svg('bld')}Rogers Centre</span><span>&nbsp;, Jun 12, 2026</span><span class="y" style="color:#ffb547"><svg viewBox="0 0 24 24" style="stroke:#ffb547;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round">{IC['ywt']}</svg></span></div></div>
<div class="body">{body}</div><div class="fade"></div>
<div class="tabs"><span class="on"><i></i>Timeline</span><span><i style="border-radius:50%"></i>Map</span><span><i></i>Passport</span><span><i style="border-radius:50%"></i>You</span></div>
</div><script>window.__ready=true</script></body></html>'''

def w(n,t,html): open(f'{OUT}/{n}.html','w').write(html)

# 1 hero + 2-col grid
b='<div class="sec"><span>Photos<small>54</small></span><a>See all</a></div><div style="padding:0 20px;display:grid;grid-template-columns:1fr 1fr;gap:6px">'
b+=im(0,st='grid-column:span 2;height:190px')+''.join(im(i,st='height:130px') for i in range(1,5))+'</div>'
w('v1-hero-grid','',page('1 · Hero + grid',b))

# 2 bento
b='<div class="sec"><span>Photos<small>54</small></span><a>See all</a></div><div style="padding:0 20px;display:grid;grid-template-columns:repeat(3,1fr);grid-auto-rows:92px;gap:5px">'
b+=im(0,st='grid-column:span 2;grid-row:span 2')+im(2)+im(4)+im(1,st='grid-row:span 2')+im(3,st='grid-column:span 2')+im(5)+im(6)+im(7,st='grid-column:span 2')+'</div>'
w('v2-bento','',page('2 · Bento mosaic',b))

# 3 justified rows
def row(items,h): return f'<div style="display:flex;gap:4px;height:{h}px;margin-bottom:4px">'+''.join(im(i,st=f'flex:{f};border-radius:4px') for i,f in items)+'</div>'
b='<div class="sec"><span>Photos<small>54</small></span><a>See all</a></div><div style="padding:0 16px">'+row([(0,1.6),(2,1)],140)+row([(4,1),(1,1.5),(3,1.2)],110)+row([(5,1.3),(6,1)],130)+row([(7,1),(8,1),(9,1)],100)+'</div>'
w('v3-justified-rows','',page('3 · Justified rows',b))

# 4 hero + filmstrip + +48
b='<div style="padding:0 20px"><div class="sec" style="padding:0"><span>Best of the night</span><a>See all 54</a></div>'
b+=im(0,st='height:170px;border-radius:14px')+'<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin-top:6px">'
b+=''.join(im(i,st='height:82px') for i in range(1,4))+'<div style="position:relative">'+im(4,st='height:82px;filter:brightness(.45)')+'<span style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font:800 22px Barlow Condensed">+49</span></div></div></div>'
w('v4-hero-strip','',page('4 · Hero + strip',b))

# 5 collage mixed, full-bleed tight
b='<div style="display:grid;grid-template-columns:repeat(6,1fr);grid-auto-rows:64px;gap:2px">'
b+=im(0,st='grid-column:span 4;grid-row:span 3;border-radius:0')+im(2,st='grid-column:span 2;grid-row:span 2;border-radius:0')+im(4,st='grid-column:span 2;border-radius:0')
b+=im(1,st='grid-column:span 2;grid-row:span 2;border-radius:0')+im(3,st='grid-column:span 2;border-radius:0')+im(5,st='grid-column:span 2;border-radius:0')+im(6,st='grid-column:span 2;border-radius:0')+im(7,st='grid-column:span 2;grid-row:span 2;border-radius:0')+im(8,st='grid-column:span 4;border-radius:0')+'</div>'
b+='<div style="position:absolute;right:14px;top:10px;background:rgba(5,5,6,.7);backdrop-filter:blur(10px);padding:6px 10px;border-radius:14px;font:700 12px Inter;letter-spacing:1px">54 PHOTOS</div>'
w('v5-edge-to-edge','',page('5 · Edge to edge',b))

# 6 chaptered by time
def chap(t,n,imgs,cols=3,h=84):
    return f'<div style="display:flex;justify-content:space-between;padding:0 20px;margin:0 0 6px;font:700 11px Inter;letter-spacing:1.6px;color:rgba(245,241,234,.55);text-transform:uppercase"><span>{t}</span><span>{n}</span></div><div style="padding:0 20px;display:grid;grid-template-columns:repeat({cols},1fr);gap:4px;margin-bottom:14px">'+''.join(im(i,st=f'height:{h}px') for i in imgs)+'</div>'
b='<div style="display:flex;gap:8px;padding:0 20px 12px"><span style="background:#fff;color:#000;padding:7px 12px;border-radius:16px;font:700 12px Inter">All 54</span><span style="background:#1a1a1f;padding:7px 12px;border-radius:16px;font:600 12px Inter">Before</span><span style="background:#1a1a1f;padding:7px 12px;border-radius:16px;font:600 12px Inter">In the park</span><span style="background:#1a1a1f;padding:7px 12px;border-radius:16px;font:600 12px Inter">After</span></div>'
b+=chap('Before the game · 2:10 PM','18',[1,2,3,4,5,6])+chap('In the park · 5:37 PM','29',[0,7,8,9,10,11])
w('v6-chapters','',page('6 · Chapters by time',b))

# 7 polaroid scatter
rot=[-5,4,-2,6,-4,3]
b='<div style="position:relative;height:400px">'
pos=[(14,6),(190,0),(40,150),(205,140),(10,290),(185,285)]
for k,(x,y) in enumerate(pos):
    b+=f'<div style="position:absolute;left:{x}px;top:{y}px;width:170px;background:#f3ece0;padding:7px 7px 26px;border-radius:3px;box-shadow:0 8px 22px rgba(0,0,0,.6);transform:rotate({rot[k]}deg)">'+im(k,st='height:130px;border-radius:1px')+f'<div style="position:absolute;bottom:6px;left:0;right:0;text-align:center;font:600 10px Inter;color:#6b645a;letter-spacing:.5px">{["Pre-game","Gates","Our seats","7th inning","Fireworks","After"][k]}</div></div>'
b+='</div>'
w('v7-scatter','',page('7 · Scrapbook scatter',b))
