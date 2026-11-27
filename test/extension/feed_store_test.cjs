const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/feed_store.js'), 'utf8');

function load() {
  const context = {};
  context.self = context;
  vm.createContext(context);
  vm.runInContext(source, context);
  return context.MDFeedStore;
}

const it = (id, extra) => Object.assign({ id, url: 'https://x.com/' + id, title: 'T ' + id }, extra);
const batch = (...ids) => ids.map((id) => it(id));
const ids = (store, order) => Array.from(store.list(order || 'flux'), (i) => i.id);

test('a known item keeps its place and new items are appended', () => {
  const s = load().create();
  s.merge(batch('a', 'b', 'c'), 'dom');
  const r = s.merge(batch('b', 'c', 'd'), 'dom');
  assert.deepEqual(ids(s), ['a', 'b', 'c', 'd']);
  assert.equal(r.added, 1);
});

test('a new item is inserted right before the first known item that follows it', () => {
  const s = load().create();
  s.merge(batch('a', 'b', 'c'), 'dom');
  s.merge(batch('x', 'a'), 'dom');
  assert.deepEqual(ids(s), ['x', 'a', 'b', 'c']);
});

test('a new item with no known follower goes right after the last known predecessor', () => {
  const s = load().create();
  s.merge(batch('a', 'b', 'c'), 'dom');
  s.merge(batch('a', 'y'), 'dom');
  assert.deepEqual(ids(s), ['a', 'y', 'b', 'c']);
});

test('several new items between two known ones keep their batch order', () => {
  const s = load().create();
  s.merge(batch('a', 'b'), 'dom');
  s.merge(batch('a', 'p', 'q', 'b'), 'dom');
  assert.deepEqual(ids(s), ['a', 'p', 'q', 'b']);
});

test('a batch with no known neighbour is appended at the end', () => {
  const s = load().create();
  s.merge(batch('a', 'b'), 'dom');
  s.merge(batch('m', 'n'), 'dom');
  assert.deepEqual(ids(s), ['a', 'b', 'm', 'n']);
});

test('merging the same batch twice adds nothing and keeps the order', () => {
  const s = load().create();
  s.merge(batch('a', 'b', 'c'), 'dom');
  const r = s.merge(batch('a', 'b', 'c'), 'dom');
  assert.equal(r.added, 0);
  assert.equal(r.changed, 0);
  assert.deepEqual(ids(s), ['a', 'b', 'c']);
  assert.equal(s.size(), 3);
});

test('seq grows by one per new item, never changes, and recent is seq descending', () => {
  const s = load().create();
  s.merge(batch('a', 'b', 'c'), 'dom');
  assert.deepEqual(Array.from(s.list('flux'), (i) => i.seq), [1, 2, 3]);
  s.merge(batch('x', 'a', 'd'), 'dom');
  assert.equal(s.get('a').seq, 1);
  assert.equal(s.get('x').seq, 4);
  assert.equal(s.get('d').seq, 5);
  assert.equal(s.lastSeq(), 5);
  assert.deepEqual(ids(s, 'recent'), ['d', 'x', 'c', 'b', 'a']);
  assert.equal(s.newSince(3), 2);
  assert.equal(s.newSince(5), 0);
});

test('a numeric title is replaced by a real title on the next merge', () => {
  const s = load().create();
  s.merge([it('a', { title: '123' })], 'dom');
  const r = s.merge([it('a', { title: 'Real title' })], 'dom');
  assert.equal(s.get('a').title, 'Real title');
  assert.equal(r.changed, 1);
  s.merge([it('a', { title: 'Other' })], 'dom');
  assert.equal(s.get('a').title, 'Real title');
});

test('the gobird source wins over dom for url, pageUrl and source', () => {
  const s = load().create();
  s.merge([it('a', { url: 'https://dom/a', pageUrl: 'https://dom/p' })], 'dom');
  s.merge([it('a', { url: 'https://gobird/a', pageUrl: 'https://gobird/p' })], 'gobird');
  assert.equal(s.get('a').url, 'https://gobird/a');
  assert.equal(s.get('a').pageUrl, 'https://gobird/p');
  assert.equal(s.get('a').source, 'gobird');
  s.merge([it('a', { url: 'https://dom/again' })], 'dom');
  assert.equal(s.get('a').url, 'https://gobird/a');
});

test('thumbnail and videoSrc prefer incoming, duration prefers existing', () => {
  const s = load().create();
  s.merge([it('a', { thumbnailUrl: 't1', videoSrc: 'v1', durationSeconds: 10 })], 'dom');
  s.merge([it('a', { thumbnailUrl: 't2', videoSrc: 'v2', durationSeconds: 99 })], 'dom');
  const a = s.get('a');
  assert.equal(a.thumbnailUrl, 't2');
  assert.equal(a.videoSrc, 'v2');
  assert.equal(a.durationSeconds, 10);
});

test('an empty batch is a no-op', () => {
  const s = load().create();
  s.merge(batch('a'), 'dom');
  const r = s.merge([], 'dom');
  assert.deepEqual({ added: r.added, changed: r.changed }, { added: 0, changed: 0 });
  assert.deepEqual(ids(s), ['a']);
});

test('duplicate ids inside one batch are added once', () => {
  const s = load().create();
  const r = s.merge(batch('a', 'b', 'a', 'b'), 'dom');
  assert.equal(r.added, 2);
  assert.deepEqual(ids(s), ['a', 'b']);
  assert.equal(s.lastSeq(), 2);
});

