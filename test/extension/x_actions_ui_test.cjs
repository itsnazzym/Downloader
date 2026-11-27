const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

// Harness choice: feed_panel.js is one big DOM-bound IIFE, so the decision logic
// lives in the small DOM-free module x_actions_ui.js (everything injected) and is
// tested here directly; the DOM wiring in feed_panel.js / .html / .css is covered
// by structural source checks at the bottom.
const shared = path.join(__dirname, '../../extension/shared');
const read = (name) => fs.readFileSync(path.join(shared, name), 'utf8').replace(/\r\n/g, '\n');

function load(file, extra) {
  const context = Object.assign({ URL }, extra);
  context.self = context;
  vm.createContext(context);
  vm.runInContext(read(file), context);
  return context;
}
const UI = () => load('x_actions_ui.js').MDXActionsUi;
const Store = () => load('feed_store.js').MDFeedStore;
const tick = () => new Promise((resolve) => setImmediate(resolve));

const X_TAB = [{ id: 7, url: 'https://x.com/home' }];

function harness(overrides) {
  const h = {
    sent: [], statuses: [], refreshed: [], delays: [], confirms: 0,
    storage: {}, queries: 0, tabs: X_TAB, answer: { ok: true, code: 'ok' }, confirmAnswer: true,
    confirmGate: null,
  };
  const deps = {
    send(message) {
      h.sent.push(message);
      if (h.answer instanceof Error) return Promise.reject(h.answer);
      return Promise.resolve(h.answer);
    },
    storage: {
      get: async (keys) => { const out = {}; [].concat(keys).forEach((k) => { if (k in h.storage) out[k] = h.storage[k]; }); return out; },
      set: async (obj) => { Object.assign(h.storage, obj); },
    },
    confirmWarning() { h.confirms++; return h.confirmGate ? h.confirmGate : Promise.resolve(h.confirmAnswer); },
    t: (key, fallback) => fallback || key,
    setStatus: (message, state) => h.statuses.push({ message, state }),
    delay: (fn, ms) => h.delays.push({ fn, ms }),
    tabId: () => null,
    queryTabs: async () => { h.queries++; return h.tabs; },
    platform: (item) => item.platform,
    refresh: (item) => h.refreshed.push(item.id),
    now: () => h.clock || 0,
  };
  Object.assign(deps, overrides || {});
  h.ui = UI().create(deps);
  return h;
}

const xItem = (extra) => Object.assign({ id: '1900000000000000001', platform: 'x' }, extra);

test('first action opens the warning and sends nothing before Continuer', async () => {
  const h = harness();
  let release;
  h.confirmGate = new Promise((resolve) => { release = resolve; });
  const done = h.ui.perform(xItem(), 'FavoriteTweet');
  await tick();
  assert.equal(h.confirms, 1);
  assert.equal(h.sent.length, 0);
  release(true);
  await done;
  assert.equal(h.sent.length, 1);
  assert.deepEqual(JSON.parse(JSON.stringify(h.sent[0])), { type: 'MD_X_ACTION', op: 'FavoriteTweet', tweetId: '1900000000000000001' });
  assert.equal(h.storage.xActionsWarningAck, true);
});

test('Annuler sends nothing, stores nothing and resolves false', async () => {
  const h = harness();
  h.confirmAnswer = false;
  assert.equal(await h.ui.ensureAck(), false);
  await h.ui.perform(xItem(), 'FavoriteTweet');
  assert.equal(h.sent.length, 0);
  assert.equal('xActionsWarningAck' in h.storage, false);
});

test('once acknowledged, the next action shows no dialog and sends the message', async () => {
  const h = harness();
  h.storage.xActionsWarningAck = true;
  assert.equal(await h.ui.ensureAck(), true);
  await h.ui.perform(xItem(), 'CreateBookmark');
  assert.equal(h.confirms, 0);
  assert.equal(h.sent.length, 1);
});

test('the hooked tab id is forwarded only when there is one', async () => {
  const h = harness({ tabId: () => 42 });
  h.storage.xActionsWarningAck = true;
  await h.ui.perform(xItem(), 'FavoriteTweet');
  assert.equal(h.sent[0].tabId, 42);
});

