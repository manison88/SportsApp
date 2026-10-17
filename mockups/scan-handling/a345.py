from lib import *

# ---------------------------------------------------------------- APPROACH 3
F = 'approach-3'
feature(F, '3 · Swipe to confirm', 'One game per card. Right adds, left is not a game, up asks later. Undo everywhere.')

CARDCSS = '''
.stack{position:absolute;left:20px;right:20px;top:108px;height:548px}
.card{position:absolute;inset:0;border-radius:22px;background:#13151a;box-shadow:inset 0 0 0 1px var(--b-line),0 20px 40px rgba(0,0,0,.5);overflow:hidden}
.card.b1{transform:translateY(14px) scale(.95);opacity:.8}.card.b2{transform:translateY(26px) scale(.90);opacity:.5}
.coll{position:absolute;left:0;right:0;top:0;height:330px;display:grid;grid-template-columns:1.5fr 1fr;grid-template-rows:1fr 1fr;gap:3px}
.coll .ph:first-child{grid-row:span 2}
.cbody{position:absolute;left:18px;right:18px;top:350px}
.acts{position:absolute;left:0;right:0;bottom:44px;display:flex;justify-content:center;gap:26px;align-items:flex-start}
.act{display:grid;justify-items:center;gap:8px;font:700 12px/1 var(--b-cond);letter-spacing:1.4px;text-transform:uppercase;color:rgba(255,255,255,.75)}
.act i{width:64px;height:64px;border-radius:50%;display:grid;place-items:center;background:var(--b-panel-2);box-shadow:inset 0 0 0 1px var(--b-line)}
.act i svg{width:26px;height:26px;stroke:#fff;fill:none;stroke-width:2.4;stroke-linecap:round;stroke-linejoin:round}
.act.go i{background:#fff}.act.go i svg{stroke:#000}
.prog{display:flex;gap:3px;flex:1;margin:0 14px}.prog i{height:4px;flex:1;border-radius:2px;background:rgba(255,255,255,.18)}.prog i.d{background:#fff}
'''
def collage(a, b, c, pa='50% 50%', pb='50% 50%', pc='50% 50%'):
    return '<div class="coll"><div class="ph">%s</div><div class="ph">%s</div><div class="ph">%s</div></div>' % (im(a, pa), im(b, pb), im(c, pc))
def cardbody(a, sa, b, sb, venue, stage=None, ev='Place, time and scoreboard'):
    return ('<div class="cbody"><div class="f-between"><div style="display:flex;align-items:center;gap:8px">%s<span class="b-bug">'
            '<span class="team" style="--c:%s;color:%s">%s</span><span class="score">%s</span><span class="team" style="--c:%s;color:%s">%s</span><span class="score">%s</span></span></div></div>'
            '<div class="hl" style="font-size:34px;margin-top:14px">%s</div>'
            '<div class="sub" style="margin-top:6px;font-size:15px">%s</div>'
            '<div class="lock" style="justify-content:flex-start;margin-top:12px;color:rgba(255,255,255,.62)">%s%s</div></div>') % (
        '', COL[a], txt(a), a, sa, COL[b], txt(b), b, sb, venue, stage, I['seal'], ev)

def topnav(n, undo=True):
    return nav(icb('x'), icb('undo') if undo else '', '<div class="prog">' + ''.join('<i class="d"></i>' if i < n else '<i></i>' for i in range(12)) + '</div>')

def acts(go=None):
    return '''<div class="acts"><div class="act"><i>%s</i>Not a game</div><div class="act"><i>%s</i>Ask later</div><div class="act go"><i>%s</i>Add</div></div>''' % (I['x'], I['clock'], I['check'])

