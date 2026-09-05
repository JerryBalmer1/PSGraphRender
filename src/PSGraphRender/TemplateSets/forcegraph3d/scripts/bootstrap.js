const DATA = /*__DATA__*/ null;
const META = /*__META__*/ null;
const CONFIG = /*__CONFIG__*/ null;
const STRINGS = /*__STRINGS__*/ null;

(function () {
    'use strict';

    var meta = META || {};

    // The library is embedded in this document, so a missing global is not a
    // network failure - it is an assembly failure, and the page says which
    // rather than going blank. A vendored file no slot names never reaches the
    // document, which is exactly the shape of mistake this catches.
    if (typeof ForceGraph3D === 'undefined') {
        showNotice(str('LibraryMissing'));
        return;
    }

    // Opened as a raw template rather than a generated report: the payload
    // markers are still the literal null the substitution would have replaced.
    if (!DATA) {
        showNotice(str('TemplateNotice'));
        return;
    }

    function showNotice(text) {
        var notice = document.getElementById('fg-notice');
        // textContent, never innerHTML. Every string on this page is text.
        notice.textContent = text;
        notice.hidden = false;
    }

    // Starting values come from this template set's Config/, substituted above.
    // PowerShell validates and fills every key before it gets here, so these
    // fallbacks are only ever reached by someone opening the raw template -
    // which bails out earlier anyway. They exist so a missing key can never
    // yield NaN and silently collapse the view.
    function cfgNumber(key, fallback) {
        var value = CONFIG ? CONFIG[key] : null;
        return typeof value === 'number' && isFinite(value) ? value : fallback;
    }

    function cfgText(key, fallback) {
        var value = CONFIG ? CONFIG[key] : null;
        return typeof value === 'string' ? value : fallback;
    }

    // Strictly a boolean, never a truthiness test. PowerShell writes $true and
    // $false into CONFIG as JSON booleans, so anything else here is a key that
    // did not arrive - and `!!undefined` would silently answer "false" for a
    // setting whose declared default is true.
    function cfgBool(key, fallback) {
        var value = CONFIG ? CONFIG[key] : null;
        return typeof value === 'boolean' ? value : fallback;
    }

    function str(key, fallback) {
        var value = STRINGS && STRINGS[key];
        return typeof value === 'string' ? value : (fallback !== undefined ? fallback : key);
    }

    // A token nobody filled stays as written rather than collapsing to nothing,
    // so the gap shows up instead of reading as an empty label.
    function fmt(key, values, fallback) {
        var text = str(key, fallback);
        for (var name in values) {
            if (Object.prototype.hasOwnProperty.call(values, name)) {
                text = text.split('{' + name + '}').join(String(values[name]));
            }
        }
        return text;
    }

    // Appearance reaches CSS as custom properties, so a theme change is a data
    // change and this file needs no list of theme keys. A key list here would
    // mean adding a colour is a code edit, which is the one thing the config
    // split exists to prevent.
    //
    // Behaviour settings land here too, harmlessly: they are set through the
    // CSSOM rather than written into a stylesheet, so a value CSS cannot parse
    // is ignored and nothing a producer or a template supplies can become
    // markup. Numbers go out bare and the stylesheet multiplies them by a unit,
    // because a length is a number in Config and a number is not a length.
    for (var key in CONFIG || {}) {
        if (Object.prototype.hasOwnProperty.call(CONFIG, key)) {
            var value = CONFIG[key];
            if ((typeof value === 'string' && value) || typeof value === 'number') {
                document.documentElement.style.setProperty('--' + key, String(value));
            }
        }
    }

    var nodes = (DATA.nodes || []).slice();
    var links = (DATA.links || []).slice();

/*__SLOT_SCRIPT_NODE_LINK__*/
/*__SLOT_SCRIPT_ACTIONS__*/
/*__SLOT_SCRIPT_SHAPES__*/
/*__SLOT_SCRIPT_SCENE__*/
/*__SLOT_SCRIPT_GRAPH__*/
/*__SLOT_SCRIPT_LABELS__*/
/*__SLOT_SCRIPT_PANEL__*/

    // Everything above declares; this runs. Order matters twice now. The item
    // panel has to exist before a click can fill it, and the CONTROL panel
    // has to be built after the drawing: its classification filters are one
    // row per kind the payload carries, and nothing knows what those are
    // until the graph has been laid out.
    fillStatus();
    drawGraph();
    panelReady();
}());
