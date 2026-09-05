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

async function screenshot(page, selector) {
  const handle = await page.$(selector);
  if (!handle) { return null; }
  return await handle.screenshot({ type: 'png' });
}

// The floor for "this view drew something", measured on the machine running
// the check rather than pinned to the one that wrote it.
//
// A constant cannot survive the move: viewport, device pixel ratio, font
// availability and Chromium version all change what a drawn canvas looks like,
// and every one of them differs in CI. The same backend rendering a payload
// with nothing in it is the same measurement taken here, now, so the
// comparison calibrates itself.
//
// The PICTURE is cached, not a number taken from it. Both floors below are
// computed from the same two images, and one of them needs the pixels.
async function measureEmpty(browser, cache, backend, baselinePath, selector) {
  const key = backend + '|' + selector;
  if (Object.prototype.hasOwnProperty.call(cache, key)) { return cache[key]; }

  const { context, page } = await openPage(browser);
  try {
    await page.goto('file:///' + baselinePath.replace(/\\/g, '/'));
    await page.waitForTimeout(SETTLE_MS * 2);
    cache[key] = await screenshot(page, selector);
  } finally {
    await context.close();
  }
  return cache[key];
}

// WHAT COUNTS AS A DIFFERENT PIXEL, and it is pinned here rather than declared
// per backend for the same reason VIEWPORT is: it is a property of the
// instrument, not of the thing being measured. A backend declares HOW MUCH of
// its canvas must differ; the harness declares what "differ" means, once, so
// two backends' floors are numbers on the same scale.
//
// Largest per-channel absolute difference, in 0-255. Twelve rather than one:
// a WebGL canvas is not deterministic to the last bit between two contexts -
// antialiasing, tone mapping and the compositor all land a shade apart - and a
// threshold of one would count that noise as drawing. Measured: an empty
// render against a SECOND empty render of the same document scores 0.0000 at
// twelve. That control is spot-check SC1's other half and it is why the number
// is twelve and not two.
const CHANNEL_THRESHOLD = 12;

// WHEN A BYTE RATIO IS STILL ALLOWED TO BE THE FLOOR, as a measurement rather
// than as a sentence.
//
// `CanvasGrowth` divides the drawn picture's PNG size by the empty one's. That
// only discriminates while the empty picture is nearly blank: anything painted
// into the captured rectangle is in both numbers and pulls the ratio toward 1.
// `styles/base.css` said so in prose from v0.15.0 - "chrome over the canvas
// does not make a blank page look drawn, but it makes a drawn page look less
// drawn; the floor stops discriminating long before it stops passing" - and
// nothing made it a check, so the next thing painted there was found by reading
// a 1.05 off a correct page. That is finding 67, and this is the check.
//
// PNG BYTES PER PIXEL of the EMPTY capture, which is the thing the sentence is
// actually about, and it does not name a backend's settings - a harness that
// knew about `BackgroundStyle` would be a second place that backend's shape is
// written down. Measured at 1280x900 DSF 1:
//
//   capture                              bytes      px        B/px
//   cytoscape #cy empty                  4,413    834,718    0.0053
//   forcegraph3d #fg empty, flat         5,168  1,103,360    0.0047
//   forcegraph3d #fg empty, vignette   339,574  1,103,360    0.3078
//
// 0.05 is an order of magnitude above both blank cases and six times below the
// gradient, so it separates the two populations rather than splitting either.
// A backend over the ceiling is told to declare CanvasDelta instead; it is not
// told to stop painting.
const GROWTH_EMPTY_BYTES_PER_PIXEL = 0.05;

