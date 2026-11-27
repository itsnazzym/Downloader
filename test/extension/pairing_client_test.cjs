const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const read = (name) => fs.readFileSync(path.join(__dirname, '../../extension/shared', name), 'utf8').replace(/\r\n/g, '\n');
const pairingSource = read('pairing.js');
const connectionSource = read('connection.js');
const plain = (v) => JSON.parse(JSON.stringify(v));
const flush = async () => { for (let i = 0; i < 5; i++) await new Promise((r) => setImmediate(r)); };

const EXT_ID = 'abcdefghijklmnopabcdefghijklmnop';
const EXT_ORIGIN = 'chrome-extension://' + EXT_ID + '/';
const POPUP = { id: EXT_ID, url: EXT_ORIGIN + 'popup.html' };
const CONTENT_SCRIPT = { id: EXT_ID, tab: { id: 7, url: 'https://evil.example/' }, frameId: 0, url: 'https://evil.example/' };
const T0 = 1_000_000;

// Background script with a stateful storage, a fake socket, a controllable clock and timers that only run on demand.
async function load(store = {}) {
  const storage = plain(store);
  const sockets = [];
  const listeners = [];
  const badge = [];
  const timers = [];
  let clock = T0;
  class FakeSocket {
    constructor(url) { this.url = url; this.readyState = 0; this.sent = []; this.closed = false; sockets.push(this); }
    send(raw) { this.sent.push(JSON.parse(raw)); }
    close() { this.readyState = 3; this.closed = true; }
  }
  FakeSocket.OPEN = 1;
  class FakeDate extends Date {
    constructor(...args) { super(...(args.length ? args : [clock])); }
    static now() { return clock; }
  }
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
    storage: {
      local: {
        get: (keys) => Promise.resolve(plain(Object.fromEntries([].concat(keys).filter((k) => k in storage).map((k) => [k, storage[k]])))),
        set: (obj) => { Object.assign(storage, plain(obj)); return Promise.resolve(); },
        remove: (keys) => { [].concat(keys).forEach((k) => delete storage[k]); return Promise.resolve(); },
      },
    },
    action: { setBadgeText: (o) => badge.push(o.text), setBadgeBackgroundColor: noop },
  };
  const context = {
    chrome,
    WebSocket: FakeSocket,
    Date: FakeDate,
    MDUrl: {
      SUPPORTED_DOMAINS: [], ADULT_DOMAINS: [],
      hostMatchesDomain: () => false, isSupportedDomain: () => false,
      isSafeHttpUrl: () => false, isRestrictedPageUrl: () => true,
    },
    MDBadge: { setConnected: noop, updateActiveBadge: noop },
    navigator: { userAgent: 'test' },
    console: { log: noop, warn: noop, debug: noop, error: noop },
    setTimeout: (fn, ms) => { timers.push({ fn, ms, done: false }); return timers.length; },
    clearTimeout: (id) => { if (timers[id - 1]) timers[id - 1].done = true; },
    setInterval: () => 0, clearInterval: noop,
    URL,
  };
  vm.createContext(context);
  vm.runInContext(pairingSource, context);
  vm.runInContext(connectionSource, context);
  await flush();

  const ws = () => sockets[sockets.length - 1];
  const bg = {
    storage, sockets, badge, ws,
    advance: (ms) => { clock += ms; },
    now: () => clock,
    open: () => { ws().readyState = 1; ws().onopen(); },
    fromApp: (msg) => ws().onmessage({ data: JSON.stringify(msg) }),
    serverClose: () => { const s = ws(); s.readyState = 3; s.onclose({ code: 1000 }); },
    sentOfType: (type, socket = ws()) => socket.sent.filter((m) => m.type === type),
    // Timers still armed (the 2 s HELLO timer is cleared on open), newest last.
    reconnectDelays: () => timers.filter((t) => !t.done).map((t) => t.ms),
    fireReconnect: async () => {
      const t = timers.filter((x) => !x.done).pop();
      assert.ok(t, 'a reconnect is scheduled');
      t.done = true;
      t.fn();
      await flush();
    },
    ask: (msg, sender = POPUP) => {
      let response;
      listeners.forEach((fn) => fn(msg, sender, (r) => { response = plain(r); }));
      return response;
    },
  };
  assert.equal(sockets.length, 1, 'connect() opened one socket');
  return bg;
}

test('a socket opened without a token sends exactly one PAIR_REQUEST and stays open', async () => {
  const bg = await load();
  bg.open();
  assert.deepEqual(bg.sentOfType('HELLO'), [{ type: 'HELLO', version: '9.9.9', token: '' }]);
  bg.fromApp({ type: 'AUTH_FAILED', reason: 'pairing_required' });
  await flush();
  assert.deepEqual(bg.sentOfType('PAIR_REQUEST'), [{ type: 'PAIR_REQUEST', extensionVersion: '9.9.9' }]);
  assert.equal(bg.ws().closed, false, 'pairing_required does not close the socket');
});

