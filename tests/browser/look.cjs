// Does the LOOK obey its settings? Loads rendered documents in a headless
// browser, reads a job file, writes JSON to stdout, exits non-zero on failure.
//
// A third browser gate, beside smoke.cjs and link-mode.cjs, because it asks a
// third question. smoke.cjs establishes that a page came alive. link-mode.cjs
// establishes that the link a live page offers is the one configuration asked
// for. This establishes that the DRAWING a live page makes is the one
// configuration asked for - which neither of the others can see, because both
// of them are satisfied by a page that draws every item as the same blue ball.
//
// It knows nothing about any backend. What to click, what to read and what
// must differ from what arrives as data from the backend's own
// templateset.psd1, under LookProbe - the same rule Smoke and LinkProbe are
// built on, and for the same reason: a harness naming '#fg' would be a second
// place this backend's shape is written down.
//
// TWO KINDS OF EVIDENCE, and neither is sufficient alone:
//
//   The DOM says what the page RESOLVED. A backend that draws by a declared
//   kind -> shape mapping can state the mapping it resolved, per item, as text
//   - the same argument the counts in #fg-status are made of, because a canvas
//   cannot be read. That proves the mapping was consulted. It does not prove a
//   single pixel changed.
//
//   The PIXELS say what the page DREW. Rendering the same one-item payload
//   under two shape mappings and comparing the two screenshots proves geometry
//   reached the drawing. It does not prove WHICH shape, because a screenshot
//   is not a name.
//
// Presence is not consumption - pass 0050 paid for that lesson with a probe
// that corrupted a value rather than removing one, and a check that reads only
// the DOM here would go green over a page that resolved a shape per item and
// then drew a sphere every time.

const fs = require('fs');
const { chromium } = require('playwright');

const VIEWPORT = { width: 1280, height: 900 };
const DEVICE_SCALE_FACTOR = 1;
const READY_TIMEOUT_MS = 15000;

function fail(results, id, message) { results.push({ case: id, ok: false, message }); }

async function openPage(browser) {
  const context = await browser.newContext({ viewport: VIEWPORT, deviceScaleFactor: DEVICE_SCALE_FACTOR });
  const attempted = [];
  await context.route('http://**', route => { attempted.push(route.request().url()); route.abort(); });
  await context.route('https://**', route => { attempted.push(route.request().url()); route.abort(); });
  const page = await context.newPage();
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') { errors.push(m.text()); } });
  page.on('pageerror', e => errors.push('uncaught: ' + e.message));
  return { context, page, errors, attempted };
}

async function load(browser, probe, file, settleMs) {
  const opened = await openPage(browser);
  await opened.page.goto('file:///' + file.replace(/\\/g, '/'));
  await opened.page.waitForSelector(probe.Ready, { timeout: READY_TIMEOUT_MS });
  await opened.page.waitForTimeout(settleMs === undefined ? probe.Settle : settleMs);
  return opened;
}

// What the page says it resolved, read off the element the backend declares for
// it. One entry per item: id, the classification it carries, and the shape the
// mapping produced for it.
async function readResolved(page, probe) {
  return page.evaluate(sel => {
    const el = document.querySelector(sel);
    if (!el) { return null; }
    return JSON.parse(el.getAttribute('data-resolved') || 'null');
  }, probe.Resolved);
}

async function shoot(page, selector) {
  const handle = await page.$(selector);
  if (!handle) { return null; }
  return (await handle.screenshot({ type: 'png' })).toString('base64');
}

