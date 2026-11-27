const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const shared = path.join(__dirname, '../../extension/shared');
const source = fs.readFileSync(path.join(shared, 'feed_panel.js'), 'utf8').replace(/\r\n/g, '\n');
const html = fs.readFileSync(path.join(shared, 'feed_panel.html'), 'utf8').replace(/\r\n/g, '\n');

// Body of `function name(...) { ... }` up to the next top-level (2-space) function.
function body(name) {
  const m = source.match(new RegExp(String.raw`\n  function ${name}\([^)]*\) \{([\s\S]*?)\n  \}\n`));
  assert.ok(m, name + ' not found');
  return m[1];
}

test('feedItems array is gone: all reads and writes go through the store', () => {
  assert.doesNotMatch(source, /\bfeedItems\b/);
  assert.match(source, /MDFeedStore\.create\(/);
  assert.match(source, /feedOrder\s*=\s*'flux'/);
});

test('mergeItems is a thin wrapper over store.merge', () => {
  assert.match(body('mergeItems'), /store\.merge\(normalizeItems\(/);
  assert.doesNotMatch(body('mergeItems'), /\.push\(|\[existingIndex\]/);
});

test('displayed items come from store.list(feedOrder)', () => {
  assert.match(source, /store\.list\(feedOrder\)/);
});

test('renderItems moves existing cards with domMoves instead of only appending', () => {
  const render = body('renderItems');
  assert.match(render, /MDFeedStore\.domMoves\(/);
  assert.match(render, /insertBefore\(/);
  assert.match(render, /loadMoreButton/);
});

test('the chip resets lastSeenSeq from the store on click', () => {
  assert.match(source, /lastSeenSeq\s*=\s*store\.lastSeq\(\)/);
  assert.match(source, /MDFeedStore\.countNewSince\(filtered \|\| filteredItems\(\), lastSeenSeq\)/);
});

test('order toggle and new-videos chip exist in the panel html and are wired', () => {
  assert.match(html, /id="feed-order-btn"/);
  assert.match(html, /id="new-videos-chip"/);
  assert.match(source, /getElementById\('feed-order-btn'\)/);
  assert.match(source, /getElementById\('new-videos-chip'\)/);
});

test('every new i18n key exists in fr, en and ar', () => {
  for (const lang of ['fr', 'en', 'ar']) {
    const messages = JSON.parse(fs.readFileSync(path.join(shared, '_locales', lang, 'messages.json'), 'utf8').replace(/\r\n/g, '\n'));
    for (const key of ['feedOrderFlux', 'feedOrderRecent', 'feedNewVideos']) {
      assert.ok(messages[key] && messages[key].message, lang + ' lacks ' + key);
    }
    assert.match(messages.feedNewVideos.message, /\{count\}/);
  }
});

// Runs the panel's own updateNewVideosChip against a fake store and chip.
function chipHarness() {
  const ctx = { MDFeedStore: undefined, console };
  ctx.self = ctx;
  vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(path.join(shared, 'feed_store.js'), 'utf8').replace(/\r\n/g, '\n'), ctx);
  const fn = source.match(/\n  function updateNewVideosChip\(filtered\) \{[\s\S]*?\n  \}\n/)[0];
  vm.runInContext(
    'var newVideosChip = { hidden: true, textContent: "" }; var currentViewMode = "videos"; var scrolledAway = false;' +
    'var lastSeenSeq = 0; var feedWasReset = false; var seq = 0; var size = 0; var shown = [];' +
    'var store = { size: function () { return size; }, lastSeq: function () { return seq; } };' +
    'function filteredItems() { return shown; }' +
    'function tf(k, d, v) { return d.replace("{count}", v.count); }' + fn, ctx);
  return ctx;
}
const seqs = (...n) => n.map((seq) => ({ seq }));

test('the new-videos chip counts only the items that pass the active filter', () => {
  const c = chipHarness();
  vm.runInContext('seq = 10; size = 10; scrolledAway = true; lastSeenSeq = 4; shown = ' + JSON.stringify(seqs(5, 6, 1)) + ';', c);
  vm.runInContext('updateNewVideosChip();', c);
  assert.equal(vm.runInContext('newVideosChip.hidden', c), false);
  assert.match(vm.runInContext('newVideosChip.textContent', c), /^2 /); // 4 of the 6 stored items are new, 2 are visible
  // a filtered list with nothing new hides the chip, and so does the sniffed view (no seq)
  vm.runInContext('updateNewVideosChip(' + JSON.stringify(seqs(1, 2)) + ');', c);
  assert.equal(vm.runInContext('newVideosChip.hidden', c), true);
  vm.runInContext('updateNewVideosChip([{ id: "s1" }]);', c);
  assert.equal(vm.runInContext('newVideosChip.hidden', c), true);
});

test('after a reset the first items are the baseline, so no false "N new" flood', () => {
  const c = chipHarness();
  vm.runInContext('scrolledAway = true; feedWasReset = true; seq = 0; size = 0; lastSeenSeq = 0;', c);
  vm.runInContext('updateNewVideosChip([]);', c); // empty store: wait for the first items
  assert.equal(vm.runInContext('feedWasReset', c), true);
  vm.runInContext('seq = 50; size = 50;', c);
  vm.runInContext('updateNewVideosChip(' + JSON.stringify(seqs(1, 2, 3)) + ');', c);
  assert.equal(vm.runInContext('newVideosChip.hidden', c), true);
  assert.equal(vm.runInContext('lastSeenSeq', c), 50);
  // later arrivals while scrolled away count again
  vm.runInContext('seq = 53; size = 53;', c);
  vm.runInContext('updateNewVideosChip(' + JSON.stringify(seqs(51, 52, 53)) + ');', c);
  assert.equal(vm.runInContext('newVideosChip.hidden', c), false);
  assert.match(source, /function resetFeed\(\) \{\s*store\.clear\(\);\s*lastSeenSeq = 0;\s*feedWasReset = true;/);
});

test('"scrolled away" is measured on the list (first card), not on the whole panel scrollTop', () => {
  assert.match(source, /function listScrolledAway\(\)/);
  assert.match(source, /scrollHost\.getBoundingClientRect\(\)\.top - el\.getBoundingClientRect\(\)\.top > 48/);
  assert.match(source, /var away = listScrolledAway\(\);/);
  assert.doesNotMatch(source, /scrollHost\.scrollTop > 48/);
});
