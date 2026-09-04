// What a node link actually does, in a real browser. The PowerShell suite
// asserts what is IN the document; this asserts what the document DOES, and the
// two are not the same claim - a template string sitting in a config blob is not
// a link until something resolves it against a node.
//
// It drives the real UI rather than reaching into the page. Nothing here calls a
// function the page defines: cy and the link resolvers live inside the
// bootstrap IIFE, and exposing them for a test would put a global into every
// shipped report - which acceptance C would catch, correctly, as a change to the
// document.
//
// Reads a job file, writes JSON to stdout, exits non-zero if any case failed.

const fs = require('fs');
const { chromium } = require('playwright');

const VIEWPORT = { width: 1280, height: 900 };
const DEVICE_SCALE_FACTOR = 1;
const SETTLE_MS = 500;
const READY_TIMEOUT_MS = 15000;

// Probe points, in order, as fractions of the canvas box. A one-node payload
// fits to the centre, so the first point is nearly always the hit; the rest are
// a scan for the case where layout puts it elsewhere. Scanning rather than
// asking the page where its nodes are, for the reason in the header.
const PROBE_POINTS = [
  [0.5, 0.5], [0.5, 0.42], [0.5, 0.58], [0.42, 0.5], [0.58, 0.5],
  [0.5, 0.35], [0.5, 0.65], [0.35, 0.5], [0.65, 0.5]
];

// Where a backend's canvas is, what opens a node's actions on it, and where
// those actions land. Named by the JOB rather than assumed here: this file
// drives more than one backend now, and a selector written into the harness
// would be a second place a backend's shape is stated - the design bug the
// Smoke block exists to avoid. The defaults are cytoscape's, so a job written
// before this file grew the fields behaves exactly as it did.
const DEFAULTS = { canvas: '#cy', menu: '#node-menu', button: 'right', ready: '#cy canvas' };

function selectorsFor(job) {
  return {
    canvas: job.canvas || DEFAULTS.canvas,
    menu: job.menu || DEFAULTS.menu,
    button: job.button || DEFAULTS.button,
    ready: job.ready || DEFAULTS.ready
  };
}

async function openNodeMenu(page, sel) {
  const box = await (await page.$(sel.canvas)).boundingBox();

  for (const [fx, fy] of PROBE_POINTS) {
    await page.mouse.click(box.x + box.width * fx, box.y + box.height * fy, { button: sel.button });
    await page.waitForTimeout(120);

    const count = await page.$$eval(sel.menu + ' > *', els => els.length);
    if (count > 0) { return true; }
  }
  return false;
}

// Every item the menu offers, as data. Anchors and buttons are different
// elements on purpose - the registry renders a real link for anything that
// hands a URI to another application - so both are reported.
async function readMenu(page, sel) {
  return page.$$eval(sel.menu + ' > *', els => els.map(el => ({
    tag: el.tagName.toLowerCase(),
    text: (el.textContent || '').trim(),
    // getAttribute, not .href: the property resolves relative URLs against the
    // document, which would turn an unresolved template into a file:// URL and
    // hide exactly the bug this is looking for.
    href: el.getAttribute('href'),
    disabled: el.disabled === true
  })));
}

