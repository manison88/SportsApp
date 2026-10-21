// Witness analytics: takes event batches from the app, keeps them in D1, and shows a dashboard.
//   POST /e        the app's batches (needs the x-witness-key header)
//   GET  /packs/*  the downloadable data packs (teams, venues, schedules) from R2; public, immutable files named by hash
//   PUT  /packs-admin/<key>, GET /packs-admin/list, DELETE /packs-admin/<key>  upload from CI (same basic-auth password)
//   GET  /         the dashboard (HTTP basic auth, password in the DASH_PASSWORD secret)
// No IP address is kept, only Cloudflare's country code. Events carry no photos, locations or names of people.

import { PRIVACY_HTML, TERMS_HTML } from './legal.js';

const EVENTS = new Set([
  'app_opened', 'onboarding_step', 'scan_finished', 'game_added', 'game_opened', 'photos_action', 'plan_team_search',
  'plan_created', 'plan_attended', 'checkin_started', 'share_opened', 'share_tapped', 'tab_viewed',
  'venue_or_list_opened', 'setting_changed',
]);

const MAX_BODY = 32 * 1024;
const MAX_EVENTS = 50;
const PER_DEVICE_PER_HOUR = 600;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/e' && request.method === 'POST') return ingest(request, env);
    if (url.pathname === '/health') return new Response('ok');
    if (url.pathname === '/feedback' && request.method === 'POST') return feedback(request, env);
    if (url.pathname === '/requests') return requests(request, env, url);
    if (url.pathname.startsWith('/packs/')) return servePack(request, env, url.pathname.slice(7));
    if (url.pathname.startsWith('/packs-admin/')) return adminPacks(request, env, url.pathname.slice(13));
    // The privacy policy and terms the App Store listing and the app link to: public, no sign-in.
    if (url.pathname === '/privacy') return page(PRIVACY_HTML);
    if (url.pathname === '/terms') return page(TERMS_HTML);
    if (url.pathname === '/' && request.method === 'GET') return dashboard(request, env);
    return new Response('Not found', { status: 404 });
  },

  // Daily: events older than the retention the privacy policy promises are deleted.
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(env.DB.prepare('DELETE FROM events WHERE ts < ?').bind(Date.now() - RETENTION_MONTHS * 30 * 86400 * 1000).run());
  },
};

const RETENTION_MONTHS = 24;

function page(html) {
  return new Response(html, { headers: { 'content-type': 'text/html;charset=utf-8', 'cache-control': 'public, max-age=3600' } });
}

// MARK: Ingest

