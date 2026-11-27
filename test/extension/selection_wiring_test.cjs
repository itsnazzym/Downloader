const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = (f) => fs.readFileSync(path.join(__dirname, '../../extension/shared', f), 'utf8');
const panel = read('feed_panel.js');

test('feed_panel no longer owns a selectedIds set', () => {
  assert.equal(/selectedIds/.test(panel), false);
  assert.match(panel, /MDSelection\.create\(\)/);
});

test('drag gestures use pointer events and hit-testing', () => {
  for (const token of ['pointerdown', 'pointermove', 'elementFromPoint', 'pointerup', 'pointercancel', "'blur'", 'pressStart', 'pressEnter', 'pressEnd', 'sel.range']) {
    assert.ok(panel.includes(token), 'feed_panel.js missing ' + token);
  }
});

test('css and html support the gestures', () => {
  assert.match(read('feed_panel.css'), /touch-action:\s*pan-y/);
  assert.match(read('feed_panel.css'), /is-selecting/);
  const html = read('feed_panel.html');
  assert.ok(html.indexOf('selection.js') > -1);
  assert.ok(html.indexOf('selection.js') < html.indexOf('feed_panel.js'));
});

test('release decision goes through MDSelection.releaseAction', () => {
  assert.match(panel, /MDSelection\.releaseAction\(/);
});

test('click after a drag is swallowed in the capture phase, and thumbnail/title can start a drag', () => {
  assert.match(panel, /MDSelection\.shouldSwallowClick\(/);
  assert.match(panel, /\}, true\);\s*\n\s*feedList\.addEventListener\('keydown'/);
  assert.equal(/select, textarea, \.thumbnail-container/.test(panel), false);
});

test('pointerdown resets gestureMoved before its first early return', () => {
  const start = panel.indexOf("feedList.addEventListener('pointerdown'");
  const end = panel.indexOf("window.addEventListener('pointermove'", start);
  assert.ok(start > -1 && end > start);
  const handler = panel.slice(start, end);
  const reset = handler.indexOf('gestureMoved = false');
  const firstReturn = handler.indexOf('return');
  assert.ok(reset > -1 && firstReturn > -1);
  assert.ok(reset < firstReturn, 'gestureMoved reset must precede the first return');
});
