const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const R = __dirname, PNG = path.join(R, 'png');
const meta = f => JSON.parse(fs.readFileSync(path.join(R, 'features', f, 'feature.json')));
const shots = f => fs.readdirSync(path.join(PNG, f)).filter(x => /^v\d.*\.png$/.test(x)).sort();
const css = `html,body{width:auto;height:auto;background:#0b0b0d;color:#f5f1ea;font-family:Inter,sans-serif}body{margin:0}
h1{font:800 44px/1 'Barlow Condensed',Inter;margin:0 0 6px;text-transform:uppercase;letter-spacing:.5px}p{font:500 17px/1.4 Inter;color:rgba(245,241,234,.6);margin:0 0 26px}
.row{display:flex;gap:28px}figure{margin:0}img{display:block;border-radius:30px;box-shadow:0 0 0 1px rgba(255,255,255,.12)}
figcaption{margin-top:12px;font:500 15px/1.3 Inter;color:rgba(245,241,234,.8)}figcaption b{color:#ffb547;margin-right:6px}`;
function fig(f, s, i, w) { const h = Math.round(w * 852 / 393); return `<figure><img width="${w}" height="${h}" src="file://${PNG}/${f}/${s}"><figcaption><b>${String(i+1).padStart(2,'0')}</b>${s.replace(/^v\d+-/,'').replace('.png','').replace(/-/g,' ')}</figcaption></figure>`; }
(async () => {
  const b = await chromium.launch(); 
  async function shot(html, out, w, scale) {
    const c = await b.newContext({ viewport: { width: w, height: 900 }, deviceScaleFactor: scale }); const p = await c.newPage();
    fs.writeFileSync(path.join(PNG, '_t.html'), `<html><head><style>${css}</style></head><body style="padding:48px">${html}</body></html>`);
    await p.goto('file://' + path.join(PNG, '_t.html')); await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(300);
    await p.screenshot({ path: out, fullPage: true }); await c.close();
  }
  const A = ['approach-1','approach-2','approach-3','approach-4','approach-5'];
  for (const f of A) {
    const m = meta(f), s = shots(f);
    await shot(`<h1>${m.title}</h1><p>${m.summary}</p><div class="row">${s.map((x,i)=>fig(f,x,i,300)).join('')}</div>`, path.join(PNG, f + '.png'), 48*2 + s.length*300 + (s.length-1)*28, 2);
  }
  // overview
  const rows = A.map(f => { const m = meta(f), s = shots(f); return `<div style="display:flex;gap:18px;align-items:flex-start;margin-bottom:34px"><div style="width:230px;flex:none"><h1 style="font-size:36px">${m.title.replace(/^\d · /,m.title[0]+'<br>')}</h1><p style="font-size:15px">${m.summary}</p></div>${s.map((x,i)=>fig(f,x,i,150).replace(/<figcaption>.*<\/figcaption>/,'')).join('<span style="width:0"></span>')}</div>`; }).join('');
  const st = `<div style="display:flex;gap:18px;align-items:flex-start"><div style="width:230px;flex:none"><h1 style="font-size:36px">Shared<br>Scan settings</h1><p style="font-size:15px">${meta('settings-sheet').summary}</p></div>${fig('settings-sheet','v1-settings.png',0,150).replace(/<figcaption>.*<\/figcaption>/,'')}</div>`;
  await shot(`<h1 style="font-size:60px;margin-bottom:28px">Scan handling: five approaches</h1>${rows}${st}`, path.join(PNG, 'overview.png'), 48*2 + 230 + 6*150 + 6*18, 2.05);
  await b.close(); fs.unlinkSync(path.join(PNG, '_t.html'));
})();