async function ingest(request, env) {
  if (request.headers.get('x-witness-key') !== env.INGEST_KEY) return new Response('Unauthorized', { status: 401 });
  const text = await request.text();
  if (text.length > MAX_BODY) return new Response('Too large', { status: 413 });
  let body;
  try { body = JSON.parse(text); } catch { return new Response('Bad JSON', { status: 400 }); }

  const device = String(body.device || '');
  if (!/^[0-9a-fA-F-]{20,40}$/.test(device)) return new Response('Bad device', { status: 400 });
  const clean = (v, n) => (typeof v === 'string' ? v.slice(0, n) : null);
  const session = clean(body.session, 40), version = clean(body.v, 20), os = clean(body.os, 20);
  const country = request.cf && request.cf.country ? String(request.cf.country).slice(0, 2) : null;

  const now = Date.now();
  const hourAgo = now - 3600 * 1000;
  const recent = await env.DB.prepare('SELECT COUNT(*) AS c FROM events WHERE device = ? AND ts > ?').bind(device, hourAgo).first();
  if (recent && recent.c > PER_DEVICE_PER_HOUR) return new Response('Slow down', { status: 429 });

  const rows = [];
  for (const e of (Array.isArray(body.events) ? body.events : []).slice(0, MAX_EVENTS)) {
    if (!e || !EVENTS.has(e.n)) continue;
    let ts = Number(e.t);
    if (!Number.isFinite(ts) || Math.abs(ts - now) > 7 * 86400 * 1000) ts = now;
    rows.push(env.DB.prepare(
      'INSERT INTO events (ts, day, name, device, session, app_version, os, country, props) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    ).bind(ts, new Date(ts).toISOString().slice(0, 10), e.n, device, session, version, os, country, cleanProps(e.p)));
  }
  if (rows.length) await env.DB.batch(rows);
  return new Response(null, { status: 204 });
}

// Short strings, numbers and booleans only, a dozen at most.
function cleanProps(p) {
  if (!p || typeof p !== 'object' || Array.isArray(p)) return null;
  const out = {};
  for (const [k, v] of Object.entries(p).slice(0, 12)) {
    if (!/^[a-z_]{1,32}$/.test(k)) continue;
    if (typeof v === 'string') out[k] = v.slice(0, 80);
    else if (typeof v === 'number' && Number.isFinite(v)) out[k] = v;
    else if (typeof v === 'boolean') out[k] = v;
  }
  const s = JSON.stringify(out);
  return s.length > 600 ? null : s;
}

// MARK: Feedback and requests

// What a fan sends from You → Feedback & requests: a kind, their words, an optional way to reach them. Listed at /requests
// behind the dashboard password, newest first, with a Done button per row.
const FEEDBACK_KINDS = { feature: 'Feature request', feedback: 'Feedback', sport: 'Sport or league to add', problem: "Something's wrong" };
const FEEDBACK_PER_DEVICE_PER_DAY = 10;
const FEEDBACK_MAX_TEXT = 2000;
let feedbackReady = false;

async function ensureFeedback(env) {
  if (feedbackReady) return;
  await env.DB.prepare(`CREATE TABLE IF NOT EXISTS feedback (
    id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL, contact TEXT,
    device TEXT NOT NULL, app_version TEXT, os TEXT, country TEXT, done INTEGER NOT NULL DEFAULT 0)`).run();
  feedbackReady = true;
}

async function feedback(request, env) {
  if (request.headers.get('x-witness-key') !== env.INGEST_KEY) return new Response('Unauthorized', { status: 401 });
  const raw = await request.text();
  if (raw.length > MAX_BODY) return new Response('Too large', { status: 413 });
  let body;
  try { body = JSON.parse(raw); } catch { return new Response('Bad JSON', { status: 400 }); }
  const device = String(body.device || '');
  if (!/^[0-9a-fA-F-]{20,40}$/.test(device)) return new Response('Bad device', { status: 400 });
  const kind = String(body.kind || '');
  if (!FEEDBACK_KINDS[kind]) return new Response('Bad kind', { status: 400 });
  const text = String(body.text || '').trim().slice(0, FEEDBACK_MAX_TEXT);
  if (!text) return new Response('Nothing to send', { status: 400 });
  const clean = (v, n) => (typeof v === 'string' && v.trim() ? v.trim().slice(0, n) : null);
  const contact = clean(body.contact, 120), version = clean(body.v, 20), os = clean(body.os, 20);
  const country = request.cf && request.cf.country ? String(request.cf.country).slice(0, 2) : null;

  await ensureFeedback(env);
  const now = Date.now();
  const today = await env.DB.prepare('SELECT COUNT(*) AS c FROM feedback WHERE device = ? AND ts > ?').bind(device, now - 86400 * 1000).first();
  if (today && today.c >= FEEDBACK_PER_DEVICE_PER_DAY) return new Response('Slow down', { status: 429 });
  await env.DB.prepare('INSERT INTO feedback (ts, kind, text, contact, device, app_version, os, country) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
    .bind(now, kind, text, contact, device, version, os, country).run();
  return new Response(null, { status: 204 });
}

async function requests(request, env, url) {
  if (!authorized(request, env)) {
    return new Response('Sign in', { status: 401, headers: { 'www-authenticate': 'Basic realm="Witness analytics"' } });
  }
  await ensureFeedback(env);
  if (request.method === 'POST') {
    const form = await request.formData();
    const id = Number(form.get('id')), done = form.get('done') === '1' ? 1 : 0;
    if (Number.isInteger(id)) await env.DB.prepare('UPDATE feedback SET done = ? WHERE id = ?').bind(done, id).run();
    return new Response(null, { status: 303, headers: { location: '/requests' + (url.search || '') } });
  }
  const kind = FEEDBACK_KINDS[url.searchParams.get('kind')] ? url.searchParams.get('kind') : null;
  const all = url.searchParams.get('show') === 'all';
  const where = [all ? null : 'done = 0', kind ? 'kind = ?' : null].filter(Boolean).join(' AND ');
  const rows = (await env.DB.prepare(`SELECT * FROM feedback${where ? ' WHERE ' + where : ''} ORDER BY ts DESC LIMIT 500`).bind(...(kind ? [kind] : [])).all()).results || [];
  const counts = Object.fromEntries(((await env.DB.prepare('SELECT kind, COUNT(*) AS c FROM feedback WHERE done = 0 GROUP BY kind').all()).results || []).map((x) => [x.kind, x.c]));
  const open = Object.values(counts).reduce((a, b) => a + b, 0);
  const q = (k, v) => { const p = new URLSearchParams(url.search); if (v) p.set(k, v); else p.delete(k); const s = p.toString(); return '/requests' + (s ? '?' + s : ''); };
  const filter = (label, href, on) => `<a class="f${on ? ' on' : ''}" href="${href}">${esc(label)}</a>`;
  const when = (ts) => new Date(ts).toISOString().slice(0, 16).replace('T', ' ');
  const html = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Witness requests</title><style>
:root{color-scheme:dark}body{margin:0;background:#050506;color:#f5f1ea;font:15px/1.45 -apple-system,Inter,sans-serif;padding:24px;max-width:1100px;margin:0 auto}
h1{font:800 34px 'Barlow Condensed',Impact,sans-serif;text-transform:uppercase;margin:0 0 4px}.sub{color:#9a958b;margin:0 0 18px}.sub a{color:#ffb547}
.filters{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 18px}.f{color:#f5f1ea;text-decoration:none;background:#121215;border-radius:999px;padding:7px 14px;font-size:13px}.f.on{background:#ffb547;color:#141413;font-weight:700}
.item{background:#121215;border-radius:16px;padding:16px 18px;margin:0 0 10px;display:grid;grid-template-columns:1fr auto;gap:12px}
.kind{font:700 12px Inter,sans-serif;letter-spacing:.12em;text-transform:uppercase;color:#ffb547}.meta{color:#9a958b;font-size:13px;margin-top:6px}
.text{white-space:pre-wrap;margin:6px 0 0;font-size:16px}.done .text{color:#9a958b}
button{background:#24242a;color:#f5f1ea;border:0;border-radius:10px;padding:8px 14px;font:600 13px Inter,sans-serif;cursor:pointer;align-self:start}.none{color:#6a665e}
</style></head><body>
<h1>Requests and feedback</h1><p class="sub">${open} open · <a href="/">back to analytics</a></p>
<div class="filters">
${filter(`All open (${open})`, q('kind', null).replace(/[?&]show=all/, ''), !kind && !all)}
${Object.entries(FEEDBACK_KINDS).map(([k, label]) => filter(`${label} (${counts[k] || 0})`, q('kind', k), kind === k)).join('')}
${filter('Including done', q('show', 'all'), all)}
</div>
${rows.length ? rows.map((x) => `<div class="item${x.done ? ' done' : ''}"><div>
<div class="kind">${esc(FEEDBACK_KINDS[x.kind] || x.kind)}${x.done ? ' · done' : ''}</div>
<p class="text">${esc(x.text)}</p>
<div class="meta">${when(x.ts)} UTC${x.contact ? ' · ' + esc(x.contact) : ''} · v${esc(x.app_version || '?')} · iOS ${esc(x.os || '?')}${x.country ? ' · ' + esc(x.country) : ''}</div>
</div><form method="post"><input type="hidden" name="id" value="${x.id}"><input type="hidden" name="done" value="${x.done ? 0 : 1}"><button>${x.done ? 'Reopen' : 'Done'}</button></form></div>`).join('')
  : '<p class="none">Nothing here</p>'}
</body></html>`;
  return new Response(html, { headers: { 'content-type': 'text/html;charset=utf-8', 'cache-control': 'no-store' } });
}

// MARK: Data packs

const PACK_KEY = /^[A-Za-z0-9._/-]{1,200}$/;
const validKey = (key) => PACK_KEY.test(key) && !key.includes('..');

async function servePack(request, env, key) {
  if (!env.PACKS || !validKey(key) || !['GET', 'HEAD'].includes(request.method)) return new Response('Not found', { status: 404 });
  const object = await env.PACKS.get(key);
  if (!object) return new Response('Not found', { status: 404 });
  const headers = new Headers({
    'content-type': 'application/json',
    'etag': object.httpEtag,
    // Files are named by their hash and never change; only the manifest is short-lived.
    'cache-control': key === 'manifest.json' ? 'public, max-age=300' : 'public, max-age=31536000, immutable',
  });
  if (request.headers.get('if-none-match') === object.httpEtag) return new Response(null, { status: 304, headers });
  return new Response(request.method === 'HEAD' ? null : object.body, { headers });
}

async function adminPacks(request, env, key) {
  if (!env.PACKS) return new Response('Not found', { status: 404 });
  if (!authorized(request, env)) return new Response('Sign in', { status: 401 });
  if (key === 'list' && request.method === 'GET') {
    const keys = [];
    let cursor;
    do {
      const page = await env.PACKS.list({ cursor, limit: 1000 });
      keys.push(...page.objects.map((o) => o.key));
      cursor = page.truncated ? page.cursor : undefined;
    } while (cursor);
    return Response.json(keys);
  }
  if (!validKey(key)) return new Response('Bad key', { status: 400 });
  if (request.method === 'PUT') { await env.PACKS.put(key, request.body); return new Response('ok'); }
  if (request.method === 'DELETE') { await env.PACKS.delete(key); return new Response('ok'); }
  return new Response('Not found', { status: 404 });
}

// MARK: Dashboard

function authorized(request, env) {
  const header = request.headers.get('authorization') || '';
  if (!env.DASH_PASSWORD || !header.startsWith('Basic ')) return false;
  let given = '';
  try { given = atob(header.slice(6)).split(':').slice(1).join(':'); } catch { return false; }
  const a = new TextEncoder().encode(given), b = new TextEncoder().encode(env.DASH_PASSWORD);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

async function dashboard(request, env) {
  if (!authorized(request, env)) {
    return new Response('Sign in', { status: 401, headers: { 'www-authenticate': 'Basic realm="Witness analytics"' } });
  }
  const q = (sql) => env.DB.prepare(sql);
  const prop = (k) => `json_extract(props, '$.${k}')`;
  const recent = (days) => `day >= date('now', '-${days - 1} days')`;
  const results = await env.DB.batch([
    q(`SELECT COUNT(DISTINCT device) AS c FROM events`),
    q(`SELECT COUNT(DISTINCT device) AS c FROM events WHERE name = 'app_opened' AND day = date('now')`),
    q(`SELECT COUNT(DISTINCT device) AS c FROM events WHERE name = 'app_opened' AND ${recent(7)}`),
    q(`SELECT COUNT(DISTINCT device) AS c FROM events WHERE name = 'app_opened' AND ${recent(30)}`),
    q(`SELECT day, COUNT(DISTINCT device) AS c FROM events WHERE name = 'app_opened' AND ${recent(30)} GROUP BY day ORDER BY day`),
    q(`SELECT d0 AS day, COUNT(*) AS c FROM (SELECT device, MIN(day) AS d0 FROM events GROUP BY device) WHERE d0 >= date('now', '-29 days') GROUP BY d0 ORDER BY d0`),
    q(`WITH f AS (SELECT device, MIN(day) AS d0 FROM events GROUP BY device)
       SELECT COUNT(*) AS n,
         SUM(EXISTS (SELECT 1 FROM events e WHERE e.device = f.device AND e.day = date(f.d0, '+1 day'))) AS d1,
         SUM(EXISTS (SELECT 1 FROM events e WHERE e.device = f.device AND e.day = date(f.d0, '+7 day'))) AS d7
       FROM f WHERE d0 <= date('now', '-8 days')`),
    q(`SELECT name AS k, COUNT(*) AS c FROM events WHERE ${recent(14)} GROUP BY name ORDER BY c DESC`),
    q(`SELECT ${prop('source')} AS k, COUNT(*) AS c FROM events WHERE name = 'game_added' AND ${recent(14)} GROUP BY k ORDER BY c DESC`),
    q(`SELECT COUNT(*) AS n, AVG(${prop('games')}) AS games, AVG(${prop('seconds')}) AS secs,
         SUM(CASE WHEN ${prop('games')} = 0 THEN 1 ELSE 0 END) AS empty
       FROM events WHERE name = 'scan_finished' AND ${recent(30)}`),
    q(`SELECT ${prop('team')} AS team, ${prop('league')} AS league, COUNT(*) AS searches,
         SUM(CASE WHEN ${prop('found')} = 0 THEN 1 ELSE 0 END) AS misses, COUNT(DISTINCT device) AS users
       FROM events WHERE name = 'plan_team_search' AND ${recent(60)} GROUP BY team, league
       HAVING misses > 0 ORDER BY misses DESC, searches DESC LIMIT 40`),
    q(`SELECT ${prop('source')} AS k, COUNT(*) AS c FROM events WHERE name = 'plan_created' AND ${recent(30)} GROUP BY k ORDER BY c DESC`),
    q(`SELECT name AS k, COUNT(*) AS c FROM events WHERE name IN ('plan_created', 'plan_attended') AND ${recent(30)} GROUP BY name`),
    q(`SELECT name || ' · ' || COALESCE(${prop('card')}, '?') || ' ' || COALESCE(${prop('style')}, '') AS k, COUNT(*) AS c
       FROM events WHERE name IN ('share_opened', 'share_tapped') AND ${recent(30)} GROUP BY k ORDER BY c DESC LIMIT 20`),
    q(`SELECT ${prop('result')} AS k, COUNT(*) AS c FROM events WHERE name = 'checkin_started' AND ${recent(30)} GROUP BY k ORDER BY c DESC`),
    q(`SELECT ${prop('step')} AS k, COUNT(*) AS c FROM events WHERE name = 'onboarding_step' AND ${recent(30)} GROUP BY k ORDER BY c DESC`),
    q(`SELECT ${prop('tab')} AS k, COUNT(*) AS c FROM events WHERE name = 'tab_viewed' AND ${recent(14)} GROUP BY k ORDER BY c DESC`),
    q(`SELECT ${prop('kind')} AS k, COUNT(*) AS c FROM events WHERE name = 'venue_or_list_opened' AND ${recent(14)} GROUP BY k ORDER BY c DESC`),
    q(`SELECT ${prop('sport')} AS k, COUNT(*) AS c FROM events WHERE name = 'game_opened' AND ${recent(14)} GROUP BY k ORDER BY c DESC`),
    q(`SELECT ${prop('action')} AS k, COUNT(*) AS c FROM events WHERE name = 'photos_action' AND ${recent(14)} GROUP BY k ORDER BY c DESC`),
    q(`SELECT ${prop('setting')} || ' → ' || ${prop('value')} AS k, COUNT(*) AS c FROM events WHERE name = 'setting_changed' AND ${recent(30)} GROUP BY k ORDER BY c DESC`),
    q(`SELECT app_version AS k, COUNT(DISTINCT device) AS c FROM events WHERE name = 'app_opened' AND ${recent(7)} GROUP BY k ORDER BY c DESC`),
  ]);
  const r = results.map((x) => x.results || []);
  const one = (i) => r[i][0] || {};
  await ensureFeedback(env);
  const openRequests = ((await env.DB.prepare('SELECT COUNT(*) AS c FROM feedback WHERE done = 0').first()) || {}).c || 0;
  const pct = (a, b) => (b ? Math.round((100 * (a || 0)) / b) + '%' : '–');
  const ret = one(6);
  const scan = one(9);

  const bars = (rows, label = 'k') => {
    const max = Math.max(1, ...rows.map((x) => x.c));
    return rows.length
      ? `<div class="bars">${rows.map((x) => `<div class="row"><span class="l">${esc(x[label] ?? '–')}</span><span class="b"><i style="width:${(100 * x.c) / max}%"></i></span><span class="n">${x.c}</span></div>`).join('')}</div>`
      : '<p class="none">Nothing yet</p>';
  };
  const series = (rows) => {
    const days = [];
    for (let i = 29; i >= 0; i--) days.push(new Date(Date.now() - i * 86400000).toISOString().slice(0, 10));
    const map = Object.fromEntries(rows.map((x) => [x.day, x.c]));
    const max = Math.max(1, ...days.map((d) => map[d] || 0));
    return `<div class="series">${days.map((d) => `<i title="${d}: ${map[d] || 0}" style="height:${Math.max(2, (100 * (map[d] || 0)) / max)}%"></i>`).join('')}</div>`;
  };
  const table = (head, rows) => rows.length
    ? `<table><tr>${head.map((h) => `<th>${h}</th>`).join('')}</tr>${rows.map((x) => `<tr>${x.map((c) => `<td>${esc(c)}</td>`).join('')}</tr>`).join('')}</table>`
    : '<p class="none">Nothing yet</p>';
  const plans = Object.fromEntries(r[12].map((x) => [x.k, x.c]));

  const html = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Witness analytics</title><style>
:root{color-scheme:dark}body{margin:0;background:#050506;color:#f5f1ea;font:15px/1.4 -apple-system,Inter,sans-serif;padding:24px;max-width:1100px;margin:0 auto}
h1{font:800 34px 'Barlow Condensed',Impact,sans-serif;text-transform:uppercase;margin:0 0 4px}h2{font:700 13px Inter,sans-serif;letter-spacing:.14em;text-transform:uppercase;color:#ffb547;margin:0 0 10px}
.sub{color:#9a958b;margin:0 0 22px}.sub a{color:#ffb547}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px}
.card{background:#121215;border-radius:16px;padding:18px}.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:16px}
.kpi{background:#121215;border-radius:16px;padding:16px}.kpi b{display:block;font:800 40px 'Barlow Condensed',Impact,sans-serif}.kpi span{color:#9a958b;font-size:13px}
.bars .row{display:grid;grid-template-columns:minmax(90px,38%) 1fr 40px;gap:10px;align-items:center;margin:6px 0}.l{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.b{background:#24242a;border-radius:6px;height:10px;display:block}.b i{display:block;height:100%;background:#ffb547;border-radius:6px}.n{text-align:right;color:#9a958b}
.series{display:flex;align-items:flex-end;gap:3px;height:90px}.series i{flex:1;background:#ffb547;border-radius:3px 3px 0 0;min-height:2px}
table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:6px 8px;border-bottom:1px solid #24242a;font-size:14px}th{color:#9a958b;font-weight:600}.none{color:#6a665e}
</style></head><body>
<h1>Witness analytics</h1><p class="sub">Anonymous usage. No photos, locations or names. Times are UTC. · <a href="/requests">Requests and feedback (${openRequests} open)</a></p>
<div class="kpis">
<div class="kpi"><b>${one(0).c || 0}</b><span>phones seen, all time</span></div>
<div class="kpi"><b>${one(1).c || 0}</b><span>opened today</span></div>
<div class="kpi"><b>${one(2).c || 0}</b><span>opened, last 7 days</span></div>
<div class="kpi"><b>${one(3).c || 0}</b><span>opened, last 30 days</span></div>
<div class="kpi"><b>${pct(ret.d1, ret.n)}</b><span>came back the next day (${ret.n || 0} phones)</span></div>
<div class="kpi"><b>${pct(ret.d7, ret.n)}</b><span>came back on day 7</span></div>
</div>
<div class="grid">
<div class="card"><h2>Phones opening the app, 30 days</h2>${series(r[4])}</div>
<div class="card"><h2>New phones, 30 days</h2>${series(r[5])}</div>
<div class="card"><h2>Photo scan, last 30 days</h2>${table(['scans', 'avg games found', 'found none', 'avg seconds'], scan.n ? [[scan.n, (scan.games || 0).toFixed(1), pct(scan.empty, scan.n), Math.round(scan.secs || 0)]] : [])}</div>
<div class="card"><h2>How games get added, 14 days</h2>${bars(r[8])}</div>
<div class="card"><h2>Schedule gaps: teams searched with no games, 60 days</h2>${table(['team', 'league', 'searches', 'empty', 'phones'], r[10].map((x) => [x.team, x.league, x.searches, x.misses, x.users]))}</div>
<div class="card"><h2>Planning, 30 days</h2>${bars(r[11])}<p class="sub">planned ${plans.plan_created || 0} · went to ${plans.plan_attended || 0}</p></div>
<div class="card"><h2>Sharing, 30 days</h2>${bars(r[13])}</div>
<div class="card"><h2>Check in live, 30 days</h2>${bars(r[14])}</div>
<div class="card"><h2>Onboarding steps, 30 days</h2>${bars(r[15])}</div>
<div class="card"><h2>Tabs, 14 days</h2>${bars(r[16])}</div>
<div class="card"><h2>Venues and Map lists, 14 days</h2>${bars(r[17])}</div>
<div class="card"><h2>Games opened by sport, 14 days</h2>${bars(r[18])}</div>
<div class="card"><h2>Photo actions, 14 days</h2>${bars(r[19])}</div>
<div class="card"><h2>Settings changed, 30 days</h2>${bars(r[20])}</div>
<div class="card"><h2>App versions, 7 days</h2>${bars(r[21])}</div>
<div class="card"><h2>All events, 14 days</h2>${bars(r[7])}</div>
</div></body></html>`;
  return new Response(html, { headers: { 'content-type': 'text/html;charset=utf-8', 'cache-control': 'no-store' } });
}
