#!/usr/bin/env python3
"""Generates v1/v2 for 09-your-team and 10-firsts-and-counts. Run: python3 gen.py"""
import os, json
HERE = os.path.dirname(os.path.abspath(__file__))
FEAT = os.path.dirname(HERE)
P = '../../../photos/'
TEAMS = {  # bg, fg
 'CHC': ('#2F6BFF', '#fff'), 'MIL': ('#F4C24B', '#2a2100'), 'CLE': ('#C8102E', '#fff'),
 'CHI': ('#E8213F', '#fff'), 'LAL': ('#552583', '#FDB927')}
def tile(c, sz='', dim=False):
    bg, fg = TEAMS[c]
    return f'<span class="tile {sz} {"dim" if dim else ""}" style="background:{bg};color:{fg}">{c}</span>'
def crop(img, ar, cx, cy, w, bw, bh):
    bgw = bw / w; bgh = bgw * ar
    return (f"background:url({P}{img}.jpg) no-repeat;background-size:{bgw:.0f}px {bgh:.0f}px;"
            f"background-position:{bw/2-cx*bgw:.0f}px {bh/2-cy*bgh:.0f}px")

CSS = """
*{-webkit-tap-highlight-color:transparent}
.title{position:absolute;left:16px;top:62px;font:800 36px/1 var(--f-cond);letter-spacing:.2px;text-transform:uppercase}
.plus{position:absolute;right:20px;top:64px;width:26px;height:26px}
.plus svg{width:26px;height:26px;stroke:#fff;stroke-width:2.4;stroke-linecap:round;fill:none}
.search{position:absolute;left:16px;right:16px;top:108px;height:38px;border-radius:11px;background:#1c1c22;display:flex;align-items:center;gap:8px;padding:0 10px;color:var(--text-3);font:400 16px/1 var(--f-ui)}
.search svg{width:17px;height:17px;stroke:var(--text-3);fill:none;stroke-width:2.2;stroke-linecap:round}
.card{position:absolute;left:16px;width:361px;border-radius:22px;overflow:hidden;background:#14151c}
.card.champ{box-shadow:0 0 0 1.5px #e6cf9a,0 0 28px rgba(230,207,154,.18)}
.photo{position:absolute;left:0;top:0;right:0;overflow:hidden;background:#0b0c10}
.photo .img,.photo canvas{position:absolute;inset:0;width:100%;height:100%}
.photo .img{filter:contrast(1.05) saturate(.9) brightness(.92)}
.scrim{position:absolute;inset:0;background:linear-gradient(to top,rgba(5,5,8,.94) 0,rgba(5,5,8,.72) 34%,rgba(5,5,8,.12) 66%,rgba(5,5,8,.28) 100%)}
.hl{position:absolute;left:20px;right:16px;bottom:18px}
.hl h2{font:800 54px/.88 var(--f-cond);letter-spacing:-.4px;text-transform:uppercase;color:#fff}
.hl h2 .w{color:var(--tc)} .hl h2 .f{color:rgba(245,241,234,.55)}
.stub{position:absolute;left:0;right:0;bottom:0;height:92px}
.stub:before{content:"";position:absolute;left:14px;right:14px;top:0;border-top:1.5px dashed rgba(255,255,255,.22)}
.notch{position:absolute;top:-9px;width:18px;height:18px;border-radius:9px;background:var(--ink)}
.notch.l{left:-9px}.notch.r{right:-9px}
.tile{display:inline-grid;place-items:center;min-width:34px;height:26px;padding:0 6px;border-radius:8px;font:900 15px/1 var(--f-cond);letter-spacing:.3px;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.16)}
.tile.s{min-width:20px;height:20px;padding:0 4px;font-size:11px;border-radius:6px}
.tile.dim{opacity:.55;filter:saturate(.7)}
.bug{position:absolute;right:20px;top:34px;display:flex;align-items:center;gap:5px;font:800 22px/1 var(--f-cond);font-variant-numeric:tabular-nums}
.bug .sc{min-width:14px;text-align:left;color:var(--text-2)} .bug .sc.me{color:#fff} .bug .gap{width:4px}
.bug .me-t{box-shadow:0 0 0 2px var(--ink),0 0 0 3.5px var(--signal)}
.date{font:700 17px/1 var(--f-ui);letter-spacing:-.2px;color:#fff;text-transform:uppercase}
.sub{font:600 11.5px/1.2 var(--f-ui);color:var(--text-2);letter-spacing:.1px}
.sub b{color:var(--signal);font-weight:700}
"""
def head(extra=''):
    return f'<!doctype html>\n<html><head><meta charset="utf-8"><title>{{T}}</title>\n<link rel="stylesheet" href="../../../kit/kit.css">\n<style>{CSS}{extra}</style></head>\n<body class="phone">\n'
