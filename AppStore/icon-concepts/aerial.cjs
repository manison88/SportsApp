#!/usr/bin/env node
/* Aerial-view stadium icon concepts: 1024x1024 opaque PNGs + contact sheet.
 *   NODE_PATH=$(npm root -g) node AppStore/icon-concepts/aerial.cjs */
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..');
const A = '#ffb547', INK = '#050506', CREAM = '#f5f1ea', GRASS = '#1f7a46', GRASS2 = '#27904f';
const font = `font-family:'Barlow Condensed',sans-serif;font-weight:800`;
const svg = inner => `<svg viewBox="0 0 1024 1024" style="position:absolute;inset:0">${inner}</svg>`;
const bg = (c = '#0e0e11') => `<div style="position:absolute;inset:0;background:radial-gradient(circle at 50% 45%,${c},${INK} 80%)"></div>`;

// bowl as stacked rounded-rect rings (rx = corner radius), segmented by gaps via dasharray
const rr = (cx, cy, w, h, r, extra) => `<rect x="${cx - w / 2}" y="${cy - h / 2}" width="${w}" height="${h}" rx="${r}" ${extra}/>`;
const bowl = (w, h, r, lit) => `
 ${rr(512, 512, w, h, r, `fill="#1b1b21"`)}
 ${[0, 1, 2].map(i => rr(512, 512, w - 40 - i * 70, h - 40 - i * 70, r - 20 - i * 30, `fill="none" stroke="${i === 0 ? '#3a3a44' : i === 1 ? '#2c2c34' : '#24242b'}" stroke-width="46" stroke-dasharray="${i === 1 ? '120 8' : '150 8'}"`)).join('')}
 ${lit || ''}`;
const stripes = (x, y, w, h, n) => Array.from({ length: n }, (_, i) => `<rect x="${x}" y="${y + i * h / n}" width="${w}" height="${h / n}" fill="${i % 2 ? GRASS2 : GRASS}"/>`).join('');
const lights = r => [[-1, -1], [1, -1], [-1, 1], [1, 1]].map(([sx, sy]) => `<circle cx="${512 + sx * r[0]}" cy="${512 + sy * r[1]}" r="26" fill="${A}"/><circle cx="${512 + sx * r[0]}" cy="${512 + sy * r[1]}" r="60" fill="${A}" fill-opacity=".18"/>`).join('');

