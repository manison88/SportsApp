#!/usr/bin/env node
/* Passport-tile style icon concepts.  NODE_PATH=$(npm root -g) node AppStore/icon-concepts/stamp.cjs */
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..');
const A = '#ffb547', INK = '#050506', BLUE = '#2f6bff', YEL = '#ffc42e', RED = '#e8344e', SILV = '#c4ccd2';
const font = `font-family:'Barlow Condensed',sans-serif;font-weight:800;text-transform:uppercase`;
const bg = `<div style="position:absolute;inset:0;background:radial-gradient(circle at 50% 40%,#16161b,${INK} 80%)"></div>`;
// aerial rings as a subtle darker overlay on a tile
const aerial = (c = 'rgba(0,0,0,.16)') => `<svg viewBox="0 0 400 400" style="position:absolute;inset:0;width:100%;height:100%"><g fill="none" stroke="${c}"><ellipse cx="270" cy="300" rx="260" ry="210" stroke-width="30"/><ellipse cx="270" cy="300" rx="190" ry="150" stroke-width="22"/><ellipse cx="270" cy="300" rx="125" ry="95" stroke-width="16"/></g><ellipse cx="270" cy="300" rx="70" ry="50" fill="${c}"/></svg>`;
const tile = ({ x, y, w, color, ink = INK, abbr, venue, date, star, rot = 0, bgFx = true, z = 1 }) => {
  const u = w / 400;
  return `<div style="position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${w}px;border-radius:${112 * u}px;background:${color};transform:rotate(${rot}deg);z-index:${z};overflow:hidden;box-shadow:0 ${24 * u}px ${60 * u}px rgba(0,0,0,.55);color:${ink}">
   ${bgFx ? aerial() : ''}
   <div style="position:absolute;inset:${14 * u}px;border-radius:${100 * u}px;border:${6 * u}px solid rgba(0,0,0,.2)"></div>
   <div style="position:absolute;left:${42 * u}px;top:${36 * u}px;${font};font-size:${150 * u}px;line-height:1">${abbr}</div>
   ${venue ? `<div style="position:absolute;left:${42 * u}px;top:${200 * u}px;${font};font-size:${46 * u}px;letter-spacing:${1 * u}px">${venue}</div>` : ''}
   ${date ? `<div style="position:absolute;left:${42 * u}px;bottom:${44 * u}px;${font};font-size:${40 * u}px;letter-spacing:${5 * u}px;opacity:.85">${date}</div>` : ''}
   ${star ? `<div style="position:absolute;right:${28 * u}px;top:${28 * u}px;width:${86 * u}px;height:${86 * u}px;border-radius:50%;background:#0e1424;display:flex;align-items:center;justify-content:center;color:#f3d58f;font-size:${50 * u}px">★</div>` : ''}
  </div>`;
};

const ICONS = [
  ['01-full-tile', 'Full-bleed tile', `<div style="position:absolute;inset:0;background:${BLUE}"></div>` + `<div style="position:absolute;inset:0">${aerial('rgba(0,0,0,.18)').replace('viewBox="0 0 400 400"', 'viewBox="0 0 400 400" preserveAspectRatio="xMidYMid slice"')}</div>
   <div style="position:absolute;inset:46px;border-radius:150px;border:12px solid rgba(0,0,0,.22)"></div>
   <div style="position:absolute;left:120px;top:90px;${font};font-size:640px;line-height:1;color:${INK}">W</div>
   <div style="position:absolute;right:96px;top:96px;width:150px;height:150px;border-radius:50%;background:#0e1424;display:flex;align-items:center;justify-content:center;color:#f3d58f;font-size:90px">★</div>`],
  ['02-amber-tile', 'Amber tile, W + stadium', `<div style="position:absolute;inset:0;background:${A}"></div><div style="position:absolute;inset:0">${aerial('rgba(0,0,0,.14)').replace('viewBox="0 0 400 400"', 'viewBox="0 0 400 400" preserveAspectRatio="xMidYMid slice"')}</div>
   <div style="position:absolute;inset:46px;border-radius:150px;border:12px solid rgba(0,0,0,.2)"></div>
   <div style="position:absolute;left:120px;top:90px;${font};font-size:640px;line-height:1;color:${INK}">W</div>
   <div style="position:absolute;left:130px;bottom:120px;${font};font-size:84px;letter-spacing:14px;color:${INK};opacity:.85">ATTENDED</div>`],
  ['03-tilted', 'Single tile on dark, tilted', bg + tile({ x: 192, y: 192, w: 640, color: BLUE, abbr: 'CHC', venue: 'Wrigley Field', date: 'Jun 14, 2014', star: true, rot: -8 })],
  ['04-fan', 'Fan of three tiles', bg + tile({ x: 100, y: 250, w: 520, color: RED, abbr: 'STL', rot: -14, bgFx: true }) + tile({ x: 400, y: 250, w: 520, color: YEL, abbr: 'MIL', rot: 12, z: 2 }) + tile({ x: 252, y: 160, w: 540, color: BLUE, abbr: 'CHC', star: true, z: 3 })],
  ['05-grid', '2x2 passport grid', bg + [[BLUE, 'CHC', 1, 90, 90], [YEL, 'MIL', 0, 530, 90], [RED, 'STL', 0, 90, 530], [SILV, 'CWS', 0, 530, 530]].map(([c, a, s, x, y]) => tile({ x, y, w: 404, color: c, abbr: a, star: !!s })).join('')],
  ['06-wide', 'Tile + stadium aerial strip', bg + tile({ x: 92, y: 92, w: 840, color: BLUE, abbr: 'CHC', venue: 'Wrigley Field', date: 'Jun 14, 2014', star: true })],
];

(async () => {
  const b = await chromium.launch();
  const wrap = inner => `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="file://${ROOT}/mockups/kit/kit.css"><style>html,body{margin:0;background:${INK};width:auto!important;height:auto!important;overflow:visible!important;display:block!important}.i{position:relative;width:1024px;height:1024px;overflow:hidden;background:${INK}}</style></head><body>${inner}</body></html>`;
  const shot = async (html, w, h, out) => {
    const ctx = await b.newContext({ viewport: { width: w, height: h } }); const p = await ctx.newPage();
    const tmp = path.join(__dirname, '_s.html'); fs.writeFileSync(tmp, html);
    await p.goto('file://' + tmp); await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(300);
    await p.screenshot({ path: out }); await ctx.close();
  };
  for (const [id, , body] of ICONS) await shot(wrap(`<div class="i">${body}</div>`), 1024, 1024, path.join(__dirname, `stamp-${id}.png`));
  const cell = (id, name, body) => `<div style="width:460px"><div style="width:460px;height:460px;border-radius:104px;overflow:hidden;position:relative"><div class="i" style="transform:scale(.449);transform-origin:0 0">${body}</div></div><div style="font:600 24px Inter,sans-serif;color:#aaa;margin-top:14px;text-align:center">${id.slice(0, 2)} · ${name}</div></div>`;
  await shot(wrap(`<div style="display:grid;grid-template-columns:repeat(3,460px);gap:50px 40px;padding:50px;background:#18181c">${ICONS.map(i => cell(...i)).join('')}</div>`), 1620, 1180, path.join(__dirname, 'stamp-contact-sheet.png'));
  await b.close(); fs.rmSync(path.join(__dirname, '_s.html'), { force: true });
})();