FOOT = '<script src="../../../kit/kit.js"></script>\n</body></html>\n'
HEADER = ('<div class="title">Timeline</div><div class="plus"><svg viewBox="0 0 24 24"><path d="M12 4v16M4 12h16"/></svg></div>'
 '<div class="search"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="M16.5 16.5L21 21"/></svg>Teams, places, years</div>')

# cards: (id, bg style, tag)
def bg(card, bw, bh):
    if card == 1: return f'<div class="img" style="{crop("wrigley-scoreboard",719/1280,.33,.5,.62 if bh>300 else .8,bw,bh)}"></div>'
    if card == 2: return f'<div class="img" style="{crop("wrigley-night",2560/1920,.62,.70,.5,bw,bh)}"></div>'
    return '<canvas class="photo-c" data-style="arena" data-seed="11" data-accent="#e8213f" data-secondary="#3a0b14"></canvas>'

# ============================ 09 =============================
def yt_card(n, top, ph):
    d = {
     1: dict(me='CHC', op='MIL', tc='#2F6BFF', w='#8fb0ff', date='Jul 4, 2026', ctx='Win <b>#9</b> of 2026 · Sec 314', win=True, a=('MIL',4), h=('CHC',5),
             head='Chicago <span class="w">win</span><br>5–4.', opp='rival', city='Chicago', champ=False, badge=''),
     2: dict(me='CHC', op='CLE', tc='#2F6BFF', w='#8fb0ff', date='Oct 30, 2016', ctx='Win <b>#6</b> of 2016 · Sec 314', win=True, a=('CLE',2), h=('CHC',3),
             head='Chicago <span class="w">win</span><br>3–2.', opp='over Cleveland · World Series G5', city='Chicago', champ=True, badge='World Series'),
     3: dict(me='CHI', op='LAL', tc='#E8213F', w='#ff6b80', date='Jan 3, 2025', ctx='Loss <b>#2</b> of 2025 · Sec 105', win=False, a=('LAL',118), h=('CHI',104),
             head='Chicago <span class="f">fall</span><br>104–118.', opp='to Los Angeles', city='Chicago', champ=False, badge=''),
    }[n]
    stub_bg = f'background:linear-gradient(180deg,color-mix(in srgb,{d["tc"]} 34%,#14151c),color-mix(in srgb,{d["tc"]} 14%,#12131a))'
    opp = ''
    if d['opp'] == 'rival':
        opp = '<div class="rv"><i></i><span>vs Milwaukee</span><i></i></div>'
    else:
        opp = f'<div class="op">{d["opp"]}</div>'
    badge = f'<div class="evb">{d["badge"]}</div>' if d['badge'] else ''
    am = d['a'][0]==d['me']
    bug = (f'{tile(d["a"][0],"",d["a"][0]!=d["me"])}<span class="sc {"me" if am else ""}">{d["a"][1]}</span><span class="gap"></span>'
           f'{tile(d["h"][0],"",d["h"][0]!=d["me"])}<span class="sc {"me" if not am else ""}">{d["h"][1]}</span>')
    return f'''<div class="card {"champ" if d["champ"] else ""}" style="top:{top}px;height:{ph+92}px;--tc:{d["w"]}">
 <div class="photo" style="height:{ph}px">{bg(n,361,ph)}<div class="scrim"></div>
  <div class="tint" style="background:linear-gradient(to top,color-mix(in srgb,{d["tc"]} 26%,transparent),transparent 55%)"></div>
  <div class="chip">{tile(d["me"],"s")}<span>You were there for <b>{d["city"]}</b></span></div>{badge}
  <div class="hl"><h2>{d["head"]}</h2>{opp}</div></div>
 <div class="stub" style="{stub_bg}"><div class="notch l"></div><div class="notch r"></div>
  <div style="position:absolute;left:20px;top:30px"><div class="date">{d["date"]}</div><div class="sub" style="margin-top:8px">{d["ctx"]}</div></div>
  <div class="bug">{bug}</div></div></div>'''