const ICONS = [
  ['01-pitch', 'Soccer/football pitch', bg() + svg(`
   ${bowl(860, 700, 190)}
   <clipPath id="p"><rect x="262" y="332" width="500" height="360" rx="14"/></clipPath>
   <g clip-path="url(#p)">${stripes(262, 332, 500, 360, 8)}</g>
   <g fill="none" stroke="#fff" stroke-opacity=".8" stroke-width="5"><rect x="262" y="332" width="500" height="360" rx="14"/><line x1="512" y1="332" x2="512" y2="692"/><circle cx="512" cy="512" r="58"/></g>
   <circle cx="512" cy="512" r="20" fill="${A}"/>${lights([380, 300])}`)],
  ['02-diamond', 'Baseball park', bg() + svg(`
   <path d="M512 140 C250 140 120 330 120 560 C120 760 300 880 512 880 C724 880 904 760 904 560 C904 330 774 140 512 140Z" fill="#1b1b21"/>
   <path d="M512 190 C290 190 175 350 175 560 C175 730 330 830 512 830 C694 830 849 730 849 560 C849 350 734 190 512 190Z" fill="none" stroke="#33333c" stroke-width="40" stroke-dasharray="140 8"/>
   <path d="M512 250 C340 250 240 380 240 560 C240 690 370 780 512 780 C654 780 784 690 784 560 C784 380 684 250 512 250Z" fill="${GRASS}"/>
   <path d="M512 742 L350 570 L512 408 L674 570Z" fill="#b9814f"/><path d="M512 700 L392 570 L512 450 L632 570Z" fill="${GRASS2}"/>
   <g fill="#fff"><rect x="496" y="727" width="32" height="32" transform="rotate(45 512 743)"/><rect x="335" y="555" width="30" height="30" transform="rotate(45 350 570)"/><rect x="659" y="555" width="30" height="30" transform="rotate(45 674 570)"/><rect x="497" y="393" width="30" height="30" transform="rotate(45 512 408)"/></g>
   <circle cx="512" cy="570" r="22" fill="${A}"/>`)],
  ['03-arena', 'Arena / court', bg() + svg(`
   <ellipse cx="512" cy="512" rx="420" ry="330" fill="#1b1b21"/>
   ${[0, 1].map(i => `<ellipse cx="512" cy="512" rx="${375 - i * 60}" ry="${285 - i * 50}" fill="none" stroke="${i ? '#2c2c34' : '#3a3a44'}" stroke-width="42" stroke-dasharray="${i ? '110 8' : '140 8'}"/>`).join('')}
   <rect x="290" y="372" width="444" height="280" rx="14" fill="#c98a4a"/>
   <g fill="none" stroke="#fff" stroke-opacity=".85" stroke-width="5"><rect x="290" y="372" width="444" height="280" rx="14"/><line x1="512" y1="372" x2="512" y2="652"/><circle cx="512" cy="512" r="46"/><path d="M290 452 H350 A60 60 0 0 1 350 572 H290"/><path d="M734 452 H674 A60 60 0 0 0 674 572 H734"/></g>
   <circle cx="512" cy="512" r="16" fill="${A}"/>`)],
  ['04-your-seat', 'Bowl with your section lit', bg('#16161b') + svg(`
   <g transform="translate(512 512)">${(() => {
     let s = ''; const ring = (r0, r1, n, litIdx) => { for (let i = 0; i < n; i++) { const a0 = (i / n) * 2 * Math.PI + .03, a1 = ((i + 1) / n) * 2 * Math.PI - .03; const p = (r, a) => `${r * Math.cos(a)} ${r * Math.sin(a)}`; s += `<path d="M${p(r0, a0)} A${r0} ${r0} 0 0 1 ${p(r0, a1)} L${p(r1, a1)} A${r1} ${r1} 0 0 0 ${p(r1, a0)}Z" fill="${litIdx.includes(i) ? A : '#2e2e37'}" ${litIdx.includes(i) ? `style="filter:drop-shadow(0 0 22px ${A})"` : ''}/>`; } };
     ring(300, 400, 20, [14]); ring(190, 280, 16, []); s += `<circle r="150" fill="${GRASS}"/><circle r="150" fill="none" stroke="#fff" stroke-opacity=".5" stroke-width="5"/>`; return s; })()}</g>`)],
  ['05-w-field', 'W as the field', bg() + svg(`
   ${bowl(880, 760, 220)}
   <clipPath id="q"><rect x="250" y="300" width="524" height="424" rx="20"/></clipPath><g clip-path="url(#q)">${stripes(250, 300, 524, 424, 10)}</g>`) +
   `<div style="position:absolute;left:0;right:0;top:238px;text-align:center;${font};font-size:560px;line-height:1;color:${CREAM};text-shadow:0 10px 40px rgba(0,0,0,.45)">W</div>
    <div style="position:absolute;left:645px;top:285px;width:70px;height:70px;border-radius:50%;background:${A};box-shadow:0 0 70px 24px rgba(255,181,71,.6)"></div>`],
  ['06-tilt', 'Tilted aerial with light beams', `<div style="position:absolute;inset:0;background:linear-gradient(180deg,#0a1226,#050506 80%)"></div>` + svg(`
   <g transform="translate(512 590) scale(1 .62)"><ellipse rx="430" ry="430" fill="#1b1b21"/>
   ${[0, 1, 2].map(i => `<circle r="${380 - i * 70}" fill="none" stroke="${['#3a3a44', '#30303a', '#26262d'][i]}" stroke-width="48" stroke-dasharray="${150 - i * 20} 8"/>`).join('')}
   <circle r="190" fill="${GRASS}"/><circle r="190" fill="none" stroke="#fff" stroke-opacity=".6" stroke-width="6"/><line x1="-190" x2="190" stroke="#fff" stroke-opacity=".6" stroke-width="6"/></g>
   <g>${[200, 400, 620, 824].map((x, i) => `<path d="M${x} 90 L${x - 60 + i * 40} 420 L${x + 90 - i * 30} 420Z" fill="${A}" fill-opacity=".12"/><circle cx="${x}" cy="90" r="30" fill="${A}"/>`).join('')}</g>
   <circle cx="512" cy="590" r="22" fill="${A}"/>`)],
  ['07-badge', 'Aerial in a circle badge', bg() + svg(`
   <clipPath id="c"><circle cx="512" cy="512" r="360"/></clipPath>
   <g clip-path="url(#c)"><rect width="1024" height="1024" fill="#1b1b21"/>
   ${[0, 1, 2].map(i => rr(512, 512, 760 - i * 150, 640 - i * 130, 180 - i * 35, `fill="none" stroke="${['#3a3a44', '#30303a', '#26262d'][i]}" stroke-width="56" stroke-dasharray="${150 - i * 20} 8"`)).join('')}
   <rect x="352" y="402" width="320" height="220" rx="10" fill="${GRASS}"/><g fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="4"><rect x="352" y="402" width="320" height="220" rx="10"/><line x1="512" y1="402" x2="512" y2="622"/><circle cx="512" cy="512" r="36"/></g></g>
   <circle cx="512" cy="512" r="360" fill="none" stroke="${A}" stroke-width="30"/><circle cx="512" cy="512" r="390" fill="none" stroke="${A}" stroke-opacity=".35" stroke-width="8"/>
   <circle cx="512" cy="512" r="16" fill="${A}"/>`)],
  ['08-line', 'Amber line-art aerial + pin', bg('#14110a') + svg(`
   <g fill="none" stroke="${A}" stroke-linecap="round">
   <ellipse cx="512" cy="540" rx="400" ry="320" stroke-width="26"/><ellipse cx="512" cy="540" rx="320" ry="250" stroke-width="16" stroke-opacity=".7"/><ellipse cx="512" cy="540" rx="240" ry="180" stroke-width="12" stroke-opacity=".45"/>
   <rect x="400" y="480" width="224" height="120" rx="8" stroke-width="8" stroke-opacity=".8"/><line x1="512" y1="480" x2="512" y2="600" stroke-width="6" stroke-opacity=".8"/></g>
   <path d="M512 170C440 170 385 225 385 295c0 90 127 215 127 215s127-125 127-215c0-70-55-125-127-125z" fill="${A}"/><circle cx="512" cy="295" r="42" fill="${INK}"/>`)],
];

