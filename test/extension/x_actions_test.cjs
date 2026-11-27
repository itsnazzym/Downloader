const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const shared = path.join(__dirname, '../../extension/shared');
const read = (name) => fs.readFileSync(path.join(shared, name), 'utf8');
const plain = (v) => JSON.parse(JSON.stringify(v));

function load() {
  const context = {};
  context.self = context;
  vm.createContext(context);
  vm.runInContext(read('x_actions.js'), context);
  return context.MDXActions;
}

// Obviously fake: the real web-app bearer is read from X's bundle at runtime.
const BEARER = 'AAAAAAAAAAAAAAAAAAAAFAKEtestTOKEN%3Dfake0123456789';
const BUNDLE = [
  'e.exports={queryId:"fav111",operationName:"FavoriteTweet",operationType:"mutation",metadata:{}}',
  'e.exports={queryId:"folder999",operationName:"CreateBookmarkFolder",operationType:"mutation"}',
  "e.exports={ operationName : 'UnfavoriteTweet', queryId : 'unfav222', operationType:'mutation'}",
  'e.exports={queryId:"other000",operationName:"HomeTimeline"}',
  'e.exports={"queryId":"bm333","operationName":"CreateBookmark"}',
  'e.exports={queryId:"del444",operationName:"DeleteBookmark"}',
  'const t="Bearer",n="' + BEARER + '";',
].join(';');
const IDS = { FavoriteTweet: 'fav111', UnfavoriteTweet: 'unfav222', CreateBookmark: 'bm333', DeleteBookmark: 'del444', bearer: BEARER };

test('parseQueryIds reads the four operations and the bearer from a bundle', () => {
  assert.deepEqual(plain(load().parseQueryIds(BUNDLE)), IDS);
});

test('parseQueryIds leaves missing operations undefined', () => {
  const ids = load().parseQueryIds('queryId:"x1",operationName:"FavoriteTweet"; queryId:"f",operationName:"CreateBookmarkFolder"');
  assert.equal(ids.FavoriteTweet, 'x1');
  assert.equal(ids.CreateBookmark, undefined);
  assert.equal(ids.UnfavoriteTweet, undefined);
  assert.equal(ids.DeleteBookmark, undefined);
  assert.equal(ids.bearer, undefined);
});

test('buildRequest builds the GraphQL POST with session headers', () => {
  const req = load().buildRequest('FavoriteTweet', IDS, '1234567890', 'csrf42');
  assert.equal(req.url, 'https://x.com/i/api/graphql/fav111/FavoriteTweet');
  assert.equal(req.init.method, 'POST');
  assert.equal(req.init.credentials, 'include');
  assert.deepEqual(plain(req.init.headers), {
    authorization: 'Bearer ' + BEARER,
    'x-csrf-token': 'csrf42',
    'content-type': 'application/json',
    'x-twitter-auth-type': 'OAuth2Session',
    'x-twitter-active-user': 'yes',
  });
  assert.deepEqual(JSON.parse(req.init.body), { variables: { tweet_id: '1234567890' }, queryId: 'fav111' });
  const bm = load().buildRequest('DeleteBookmark', IDS, '99', 'c');
  assert.equal(bm.url, 'https://x.com/i/api/graphql/del444/DeleteBookmark');
  assert.deepEqual(JSON.parse(bm.init.body), { variables: { tweet_id: '99' }, queryId: 'del444' });
});

test('buildRequest rejects a bad tweet id or an unknown operation', () => {
  const X = load();
  assert.throws(() => X.buildRequest('FavoriteTweet', IDS, '12/../34', 'c'));
  assert.throws(() => X.buildRequest('FavoriteTweet', IDS, '', 'c'));
  assert.throws(() => X.buildRequest('FavoriteTweet', IDS, '1'.repeat(26), 'c'));
  assert.throws(() => X.buildRequest('DeleteTweet', IDS, '123', 'c'));
  assert.throws(() => X.buildRequest('toString', IDS, '123', 'c'));
});

