/**
 * TapLoad — pairing state with the desktop app (pure, no browser APIs).
 * Loaded before connection.js in the service worker / Firefox background.
 */
(function (root) {
  'use strict';

  var FAST_RECONNECT_MS = 3000;
  var SLOW_RECONNECT_MS = 10000;
  var FAST_WINDOW_MS = 5 * 60 * 1000;
  var DEFAULT_PAUSE_S = 600; // the app's pause after a refusal
  var MIN_DELAY_S = 10; // a 0 s delay from the app would loop requests
  // PAIR_EXPIRED / PAIR_BUSY carry no delay: no new prompt for 30 min unless Retry (no re-invite loop); busy clears soon.
  var EXPIRED_PAUSE_MS = 30 * 60 * 1000;
  var BUSY_PAUSE_MS = 30 * 1000;
  var PAUSE_PHASES = ['denied', 'paused', 'expired', 'busy'];

  var IDLE = { phase: 'idle' };

  // 3 s for the first 5 minutes the app is unreachable, then 10 s.
  function reconnectDelayMs(attempt, elapsedMs) {
    return elapsedMs < FAST_WINDOW_MS ? FAST_RECONNECT_MS : SLOW_RECONNECT_MS;
  }

  function seconds(value, fallback) {
    var n = Number(value);
    return Number.isFinite(n) && n >= 0 ? Math.max(n, MIN_DELAY_S) : fallback;
  }

  // event.now (ms) dates the pauses; event.noToken = the socket's HELLO carried no token.
  function next(state, event) {
    state = state && state.phase ? state : IDLE;
    var now = (event && event.now) || 0;
    switch (event && event.type) {
      case 'AUTH_FAILED':
        // An up-to-date app answers a tokenless HELLO with pairing_required: a bare refusal is an old app.
        if (!event.reason && event.noToken) return { phase: 'update_needed' };
        // Only an up-to-date app says pairing_required.
        if (event.reason === 'pairing_required' && state.phase === 'update_needed') return IDLE;
        return state;
      case 'PAIR_PENDING':
        // The app repeats PAIR_PENDING every 10 s: same request, same state (and no storage write).
        if (state.phase === 'pending' && state.requestId === event.requestId && state.code === String(event.code || '')) return state;
        return {
          phase: 'pending',
          code: String(event.code || ''),
          requestId: event.requestId,
          until: now + seconds(event.expiresInSeconds, 120) * 1000,
        };
      case 'PAIR_OK':
      case 'RETRY':
        return IDLE;
      case 'PAIR_DENIED':
        return { phase: 'denied', until: now + seconds(event.retryAfterSeconds, DEFAULT_PAUSE_S) * 1000 };
      case 'PAIR_PAUSED':
        return { phase: 'paused', until: now + seconds(event.retryAfterSeconds, DEFAULT_PAUSE_S) * 1000 };
      case 'PAIR_EXPIRED':
        return { phase: 'expired', until: now + EXPIRED_PAUSE_MS };
      case 'PAIR_BUSY':
        return { phase: 'busy', until: now + BUSY_PAUSE_MS };
      case 'SOCKET_CLOSED':
        // The code only means something while the app shows its prompt.
        return state.phase === 'pending' ? IDLE : state;
      case 'TOKEN_CLEARED':
        return state; // a revoked token falls back to pairing, pauses still apply
      default:
        return state;
    }
  }

  function shouldRequestPairing(state, now) {
    if (!state || !state.phase) return true;
    if (state.phase === 'update_needed') return false;
    if (PAUSE_PHASES.indexOf(state.phase) !== -1) return !(state.until > now);
    return true;
  }

  root.MDPairing = {
    reconnectDelayMs: reconnectDelayMs,
    next: next,
    shouldRequestPairing: shouldRequestPairing,
  };
})(typeof globalThis !== 'undefined' ? globalThis : self);
