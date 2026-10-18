#!/usr/bin/env python3
"""Generates the game-hero variations. Run: python3 gen.py"""
import os, json
HERE = os.path.dirname(os.path.abspath(__file__))

IC = {
 'ywt': '<svg viewBox="0 0 24 24"><path d="M2 12.5h4.2l2.3-6.5 4 12 3-8.5 1.6 3H22"/></svg>',
 'stadium': '<svg viewBox="0 0 24 24"><path d="M3 9.2 12 4l9 5.2z"/><path d="M5.5 11.5v6.5M9.8 11.5v6.5M14.2 11.5v6.5M18.5 11.5v6.5M3 20.5h18"/></svg>',
 'trip': '<svg viewBox="0 0 24 24"><path d="M21 15.2v-1.7l-8-5V4.4a1.5 1.5 0 0 0-3 0v4.1l-8 5v1.7l8-2.4v3.7l-2 1.5V20l3.5-.9 3.5.9v-1.5l-2-1.5v-3.7z"/></svg>',
 'cloud': '<svg viewBox="0 0 24 24"><path d="M7 18a4 4 0 0 1-.6-7.95A5.5 5.5 0 0 1 17 10.6 3.7 3.7 0 0 1 17 18z"/></svg>',
 'moon': '<svg viewBox="0 0 24 24"><path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/></svg>',
 'back': '<svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg>',
 'share': '<svg viewBox="0 0 24 24"><path d="M12 15V4M8 7.5 12 3.5l4 4M6 11H5.5A1.5 1.5 0 0 0 4 12.5v6A1.5 1.5 0 0 0 5.5 20h13a1.5 1.5 0 0 0 1.5-1.5v-6A1.5 1.5 0 0 0 18.5 11H18"/></svg>',
 'more': '<svg viewBox="0 0 24 24"><circle cx="5.5" cy="12" r=".6"/><circle cx="12" cy="12" r=".6"/><circle cx="18.5" cy="12" r=".6"/></svg>',
}
LABEL = {'ywt': ('YOU WERE<br>THERE', 'You were there'), 'stadium': ('STADIUM', 'Stadium'), 'trip': ('TRIP', 'Trip')}

