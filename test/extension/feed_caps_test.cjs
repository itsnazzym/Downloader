'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = (f) => fs.readFileSync(path.join(__dirname, '../../extension/shared', f), 'utf8').replace(/\r\n/g, '\n');
const num = (src, name) => Number(new RegExp('var ' + name + ' = (\\d+);').exec(src)[1]);

test('the page cache never holds more than the panel keeps after an eviction', () => {
  // A larger page cache would re-send evicted items, which the panel admits again with a fresh seq.
  const max = num(read('feed_panel.js'), 'MAX_ITEMS');
  assert.ok(num(read('content.js'), 'X_FEED_CACHE_LIMIT') <= Math.floor(max * 0.9));
});

test('the truncated hint stays once the panel store has evicted items', () => {
  const panel = read('feed_panel.js');
  assert.match(panel, /if \(opts\.truncated \|\| store\.evicted\(\) > 0\)/);
  assert.equal(/store\.size\(\) >= MAX_ITEMS/.test(panel), false);
});
