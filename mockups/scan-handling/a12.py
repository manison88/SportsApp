from lib import *

# ---------------------------------------------------------------- APPROACH 1
F = 'approach-1'
feature(F, '1 · Scan everything, foreground', 'One big scan with a live screen and one list to confirm in bulk. The baseline.')

page(F, 'v1-start', 'Find my games', nav(icb('x'), '<div class="txtbtn">Scan settings</div>') + '''
<div class="f-col col">
  <div><div class="mega">52,310</div><div class="hl" style="font-size:30px;margin-top:12px">photos in your library</div></div>
  <div class="f-list">
    <div class="gr" style="min-height:60px"><div class="mid"><div class="t">Scan everything</div><div class="s">Camera Roll and all albums</div></div><div class="end dim">%(chev)s</div></div>
    <div class="gr" style="min-height:60px"><div class="mid"><div class="t">About 8 minutes</div><div class="s">Keep Witness open and the screen on</div></div></div>
  </div>
</div>
<div class="cta"><div class="b-btn">Start scan</div>%(lk)s</div>
''' % dict(chev=ic('chev').replace('<svg', '<svg class="ico24"'), lk=lockline('Photos are read on this iPhone. Nothing is uploaded.')))

LIVE = '''
%(nav)s
<div class="f-col col" style="gap:22px">
  <div><div class="mega" style="font-size:112px">31,204</div>
  <div class="hl" style="font-size:24px;margin-top:10px;color:rgba(255,255,255,.7)">of 52,310 photos checked</div>
  <div class="bar" style="margin-top:16px"><i style="width:60%%"></i></div>
  <div class="sub" style="margin-top:10px">About 3 minutes left</div></div>
  <div class="f-stats"><div><b>1,284</b><span>Near a stadium</span></div><div><b>14</b><span>Venues</span></div><div><b>28</b><span>Games</span></div></div>
  <div class="f-list">
    <div class="gr" style="min-height:62px">%(m1)s<div class="mid"><div class="t">%(b1)s</div><div class="s">Wrigley Field, Jul 4 2026</div></div><div class="end tag amb">New</div></div>
    <div class="gr" style="min-height:62px">%(m2)s<div class="mid"><div class="t">%(b2)s</div><div class="s">Lambeau Field, Dec 14 2025</div></div></div>
    <div class="gr" style="min-height:62px">%(m3)s<div class="mid"><div class="t">%(b3)s</div><div class="s">Fenway Park, Jun 12 2024</div></div></div>
  </div>
</div>
<div class="cta">%(lk)s</div>
'''
page(F, 'v2-scanning', 'Scanning', LIVE % dict(
    nav=nav('<div class="b-label" style="color:#fff;display:flex;gap:8px;align-items:center"><span class="b-dot" style="background:var(--amber);box-shadow:0 0 10px var(--amber)"></span>Scanning</div>', '<div class="b-btn ghost" style="height:40px;padding:0 16px;font-size:14px">Pause</div>'),
    m1=mono('CHC'), m2=mono('GB'), m3=mono('BOS'), b1='CHC 4 <em>MIL 3</em>', b2='GB 17 <em>CHI 20</em>', b3='CHC 3 <em>BOS 6</em>',
    lk=lockline('Reading dates and places on this iPhone. Nothing leaves it.')))

def grow(thumb, pos, a, sa, b, sb, sub, on=True, flag=''):
    return ('<div class="gr">%s<div class="th ph">%s</div><div class="mid"><div class="t">%s <em>%s</em></div><div class="s">%s</div></div>%s</div>') % (
        cb(on), im(thumb, pos), '%s %s' % (a, sa), '%s %s' % (b, sb), sub, flag)

page(F, 'v3-results', 'Results', nav(icb('x'), '<div class="txtbtn">Deselect all</div>') + '''
<div class="f-col" style="top:108px;gap:6px;bottom:150px;overflow:hidden">
  <div class="hl" style="font-size:44px">47 games found</div>
  <div class="f-list" style="margin-top:10px">
  ''' + grow('wrigley-night.jpg', '50% 38%', 'CLE', 2, 'CHC', 3, 'World Series · Oct 30 2016') +
  grow('wrigley-bleachers.jpg', '50% 50%', 'MIL', 3, 'CHC', 4, 'Wrigley Field · Jul 4 2026') +
  grow('lambeau-concourse.jpg', '50% 80%', 'CHI', 20, 'GB', 17, 'Lambeau Field · Dec 14 2025') +
  grow('fenway-night.jpg', '50% 40%', 'CHC', 3, 'BOS', 6, 'Fenway Park · Jun 12 2024') +
  grow('united-center-court.jpg', '50% 50%', 'BCS', 101, 'BUL', 108, 'United Center · Jan 19 2025') +
  grow('soldier-soccer.jpg', '50% 50%', 'ORL', 1, 'CFC', 2, 'Soldier Field · Aug 9 2025') +
  grow('wrigley-night-2.jpg', '50% 40%', 'MIL', '', 'CHC', '', 'Wrigley rooftop · Jun 2 2024', False, '<div class="end tag amb">Check</div>') + '''
  </div>
</div>
<div class="cta" style="bottom:36px"><div class="b-btn">Add 45 games</div>''' + lockline('Matched on this iPhone') + '</div>')