WS = cardbody('CLE', 2, 'CHC', 3, 'Wrigley Field', 'World Series, Game 5 · Oct 30 2016')
page(F, 'v1-start', 'Swipe intro', nav(icb('x')) + '''
<div class="f-col" style="top:108px;gap:22px">
  <div><div class="mega" style="font-size:130px">47</div><div class="hl" style="font-size:32px;margin-top:10px">games to flip through</div><div class="sub" style="margin-top:8px">From 52,310 photos checked on this iPhone.</div></div>
</div>
<div style="position:absolute;left:60px;right:60px;top:372px;height:150px">
  <div class="card b2" style="top:0;transform:rotate(-7deg) translateX(-26px)"><div class="abs">''' + im('fenway-night.jpg', '50% 40%') + '''</div></div>
  <div class="card b2" style="transform:rotate(6deg) translateX(26px)"><div class="abs">''' + im('lambeau-concourse.jpg', '50% 80%') + '''</div></div>
  <div class="card" style="transform:rotate(-1deg)"><div class="abs">''' + im('wrigley-bleachers.jpg', '50% 50%') + '''</div></div>
</div>
<div style="position:absolute;left:20px;right:20px;top:566px" class="f-list">
  <div class="gr" style="min-height:48px;gap:14px"><span class="ico24" style="display:grid">''' + I['check'].replace('<svg', '<svg class="ico24"') + '''</span><div class="t" style="font-size:17px">Swipe right to add</div></div>
  <div class="gr" style="min-height:48px;gap:14px">''' + I['x'].replace('<svg', '<svg class="ico24"') + '''<div class="t" style="font-size:17px">Swipe left if it was not a game</div></div>
  <div class="gr" style="min-height:48px;gap:14px">''' + I['up'].replace('<svg', '<svg class="ico24"') + '''<div class="t" style="font-size:17px">Swipe up to decide later</div></div>
</div>
<div class="cta" style="bottom:36px"><div class="b-btn">Start</div></div>
''', CARDCSS)

def stack(front, tilt='', extra='', back=True):
    b = ('<div class="card b2"></div><div class="card b1"></div>' if back else '')
    return '<div class="stack">%s<div class="card" style="%s">%s</div></div>' % (b, tilt, front + extra)

F1 = collage('wrigley-night.jpg', 'wrigley-night-2.jpg', 'wrigley-scoreboard.jpg', '50% 38%', '50% 40%', '50% 50%') + WS
page(F, 'v2-card', 'Card', topnav(13) + stack(F1) + acts() + lockline('') .replace('<div class="lock">', '<div class="lock" style="display:none">'), CARDCSS)

STAMP = '<div style="position:absolute;top:34px;left:24px;transform:rotate(-12deg);border:4px solid #fff;border-radius:12px;padding:8px 16px;font:800 38px/1 var(--b-cond);letter-spacing:2px;color:#fff;z-index:5">ADD</div>'
page(F, 'v3-swiping', 'Swiping', topnav(13) +
  '<div class="stack"><div class="card b2"></div><div class="card b1" style="opacity:1;transform:translateY(0) scale(1)">%s</div><div class="card" style="transform:translate(70px,-10px) rotate(9deg)">%s%s%s</div></div>' % (
    collage('fenway-night.jpg', 'fenway-day.jpg', 'fenway-night.jpg', '50% 40%', '50% 40%', '50% 70%') + cardbody('CHC', 3, 'BOS', 6, 'Fenway Park', 'Jun 12 2024'),
    collage('wrigley-night.jpg', 'wrigley-night-2.jpg', 'wrigley-scoreboard.jpg', '50% 38%', '50% 40%', '50% 50%'), WS, STAMP) +
  '''<div class="acts"><div class="act"><i>%s</i>Not a game</div><div class="act"><i>%s</i>Ask later</div><div class="act go"><i style="transform:scale(1.12)">%s</i>Add</div></div>''' % (I['x'], I['clock'], I['check']), CARDCSS)

TOAST = '''<div style="position:absolute;left:20px;right:20px;bottom:156px;height:56px;border-radius:16px;background:#fff;color:#000;display:flex;align-items:center;gap:12px;padding:0 8px 0 18px;z-index:30">
  <div style="flex:1;font:800 16px/1.1 var(--b-cond);letter-spacing:.8px;text-transform:uppercase">Lambeau moved to Not a game</div>
  <div style="height:40px;padding:0 16px;border-radius:10px;background:#000;color:#fff;display:flex;align-items:center;gap:8px;font:800 14px/1 var(--b-cond);letter-spacing:1.4px;text-transform:uppercase">%s Undo</div></div>''' % I['undo'].replace('<svg', '<svg style="width:16px;height:16px;stroke:#fff;fill:none;stroke-width:2.4;stroke-linecap:round"')