test('mapResult maps statuses and X errors to short codes', () => {
  const X = load();
  const code = (s, b) => plain(X.mapResult(s, b));
  assert.deepEqual(code(200, { data: { favorite_tweet: 'Done' } }).code, 'ok');
  assert.equal(code(200, { data: {} }).ok, true);
  const already = code(200, { errors: [{ message: 'Authorization: Actor (uid: 1) has already favorited tweet (tid: 2)', code: 139 }] });
  assert.equal(already.code, 'already');
  assert.equal(already.ok, true);
  assert.equal(code(200, { errors: [{ message: 'You have already bookmarked this post' }] }).code, 'already');
  assert.equal(code(200, { errors: [{ message: 'Cannot query field "x" on type "Mutation"' }] }).code, 'stale');
  assert.equal(code(200, { errors: [{ message: 'Something odd' }] }).code, 'unknown');
  assert.equal(code(200, { errors: [{ message: 'Something odd' }] }).ok, false);
  assert.equal(code(401, null).code, 'auth');
  assert.equal(code(403, {}).code, 'auth');
  assert.equal(code(429, null).code, 'rate');
  assert.equal(code(400, null).code, 'stale');
  assert.equal(code(404, null).code, 'stale');
  assert.equal(code(500, null).code, 'unknown');
  const r = code(500, { errors: [{ message: 'secret raw body' }] });
  assert.equal(r.ok, false);
  assert.ok(r.message && !r.message.includes('secret'));
});

test('limiter: two immediate calls wait at least minGapMs, a third waits for its own slot', () => {
  let t = 1000;
  const lim = load().createLimiter({ minGapMs: 1500, perMinute: 30 }, () => t);
  assert.equal(lim.next().waitMs, 0);
  assert.ok(lim.next().waitMs >= 1500);
  assert.ok(lim.next().waitMs >= 3000);
});

test('limiter: the 31st call within a minute waits until the oldest leaves the window', () => {
  let t = 0;
  const lim = load().createLimiter({ minGapMs: 1500, perMinute: 30 }, () => t);
  for (let i = 0; i < 30; i++) {
    t = i * 1500;
    assert.equal(lim.next().waitMs, 0);
  }
  t = 45000;
  assert.equal(lim.next().waitMs, 15000);
});

// Fake page: script tags, cookie, optional articles with action buttons.
function fakeDocument({ scripts = [], cookie = 'ct0=csrf42; lang=en', articles = [] } = {}) {
  const clicks = [];
  const arts = articles.map(({ permalink, buttons }) => ({
    querySelector(sel) {
      if (sel === 'time') return { closest: () => ({ getAttribute: () => permalink, href: 'https://x.com' + permalink }) };
      const m = sel.match(/data-testid="(\w+)"/);
      if (m && buttons.includes(m[1])) return { click: () => clicks.push(m[1]) };
      return null;
    },
  }));
  return {
    clicks,
    cookie,
    querySelectorAll(sel) {
      if (sel === 'script[src]') return scripts.map((src) => ({ src }));
      if (sel === 'article') return arts;
      return [];
    },
  };
}

const MAIN = 'https://abs.twimg.com/responsive-web/client-web/main.abc123.js';

function env(doc, responses) {
  const calls = [];
  const sleeps = [];
  let t = 0;
  return {
    calls,
    sleeps,
    fetch: async (url, init) => {
      calls.push({ url, init });
      if (url === MAIN) return { ok: true, status: 200, text: async () => BUNDLE };
      const next = responses.shift();
      if (next instanceof Error) throw next;
      return { ok: next.status === 200, status: next.status, json: async () => next.body };
    },
    document: doc,
    now: () => t,
    sleep: async (ms) => { sleeps.push(ms); t += ms; },
  };
}

test('perform fetches the bundle, sends one API request and maps success', async () => {
  const X = load();
  const e = env(fakeDocument({ scripts: ['https://x.com/other.js', MAIN] }), [{ status: 200, body: { data: {} } }, { status: 200, body: { data: {} } }]);
  const r = plain(await X.perform('FavoriteTweet', '123', e));
  assert.deepEqual(r.ok, true);
  assert.equal(r.code, 'ok');
  assert.equal(e.calls.length, 2);
  assert.equal(e.calls[0].url, MAIN);
  assert.equal(e.calls[0].init && e.calls[0].init.credentials, 'omit');
  assert.equal(e.calls[1].url, 'https://x.com/i/api/graphql/fav111/FavoriteTweet');
  assert.equal(e.calls[1].init.headers['x-csrf-token'], 'csrf42');
  // The bundle is cached: a second action does not fetch it again, and waits its turn.
  assert.equal(plain(await X.perform('CreateBookmark', '123', e)).code, 'ok');
  assert.equal(e.calls.filter((c) => c.url === MAIN).length, 1);
  assert.equal(e.calls[2].url, 'https://x.com/i/api/graphql/bm333/CreateBookmark');
  assert.ok(e.sleeps[0] >= 1500);
});