test('clear empties the store and resets seq', () => {
  const s = load().create();
  s.merge(batch('a', 'b'), 'dom');
  s.clear();
  assert.equal(s.size(), 0);
  assert.equal(s.lastSeq(), 0);
  assert.equal(s.get('a'), undefined);
});

test('5000 items merged in batches of 50 take under 500 ms', () => {
  const s = load().create();
  const t0 = Date.now();
  for (let i = 0; i < 5000; i += 50) {
    const b = [];
    for (let j = 0; j < 50; j++) b.push(it('id' + (i + j)));
    s.merge(b, 'dom');
  }
  assert.equal(s.size(), 5000);
  assert.ok(Date.now() - t0 < 500, 'took ' + (Date.now() - t0) + ' ms');
});

// Applies domMoves to a plain array the way insertBefore would.
function applyMoves(current, moves) {
  const arr = current.slice();
  for (const m of moves) {
    arr.splice(arr.indexOf(m.id), 1);
    arr.splice(m.beforeId === null ? arr.length : arr.indexOf(m.beforeId), 0, m.id);
  }
  return arr;
}
const moves = (cur, tgt) => Array.from(load().domMoves(cur, tgt), (m) => ({ id: m.id, beforeId: m.beforeId }));

test('domMoves: identical order needs no move', () => {
  assert.deepEqual(moves(['a', 'b', 'c'], ['a', 'b', 'c']), []);
});

test('domMoves: one item moved up costs a single move', () => {
  const m = moves(['a', 'b', 'c', 'd'], ['a', 'd', 'b', 'c']);
  assert.deepEqual(m, [{ id: 'd', beforeId: 'b' }]);
});

test('domMoves: a new card appended at the end is moved to the top with one move', () => {
  const m = moves(['a', 'b', 'c', 'x'], ['x', 'a', 'b', 'c']);
  assert.deepEqual(m, [{ id: 'x', beforeId: 'a' }]);
});

test('domMoves: a reversed list ends in the target order', () => {
  const cur = ['a', 'b', 'c', 'd', 'e'];
  const tgt = ['e', 'd', 'c', 'b', 'a'];
  const m = moves(cur, tgt);
  assert.equal(m.length, 4);
  assert.deepEqual(applyMoves(cur, m), tgt);
});

test('domMoves: an item sent to the very end uses beforeId null', () => {
  const m = moves(['a', 'b', 'c'], ['b', 'c', 'a']);
  assert.deepEqual(m, [{ id: 'a', beforeId: null }]);
});

test('domMoves: ids missing from either list are ignored', () => {
  const cur = ['a', 'gone', 'b', 'c'];
  const tgt = ['c', 'a', 'fresh', 'b'];
  const m = moves(cur, tgt);
  assert.ok(m.every((x) => x.id !== 'gone' && x.id !== 'fresh' && x.beforeId !== 'gone' && x.beforeId !== 'fresh'));
  assert.deepEqual(applyMoves(cur, m).filter((id) => id !== 'gone'), ['c', 'a', 'b']);
});

test('remove drops an item and its order slot', () => {
  const s = load().create();
  s.merge(batch('a', 'b', 'c'), 'dom');
  s.remove('b');
  assert.deepEqual(ids(s), ['a', 'c']);
  assert.equal(s.size(), 2);
  assert.equal(s.get('b'), undefined);
  s.remove('nope');
  assert.equal(s.size(), 2);
});

test('countNewSince counts only the items of the given (filtered) list that arrived later', () => {
  const lib = load();
  const s = lib.create();
  s.merge([it('a', { platform: 'x' }), it('b', { platform: 'tiktok' }), it('c', { platform: 'x' })], 'dom');
  const all = s.list('flux');
  assert.equal(lib.countNewSince(all, 1), 2);
  // only the X posts pass the active filter: b is not a "new video" for this list
  assert.equal(lib.countNewSince(all.filter((i) => i.platform === 'x'), 1), 1);
  assert.equal(lib.countNewSince(all, 3), 0);
  assert.equal(lib.countNewSince([], 0), 0);
  // synthetic items (sniffed streams) have no seq and never count
  assert.equal(lib.countNewSince([{ id: 's1' }, { id: 's2' }], 0), 0);
});

test('a capped store drops the earliest detected items and keeps order and seq intact', () => {
  const s = load().create(100);
  for (let i = 0; i < 100; i += 10) s.merge(Array.from({ length: 10 }, (_, j) => it('id' + (i + j))), 'dom');
  assert.equal(s.size(), 100);
  s.merge([it('late1'), it('late2')], 'dom');
  // over the cap: back down to 90 items, the 12 earliest detections are gone
  assert.equal(s.size(), 90);
  assert.equal(s.get('id0'), undefined);
  assert.equal(s.get('id11'), undefined);
  assert.ok(s.get('id12') && s.get('late2'));
  assert.deepEqual(ids(s).slice(-3), ['id99', 'late1', 'late2']);
  assert.equal(s.lastSeq(), 102);
  assert.equal(s.newSince(100), 2);
  // an uncapped store never evicts
  const u = load().create();
  u.merge(Array.from({ length: 300 }, (_, i) => it('u' + i)), 'dom');
  assert.equal(u.size(), 300);
});