test('no x.com tab: buttons are disabled with the xOpenXFirst title', async () => {
  const h = harness();
  h.tabs = [{ id: 1, url: 'https://example.com/' }, { id: 2, url: 'https://notx.com/' }];
  assert.equal(await h.ui.hasXTab(), false);
  const s = h.ui.buttonState(xItem(), 'like', false);
  assert.equal(s.disabled, true);
  assert.equal(s.title, 'Ouvrez x.com');
  h.tabs = [{ id: 3, url: 'https://mobile.twitter.com/a' }];
  h.ui.invalidateTabs();
  assert.equal(await h.ui.hasXTab(), true);
  const on = h.ui.buttonState(xItem(), 'like', true);
  assert.equal(on.disabled, false);
  assert.equal(on.title, 'J’aime sur X');
});

test('hasXTab is cached for 2 s and refreshed after invalidation', async () => {
  const h = harness();
  h.clock = 1000;
  await h.ui.hasXTab();
  h.clock = 2500;
  await h.ui.hasXTab();
  assert.equal(h.queries, 1);
  h.clock = 3100;
  await h.ui.hasXTab();
  assert.equal(h.queries, 2);
  h.ui.invalidateTabs();
  await h.ui.hasXTab();
  assert.equal(h.queries, 3);
});

test('buttons are hidden for other platforms and for ids that are not tweet ids', () => {
  const h = harness();
  assert.equal(h.ui.buttonState({ id: '1900000000000000001', platform: 'tiktok' }, 'like', true).hidden, true);
  assert.equal(h.ui.buttonState({ id: 'abc', platform: 'x' }, 'bookmark', true).hidden, true);
  assert.equal(h.ui.buttonState(xItem({ id: '1900000000000000001-video-2' }), 'like', true).hidden, false);
  assert.equal(h.ui.tweetIdOf(xItem({ id: '1900000000000000001-video-2' })), '1900000000000000001');
  assert.equal(h.ui.tweetIdOf(xItem({ tweetId: '55' })), '55');
  assert.equal(h.ui.tweetIdOf(xItem({ id: '1; drop' })), null);
});

test('toggle semantics: liked gives UnfavoriteTweet, bookmarked gives DeleteBookmark', async () => {
  const h = harness();
  h.storage.xActionsWarningAck = true;
  const item = xItem({ liked: true, bookmarked: true });
  assert.equal(h.ui.nextOp(item, 'like'), 'UnfavoriteTweet');
  assert.equal(h.ui.nextOp(item, 'bookmark'), 'DeleteBookmark');
  assert.equal(h.ui.nextOp(xItem(), 'like'), 'FavoriteTweet');
  assert.equal(h.ui.nextOp(xItem(), 'bookmark'), 'CreateBookmark');
  assert.equal(h.ui.buttonState(item, 'like', true).pressed, true);
  await h.ui.perform(item, 'UnfavoriteTweet');
  assert.equal(item.liked, false);
  assert.equal(item.bookmarked, true);
  assert.deepEqual(h.statuses.pop(), { message: 'Like retiré', state: 'success' });
  await h.ui.perform(item, 'DeleteBookmark');
  assert.equal(item.bookmarked, false);
  assert.equal(h.statuses.pop().message, 'Retiré des signets');
  await h.ui.perform(item, 'FavoriteTweet');
  assert.equal(item.liked, true);
  assert.equal(h.statuses.pop().message, 'Liké sur X');
  await h.ui.perform(item, 'CreateBookmark');
  assert.equal(item.bookmarked, true);
  assert.equal(h.statuses.pop().message, 'Ajouté aux signets X');
  assert.ok(h.refreshed.length >= 4);
});

test('code already counts as success', async () => {
  const h = harness();
  h.storage.xActionsWarningAck = true;
  h.answer = { ok: true, code: 'already' };
  const item = xItem();
  await h.ui.perform(item, 'FavoriteTweet');
  assert.equal(item.liked, true);
});