FL = collage('lambeau-concourse.jpg', 'lambeau-exterior.jpg', 'lambeau-concourse.jpg', '50% 80%', '50% 50%', '30% 60%') + cardbody('CHI', 20, 'GB', 17, 'Lambeau Field', 'Dec 14 2025')
page(F, 'v4-undo-edge', 'Undo', topnav(14) + stack(collage('fenway-night.jpg', 'fenway-night.jpg', 'fenway-night.jpg', '50% 40%', '30% 60%', '70% 70%') + cardbody('CHC', 3, 'BOS', 6, 'Fenway Park', 'Jun 12 2024')) + TOAST + acts(), CARDCSS)

page(F, 'v5-wrong-game', 'Wrong game', topnav(14) + stack(FL, '', '', True) + '''
<div class="scrimall"></div>
<div class="sheet" style="padding-bottom:40px">
  <div class="grab"></div>
  <div class="hl" style="font-size:32px">Which game was it?</div>
  <div class="sub" style="margin:8px 0 6px">Lambeau Field. Your photos run from 11:48 PM Dec 13 to 12:20 AM Dec 14.</div>
  <div class="opt"><div class="rad"></div><div class="mid"><div class="t">Dec 13 · CHI at GB, 7:20 PM</div><div class="s">Ended 3 hours before your photos</div></div></div>
  <div class="opt"><div class="rad on"></div><div class="mid"><div class="t">Dec 14 · CHI at GB, 12:00 AM</div><div class="s">Closest to your photos</div></div></div>
  <div class="opt"><div class="mid"><div class="t">Search another date</div></div><div class="dim">''' + I['chev'].replace('<svg', '<svg class="ico24"') + '''</div></div>
  <div class="b-btn" style="width:100%;height:54px;font-size:17px;margin-top:14px">Use this game</div>
</div>''', CARDCSS)

page(F, 'v6-done', 'Done', nav(icb('x')) + '''
<div class="f-col col">
  <div><div class="mega" style="font-size:150px">39</div><div class="hl" style="font-size:34px;margin-top:8px">games added</div></div>
  <div class="f-stats"><div><b>5</b><span>Not games</span></div><div><b>3</b><span>Ask later</span></div></div>
  <div class="f-list">
    <div class="gr" style="min-height:62px"><div class="mid"><div class="t">3 cards come back in a week</div><div class="s">Or open them now from Timeline</div></div><div class="end">%s</div></div>
  </div>
</div>
<div class="cta"><div class="b-btn">See timeline</div></div>''' % I['chev'].replace('<svg', '<svg class="ico24"'), CARDCSS)

# ---------------------------------------------------------------- APPROACH 4
F = 'approach-4'
feature(F, '4 · Start from a place or trip', 'Scope the scan on purpose: a stadium or city, an album, a date range. Review per trip. Ask only for what is missing.')

def bigopt(icon, t, s):
    return '<div class="gr" style="min-height:92px;gap:16px"><div class="ibox" style="width:56px;height:56px;border-radius:16px">%s</div><div class="mid"><div class="t" style="font-size:24px">%s</div><div class="s" style="font-size:14px">%s</div></div><div class="end dim">%s</div></div>' % (I[icon], t, s, I['chev'].replace('<svg', '<svg class="ico24"'))
page(F, 'v1-start', 'Where have you been', nav(icb('x'), '<div class="txtbtn">Scan settings</div>') + '''
<div class="f-col" style="top:112px;gap:26px">
  <div class="hl" style="font-size:52px">Where have you been?</div>
  <div class="f-list">''' + bigopt('pin', 'A stadium or city', 'Pick it on the map') + bigopt('album', 'An album', 'A trip you already saved') + bigopt('cal', 'A date range', 'A season or a weekend') + '''</div>
</div>
<div class="cta">''' + lockline('Witness only reads photos from what you pick. On this iPhone.') + '<div class="link" style="color:rgba(255,255,255,.62)">Scan everything instead</div></div>')