async function runCase(browser, job) {
  const context = await browser.newContext({ viewport: VIEWPORT, deviceScaleFactor: DEVICE_SCALE_FACTOR });

  // Same rule as smoke.cjs: the network is blocked by host, not by setOffline,
  // because the document under test IS a file://.
  const attempted = [];
  await context.route('http://**', route => { attempted.push(route.request().url()); route.abort(); });
  await context.route('https://**', route => { attempted.push(route.request().url()); route.abort(); });

  const page = await context.newPage();
  const errors = [];
  const dialogs = [];
  page.on('console', m => { if (m.type() === 'error') { errors.push(m.text()); } });
  page.on('pageerror', e => errors.push('uncaught: ' + e.message));
  // An injected payload that executes announces itself here. Accepting rather
  // than ignoring, so a hung dialog cannot be mistaken for a passing case.
  page.on('dialog', async d => { dialogs.push(d.message()); await d.dismiss(); });

  const sel = selectorsFor(job);
  const result = { case: job.id, ok: false, message: '', menu: [], dialogs, errors };

  try {
    await page.goto('file:///' + job.file.replace(/\\/g, '/'), { waitUntil: 'load', timeout: READY_TIMEOUT_MS });
    await page.waitForSelector(sel.ready, { timeout: READY_TIMEOUT_MS });
    // A force simulation is still moving when the canvas first exists, so a
    // fixed settle is not enough for every backend. The job may ask for longer;
    // the default is the one cytoscape has always used.
    await page.waitForTimeout(job.settle || SETTLE_MS);

    const opened = await openNodeMenu(page, sel);
    if (!opened) {
      result.message = 'no node menu opened at any probe point - the payload drew no reachable node';
      return result;
    }

    result.menu = await readMenu(page, sel);
    const anchors = result.menu.filter(m => m.tag === 'a');
    const hrefs = anchors.map(m => m.href).filter(Boolean);
    result.hrefs = hrefs;

    if (job.expect === 'none') {
      // SC4. "The action absent, not stubbed" - so a DISABLED editor item is a
      // failure here too, not a pass.
      if (anchors.length > 0) {
        result.message = `expected no link action, found ${anchors.length}: ${hrefs.join(', ')}`;
        return result;
      }
      const named = result.menu.filter(m => /editor link|file location|call site/i.test(m.text));
      if (named.length > 0) {
        result.message = `expected no editor action, found: ${named.map(n => n.text).join(' | ')}`;
        return result;
      }
      if (result.menu.length === 0) {
        result.message = 'the menu opened empty - none mode must remove the link actions, not the menu';
        return result;
      }
    }
    else if (job.expect === 'prefix') {
      if (hrefs.length === 0) {
        result.message = 'expected a link action, found none';
        return result;
      }
      const bad = hrefs.filter(h => h.indexOf(job.prefix) !== 0);
      if (bad.length > 0) {
        result.message = `expected every href to start with ${job.prefix}, got: ${bad.join(', ')}`;
        return result;
      }
      // An unresolved token means the template shipped but nothing filled it.
      const unresolved = hrefs.filter(h => /\{[a-zA-Z]+\}/.test(h));
      if (unresolved.length > 0) {
        result.message = `href carries an unresolved token: ${unresolved.join(', ')}`;
        return result;
      }
    }

    if (job.forbidInHref) {
      // SC3. A resolved URL reaches the DOM as an attribute VALUE; if the raw
      // angle bracket or quote survives into it, the encoding step is not
      // running and a label is one step from being markup.
      const leaked = hrefs.filter(h => job.forbidInHref.some(ch => h.indexOf(ch) >= 0));
      if (leaked.length > 0) {
        result.message = `href carries an unencoded character: ${leaked.join(', ')}`;
        return result;
      }
    }

    if (dialogs.length > 0) {
      result.message = `script executed from payload or template: ${dialogs.join(' | ')}`;
      return result;
    }
    if (attempted.length > 0) {
      result.message = `the page attempted a network request: ${attempted.join(', ')}`;
      return result;
    }

    result.ok = true;
  }
  catch (err) {
    result.message = err.message;
  }
  finally {
    await context.close();
  }

  return result;
}

(async () => {
  const jobPath = process.argv[2];
  if (!jobPath) {
    console.error('usage: node link-mode.cjs <job.json>');
    process.exit(2);
  }

  const jobs = JSON.parse(fs.readFileSync(jobPath, 'utf8'));
  const browser = await chromium.launch();
  const results = [];

  try {
    for (const job of jobs) {
      results.push(await runCase(browser, job));
    }
  }
  finally {
    await browser.close();
  }

  console.log(JSON.stringify({ viewport: VIEWPORT, results }, null, 2));
  process.exit(results.every(r => r.ok) ? 0 : 1);
})();
