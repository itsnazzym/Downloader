'use strict';
// CPU budgets for the panel's pure logic. They are about 3x what a laptop needs, so a slow CI
// runner passes while an accidental O(n^2) does not. The plain "5000 merged by 50" and
// "500 x 20 ingests" budgets live in feed_store_test.cjs and download_tracker_test.cjs.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function load(file, name) {
  const context = {};
  context.self = context;
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../../extension/shared', file), 'utf8'), context);
  return context[name];
}
const MDFeedStore = load('feed_store.js', 'MDFeedStore');
const MDDownloads = load('download_tracker.js', 'MDDownloads');
const MDSelection = load('selection.js', 'MDSelection');

const MB = 1024 * 1024;
const it = (i) => ({ id: 'id' + i, url: 'https://x.com/u/status/' + i, title: 'T ' + i });
const range = (from, to) => Array.from({ length: to - from }, (_, k) => it(from + k));
const ms = (fn) => {
  const t0 = process.hrtime.bigint();
  fn();
  return Number(process.hrtime.bigint() - t0) / 1e6;
};
const within = (budget, fn, label) => {
  const took = ms(fn);
  if (process.env.PERF_LOG) console.log(`${label}: ${took.toFixed(1)} ms`);
  assert.ok(took < budget, `${label}: ${took.toFixed(1)} ms >= ${budget} ms`);
};

test('re-merging overlapping windows of a virtualised timeline stays under 500 ms', () => {
  const s = MDFeedStore.create();
  s.merge(range(0, 5000), 'dom');
  within(500, () => {
    // The page keeps ~1000 posts in the DOM and slides that window down, then back up.
    for (let start = 0; start + 1000 <= 5000; start += 250) s.merge(range(start, start + 1000), 'dom');
    for (let start = 4000; start >= 0; start -= 250) s.merge(range(start, start + 1000), 'dom');
  }, '35 windows of 1000');
  assert.equal(s.size(), 5000);
  assert.deepEqual(Array.from(s.list('flux').slice(0, 3), (x) => x.id), ['id0', 'id1', 'id2']);
});

test('newSince and list on 5000 items are cheap', () => {
  const s = MDFeedStore.create();
  s.merge(range(0, 5000), 'dom');
  within(200, () => {
    for (let k = 0; k < 50; k++) { s.newSince(4000); s.list('recent'); }
  }, '50 x (newSince + list recent)');
});

test('domMoves on 5000 reversed ids stays under 200 ms and is a valid permutation', () => {
  const ids = Array.from({ length: 5000 }, (_, i) => 'id' + i);
  const target = ids.slice().reverse();
  let moves;
  within(200, () => { moves = MDFeedStore.domMoves(ids, target); }, 'domMoves reversed');
  const arr = ids.slice();
  for (const m of moves) {
    arr.splice(arr.indexOf(m.id), 1);
    arr.splice(m.beforeId === null ? arr.length : arr.indexOf(m.beforeId), 0, m.id);
  }
  assert.deepEqual(arr, target);
});

test('a download snapshot of 500 items, 20 times, plus the view diff stays under 200 ms', () => {
  const t = MDDownloads.create();
  const row = (i, u) => ({ id: 'd' + i, title: 'T' + i, url: 'https://x.com/u/status/' + i, tweetId: String(i), status: 2, progress: u / 20, speed: '1MiB/s', totalSize: 100 * MB, downloadedSize: u * MB });
  within(200, () => {
    let prev = [];
    for (let u = 1; u <= 20; u++) {
      t.ingestSnapshot(Array.from({ length: 500 }, (_, i) => row(i, u)), 1000 + u * 50);
      const next = t.groups().running.map((dl) => ({ id: dl.id, sig: 'running|' + dl.status }));
      MDDownloads.planRowUpdates(prev, next);
      prev = next;
      t.summary(1000 + u * 50);
    }
  }, '20 snapshots');
  assert.equal(t.summary(5000).running, 500);
});

test('looking up the 80 rendered cards among 500 live downloads, 20 ticks, stays under 200 ms', () => {
  const t = MDDownloads.create();
  for (let i = 0; i < 500; i++) {
    t.ingest({ id: 'd' + i, url: 'https://x.com/u/status/' + i, tweetId: String(i), status: 2, progress: 0.5, speed: '1MiB/s' }, 1);
  }
  within(200, () => {
    for (let tick = 0; tick < 20; tick++) {
      for (let c = 0; c < 80; c++) t.findByCardKey({ tweetId: String(c * 6), tikTokId: null, url: 'https://x.com/u/status/' + c * 6 });
    }
  }, '1600 card lookups');
});

test('selecting a range of 5000 ids, dragging across them and pruning stays under 200 ms', () => {
  const ordered = Array.from({ length: 5000 }, (_, i) => 'id' + i);
  const sel = MDSelection.create();
  within(200, () => {
    assert.equal(sel.range('id0', 'id4999', ordered).length, 5000);
    sel.clear();
    sel.pressStart('id0');
    sel.pressEnter('id1', ordered);
    sel.pressEnter('id4999', ordered);
    sel.pressEnd();
    sel.prune(ordered.slice(0, 2500));
  }, 'range + drag + prune');
  assert.equal(sel.size(), 2500);
});