MAPCSS = '''.map{position:absolute;inset:0;background:#0c0e12}
.map svg{position:absolute;inset:0;width:100%;height:100%}'''
def mapsvg(sel=True):
    return '''<div class="map"><svg viewBox="0 0 393 852" preserveAspectRatio="xMidYMid slice">
<defs><pattern id="g" width="40" height="40" patternUnits="userSpaceOnUse"><path d="M40 0H0V40" fill="none" stroke="#fff" stroke-opacity=".05"/></pattern></defs>
<rect width="393" height="852" fill="url(#g)"/>
<path d="M290 0C300 120 330 160 318 260C310 340 350 420 340 560L393 560V0Z" fill="#101a2a"/>
<path d="M290 0C300 120 330 160 318 260C310 340 350 420 340 560" fill="none" stroke="#2a4468" stroke-width="2"/>
<path d="M0 300C90 280 160 330 250 300M110 120L140 700M20 520L300 470M190 80L205 650" stroke="#1d2129" stroke-width="7" fill="none"/>
<path d="M0 300C90 280 160 330 250 300M110 120L140 700M20 520L300 470M190 80L205 650" stroke="#2a2f3a" stroke-width="1.500" fill="none"/>
<path d="M60 380C140 400 200 360 260 400" stroke="#1b3350" stroke-width="5" fill="none"/>
<g fill="none" stroke="#fff" stroke-opacity=".9" stroke-width="2"><circle cx="150" cy="190" r="34" fill="#2f6bff" fill-opacity=".25" stroke="#2f6bff"/><circle cx="270" cy="400" r="34" fill="#f05a1a" fill-opacity=".25" stroke="#f05a1a"/><circle cx="104" cy="360" r="34" fill="#ce1141" fill-opacity=".25" stroke="#ce1141"/><circle cx="212" cy="506" r="34" fill="#3dd" fill-opacity=".0" stroke="#fff" stroke-opacity=".3"/></g>
<g fill="#fff" font-family="Barlow Condensed" font-weight="800" font-size="15" letter-spacing="1"><circle cx="150" cy="190" r="6"/><circle cx="270" cy="400" r="6"/><circle cx="104" cy="360" r="6"/><circle cx="212" cy="506" r="5" opacity=".5"/>
<text x="150" y="150" text-anchor="middle">WRIGLEY FIELD</text><text x="260" y="348" text-anchor="middle">SOLDIER FIELD</text><text x="100" y="412" text-anchor="middle">UNITED CENTER</text><text x="212" y="548" text-anchor="middle" opacity=".5">GUARANTEED RATE</text></g>
</svg></div>'''
page(F, 'v2-map-pick', 'Pick a place', mapsvg() + '''
<div style="position:absolute;left:20px;right:20px;top:56px;display:flex;gap:10px;z-index:20"><div class="b-icon-btn">%s</div>
 <div style="flex:1;height:40px;border-radius:12px;background:rgba(21,23,28,.92);box-shadow:inset 0 0 0 1px var(--b-line);display:flex;align-items:center;gap:10px;padding:0 14px;font:600 16px/1 var(--b-ui)">%s Chicago</div></div>
<div class="sheet" style="padding-bottom:40px">
  <div class="grab"></div>
  <div class="f-between"><div class="hl" style="font-size:40px">Chicago</div><div class="tag">4 stadiums</div></div>
  <div class="sub" style="margin:8px 0 14px">About 4,210 photos taken in this area. Dates: all.</div>
  <div class="row2" style="margin-bottom:14px"><div class="b-pill" style="height:34px;padding:0 14px;font-size:13px">Boston</div><div class="b-pill" style="height:34px;padding:0 14px;font-size:13px">Barcelona</div><div class="b-pill" style="height:34px;padding:0 14px;font-size:13px">Madrid</div></div>
  <div class="b-btn" style="width:100%%;height:54px;font-size:17px">Scan Chicago</div>
</div>''' % (I['back'], I['search'].replace('<svg', '<svg class="ico" style="opacity:.6"')), MAPCSS)

page(F, 'v3-scanning', 'Scanning Chicago', nav('<div class="b-label" style="color:#fff;display:flex;gap:8px;align-items:center"><span class="b-dot" style="background:var(--amber);box-shadow:0 0 10px var(--amber)"></span>Chicago, all dates</div>', '<div class="b-btn ghost" style="height:40px;padding:0 16px;font-size:14px">Stop</div>') + '''
<div class="f-col col">
  <div><div class="mega" style="font-size:118px">2,980</div><div class="hl" style="font-size:24px;margin-top:10px;color:rgba(255,255,255,.7)">of 4,210 photos checked</div><div class="bar" style="margin-top:16px"><i style="width:71%"></i></div><div class="sub" style="margin-top:10px">About 20 seconds left</div></div>
  <div class="f-stats"><div><b>388</b><span>Near a stadium</span></div><div><b>4</b><span>Venues</span></div><div><b>19</b><span>Games</span></div></div>
</div>
<div class="cta">''' + lockline('The other 48,100 photos were not opened.') + '</div>')