BASE_CSS = """
:root{--trophy:#e9d3a1;--trophy-2:#c9b07a;--acc:var(--signal)}
body.champ{--acc:var(--trophy)}
.cover{position:absolute;left:0;right:0;top:0;height:548px;overflow:hidden}
.cover .ph{position:absolute;inset:0;width:100%;height:100%}
.cover .scrim{position:absolute;inset:0;background:
  linear-gradient(180deg,rgba(5,5,6,.85) 0,rgba(5,5,6,.45) 22%,rgba(5,5,6,0) 40%),
  linear-gradient(0deg,rgba(5,5,6,1) 0,rgba(5,5,6,.9) 22%,rgba(5,5,6,.55) 48%,rgba(5,5,6,0) 74%)}
.nav{position:absolute;top:58px;left:16px;right:16px;display:flex;justify-content:space-between;z-index:5}
.nav .r{display:flex;gap:10px}
.nav .btn-circle{width:40px;height:40px}
.nav .btn-circle svg{width:19px;height:19px}
.nav .more svg{fill:#fff;stroke:none}
.info{position:absolute;left:20px;right:20px;bottom:20px;display:flex;align-items:flex-end;gap:12px;z-index:4}
.info .txt{flex:1;min-width:0}
.badge{display:inline-flex;align-items:center;gap:7px;height:24px;padding:0 10px 0 9px;border-radius:12px;
  font:700 10.5px/1 var(--f-ui);letter-spacing:1.5px;text-transform:uppercase;margin-bottom:12px;color:var(--ink);background:var(--acc)}
.badge i{width:5px;height:5px;border-radius:3px;background:var(--ink);opacity:.55}
.hl{display:flex;flex-direction:column;gap:2px;font-family:var(--f-cond);font-weight:800;text-transform:uppercase;
  line-height:.94;letter-spacing:.2px;color:var(--text)}
.hl .ln{display:grid;grid-template-columns:.2em minmax(0,1fr) 1.22em;column-gap:.14em;align-items:baseline}
.hl .nm{white-space:nowrap;display:inline-block;justify-self:start}
.hl .sc{text-align:right;font-variant-numeric:tabular-nums;font-feature-settings:"tnum" 1}
.hl .dot{width:.1em;height:.1em;min-width:5px;min-height:5px;border-radius:50%;background:var(--acc);align-self:center;transform:translateY(-.02em)}
.hl .ln.lose{color:var(--text-2)}
.hl .ln.lose .sc{color:var(--text-2)}
.meta{margin-top:12px;font:500 13.5px/1.35 var(--f-ui);color:var(--text-2)}
.meta b{font-weight:600;color:var(--text)}
.ko{display:flex;align-items:center;gap:6px;margin-top:6px;font:600 12.5px/1 var(--f-ui);color:var(--text-2);letter-spacing:.1px}
.ko svg{width:16px;height:16px;stroke:var(--text-2);fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}
.ko .sep{width:2px;height:2px;border-radius:1px;background:var(--text-3)}
.act svg{stroke:#fff;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.cap{font:700 10px/1.18 var(--f-ui);letter-spacing:.9px;text-transform:uppercase;color:rgba(255,255,255,.82);text-align:center}
/* below the cover */
.sheet{position:absolute;left:0;right:0;top:548px;bottom:0;padding:6px 20px 0}
.sec{font:600 11px/1 var(--f-ui);letter-spacing:1.8px;text-transform:uppercase;color:var(--text-3)}
.tbl{margin-top:12px;border-radius:18px;background:var(--surface);border:.5px solid var(--line);padding:4px 16px}
.tr{display:grid;align-items:center;height:46px;font:600 15px/1 var(--f-ui);border-bottom:.5px solid var(--line)}
.tr:last-child{border-bottom:0}
.tr.h{height:34px;font:600 10.5px/1 var(--f-ui);letter-spacing:1.4px;color:var(--text-3);text-transform:uppercase}
.tr .c{text-align:right;font-variant-numeric:tabular-nums;color:var(--text-2)}
.tr .c.f{color:var(--text);font-weight:700}
.tm{display:flex;align-items:center;gap:10px}
.tm .mono-badge{width:24px;height:24px;font-size:12px;border-radius:7px}
.chips{display:flex;gap:8px;margin-top:12px;flex-wrap:nowrap}
.chip{height:34px;padding:0 13px;border-radius:17px;background:var(--raised);border:.5px solid var(--line-2);font:600 13px/34px var(--f-ui);color:var(--text);white-space:nowrap}
.chip.on{background:color-mix(in srgb,var(--acc) 18%,transparent);border-color:color-mix(in srgb,var(--acc) 55%,transparent);color:var(--acc)}
"""

# ---- three icon treatments -------------------------------------------------
def v1_css():
    return """
.rail{display:flex;flex-direction:column;gap:12px;width:72px;align-items:center;flex:none}
.rail .it{display:flex;flex-direction:column;align-items:center;gap:6px;width:72px}
.rail .btn-circle{width:50px;height:50px;border-radius:25px;background:rgba(22,22,26,.5)}
.rail .btn-circle svg{width:23px;height:23px;stroke:#fff;fill:none;stroke-width:1.8}
.rail .it.k .btn-circle{background:color-mix(in srgb,var(--acc) 22%,rgba(22,22,26,.5));border-color:color-mix(in srgb,var(--acc) 60%,transparent)}
.rail .it.k .btn-circle svg{stroke:var(--acc)}
"""
def v1_html(items):
    out = '<div class="rail">'
    for i, k in enumerate(items):
        out += f'<div class="it {"k" if k=="ywt" else ""}"><div class="btn-circle glass act">{IC[k]}</div><div class="cap">{LABEL[k][0]}</div></div>'
    return out + '</div>'

def v2_css():
    return """
.pill{flex:none;width:62px;border-radius:31px;overflow:hidden;background:rgba(22,22,26,.5);padding:4px 0}
.pill .it{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;height:76px;position:relative}
.pill .it+.it::before{content:"";position:absolute;top:0;left:12px;right:12px;height:.5px;background:rgba(255,255,255,.2)}
.pill svg{width:23px;height:23px;stroke:#fff}
.pill .it.k svg{stroke:var(--acc)}
.pill .cap{font-size:9.5px;letter-spacing:.6px;padding:0 2px}
"""
def v2_html(items):
    out = '<div class="pill glass act">'
    for k in items:
        out += f'<div class="it {"k" if k=="ywt" else ""}">{IC[k]}<div class="cap">{LABEL[k][0]}</div></div>'
    return out + '</div>'

