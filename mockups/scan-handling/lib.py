import os, json
ROOT = os.path.dirname(os.path.abspath(__file__))
P = '../../../photos/'

CSS = r"""
body.b { --b-text-3: rgba(255,255,255,.62); --amber:#ffb547; }
.b-body{font-size:15px}
.im{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;filter:contrast(1.05) saturate(.92) brightness(.92)}
.abs{position:absolute;inset:0}
.ph{position:relative;overflow:hidden;background:#1a1c21}
.amber{color:var(--amber)}
.dim{color:rgba(255,255,255,.62)}
.cta{position:absolute;left:20px;right:20px;bottom:36px;display:flex;flex-direction:column;gap:10px}
.cta .b-btn{width:100%;height:54px;font-size:17px;box-shadow:inset 0 1px 0 rgba(255,255,255,.7),inset 0 -1px 0 rgba(0,0,0,.25)}
.cta .b-btn.ghost{box-shadow:inset 0 0 0 1px var(--b-line)}
.row2{display:flex;gap:10px}.row2 .b-btn{flex:1}
.link{height:44px;display:flex;align-items:center;justify-content:center;font:700 15px/1 var(--b-cond);letter-spacing:1.4px;text-transform:uppercase;color:rgba(255,255,255,.86)}
.lock{display:flex;align-items:center;justify-content:center;gap:8px;color:rgba(255,255,255,.66);font:500 13px/1.3 var(--b-ui);text-align:center}
.lock svg,.ico{width:16px;height:16px;stroke:currentColor;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;flex:none}
.ico24{width:24px;height:24px;stroke:currentColor;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
.txtbtn{height:40px;padding:0 4px;display:flex;align-items:center;font:800 14px/1 var(--b-cond);letter-spacing:1.4px;text-transform:uppercase;color:#fff}
.col{top:112px;gap:24px}
.mega{font:800 118px/.9 var(--b-cond);letter-spacing:-3px;margin-left:-3px;font-variant-numeric:tabular-nums}
.hl{font:800 40px/.98 var(--b-cond);text-transform:uppercase;letter-spacing:.2px}
.sub{font:500 15px/1.4 var(--b-ui);color:rgba(255,255,255,.7)}
.bar{height:5px;border-radius:3px;background:rgba(255,255,255,.14);overflow:hidden}
.bar i{display:block;height:100%;background:#fff}
.cb{width:26px;height:26px;border-radius:50%;flex:none;display:grid;place-items:center;box-shadow:inset 0 0 0 2px rgba(255,255,255,.4)}
.cb svg{width:15px;height:15px;stroke:#000;fill:none;stroke-width:3;stroke-linecap:round;stroke-linejoin:round;display:none}
.cb.on{background:#fff;box-shadow:none}.cb.on svg{display:block}
.th{width:54px;height:54px;border-radius:10px;flex:none}
.gr{display:flex;align-items:center;gap:12px;min-height:68px;box-shadow:inset 0 -1px 0 var(--b-line)}
.gr:last-child{box-shadow:none}
.gr .t{font:800 19px/1 var(--b-cond);letter-spacing:.5px;text-transform:uppercase;display:flex;align-items:center;gap:6px}
.gr .t em{font-style:normal;opacity:.6;font-weight:700}
.gr .s{font:500 13px/1.3 var(--b-ui);color:rgba(255,255,255,.64);margin-top:4px}
.gr .mid{flex:1;min-width:0}
.gr .end{text-align:right;flex:none}
.tag{font:800 12px/1 var(--b-cond);letter-spacing:1.3px;text-transform:uppercase;color:rgba(255,255,255,.7)}
.tag.amb{color:var(--amber)}
.sheet{position:absolute;left:0;right:0;bottom:0;background:#15171c;border-radius:26px 26px 0 0;padding:10px 20px 36px;box-shadow:inset 0 1px 0 rgba(255,255,255,.12);z-index:40}
.sheet .grab{width:38px;height:5px;border-radius:3px;background:rgba(255,255,255,.25);margin:0 auto 18px}
.scrimall{position:absolute;inset:0;background:rgba(0,0,0,.62);z-index:35}
.opt{display:flex;align-items:center;gap:14px;min-height:64px;box-shadow:inset 0 -1px 0 var(--b-line)}
.opt:last-child{box-shadow:none}
.opt .t{font:800 19px/1 var(--b-cond);letter-spacing:.5px;text-transform:uppercase}
.opt .s{font:500 13px/1.3 var(--b-ui);color:rgba(255,255,255,.64);margin-top:4px}
.opt .mid{flex:1}
.rad{width:24px;height:24px;border-radius:50%;box-shadow:inset 0 0 0 2px rgba(255,255,255,.4);flex:none}
.rad.on{box-shadow:inset 0 0 0 7px #fff}
.tg{width:52px;height:32px;border-radius:16px;background:rgba(255,255,255,.18);position:relative;flex:none}
.tg::after{content:"";position:absolute;top:3px;left:3px;width:26px;height:26px;border-radius:50%;background:#fff}
.tg.on{background:#fff}.tg.on::after{left:23px;background:#000}
.ibox{width:44px;height:44px;border-radius:12px;display:grid;place-items:center;background:var(--b-panel-2);box-shadow:inset 0 0 0 1px var(--b-line);flex:none}
.ibox svg{width:22px;height:22px;stroke:#fff;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
.badge{position:absolute;top:-4px;left:50%;margin-left:4px;min-width:22px;height:20px;border-radius:10px;background:#fff;color:#000;font:800 13px/20px var(--b-cond);text-align:center;padding:0 5px}
.wtile{width:38px;height:38px;border-radius:10px;background:#0b0c0f;box-shadow:inset 0 0 0 1px rgba(255,255,255,.25);display:grid;place-items:center;font:800 22px/1 var(--b-cond);flex:none}
.b-bug.sm{height:28px;font-size:15px}
.f-stats b{font-size:36px}
.f-stats span{letter-spacing:1.6px}
"""

