from common import *
CSS = """
.stub{height:100px;--m:radial-gradient(circle at 0 0,transparent 8px,#000 8.5px),radial-gradient(circle at 100% 0,transparent 8px,#000 8.5px)}
.sl{position:absolute;left:18px;top:0;bottom:0;display:flex;flex-direction:column;justify-content:center;gap:12px;padding-top:2px}
.date{font:700 16px/1 var(--f-tight);letter-spacing:.2px;text-transform:uppercase}
.pp{display:flex;align-items:center;gap:11px}
.av{display:flex}
.av i{width:24px;height:24px;border-radius:50%;display:grid;place-items:center;font:800 11px/1 var(--f-ui);font-style:normal;color:#10101a;box-shadow:0 0 0 2px var(--stub);margin-left:-7px}
.av i:first-child{margin-left:0}
.av i.ghost{background:transparent;border:1.5px dashed rgba(255,255,255,.3);color:var(--text-3);box-shadow:none}
.av i.ghost svg{width:11px;height:11px}
.cnt{display:flex;align-items:center;gap:5px;font:600 12.5px/1 var(--f-ui);color:var(--text);padding-left:11px;border-left:1px solid var(--line-2);height:16px;font-variant-numeric:tabular-nums}
.cnt svg{color:var(--text-2);width:14px;height:14px}
.add{display:flex;align-items:center;gap:5px;height:24px;padding:0 10px 0 8px;border-radius:12px;border:1.5px dashed rgba(255,181,71,.6);color:var(--signal);font:700 12px/1 var(--f-ui)}
.add svg{width:14px;height:14px}
.bug{position:absolute;right:16px;top:0;bottom:0;display:flex;align-items:center;gap:7px;padding-top:2px}
.bug .sc{font:800 22px/1 var(--f-cond);font-variant-numeric:tabular-nums;color:var(--text-2)}
.bug .me{color:#fff}
.bug .tile.rt{box-shadow:0 0 0 1.5px var(--stub),0 0 0 3px var(--signal)}
.bug .gap{width:2px}
.poly{position:absolute;right:12px;bottom:16px;width:74px;height:70px}
.pl{position:absolute;width:46px;height:56px;padding:3px 3px 11px;background:#f3ece0;border-radius:2px;box-shadow:0 4px 10px rgba(0,0,0,.55),0 0 0 .5px rgba(0,0,0,.4)}
.pl div{width:100%;height:100%;background-size:cover}
.pl.a{left:0;bottom:6px;transform:rotate(-10deg)}
.pl.b{left:13px;bottom:2px;transform:rotate(-2deg)}
.pl.c{left:26px;bottom:0;transform:rotate(8deg)}
.pl em{position:absolute;right:-6px;top:-7px;font:800 10px/1 var(--f-ui);font-style:normal;color:#2a1a00;background:var(--signal);padding:4px 6px;border-radius:9px;box-shadow:0 2px 6px rgba(0,0,0,.5)}
"""
def thumb(photo, pos, size='cover'):
    return f'<div style="background-image:url({P}{photo}.jpg);background-position:{pos};background-size:{size}"></div>'
def card(c, top, ph_h):
    av = ''.join(f'<i style="background:{col}">{ini}</i>' for ini, col in c['who'])
    if not av: av = '<i class="ghost">'+ICON['plus']+'</i>'
    cnt = f'<span class="cnt">{ICON["camera"]}{c["n"]} photos</span>' if c['n'] else f'<span class="add">{ICON["camera"]}Add photos</span>'
    if not c['n']: cnt = cnt.replace('class="add"','class="add"')
    a, as_, h, hs, me = c['bug'][:5]
    rt = lambda x: ' rt' if x == me else ''
    bug = f'<div class="bug">{tile(a).replace("class=\"tile\"", "class=\"tile"+rt(a)+"\"")}<span class="sc">{as_}</span><span class="gap"></span>{tile(h).replace("class=\"tile\"", "class=\"tile"+rt(h)+"\"")}<span class="sc me">{hs}</span></div>'
    poly = ''
    if c['n']:
        t = c['thumbs']
        poly = f'<div class="poly"><div class="pl a">{thumb(*t[0])}</div><div class="pl b">{thumb(*t[1])}</div><div class="pl c">{thumb(*t[2])}<em>+{c["n"]-4}</em></div></div>'
    badge = f'<div class="badge"><svg width="11" height="11" viewBox="0 0 24 24" fill="#2a2008"><path d="M12 2l2.9 6.6 7.1.6-5.4 4.7 1.6 7L12 17.3 5.8 20.9l1.6-7L2 9.2l7.1-.6z"/></svg>{c["badge"]}</div>' if c.get('badge') else ''
    return f"""<div class="card{' big' if c.get('badge') else ''}" style="top:{top}px"><div class="clip">
<div class="photo" style="height:{ph_h}px">{c['photo'](ph_h)}<div class="scrim top"></div>{badge}<div class="hl" style="{c.get('hs','font-size:48px')}">{c['hl']}</div>{poly}</div>
<div class="stub"><div class="sl"><span class="date">{c['date']}</span><div class="pp"><span class="av">{av}</span>{cnt}</div></div>{bug}</div></div></div>"""
def img(photo, cx, cy, wf):
    return lambda ph: f'<div style="position:absolute;inset:0;{bg(photo,361,ph,cx,cy,wf)}"></div>'
DANA=('D','#b79cff'); DAD=('R','#8fe3a0')
CARDS = {
 1: dict(hl='Chicago 5,<br>Milwaukee 4.', date='Jul 4, 2026', who=[DANA,DAD], n=63,
   photo=lambda ph: f'<img class="ph graded" src="{P}wrigley-scoreboard.jpg" style="object-position:35% 50%">', bug=('MIL',4,'CHC',5,'CHC'),
   thumbs=[('wrigley-bleachers','60% 50%'),('wrigley-night-2','72% 66%','230%'),('wrigley-night','30% 62%','210%')]),
 2: dict(hl='Chicago 3,<br>Cleveland 2.', date='Oct 30, 2016', who=[DAD], n=63, badge='World Series',
   photo=img('wrigley-night',.62,.60,.46), bug=('CLE',2,'CHC',3,'CHC'),
   thumbs=[('wrigley-bleachers','30% 50%'),('wrigley-night-2','72% 66%','230%'),('wrigley-scoreboard-wide','25% 60%','240%')]),
 3: dict(hl='Los Angeles 118,<br>Chicago 104.', hs='font-size:46px', date='Jan 3, 2025', who=[], n=0,
   photo=lambda ph: '<canvas class="photo" data-style="arena" data-seed="11" data-accent="#e8213f" data-secondary="#552583" data-board="LAL 118|CHI 104"></canvas>', bug=('LAL',118,'CHI',104,'CHI')),
}
v1 = head() + card(CARDS[1], 157, 420) + card(CARDS[2], 157+420+100+24, 420)
open('v1-main.html','w').write(page('People and photos', CSS, v1))
v2 = card(CARDS[2], 68, 244) + card(CARDS[3], 68+244+100+22, 244)
open('v2-states.html','w').write(page('People and photos states', CSS, v2))