(async () => {
  const b = await chromium.launch();
  const wrap = inner => `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="file://${ROOT}/mockups/kit/kit.css"><style>html,body{margin:0;background:${INK};width:auto!important;height:auto!important;overflow:visible!important;display:block!important}.i{position:relative;width:1024px;height:1024px;overflow:hidden;background:${INK}}</style></head><body>${inner}</body></html>`;
  const shot = async (html, w, h, out) => {
    const ctx = await b.newContext({ viewport: { width: w, height: h } }); const p = await ctx.newPage();
    const tmp = path.join(__dirname, '_a.html'); fs.writeFileSync(tmp, html);
    await p.goto('file://' + tmp); await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(300);
    await p.screenshot({ path: out }); await ctx.close();
  };
  for (const [id, , body] of ICONS) await shot(wrap(`<div class="i">${body}</div>`), 1024, 1024, path.join(__dirname, `aerial-${id}.png`));
  const cell = (id, name, body) => `<div style="width:460px"><div style="width:460px;height:460px;border-radius:104px;overflow:hidden;position:relative"><div class="i" style="transform:scale(.449);transform-origin:0 0">${body}</div></div><div style="font:600 24px Inter,sans-serif;color:#aaa;margin-top:14px;text-align:center">${id.slice(0, 2)} · ${name}</div></div>`;
  await shot(wrap(`<div style="display:grid;grid-template-columns:repeat(4,460px);gap:50px 40px;padding:50px;background:#18181c">${ICONS.map(i => cell(...i)).join('')}</div>`), 2060, 1180, path.join(__dirname, 'aerial-contact-sheet.png'));
  await b.close(); fs.rmSync(path.join(__dirname, '_a.html'), { force: true });
})();
