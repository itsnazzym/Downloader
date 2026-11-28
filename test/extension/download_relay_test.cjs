const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/connection.js'), 'utf8').replace(/\r\n/g, '\n');
const plain = (v) => JSON.parse(JSON.stringify(v));
const flush = () => new Promise((resolve) => setImmediate(resolve));

const EXT_ID = 'abcdefghijklmnopabcdefghijklmnop';
const EXT_ORIGIN = 'chrome-extension://' + EXT_ID + '/';
const PANEL_SENDER = { id: EXT_ID, url: EXT_ORIGIN + 'feed_panel.html' };

// Loads the whole background script with stubbed browser APIs, a fake socket and inert timers.
async function load(opts = {}) {
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
      id: EXT_ID,
      getURL: (p) => EXT_ORIGIN + p,
      getManifest: () => ({ version: '9.9.9' }),
      onMessage: { addListener: (fn) => listeners.push(fn) },
      onInstalled: { addListener: noop },
      sendMessage: (msg) => { relayed.push(plain(msg)); return Promise.resolve(); },
    },
    storage: { local: { get: opts.storageGet || (() => Promise.resolve({})), set: () => Promise.resolve(), remove: () => Promise.resolve() } },
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
    // opts.settleHeartbeat: the 250 ms pause of an X feed request resolves at once; every other timer stays inert.
    setTimeout: (fn, ms) => { if (opts.settleHeartbeat && ms === 250) queueMicrotask(fn); return 0; }, clearTimeout: noop, setInterval: () => 0, clearInterval: noop,
    URL,
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../../extension/shared/pairing.js'), 'utf8'), context);
  vm.runInContext(source, context);
  await flush();
  assert.equal(sockets.length, 1, 'connect() opened one socket');
  const ws = sockets[0];
  const fromApp = (msg) => ws.onmessage({ data: JSON.stringify(msg) });
  const ask = (msg, sender = PANEL_SENDER) => {
    let response;
    listeners.forEach((fn) => fn(msg, sender, (r) => { response = plain(r); }));
    return response;
  };
  const sentOfType = (type) => ws.sent.filter((m) => m.type === type);
  const askAsync = (msg, sender = PANEL_SENDER) => new Promise((resolve) => {
    listeners.forEach((fn) => fn(msg, sender, (r) => resolve(plain(r))));
  });
  return { ws, relayed, fromApp, ask, askAsync, sentOfType };
}

async function loadReady(opts) {
  const bg = await load(opts);
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

test('queue messages from a content script are refused and nothing reaches the socket', async () => {
  const bg = await loadReady();
  const contentScript = { id: EXT_ID, tab: { id: 7, url: 'https://evil.example/' }, frameId: 0, url: 'https://evil.example/' };
  assert.deepEqual(bg.ask({ type: 'MD_DOWNLOAD_COMMAND', command: 'cancel_all' }, contentScript), { ok: false, error: 'forbidden' });
  assert.deepEqual(bg.ask({ type: 'MD_QUEUE_SNAPSHOT_REQUEST' }, contentScript), { ok: false, error: 'forbidden' });
  assert.deepEqual(bg.ask({ type: 'MD_DOWNLOAD_COMMAND', command: 'cancel', id: 'd1' }, { id: 'other-extension', url: 'chrome-extension://other-extension/x.html' }), { ok: false, error: 'forbidden' });
  assert.deepEqual(bg.ask({ type: 'MD_DOWNLOAD_COMMAND', command: 'cancel', id: 'd1' }, {}), { ok: false, error: 'forbidden' });
  assert.deepEqual(bg.sentOfType('DOWNLOAD_COMMAND'), []);
  assert.equal(bg.sentOfType('QUEUE_SNAPSHOT_REQUEST').length, 1); // only the HELLO_OK one
});

test('extension pages are accepted, also when opened in a tab', async () => {
  const bg = await loadReady();
  const panelInTab = { id: EXT_ID, tab: { id: 3 }, url: EXT_ORIGIN + 'feed_panel.html' };
  assert.deepEqual(bg.ask({ type: 'MD_DOWNLOAD_COMMAND', command: 'pause', id: 'd2' }, panelInTab), { ok: true, sent: true });
  assert.deepEqual(bg.ask({ type: 'MD_DOWNLOAD_COMMAND', command: 'retry', id: 'd3' }), { ok: true, sent: true });
  assert.deepEqual(bg.sentOfType('DOWNLOAD_COMMAND').map((m) => m.command), ['pause', 'retry']);
});

test('a socket close tells the panel the app is offline and resets the active count', async () => {
  const bg = await loadReady();
  bg.fromApp({ type: 'PROGRESS', data: { id: 'a', status: 2, progress: 0.4 } });
  await flush();
  bg.relayed.length = 0;
  bg.ws.onclose({ code: 1006 });
  assert.deepEqual(bg.relayed, [{ type: 'MD_CONNECTION_STATE', connected: false, activeCount: 0 }]);
  assert.deepEqual(bg.ask({ type: 'GET_CONNECTION_STATE' }), { ok: true, connected: false, activeCount: 0 });
});

test('a close while an X feed request waits answers app_offline instead of hanging', async () => {
  const bg = await loadReady({ settleHeartbeat: true });
  let answer;
  bg.askAsync({ type: 'ANALYZE_X_FEED', maxItems: 10 }).then((r) => { answer = r; });
  await flush();
  assert.equal(bg.sentOfType('X_FEED_REQUEST').length, 1, 'the request reached the app');
  assert.equal(answer, undefined, 'still waiting for the app');
  bg.ws.onclose({ code: 1006 });
  await flush();
  assert.ok(answer, 'the caller is released as soon as the socket closes');
  assert.equal(answer.gobirdErrorCode, 'app_offline');
});

test('a failing storage read while handling PROGRESS is logged, not an unhandled rejection', async () => {
  const unhandled = [];
  const onUnhandled = (reason) => unhandled.push(reason);
  process.on('unhandledRejection', onUnhandled);
  try {
    const bg = await loadReady({ storageGet: (keys) => (keys.includes('recentDownloads') ? Promise.reject(new Error('storage down')) : Promise.resolve({})) });
    bg.fromApp({ type: 'PROGRESS', data: { id: 'a', status: 2, progress: 0.4 } });
    await flush();
    await flush();
    assert.deepEqual(unhandled.map(String), []);
  } finally {
    process.off('unhandledRejection', onUnhandled);
  }
});
