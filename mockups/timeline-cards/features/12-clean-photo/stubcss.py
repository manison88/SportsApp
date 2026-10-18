from common import *
STUB = """
.stub{height:100px;--m:radial-gradient(circle at 0 0,transparent 8px,#000 8.5px),radial-gradient(circle at 100% 0,transparent 8px,#000 8.5px),radial-gradient(circle at calc(100% - 96px) 0,transparent 7px,#000 7.5px),radial-gradient(circle at calc(100% - 96px) 100%,transparent 7px,#000 7.5px)}
.main{position:absolute;left:0;top:0;bottom:0;right:96px;padding:2px 12px 0 18px;display:flex;flex-direction:column;justify-content:center}
.r1{display:flex;justify-content:space-between;align-items:baseline}
.date{font:700 16px/1 var(--f-tight);letter-spacing:.2px;text-transform:uppercase;color:var(--text)}
.seat{font:600 10.5px/1 var(--f-ui);letter-spacing:1.1px;text-transform:uppercase;color:var(--text-2)}
.seat b{color:var(--text);font-weight:700}
.r2{margin-top:13px;padding-top:11px;border-top:1px solid var(--line);display:flex;align-items:center}
.f{display:flex;align-items:center;gap:5px;font:600 11.5px/1 var(--f-ui);font-variant-numeric:tabular-nums;color:var(--text-2);white-space:nowrap;padding:0 9px;border-left:1px solid var(--line-2);height:14px}
.f:first-child{padding-left:0;border-left:0}
.f.tk{color:var(--signal);margin-left:auto;padding-right:0}
.f svg{color:var(--text-3)}
.f.tk svg{color:var(--signal)}
.perf{position:absolute;right:96px;top:12px;bottom:12px;border-left:1.5px dashed rgba(255,255,255,.2)}
.tear{position:absolute;right:0;top:0;bottom:0;width:96px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;padding-top:2px}
.fin{font:700 9px/1 var(--f-ui);letter-spacing:1.6px;color:var(--text-3);margin-bottom:3px}
.fin b{color:var(--signal)} .fin b.l{color:var(--text-2)}
.row{display:flex;align-items:center;gap:6px;width:76px;justify-content:space-between}
.sc{font:800 21px/1 var(--f-cond);font-variant-numeric:tabular-nums;color:var(--text-2);text-align:right}
.row.me .tile{box-shadow:0 0 0 1.5px var(--stub),0 0 0 3px var(--signal)}
.row.me .sc{color:#fff}
.v2 .card{}
"""
CHIP = """
.chip{position:absolute;left:14px;top:14px;height:26px;padding:0 11px;border-radius:13px;display:flex;align-items:center;font:700 11px var(--f-ui);letter-spacing:1.4px;color:#fff;background:rgba(10,11,16,.52);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);box-shadow:inset 0 0 0 1px rgba(255,255,255,.14)}
.badge{left:auto;right:14px}
"""
def bug(away, as_, home, hs, me, res):
    r = lambda c, s: f'<div class="row{" me" if c==me else ""}">{tile(c)}<span class="sc tnum">{s}</span></div>'
    return f'<div class="tear"><div class="fin">FINAL · <b class="{"l" if res=="L" else ""}">{res}</b></div>{r(away,as_)}{r(home,hs)}</div>'