test('PAIR_PENDING stores the code and puts ? on the action badge', async () => {
  const bg = await load();
  bg.open();
  bg.fromApp({ type: 'AUTH_FAILED', reason: 'pairing_required' });
  bg.fromApp({ type: 'PAIR_PENDING', requestId: 'r1', code: '0042', expiresInSeconds: 120 });
  await flush();
  assert.deepEqual(bg.storage.pairing, { phase: 'pending', code: '0042', requestId: 'r1', until: T0 + 120000 });
  assert.equal(bg.badge[bg.badge.length - 1], '?');
  // The reminders every 10 s never trigger another request.
  bg.fromApp({ type: 'PAIR_PENDING', requestId: 'r1', code: '0042', expiresInSeconds: 110 });
  assert.equal(bg.sentOfType('PAIR_REQUEST').length, 1);
  // A message refused while the app waits for the user does not drop the request.
  bg.fromApp({ type: 'AUTH_FAILED', reason: 'not_authenticated' });
  assert.equal(bg.ws().closed, false);
});

test('PAIR_OK stores apiToken, clears pairing and the badge, and reconnects with the token', async () => {
  const bg = await load();
  bg.open();
  bg.fromApp({ type: 'PAIR_PENDING', requestId: 'r1', code: '1234', expiresInSeconds: 120 });
  const first = bg.ws();
  bg.fromApp({ type: 'PAIR_OK', token: 'paired-token' });
  bg.serverClose(); // the app closes right after its final answer
  await flush();
  assert.equal(bg.storage.apiToken, 'paired-token');
  assert.equal('pairing' in bg.storage, false);
  assert.equal(bg.badge[bg.badge.length - 1], '');
  assert.equal(bg.sockets.length, 2, 'a new socket was opened');
  assert.notEqual(bg.ws(), first);
  assert.deepEqual(bg.reconnectDelays(), [3000], 'only the new socket\'s connect timeout, no stale reconnect');
  bg.open();
  assert.deepEqual(bg.sentOfType('HELLO'), [{ type: 'HELLO', version: '9.9.9', token: 'paired-token' }]);
  assert.deepEqual(bg.sentOfType('PAIR_REQUEST'), []);
});

test('no second PAIR_REQUEST during a pause, and a slow reconnect meanwhile', async () => {
  const bg = await load();
  bg.open();
  bg.fromApp({ type: 'PAIR_DENIED', retryAfterSeconds: 600 });
  await flush();
  assert.deepEqual(bg.storage.pairing, { phase: 'denied', until: T0 + 600000 });
  bg.serverClose();
  assert.deepEqual(bg.reconnectDelays(), [10000]);
  await bg.fireReconnect();
  bg.open();
  bg.fromApp({ type: 'AUTH_FAILED', reason: 'pairing_required' });
  await flush();
  assert.deepEqual(bg.sentOfType('PAIR_REQUEST'), []);
  assert.equal(bg.ws().closed, true, 'nothing to wait for: the client closes and retries later');
  // Once the pause is over the next attempt asks again.
  bg.advance(600000);
  bg.ws().onclose({ code: 1000 });
  await bg.fireReconnect();
  bg.open();
  assert.equal(bg.sentOfType('PAIR_REQUEST').length, 1);
});

test('a pause stored by a previous service worker is respected', async () => {
  const bg = await load({ pairing: { phase: 'paused', until: T0 + 60000 } });
  bg.open();
  assert.deepEqual(bg.sentOfType('PAIR_REQUEST'), []);
});

test('MD_PAIRING_RETRY is refused from a content script and accepted from the popup', async () => {
  const bg = await load({ pairing: { phase: 'denied', until: T0 + 600000 } });
  bg.open();
  assert.deepEqual(bg.ask({ type: 'MD_PAIRING_RETRY' }, CONTENT_SCRIPT), { ok: false, error: 'forbidden' });
  assert.deepEqual(bg.ask({ type: 'MD_PAIRING_RETRY' }, {}), { ok: false, error: 'forbidden' });
  await flush();
  assert.equal(bg.sockets.length, 1);
  assert.deepEqual(bg.storage.pairing, { phase: 'denied', until: T0 + 600000 });

  assert.deepEqual(bg.ask({ type: 'MD_PAIRING_RETRY' }), { ok: true });
  await flush();
  assert.equal('pairing' in bg.storage, false);
  assert.equal(bg.sockets.length, 2);
  bg.open();
  assert.equal(bg.sentOfType('PAIR_REQUEST').length, 1);
});

