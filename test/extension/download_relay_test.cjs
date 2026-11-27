const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/connection.js'), 'utf8');
const plain = (v) => JSON.parse(JSON.stringify(v));
const flush = () => new Promise((resolve) => setImmediate(resolve));

// Loads the whole background script with stubbed browser APIs, a fake socket and inert timers.
async function load() {
  const sockets = [];
  const relayed = [];
  const listeners = [];
  class FakeSocket {
    constructor(url) { this.url = url; this.readyState = 0; this.sent = []; sockets.push(this); }
    send(raw) { this.sent.push(JSON.parse(raw)); }
    close() { this.readyState = 3; }
  }
  FakeSocket.OPEN = 1;
  const noop = () => {};
  const chrome = {
    runtime: {
      getManifest: () => ({ version: '9.9.9' }),
      onMessage: { addListener: (fn) => listeners.push(fn) },
      onInstalled: { addListener: noop },
      sendMessage: (msg) => { relayed.push(plain(msg)); return Promise.resolve(); },
    },
    storage: { local: { get: () => Promise.resolve({}), set: () => Promise.resolve(), remove: () => Promise.resolve() } },
    action: {},
  };
  const context = {
    chrome,
    WebSocket: FakeSocket,
    MDUrl: {
      SUPPORTED_DOMAINS: [], ADULT_DOMAINS: [],
      hostMatchesDomain: () => false, isSupportedDomain: () => false,
      isSafeHttpUrl: () => false, isRestrictedPageUrl: () => true,
    },
    MDBadge: { setConnected: noop, updateActiveBadge: noop },
    navigator: { userAgent: 'test' },
    console: { log: noop, warn: noop, debug: noop, error: noop },
    setTimeout: () => 0, clearTimeout: noop, setInterval: () => 0, clearInterval: noop,
    URL,
  };
  vm.createContext(context);
  vm.runInContext(source, context);
  await flush();
  assert.equal(sockets.length, 1, 'connect() opened one socket');
  const ws = sockets[0];
  const fromApp = (msg) => ws.onmessage({ data: JSON.stringify(msg) });
  const ask = (msg) => {
    let response;
    listeners.forEach((fn) => fn(msg, {}, (r) => { response = plain(r); }));
    return response;
  };
  const sentOfType = (type) => ws.sent.filter((m) => m.type === type);
  return { ws, relayed, fromApp, ask, sentOfType };
}

async function loadReady() {
  const bg = await load();
  bg.ws.readyState = 1;
  bg.ws.onopen();
  bg.fromApp({ type: 'HELLO_OK' });
  return bg;
}

test('a snapshot is requested automatically once HELLO_OK arrives', async () => {
  const bg = await load();
  bg.ws.readyState = 1;
  bg.ws.onopen();
  assert.deepEqual(bg.sentOfType('QUEUE_SNAPSHOT_REQUEST'), []);
  bg.fromApp({ type: 'HELLO_OK' });
  assert.deepEqual(bg.sentOfType('QUEUE_SNAPSHOT_REQUEST'), [{ type: 'QUEUE_SNAPSHOT_REQUEST' }]);
});

test('MD_DOWNLOAD_COMMAND is sent as exactly {type, command, id} and acknowledged', async () => {
  const bg = await loadReady();
  const response = bg.ask({ type: 'MD_DOWNLOAD_COMMAND', command: 'cancel', id: 'd1', token: 'x' });
  assert.deepEqual(response, { ok: true, sent: true });
  assert.deepEqual(bg.sentOfType('DOWNLOAD_COMMAND'), [{ type: 'DOWNLOAD_COMMAND', command: 'cancel', id: 'd1' }]);
});

test('cancel_all is sent without an id', async () => {
  const bg = await loadReady();
  bg.ask({ type: 'MD_DOWNLOAD_COMMAND', command: 'cancel_all' });
  assert.deepEqual(bg.sentOfType('DOWNLOAD_COMMAND'), [{ type: 'DOWNLOAD_COMMAND', command: 'cancel_all' }]);
});

test('unknown commands are refused locally', async () => {
  const bg = await loadReady();
  assert.deepEqual(bg.ask({ type: 'MD_DOWNLOAD_COMMAND', command: 'delete', id: 'd1' }), { ok: false, error: 'unknown_command' });
  assert.deepEqual(bg.sentOfType('DOWNLOAD_COMMAND'), []);
});

