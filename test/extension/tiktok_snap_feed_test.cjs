const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/content.js'), 'utf8').replace(/\r\n/g, '\n');
const start = source.indexOf('  function isElementDisplayed(el) {');
const end = source.indexOf('  function scrollAllFeedContainers(amount) {', start);
assert.ok(start >= 0 && end > start, 'snap feed implementation is available');
const implementation = source.slice(start, end);

function loadAdvance(document, window) {
  const context = { document, window, findScrollableAncestor: () => null };
  vm.createContext(context);
  vm.runInContext(implementation + '\nthis.advance = advanceTikTokSnapFeed;', context);
  return context.advance;
}

test('For You advances using TikTok next-video control', () => {
  let clicked = 0;
  const button = {
    nodeType: 1,
    getAttribute: () => '',
    textContent: '',
    click() { clicked++; },
  };
  const arrow = { closest: () => button };
  const document = {
    querySelector: () => null,
    querySelectorAll: () => [arrow],
  };
  const window = { getComputedStyle: () => ({ display: 'block', visibility: 'visible' }) };
  assert.equal(loadAdvance(document, window)(), true);
  assert.equal(clicked, 1);
});

test('For You advances its snap scroller when no next control exists', () => {
  const body = {};
  const scroller = {
    nodeType: 1,
    parentElement: body,
    scrollHeight: 1800,
    clientHeight: 600,
    scrollTop: 0,
    getBoundingClientRect: () => ({ height: 600 }),
    scrollBy({ top }) { this.scrollTop += top; },
  };
  const video = { parentElement: scroller };
  const document = {
    body,
    documentElement: {},
    querySelector: (selector) => selector === 'video' ? video : null,
    querySelectorAll: () => [],
  };
  const window = {
    innerHeight: 600,
    getComputedStyle: (element) => element === scroller
      ? { overflowY: 'hidden', scrollSnapType: 'y mandatory' }
      : { display: 'block', visibility: 'visible' },
  };
  assert.equal(loadAdvance(document, window)(), true);
  assert.equal(scroller.scrollTop, 600);
});

test('For You reports unavailable navigation instead of pretending to scroll', () => {
  const document = {
    body: {},
    documentElement: {},
    scrollingElement: null,
    querySelector: () => null,
    querySelectorAll: () => [],
  };
  const window = { innerHeight: 600, getComputedStyle: () => ({ display: 'block', visibility: 'visible' }) };
  assert.equal(loadAdvance(document, window)(), false);
});
