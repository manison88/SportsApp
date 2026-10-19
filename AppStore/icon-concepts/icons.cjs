#!/usr/bin/env node
/* App icon concepts: 1024x1024 opaque PNGs + a contact sheet with the iOS rounded mask.
 *   NODE_PATH=$(npm root -g) node AppStore/icon-concepts/icons.cjs */
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..');
const A = '#ffb547', INK = '#050506', CREAM = '#f5f1ea';
const font = `font-family:'Barlow Condensed','Anton',sans-serif;font-weight:800`;
const glow = (x, y, r, a) => `radial-gradient(circle at ${x}% ${y}%,rgba(255,181,71,${a}),transparent ${r}%)`;

const ICONS = [
  ['01-w-flash', 'W + flash (refined current)', `
   <div style="position:absolute;inset:0;background:${glow(70,24,45,.35)},linear-gradient(160deg,#101a33,#050506 70%)"></div>
   <div style="position:absolute;left:0;right:0;top:150px;text-align:center;${font};font-size:860px;line-height:1;color:${CREAM}">W</div>
   <div style="position:absolute;left:640px;top:150px;width:150px;height:150px;border-radius:50%;background:${A};box-shadow:0 0 120px 40px rgba(255,181,71,.55)"></div>`],
  ['02-amber-w', 'Amber W', `
   <div style="position:absolute;inset:0;background:${glow(50,100,70,.22)},linear-gradient(180deg,#0e0e11,#050506)"></div>
   <div style="position:absolute;left:0;right:0;top:120px;text-align:center;${font};font-size:900px;line-height:1;color:${A}">W</div>`],
  ['03-ticket', 'Ticket stub', `
   <div style="position:absolute;inset:0;background:linear-gradient(180deg,#0e0e11,#050506)"></div>
   <div style="position:absolute;left:130px;top:270px;width:764px;height:484px;border-radius:50px;background:${A};
     -webkit-mask:radial-gradient(circle 50px at 0 50%,#0000 98%,#000) left/51% 100% no-repeat,radial-gradient(circle 50px at 100% 50%,#0000 98%,#000) right/51% 100% no-repeat;"></div>
   <div style="position:absolute;left:620px;top:310px;height:404px;border-left:8px dashed rgba(5,5,6,.45)"></div>
   <div style="position:absolute;left:130px;width:490px;top:270px;height:484px;display:flex;align-items:center;justify-content:center;${font};font-size:420px;color:${INK}">W</div>
   <div style="position:absolute;left:640px;width:230px;top:270px;height:484px;display:flex;align-items:center;justify-content:center;flex-direction:column;${font};color:${INK};font-size:60px;letter-spacing:3px;line-height:1.1"><span>ADMIT</span><span style="font-size:112px">ONE</span></div>`],
  ['04-bowl', 'Stadium bowl from above', `
   <div style="position:absolute;inset:0;background:radial-gradient(circle at 50% 50%,#1a1a20,#050506 75%)"></div>
   <svg viewBox="0 0 1024 1024" style="position:absolute;inset:0"><g fill="none" stroke="${CREAM}" stroke-opacity=".9">
   <ellipse cx="512" cy="512" rx="400" ry="330" stroke-width="30"/><ellipse cx="512" cy="512" rx="320" ry="256" stroke-width="22" stroke-opacity=".6"/><ellipse cx="512" cy="512" rx="245" ry="186" stroke-width="16" stroke-opacity=".35"/></g>
   <ellipse cx="512" cy="512" rx="160" ry="115" fill="#1f7a46"/><circle cx="512" cy="512" r="46" fill="${A}"/></svg>`],
  ['05-lens', 'Witness eye (lens + light)', `
   <div style="position:absolute;inset:0;background:${glow(50,50,60,.18)},${INK}"></div>
   <svg viewBox="0 0 1024 1024" style="position:absolute;inset:0"><circle cx="512" cy="512" r="330" fill="none" stroke="${CREAM}" stroke-width="44"/>
   <circle cx="512" cy="512" r="200" fill="none" stroke="${CREAM}" stroke-opacity=".4" stroke-width="22"/><circle cx="512" cy="512" r="110" fill="${A}"/><circle cx="470" cy="470" r="30" fill="#fff" fill-opacity=".7"/></svg>`],
  ['06-lights', 'Stadium floodlights', `
   <div style="position:absolute;inset:0;background:linear-gradient(180deg,#0a1226,#050506 85%)"></div>
   <svg viewBox="0 0 1024 1024" style="position:absolute;inset:0">${[0,1,2].map(r=>[0,1,2,3].map(c=>`<circle cx="${262+c*167}" cy="${240+r*140}" r="48" fill="${A}" ${c==1&&r==1?'':'fill-opacity=".92"'}/>`).join('')).join('')}
   <path d="M130 760 Q512 640 894 760" fill="none" stroke="${CREAM}" stroke-width="30" stroke-linecap="round"/><path d="M200 850 Q512 750 824 850" fill="none" stroke="${CREAM}" stroke-opacity=".5" stroke-width="22" stroke-linecap="round"/></svg>`],
  ['07-stamp', 'Passport stamp', `
   <div style="position:absolute;inset:0;background:linear-gradient(180deg,#0e0e11,#050506)"></div>
   <svg viewBox="0 0 1024 1024" style="position:absolute;inset:0;transform:rotate(-12deg);transform-origin:50% 50%"><circle cx="512" cy="512" r="360" fill="none" stroke="${A}" stroke-width="34"/><circle cx="512" cy="512" r="300" fill="none" stroke="${A}" stroke-width="10" stroke-dasharray="6 16" stroke-linecap="round"/></svg>
   <div style="position:absolute;left:0;right:0;top:190px;text-align:center;${font};font-size:520px;line-height:1;color:${A};transform:rotate(-12deg)">W</div>
   <div style="position:absolute;left:0;right:0;top:690px;text-align:center;${font};font-size:56px;letter-spacing:12px;color:${A};transform:rotate(-12deg)">ATTENDED</div>`],
  ['08-pin', 'Seat + map pin', `
   <div style="position:absolute;inset:0;background:${glow(50,40,55,.25)},linear-gradient(180deg,#0e0e11,#050506)"></div>
   <svg viewBox="0 0 1024 1024" style="position:absolute;inset:0"><path d="M512 140C380 140 280 240 280 372c0 170 232 410 232 410s232-240 232-410c0-132-100-232-232-232z" fill="${A}"/>
   <text x="512" y="470" text-anchor="middle" font-family="Barlow Condensed" font-weight="800" font-size="300" fill="${INK}">W</text>
   <ellipse cx="512" cy="840" rx="210" ry="40" fill="none" stroke="${CREAM}" stroke-opacity=".5" stroke-width="14"/></svg>`],
];