def v3_css():
    return """
.info{flex-direction:column;align-items:stretch;gap:0}
.chiprow{display:flex;justify-content:flex-end;gap:6px;margin-top:16px}
.cp{height:46px;border-radius:23px;display:flex;align-items:center;gap:6px;padding:0 12px 0 11px;background:rgba(22,22,26,.5);
  font:700 10px/1 var(--f-ui);letter-spacing:.7px;text-transform:uppercase;color:#fff;white-space:nowrap}
.cp svg{width:18px;height:18px;flex:none}
.cp.k{background:color-mix(in srgb,var(--acc) 20%,rgba(22,22,26,.5));border-color:color-mix(in srgb,var(--acc) 55%,transparent);color:var(--acc)}
.cp.k svg{stroke:var(--acc)}
.metarow{display:flex;justify-content:space-between;align-items:flex-end}
"""
def v3_html(items):
    out = '<div class="chiprow">'
    for k in items:
        out += f'<div class="cp glass act {"k" if k=="ywt" else ""}">{IC[k]}<span>{LABEL[k][1]}</span></div>'
    return out + '</div>'

VARS = {
 'v1-stacked-circles': (v1_css, v1_html, 'rail',
   'Stacked glass circles', 'Two (or three) 50pt glass circles with tracked captions stack in a right rail, bottom-aligned with the info block; the headline column scales to fit beside them.'),
 'v2-vertical-pill': (v2_css, v2_html, 'rail',
   'Vertical pill', 'One slim glass pill holds You were there, Stadium and Trip divided by hairlines, bottom-right of the cover, the quietest and most compact treatment.'),
 'v3-icon-chips': (v3_css, v3_html, 'row',
   'Icon chips', 'Labeled icon chips run in a row along the right edge under the info lines, so the headline gets the full cover width for the longest names.'),
}

GAMES = {
 'v1-main': dict(
   title_suffix='Group stage', photo='soldier-soccer', champ=False, pos='50% 60%', zoom=3,
   badge='FIFA World Cup · Group stage', items=['ywt', 'stadium', 'trip'],
   lines=[('Bosnia and Herzegovina', 3, True, 'win'), ('Qatar', 1, False, 'lose')],
   venue='Lumen Field', place='Seattle', date='Wednesday, June 24, 2026',
   ko='12:00 PM', wx='cloud', temp='64°F',
   sheet='soccer'),
 'v2-big-game': dict(
   title_suffix='World Series', photo='wrigley-night', champ=True, pos='50% 55%',
   badge='World Series · Game 5', items=['ywt', 'stadium'],
   lines=[('Chicago', 3, True, 'win'), ('Cleveland', 2, False, 'lose')],
   venue='Wrigley Field', place='Chicago', date='Sunday, October 30, 2016',
   ko='7:20 PM', wx='moon', temp='63°F clear',
   sheet='ws'),
}

def sheet_html(kind):
    if kind == 'soccer':
        return """
<div class="sec">Final score</div>
<div class="tbl">
  <div class="tr h" style="grid-template-columns:1fr 44px 44px 48px"><span></span><span class="c">1H</span><span class="c">2H</span><span class="c">FT</span></div>
  <div class="tr" style="grid-template-columns:1fr 44px 44px 48px"><span class="tm"><span class="mono-badge" style="background:#1d3f9e">BIH</span>Bosnia and Herzegovina</span><span class="c">2</span><span class="c">1</span><span class="c f">3</span></div>
  <div class="tr" style="grid-template-columns:1fr 44px 44px 48px"><span class="tm"><span class="mono-badge" style="background:#7a1630">QAT</span>Qatar</span><span class="c">0</span><span class="c">1</span><span class="c f">1</span></div>
</div>
<div class="sec" style="margin-top:22px">I was there for</div>
<div class="chips"><span class="chip on">Opening goal</span><span class="chip">Four goals</span><span class="chip">Full time</span></div>"""
    return """
<div class="sec">Final score</div>
<div class="tbl">
  <div class="tr h" style="grid-template-columns:1fr 64px 64px"><span></span><span class="c">Final</span><span class="c">Series</span></div>
  <div class="tr" style="grid-template-columns:1fr 64px 64px"><span class="tm"><span class="mono-badge" style="background:#0e3386">CHC</span>Chicago</span><span class="c f">3</span><span class="c">2</span></div>
  <div class="tr" style="grid-template-columns:1fr 64px 64px"><span class="tm"><span class="mono-badge" style="background:#0c2340">CLE</span>Cleveland</span><span class="c f">2</span><span class="c">3</span></div>
</div>
<div class="sec" style="margin-top:22px">I was there for</div>
<div class="chips"><span class="chip on">Bryant HR, 4th</span><span class="chip">Chapman save</span><span class="chip">Final out</span></div>"""