page(F, 'v4-done', 'Done', nav(icb('x')) + '''
<div class="f-col col">
  <div><div class="mega" style="font-size:150px">45</div><div class="hl" style="font-size:34px;margin-top:8px">games added</div></div>
  <div class="f-stats"><div><b>2</b><span>Stadium visits</span></div><div><b>0</b><span>Skipped</span></div></div>
  <div class="f-list">
    <div class="gr" style="min-height:62px"><div class="mid"><div class="t">Missing one?</div><div class="s">Rescan a date or add a game by hand</div></div><div class="end">%(c)s</div></div>
  </div>
</div>
<div class="cta"><div class="b-btn">See timeline</div></div>''' % dict(c=ic('chev').replace('<svg', '<svg class="ico24"')))

PAUSE_BG = '''<div style="position:absolute;inset:0;background:#07080a"></div>'''
page(F, 'v5-paused-edge', 'Scan paused', nav(icb('x')) + '''
<div class="f-col col">
  <div><div class="hl" style="font-size:44px">Scan paused</div><div class="sub" style="margin-top:12px;font-size:16px">You left Witness. iOS stops a foreground scan after a few seconds, so it stopped at 60%.</div></div>
  <div><div class="bar"><i style="width:60%"></i></div>
  <div class="f-between" style="margin-top:12px"><span class="sub">31,204 of 52,310 photos</span><span class="sub" style="color:#fff;font-weight:700">28 games saved</span></div></div>
  <div class="f-list">
    <div class="gr" style="min-height:60px"><div class="mid"><div class="t">Nothing is lost</div><div class="s">Games found so far wait for you</div></div></div>
    <div class="gr" style="min-height:60px"><div class="mid"><div class="t">Resume picks up at photo 31,205</div><div class="s">Already checked photos are skipped</div></div></div>
  </div>
</div>
<div class="cta"><div class="b-btn">Resume scan</div><div class="link">Review 28 games now</div></div>''')

SHEET1 = '''
<div class="scrimall"></div>
<div class="sheet" style="padding-bottom:40px">
  <div class="grab"></div>
  <div class="hl" style="font-size:32px">Wrong game?</div>
  <div class="sub" style="margin-top:8px;margin-bottom:6px">Wrigley Field, Jul 4 2026. Your photos were taken 5:48 to 9:30 PM.</div>
  <div class="opt"><div class="rad"></div><div class="mid"><div class="t">MIL at CHC, 1:20 PM</div><div class="s">Matched first, ended before your photos</div></div></div>
  <div class="opt"><div class="rad on"></div><div class="mid"><div class="t">MIL at CHC, 7:05 PM</div><div class="s">Closest to your photos</div></div></div>
  <div class="opt"><div class="mid"><div class="t" style="color:rgba(255,255,255,.8)">Not a game</div></div></div>
  <div class="b-btn" style="width:100%;height:54px;font-size:17px;margin-top:14px">Save change</div>
</div>'''
page(F, 'v6-fix-row', 'Fix a row', '''<div style="position:absolute;inset:0">''' + nav(icb('x'), '<div class="txtbtn">Deselect all</div>') + '''
<div class="f-col" style="top:108px;gap:6px"><div class="hl" style="font-size:44px">47 games found</div><div class="f-list" style="margin-top:10px">''' +
  grow('wrigley-night.jpg', '50% 38%', 'CLE', 2, 'CHC', 3, 'World Series · Oct 30 2016') +
  grow('wrigley-bleachers.jpg', '50% 50%', 'MIL', 3, 'CHC', 4, 'Wrigley Field · Jul 4 2026', True, '<div class="end tag amb">Tapped</div>') +
  grow('lambeau-concourse.jpg', '50% 80%', 'CHI', 20, 'GB', 17, 'Lambeau Field · Dec 14 2025') +
  grow('fenway-night.jpg', '50% 40%', 'CHC', 3, 'BOS', 6, 'Fenway Park · Jun 12 2024') + '</div></div></div>' + SHEET1)

# ---------------------------------------------------------------- APPROACH 2
F = 'approach-2'
feature(F, '2 · Background scan + inbox', 'Scan runs in the background with a Live Activity. Results land in a Games found inbox with a badge on Timeline.')