test('pending: the button is disabled while the request runs and no second call goes out', async () => {
  const h = harness();
  h.storage.xActionsWarningAck = true;
  let answer;
  h.ui = UI().create({
    send: (m) => { h.sent.push(m); return new Promise((r) => { answer = r; }); },
    storage: { get: async () => ({ xActionsWarningAck: true }), set: async () => {} },
    confirmWarning: async () => true, t: (k, f) => f, setStatus() {}, delay() {},
    tabId: () => null, queryTabs: async () => X_TAB, platform: (i) => i.platform, refresh() {}, now: () => 0,
  });
  const item = xItem();
  const first = h.ui.perform(item, 'FavoriteTweet');
  await tick();
  assert.equal(h.ui.buttonState(item, 'like', true).disabled, true);
  assert.equal(h.ui.buttonState(item, 'like', true).pending, true);
  assert.equal(h.ui.buttonState(item, 'bookmark', true).disabled, false);
  await h.ui.perform(item, 'FavoriteTweet');
  assert.equal(h.sent.length, 1);
  answer({ ok: true, code: 'ok' });
  await first;
  assert.equal(h.ui.buttonState(item, 'like', true).disabled, false);
});

test('rate: error status, and the button comes back after the injected 5 s delay', async () => {
  const h = harness();
  h.storage.xActionsWarningAck = true;
  h.answer = { ok: false, code: 'rate', message: 'Trop vite' };
  const item = xItem();
  await h.ui.perform(item, 'FavoriteTweet');
  assert.equal(h.statuses.at(-1).state, 'error');
  assert.match(h.statuses.at(-1).message, /X limite|limit/i);
  assert.equal(item.liked, undefined);
  assert.equal(h.delays.length, 1);
  assert.equal(h.delays[0].ms, 5000);
  assert.equal(h.ui.buttonState(item, 'like', true).disabled, true);
  h.delays[0].fn();
  assert.equal(h.ui.buttonState(item, 'like', true).disabled, false);
  assert.equal(h.refreshed.at(-1), item.id);
});

test('other codes map to their own short message and re-enable at once', async () => {
  const cases = { auth: 'Connectez-vous', stale: 'Rechargez', no_tab: 'Ouvrez x.com', unknown: 'impossible' };
  for (const [code, fragment] of Object.entries(cases)) {
    const h = harness();
    h.storage.xActionsWarningAck = true;
    h.answer = { ok: false, code };
    const item = xItem();
    await h.ui.perform(item, 'CreateBookmark');
    assert.equal(h.statuses.at(-1).state, 'error', code);
    assert.ok(h.statuses.at(-1).message.includes(fragment), code + ': ' + h.statuses.at(-1).message);
    assert.equal(h.delays.length, 0, code);
    assert.equal(h.ui.buttonState(item, 'bookmark', true).disabled, false, code);
    assert.equal(item.bookmarked, undefined, code);
  }
});

test('a rejected sendMessage or a forbidden reply gives the generic error and re-enables', async () => {
  for (const answer of [new Error('The message port closed'), { ok: false, error: 'forbidden' }, undefined]) {
    const h = harness();
    h.storage.xActionsWarningAck = true;
    h.answer = answer;
    const item = xItem();
    await h.ui.perform(item, 'FavoriteTweet');
    assert.equal(h.statuses.at(-1).state, 'error');
    assert.equal(h.statuses.at(-1).message, 'Action impossible pour le moment.');
    assert.equal(h.ui.buttonState(item, 'like', true).disabled, false);
    assert.equal(item.liked, undefined);
  }
});

test('an invalid platform, id or op sends nothing and does not even ask for the warning', async () => {
  const h = harness();
  await h.ui.perform({ id: '1900000000000000001', platform: 'tiktok' }, 'FavoriteTweet');
  await h.ui.perform(xItem({ id: 'nope' }), 'FavoriteTweet');
  await h.ui.perform(xItem(), 'DeleteTweet');
  assert.equal(h.sent.length, 0);
  assert.equal(h.confirms, 0);
});