X9 = """
.tint{position:absolute;inset:0}
.chip{position:absolute;left:12px;top:12px;height:30px;padding:0 12px 0 5px;border-radius:15px;display:flex;align-items:center;gap:7px;background:rgba(18,18,24,.55);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);border:.5px solid rgba(255,255,255,.2);font:500 12px/1 var(--f-ui);color:var(--text-2)}
.chip b{color:#fff;font-weight:700}
.evb{position:absolute;right:12px;top:12px;height:30px;padding:0 12px;border-radius:15px;display:grid;place-items:center;background:#e6cf9a;color:#2a2210;font:800 12px/1 var(--f-cond);letter-spacing:1.4px;text-transform:uppercase}
.op{margin-top:10px;font:600 15px/1.1 var(--f-ui);color:var(--text-2);letter-spacing:.1px}
.rv{margin-top:11px;display:flex;align-items:center;gap:10px}
.rv i{flex:1;height:1px;background:rgba(255,255,255,.28)}
.rv span{font:700 10.5px/1 var(--f-ui);letter-spacing:1.8px;text-transform:uppercase;color:var(--text-2)}
"""
def build09():
    d = os.path.join(FEAT, '09-your-team')
    v1 = head(X9).replace('{T}', 'Your team') + HEADER + yt_card(1, 164, 420) + yt_card(2, 700, 420) + FOOT
    open(os.path.join(d, 'v1-main.html'), 'w').write(v1)
    v2 = head(X9).replace('{T}', 'Your team states') + yt_card(2, 62, 262) + yt_card(3, 62+354+18, 262) + FOOT
    open(os.path.join(d, 'v2-states.html'), 'w').write(v2)
    json.dump({"title": "09 · Your team", "summary": "The card is told from your side: a rooted-team chip, a team-tinted stub, and a headline like \"Chicago win 5–4\" with the opponent demoted."}, open(os.path.join(d, 'feature.json'), 'w'))
    open(os.path.join(d, 'NOTES.md'), 'w').write(
"""- Added: top-left "You were there for Chicago" glass chip with the team monogram; stub gradient tinted in the rooted team's colour (and a faint tint up the photo scrim).
- Headline rewritten from your side ("CHICAGO WIN 5–4." / "CHICAGO FALL 104–118."): WIN takes a light team tint, FALL goes grey; your score is always first, so a loss reads 104–118, not 118–104.
- Opponent demoted to a 15pt line ("over Cleveland · World Series G5"); rivalry games swap it for a hairline "vs Milwaukee" divider. Event badge moves top-right so the chip owns top-left.
- Stub: date plus season context ("Win #9 of 2026 · Sec 314"); score bug keeps the rooted tile at full colour and dims the opponent.
- Data: rootingForTeamId, per-season W/L count, rivalry flag. Risk: two-line headline is shorter than the original on short names; a rival flag needs a data source.
""")

