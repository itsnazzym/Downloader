const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const shared = path.join(__dirname, '../../extension/shared');
const read = (name) => fs.readFileSync(path.join(shared, name), 'utf8').replace(/\r\n/g, '\n').replace(/^﻿/, '');
const popupSource = read('popup.js');
const popupHtml = read('popup.html');
const popupCss = read('popup.css');
const locales = Object.fromEntries(['fr', 'en', 'ar'].map((l) => [l, JSON.parse(read('_locales/' + l + '/messages.json'))]));
const msg = (key, locale = 'fr') => locales[locale][key] && locales[locale][key].message;
const plain = (v) => JSON.parse(JSON.stringify(v));
const flush = async () => { for (let i = 0; i < 5; i++) await new Promise((r) => setImmediate(r)); };
const T0 = 1_000_000;

const htmlIds = new Set([...popupHtml.matchAll(/\bid="([^"]+)"/g)].map((m) => m[1]));
const htmlHidden = (id) => new RegExp('<[a-z0-9]+[^>]*\\bid="' + id + '"[^>]*\\bhidden\\b').test(popupHtml);

class El {
  constructor(id) {
    this.id = id;
    this.textContent = '';
    this.hidden = htmlHidden(id);
    this.className = '';
    this.dataset = {};
    this.value = '';
    this.checked = false;
    this.disabled = false;
    this.title = '';
    this.type = 'text';
    this.placeholder = '';
    this.open = false;
    this.style = {};
    this.children = [];
    this.handlers = {};
    this.focused = false;
  }
  addEventListener(type, fn) { (this.handlers[type] = this.handlers[type] || []).push(fn); }
  click() { (this.handlers.click || []).forEach((fn) => fn({})); }
  appendChild(child) { this.children.push(child); return child; }
  setAttribute() {}
  getAttribute() { return null; }
  querySelector() { return null; }
  focus() { this.focused = true; }
}

// popup.js against a minimal DOM built from popup.html's ids; timers never run.
async function load(store = {}, { locale = 'fr', now = T0 } = {}) {
  const storage = plain(store);
  const sent = [];
  const els = {};
  const changeListeners = [];
  const intervals = [];
  const tokenSaves = [];
  const body = new El('body');
  const document = {
    body,
    documentElement: { lang: '', dir: '' },
    getElementById: (id) => (htmlIds.has(id) ? (els[id] = els[id] || new El(id)) : null),
    querySelectorAll: () => [],
    createElement: (tag) => new El(tag),
  };
  const chrome = {
    i18n: { getMessage: (key) => msg(key, locale), getUILanguage: () => locale },
    runtime: {
      sendMessage: (message, cb) => {
        sent.push(message);
        if (cb) cb(message.type === 'MD_PAIRING_RETRY' ? { ok: true } : undefined);
      },
    },
    storage: {
      local: {
        get: (keys) => Promise.resolve(plain(Object.fromEntries([].concat(keys).filter((k) => k in storage).map((k) => [k, storage[k]])))),
        set: (obj) => { tokenSaves.push(plain(obj)); Object.assign(storage, plain(obj)); return Promise.resolve(); },
      },
      onChanged: { addListener: (fn) => changeListeners.push(fn) },
    },
    tabs: { query: () => Promise.resolve([]) },
  };
  class FakeDate extends Date {
    constructor(...args) { super(...(args.length ? args : [now])); }
    static now() { return now; }
  }
  const context = {
    chrome, document, Date: FakeDate, Intl, console,
    setTimeout: () => 1, clearTimeout: () => {},
    setInterval: (fn) => intervals.push(fn), clearInterval: () => {},
  };
  vm.createContext(context);
  vm.runInContext(popupSource, context);
  await flush();
  const el = (id) => document.getElementById(id);
  return {
    body, el, sent, storage, tokenSaves,
    refresh: async () => { intervals.forEach((fn) => fn()); await flush(); },
    changed: async (changes) => { changeListeners.forEach((fn) => fn(changes, 'local')); await flush(); },
    title: () => el('setup-title').textContent,
    text: (id) => el(id).textContent,
  };
}

const PHASES = {
  idle: { title: 'pairNotFoundTitle', body: 'pairNotFoundBody' },
  pending: { title: 'pairPendingTitle', body: 'pairPendingBody' },
  denied: { title: 'pairDeniedTitle', body: 'pairDeniedBody' },
  paused: { title: 'pairDeniedTitle', body: 'pairDeniedBody' },
  expired: { title: 'pairExpiredTitle', body: 'pairExpiredBody' },
  busy: { title: 'pairBusyTitle', body: 'pairBusyBody' },
  update_needed: { title: 'pairUpdateTitle', body: 'pairUpdateBody' },
};
const stateFor = (phase) => {
  if (phase === 'idle') return {};
  if (phase === 'pending') return { pairing: { phase, code: '0042', requestId: 'r1', until: T0 + 90000 } };
  if (phase === 'update_needed') return { pairing: { phase } };
  return { pairing: { phase, until: T0 + 600000 } };
};

test('every phase shows its own title and body', async () => {
  for (const [phase, keys] of Object.entries(PHASES)) {
    const popup = await load(stateFor(phase));
    assert.equal(popup.title(), msg(keys.title), phase + ' title');
    assert.equal(popup.text('pair-body'), msg(keys.body), phase + ' body');
    assert.ok(msg(keys.title) && msg(keys.body), phase + ' keys exist');
    assert.equal(popup.body.dataset.conn, 'offline');
    assert.equal(popup.body.dataset.pair, phase);
  }
});

test('the code is shown, large, only while pending', async () => {
  for (const phase of Object.keys(PHASES)) {
    const popup = await load(stateFor(phase));
    const code = popup.el('pair-code');
    assert.equal(code.hidden, phase !== 'pending', phase);
    assert.equal(code.textContent, phase === 'pending' ? '0042' : '', phase);
  }
  assert.match(popupCss, /\.pair-code\s*\{[^}]*font-size:\s*(4\d|5\d)px/);
});

test('a stale pending state (past its deadline) is shown as app not found', async () => {
  const popup = await load({ pairing: { phase: 'pending', code: '0042', until: T0 - 1 } });
  assert.equal(popup.body.dataset.pair, 'idle');
  assert.equal(popup.el('pair-code').hidden, true);
});

test('after a refusal only the remaining delay shows; Retry exists only for expired and busy', async () => {
  for (const phase of Object.keys(PHASES)) {
    const popup = await load(stateFor(phase));
    const counts = ['denied', 'paused'].includes(phase);
    assert.equal(popup.el('pair-retry-btn').hidden, !['expired', 'busy'].includes(phase), phase + ' retry');
    assert.equal(popup.el('pair-delay').hidden, !counts, phase + ' delay');
    if (counts) {
      assert.match(popup.text('pair-delay'), /10/, 'ten minutes left: ' + popup.text('pair-delay'));
    }
  }
  const over = await load({ pairing: { phase: 'denied', until: T0 - 1000 } });
  assert.equal(over.text('pair-delay'), msg('pairRetryReady'));
  assert.equal(over.el('pair-retry-btn').hidden, true, 'the extension asks again by itself after the pause');
  const always = await load({ pairing: { phase: 'denied', until: T0 + 86400000 } });
  assert.match(always.text('pair-delay'), /24/);
});

test('Retry sends MD_PAIRING_RETRY to the background', async () => {
  const popup = await load(stateFor('expired'));
  popup.el('pair-retry-btn').click();
  await flush();
  assert.deepEqual(plain(popup.sent.filter((m) => m.type === 'MD_PAIRING_RETRY')), [{ type: 'MD_PAIRING_RETRY' }]);
});

test('connected: no pairing card content, status says Connecté even with a stale state', async () => {
  const popup = await load({ isConnected: true, apiToken: 'paired', ...stateFor('denied') });
  assert.equal(popup.body.dataset.conn, 'online');
  assert.equal(popup.body.dataset.pair, 'none');
  assert.equal(popup.text('status-text'), msg('connected'));
  assert.equal(popup.el('pair-code').hidden, true);
  assert.equal(popup.el('pair-retry-btn').hidden, true);
});

test('the popup follows storage: pending, then connected', async () => {
  const popup = await load();
  assert.equal(popup.body.dataset.pair, 'idle');
  popup.storage.pairing = stateFor('pending').pairing;
  await popup.changed({ pairing: { newValue: popup.storage.pairing } });
  assert.equal(popup.el('pair-code').textContent, '0042');
  delete popup.storage.pairing;
  popup.storage.isConnected = true;
  await popup.changed({ isConnected: { newValue: true }, pairing: { newValue: undefined } });
  assert.equal(popup.body.dataset.pair, 'none');
  assert.equal(popup.el('pair-code').hidden, true);
});

test('pairing_required is never reported as a bad token; real auth errors still are', async () => {
  const pairing = await load({ lastAuthError: 'pairing_required', ...stateFor('pending') });
  assert.equal(pairing.text('connection-msg'), '');
  const bare = await load({ lastAuthError: 'pairing_required' });
  assert.equal(bare.text('connection-msg'), '');
  const old = await load({ lastAuthError: 'auth_failed', ...stateFor('update_needed') });
  assert.equal(old.text('connection-msg'), '', 'update_needed already explains it');
  const wrong = await load({ lastAuthError: 'auth_failed', apiToken: 'typo' });
  assert.equal(wrong.text('connection-msg'), msg('authFailed'));
});

test('the token field lives in a collapsed Advanced section', () => {
  const details = popupHtml.match(/<details\b[^>]*\bid="advanced"[^>]*>[\s\S]*?<\/details>/);
  assert.ok(details, 'details#advanced exists');
  assert.doesNotMatch(details[0].match(/^<details[^>]*>/)[0], /\bopen\b/, 'collapsed by default');
  assert.match(details[0], /id="token-input"/);
  assert.match(details[0], /id="test-connection-btn"/);
  assert.match(details[0], /<summary[^>]*data-i18n="pairAdvanced"/);
  const outside = popupHtml.replace(details[0], '');
  assert.doesNotMatch(outside, /id="token-input"/);
  assert.match(outside, /id="pair-code"/);
});

test('a manual token still loads, saves and opens Advanced from the settings', async () => {
  const popup = await load({ apiToken: 'manual-token' });
  assert.equal(popup.el('token-input').value, 'manual-token');
  popup.el('token-input').value = '  other-token ';
  popup.el('token-input').handlers.change.forEach((fn) => fn({}));
  await flush();
  assert.equal(popup.storage.apiToken, 'other-token');
  assert.ok(popup.sent.some((m) => m.type === 'CONFIG_UPDATED'));

  popup.el('edit-token-btn').click();
  assert.equal(popup.el('advanced').open, true);
  assert.equal(popup.el('token-input').focused, true);
  assert.equal(popup.body.dataset.setup, 'open');
});

test('a token paired while the popup is open is not wiped by the next settings save', async () => {
  const popup = await load(stateFor('pending'));
  assert.equal(popup.el('token-input').value, '');
  popup.storage.apiToken = 'paired-token'; // the background stores it on PAIR_OK
  delete popup.storage.pairing;
  await popup.changed({ apiToken: { newValue: 'paired-token' } });
  assert.equal(popup.el('token-input').value, 'paired-token');
  popup.el('cookies-toggle').checked = false;
  popup.el('cookies-toggle').handlers.change.forEach((fn) => fn({}));
  await flush();
  assert.equal(popup.storage.apiToken, 'paired-token');
  assert.equal(popup.storage.autoSendCookies, false);
});

test('connected: the card keeps no title or body from an earlier phase', () => {
  assert.match(popupCss, /body\[data-pair="none"\][^{]*#setup-title[^{]*\{\s*display:\s*none/);
  assert.match(popupCss, /body\[data-pair="none"\][^{]*#pair-body/);
});

test('Arabic sets the document to RTL and keeps the code left-to-right', async () => {
  const popup = await load(stateFor('pending'), { locale: 'ar' });
  assert.equal(popup.title(), msg('pairPendingTitle', 'ar'));
  assert.equal(popup.body.dataset.pair, 'pending');
  assert.match(popupCss, /\.pair-code\s*\{[^}]*direction:\s*ltr/);
});

test('fr, en and ar define exactly the same keys, and every key the popup uses', () => {
  const keys = (l) => Object.keys(locales[l]).sort();
  assert.deepEqual(keys('en'), keys('fr'));
  assert.deepEqual(keys('ar'), keys('fr'));
  const used = new Set([
    ...[...popupSource.matchAll(/\bt\('(\w+)'/g)].map((m) => m[1]),
    ...[...popupSource.matchAll(/'(pair[A-Z]\w+)'/g)].map((m) => m[1]),
    ...[...popupHtml.matchAll(/data-i18n(?:-placeholder|-aria)?="(\w+)"/g)].map((m) => m[1]),
  ]);
  for (const key of used) {
    for (const l of ['fr', 'en', 'ar']) assert.ok(msg(key, l), key + ' missing in ' + l);
  }
  for (const l of ['fr', 'en', 'ar']) {
    assert.match(msg('pairRetryIn', l), /\{time\}/, l);
    for (const [key, value] of Object.entries(locales[l])) assert.ok(value.message.trim(), key + ' empty in ' + l);
  }
});