def timeline_bg():
    return '''<div class="f-title" style="position:absolute;left:20px;top:60px">Timeline</div>
<div style="position:absolute;left:20px;right:20px;top:112px;height:300px;border-radius:16px;overflow:hidden" class="ph">%s</div>
<div style="position:absolute;left:20px;right:20px;top:428px;height:130px;border-radius:16px;overflow:hidden" class="ph">%s</div>''' % (im('wrigley-night.jpg'), im('wrigley-bleachers.jpg'))

page(F, 'v1-start', 'Background scan', timeline_bg() + tabs(0) + '''
<div class="scrimall"></div>
<div class="sheet" style="padding-bottom:40px">
  <div class="grab"></div>
  <div class="hl" style="font-size:36px">Find my games while you do other things</div>
  <div class="sub" style="margin:10px 0 8px">52,310 photos. It runs in the background and tells you when games are ready.</div>
  <div class="opt"><div class="mid"><div class="t">Live Activity</div><div class="s">Progress on your Lock Screen</div></div><div class="tg on"></div></div>
  <div class="opt"><div class="mid"><div class="t">Notify me when done</div></div><div class="tg on"></div></div>
  <div class="opt"><div class="mid"><div class="t">Only while charging</div><div class="s">Faster, easier on battery</div></div><div class="tg"></div></div>
  <div class="b-btn" style="width:100%;height:54px;font-size:17px;margin-top:14px">Start in background</div>
  <div style="margin-top:12px">''' + lockline('Checked on this iPhone. Nothing is uploaded.') + '</div></div>')

LOCKCSS = '''
.wall{position:absolute;inset:0}.wall .im{filter:blur(18px) brightness(.45) saturate(.8);transform:scale(1.2)}
.clock{position:absolute;top:100px;left:0;right:0;text-align:center}
.clock .d{font:600 20px/1 var(--b-ui);color:rgba(255,255,255,.8)}
.clock .tm{font:700 100px/1 var(--b-ui);letter-spacing:-2px;margin-top:6px}
.la{position:absolute;left:12px;right:12px;border-radius:26px;background:rgba(32,34,40,.72);backdrop-filter:blur(30px);padding:16px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.1)}
.la .hd{display:flex;align-items:center;gap:12px}
.la .nm{font:700 16px/1.2 var(--b-ui)}
.la .sm{font:500 13px/1.3 var(--b-ui);color:rgba(255,255,255,.66)}
.la .pc{margin-left:auto;font:800 30px/1 var(--b-cond);font-variant-numeric:tabular-nums}
.la .bar{margin:14px 0 12px}
.la .st{display:flex;justify-content:space-between;font:500 13px/1.2 var(--b-ui);color:rgba(255,255,255,.7)}
.la .st b{color:#fff;font:800 20px/1 var(--b-cond);margin-right:5px}
'''
def lock(inner, after=''):
    return '<div class="wall">%s</div><div class="clock"><div class="d">Tuesday, October 17</div><div class="tm">9:41</div></div>%s' % (im('wrigley-night-2.jpg', '50% 40%'), inner)

page(F, 'v2-live-activity', 'Live Activity', lock('''
<div class="la" style="top:330px">
  <div class="hd"><div class="wtile">W</div><div><div class="nm">Finding your games</div><div class="sm">On this iPhone</div></div><div class="pc">60%</div></div>
  <div class="bar"><i style="width:60%"></i></div>
  <div class="st"><span><b>31,204</b>checked</span><span><b>14</b>venues</span><span><b>47</b>games</span></div>
</div>'''), LOCKCSS, chrome=None)

page(F, 'v3-notification', 'Notification', lock('''
<div class="la" style="top:330px;padding:14px 16px">
  <div class="hd"><div class="wtile">W</div><div style="flex:1"><div class="f-between"><div class="nm">Witness</div><div class="sm">now</div></div>
  <div class="nm" style="font-weight:600;margin-top:3px">47 games found in your photos</div>
  <div class="sm" style="margin-top:2px">38 look certain. Tap to review. All checked on this iPhone.</div></div></div>
</div>
<div class="la" style="top:458px;opacity:.55;padding:12px 16px"><div class="hd"><div class="wtile" style="width:30px;height:30px;font-size:17px">W</div><div class="sm">Finding your games ended after 14 minutes</div></div></div>'''), LOCKCSS)