test('liked/bookmarked survive a later store.merge of the same id', () => {
  const store = Store().create();
  const base = { id: '1900000000000000001', url: 'https://x.com/a/status/1900000000000000001', platform: 'x', title: 'T', author: 'a' };
  store.merge([base], 'dom');
  const stored = store.get(base.id);
  stored.liked = true;
  stored.bookmarked = true;
  store.merge([Object.assign({}, base, { title: 'T2', thumbnailUrl: 'https://pbs.twimg.com/a.jpg', isActive: true })], 'gobird');
  const after = store.get(base.id);
  assert.equal(after, stored);
  assert.equal(after.liked, true);
  assert.equal(after.bookmarked, true);
  assert.equal(after.thumbnailUrl, 'https://pbs.twimg.com/a.jpg');
});

// ---- Structure and wiring of the panel (DOM-bound code is not run here) ----

const html = read('feed_panel.html');
const panel = read('feed_panel.js');
const css = read('feed_panel.css');

test('warning dialog markup is an accessible modal with Annuler / Continuer', () => {
  const m = html.match(/<div id="x-warning-modal"[^>]*>/);
  assert.ok(m, 'x-warning-modal missing');
  assert.match(m[0], /role="dialog"/);
  assert.match(m[0], /aria-modal="true"/);
  assert.match(m[0], /aria-labelledby="x-warning-title"/);
  assert.match(m[0], /\bhidden\b/);
  for (const id of ['x-warning-title', 'x-warning-cancel', 'x-warning-continue']) {
    assert.match(html, new RegExp('id="' + id + '"'));
  }
  for (const key of ['xWarnTitle', 'xWarnBody', 'xWarnOnce', 'xWarnCancel', 'xWarnContinue']) {
    assert.match(html, new RegExp('data-i18n="' + key + '"'));
  }
  assert.ok(html.indexOf('x_actions_ui.js') > -1 && html.indexOf('x_actions_ui.js') < html.indexOf('feed_panel.js'));
});

test('feed_panel.js wires the dialog (Escape = cancel), the module and the card buttons', () => {
  assert.match(panel, /MDXActionsUi\.create\(/);
  assert.match(panel, /getElementById\('x-warning-cancel'\)/);
  assert.match(panel, /getElementById\('x-warning-continue'\)/);
  assert.match(panel, /xWarningModal/);
  assert.match(panel, /showDialog\(xWarningModal/);
  assert.match(panel, /Escape[\s\S]{0,400}xWarningModal|xWarningModal[\s\S]{0,400}Escape/);
  assert.match(panel, /function ensureXActionsAck\(/);
  assert.match(panel, /function performXAction\(/);
  assert.match(panel, /card-x-btn/);
  assert.match(panel, /xui\.buttonState\(/);
  assert.match(panel, /api\.tabs\.onRemoved/);
  assert.match(panel, /setTimeout\(fn, ms\)/);
  // The only place MD_X_ACTION is built is the module, behind the acknowledgement.
  assert.doesNotMatch(panel, /MD_X_ACTION/);
});

test('every new i18n key exists in fr, en and ar', () => {
  const keys = ['xLike', 'xUnlike', 'xBookmark', 'xUnbookmark', 'xOpenXFirst',
    'xLikedOk', 'xUnlikedOk', 'xBookmarkedOk', 'xUnbookmarkedOk',
    'xActionAuth', 'xActionRate', 'xActionStale', 'xActionNoTab', 'xActionFailed',
    'xStateLiked', 'xStateBookmarked',
    'xWarnTitle', 'xWarnBody', 'xWarnOnce', 'xWarnCancel', 'xWarnContinue'];
  for (const lang of ['fr', 'en', 'ar']) {
    const messages = JSON.parse(read('_locales/' + lang + '/messages.json'));
    for (const key of keys) {
      assert.ok(messages[key] && messages[key].message, lang + ' lacks ' + key);
    }
  }
  const fr = JSON.parse(read('_locales/fr/messages.json'));
  assert.equal(fr.xWarnTitle.message, 'Like et signets passent par votre session X');
  assert.equal(fr.xWarnOnce.message, 'Ce message ne s’affiche qu’une fois.');
});

test('the CSS added for X actions uses theme variables only (no hex colours)', () => {
  const lines = css.split(/\r?\n/).filter((line) => /card-x-|x-warning/.test(line));
  assert.ok(lines.length >= 6, 'expected X action rules in feed_panel.css');
  for (const line of lines) assert.doesNotMatch(line, /#[0-9a-fA-F]{3,8}\b|rgb\(/, line);
});