test('perform on 429 reports rate and makes no second attempt or DOM click', async () => {
  const doc = fakeDocument({ scripts: [MAIN], articles: [{ permalink: '/u/status/123', buttons: ['like'] }] });
  const e = env(doc, [{ status: 429, body: null }]);
  const r = plain(await load().perform('FavoriteTweet', '123', e));
  assert.equal(r.code, 'rate');
  assert.equal(r.ok, false);
  assert.equal(e.calls.length, 2);
  assert.deepEqual(doc.clicks, []);
});

test('perform falls back to clicking the real button once when identifiers are stale', async () => {
  const doc = fakeDocument({
    scripts: [MAIN],
    articles: [
      { permalink: '/u/status/1234', buttons: ['like'] },
      { permalink: '/u/status/123', buttons: ['like', 'bookmark'] },
    ],
  });
  const e = env(doc, [{ status: 404, body: null }]);
  const r = plain(await load().perform('FavoriteTweet', '123', e));
  assert.equal(r.ok, true);
  assert.equal(r.code, 'ok');
  assert.deepEqual(doc.clicks, ['like']);
  assert.equal(e.calls.length, 2);
});

test('perform DOM fallback does not toggle back when the post is already in the wanted state', async () => {
  const doc = fakeDocument({ scripts: [MAIN], articles: [{ permalink: '/u/status/123', buttons: ['unlike'] }] });
  const e = env(doc, [new Error('network')]);
  const r = plain(await load().perform('FavoriteTweet', '123', e));
  assert.equal(r.code, 'already');
  assert.equal(r.ok, true);
  assert.deepEqual(doc.clicks, []);
});

test('perform without a bundle reports stale and sends no API request', async () => {
  const e = env(fakeDocument({ scripts: ['https://x.com/a.js'] }), []);
  const r = plain(await load().perform('UnfavoriteTweet', '123', e));
  assert.equal(r.code, 'stale');
  assert.equal(r.ok, false);
  assert.equal(e.calls.length, 0);
});

test('perform without a ct0 cookie reports auth and sends no API request', async () => {
  const e = env(fakeDocument({ scripts: [MAIN], cookie: 'lang=en' }), []);
  const r = plain(await load().perform('FavoriteTweet', '123', e));
  assert.equal(r.code, 'auth');
  assert.equal(e.calls.filter((c) => c.url.includes('/i/api/')).length, 0);
});

test('perform refuses a burst beyond the 70 s wait instead of firing it early', async () => {
  const doc = fakeDocument({ scripts: [MAIN] });
  const responses = Array.from({ length: 60 }, () => ({ status: 200, body: { data: {} } }));
  const e = env(doc, responses);
  e.sleep = async (ms) => { e.sleeps.push(ms); }; // fixed clock: every call is requested at once
  const X = load();
  const results = (await Promise.all(Array.from({ length: 50 }, () => X.perform('FavoriteTweet', '123', e)))).map(plain);
  const refused = results.filter((r) => r.code === 'rate').length;
  const api = e.calls.filter((c) => c.url.includes('/i/api/')).length;
  assert.ok(refused > 0);
  assert.equal(api + refused, 50);
  assert.ok(e.sleeps.every((ms) => ms <= 70000));
  assert.equal(e.calls.filter((c) => c.url === MAIN).length, 1);
});

test('mapResult never reports a missing post or user as already done', () => {
  const X = load();
  for (const message of ['Tweet not found', 'User not found']) {
    const r = plain(X.mapResult(200, { errors: [{ message }] }));
    assert.equal(r.ok, false, message);
    assert.equal(r.code, 'unknown', message);
  }
  const already = plain(X.mapResult(200, { errors: [{ message: 'has already favorited tweet' }] }));
  assert.equal(already.code, 'already');
  assert.equal(already.ok, true);
});

test('mapResult treats an unparseable 200 body as unknown', () => {
  const r = plain(load().mapResult(200, null));
  assert.equal(r.ok, false);
  assert.equal(r.code, 'unknown');
});

test('parseQueryIds skips A-padding runs and needs the full bearer shape', () => {
  const X = load();
  const padding = 'data:image/png;base64,' + 'A'.repeat(40) + '==";';
  assert.equal(X.parseQueryIds(padding + BUNDLE).bearer, BEARER);
  assert.equal(X.parseQueryIds(padding + 'n="AAAAAAAAAAAAAAAAAAAAnoSeparatorHere"').bearer, undefined);
});