page(F, 'v4-trip-review', 'Trip review', nav(icb('back'), '<div class="b-pill" style="background:rgba(7,8,10,.75)">Trip 2 of 3</div>') + '''
<div class="ph" style="position:absolute;left:0;right:0;top:0;height:290px">''' + im('camp-nou-aerial.jpg', '50% 50%') + '''<div class="abs" style="background:linear-gradient(180deg,rgba(7,8,10,.78),rgba(7,8,10,0) 34%,rgba(7,8,10,.95) 100%)"></div></div>
<div class="f-col" style="top:196px;gap:14px;bottom:130px">
  <div><div class="hl" style="font-size:54px">Spain</div><div class="sub" style="margin-top:6px">Mar 6 to 12, 2020 · album Spain 2020</div></div>
  <div class="f-list" style="margin-top:8px">
  ''' + '<div class="gr" style="min-height:76px">%s<div class="th ph">%s</div><div class="mid"><div class="t">FCB 1 <em>RSO 0</em></div><div class="s">Camp Nou · Mar 8 2020</div></div></div>' % (cb(True), im('camp-nou-aerial.jpg', '50% 60%')) +
  '<div class="gr" style="min-height:76px">%s<div class="th ph">%s</div><div class="mid"><div class="t">Stadium visit</div><div class="s">Camp Nou · Mar 7 · no game that day</div></div></div>' % (cb(True), im('camp-nou-aerial.jpg', '20% 30% 2.2')) +
  '</div></div><div class="cta">' + '<div class="b-btn">Add 1 game, 1 visit</div>' + lockline('Matched on this iPhone') + '</div>')

def photo_sq(f, pos): return '<div class="ph" style="width:100%%;aspect-ratio:1;border-radius:10px">%s</div>' % im(f, pos)
page(F, 'v5-missing-place', 'Where was this', nav(icb('x'), '<div class="tag">14 photos</div>') + '''
<div class="f-col col" style="top:112px;gap:22px">
  <div class="hl" style="font-size:44px">Where were these taken?</div>
  <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:6px">''' + photo_sq('camp-nou-aerial.jpg', '50% 50% 1.2') + photo_sq('camp-nou-aerial.jpg', '15% 70% 2') + photo_sq('camp-nou-aerial.jpg', '85% 60% 2') + photo_sq('camp-nou-aerial.jpg', '50% 20% 2.4') + '''</div>
  <div class="sub">Spain 2020, Mar 8, 6:41 to 9:12 PM. No location saved. Other photos that evening were at Camp Nou.</div>
  <div class="f-list">
    <div class="opt" style="min-height:70px"><div class="mid"><div class="t">Camp Nou, Barcelona</div><div class="s">Best guess</div></div><div class="rad on"></div></div>
    <div class="opt" style="min-height:70px"><div class="mid"><div class="t">Somewhere else</div></div><div class="dim">''' + I['chev'].replace('<svg', '<svg class="ico24"') + '''</div></div>
  </div>
</div>
<div class="cta"><div class="b-btn">Camp Nou</div><div class="link">Skip these photos</div></div>''')

def covrow(t, s, end):
    return '<div class="gr" style="min-height:64px"><div class="mid"><div class="t">%s</div><div class="s">%s</div></div><div class="end">%s</div></div>' % (t, s, end)
SC = '<div class="b-btn ghost" style="height:38px;padding:0 16px;font-size:14px;border-radius:10px">Scan</div>'
page(F, 'v6-done', 'Done', nav(icb('x'), '') + '''
<div class="f-col col" style="top:112px">
  <div><div class="mega" style="font-size:150px">20</div><div class="hl" style="font-size:34px;margin-top:8px">games added</div></div>
  <div class="f-list">''' + covrow('Chicago, all dates', '19 games · scanned today', '<span class="tag">Done</span>') + covrow('Spain, Mar 2020', '1 game, 1 visit · scanned today', '<span class="tag">Done</span>') + covrow('Boston', 'Not scanned. Photos were not opened.', SC) + covrow('Missing a game?', 'Scan a date or add it by hand', I['chev'].replace('<svg', '<svg class="ico24"')) + '''</div>
</div>
<div class="cta"><div class="b-btn">See timeline</div>''' + lockline('Only Chicago and Spain photos were read.') + '</div>')