// The repair for the defect finding 67 recorded, and the reason it is a
// DIFFERENCE rather than a ratio.
//
// Until v0.16.0 the floor was `drawn PNG bytes / empty PNG bytes`. Anything
// painted inside the captured rectangle is in BOTH numbers, so it lands in the
// numerator and the denominator together and drives the ratio toward 1. It is
// not a matter of degree: PNG cannot compress a gradient, so a vignette that a
// reader can barely see costs 339,574 bytes of empty render and takes the same
// drawing from 4.32 to 1.05 - under the shipped floor of 2.25, on a page that
// is drawing perfectly. `styles/base.css` carried that warning in prose from
// v0.15.0 and nothing turned the sentence into a check.
//
// Comparing the two pictures against EACH OTHER cancels the background instead
// of being dominated by it: a pixel the environment paints is the same pixel
// in both, so it contributes nothing. What is left is what the payload put
// there, which is the only thing this gate was ever asking about.
//
// DECODED IN THE BROWSER that is already open, rather than by a PNG library.
// tests/browser/package.json declares exactly one dependency and the whole
// claim of the harness is that it needs nothing else; a decoder would be a
// second. A data: URL does not taint a canvas, so getImageData is readable.
async function changedFraction(browser, drawn, empty) {
  const { context, page } = await openPage(browser);
  try {
    await page.goto('about:blank');
    return await page.evaluate(async (arg) => {
      const load = src => new Promise((res, rej) => {
        const i = new Image();
        i.onload = () => res(i);
        i.onerror = () => rej(new Error('the harness could not decode a screenshot it had just taken'));
        i.src = src;
      });
      const a = await load('data:image/png;base64,' + arg.drawn);
      const b = await load('data:image/png;base64,' + arg.empty);

      // Two captures of the same selector at the same pinned viewport are the
      // same size, so a mismatch is a real finding rather than something to
      // resize away: it means the drawn document laid its canvas out
      // differently from the empty one, which the caller wants told about.
      if (a.width !== b.width || a.height !== b.height) {
        return { error: 'the drawn capture is ' + a.width + 'x' + a.height
          + ' and the empty one is ' + b.width + 'x' + b.height
          + ', so the two cannot be compared pixel for pixel' };
      }

      const canvas = document.createElement('canvas');
      canvas.width = a.width;
      canvas.height = a.height;
      const ctx = canvas.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(a, 0, 0);
      const da = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(b, 0, 0);
      const db = ctx.getImageData(0, 0, canvas.width, canvas.height).data;

      let changed = 0;
      const total = canvas.width * canvas.height;
      for (let i = 0; i < total; i++) {
        const o = i * 4;
        const d = Math.max(
          Math.abs(da[o] - db[o]),
          Math.abs(da[o + 1] - db[o + 1]),
          Math.abs(da[o + 2] - db[o + 2]));
        if (d > arg.threshold) { changed++; }
      }
      return { changed: changed, total: total, fraction: changed / total };
    }, { drawn: drawn.toString('base64'), empty: empty.toString('base64'), threshold: CHANNEL_THRESHOLD });
  } finally {
    await context.close();
  }
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
      // rectangle. A screenshot is the only thing that can tell them apart.
      //
      // Against the SAME backend rendering an empty payload, measured in this
      // run on this machine, so nothing is pinned to the hardware that wrote
      // the check.
      //
      // TWO DECLARATIONS, and a backend picks the one that can see it:
      //
      //   CanvasDelta   the fraction of the rectangle whose pixels the payload
      //                 CHANGED. Survives a painted background, because a
      //                 background is in both pictures and cancels.
      //   CanvasGrowth  the older ratio of PNG byte lengths. Still honest for a
      //                 backend whose empty render is nearly blank, and still
      //                 what `cytoscape` is held to.
      //
      // BOTH NUMBERS ARE COMPUTED AND REPORTED FOR EVERY CANVAS, whichever key
      // declared it, because the two pictures are already in hand and the
      // comparison between the metrics is the evidence that decided the
      // change. A backend gated on one of them still has the other printed
      // beside it on every run, which is how the next floor gets re-pinned
      // from measurement rather than from argument.
      await page.waitForTimeout(SETTLE_MS);

      const growth = smoke.CanvasGrowth || {};
      const delta = smoke.CanvasDelta || {};
      const canvases = [...new Set([...Object.keys(growth), ...Object.keys(delta)])];

      for (const selector of canvases) {
        const drawn = await screenshot(page, selector);
        if (drawn === null) { fail(results, id, 'nothing matched ' + selector + ' to screenshot'); continue; }

        const empty = await measureEmpty(browser, emptyCache, c.backend, c.baseline, selector);
        if (empty === null) {
          fail(results, id, 'nothing matched ' + selector + ' in the empty render, so there is no floor to compare against');
          continue;
        }
        if (empty.length <= 0) {
          fail(results, id, selector + ' screenshotted 0 bytes for an empty render, which is not a floor');
          continue;
        }

        const row = { case: id, selector, drawnBytes: drawn.length, emptyBytes: empty.length };
        row.ratio = Number((drawn.length / empty.length).toFixed(2));

        const diff = await changedFraction(browser, drawn, empty);
        if (diff.error) {
          fail(results, id, selector + ': ' + diff.error);
        } else {
          row.changedPixels = diff.changed;
          row.totalPixels = diff.total;
          row.fraction = Number(diff.fraction.toFixed(4));
        }
        row.gatedOn = Object.prototype.hasOwnProperty.call(delta, selector) ? 'CanvasDelta' : 'CanvasGrowth';
        row.required = row.gatedOn === 'CanvasDelta' ? delta[selector] : growth[selector];
        measured.push(row);

        // Every number that produced the verdict goes in the message. A floor
        // that fails tells you less than a floor that fails and says which
        // measurements it failed on.
        if (row.gatedOn === 'CanvasDelta') {
          if (diff.error) { continue; }
          if (diff.fraction < delta[selector]) {
            fail(results, id, selector + ' differs from the same backend\'s empty render in '
              + diff.changed + ' of ' + diff.total + ' pixels - a fraction of '
              + diff.fraction.toFixed(4) + ', and ' + delta[selector] + ' is required at a per-channel '
              + 'threshold of ' + CHANNEL_THRESHOLD + '. The view is blank.');
          }
        } else {
          // The instrument checks ITSELF before it checks the page. A byte
          // ratio is only a floor while the empty capture is nearly blank, and
          // that is measurable rather than assertable - see
          // GROWTH_EMPTY_BYTES_PER_PIXEL.
          if (row.totalPixels) { row.emptyBytesPerPixel = Number((empty.length / row.totalPixels).toFixed(4)); }
          if (row.emptyBytesPerPixel > GROWTH_EMPTY_BYTES_PER_PIXEL) {
            fail(results, id, selector + ' is gated on CanvasGrowth, and CanvasGrowth is a ratio against '
              + 'an empty render that is supposed to be nearly blank. This one is not: ' + empty.length
              + ' bytes over ' + row.totalPixels + ' pixels is ' + row.emptyBytesPerPixel
              + ' B/px, and ' + GROWTH_EMPTY_BYTES_PER_PIXEL + ' is the ceiling. Whatever is painted there '
              + 'is in the drawn picture too, so the ratio is measuring the background as much as the '
              + 'drawing. Declare CanvasDelta for ' + selector + ' instead; it changed '
              + (row.fraction === undefined ? 'an unknown fraction' : row.fraction.toFixed(4))
              + ' of the rectangle in this run.');
          } else if (row.ratio < growth[selector]) {
            fail(results, id, selector + ' drew ' + drawn.length + ' bytes of PNG against ' + empty.length
              + ' for an empty payload of the same backend on this machine - ratio '
              + row.ratio.toFixed(2) + ', and ' + growth[selector] + ' is required. The view is blank.'
              + (row.fraction === undefined ? '' : ' (It changed ' + row.fraction.toFixed(4)
                + ' of the rectangle, which CanvasDelta would have measured instead.)'));
          }
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
    channelThreshold: CHANNEL_THRESHOLD,
    cases: results.length,
    failed: failed.length,
    canvas: measured,
    results,
  }, null, 2));
  process.exit(failed.length ? 1 : 0);
}

run().catch(e => { console.error(e); process.exit(2); });