test('parseQueryIds stays fast on a huge run of A and still finds a later token', () => {
  const X = load();
  const text = 'A'.repeat(300000) + '";n="' + BEARER + '";';
  const started = process.hrtime.bigint();
  const ids = X.parseQueryIds(text);
  const ms = Number(process.hrtime.bigint() - started) / 1e6;
  assert.ok(ms < 100, 'parseQueryIds took ' + ms + ' ms');
  assert.equal(ids.bearer, BEARER);
});

test('perform rediscovers identifiers after an auth or stale result', async () => {
  const X = load();
  const e = env(fakeDocument({ scripts: [MAIN] }), [{ status: 401, body: null }, { status: 200, body: { data: {} } }]);
  assert.equal(plain(await X.perform('FavoriteTweet', '123', e)).code, 'auth');
  assert.equal(plain(await X.perform('FavoriteTweet', '123', e)).code, 'ok');
  assert.equal(e.calls.filter((c) => c.url === MAIN).length, 2);
});

test('perform rejects an invalid op or tweet id without any request', async () => {
  const e = env(fakeDocument({ scripts: [MAIN] }), []);
  const r = plain(await load().perform('DeleteTweet', '123', e));
  assert.equal(r.ok, false);
  assert.equal(plain(await load().perform('FavoriteTweet', 'abc', e)).ok, false);
  assert.equal(e.calls.length, 0);
});

// ---- Wiring -------------------------------------------------------------

test('x_actions.js loads before content.js everywhere content.js is injected', () => {
  const list = '"url_policy.js", "theme.js", "x_actions.js", "content.js"';
  assert.ok(read('manifest.chrome.json').includes(list));
  assert.ok(read('manifest.firefox.json').includes(list));
  assert.ok(read('connection.js').includes("files: ['url_policy.js', 'theme.js', 'x_actions.js', 'content.js']"));
  const root = path.join(__dirname, '../..');
  const build = fs.readFileSync(path.join(root, 'tool/build_extension.dart'), 'utf8');
  const contract = fs.readFileSync(path.join(root, 'tool/check_extension_contract.dart'), 'utf8');
  assert.match(build, /'x_actions\.js',/);
  assert.equal((contract.match(/'x_actions\.js'/g) || []).length, 2);
});