async function run() {
  const jobPath = process.argv[2];
  if (!jobPath) { throw new Error('usage: look.cjs <job.json>'); }
  const job = JSON.parse(fs.readFileSync(jobPath, 'utf8'));

  const browser = await chromium.launch();
  const results = [];
  const notes = [];

  for (const c of job.cases) {
    const probe = c.probe;
    const id = c.backend + '/' + c.name;

    try {
      // ---- B: the mapping was resolved, per item, from the payload's own
      //         classifications, with the declared fallback for the rest.
      if (c.kind === 'shapes') {
        const { context, page, errors, attempted } = await load(browser, probe, c.path);
        try {
          const resolved = await readResolved(page, probe);
          if (!resolved) {
            fail(results, id, 'nothing matched ' + probe.Resolved + ', so the page states no resolved mapping to check');
          } else {
            const shapes = [...new Set(resolved.map(r => r.shape))];
            const kinds = [...new Set(resolved.map(r => r.kind))];
            if (shapes.length < c.expect.distinctShapes) {
              fail(results, id, 'payload carries ' + kinds.length + ' classification(s) '
                + JSON.stringify(kinds) + ' and the page resolved only ' + shapes.length
                + ' distinct geometr(ies) ' + JSON.stringify(shapes) + '; '
                + c.expect.distinctShapes + ' required');
            }
            // The declared fallback, for a classification the mapping does not
            // name. A producer may send anything, so there is always one.
            if (c.expect.fallbackFor) {
              const hit = resolved.filter(r => r.kind === c.expect.fallbackFor);
              if (!hit.length) {
                fail(results, id, 'no item carries classification ' + c.expect.fallbackFor + ' to check the fallback with');
              } else if (hit.some(r => r.shape !== c.expect.fallbackShape)) {
                fail(results, id, 'unmapped classification ' + c.expect.fallbackFor + ' resolved to '
                  + JSON.stringify([...new Set(hit.map(r => r.shape))]) + ', and the declared fallback is '
                  + c.expect.fallbackShape);
              }
            }
            notes.push({ case: id, kinds, shapes, items: resolved.length });
          }
          if (attempted.length) { fail(results, id, 'tried to fetch ' + attempted.join(', ')); }
          if (errors.length) { fail(results, id, errors.length + ' console error(s): ' + errors.slice(0, 3).join(' | ')); }
        } finally { await context.close(); }
      }

      // ---- B: and the geometry reached the DRAWING. Two documents that differ
      //         in one theme value must not produce the same picture.
      else if (c.kind === 'pixels') {
        const a = await load(browser, probe, c.path);
        const b = await load(browser, probe, c.other);
        try {
          const shotA = await shoot(a.page, probe.Canvas);
          const shotB = await shoot(b.page, probe.Canvas);
          if (!shotA || !shotB) {
            fail(results, id, 'nothing matched ' + probe.Canvas + ' to screenshot');
          } else if (shotA === shotB) {
            fail(results, id, c.what + ' produced a byte-identical picture, so the setting reached the DOM and never reached the drawing');
          } else {
            notes.push({ case: id, what: c.what, bytesA: shotA.length, bytesB: shotB.length, identical: false });
          }
          for (const opened of [a, b]) {
            if (opened.errors.length) { fail(results, id, opened.errors.length + ' console error(s): ' + opened.errors.slice(0, 3).join(' | ')); }
          }
        } finally { await a.context.close(); await b.context.close(); }
      }

      // ---- C: a setting reached the LIVE object that consumes it. Read back
      //         off the page rather than inferred from the document text: a
      //         value written into CONFIG and never applied is exactly the
      //         failure this case exists to catch.
      else if (c.kind === 'live') {
        const { context, page, errors } = await load(browser, probe, c.path);
        try {
          const observed = await page.evaluate(sel => {
            const el = document.querySelector(sel);
            if (!el) { return null; }
            return JSON.parse(el.getAttribute('data-live') || 'null');
          }, probe.Live);
          if (!observed) {
            fail(results, id, 'nothing matched ' + probe.Live + ', so no live value is reported');
          } else if (String(observed[c.field]) !== String(c.expect.value)) {
            fail(results, id, 'configured ' + c.field + '=' + c.expect.value
              + ' and the live object reports ' + JSON.stringify(observed[c.field])
              + '. The setting is declared and not consumed.');
          } else {
            notes.push({ case: id, field: c.field, live: observed[c.field] });
          }
          if (errors.length) { fail(results, id, errors.length + ' console error(s): ' + errors.slice(0, 3).join(' | ')); }
        } finally { await context.close(); }
      }

      // ---- C: a setting SCALES a live value, proven by two documents rather
      //         than by one reading. The right check for anything the page
      //         normalises: the fog density that reaches the scene is the
      //         configured number divided by how far the camera ended up, so
      //         one document can only ever say "some fog exists". Two say the
      //         setting is what moved it.
      else if (c.kind === 'liveRatio') {
        const a = await load(browser, probe, c.path);
        const b = await load(browser, probe, c.other);
        try {
          const read = async page => {
            const v = await page.evaluate(sel => {
              const el = document.querySelector(sel);
              return el ? JSON.parse(el.getAttribute('data-live') || 'null') : null;
            }, probe.Live);
            return v ? Number(v[c.field]) : null;
          };
          const va = await read(a.page), vb = await read(b.page);
          if (!va || !vb) {
            fail(results, id, 'one of the two documents reported no ' + c.field
              + ': ' + JSON.stringify([va, vb]));
          } else {
            const ratio = va / vb;
            // Loose, deliberately. Both documents lay the same payload out the
            // same way, but the camera lands where zoomToFit puts it and that
            // is not identical to the last decimal between two runs.
            const lo = c.expect.ratio * 0.85, hi = c.expect.ratio * 1.15;
            if (ratio < lo || ratio > hi) {
              fail(results, id, c.field + ' was ' + va + ' at one setting and ' + vb
                + ' at the other - ratio ' + ratio.toFixed(3) + ', and ' + c.expect.ratio
                + ' was configured. The setting does not scale the live value.');
            } else {
              notes.push({ case: id, field: c.field, high: va, low: vb, ratio: Number(ratio.toFixed(3)) });
            }
          }
          for (const opened of [a, b]) {
            if (opened.errors.length) { fail(results, id, opened.errors.length + ' console error(s): ' + opened.errors.slice(0, 3).join(' | ')); }
          }
        } finally { await a.context.close(); await b.context.close(); }
      }

      // ---- C: hover does what the setting says, driven through a real pointer.
      else if (c.kind === 'hover') {
        const { context, page, errors } = await load(browser, probe, c.path);
        try {
          const box = await (await page.$(probe.Canvas)).boundingBox();
          let hit = null;
          for (const [fx, fy] of (probe.Points || [[0.5, 0.5]])) {
            await page.mouse.move(box.x + box.width * fx, box.y + box.height * fy);
            await page.waitForTimeout(probe.Hover);
            const state = await page.evaluate(sel => {
              const el = document.querySelector(sel);
              return el ? JSON.parse(el.getAttribute('data-hover') || 'null') : null;
            }, probe.Live);
            if (state && state.over) { hit = state; break; }
          }
          if (!hit) {
            fail(results, id, 'the pointer never came to rest over an item at any of '
              + (probe.Points || [[0.5, 0.5]]).length + ' point(s), so hover behaviour was never exercised');
          } else if (c.expect.highlights === 0 && hit.highlighted > 0) {
            fail(results, id, 'HoverMode is off and the page highlighted ' + hit.highlighted + ' item(s)');
          } else if (c.expect.highlights === 'neighbors' && !(hit.highlighted > 1)) {
            fail(results, id, 'HoverMode is neighbors and the page highlighted ' + hit.highlighted
              + ' item(s) - the hovered item and nothing else is what "node" means');
          } else if (c.expect.highlights === 'node' && hit.highlighted !== 1) {
            fail(results, id, 'HoverMode is node and the page highlighted ' + hit.highlighted + ' item(s)');
          } else {
            notes.push({ case: id, mode: c.expect.highlights, highlighted: hit.highlighted, tooltip: hit.tooltip });
          }
          if (c.expect.tooltipContains !== undefined && hit) {
            const t = String(hit.tooltip === null ? '' : hit.tooltip);
            if (c.expect.tooltipContains === '' ? t !== '' : t.indexOf(c.expect.tooltipContains) < 0) {
              fail(results, id, 'HoverTooltip is ' + c.expect.tooltip + ' and the tooltip read '
                + JSON.stringify(t) + ', which does not carry ' + JSON.stringify(c.expect.tooltipContains));
            }
          }
          if (errors.length) { fail(results, id, errors.length + ' console error(s): ' + errors.slice(0, 3).join(' | ')); }
        } finally { await context.close(); }
      }

      else {
        fail(results, id, 'unknown case kind ' + c.kind);
      }

      if (!results.some(r => r.case === id && !r.ok)) {
        results.push({ case: id, ok: true, message: 'obeyed' });
      }
    } catch (e) {
      fail(results, id, 'threw: ' + e.message);
    }
  }

  await browser.close();

  const failed = results.filter(r => !r.ok);
  console.log(JSON.stringify({
    viewport: VIEWPORT,
    deviceScaleFactor: DEVICE_SCALE_FACTOR,
    cases: results.length,
    failed: failed.length,
    observed: notes,
    results,
  }, null, 2));
  process.exit(failed.length ? 1 : 0);
}

run().catch(e => { console.error(e); process.exit(2); });