# ============================ 10 =============================
def stamp(code, n, yr, rot=-10, new=False):
    col = '#ffb547'
    ring = f'stroke="{col}" stroke-width="1.6"'
    glow = 'filter="drop-shadow(0 0 3px rgba(255,181,71,.7))"' if new else ''
    return f'''<svg class="stamp" viewBox="0 0 44 44" style="transform:rotate({rot}deg)" {glow}><circle cx="22" cy="22" r="20" fill="none" {ring} {'stroke-dasharray="3 2"' if new else ''}/><circle cx="22" cy="22" r="16.5" fill="none" stroke="{col}" stroke-width=".7" opacity=".8"/>
<text x="22" y="14.5" text-anchor="middle" font-family="Barlow Condensed" font-weight="800" font-size="7.5" letter-spacing=".8" fill="{col}">{code}</text>
<text x="22" y="28.5" text-anchor="middle" font-family="Barlow Condensed" font-weight="800" font-size="15" fill="{col}">{n}</text>
<text x="22" y="36.5" text-anchor="middle" font-family="JetBrains Mono" font-weight="600" font-size="5" letter-spacing=".4" fill="{col}">{yr}</text></svg>'''
def burst(l1, l2):
    import math
    pts = []
    for i in range(32):
        r = 34 if i % 2 == 0 else 28
        a = math.pi * 2 * i / 32
        pts.append(f'{36+r*math.sin(a):.1f},{36-r*math.cos(a):.1f}')
    return f'''<div class="burst"><svg viewBox="0 0 72 72"><polygon points="{' '.join(pts)}" fill="#ffb547"/><circle cx="36" cy="36" r="24.5" fill="none" stroke="#3a2200" stroke-width="1" stroke-dasharray="2 2" opacity=".55"/></svg><div><b>NEW</b><em>{l2}</em></div></div>'''

def fc_card(n, top, ph):
    d = {
     1: dict(head='Chicago 5,<br>Milwaukee 4.', date='Jul 4, 2026', sub='<b>3rd</b> time seeing Milwaukee', a=('MIL',4), h=('CHC',5), me='CHC', champ=False,
             top='count', cnt=('WRIGLEY','#17'), stamp=('WRG','17','2026',False)),
     2: dict(head='Chicago 3,<br>Cleveland 2.', date='Oct 30, 2016', sub='<b>1st</b> time seeing Cleveland', a=('CLE',2), h=('CHC',3), me='CHC', champ=True,
             top='champ+count', cnt=('WRIGLEY','#6'), stamp=('WRG','6','2016',False)),
     3: dict(head='Los Angeles 118,<br>Chicago 104.', date='Jan 3, 2025', sub='<b>1st</b> time seeing Los Angeles', a=('LAL',118), h=('CHI',104), me='CHI', champ=False,
             top='new', cnt=None, stamp=('UC','1','2025',True)),
    }[n]
    tl = tr = ''
    if 'champ' in d['top']: tl = '<div class="evb">World Series · G5</div>'
    if d['top'] == 'count': tr = f'<div class="cnt">{d["cnt"][0]}<b>{d["cnt"][1]}</b></div>'
    if d['top'] == 'champ+count': tr = f'<div class="cnt quiet">{d["cnt"][0]}<b>{d["cnt"][1]}</b></div>'
    if d['top'] == 'new': tr = burst('NEW', 'ARENA')
    am = d['a'][0]==d['me']
    bug = (f'{tile(d["a"][0],"",d["a"][0]!=d["me"])}<span class="sc {"me" if am else ""}">{d["a"][1]}</span><span class="gap"></span>'
           f'{tile(d["h"][0],"",d["h"][0]!=d["me"])}<span class="sc {"me" if not am else ""}">{d["h"][1]}</span>')
    return f'''<div class="card {"champ" if d["champ"] else ""}" style="top:{top}px;height:{ph+92}px;--tc:#fff">
 <div class="photo" style="height:{ph}px">{bg(n,361,ph)}<div class="scrim"></div>{tl}{tr}
  <div class="hl"><h2>{d["head"]}</h2></div></div>
 <div class="stub" style="background:#16171e"><div class="notch l"></div><div class="notch r"></div>
  <div style="position:absolute;left:20px;top:30px"><div class="date">{d["date"]}</div><div class="sub" style="margin-top:8px">{d["sub"]}</div></div>
  <div class="stampw">{stamp(*d["stamp"][:3], new=d["stamp"][3])}</div>
  <div class="bug sm">{bug}</div></div></div>'''