test('content.js only accepts MD_X_ACTION from the background, in the top frame of an X page', () => {
  const content = read('content.js');
  const start = content.indexOf("message.type === 'MD_X_ACTION'");
  assert.ok(start > 0);
  const block = content.slice(start, content.indexOf("message.type === 'MD_CLEAR_CACHE'", start));
  assert.match(block, /window !== window\.top/);
  assert.match(block, /isXPage\(\)/);
  assert.match(block, /sender\.id !== api\.runtime\.id/);
  assert.match(block, /sender\.tab/);
  assert.match(block, /MDXActions\.perform\(/);
  assert.match(block, /return true;/);
});

// Loads the background script with stubbed browser APIs (same harness as download_relay_test).
const EXT_ID = 'abcdefghijklmnopabcdefghijklmnop';
const EXT_ORIGIN = 'chrome-extension://' + EXT_ID + '/';
const PANEL = { id: EXT_ID, url: EXT_ORIGIN + 'feed_panel.html' };

function loadBackground(tabs) {
  const listeners = [];
  const forwarded = [];
  const noop = () => {};
  const chrome = {
    runtime: {
      id: EXT_ID,
      getURL: (p) => EXT_ORIGIN + p,
      getManifest: () => ({ version: '9.9.9' }),
      onMessage: { addListener: (fn) => listeners.push(fn) },
      onInstalled: { addListener: noop },
      sendMessage: () => Promise.resolve(),
    },
    tabs: {
      get: async (id) => { const t = tabs.find((x) => x.id === id); if (!t) throw new Error('no tab'); return t; },
      query: async () => tabs,
      sendMessage: async (tabId, msg) => { forwarded.push({ tabId, msg: plain(msg) }); return { ok: true, code: 'ok', message: 'done' }; },
    },
    storage: { local: { get: () => Promise.resolve({}), set: () => Promise.resolve(), remove: () => Promise.resolve() } },
    action: {},
  };
  class FakeSocket { constructor() { this.readyState = 0; } send() {} close() {} }
  FakeSocket.OPEN = 1;
  const context = {
    chrome,
    WebSocket: FakeSocket,
    MDUrl: {
      SUPPORTED_DOMAINS: [], ADULT_DOMAINS: [],
      hostMatchesDomain: (h, d) => h === d || h.endsWith('.' + d),
      isSupportedDomain: () => false,
      isSafeHttpUrl: (u) => /^https?:\/\//.test(u), isRestrictedPageUrl: () => false,
    },
    MDBadge: { setConnected: noop, updateActiveBadge: noop },
    navigator: { userAgent: 'test' },
    console: { log: noop, warn: noop, debug: noop, error: noop },
    setTimeout: () => 0, clearTimeout: noop, setInterval: () => 0, clearInterval: noop,
    URL,
  };
  vm.createContext(context);
  vm.runInContext(read('connection.js'), context);
  // Resolves undefined when no listener keeps the channel open, so a missing handler fails fast.
  const ask = (msg, sender) => new Promise((resolve) => {
    let async = false;
    listeners.forEach((fn) => { if (fn(msg, sender, (r) => resolve(plain(r))) === true) async = true; });
    if (!async) setImmediate(() => resolve(undefined));
  });
  return { ask, forwarded };
}

const X_TABS = [
  { id: 1, url: 'https://example.com/' },
  { id: 2, url: 'https://x.com/home' },
  { id: 3, url: 'https://twitter.com/u/status/5' },
];

test('background rejects MD_X_ACTION from anything but an extension page', async () => {
  const bg = loadBackground(X_TABS);
  const msg = { type: 'MD_X_ACTION', op: 'FavoriteTweet', tweetId: '123' };
  assert.deepEqual(await bg.ask(msg, { id: EXT_ID, url: 'https://x.com/home', tab: { id: 2 } }), { ok: false, error: 'forbidden' });
  assert.deepEqual(await bg.ask(msg, { id: 'other', url: 'chrome-extension://other/feed_panel.html' }), { ok: false, error: 'forbidden' });
  assert.deepEqual(bg.forwarded, []);
});

test('background relays to the hooked x.com tab, else the first x.com tab', async () => {
  const bg = loadBackground(X_TABS);
  const r = await bg.ask({ type: 'MD_X_ACTION', op: 'CreateBookmark', tweetId: '123', tabId: 3, extra: 'dropped' }, PANEL);
  assert.equal(r.ok, true);
  assert.deepEqual(bg.forwarded[0], { tabId: 3, msg: { type: 'MD_X_ACTION', op: 'CreateBookmark', tweetId: '123' } });
  await bg.ask({ type: 'MD_X_ACTION', op: 'FavoriteTweet', tweetId: '123', tabId: 1 }, PANEL);
  assert.equal(bg.forwarded[1].tabId, 2);
});

test('background prefers a main x.com tab over help/ads subdomains, including a hooked one', async () => {
  const tabs = [
    { id: 7, url: 'https://help.x.com/en' },
    { id: 8, url: 'https://ads.twitter.com/' },
    { id: 9, url: 'https://x.com/home' },
  ];
  const bg = loadBackground(tabs);
  await bg.ask({ type: 'MD_X_ACTION', op: 'FavoriteTweet', tweetId: '1' }, PANEL);
  assert.equal(bg.forwarded[0].tabId, 9);
  await bg.ask({ type: 'MD_X_ACTION', op: 'FavoriteTweet', tweetId: '1', tabId: 7 }, PANEL);
  assert.equal(bg.forwarded[1].tabId, 9);
  const only = loadBackground([{ id: 7, url: 'https://help.x.com/en' }]);
  await only.ask({ type: 'MD_X_ACTION', op: 'FavoriteTweet', tweetId: '1' }, PANEL);
  assert.equal(only.forwarded[0].tabId, 7);
});

test('background answers no_tab without an x.com tab and refuses bad input', async () => {
  const bg = loadBackground([{ id: 1, url: 'https://example.com/' }]);
  const r = await bg.ask({ type: 'MD_X_ACTION', op: 'FavoriteTweet', tweetId: '123' }, PANEL);
  assert.equal(r.ok, false);
  assert.equal(r.code, 'no_tab');
  const bad = await bg.ask({ type: 'MD_X_ACTION', op: 'FavoriteTweet', tweetId: '1; drop' }, PANEL);
  assert.equal(bad.ok, false);
  assert.deepEqual(bg.forwarded, []);
});
