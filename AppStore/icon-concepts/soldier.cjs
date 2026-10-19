#!/usr/bin/env node
/* Icon concepts using a real aerial of Soldier Field (Esri World Imagery) + ticket / W treatments.
 *   NODE_PATH=$(npm root -g) node AppStore/icon-concepts/soldier.cjs */
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..');
const IMG = 'file://' + path.join(__dirname, 'soldier-field-aerial.jpg');
const A = '#ffb547', INK = '#050506', CREAM = '#f5f1ea';
const font = `font-family:'Barlow Condensed',sans-serif;font-weight:800;text-transform:uppercase`;
const photo = (extra = '', pos = '50% 50%', size = '100%') => `background:url(${IMG}) ${pos}/${size} no-repeat;${extra}`;
const shade = (a = .35) => `linear-gradient(rgba(5,5,6,${a}),rgba(5,5,6,${a}))`;
const ticketMask = (r, w, h) => `-webkit-mask:radial-gradient(circle ${r}px at 0 50%,#0000 98%,#000) left/51% 100% no-repeat,radial-gradient(circle ${r}px at 100% 50%,#0000 98%,#000) right/51% 100% no-repeat`;

const ICONS = [
  ['01-full-w', 'Aerial + cream W', `<div style="position:absolute;inset:0;${photo('', '50% 50%', '100%')}"></div><div style="position:absolute;inset:0;background:linear-gradient(180deg,rgba(5,5,6,.5),rgba(5,5,6,.2) 40%,rgba(5,5,6,.7))"></div>
   <div style="position:absolute;left:0;right:0;top:130px;text-align:center;${font};font-size:820px;line-height:1;color:${CREAM}">W</div>
   <div style="position:absolute;left:690px;top:150px;width:130px;height:130px;border-radius:50%;background:${A};box-shadow:0 0 90px 30px rgba(255,181,71,.6)"></div>`],
  ['02-w-knockout', 'Aerial seen through the W', `<div style="position:absolute;inset:0;background:radial-gradient(circle at 50% 45%,#16161b,${INK} 80%)"></div>
   <div style="position:absolute;left:0;right:0;top:90px;text-align:center;${font};font-size:900px;line-height:1;color:transparent;background:url(${IMG}) 50% 40%/ 75% no-repeat;-webkit-background-clip:text;background-clip:text;">W</div>
   <div style="position:absolute;left:692px;top:130px;width:120px;height:120px;border-radius:50%;background:${A};box-shadow:0 0 80px 26px rgba(255,181,71,.55)"></div>`],
  ['03-ticket-stub', 'Ticket with aerial', `<div style="position:absolute;inset:0;background:linear-gradient(180deg,#0e0e11,${INK})"></div>
   <div style="position:absolute;left:90px;top:230px;width:844px;height:564px;border-radius:56px;${photo('', '50% 55%', '125%')};${ticketMask(56)}"></div>
   <div style="position:absolute;left:90px;top:230px;width:844px;height:564px;border-radius:56px;background:linear-gradient(90deg,rgba(5,5,6,.15) 0,rgba(5,5,6,.15) 68%,${A} 68%);${ticketMask(56)}"></div>
   <div style="position:absolute;left:690px;top:270px;height:484px;border-left:8px dashed rgba(5,5,6,.5)"></div>
   <div style="position:absolute;left:700px;width:234px;top:230px;height:564px;display:flex;flex-direction:column;align-items:center;justify-content:center;${font};color:${INK};line-height:1.02"><span style="font-size:58px;letter-spacing:4px">Admit</span><span style="font-size:98px">One</span></div>
   <div style="position:absolute;left:120px;width:560px;top:230px;height:564px;display:flex;align-items:center;justify-content:center;${font};font-size:430px;color:${CREAM};text-shadow:0 6px 30px rgba(0,0,0,.6)">W</div>`],
  ['04-ticket-full', 'Full-bleed aerial, amber ticket overlay', `<div style="position:absolute;inset:0;${photo(`background-image:${shade(.5)},url(${IMG})`, '50% 50%', '150%')}"></div>
   <div style="position:absolute;left:150px;top:340px;width:724px;height:344px;border-radius:44px;background:${A};${ticketMask(44)}"></div>
   <div style="position:absolute;left:150px;width:470px;top:340px;height:344px;display:flex;align-items:center;justify-content:center;${font};font-size:330px;color:${INK}">W</div>
   <div style="position:absolute;left:636px;top:372px;height:280px;border-left:7px dashed rgba(5,5,6,.45)"></div>
   <div style="position:absolute;left:650px;width:224px;top:340px;height:344px;display:flex;flex-direction:column;align-items:center;justify-content:center;${font};color:${INK};line-height:1.02"><span style="font-size:48px;letter-spacing:3px">Admit</span><span style="font-size:74px">One</span></div>`],
  ['05-circle-stamp', 'Aerial circle stamp', `<div style="position:absolute;inset:0;background:radial-gradient(circle at 50% 45%,#16161b,${INK} 80%)"></div>
   <div style="position:absolute;left:112px;top:112px;width:800px;height:800px;border-radius:50%;${photo('', '45% 50%', '135%')};box-shadow:0 0 0 26px ${A},0 0 0 44px ${INK},0 0 0 52px rgba(255,181,71,.45),0 30px 90px rgba(0,0,0,.6)"></div>
   <div style="position:absolute;left:112px;top:112px;width:800px;height:800px;border-radius:50%;background:linear-gradient(rgba(5,5,6,.1),rgba(5,5,6,.45))"></div>
   <div style="position:absolute;left:0;right:0;top:250px;text-align:center;${font};font-size:560px;line-height:1;color:${CREAM}">W</div>`],
  ['06-tile', 'Passport tile over aerial', `<div style="position:absolute;inset:0;${photo(`background-image:${shade(.72)},url(${IMG})`, '50% 50%', '170%')}"></div>
   <div style="position:absolute;left:150px;top:150px;width:724px;height:724px;border-radius:200px;background:#ff6a1f;transform:rotate(-7deg);overflow:hidden;box-shadow:0 40px 100px rgba(0,0,0,.6)">
     <div style="position:absolute;inset:0;${photo('opacity:.3;mix-blend-mode:multiply', '45% 50%', '150%')}"></div>
     <div style="position:absolute;inset:24px;border-radius:176px;border:10px solid rgba(0,0,0,.22)"></div>
     <div style="position:absolute;left:76px;top:62px;${font};font-size:270px;line-height:1;color:${INK}">CHI</div>
     <div style="position:absolute;left:78px;top:372px;${font};font-size:84px;letter-spacing:2px;color:${INK}">Soldier Field</div>
     <div style="position:absolute;left:78px;bottom:78px;${font};font-size:72px;letter-spacing:9px;color:${INK};opacity:.85">Sep 8, 2024</div>
     <div style="position:absolute;right:50px;top:50px;width:150px;height:150px;border-radius:50%;background:#0e1424;display:flex;align-items:center;justify-content:center;color:#f3d58f;font-size:88px">★</div></div>`],
  ['07-split', 'Ticket: aerial top, amber W bottom', `<div style="position:absolute;inset:0;background:linear-gradient(180deg,#0e0e11,${INK})"></div>
   <div style="position:absolute;left:170px;top:90px;width:684px;height:844px;border-radius:56px;overflow:hidden;box-shadow:0 40px 100px rgba(0,0,0,.6);-webkit-mask:radial-gradient(circle 52px at 0 62%,#0000 98%,#000) left/51% 100% no-repeat,radial-gradient(circle 52px at 100% 62%,#0000 98%,#000) right/51% 100% no-repeat">
     <div style="position:absolute;left:0;right:0;top:0;height:62%;${photo('', '45% 45%', '150%')}"></div>
     <div style="position:absolute;left:0;right:0;top:62%;bottom:0;background:${A}"></div>
     <div style="position:absolute;left:44px;right:44px;top:62%;border-top:7px dashed rgba(5,5,6,.45)"></div>
     <div style="position:absolute;left:0;right:0;top:62%;bottom:0;display:flex;align-items:center;justify-content:center;${font};font-size:330px;line-height:1;color:${INK}">W</div></div>`],
  ['08-pin', 'Aerial with W pin', `<div style="position:absolute;inset:0;${photo(`background-image:${shade(.45)},url(${IMG})`, '50% 50%', '140%')}"></div>
   <svg viewBox="0 0 1024 1024" style="position:absolute;inset:0;filter:drop-shadow(0 20px 40px rgba(0,0,0,.6))"><path d="M512 120C392 120 300 212 300 332c0 156 212 380 212 380s212-224 212-380c0-120-92-212-212-212z" fill="${A}"/><text x="512" y="420" text-anchor="middle" font-family="Barlow Condensed" font-weight="800" font-size="290" fill="${INK}">W</text></svg>`],
];