X10 = """
.evb{position:absolute;left:12px;top:12px;height:30px;padding:0 12px;border-radius:15px;display:grid;place-items:center;background:#e6cf9a;color:#2a2210;font:800 12px/1 var(--f-cond);letter-spacing:1.4px;text-transform:uppercase}
.cnt{position:absolute;right:12px;top:12px;height:30px;padding:0 6px 0 13px;border-radius:15px;display:flex;align-items:center;gap:8px;background:rgba(18,18,24,.55);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);border:.5px solid rgba(255,255,255,.22);font:700 11px/1 var(--f-ui);letter-spacing:1.6px;color:#fff}
.cnt b{height:22px;padding:0 9px;border-radius:11px;background:var(--signal);color:#1a1100;display:grid;place-items:center;font:800 15px/1 var(--f-cond);letter-spacing:.3px}
.cnt.quiet{opacity:.92;color:var(--text-2)} .cnt.quiet b{background:rgba(255,181,71,.2);color:var(--signal)}
.burst{position:absolute;right:8px;top:6px;width:76px;height:76px;transform:rotate(9deg);filter:drop-shadow(0 4px 10px rgba(0,0,0,.5))}
.burst svg{position:absolute;inset:0;width:100%;height:100%}
.burst div{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#2a1700;transform:rotate(-9deg)}
.burst b{font:900 25px/.85 var(--f-cond);letter-spacing:.2px} .burst em{font:800 11.5px/1 var(--f-cond);font-style:normal;letter-spacing:1.4px;margin-top:2px}
.stampw{position:absolute;left:176px;top:22px;width:46px;height:46px}
.stamp{width:44px;height:44px;opacity:.95}
.bug.sm{font-size:20px;gap:4px} .bug.sm .tile{min-width:30px;height:24px;font-size:14px}
"""
def build10():
    d = os.path.join(FEAT, '10-firsts-and-counts')
    v1 = head(X10).replace('{T}', 'Firsts and counts') + HEADER + fc_card(1, 164, 420) + fc_card(2, 700, 420) + FOOT
    open(os.path.join(d, 'v1-main.html'), 'w').write(v1)
    # priority legend
    leg = '''<div class="leg"><span>Badge priority</span><i class="a">Championship</i><u>›</u><i class="b">New park</i><u>›</u><i class="c">Count</i></div>'''
    x = X10 + ".leg{position:absolute;left:16px;right:16px;top:58px;height:24px;display:flex;align-items:center;gap:8px;font:600 10.5px/1 var(--f-ui);color:var(--text-3);letter-spacing:.3px} .leg span{letter-spacing:1.4px;text-transform:uppercase;margin-right:2px} .leg i{font-style:normal;padding:4px 8px;border-radius:9px} .leg .a{background:#e6cf9a;color:#2a2210} .leg .b{background:var(--signal);color:#2a1700} .leg .c{background:rgba(255,255,255,.12);color:#fff} .leg u{text-decoration:none;color:var(--text-4)}"
    v2 = head(x).replace('{T}', 'Firsts and counts states') + leg + fc_card(2, 92, 244) + fc_card(3, 92+336+16, 244) + FOOT
    open(os.path.join(d, 'v2-states.html'), 'w').write(v2)
    json.dump({"title": "10 · Firsts and counts", "summary": "Visit-aware badges (venue count chip, NEW PARK starburst, \"3rd time seeing\" and a passport stamp) so the card celebrates what's special about this visit."}, open(os.path.join(d, 'feature.json'), 'w'))
    open(os.path.join(d, 'NOTES.md'), 'w').write(
"""- Added: "WRIGLEY #17" count chip top-right of the photo; amber "NEW ARENA/PARK" starburst replaces it on a first visit; "3rd time seeing Milwaukee" under the date; a tiny rotated passport stamp (dashed and glowing when it is new) between text and score bug.
- Priority when several apply: championship (champagne keyline + top-left badge, owns the card) > new park (starburst) > count (chip). A lower-priority badge is never dropped but drops to a quiet outline chip (card 2 shows championship plus a quiet count); a first visit and a count never co-occur.
- Date and score bug are kept; headline unchanged. The stub carries four items, so the bug is a size smaller (20pt).
- Data: per-venue visit number, first-visit flag, per-opponent meeting count, venue stamp code.
- Risk: the stub is dense; "NEW PARK" is "NEW ARENA" for non-baseball venues (brief's persona has Sam at United Center before, so card 3 is illustrative).
""")
build09(); build10()