I = {
 'lock':'<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>',
 'check':'<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7"/></svg>',
 'x':'<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',
 'back':'<svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg>',
 'chev':'<svg viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></svg>',
 'clock':'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
 'undo':'<svg viewBox="0 0 24 24"><path d="M9 7L4 12l5 5"/><path d="M4 12h11a5 5 0 0 1 0 10h-3"/></svg>',
 'up':'<svg viewBox="0 0 24 24"><path d="M12 19V5M6 11l6-6 6 6"/></svg>',
 'sliders':'<svg viewBox="0 0 24 24"><path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/></svg>',
 'pin':'<svg viewBox="0 0 24 24"><path d="M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.800 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/></svg>',
 'cal':'<svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/></svg>',
 'album':'<svg viewBox="0 0 24 24"><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M6 4h12M8 1.500h8"/><circle cx="9" cy="12" r="1.500"/><path d="M4 18l5-4 4 3 3-2 5 4"/></svg>',
 'search':'<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.500"/><path d="M20 20l-4.500-4.500"/></svg>',
 'plus':'<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
 'more':'<svg viewBox="0 0 24 24"><circle cx="5" cy="12" r="1.200"/><circle cx="12" cy="12" r="1.200"/><circle cx="19" cy="12" r="1.200"/></svg>',
 'seal':'<svg viewBox="0 0 24 24"><path d="M12 3l2.200 1.600 2.700-.1 .9 2.600 2.200 1.600-.8 2.600.8 2.600-2.200 1.600-.9 2.600-2.700-.1L12 21l-2.200-1.600-2.700.1-.9-2.600L4 15.300l.8-2.600L4 10.100l2.200-1.600.9-2.600 2.700.1z"/><path d="M8.500 12l2.500 2.500 4.500-5"/></svg>',
 'cal2':'<svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/></svg>',
 'pinring':'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2.500"/></svg>',
 'trash':'<svg viewBox="0 0 24 24"><path d="M5 7h14M10 7V4h4v3M7 7l1 13h8l1-13"/></svg>',
 'refresh':'<svg viewBox="0 0 24 24"><path d="M20 12a8 8 0 1 1-2.500-5.800M20 4v5h-5"/></svg>',
 'video':'<svg viewBox="0 0 24 24"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 11l5-3v8l-5-3z"/></svg>',
 'flag':'<svg viewBox="0 0 24 24"><path d="M5 21V4M5 5h12l-2 4 2 4H5"/></svg>',
 'swap':'<svg viewBox="0 0 24 24"><path d="M4 8h14M14 4l4 4-4 4M20 16H6M10 12l-4 4 4 4"/></svg>',
}
def ic(n): return I[n]
def icb(n, extra=''): return '<div class="b-icon-btn" %s>%s</div>' % (extra, I[n])