# ---------------------------------------------------------------- APPROACH 5
F = 'approach-5'
feature(F, '5 · Ask first, prove later', 'No scan screen. The Timeline quietly asks Did you go to this? with a confidence label and expandable proof.')

SUGCSS = '''
.sug{position:absolute;left:20px;right:20px;border-radius:20px;background:#13151a;box-shadow:inset 0 0 0 1px var(--b-line);overflow:hidden}
.sug .hero{position:relative;height:210px}
.sug .hero::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(7,8,10,.5),rgba(7,8,10,0) 35%,rgba(7,8,10,.92) 100%)}
.sug .bd{padding:16px}
.conf{display:flex;align-items:center;gap:8px;font:600 14px/1.3 var(--b-ui);color:rgba(255,255,255,.8)}
.conf svg{width:18px;height:18px;stroke:#fff;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;flex:none}
.three{display:flex;gap:8px;margin-top:14px}
.three .b-btn{height:46px;flex:1;font-size:14px;padding:0 4px;letter-spacing:1px}
.three .b-btn.ghost{flex:1}
.q{position:absolute;left:14px;top:14px;font:800 13px/1 var(--b-cond);letter-spacing:1.4px;text-transform:uppercase;background:rgba(7,8,10,.7);padding:8px 10px;border-radius:7px;z-index:3}
'''
def three(): return '<div class="three"><div class="b-btn">Yes</div><div class="b-btn ghost">Not a game</div><div class="b-btn ghost">Wrong game</div></div>'
def sug(top, img, pos, a, sa, b, sb, venue, conf, extra='', hero=210):
    return ('<div class="sug" style="top:%spx"><div class="hero" style="height:%spx">%s<div class="q">Did you go to this?</div>'
            '<div style="position:absolute;left:16px;right:16px;bottom:14px;z-index:3" class="f-between"><div class="hl" style="font-size:28px;white-space:nowrap">%s</div>%s</div></div>'
            '<div class="bd"><div class="conf">%s%s</div>%s</div></div>') % (top, hero, im(img, pos), venue, bug(a, sa, b, sb, 'sm'), I['seal'], conf, extra)

page(F, 'v1-feed', 'Suggestion feed', '<div class="f-title" style="position:absolute;left:20px;top:60px">Timeline</div><div class="b-icon-btn" style="position:absolute;right:20px;top:56px">%s</div>' % I['search'] +
  sug(112, 'wrigley-bleachers.jpg', '50% 50%', 'MIL', 3, 'CHC', 4, 'Wrigley Field', 'Matched by place, time and scoreboard', three() + '<div style="margin-top:12px;font:500 13px/1.3 var(--b-ui);color:rgba(255,255,255,.62)">Jul 4 2026 · 7:05 PM · 4 photos</div>') +
  '<div class="ph" style="position:absolute;left:20px;right:20px;top:520px;height:160px;border-radius:20px">%s<div class="abs" style="background:linear-gradient(0deg,rgba(7,8,10,.85),rgba(7,8,10,.1))"></div><div style="position:absolute;left:16px;bottom:14px"><div class="hl" style="font-size:26px">Lambeau Field</div><div class="sub" style="font-size:13px">Dec 14 2025</div></div></div>' % im('lambeau-concourse.jpg', '50% 80%') + tabs(0), SUGCSS)

def ev(icon, t, s):
    return '<div class="gr" style="min-height:64px;align-items:flex-start;padding:12px 0"><div class="ibox" style="width:38px;height:38px;border-radius:10px">%s</div><div class="mid"><div class="t" style="font-size:17px">%s</div><div class="s">%s</div></div></div>' % (I[icon].replace('<svg', '<svg style="width:20px;height:20px"'), t, s)
