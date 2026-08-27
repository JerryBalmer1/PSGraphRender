// Screenshots of generated sample pages, for the docs.
//
// Separate from tests/browser/smoke.cjs on purpose. That file is a GATE: it
// decides whether the build goes red, it blocks the network to make its red
// unambiguous, and it is the thing four iterations of falsifiability work were
// spent on. Adding a "also save the picture" branch to it would put a
// documentation errand inside the one script that must not acquire reasons to
// change.
//
// This takes pictures. If it breaks, nothing is wrong with the renderer.
//
// Usage: node tools/shoot.cjs <job.json>
//   { "outDir": "...", "viewport": {...}, "deviceScaleFactor": 1,
//     "shots": [ { "id": "...", "file": "...", "selector": "#cy" | null,
//                  "settleMs": 1200 } ] }

const fs = require('fs');
const path = require('path');
const { chromium } = require(path.join(__dirname, '..', 'tests', 'browser', 'node_modules', 'playwright'));

async function main() {
  const job = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  fs.mkdirSync(job.outDir, { recursive: true });

  const browser = await chromium.launch();
  const context = await browser.newContext({
    // Pinned for the same reason the harness pins them: two pictures that
    // cannot be compared are two pictures that cannot show a change.
    viewport: job.viewport,
    deviceScaleFactor: job.deviceScaleFactor
  });

  // Blocked, exactly as the harness blocks it. A sample page that quietly
  // needed a CDN would be a sample of something this repository does not ship.
  await context.route('http://**', route => route.abort());
  await context.route('https://**', route => route.abort());

  const results = [];
  for (const shot of job.shots) {
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

    await page.goto('file://' + shot.file.replace(/\\/g, '/'), { waitUntil: 'load' });
    // A layout runs after load. Nothing here waits on a selector being
    // populated, because a page that draws nothing is a picture worth having.
    await page.waitForTimeout(shot.settleMs || 1200);

    // Anything the picture needs turned on first. A default view is one view.
    for (const selector of (shot.clicks || [])) {
      // Through the DOM rather than Playwright's click. These are checkboxes a
      // stylesheet may have made invisible in favour of their label, and a
      // picture of a filtered view is the point - not a test of hit targets.
      const hit = await page.evaluate(function (sel) {
        var el = document.querySelector(sel);
        if (!el) { return false; }
        el.click();
        return true;
      }, selector);
      if (!hit) { errors.push('click target ' + selector + ' matched nothing'); }
    }
    if ((shot.clicks || []).length) { await page.waitForTimeout(shot.afterClickMs || 1500); }

    const out = path.join(job.outDir, shot.id + '.png');
    if (shot.selector) {
      const handle = await page.$(shot.selector);
      if (handle) {
        await handle.screenshot({ path: out });
      } else {
        await page.screenshot({ path: out });
        errors.push('selector ' + shot.selector + ' matched nothing; took the whole page instead');
      }
    } else {
      await page.screenshot({ path: out, fullPage: false });
    }

    results.push({ id: shot.id, png: out, bytes: fs.statSync(out).size, errors: errors });
    await page.close();
  }

  await browser.close();
  process.stdout.write(JSON.stringify(results, null, 2));
}

main().catch(e => { process.stderr.write(String(e && e.stack || e)); process.exit(1); });
