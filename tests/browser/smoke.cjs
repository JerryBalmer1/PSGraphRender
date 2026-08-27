// Loads rendered documents in a headless browser and reports whether each one
// came alive. Reads a job file, writes JSON to stdout, exits non-zero if any
// case failed.
//
// It knows nothing about any backend. What "came alive" means is declared by
// each backend in its own templateset.psd1 under Smoke, and arrives here as
// data - otherwise this file would be a second place a backend's shape is
// written down, which is the design bug iteration 2 removed from src/.
//
// The network is blocked, not merely unused. A harness that can reach a CDN
// has not tested what it thinks it has: before v0.5.0 an offline cytoscape
// page and a broken script produced the same signature, and that ambiguity is
// the reason the libraries are vendored.

const fs = require('fs');
const { chromium } = require('playwright');

const SETTLE_MS = 500;
const READY_TIMEOUT_MS = 15000;

function fail(results, id, message) {
  results.push({ case: id, ok: false, message });
}

async function run() {
  const jobPath = process.argv[2];
  if (!jobPath) { throw new Error('usage: smoke.cjs <job.json>'); }
  const job = JSON.parse(fs.readFileSync(jobPath, 'utf8'));

  const browser = await chromium.launch();
  const results = [];

  for (const c of job.cases) {
    const id = c.backend + '/' + c.fixture;
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });

    // By host, not context.setOffline: that kills file:// too, and the
    // document under test IS a file.
    const attempted = [];
    await context.route('http://**', route => { attempted.push(route.request().url()); route.abort(); });
    await context.route('https://**', route => { attempted.push(route.request().url()); route.abort(); });

    const page = await context.newPage();
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') { errors.push(m.text()); } });
    page.on('pageerror', e => errors.push('uncaught: ' + e.message));

    try {
      await page.goto('file:///' + c.path.replace(/\\/g, '/'));

      const smoke = c.smoke || {};
      const text = smoke.Text || {};
      const elements = smoke.Elements || {};

      // Wait for what the backend says should be true rather than for a fixed
      // sleep, so a slow machine does not read as a broken page.
      const wanted = { text: {}, elements: {} };
      for (const [selector, key] of Object.entries(text)) { wanted.text[selector] = c.counts[key]; }
      for (const [selector, key] of Object.entries(elements)) { wanted.elements[selector] = c.counts[key]; }

      let ready = true;
      try {
        await page.waitForFunction(w => {
          for (const [selector, expected] of Object.entries(w.text)) {
            const el = document.querySelector(selector);
            if (!el || Number(el.textContent.trim()) !== expected) { return false; }
          }
          for (const [selector, expected] of Object.entries(w.elements)) {
            if (document.querySelectorAll(selector).length !== expected) { return false; }
          }
          return true;
        }, wanted, { timeout: READY_TIMEOUT_MS });
      } catch (e) {
        ready = false;
      }

      // Read the actual values whether or not the wait succeeded: "expected 17,
      // found 0" is a report, "timed out" is not.
      const observed = await page.evaluate(w => {
        const out = { text: {}, elements: {} };
        for (const selector of Object.keys(w.text)) {
          const el = document.querySelector(selector);
          out.text[selector] = el ? el.textContent.trim() : null;
        }
        for (const selector of Object.keys(w.elements)) {
          out.elements[selector] = document.querySelectorAll(selector).length;
        }
        return out;
      }, wanted);

      if (!ready) {
        fail(results, id, 'page did not reach its declared ready state: expected '
          + JSON.stringify(wanted) + ', found ' + JSON.stringify(observed));
        await context.close();
        continue;
      }

      for (const selector of smoke.Present || []) {
        const count = await page.evaluate(s => document.querySelectorAll(s).length, selector);
        if (count < 1) { fail(results, id, 'nothing matched ' + selector); }
      }

      // Canvas content cannot be read from the DOM: cytoscape draws into a
      // canvas, so every DOM assertion above passes just as happily over a
      // blank rectangle. A screenshot is the only thing that can tell them
      // apart, and a PNG of a flat colour is tiny.
      await page.waitForTimeout(SETTLE_MS);
      for (const [selector, minimum] of Object.entries(smoke.MinScreenshotBytes || {})) {
        const handle = await page.$(selector);
        if (!handle) { fail(results, id, 'nothing matched ' + selector + ' to screenshot'); continue; }
        const bytes = (await handle.screenshot({ type: 'png' })).length;
        if (bytes < minimum) {
          fail(results, id, selector + ' rendered ' + bytes + ' bytes of PNG, below the ' + minimum
            + ' a drawn view produces - the view is blank');
        }
      }

      if (attempted.length) {
        fail(results, id, 'tried to fetch ' + attempted.length + ' external resource(s): ' + attempted.join(', '));
      }
      if (errors.length) {
        fail(results, id, errors.length + ' console error(s): ' + errors.slice(0, 3).join(' | '));
      }

      if (!results.some(r => r.case === id && !r.ok)) {
        results.push({ case: id, ok: true, message: 'alive' });
      }
    } catch (e) {
      fail(results, id, 'threw: ' + e.message);
    } finally {
      await context.close();
    }
  }

  await browser.close();

  const failed = results.filter(r => !r.ok);
  console.log(JSON.stringify({ cases: results.length, failed: failed.length, results }, null, 2));
  process.exit(failed.length ? 1 : 0);
}

run().catch(e => { console.error(e); process.exit(2); });