page(F, 'v2-evidence', 'Evidence', nav(icb('back'), icb('more')) + '''
<div class="f-col" style="top:108px;gap:18px;bottom:120px;overflow:hidden">
  <div><div class="hl" style="font-size:44px">Wrigley Field</div><div style="margin-top:10px">''' + bug('MIL', 3, 'CHC', 4) + '''</div></div>
  <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:6px">''' +
  ''.join('<div><div class="ph" style="aspect-ratio:3/4;border-radius:10px">%s</div><div class="tag" style="margin-top:6px;text-align:center;font-size:12px">%s</div></div>' % (im(f, p), t) for f, p, t in
    [('wrigley-night.jpg', '50% 38%', '6:12 PM'), ('wrigley-night-2.jpg', '50% 40%', '7:08 PM'), ('wrigley-scoreboard.jpg', '50% 50%', '8:31 PM'), ('wrigley-bleachers.jpg', '60% 50%', '9:24 PM')]) + '''</div>
  <div class="f-list">''' + ev('pinring', 'Inside the fence', 'Within 200 m of Wrigley Field for 3 h 12 min') + ev('cal', 'On the schedule', 'MIL at CHC, Jul 4 2026, 7:05 PM · ESPN') + ev('seal', 'Scoreboard sealed', 'Read CHC 4, MIL 3 from your 8:31 PM photo') + '''</div>
</div>
<div class="cta" style="bottom:36px"><div class="row2"><div class="b-btn" style="flex:1.4">Yes</div><div class="b-btn ghost">Not a game</div><div class="b-btn ghost">Wrong game</div></div>''' + lockline('Read on this iPhone. Photos never leave it.') + '</div>', SUGCSS)

page(F, 'v3-wrong-game', 'Wrong game', '<div class="f-title" style="position:absolute;left:20px;top:60px">Timeline</div>' +
  sug(112, 'fenway-night.jpg', '50% 40%', 'CHC', 3, 'BOS', 6, 'Fenway Park', 'Matched by place and time', '', 150) + '''
<div class="scrimall"></div>
<div class="sheet" style="padding-bottom:40px">
  <div class="grab"></div>
  <div class="hl" style="font-size:32px">Pick the right game</div>
  <div class="sub" style="margin:8px 0 6px">Fenway Park, around Jun 12 2024</div>
  <div class="opt"><div class="rad"></div><div class="mid"><div class="t">Jun 11 · CHC at BOS, 7:10 PM</div><div class="s">Photos start Jun 12, 7:41 PM</div></div></div>
  <div class="opt"><div class="rad on"></div><div class="mid"><div class="t">Jun 12 · CHC at BOS, 7:10 PM</div><div class="s">Current match</div></div></div>
  <div class="opt"><div class="rad"></div><div class="mid"><div class="t">Jun 13 · CHC at BOS, 1:35 PM</div><div class="s">Photos end before first pitch</div></div></div>
  <div class="opt"><div class="mid"><div class="t">Other game or date</div></div><div class="dim">''' + I['chev'].replace('<svg', '<svg class="ico24"') + '''</div></div>
</div>''', SUGCSS)

TOAST5 = '''<div style="position:absolute;left:20px;right:20px;top:112px;height:56px;border-radius:16px;background:#fff;color:#000;display:flex;align-items:center;gap:12px;padding:0 8px 0 18px;z-index:30">
  <div style="flex:1;font:800 16px/1.1 var(--b-cond);letter-spacing:.8px;text-transform:uppercase">Added to your Timeline</div>
  <div style="height:40px;padding:0 16px;border-radius:10px;background:#000;color:#fff;display:flex;align-items:center;font:800 14px/1 var(--b-cond);letter-spacing:1.4px;text-transform:uppercase">Undo</div></div>'''
page(F, 'v4-confirmed-backlog', 'Confirmed', '<div class="f-title" style="position:absolute;left:20px;top:60px">Timeline</div><div class="b-icon-btn" style="position:absolute;right:20px;top:56px">%s</div>' % I['search'] + TOAST5 +
  sug(184, 'lambeau-concourse.jpg', '50% 80%', 'CHI', 20, 'GB', 17, 'Lambeau Field', 'Matched by place and time', three(), 170) +
  '''<div style="position:absolute;left:20px;right:20px;top:610px" class="gr"><div class="mid"><div class="t" style="font-size:18px">44 more suggestions</div><div class="s">Witness shows 3 at a time, newest first</div></div><div class="end"><div class="txtbtn" style="font-size:14px">Show all</div></div></div>''' + tabs(0), SUGCSS)

