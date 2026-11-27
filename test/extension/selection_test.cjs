const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/selection.js'), 'utf8');

function load() {
  const context = {};
  context.self = context;
  vm.createContext(context);
  vm.runInContext(source, context);
  return context.MDSelection;
}

const ORDER = ['a', 'b', 'c', 'd', 'e'];
const sorted = (sel) => Array.from(sel.ids()).sort();

test('dragging from card 1 to card 4 selects 1 to 4', () => {
  const s = load().create();
  s.pressStart('a', ORDER);
  assert.equal(s.isDragging(), false);
  s.pressEnter('b', ORDER);
  s.pressEnter('c', ORDER);
  s.pressEnter('d', ORDER);
  assert.deepEqual(sorted(s), ['a', 'b', 'c', 'd']);
  assert.equal(s.size(), 4);
});

test('starting on a selected card deselects the cards crossed', () => {
  const s = load().create();
  ORDER.forEach((id) => s.toggle(id));
  s.pressStart('b', ORDER);
  const changed = Array.from(s.pressEnter('d', ORDER)).sort();
  assert.deepEqual(changed, ['b', 'c', 'd']);
  assert.deepEqual(sorted(s), ['a', 'e']);
});

test('a click without drag changes nothing', () => {
  const s = load().create();
  s.pressStart('a', ORDER);
  assert.deepEqual(Array.from(s.pressEnter('a', ORDER)), []);
  s.pressEnd();
  assert.equal(s.size(), 0);
  assert.equal(s.isDragging(), false);
});

test('a jump from card 1 to card 5 selects every skipped card', () => {
  const s = load().create();
  s.pressStart('a', ORDER);
  s.pressEnter('e', ORDER);
  assert.deepEqual(sorted(s), ORDER);
});

test('going back over cards keeps applying the same mode', () => {
  const s = load().create();
  s.pressStart('b', ORDER);
  s.pressEnter('d', ORDER);
  s.pressEnter('a', ORDER);
  assert.deepEqual(sorted(s), ['a', 'b', 'c', 'd']);
});

test('pressEnd ends the drag and later enters do nothing', () => {
  const s = load().create();
  s.pressStart('a', ORDER);
  s.pressEnter('b', ORDER);
  assert.equal(s.isDragging(), true);
  s.pressEnd();
  assert.equal(s.isDragging(), false);
  assert.deepEqual(Array.from(s.pressEnter('d', ORDER)), []);
  assert.deepEqual(sorted(s), ['a', 'b']);
});

test('toggle returns the new state', () => {
  const s = load().create();
  assert.equal(s.toggle('a'), true);
  assert.equal(s.has('a'), true);
  assert.equal(s.toggle('a'), false);
  assert.equal(s.has('a'), false);
});

test('range returns the ids between two cards, in either direction', () => {
  const s = load().create();
  assert.deepEqual(Array.from(s.range('b', 'd', ORDER)), ['b', 'c', 'd']);
  assert.deepEqual(Array.from(s.range('d', 'b', ORDER)), ['b', 'c', 'd']);
  assert.deepEqual(sorted(s), ['b', 'c', 'd']);
});

test('range with an unknown id returns nothing', () => {
  const s = load().create();
  assert.deepEqual(Array.from(s.range('zz', 'd', ORDER)), []);
  assert.equal(s.size(), 0);
});

test('prune removes ids that are no longer visible', () => {
  const s = load().create();
  ['a', 'b', 'c'].forEach((id) => s.toggle(id));
  s.prune(['b', 'c', 'x']);
  assert.deepEqual(sorted(s), ['b', 'c']);
});

test('clear empties the selection', () => {
  const s = load().create();
  s.toggle('a');
  s.clear();
  assert.equal(s.size(), 0);
});

test('releaseAction: only an in-place touch long-press toggles', () => {
  const r = load().releaseAction;
  assert.equal(r({ pointerType: 'mouse', armed: true, dragging: false, moved: false }), 'none');
  assert.equal(r({ pointerType: 'mouse', armed: true, dragging: true, moved: true }), 'none');
  assert.equal(r({ pointerType: 'touch', armed: true, dragging: false, moved: false }), 'toggle');
  assert.equal(r({ pointerType: 'touch', armed: false, dragging: false, moved: false }), 'none');
  assert.equal(r({ pointerType: 'touch', armed: true, dragging: true, moved: true }), 'none');
});

test('shouldSwallowClick: only after a drag or a long-press toggle', () => {
  const f = load().shouldSwallowClick;
  assert.equal(f({ moved: false }), false);
  assert.equal(f({ moved: true }), true);
});