(async () => {
  const b = await chromium.launch();
  const wrap = inner => `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="file://${ROOT}/mockups/kit/kit.css"><style>html,body{margin:0;background:${INK};width:auto!important;height:auto!important;overflow:visible!important;display:block!important}.i{position:relative;width:1024px;height:1024px;overflow:hidden;background:${INK}}</style></head><body>${inner}</body></html>`;
  const shot = async (html, w, h, out) => {
    const ctx = await b.newContext({ viewport: { width: w, height: h } }); const p = await ctx.newPage();
    const tmp = path.join(__dirname, '_r.html'); fs.writeFileSync(tmp, html);
    await p.goto('file://' + tmp); await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(500);
    await p.screenshot({ path: out }); await ctx.close();
  };
  for (const [id, , body] of ICONS) await shot(wrap(`<div class="i">${body}</div>`), 1024, 1024, path.join(__dirname, `soldier-${id}.png`));
  const cell = (id, name, body) => `<div style="width:460px"><div style="width:460px;height:460px;border-radius:104px;overflow:hidden;position:relative"><div class="i" style="transform:scale(.449);transform-origin:0 0">${body}</div></div><div style="font:600 24px Inter,sans-serif;color:#aaa;margin-top:14px;text-align:center">${id.slice(0, 2)} · ${name}</div></div>`;
  await shot(wrap(`<div style="display:grid;grid-template-columns:repeat(4,460px);gap:50px 40px;padding:50px;background:#18181c">${ICONS.map(i => cell(...i)).join('')}</div>`), 2060, 1180, path.join(__dirname, 'soldier-contact-sheet.png'));
  await b.close(); fs.rmSync(path.join(__dirname, '_r.html'), { force: true });
})();