page(F, 'v4-paused-edge', 'Paused', lock('''
<div class="la" style="top:330px">
  <div class="hd"><div class="wtile">W</div><div><div class="nm">Scan paused</div><div class="sm">Low Power Mode is on</div></div><div class="pc" style="color:var(--amber)">42%</div></div>
  <div class="bar"><i style="width:42%;background:var(--amber)"></i></div>
  <div class="st"><span><b>21,900</b>checked</span><span><b>9</b>venues</span><span><b>23</b>games</span></div>
</div>
<div class="la" style="top:470px;padding:14px 16px">
  <div class="hd"><div class="wtile">W</div><div style="flex:1"><div class="f-between"><div class="nm">Witness</div><div class="sm">2 min ago</div></div>
  <div class="nm" style="font-weight:600;margin-top:3px">Scan paused at 42%</div>
  <div class="sm" style="margin-top:2px">It resumes when you charge or turn off Low Power Mode. 23 games are already in your inbox.</div></div></div>
</div>'''), LOCKCSS)

def irow(img, pos, a, sa, b, sb, sub, right='', swiped=False):
    inner = ('<div class="gr" style="min-height:70px;background:#07080a;position:relative;%s"><div class="th ph" style="width:56px;height:56px">%s</div>'
             '<div class="mid"><div class="t">%s %s <em>%s %s</em></div><div class="s">%s</div></div>%s</div>') % (
        'transform:translateX(-168px);' if swiped else '', im(img, pos), '', a + ' ' + str(sa), b, sb, sub, right)
    return inner

ADD = '<div class="b-btn" style="height:38px;padding:0 16px;font-size:14px;border-radius:10px">Add</div>'
def inbox_row(img, pos, a, sa, b, sb, sub, right=ADD):
    return ('<div class="gr" style="min-height:72px"><div class="th ph" style="width:56px;height:56px">%s</div>'
            '<div class="mid"><div class="t">%s %s <em>%s %s</em></div><div class="s">%s</div></div>%s</div>') % (im(img, pos), a, sa, b, sb, sub, right)

swiped = ('<div style="box-shadow:inset 0 -1px 0 var(--b-line);padding-bottom:12px">'
  '<div class="gr" style="min-height:72px;box-shadow:none"><div class="th ph" style="width:56px;height:56px">%s</div>'
  '<div class="mid"><div class="t">CHI 20 <em>GB 17</em></div><div class="s">Lambeau Field · Dec 14 2025</div></div>%s</div>'
  '<div style="display:flex;gap:10px"><div class="b-btn" style="flex:1;height:44px;font-size:14px;background:var(--amber)">Wrong game</div><div class="b-btn ghost" style="flex:1;height:44px;font-size:14px">Not a game</div></div></div>') % (im('lambeau-concourse.jpg'), '<div class="end tag amb">Fixing</div>')

page(F, 'v5-inbox', 'Games found', nav('<div class="f-title">Games found</div>', icb('more')) + '''
<div class="f-col" style="top:116px;gap:14px;bottom:100px;overflow:hidden">
  <div class="f-between" style="gap:16px"><div><div class="hl" style="font-size:44px;line-height:.9">47</div><div class="sub">38 look certain</div></div><div class="b-btn" style="height:48px;padding:0 20px;flex:none">Add 38</div></div>
  <div class="f-list">''' +
  inbox_row('wrigley-bleachers.jpg', '50% 50%', 'MIL', 3, 'CHC', 4, 'Wrigley Field · Jul 4 2026', '<div class="end tag amb">New</div>') +
  inbox_row('wrigley-night.jpg', '50% 38%', 'CLE', 2, 'CHC', 3, 'World Series · Oct 30 2016', ADD) +
  swiped +
  inbox_row('fenway-night.jpg', '50% 40%', 'CHC', 3, 'BOS', 6, 'Fenway Park · Jun 12 2024') +
  inbox_row('united-center-court.jpg', '50% 50%', 'BCS', 101, 'BUL', 108, 'United Center · Jan 19 2025', '<div class="end tag amb">Check</div>') +
  '''</div></div>''' + tabs(0, '47'))

page(F, 'v6-all-caught-up', 'All caught up', nav('<div class="f-title">Games found</div>', icb('more')) + '''
<div class="f-col col" style="top:116px">
  <div><div class="mega" style="font-size:130px">0</div><div class="hl" style="font-size:32px;margin-top:10px">to review</div><div class="sub" style="margin-top:10px">45 games added. 2 were not games.</div></div>
  <div class="f-list">
    <div class="gr" style="min-height:64px"><div class="mid"><div class="t">New photos are checked automatically</div><div class="s">Last checked 2 minutes ago</div></div><div class="tg on"></div></div>
    <div class="gr" style="min-height:64px"><div class="mid"><div class="t">Wrigley Field, last night</div><div class="s">1 new game will arrive here</div></div></div>
  </div>
  <div class="b-panel" style="padding:16px;display:flex;gap:12px;align-items:flex-start"><span class="lock" style="margin-top:1px">%s</span><div class="sub" style="font-size:14px">Everything runs on this iPhone. Witness never uploads your photos.</div></div>
</div>''' % I['lock'] + tabs(0))