(async () => {
  const b = await chromium.launch();
  const wrap = (inner, extra = '') => `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="file://${ROOT}/mockups/kit/kit.css"><style>html,body{margin:0;background:${INK};width:auto!important;height:auto!important;overflow:visible!important;display:block!important}.i{position:relative;width:1024px;height:1024px;overflow:hidden;background:${INK};${extra}}</style></head><body>${inner}</body></html>`;
  const shot = async (html, w, h, out) => {
    const ctx = await b.newContext({ viewport: { width: w, height: h } });
    const p = await ctx.newPage();
    const tmp = path.join(__dirname, '_p.html'); fs.writeFileSync(tmp, html);
    await p.goto('file://' + tmp); await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(300);
    await p.screenshot({ path: out }); await ctx.close();
  };
  for (const [id, , body] of ICONS) await shot(wrap(`<div class="i">${body}</div>`), 1024, 1024, path.join(__dirname, `icon-${id}.png`));
  const cell = (id, name, body) => `<div style="width:460px"><div style="width:460px;height:460px;border-radius:104px;overflow:hidden;position:relative"><div class="i" style="transform:scale(.449);transform-origin:0 0">${body}</div></div><div style="font:600 24px Inter,sans-serif;color:#aaa;margin-top:14px;text-align:center">${id.slice(0,2)} · ${name}</div></div>`;
  const sheet = `<div style="display:grid;grid-template-columns:repeat(4,460px);gap:50px 40px;padding:50px;background:#18181c">${ICONS.map(i => cell(...i)).join('')}</div>`;
  await shot(wrap(sheet), 2060, 1180, path.join(__dirname, 'contact-sheet.png'));
  await b.close(); fs.rmSync(path.join(__dirname, '_p.html'), { force: true });
})();
