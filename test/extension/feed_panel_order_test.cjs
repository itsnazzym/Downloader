const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const shared = path.join(__dirname, '../../extension/shared');
const source = fs.readFileSync(path.join(shared, 'feed_panel.js'), 'utf8');
const html = fs.readFileSync(path.join(shared, 'feed_panel.html'), 'utf8');

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
  assert.match(source, /store\.newSince\(lastSeenSeq\)/);
});

test('order toggle and new-videos chip exist in the panel html and are wired', () => {
  assert.match(html, /id="feed-order-btn"/);
  assert.match(html, /id="new-videos-chip"/);
  assert.match(source, /getElementById\('feed-order-btn'\)/);
  assert.match(source, /getElementById\('new-videos-chip'\)/);
});

test('every new i18n key exists in fr, en and ar', () => {
  for (const lang of ['fr', 'en', 'ar']) {
    const messages = JSON.parse(fs.readFileSync(path.join(shared, '_locales', lang, 'messages.json'), 'utf8'));
    for (const key of ['feedOrderFlux', 'feedOrderRecent', 'feedNewVideos']) {
      assert.ok(messages[key] && messages[key].message, lang + ' lacks ' + key);
    }
    assert.match(messages.feedNewVideos.message, /\{count\}/);
  }
});