page(F, 'v5-missed-game', 'Missed game', nav(icb('back'), icb('more')) + '''
<div class="ph" style="position:absolute;left:0;right:0;top:0;height:300px">''' + im('fenway-night.jpg', '50% 100% 1.5') + '''<div class="abs" style="background:linear-gradient(180deg,rgba(7,8,10,.55),rgba(7,8,10,0) 30%,rgba(7,8,10,.95) 100%)"></div></div>
<div class="f-col" style="top:206px;gap:18px">
  <div><div class="hl" style="font-size:44px">Stadium visit</div><div class="sub" style="margin-top:6px">Fenway Park · Jun 12 2024 · 38 photos</div></div>
  <div class="b-panel" style="padding:16px"><div class="conf" style="align-items:flex-start">''' + I['flag'].replace('<svg', '<svg style="margin-top:1px"') + '''<div>No game matched. Your photos start at 9:50 PM, after the game on the schedule ended.</div></div></div>
  <div class="f-list">
    <div class="opt" style="min-height:62px"><div class="mid"><div class="t">Pick a game from the schedule</div></div><div class="dim">''' + I['chev'].replace('<svg', '<svg class="ico24"') + '''</div></div>
    <div class="opt" style="min-height:62px"><div class="mid"><div class="t">Add the game by hand</div></div><div class="dim">''' + I['chev'].replace('<svg', '<svg class="ico24"') + '''</div></div>
  </div>
</div>
<div class="cta"><div class="b-btn ghost">Keep as stadium visit</div>''' + lockline('Matched on this iPhone') + '</div>', SUGCSS)

# ---------------------------------------------------------------- SETTINGS SHEET
F = 'settings-sheet'
feature(F, 'Scan settings (shared)', 'One sheet for every approach: scope, albums, videos later, rescan, clear suggestions.')
def sopt(t, s, right): return '<div class="opt" style="min-height:60px"><div class="mid"><div class="t" style="font-size:18px">%s</div>%s</div>%s</div>' % (t, ('<div class="s">%s</div>' % s) if s else '', right)
def seg(items, on):
    return '<div style="display:flex;background:var(--b-panel-2);border-radius:10px;padding:3px;box-shadow:inset 0 0 0 1px var(--b-line);margin:6px 0 4px">' + ''.join(
      '<div style="flex:1;text-align:center;height:38px;line-height:38px;border-radius:8px;font:800 13px/38px var(--b-cond);letter-spacing:1.2px;text-transform:uppercase;%s">%s</div>' % ('background:#fff;color:#000' if i == on else 'color:rgba(255,255,255,.7)', t) for i, t in enumerate(items)) + '</div>'
page(F, 'v1-settings', 'Scan settings', '''<div class="f-title" style="position:absolute;left:20px;top:60px">Timeline</div>
<div class="ph" style="position:absolute;left:20px;right:20px;top:112px;height:300px;border-radius:16px">''' + im('lambeau-concourse.jpg', '50% 80%') + '</div><div class="scrimall"></div>' + '''
<div class="sheet" style="top:60px;padding-top:10px;overflow:hidden">
  <div class="grab"></div>
  <div class="f-between" style="margin-bottom:6px"><div class="hl" style="font-size:34px">Scan settings</div><div class="txtbtn">Done</div></div>
  ''' + seg(['Everything', 'Albums', 'Dates', 'Places'], 1) + '''
  ''' + sopt('Camera Roll', '52,310 photos', '<div class="tg on"></div>') + sopt('Spain 2020', '214 photos · ticket screenshots help', '<div class="tg on"></div>') + sopt('Chicago summer', '1,880 photos', '<div class="tg"></div>') + sopt('Videos', 'Coming later', '<div class="tg" style="opacity:.35"></div>') + '''
  <div class="opt" style="min-height:72px;margin-top:6px"><div class="ibox" style="width:36px;height:36px">''' + I['refresh'] + '''</div><div class="mid"><div class="t" style="font-size:18px">Rescan</div><div class="s">Last 30 days or everything. Your confirmed games stay.</div></div><div class="dim">''' + I['chev'].replace('<svg', '<svg class="ico24"') + '''</div></div>
  <div class="opt" style="min-height:72px"><div class="ibox" style="width:36px;height:36px">''' + I['trash'] + '''</div><div class="mid"><div class="t" style="font-size:18px;color:#ff7a6e">Clear suggestions</div><div class="s">Removes 47 unconfirmed games. Confirmed games stay.</div></div></div>
  <div style="margin-top:12px">''' + lockline('Everything here runs on this iPhone. Nothing is uploaded.') + '''</div>
</div>''', '')
