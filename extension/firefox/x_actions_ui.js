/**
 * Panel-side logic for the X like / bookmark buttons, free of any DOM: the
 * one-time warning, the request through the background, the liked / bookmarked
 * state and the button state. feed_panel.js injects everything it touches.
 */
(function (global) {
  'use strict';

  var TWEET_ID = /^\d{1,25}$/;
  var X_HOST = /^(?:[\w-]+\.)*(?:x|twitter)\.com$/i;
  var TAB_CACHE_MS = 2000;
  var RATE_COOLDOWN_MS = 5000;
  var ACK_KEY = 'xActionsWarningAck';

  // op -> which button it belongs to and the state it leaves behind.
  var OPS = {
    FavoriteTweet: { kind: 'like', field: 'liked', value: true, ok: ['xLikedOk', 'Liké sur X'] },
    UnfavoriteTweet: { kind: 'like', field: 'liked', value: false, ok: ['xUnlikedOk', 'Like retiré'] },
    CreateBookmark: { kind: 'bookmark', field: 'bookmarked', value: true, ok: ['xBookmarkedOk', 'Ajouté aux signets X'] },
    DeleteBookmark: { kind: 'bookmark', field: 'bookmarked', value: false, ok: ['xUnbookmarkedOk', 'Retiré des signets'] },
  };
  var KINDS = {
    like: { field: 'liked', on: 'UnfavoriteTweet', off: 'FavoriteTweet', labelOn: ['xUnlike', 'Retirer le like'], labelOff: ['xLike', 'J’aime sur X'] },
    bookmark: { field: 'bookmarked', on: 'DeleteBookmark', off: 'CreateBookmark', labelOn: ['xUnbookmark', 'Retirer des signets'], labelOff: ['xBookmark', 'Ajouter aux signets X'] },
  };
  var ERRORS = {
    auth: ['xActionAuth', 'Connectez-vous à x.com dans ce navigateur.'],
    rate: ['xActionRate', 'X limite les actions : patientez quelques secondes.'],
    stale: ['xActionStale', 'Rechargez l’onglet x.com.'],
    no_tab: ['xActionNoTab', 'Ouvrez x.com dans ce navigateur.'],
  };
  var FAILED = ['xActionFailed', 'Action impossible pour le moment.'];

  function create(deps) {
    var pending = Object.create(null); // "<id>:<kind>" -> true while a request or a rate cooldown runs
    var tabCache = null;
    var tabCacheAt = -Infinity;
    var acked = false;
    var ackFlight = null;

    function text(pair) { return deps.t(pair[0], pair[1]); }

    function tweetIdOf(item) {
      if (!item) return null;
      var raw = item.tweetId ? String(item.tweetId) : String(item.id || '').split('-')[0];
      return TWEET_ID.test(raw) ? raw : null;
    }

    function isXItem(item) {
      return Boolean(item) && deps.platform(item) === 'x' && tweetIdOf(item) !== null;
    }

    function nextOp(item, kind) {
      var k = KINDS[kind];
      return item && item[k.field] === true ? k.on : k.off;
    }

    function buttonState(item, kind, hasTab) {
      var k = KINDS[kind];
      var pressed = Boolean(item && item[k.field] === true);
      var label = text(pressed ? k.labelOn : k.labelOff);
      var busy = Boolean(pending[(item && item.id) + ':' + kind]);
      var noTab = !hasTab;
      return {
        hidden: !isXItem(item),
        pressed: pressed,
        pending: busy,
        disabled: busy || noTab,
        label: label,
        title: noTab ? deps.t('xOpenXFirst', 'Ouvrez x.com') : label,
      };
    }

    function ensureAck() {
      if (acked) return Promise.resolve(true);
      if (ackFlight) return ackFlight;
      ackFlight = (async function () {
        var stored = false;
        try {
          var saved = await deps.storage.get([ACK_KEY]);
          stored = Boolean(saved) && saved[ACK_KEY] === true;
        } catch (e) { /* unreadable storage: ask again */ }
        if (stored) { acked = true; return true; }
        if ((await deps.confirmWarning()) !== true) return false;
        acked = true;
        try {
          var record = {};
          record[ACK_KEY] = true;
          await deps.storage.set(record);
        } catch (e) { /* asked again next session */ }
        return true;
      })();
      var clear = function () { ackFlight = null; };
      ackFlight.then(clear, clear);
      return ackFlight;
    }

    async function perform(item, op) {
      var spec = OPS[op];
      if (!spec || !isXItem(item)) return;
      var key = item.id + ':' + spec.kind;
      if (pending[key]) return;
      pending[key] = true; // also covers the time the warning is open
      var release = function () { delete pending[key]; deps.refresh(item); };
      var response = null;
      try {
        if (!(await ensureAck())) { release(); return; }
        deps.refresh(item);
        var message = { type: 'MD_X_ACTION', op: op, tweetId: tweetIdOf(item) };
        var tabId = deps.tabId();
        if (typeof tabId === 'number') message.tabId = tabId;
        try { response = await deps.send(message); } catch (e) { response = null; }
      } catch (e) {
        release();
        deps.setStatus(text(FAILED), 'error');
        return;
      }
      var code = response && response.code;
      if (response && response.ok === true && (code === 'ok' || code === 'already')) {
        item[spec.field] = spec.value;
        release();
        deps.setStatus(text(spec.ok), 'success');
        return;
      }
      deps.setStatus(text(ERRORS[code] || FAILED), 'error');
      if (code === 'no_tab') tabCacheAt = -Infinity;
      if (code === 'rate') {
        // Keep the button off for a moment: X is already throttling this account.
        deps.refresh(item);
        deps.delay(release, RATE_COOLDOWN_MS);
      } else {
        release();
      }
    }

    function hasXTab() {
      if (tabCache !== null && deps.now() - tabCacheAt <= TAB_CACHE_MS) return Promise.resolve(tabCache);
      return Promise.resolve().then(function () { return deps.queryTabs(); }).then(function (tabs) {
        return (tabs || []).some(function (tab) {
          try { return X_HOST.test(new URL(tab.url || '').hostname); } catch (e) { return false; }
        });
      }, function () { return false; }).then(function (found) {
        tabCache = found;
        tabCacheAt = deps.now();
        return found;
      });
    }

    return {
      tweetIdOf: tweetIdOf,
      isXItem: isXItem,
      nextOp: nextOp,
      buttonState: buttonState,
      ensureAck: ensureAck,
      perform: perform,
      hasXTab: hasXTab,
      xTabKnown: function () { return tabCache === true; },
      invalidateTabs: function () { tabCacheAt = -Infinity; },
    };
  }

  global.MDXActionsUi = { create: create };
})(typeof self !== 'undefined' ? self : this);
