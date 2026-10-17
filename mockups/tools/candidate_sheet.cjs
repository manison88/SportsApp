// Contact sheet of photo candidates whose id starts with any given prefix.
//   NODE_PATH=$(npm root -g) node mockups/tools/candidate_sheet.cjs out.png lambeau wrigley
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const dir = path.join(__dirname, '..', 'photo-candidates');
const [out, ...prefixes] = process.argv.slice(2);
(async () => {
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.jpg') && prefixes.some(p => f.replace(/-\d+\.jpg$/, '') === p)).sort();
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1500, height: 400 } });
  const html = path.join(dir, '_sheet.html');
  fs.writeFileSync(html, `<body style="margin:0;background:#111;display:flex;flex-wrap:wrap;gap:6px;padding:6px;font:600 15px sans-serif;color:#fff">${files.map(f =>
    `<div style="width:240px"><img src="file://${dir}/${f}" style="width:240px;height:160px;object-fit:cover;display:block"><div>${f.replace('.jpg', '')}</div></div>`).join('')}</body>`);
  await p.goto('file://' + html);
  await p.waitForTimeout(800);
  await p.screenshot({ path: out, fullPage: true });
  await b.close();
})();