FIT_JS = """
window.afterPaint = async () => {
  await document.fonts.ready;
  const hl = document.querySelector('.hl');
  const col = hl.getBoundingClientRect().width;
  const MAX = 62, MIN = 20;
  let s = MAX;
  hl.style.fontSize = '100px';
  hl.querySelectorAll('.nm').forEach(n => {
    const w = n.getBoundingClientRect().width / 100;     // em width of the name
    // column = name + score(1.22em) + dot(.2em) + 2 gaps(.28em)
    s = Math.min(s, col / (w + 1.70));
  });
  s = Math.max(MIN, Math.floor(s * 2) / 2);
  hl.style.fontSize = s + 'px';
};
"""

def build(var, vkey, g):
    css_fn, html_fn, mode, name, _ = VARS[var]
    lines = ''
    for (n, sc, mine, cls) in g['lines']:
        lines += f'<div class="ln {cls}"><span class="dot" style="{"" if mine else "visibility:hidden"}"></span><span class="nm">{n}</span><span class="sc">{sc}</span></div>'
    wx = f'<span class="ko">{IC[g["wx"]]}</span>'
    ko = f'<div class="ko"><b style="color:var(--text);font-weight:700">{g["ko"]}</b><span class="sep"></span>{IC[g["wx"]]}<span>{g["temp"]}</span></div>'
    actions = html_fn(g['items'])
    meta = f'<div class="meta"><b>{g["venue"]}</b>, {g["place"]}<br>{g["date"]}</div>'
    if mode == 'rail':
        info = f'<div class="info"><div class="txt"><div class="badge"><i></i>{g["badge"]}</div><div class="hl">{lines}</div>{meta}{ko}</div>{actions}</div>'
    else:
        info = f'<div class="info"><div class="badge" style="align-self:flex-start"><i></i>{g["badge"]}</div><div class="hl">{lines}</div><div class="metarow"><div>{meta}{ko}</div></div>{actions}</div>'
    nav = f"""<div class="nav"><div class="btn-circle glass">{IC['back']}</div><div class="r"><div class="btn-circle glass">{IC['share']}</div><div class="btn-circle glass more">{IC['more']}</div></div></div>"""
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>{name}</title>
<link rel="stylesheet" href="../../../kit/kit.css">
<style>{BASE_CSS}{css_fn()}
</style></head>
<body class="phone{' champ' if g['champ'] else ''}">
<div class="cover"><img class="ph graded" src="../../../photos/{g['photo']}.jpg" style="object-position:{g['pos']};transform:scale({g.get('zoom',1)});transform-origin:50% 100%"><div class="scrim"></div>{nav}{info}</div>
<div class="sheet">{sheet_html(g['sheet'])}</div>
<script src="../../../kit/kit.js"></script>
<script>{FIT_JS}</script>
</body></html>"""

for var, (cf, hf, mode, name, summary) in VARS.items():
    d = os.path.join(HERE, 'features', var)
    os.makedirs(d, exist_ok=True)
    json.dump({'title': name, 'summary': summary}, open(os.path.join(d, 'feature.json'), 'w'), indent=1)
    for vk, g in GAMES.items():
        open(os.path.join(d, vk + '.html'), 'w').write(build(var, vk, g))
print('ok')