TABS = ['<span%s><svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="9" rx="2"/><path d="M4 17h16M4 21h10"/></svg>Timeline%s</span>',
 '<span%s><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3.2 3.4 3.2 14.6 0 18M12 3c-3.2 3.4-3.2 14.6 0 18"/></svg>Map</span>',
 '<span%s><svg viewBox="0 0 24 24"><rect x="5" y="3" width="14" height="18" rx="2"/><circle cx="12" cy="11" r="3.5"/><path d="M9 17.5h6"/></svg>Passport</span>',
 '<span%s><svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.4-4 4.4-6 8-6s6.6 2 8 6"/></svg>You</span>']
def tabs(on=0, badge=None):
    out = []
    for i, t in enumerate(TABS):
        cls = ' class="on"' if i == on else ''
        if i == 0:
            b = '<i class="badge">%s</i>' % badge if badge else ''
            out.append(t % (cls, b))
        else: out.append(t % cls)
    return '<nav class="b-tabs">' + ''.join(out) + '</nav>'

COL = dict(CHC='#2f6bff', MIL='#ffc52f', CLE='#e31937', CHI='#f05a1a', GB='#ffb612', BOS='#c8102e', CFC='#d6264a', ORL='#7b3fa0', FCB='#a50044', RSO='#1e5cb3', BUL='#ce1141', BCS='#1a8a4a')
def tc(c): return COL[c]
def txt(c): return '#111' if c in ('MIL', 'GB') else '#fff'
def mono(c, s=''):
    return '<span class="f-mono" style="--c:%s;color:%s;%s">%s</span>' % (COL[c], txt(c), s, c)
def bug(a, sa, b, sb, cls=''):
    return ('<span class="b-bug %s"><span class="team" style="--c:%s;color:%s">%s</span><span class="score">%s</span>'
            '<span class="team" style="--c:%s;color:%s">%s</span><span class="score">%s</span></span>') % (cls, COL[a], txt(a), a, sa, COL[b], txt(b), b, sb)
def im(f, pos='50% 50%', extra=''):
    t = pos.split()
    z = None
    if len(t) == 3: z = float(t[2]); pos = ' '.join(t[:2])
    elif f.startswith('wrigley-night') : z = 1.9; pos = '60% 92%'
    elif f == 'lambeau-concourse.jpg': z = 1.6; pos = '50% 96%'
    if z: extra += 'transform:scale(%s);transform-origin:%s;' % (z, pos)
    return '<img class="im" src="%s%s" style="object-position:%s;%s">' % (P, f, pos, extra)
def ph(f, pos='50% 50%', cls='', style=''):
    return '<div class="ph %s" style="%s">%s</div>' % (cls, style, im(f, pos))
def lockline(t):
    return '<div class="lock">%s%s</div>' % (I['lock'], t)
def cb(on=True): return '<div class="cb %s">%s</div>' % ('on' if on else '', I['check'])

def page(folder, name, title, body, css='', chrome=None):
    d = os.path.join(ROOT, 'features', folder); os.makedirs(d, exist_ok=True)
    ch = ' data-chrome="%s"' % chrome if chrome else ''
    html = ('<!doctype html>\n<html><head><meta charset="utf-8"><title>%s</title>\n'
     '<link rel="stylesheet" href="../../../kit/kit.css">\n<link rel="stylesheet" href="../../../round2/system/broadcast.css">\n'
     '<link rel="stylesheet" href="../../../final/system/final.css">\n<style>%s%s</style></head>\n<body class="phone b"%s>\n%s\n'
     '<script src="../../../kit/kit.js"></script>\n</body></html>') % (title, CSS, css, ch, body)
    open(os.path.join(d, name + '.html'), 'w').write(html)

def feature(folder, title, summary):
    d = os.path.join(ROOT, 'features', folder); os.makedirs(d, exist_ok=True)
    json.dump({'title': title, 'summary': summary}, open(os.path.join(d, 'feature.json'), 'w'))

def nav(left='', right='', mid=''):
    return '<div class="b-nav">%s%s%s</div>' % (left or '<span></span>', mid, right or '<span></span>')
