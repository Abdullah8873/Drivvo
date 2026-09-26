// Checks that the security headers in web/_headers don't break the web app:
// serves a release build locally WITH those headers, opens a few screens in
// headless Chromium and fails on any Content-Security-Policy violation or
// page error. Every request that isn't to localhost is blocked, so nothing
// leaves the machine (build with --no-web-resources-cdn so CanvasKit is
// local too).
//
//   flutter build web --release --no-web-resources-cdn
//   NODE_PATH=$(npm root -g) node tool/web_csp_check.cjs [build/web]
//
// Needs Node and the `playwright` package with a Chromium browser.
'use strict';
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2] || 'build/web');
const headers = {};
let inBlock = false;
for (const line of fs.readFileSync(path.join(root, '_headers'), 'utf8').split('\n')) {
  if (line.startsWith('/*')) { inBlock = true; continue; }
  const m = inBlock && line.match(/^\s+([A-Za-z-]+):\s*(.+)$/);
  if (m) headers[m[1]] = m[2].trim();
}
if (!headers['Content-Security-Policy']) throw new Error('no CSP in _headers');

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png',
  '.otf': 'font/otf', '.ttf': 'font/ttf', '.css': 'text/css', '.ico': 'image/x-icon',
  '.symbols': 'text/plain', '.frag': 'text/plain',
};
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  let file = path.join(root, decodeURIComponent(url.pathname));
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(root, 'index.html'); // client-side routes
  }
  const h = { ...headers, 'Content-Type': types[path.extname(file)] || 'application/octet-stream' };
  delete h['Strict-Transport-Security']; // meaningless over http://localhost
  res.writeHead(200, h);
  fs.createReadStream(file).pipe(res);
});

(async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://localhost:${server.address().port}`;
  const browser = await chromium.launch();
  // A locale is required: without one Flutter's intl throws at start-up.
  const page = await browser.newPage({ locale: 'en-US' });
  const problems = [];
  const blocked = new Set();
  await page.route('**/*', (route) => {
    const u = new URL(route.request().url());
    if (u.hostname === 'localhost' || u.hostname === '127.0.0.1') return route.continue();
    blocked.add(u.origin);
    return route.abort();
  });
  await page.addInitScript(() => {
    document.addEventListener('securitypolicyviolation', (e) => {
      console.error(`CSP violation: ${e.violatedDirective} blocked ${e.blockedURI}`);
    });
  });
  page.on('console', (m) => {
    const t = m.text();
    if (/CSP violation|Content Security Policy|Refused to/i.test(t)) problems.push(t);
  });
  page.on('pageerror', (e) => problems.push(`page error: ${e.message}`));

  for (const route of ['/', '/reports', '/places', '/more']) {
    await page.goto(base + route);
    await page.waitForSelector('flutter-view', { timeout: 30000 });
    await page.waitForTimeout(4000);
    const shot = path.join(require('node:os').tmpdir(), `csp${route.replace(/\//g, '_') || '_'}.png`);
    await page.screenshot({ path: shot });
    console.log(`opened ${route} (screenshot ${shot})`);
  }
  await browser.close();
  server.close();
  console.log(`blocked (external, expected): ${[...blocked].join(', ') || 'none'}`);
  if (problems.length) {
    console.error(`FAILED:\n  ${problems.join('\n  ')}`);
    process.exit(1);
  }
  console.log('No CSP violations or page errors.');
})().catch((e) => { console.error(e); process.exit(1); });
