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

// PINNED, not defaulted. Every one of these moves how much a canvas draws, and
// all three differ between a laptop and a CI runner. Two runs that cannot be
// compared are two runs that cannot bisect, so they are stated here and echoed
// into the report rather than inherited from whatever Playwright felt like.
const VIEWPORT = { width: 1280, height: 900 };
const DEVICE_SCALE_FACTOR = 1;

function fail(results, id, message) {
  results.push({ case: id, ok: false, message });
}

async function openPage(browser) {
  const context = await browser.newContext({ viewport: VIEWPORT, deviceScaleFactor: DEVICE_SCALE_FACTOR });

  // By host, not context.setOffline: that kills file:// too, and the document
  // under test IS a file.
  const attempted = [];
  await context.route('http://**', route => { attempted.push(route.request().url()); route.abort(); });
  await context.route('https://**', route => { attempted.push(route.request().url()); route.abort(); });

  const page = await context.newPage();
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') { errors.push(m.text()); } });
  page.on('pageerror', e => errors.push('uncaught: ' + e.message));
  return { context, page, errors, attempted };
}

async function screenshotBytes(page, selector) {
  const handle = await page.$(selector);
  if (!handle) { return null; }
  return (await handle.screenshot({ type: 'png' })).length;
}

// The floor for "this view drew something", measured on the machine running
// the check rather than pinned to the one that wrote it.
//
// A constant cannot survive the move: viewport, device pixel ratio, font
// availability and Chromium version all change how many bytes a drawn canvas
// compresses to, and every one of them differs in CI. The same backend
// rendering a payload with nothing in it is the same measurement taken here,
// now, so the comparison calibrates itself.
async function measureEmpty(browser, cache, backend, baselinePath, selector) {
  const key = backend + '|' + selector;
  if (Object.prototype.hasOwnProperty.call(cache, key)) { return cache[key]; }

  const { context, page } = await openPage(browser);
  try {
    await page.goto('file:///' + baselinePath.replace(/\\/g, '/'));
    await page.waitForTimeout(SETTLE_MS * 2);
    cache[key] = await screenshotBytes(page, selector);
  } finally {
    await context.close();
  }
  return cache[key];
}

async function run() {
  const jobPath = process.argv[2];
  if (!jobPath) { throw new Error('usage: smoke.cjs <job.json>'); }
  const job = JSON.parse(fs.readFileSync(jobPath, 'utf8'));

  const browser = await chromium.launch();
  const results = [];
  const emptyCache = {};
  const measured = [];

  for (const c of job.cases) {
    const id = c.backend + '/' + c.fixture;
    const { context, page, errors, attempted } = await openPage(browser);

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

      // Canvas content cannot be read from the DOM: a view that draws into a
      // canvas passes every DOM assertion above just as happily over a blank
      // rectangle. A screenshot is the only thing that can tell them apart,
      // and a PNG of a flat colour is tiny.
      //
      // Against the SAME backend rendering an empty payload, measured in this
      // run on this machine, so nothing is pinned to the hardware that wrote
      // the check. Locally that ratio is about 12; the requirement has daylight
      // in it rather than precision.
      await page.waitForTimeout(SETTLE_MS);
      for (const [selector, required] of Object.entries(smoke.CanvasGrowth || {})) {
        const drawn = await screenshotBytes(page, selector);
        if (drawn === null) { fail(results, id, 'nothing matched ' + selector + ' to screenshot'); continue; }

        const empty = await measureEmpty(browser, emptyCache, c.backend, c.baseline, selector);
        if (empty === null) {
          fail(results, id, 'nothing matched ' + selector + ' in the empty render, so there is no floor to compare against');
          continue;
        }
        if (empty <= 0) {
          fail(results, id, selector + ' screenshotted 0 bytes for an empty render, which is not a floor');
          continue;
        }

        const ratio = drawn / empty;
        measured.push({ case: id, selector, drawn, empty, ratio: Number(ratio.toFixed(2)), required });

        // Both absolute numbers in the message. A ratio that fails tells you
        // less than a ratio that fails and says which two numbers produced it.
        if (ratio < required) {
          fail(results, id, selector + ' drew ' + drawn + ' bytes of PNG against ' + empty
            + ' for an empty payload of the same backend on this machine - ratio '
            + ratio.toFixed(2) + ', and ' + required + ' is required. The view is blank.');
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
  console.log(JSON.stringify({
    viewport: VIEWPORT,
    deviceScaleFactor: DEVICE_SCALE_FACTOR,
    cases: results.length,
    failed: failed.length,
    canvas: measured,
    results,
  }, null, 2));
  process.exit(failed.length ? 1 : 0);
}

run().catch(e => { console.error(e); process.exit(2); });
