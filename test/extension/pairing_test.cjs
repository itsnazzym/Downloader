const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/pairing.js'), 'utf8').replace(/\r\n/g, '\n');
const context = {};
vm.createContext(context);
vm.runInContext(source, context);
const P = context.MDPairing;
const plain = (v) => JSON.parse(JSON.stringify(v));

const NOW = 1_000_000;
const idle = { phase: 'idle' };

test('reconnect: 3 s for the first 5 minutes, then 10 s', () => {
  assert.equal(P.reconnectDelayMs(0, 0), 3000);
  assert.equal(P.reconnectDelayMs(40, 299999), 3000);
  assert.equal(P.reconnectDelayMs(41, 300000), 10000);
  assert.equal(P.reconnectDelayMs(500, 3600000), 10000);
});

test('pairing_required from idle asks for pairing', () => {
  const s = P.next(idle, { type: 'AUTH_FAILED', reason: 'pairing_required', now: NOW });
  assert.equal(s.phase, 'idle');
  assert.equal(P.shouldRequestPairing(s, NOW), true);
  assert.equal(P.shouldRequestPairing(undefined, NOW), true);
});

test('PAIR_PENDING keeps the code (leading zeros too) and the expiry', () => {
  const s = P.next(idle, { type: 'PAIR_PENDING', code: '0042', requestId: 'r1', expiresInSeconds: 120, now: NOW });
  assert.deepEqual(plain(s), { phase: 'pending', code: '0042', requestId: 'r1', until: NOW + 120000 });
  assert.equal(P.shouldRequestPairing(s, NOW), true, 'a new socket re-attaches to the same request');
});

test('PAIR_OK goes back to idle', () => {
  const pending = P.next(idle, { type: 'PAIR_PENDING', code: '1234', requestId: 'r1', expiresInSeconds: 120, now: NOW });
  assert.deepEqual(plain(P.next(pending, { type: 'PAIR_OK', now: NOW })), idle);
});

test('PAIR_DENIED(600) pauses requests until now + 600 s', () => {
  const s = P.next(idle, { type: 'PAIR_DENIED', retryAfterSeconds: 600, now: NOW });
  assert.deepEqual(plain(s), { phase: 'denied', until: NOW + 600000 });
  assert.equal(P.shouldRequestPairing(s, NOW), false);
  assert.equal(P.shouldRequestPairing(s, NOW + 599999), false);
  assert.equal(P.shouldRequestPairing(s, NOW + 600000), true);
});

test('paused, expired and busy each carry an until', () => {
  const paused = P.next(idle, { type: 'PAIR_PAUSED', retryAfterSeconds: 90, now: NOW });
  assert.deepEqual(plain(paused), { phase: 'paused', until: NOW + 90000 });
  const expired = P.next(idle, { type: 'PAIR_EXPIRED', now: NOW });
  assert.deepEqual(plain(expired), { phase: 'expired', until: NOW + 30 * 60000 }, 'no quick re-invite loop');
  const busy = P.next(idle, { type: 'PAIR_BUSY', now: NOW });
  assert.deepEqual(plain(busy), { phase: 'busy', until: NOW + 30000 });
  // The hourly limit is not the user's refusal; an older app sends no reason and stays 'paused'.
  const limited = P.next(idle, { type: 'PAIR_PAUSED', retryAfterSeconds: 1800, reason: 'rate_limited', now: NOW });
  assert.deepEqual(plain(limited), { phase: 'limited', until: NOW + 1800000 });
  [paused, expired, busy, limited].forEach((s) => {
    assert.equal(P.shouldRequestPairing(s, NOW + 1), false);
    assert.equal(P.shouldRequestPairing(s, s.until), true);
  });
});

test('a bare AUTH_FAILED to a HELLO without token means an old app', () => {
  const s = P.next(idle, { type: 'AUTH_FAILED', noToken: true, now: NOW });
  assert.deepEqual(plain(s), { phase: 'update_needed' });
  assert.equal(P.shouldRequestPairing(s, NOW + 1e9), false);
});

test('a bare AUTH_FAILED to a HELLO with a token changes nothing', () => {
  assert.deepEqual(plain(P.next(idle, { type: 'AUTH_FAILED', now: NOW })), idle);
});

test('an updated app (pairing_required) lifts update_needed', () => {
  const s = P.next({ phase: 'update_needed' }, { type: 'AUTH_FAILED', reason: 'pairing_required', now: NOW });
  assert.deepEqual(plain(s), idle);
});

test('RETRY lifts a pause', () => {
  const denied = P.next(idle, { type: 'PAIR_DENIED', retryAfterSeconds: 86400, now: NOW });
  const s = P.next(denied, { type: 'RETRY', now: NOW });
  assert.deepEqual(plain(s), idle);
  assert.equal(P.shouldRequestPairing(s, NOW), true);
});

test('SOCKET_CLOSED drops a pending code but keeps a pause', () => {
  const pending = { phase: 'pending', code: '1234', requestId: 'r', until: NOW + 1000 };
  assert.deepEqual(plain(P.next(pending, { type: 'SOCKET_CLOSED', now: NOW })), idle);
  const denied = { phase: 'denied', until: NOW + 1000 };
  assert.deepEqual(plain(P.next(denied, { type: 'SOCKET_CLOSED', now: NOW })), denied);
});

test('TOKEN_CLEARED keeps a running pause', () => {
  const paused = { phase: 'paused', until: NOW + 1000 };
  assert.deepEqual(plain(P.next(paused, { type: 'TOKEN_CLEARED', now: NOW })), paused);
  assert.equal(P.shouldRequestPairing(P.next(paused, { type: 'TOKEN_CLEARED', now: NOW }), NOW), false);
});

test('missing delays fall back to the 10 minute pause', () => {
  assert.deepEqual(plain(P.next(idle, { type: 'PAIR_DENIED', now: NOW })), { phase: 'denied', until: NOW + 600000 });
});

test('PAIR_PENDING reminders for the same request keep the same state (no storage write)', () => {
  const first = P.next(idle, { type: 'PAIR_PENDING', code: '0042', requestId: 'r1', expiresInSeconds: 120, now: NOW });
  assert.equal(P.next(first, { type: 'PAIR_PENDING', code: '0042', requestId: 'r1', expiresInSeconds: 110, now: NOW + 10000 }), first);
  const other = P.next(first, { type: 'PAIR_PENDING', code: '7777', requestId: 'r2', expiresInSeconds: 120, now: NOW });
  assert.deepEqual(plain(other), { phase: 'pending', code: '7777', requestId: 'r2', until: NOW + 120000 });
});

test('delays from the app are floored at 10 s', () => {
  assert.deepEqual(plain(P.next(idle, { type: 'PAIR_DENIED', retryAfterSeconds: 0, now: NOW })), { phase: 'denied', until: NOW + 10000 });
  assert.equal(P.next(idle, { type: 'PAIR_PENDING', code: '1', requestId: 'r', expiresInSeconds: 1, now: NOW }).until, NOW + 10000);
  assert.deepEqual(plain(P.next(idle, { type: 'PAIR_PAUSED', retryAfterSeconds: -5, now: NOW })), { phase: 'paused', until: NOW + 600000 });
});