test('without an authenticated socket the command answers not_connected', async () => {
  const bg = await load();
  bg.ws.readyState = 1; // open but HELLO_OK never came
  assert.deepEqual(bg.ask({ type: 'MD_DOWNLOAD_COMMAND', command: 'cancel', id: 'd1' }), { ok: false, error: 'not_connected' });
  assert.deepEqual(bg.ask({ type: 'MD_QUEUE_SNAPSHOT_REQUEST' }), { ok: false, error: 'not_connected' });
  assert.deepEqual(bg.sentOfType('DOWNLOAD_COMMAND'), []);
  assert.deepEqual(bg.sentOfType('QUEUE_SNAPSHOT_REQUEST'), []);
});

test('MD_QUEUE_SNAPSHOT_REQUEST asks the app for a snapshot', async () => {
  const bg = await loadReady();
  assert.deepEqual(bg.ask({ type: 'MD_QUEUE_SNAPSHOT_REQUEST' }), { ok: true, sent: true });
  assert.equal(bg.sentOfType('QUEUE_SNAPSHOT_REQUEST').length, 2); // HELLO_OK + explicit
});

const SANITIZED_KEYS = ['id', 'title', 'status', 'progress', 'speed', 'totalSize', 'downloadedSize', 'eta', 'error', 'url', 'tweetId', 'mediaId', 'tikTokId'];

test('QUEUE_SNAPSHOT is relayed to the panel with sanitized items only', async () => {
  const bg = await loadReady();
  bg.fromApp({
    type: 'QUEUE_SNAPSHOT',
    items: [{ id: 'd1', title: 'Clip', status: 2, progress: 0.4, speed: '1MiB/s', url: 'https://x.com/a/status/1', filePath: 'C:/secret.mp4', cookies: 'sid=1', request: {} }],
  });
  const snap = bg.relayed.filter((m) => m.type === 'MD_QUEUE_SNAPSHOT');
  assert.equal(snap.length, 1);
  assert.equal(snap[0].items.length, 1);
  const item = snap[0].items[0];
  assert.deepEqual(Object.keys(item).sort(), SANITIZED_KEYS.filter((k) => k in item).sort());
  assert.equal(item.filePath, undefined);
  assert.equal(item.cookies, undefined);
  assert.equal(item.request, undefined);
  assert.equal(item.id, 'd1');
  assert.equal(item.status, 2);
});

test('a malformed snapshot is relayed as an empty list', async () => {
  const bg = await loadReady();
  bg.fromApp({ type: 'QUEUE_SNAPSHOT', items: 'nope' });
  assert.deepEqual(bg.relayed.filter((m) => m.type === 'MD_QUEUE_SNAPSHOT'), [{ type: 'MD_QUEUE_SNAPSHOT', items: [] }]);
});

test('DOWNLOAD_COMMAND_RESULT is relayed to the panel', async () => {
  const bg = await loadReady();
  bg.fromApp({ type: 'DOWNLOAD_COMMAND_RESULT', ok: false, command: 'pause', id: 'd1', error: 'invalid_state', extra: 1 });
  assert.deepEqual(bg.relayed.filter((m) => m.type === 'MD_DOWNLOAD_COMMAND_RESULT'), [
    { type: 'MD_DOWNLOAD_COMMAND_RESULT', ok: false, command: 'pause', id: 'd1', error: 'invalid_state' },
  ]);
});

test('progress, snapshot and command results reach the panel in arrival order', async () => {
  const bg = await loadReady();
  bg.fromApp({ type: 'PROGRESS', data: { id: 'd1', status: 2, progress: 0.1, filePath: 'C:/x' } });
  bg.fromApp({ type: 'QUEUE_SNAPSHOT', items: [] });
  bg.fromApp({ type: 'DOWNLOAD_COMMAND_RESULT', ok: true, command: 'cancel', id: 'd1' });
  bg.fromApp({ type: 'PROGRESS', data: { id: 'd1', status: 6 } });
  const order = bg.relayed
    .filter((m) => /^MD_(DOWNLOAD_PROGRESS|QUEUE_SNAPSHOT|DOWNLOAD_COMMAND_RESULT)$/.test(m.type))
    .map((m) => m.type);
  assert.deepEqual(order, ['MD_DOWNLOAD_PROGRESS', 'MD_QUEUE_SNAPSHOT', 'MD_DOWNLOAD_COMMAND_RESULT', 'MD_DOWNLOAD_PROGRESS']);
  const progress = bg.relayed.find((m) => m.type === 'MD_DOWNLOAD_PROGRESS');
  assert.equal(progress.data.filePath, undefined);
});
