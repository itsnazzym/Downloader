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