test('an old app (bare AUTH_FAILED after PAIR_REQUEST) gives update_needed and a slow reconnect', async () => {
  const bg = await load();
  bg.open();
  assert.equal(bg.sentOfType('PAIR_REQUEST').length, 1);
  bg.fromApp({ type: 'AUTH_FAILED' });
  await flush();
  assert.deepEqual(bg.storage.pairing, { phase: 'update_needed' });
  assert.equal(bg.ws().closed, true);
  bg.ws().onclose({ code: 1000 });
  assert.deepEqual(bg.reconnectDelays(), [10000]);
  await bg.fireReconnect();
  bg.open();
  assert.deepEqual(bg.sentOfType('PAIR_REQUEST'), [], 'the old app is not asked again');
  // Once the app is updated it says pairing_required, and pairing starts.
  bg.fromApp({ type: 'AUTH_FAILED', reason: 'pairing_required' });
  await flush();
  assert.equal(bg.sentOfType('PAIR_REQUEST').length, 1);
  assert.equal('pairing' in bg.storage, false);
});

test('a revoked token is cleared and pairing starts on the same socket', async () => {
  const bg = await load({ apiToken: 'revoked' });
  bg.open();
  assert.deepEqual(bg.sentOfType('HELLO'), [{ type: 'HELLO', version: '9.9.9', token: 'revoked' }]);
  assert.deepEqual(bg.sentOfType('PAIR_REQUEST'), []);
  bg.fromApp({ type: 'AUTH_FAILED', reason: 'pairing_required' });
  await flush();
  assert.equal('apiToken' in bg.storage, false);
  assert.equal(bg.sentOfType('PAIR_REQUEST').length, 1);
  assert.equal(bg.ws().closed, false);
});

test('a revoked token during a pause is cleared without a new request', async () => {
  const bg = await load({ apiToken: 'revoked', pairing: { phase: 'paused', until: T0 + 600000 } });
  bg.open();
  bg.fromApp({ type: 'AUTH_FAILED', reason: 'pairing_required' });
  await flush();
  assert.equal('apiToken' in bg.storage, false);
  assert.deepEqual(bg.sentOfType('PAIR_REQUEST'), []);
  assert.deepEqual(bg.storage.pairing, { phase: 'paused', until: T0 + 600000 });
});

test('a manual token from the popup is used as is and never triggers pairing', async () => {
  const bg = await load({ apiToken: 'manual-token' });
  bg.open();
  bg.fromApp({ type: 'HELLO_OK' });
  await flush();
  assert.deepEqual(bg.sentOfType('HELLO'), [{ type: 'HELLO', version: '9.9.9', token: 'manual-token' }]);
  assert.deepEqual(bg.sentOfType('PAIR_REQUEST'), []);
  assert.equal(bg.storage.apiToken, 'manual-token');
  assert.equal('pairing' in bg.storage, false);
});

test('while the app is unreachable: every 3 s for 5 minutes, then every 10 s', async () => {
  const bg = await load();
  bg.ws().onclose({ code: 1006 });
  assert.deepEqual(bg.reconnectDelays().slice(-1), [3000]);
  await bg.fireReconnect();
  bg.advance(299000);
  bg.ws().onclose({ code: 1006 });
  assert.deepEqual(bg.reconnectDelays().slice(-1), [3000]);
  await bg.fireReconnect();
  bg.advance(1000);
  bg.ws().onclose({ code: 1006 });
  assert.deepEqual(bg.reconnectDelays().slice(-1), [10000]);
});

test('pairing.js loads before the connection client in Chrome and Firefox, and is packaged', () => {
  const sw = read('sw_shell.js');
  assert.ok(sw.indexOf("importScripts('pairing.js')") > 0);
  assert.ok(sw.indexOf("importScripts('pairing.js')") < sw.indexOf("importScripts('connection.js')"));
  assert.ok(read('manifest.firefox.json').includes('"pairing.js", "background.js"'));
  const root = path.join(__dirname, '../..');
  assert.match(fs.readFileSync(path.join(root, 'tool/build_extension.dart'), 'utf8'), /'pairing\.js',/);
  const contract = fs.readFileSync(path.join(root, 'tool/check_extension_contract.dart'), 'utf8');
  assert.equal((contract.match(/'pairing\.js'/g) || []).length, 2);
});

test('a stored token refused by an old app reconnects at the slow pace, not every 3 s', async () => {
  const bg = await load({ apiToken: 'stale' });
  for (let i = 0; i < 2; i++) {
    bg.open();
    bg.fromApp({ type: 'AUTH_FAILED' });
    await flush();
    assert.equal(bg.ws().closed, true);
    bg.ws().onclose({ code: 1000 });
    assert.deepEqual(bg.reconnectDelays(), [10000]);
    await bg.fireReconnect();
  }
  assert.deepEqual(bg.sentOfType('PAIR_REQUEST'), []);
  assert.equal(bg.storage.apiToken, 'stale', 'an old app cannot mean revoked: the token stays');
});
