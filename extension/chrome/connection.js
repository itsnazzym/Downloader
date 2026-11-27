/**
 * TapLoad — WebSocket connection client.
 * Runs in Chrome offscreen document or Firefox background.
 */
(function () {
  'use strict';

  var api = typeof MD_API !== 'undefined' ? MD_API : (typeof browser !== 'undefined' ? browser : chrome);
  var action = typeof MD_ACTION !== 'undefined' ? MD_ACTION : (api.action || api.browserAction);

  var SUPPORTED_DOMAINS = MDUrl.SUPPORTED_DOMAINS;
  var ADULT_DOMAINS = MDUrl.ADULT_DOMAINS;
  var ALLOWED_OPTION_KEYS = ['isAudioOnly', 'preferredQuality', 'isPlaylist'];
  var HELLO_TIMEOUT_MS = 2000;

  var hostMatchesDomain = MDUrl.hostMatchesDomain;
  var isSupportedDomain = MDUrl.isSupportedDomain;
  var isSafeHttpUrl = MDUrl.isSafeHttpUrl;
  var isRestrictedPageUrl = MDUrl.isRestrictedPageUrl;
  var setConnected = MDBadge.setConnected;
  var updateActiveBadge = MDBadge.updateActiveBadge;

  function sanitizeOptions(options) {
    var safe = {};
    if (!options || typeof options !== 'object') return safe;
    ALLOWED_OPTION_KEYS.forEach(function (key) {
      if (Object.prototype.hasOwnProperty.call(options, key)) {
        safe[key] = options[key];
      }
    });
    return safe;
  }

  function getManifestVersion() {
    try {
      return api.runtime.getManifest().version || '2.0.0';
    } catch (e) {
      return '2.0.0';
    }
  }

    // ==========================================
  // Full connection (Chrome SW / Firefox)
  // ==========================================
  var serverPort = 6969;
  var apiToken = '';
  var socket = null;
  var isConnected = false;
  var reconnectTimer = null;
  var reconnectAttempt = 0;
  var unreachableSince = 0;
  var pairingState = { phase: 'idle' };
  var pairRequested = false; // a PAIR_REQUEST went out on the current socket
  var authRefused = false; // the app refused the current socket: retrying fast cannot help
  var cookieDebounce = null;
  var cookieDebounceByDomain = {};
  var pendingDownloadAcks = [];
  var pendingCorrelated = {};
  var activeDownloadCount = 0;
  var adultSitesEnabled = true;
  var nextRequestId = 1;
  var DOWNLOADED_KEYS_CAP = 4000;
  var DOWNLOAD_STATUS_COMPLETED = 4;
  var DOWNLOAD_STATUS_FAILED = 5;
  var DOWNLOAD_STATUS_CANCELED = 6;
  var DOWNLOAD_STATUS_DUPLICATE = 8;
  var DOWNLOAD_COMMANDS = ['cancel', 'pause', 'resume', 'retry', 'cancel_all'];

  function scheduleReconnect() {
    if (reconnectTimer) return;
    var now = Date.now();
    if (!unreachableSince) unreachableSince = now;
    // After a refusal, during a pause or with an old app there is nothing to ask: always the slow pace.
    var slow = authRefused || !MDPairing.shouldRequestPairing(pairingState, now);
    var elapsed = slow ? Infinity : now - unreachableSince;
    reconnectTimer = setTimeout(function () {
      reconnectTimer = null;
      connect();
    }, MDPairing.reconnectDelayMs(reconnectAttempt++, elapsed));
  }

  function clearReconnect() {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
      reconnectTimer = null;
    }
    reconnectAttempt = 0;
    unreachableSince = 0;
  }

  // storage.local.pairing is what the popup shows; an idle state is stored as no key.
  function setPairing(state) {
    if (state === pairingState) return;
    var wasPending = pairingState.phase === 'pending';
    pairingState = state;
    try {
      var write = state.phase === 'idle'
        ? api.storage.local.remove(['pairing'])
        : api.storage.local.set({ pairing: state });
      if (write && typeof write.catch === 'function') write.catch(function () {});
    } catch (e) { /* storage unavailable while reloading */ }
    if (state.phase !== 'pending' && !wasPending) return;
    try {
      if (action && action.setBadgeText) action.setBadgeText({ text: state.phase === 'pending' ? '?' : '' });
    } catch (e) { /* chrome.action is restricted outside service workers */ }
  }

  function pairingEvent(event) {
    event.now = Date.now();
    setPairing(MDPairing.next(pairingState, event));
  }

  // One request per socket, never during a pause (the app would refuse it anyway).
  function requestPairing() {
    if (pairRequested || !socket || socket.readyState !== WebSocket.OPEN) return false;
    if (!MDPairing.shouldRequestPairing(pairingState, Date.now())) return false;
    pairRequested = true;
    socket.send(JSON.stringify({ type: 'PAIR_REQUEST', extensionVersion: getManifestVersion() }));
    logDiag('PAIR_REQUEST', 'sent');
    return true;
  }

  function publishConnectionState() {
    setConnected(isConnected);
    try {
      var pending = api.runtime.sendMessage({
        type: 'MD_CONNECTION_STATE',
        connected: isConnected,
        activeCount: activeDownloadCount,
      });
      if (pending && typeof pending.catch === 'function') {
        pending.catch(function () {});
      }
    } catch (e) {
      /* SW may be asleep */
    }
  }

  // Callers waiting on the app (ACKs, feed results) must not outlive their socket: the answer can
  // never come, and a stale ACK resolver would swallow the next socket's ACK.
  function failPending() {
    pendingDownloadAcks.splice(0).forEach(function (finish) { finish({ ok: false, error: 'app_offline' }); });
    Object.keys(pendingCorrelated).forEach(function (requestId) {
      var finish = pendingCorrelated[requestId];
      delete pendingCorrelated[requestId];
      finish({ ok: false, error: 'app_offline', requestId: requestId });
    });
  }

  function closeSocketQuietly() {
    if (!socket) return;
    failPending();
    try {
      socket.onclose = null;
      socket.onerror = null;
      socket.onmessage = null;
      socket.close();
    } catch (e) {
      /* ignore */
    }
    socket = null;
  }

  function logDiag(event, data) {
    try {
      api.storage.local.get(['_mdDiag']).then(function (res) {
        var logs = (res && res._mdDiag) || [];
        logs.push({
          t: new Date().toISOString().substring(11, 19),
          e: event,
          d: String(data || ''),
        });
        if (logs.length > 40) logs = logs.slice(logs.length - 40);
        api.storage.local.set({ _mdDiag: logs }).catch(function () {});
      }).catch(function () {});
    } catch (e) {}
  }

  function connect() {
    api.storage.local.get(['serverPort', 'apiToken', 'adultSitesEnabled', 'pairing']).then(function (res) {
      serverPort = parseInt(res.serverPort, 10) || 6969;
      if (serverPort < 1024 || serverPort > 65535) {
        console.warn('Invalid server port; using 6969');
        serverPort = 6969;
      }
      apiToken = res.apiToken || '';
      adultSitesEnabled = res.adultSitesEnabled !== false;
      // The service worker restarts often: a pause must outlive it.
      pairingState = res.pairing && res.pairing.phase ? res.pairing : { phase: 'idle' };

      closeSocketQuietly();
      pairRequested = false;
      authRefused = false;
      logDiag('CONNECT_START', 'port=' + serverPort + ' tokenLen=' + apiToken.length);
      console.log('Connecting to TapLoad on 127.0.0.1:' + serverPort + '...');

      try {
        // Token is NOT placed in the URL — only sent in HELLO.
        socket = new WebSocket('ws://127.0.0.1:' + serverPort + '/');

        var helloTimer = setTimeout(function () {
          if (!isConnected && socket) {
            logDiag('HELLO_TIMEOUT', 'No HELLO_OK received');
            console.warn('HELLO handshake timed out');
            try { socket.close(); } catch (e) { /* ignore */ }
          }
        }, HELLO_TIMEOUT_MS + 1000);

        socket.onopen = function () {
          clearTimeout(helloTimer);
          unreachableSince = 0;
          logDiag('WS_OPEN', 'Sending HELLO');
          var version = getManifestVersion();
          socket.send(JSON.stringify({
            type: 'HELLO',
            version: version,
            token: apiToken,
          }));
          // Sent right away: an old app answers this HELLO with a bare AUTH_FAILED, which then reads as "update the app".
          if (!apiToken) requestPairing();
        };

        socket.onclose = function (event) {
          clearTimeout(helloTimer);
          logDiag('WS_CLOSE', 'code=' + (event ? event.code : 'unknown'));
          console.log('Disconnected from App. Reconnecting...');
          isConnected = false;
          pairingEvent({ type: 'SOCKET_CLOSED' }); // before publishConnectionState, whose OFF badge must win
          socket = null;
          activeDownloadCount = 0; // the app's queue is unknown until it is back
          failPending();
          publishConnectionState();
          scheduleReconnect();
        };

        socket.onmessage = function (event) {
          try {
            var message = JSON.parse(event.data);
            handleAppMessage(message);
          } catch (e) {
            console.error('Failed to parse app message', e);
          }
        };

        socket.onerror = function () {
          logDiag('WS_OFFLINE', 'ReadyState=' + (socket ? socket.readyState : 'null'));
          console.debug('TapLoad desktop app is offline or unreachable on ws://127.0.0.1:' + serverPort);
        };
      } catch (e) {
        logDiag('WS_CONNECT_IDLE', (e && e.message) || String(e));
        console.debug('WebSocket connection attempt idle (desktop app offline):', (e && e.message) || String(e));
        scheduleReconnect();
      }
    }).catch(function (e) {
      logDiag('SETTINGS_ERR', (e && e.message) || String(e));
      console.warn('Failed to read settings for connect', e);
      scheduleReconnect();
    });
  }

  function handleAppMessage(message) {
    if (!message || !message.type) return;

    if (message.type === 'HELLO_OK') {
      isConnected = true;
      clearReconnect();
      api.storage.local.remove(['lastAuthError']);
      if (pairingState.phase !== 'idle') setPairing({ phase: 'idle' }); // e.g. a manual token typed during a pause
      publishConnectionState();
      logDiag('HELLO_OK', 'Connected successfully');
      console.log('Connected to TapLoad App');
      requestLibraryKeys();
      requestQueueSnapshot();
      api.storage.local.get(['autoSendCookies']).then(function (cookieRes) {
        if (cookieRes.autoSendCookies !== false) {
          setTimeout(sendCurrentTabCookies, 2000);
        }
      }).catch(function (e) {
        logDiag('COOKIE_PREF_ERR', (e && e.message) || String(e));
      });
      return;
    }

    if (message.type === 'AUTH_FAILED') {
      // Something sent while the app waits for the user's answer: the request stays valid.
      if (pairRequested && message.reason === 'not_authenticated') return;
      isConnected = false;
      publishConnectionState();
      var reason = message.reason || 'auth_failed';
      var hadToken = !!apiToken;
      api.storage.local.set({ lastAuthError: reason });
      logDiag('AUTH_FAILED', reason);
      pairingEvent({ type: 'AUTH_FAILED', reason: message.reason, hadToken: hadToken, requested: pairRequested });
      if (message.reason === 'pairing_required') {
        if (hadToken) {
          // Only an up-to-date app says this: the stored token was revoked.
          apiToken = '';
          api.storage.local.remove(['apiToken']);
          pairingEvent({ type: 'TOKEN_CLEARED' });
        }
        if (requestPairing() || pairRequested) return; // keep the socket open for the answer
      } else {
        console.warn('Auth failed — check token in extension popup');
      }
      authRefused = true;
      try { if (socket) socket.close(); } catch (e) { /* ignore */ }
      return;
    }

    if (message.type === 'PAIR_PENDING' || message.type === 'PAIR_DENIED' || message.type === 'PAIR_PAUSED' ||
        message.type === 'PAIR_EXPIRED' || message.type === 'PAIR_BUSY') {
      logDiag(message.type, ''); // never the code
      pairingEvent({
        type: message.type,
        code: message.code,
        requestId: message.requestId,
        expiresInSeconds: message.expiresInSeconds,
        retryAfterSeconds: message.retryAfterSeconds,
      });
      return;
    }

    if (message.type === 'PAIR_OK') {
      if (typeof message.token !== 'string' || !message.token) return;
      logDiag('PAIR_OK', 'paired');
      pairingEvent({ type: 'PAIR_OK' });
      api.storage.local.set({ apiToken: message.token }).then(function () {
        clearReconnect(); // the app closes this socket after its answer
        connect();
      }).catch(function (e) {
        logDiag('PAIR_TOKEN_ERR', (e && e.message) || String(e));
      });
      return;
    }

    if (message.type === 'PONG') {
      api.storage.local.set({ lastPongAt: Date.now() });
      return;
    }

    if (message.type === 'ACK') {
      var resolver = pendingDownloadAcks.shift();
      if (resolver) {
        resolver({
          ok: message.ok !== false,
          error: message.error,
          message: message.message || 'ok',
        });
      }
      return;
    }

    if (message.type === 'X_FEED_RESULT') {
      var feedRequestId = message.requestId;
      if (feedRequestId != null && pendingCorrelated[feedRequestId]) {
        var finishFeed = pendingCorrelated[feedRequestId];
        delete pendingCorrelated[feedRequestId];
        finishFeed(message);
      }
      return;
    }

    if (message.type === 'THEME') {
      var theme = Object.assign({}, message);
      delete theme.type;
      api.storage.local.set({ appTheme: theme }).catch(function () {});
      return;
    }

    if (message.type === 'LIBRARY_KEYS_RESULT') {
      if (message.ok !== false) {
        mergeDownloadedKeys(message.tweetIds, message.mediaIds, message.tikTokIds);
      }
      return;
    }

    if (message.type === 'REQUEST_TIKTOK_COLLECTIONS_SYNC') {
      syncTikTokCollections(message.requestId);
      return;
    }

    if (message.type === 'TIKTOK_COLLECTIONS_SYNC_ACK') {
      logDiag('TIKTOK_SYNC_ACK', 'ok=' + message.ok + ' count=' + message.collectionCount);
      try {
        api.runtime.sendMessage({
          type: 'MD_TIKTOK_COLLECTIONS_SYNC_ACK',
          ok: message.ok,
          count: message.collectionCount,
          error: message.error,
        }).catch(function () {});
      } catch (e) {}
      return;
    }

    if (message.type === 'QUEUE_SNAPSHOT') {
      relayToPanel({
        type: 'MD_QUEUE_SNAPSHOT',
        items: Array.isArray(message.items) ? message.items.map(sanitizeProgress) : [],
      });
      return;
    }

    if (message.type === 'DOWNLOAD_COMMAND_RESULT') {
      relayToPanel({
        type: 'MD_DOWNLOAD_COMMAND_RESULT',
        ok: message.ok === true,
        command: message.command,
        id: message.id,
        error: message.error,
      });
      return;
    }

    if (message.type === 'PROGRESS') {
      var item = message.data || {};
      var sanitized = sanitizeProgress(item);
      updateBadgeFromProgress(sanitized);
      recordProgressDownloadKeys(item);

      // Notify feed panel / UI in real time
      try {
        var progressPromise = api.runtime.sendMessage({
          type: 'MD_DOWNLOAD_PROGRESS',
          data: sanitized,
        });
        if (progressPromise && typeof progressPromise.catch === 'function') {
          progressPromise.catch(function () {});
        }
      } catch (e) {}

      api.storage.local.get(['recentDownloads']).then(function (result) {
        var recents = result.recentDownloads || [];
        var idx = recents.findIndex(function (r) { return r.id === sanitized.id; });
        if (idx >= 0) recents[idx] = sanitized;
        else recents.unshift(sanitized);
        recents = recents.slice(0, 10);
        activeDownloadCount = recents.filter(function (r) {
          return r.status === 1 || r.status === 2 || r.status === 3;
        }).length;
        publishConnectionState();
        return api.storage.local.set({ recentDownloads: recents });
      }).catch(function (e) {
        logDiag('RECENTS_ERR', (e && e.message) || String(e));
      });
    }
  }

  function tweetIdFromUrl(value) {
    if (!isSafeHttpUrl(value)) return null;
    try {
      var url = new URL(value);
      var match = url.pathname.match(
        /^\/(?:[^/]+\/status|i\/(?:web\/)?status)\/(\d{15,20})/,
      );
      return match ? match[1] : null;
    } catch (e) {
      return null;
    }
  }

  function mediaAssetIdFrom(value) {
    if (!value || typeof value !== 'string') return null;
    var match = value.match(
      /\/(?:ext_tw_video(?:_thumb)?|amplify_video(?:_thumb)?|tweet_video(?:_thumb)?)\/(\d{15,20})(?:\/|\.|$)/i,
    );
    return match ? match[1] : null;
  }

  function tikTokIdFromUrl(value) {
    if (!value || typeof value !== 'string') return null;
    try {
      var match = value.match(/(?:video|v)\/(\d{15,25})/);
      if (match) return match[1];
      var xgMatch = value.match(/xgwrapper-\d+-(\d{15,25})/);
      if (xgMatch) return xgMatch[1];
      var ttPrefix = value.match(/^tt-(\d{15,25})$/);
      if (ttPrefix) return ttPrefix[1];
      if (/^\d{15,25}$/.test(value.trim())) return value.trim();
      return null;
    } catch (e) {
      return null;
    }
  }

  function uniqueCap(values, cap) {
    var seen = {};
    var out = [];
    (Array.isArray(values) ? values : []).forEach(function (raw) {
      var id = String(raw || '').trim();
      if (!/^\d{5,25}$/.test(id) || seen[id]) return;
      seen[id] = true;
      out.push(id);
    });
    if (out.length <= cap) return out;
    return out.slice(out.length - cap);
  }

  function sanitizeIdList(values) {
    return uniqueCap(values, DOWNLOADED_KEYS_CAP);
  }

  function broadcastDownloadState(payload) {
    if (!api.tabs || !api.tabs.query) return;
    var query = { url: ['http://*/*', 'https://*/*'] };
    var send = function (tabs) {
      (tabs || []).forEach(function (tab) {
        if (typeof tab.id !== 'number') return;
        try {
          var pending = api.tabs.sendMessage(tab.id, payload);
          if (pending && typeof pending.catch === 'function') {
            pending.catch(function () {
              /* Tab has no content script. */
            });
          }
        } catch (e) {
          /* Ignore missing receivers. */
        }
      });
    };
    try {
      var result = api.tabs.query(query);
      if (result && typeof result.then === 'function') {
        result.then(send).catch(function () { /* ignore */ });
      }
    } catch (e) {
      /* tabs.query may be unavailable */
    }
  }

  function mergeDownloadedKeys(tweetIds, mediaIds, tikTokIds) {
    var addedTweets = sanitizeIdList(tweetIds);
    var addedMedia = sanitizeIdList(mediaIds);
    var addedTikToks = sanitizeIdList(tikTokIds);
    if (addedTweets.length === 0 && addedMedia.length === 0 && addedTikToks.length === 0) {
      return Promise.resolve();
    }
    return api.storage.local.get(['downloadedKeys']).then(function (result) {
      var current = result.downloadedKeys || {};
      var next = {
        tweetIds: uniqueCap(
          [].concat(current.tweetIds || [], addedTweets),
          DOWNLOADED_KEYS_CAP,
        ),
        mediaIds: uniqueCap(
          [].concat(current.mediaIds || [], addedMedia),
          DOWNLOADED_KEYS_CAP,
        ),
        tikTokIds: uniqueCap(
          [].concat(current.tikTokIds || [], addedTikToks),
          DOWNLOADED_KEYS_CAP,
        ),
      };
      return api.storage.local.set({ downloadedKeys: next }).then(function () {
        broadcastDownloadState({
          type: 'MD_DOWNLOAD_STATE',
          tweetIds: addedTweets,
          mediaIds: addedMedia,
          tikTokIds: addedTikToks,
          removedTweetIds: [],
          removedTikTokIds: [],
        });
      });
    }).catch(function (e) {
      console.warn('Could not persist downloaded keys', e && e.message);
    });
  }

  function removeDownloadedTweetIds(tweetIds) {
    var removed = sanitizeIdList(tweetIds);
    if (removed.length === 0) return Promise.resolve();
    var removedSet = {};
    removed.forEach(function (id) { removedSet[id] = true; });
    return api.storage.local.get(['downloadedKeys']).then(function (result) {
      var current = result.downloadedKeys || {};
      var nextTweets = (current.tweetIds || []).filter(function (id) {
        return !removedSet[id];
      });
      var next = {
        tweetIds: nextTweets,
        mediaIds: current.mediaIds || [],
        tikTokIds: current.tikTokIds || [],
      };
      return api.storage.local.set({ downloadedKeys: next }).then(function () {
        broadcastDownloadState({
          type: 'MD_DOWNLOAD_STATE',
          tweetIds: [],
          mediaIds: [],
          tikTokIds: [],
          removedTweetIds: removed,
          removedTikTokIds: [],
        });
      });
    }).catch(function (e) {
      console.warn('Could not update downloaded keys', e && e.message);
    });
  }

  function removeDownloadedTikTokIds(tikTokIds) {
    var removed = sanitizeIdList(tikTokIds);
    if (removed.length === 0) return Promise.resolve();
    var removedSet = {};
    removed.forEach(function (id) { removedSet[id] = true; });
    return api.storage.local.get(['downloadedKeys']).then(function (result) {
      var current = result.downloadedKeys || {};
      var nextTikToks = (current.tikTokIds || []).filter(function (id) {
        return !removedSet[id];
      });
      var next = {
        tweetIds: current.tweetIds || [],
        mediaIds: current.mediaIds || [],
        tikTokIds: nextTikToks,
      };
      return api.storage.local.set({ downloadedKeys: next }).then(function () {
        broadcastDownloadState({
          type: 'MD_DOWNLOAD_STATE',
          tweetIds: [],
          mediaIds: [],
          tikTokIds: [],
          removedTweetIds: [],
          removedTikTokIds: removed,
        });
      });
    }).catch(function (e) {
      console.warn('Could not update downloaded keys', e && e.message);
    });
  }

  function recordProgressDownloadKeys(item) {
    var status = item && item.status;
    var tweetId = item.tweetId || tweetIdFromUrl(item.url);
    var mediaId = item.mediaId || mediaAssetIdFrom(item.url);
    var tikTokId = item.tikTokId || tikTokIdFromUrl(item.url);
    if (status === DOWNLOAD_STATUS_COMPLETED || status === DOWNLOAD_STATUS_DUPLICATE) {
      mergeDownloadedKeys(
        tweetId ? [tweetId] : [],
        mediaId ? [mediaId] : [],
        tikTokId ? [tikTokId] : [],
      );
      return;
    }
    if (status === DOWNLOAD_STATUS_FAILED || status === DOWNLOAD_STATUS_CANCELED) {
      if (tweetId) removeDownloadedTweetIds([tweetId]);
      if (tikTokId) removeDownloadedTikTokIds([tikTokId]);
    }
  }

  function requestLibraryKeys() {
    if (!isConnected || !socket || socket.readyState !== WebSocket.OPEN) return;
    try {
      socket.send(JSON.stringify({ type: 'LIBRARY_KEYS' }));
    } catch (e) {
      /* ignore */
    }
  }

  // Only these progress fields ever leave the background (no cookies / paths).
  function sanitizeProgress(item) {
    item = item || {};
    return {
      id: item.id,
      title: item.title,
      status: item.status,
      progress: item.progress,
      speed: item.speed,
      totalSize: item.totalSize,
      downloadedSize: item.downloadedSize,
      eta: item.eta,
      error: item.error,
      url: item.url,
      tweetId: item.tweetId,
      mediaId: item.mediaId,
      tikTokId: item.tikTokId,
    };
  }

  function relayToPanel(payload) {
    try {
      var pending = api.runtime.sendMessage(payload);
      if (pending && typeof pending.catch === 'function') {
        pending.catch(function () { /* No feed panel is open. */ });
      }
    } catch (e) {
      /* Ignore messages while the extension is reloading. */
    }
  }

  // Returns false when the app is not connected and authenticated.
  function sendToApp(payload) {
    if (!isConnected || !socket || socket.readyState !== WebSocket.OPEN) return false;
    try {
      socket.send(JSON.stringify(payload));
      return true;
    } catch (e) {
      return false;
    }
  }

  // A content script's sender.url is the page URL, so it never matches the extension origin.
  function isExtensionPage(sender) {
    try {
      var origin = api.runtime.getURL('');
      return !!sender && !!origin && sender.id === api.runtime.id &&
        typeof sender.url === 'string' && sender.url.indexOf(origin) === 0;
    } catch (e) {
      return false;
    }
  }

  function requestQueueSnapshot() {
    return sendToApp({ type: 'QUEUE_SNAPSHOT_REQUEST' });
  }

  function sendDownloadCommand(command, id) {
    if (DOWNLOAD_COMMANDS.indexOf(command) === -1) return { ok: false, error: 'unknown_command' };
    var payload = { type: 'DOWNLOAD_COMMAND', command: command };
    if (command !== 'cancel_all') payload.id = String(id || '');
    return sendToApp(payload) ? { ok: true, sent: true } : { ok: false, error: 'not_connected' };
  }

  function updateBadgeFromProgress(item) {
    if (!isConnected) return;
    if (item.status === 1 || item.status === 2 || item.status === 3) {
      updateActiveBadge(Math.max(activeDownloadCount, 1));
    } else if (item.status === 4) {
      updateActiveBadge(activeDownloadCount);
    }
  }

  function formatCookiesToNetscape(cookies) {
    var sb = '# Netscape HTTP Cookie File\n';
    sb += '# This file was generated by TapLoad Extension\n\n';
    for (var i = 0; i < cookies.length; i++) {
      var cookie = cookies[i];
      var domain = cookie.domain;
      var flag = domain.startsWith('.') ? 'TRUE' : 'FALSE';
      var path = cookie.path;
      var secure = cookie.secure ? 'TRUE' : 'FALSE';
      var expiration = Math.floor(cookie.expirationDate || (Date.now() / 1000 + 31536000));
      sb += domain + '\t' + flag + '\t' + path + '\t' + secure + '\t' +
        expiration + '\t' + cookie.name + '\t' + cookie.value + '\n';
    }
    return sb;
  }

  async function detectBrowser() {
    var res = await api.storage.local.get(['preferredBrowser']);
    if (res.preferredBrowser && res.preferredBrowser !== 'auto') {
      return res.preferredBrowser;
    }
    var ua = navigator.userAgent.toLowerCase();
    if (ua.indexOf('edg/') !== -1) return 'edge';
    if (ua.indexOf('opr/') !== -1 || ua.indexOf('opera') !== -1) return 'opera';
    if (ua.indexOf('vivaldi') !== -1) return 'vivaldi';
    if (ua.indexOf('firefox') !== -1) return 'firefox';
    try {
      if (navigator.brave && await navigator.brave.isBrave()) return 'brave';
    } catch (e) { /* ignore */ }
    return 'chrome';
  }

  async function getCookiesForPageUrl(pageUrl) {
    if (!api.cookies || !isSafeHttpUrl(pageUrl)) return [];
    try {
      // Prefer url-scoped getAll so host-only and .domain cookies are included.
      var byUrl = await api.cookies.getAll({ url: pageUrl });
      if (byUrl && byUrl.length) return byUrl;
    } catch (e) {
      console.warn('cookies.getAll failed for page');
    }
    try {
      var hostname = new URL(pageUrl).hostname.replace(/^www\./i, '');
      var byDomain = await api.cookies.getAll({ domain: hostname });
      if (byDomain && byDomain.length) return byDomain;
    } catch (e2) {
      /* domain-scoped lookup is a fallback only */
    }
    return [];
  }

  function waitForAck(timeoutMs) {
    return new Promise(function (resolve) {
      var settled = false;
      var timer = setTimeout(function () {
        if (settled) return;
        settled = true;
        var idx = pendingDownloadAcks.indexOf(finish);
        if (idx >= 0) pendingDownloadAcks.splice(idx, 1);
        resolve({ ok: false, error: 'ack_timeout' });
      }, timeoutMs || 5000);

      function finish(result) {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        resolve(result);
      }
      pendingDownloadAcks.push(finish);
    });
  }

  function waitForCorrelatedResponse(requestId, timeoutMs) {
    return new Promise(function (resolve) {
      var settled = false;
      var timer = setTimeout(function () {
        if (settled) return;
        settled = true;
        delete pendingCorrelated[requestId];
        resolve({ ok: false, error: 'request_timeout', requestId: requestId });
      }, timeoutMs || 20000);

      pendingCorrelated[requestId] = function (result) {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        resolve(result || { ok: false, error: 'empty_result' });
      };
    });
  }

  async function requestXFeedFromApp(maxItems) {
    if (!isConnected || !socket || socket.readyState !== WebSocket.OPEN) {
      return { ok: false, error: 'app_offline' };
    }

    // Refresh X session cookies even if the sidebar/popup stole tab focus.
    try {
      await sendHeartbeatForUrl('https://x.com/home');
      await sendHeartbeatForUrl('https://twitter.com/home');
      await sendCurrentTabCookies();
      await new Promise(function (resolve) {
        setTimeout(resolve, 250);
      });
    } catch (e) {
      console.warn('Could not refresh X session heartbeat');
    }

    var requestId = 'xf-' + String(nextRequestId++) + '-' + Date.now();
    var count = parseInt(maxItems, 10);
    if (!Number.isFinite(count) || count < 1) count = 10000;
    if (count > 10000) count = 10000;

    try {
      var waitPromise = waitForCorrelatedResponse(requestId, 13 * 60 * 1000);
      socket.send(JSON.stringify({
        type: 'X_FEED_REQUEST',
        requestId: requestId,
        count: count,
        // Never attach cookies on this channel.
      }));
      var result = await waitPromise;
      if (!result || typeof result !== 'object') {
        return { ok: false, error: 'empty_result' };
      }
      return result;
    } catch (e) {
      return { ok: false, error: (e && e.message) || 'error' };
    }
  }

  function isXCdnHost(hostname) {
    return hostMatchesDomain(hostname, 'twimg.com') ||
      hostMatchesDomain(hostname, 'pscp.tv');
  }

  function xStatusPermalink(value) {
    return MDUrl.isXStatusPermalink(value);
  }

  function canonicalizeXDownloadUrl(mediaUrl, pageUrl) {
    return resolveXDownloadUrl(mediaUrl, pageUrl) || mediaUrl;
  }

  function isXCdnUrl(value) {
    if (!isSafeHttpUrl(value)) return false;
    try {
      return isXCdnHost(new URL(value).hostname);
    } catch (e) {
      return false;
    }
  }

  function resolveXDownloadUrl(mediaUrl, pageUrl) {
    try {
      var permalink = xStatusPermalink(mediaUrl);
      if (permalink) return permalink;
      if (isXCdnUrl(mediaUrl)) {
        return xStatusPermalink(pageUrl);
      }
      return mediaUrl;
    } catch (e) {
      return mediaUrl;
    }
  }

  async function resolvePermalinkFromTab(tab, srcUrl) {
    if (!tab || typeof tab.id !== 'number' || !api.tabs || !api.tabs.sendMessage) {
      return null;
    }
    try {
      var response = await api.tabs.sendMessage(tab.id, {
        type: 'MD_RESOLVE_X_PERMALINK',
        srcUrl: srcUrl || '',
      });
      if (response && response.ok && isSafeHttpUrl(response.url)) {
        return response.url;
      }
    } catch (e) {
      /* content script may be missing on this tab */
    }
    return null;
  }

  function isAllowedDownloadUrl(value) {
    if (isXCdnUrl(value)) return false;
    return MDUrl.isAllowedDownloadUrl(value, adultSitesEnabled);
  }

  async function handleDownloadRequest(mediaUrl, pageUrl, options, hints) {
    if (!isSafeHttpUrl(mediaUrl)) {
      return { ok: false, error: 'invalid_url' };
    }
    if (!isConnected || !socket || socket.readyState !== WebSocket.OPEN) {
      return { ok: false, error: 'app_offline' };
    }

    try {
      var extra = hints && typeof hints === 'object' ? hints : {};
      var safePage = isSafeHttpUrl(pageUrl) ? pageUrl : mediaUrl;
      var downloadUrl = resolveXDownloadUrl(mediaUrl, safePage);
      if (!downloadUrl || isXCdnUrl(downloadUrl)) {
        return { ok: false, error: 'need_tweet_url' };
      }
      if (!isSafeHttpUrl(downloadUrl)) {
        return { ok: false, error: 'invalid_url' };
      }
      if (!isAllowedDownloadUrl(downloadUrl)) {
        return { ok: false, error: 'unsupported_url' };
      }
      var cookies = await getCookiesForPageUrl(safePage);
      var cookieString = formatCookiesToNetscape(cookies);
      var detectedBrowser = await detectBrowser();
      var safeOpts = sanitizeOptions(options);

      var payload = {
        type: 'DOWNLOAD',
        url: downloadUrl,
        cookies: cookieString,
        userAgent: navigator.userAgent,
        referrer: safePage,
        cookieBrowser: detectedBrowser,
        token: apiToken,
        isAudioOnly: !!safeOpts.isAudioOnly,
        isPlaylist: !!safeOpts.isPlaylist,
      };
      if (safeOpts.preferredQuality) {
        payload.preferredQuality = safeOpts.preferredQuality;
      }

      if (!socket || socket.readyState !== WebSocket.OPEN) return { ok: false, error: 'app_offline' }; // closed while cookies loaded
      var ackPromise = waitForAck(5000);
      socket.send(JSON.stringify(payload));
      // Do not log cookies, token, or UA.
      console.log('Sent download request for', downloadUrl);
      var ack = await ackPromise;
      if (ack && ack.ok) {
        var tweetId = extra.tweetId ||
          tweetIdFromUrl(downloadUrl) ||
          tweetIdFromUrl(safePage);
        var mediaId = extra.mediaId ||
          mediaAssetIdFrom(extra.thumbnailUrl) ||
          mediaAssetIdFrom(downloadUrl);
        var tikTokId = extra.tikTokId ||
          tikTokIdFromUrl(downloadUrl) ||
          tikTokIdFromUrl(safePage);
        mergeDownloadedKeys(
          tweetId ? [tweetId] : [],
          mediaId ? [mediaId] : [],
          tikTokId ? [tikTokId] : [],
        );
      }
      return ack;
    } catch (e) {
      console.error('Error processing download request', e && e.message);
      return { ok: false, error: (e && e.message) || 'error' };
    }
  }

  async function sendHeartbeatForUrl(pageUrl) {
    if (!isConnected || !socket || socket.readyState !== WebSocket.OPEN) return;
    if (!isSafeHttpUrl(pageUrl)) return;
    var hostname;
    try {
      hostname = new URL(pageUrl).hostname;
    } catch (e) {
      return;
    }
    if (!isSupportedDomain(hostname, adultSitesEnabled)) return;

    var res = await api.storage.local.get(['autoSendCookies']);
    if (res.autoSendCookies === false) return;

    var cookies = await getCookiesForPageUrl(pageUrl);
    var cookieString = formatCookiesToNetscape(cookies);
    // Use registrable-ish domain for server-side per-domain files.
    var domainKey = SUPPORTED_DOMAINS.concat(adultSitesEnabled ? ADULT_DOMAINS : []).find(function (d) {
      return hostMatchesDomain(hostname, d);
    }) || hostname;

    socket.send(JSON.stringify({
      type: 'HEARTBEAT_COOKIES',
      domain: domainKey,
      cookies: cookieString,
      token: apiToken,
    }));
    console.log('Sent session heartbeat for', domainKey);
  }

  async function sendCurrentTabCookies() {
    try {
      if (!api.tabs) return;
      var tabs = await api.tabs.query({ active: true, currentWindow: true });
      var tab = tabs && tabs[0];
      if (tab && tab.url && !isRestrictedPageUrl(tab.url)) {
        await sendHeartbeatForUrl(tab.url);
      }
    } catch (e) {
      /* tabs.url may be unavailable without host access */
    }
  }

  async function sendCurrentTabDownload() {
    try {
      if (!api.tabs) return { ok: false, error: 'no_tabs' };
      var tabs = await api.tabs.query({ active: true, currentWindow: true });
      var tab = tabs && tabs[0];
      if (!tab || !tab.url || isRestrictedPageUrl(tab.url) || !isSafeHttpUrl(tab.url)) {
        return { ok: false, error: 'invalid_tab' };
      }
      return await handleDownloadRequest(tab.url, tab.url, {});
    } catch (e) {
      return { ok: false, error: (e && e.message) || 'error' };
    }
  }

  function isXPageUrl(value) {
    if (!isSafeHttpUrl(value)) return false;
    try {
      var hostname = new URL(value).hostname;
      return hostMatchesDomain(hostname, 'x.com') ||
        hostMatchesDomain(hostname, 'twitter.com');
    } catch (e) {
      return false;
    }
  }

  var X_ACTION_OPS = ['FavoriteTweet', 'UnfavoriteTweet', 'CreateBookmark', 'DeleteBookmark'];

  function isMainXUrl(value) {
    if (!isXPageUrl(value)) return false;
    return /^(www\.|mobile\.)?(x|twitter)\.com$/i.test(new URL(value).hostname);
  }

  // Like/bookmark run in an x.com tab with the user's own session: the hooked tab, else the first x.com tab.
  async function relayXAction(message) {
    var op = message.op;
    var tweetId = String(message.tweetId || '');
    if (X_ACTION_OPS.indexOf(op) === -1 || !/^\d{1,25}$/.test(tweetId)) {
      return { ok: false, code: 'unknown', message: 'Action invalide.' };
    }
    var noTab = { ok: false, code: 'no_tab', message: 'Ouvrez x.com dans ce navigateur.' };
    if (!api.tabs || !api.tabs.query || !api.tabs.sendMessage) return noTab;
    var tab = null;
    if (typeof message.tabId === 'number') {
      try {
        var hooked = await api.tabs.get(message.tabId);
        if (hooked && isMainXUrl(hooked.url || '')) tab = hooked;
      } catch (e) { /* closed tab */ }
    }
    if (!tab) {
      try {
        var tabs = await api.tabs.query({
          url: ['*://x.com/*', '*://*.x.com/*', '*://twitter.com/*', '*://*.twitter.com/*'],
        });
        var xTabs = (tabs || []).filter(function (t) {
          return typeof t.id === 'number' && isXPageUrl(t.url || '');
        });
        // help.x.com / ads.x.com have no web-app bundle: only use them when nothing better is open.
        tab = xTabs.find(function (t) { return isMainXUrl(t.url); }) || xTabs[0] || null;
      } catch (e) { /* tabs.query unavailable */ }
    }
    if (!tab) return noTab;
    try {
      var response = await api.tabs.sendMessage(tab.id, { type: 'MD_X_ACTION', op: op, tweetId: tweetId });
      return response || { ok: false, code: 'unknown', message: 'Rechargez l’onglet x.com.' };
    } catch (e) {
      return { ok: false, code: 'no_tab', message: 'Rechargez l’onglet x.com.' };
    }
  }

  async function extractActiveXFeed(maxItems) {
    if (!api.tabs || !api.tabs.query || !api.tabs.sendMessage) {
      return { ok: false, error: 'tabs_unavailable' };
    }

    try {
      var tabs = await api.tabs.query({ active: true, currentWindow: true });
      var tab = tabs && tabs[0];
      if (
        !tab ||
        typeof tab.id !== 'number' ||
        !isXPageUrl(tab.url || '')
      ) {
        return { ok: false, error: 'not_x_page' };
      }

      var response = await api.tabs.sendMessage(tab.id, {
        type: 'MD_EXTRACT_X_FEED',
        maxItems: maxItems,
      });
      return response || { ok: false, error: 'no_content_response' };
    } catch (e) {
      return { ok: false, error: 'content_unavailable' };
    }
  }

  function setupContextMenusFull() {
    if (!api.contextMenus) return;
    var recreate = function () {
      api.contextMenus.removeAll(function () {
        void api.runtime.lastError;
        api.contextMenus.create({
          id: 'download-with-md',
          title: 'Download with TapLoad',
          contexts: ['link', 'video', 'audio', 'page'],
        });
      });
    };
    api.runtime.onInstalled.addListener(recreate);
    if (api.runtime.onStartup) api.runtime.onStartup.addListener(recreate);
    recreate();

    api.contextMenus.onClicked.addListener(function (info, tab) {
      if (info.menuItemId !== 'download-with-md') return;
      var pageUrl = (tab && tab.url) || info.pageUrl || '';
      if (isRestrictedPageUrl(pageUrl) && isRestrictedPageUrl(info.linkUrl || '')) return;
      var url = info.linkUrl || info.srcUrl || info.pageUrl;
      (async function () {
        if (isXCdnUrl(url)) {
          var resolved = await resolvePermalinkFromTab(tab, info.srcUrl || url);
          if (resolved) url = resolved;
        }
        handleDownloadRequest(url, pageUrl || url, {});
      })();
    });
  }

  if (api.cookies && api.cookies.onChanged) {
    api.cookies.onChanged.addListener(function (changeInfo) {
      var domain = (changeInfo.cookie.domain || '').replace(/^\./, '');
      if (!isSupportedDomain(domain, adultSitesEnabled)) return;

      if (cookieDebounceByDomain[domain]) {
        clearTimeout(cookieDebounceByDomain[domain]);
      }
      cookieDebounceByDomain[domain] = setTimeout(function () {
        delete cookieDebounceByDomain[domain];
        // Rebuild from a synthetic https URL for getAll({url}).
        var pageUrl = 'https://' + domain + '/';
        sendHeartbeatForUrl(pageUrl);
      }, 2000);
    });
  }

  function sanitizeXFeedItems(items) {
    if (!Array.isArray(items)) return [];
    var seen = {};
    var safeItems = [];
    items.forEach(function (item) {
      if (!item || typeof item !== 'object') return;
      var id = String(item.id || '');
      var url = String(item.url || '');
      if (!id || seen[id] || !isSafeHttpUrl(url)) return;
      seen[id] = true;
      var platform = item.platform || (typeof MDUrl !== 'undefined' && MDUrl.detectPlatform ? MDUrl.detectPlatform(url) : 'x');
      var isHttpThumb = isSafeHttpUrl(item.thumbnailUrl);
      var isDataThumb = typeof item.thumbnailUrl === 'string' && item.thumbnailUrl.indexOf('data:image/') === 0;
      var safeThumb = (isHttpThumb || isDataThumb) ? item.thumbnailUrl : null;
      var isDirectVideo = (isSafeHttpUrl(item.videoSrc) || (typeof item.videoSrc === 'string' && item.videoSrc.indexOf('blob:') === 0));

      safeItems.push({
        id: id,
        url: url,
        pageUrl: isSafeHttpUrl(item.pageUrl) ? item.pageUrl : url,
        title: String(item.title || (platform.toUpperCase() + ' video')),
        author: String(item.author || (platform.toUpperCase() + ' user')),
        platform: platform,
        music: item.music ? String(item.music) : null,
        avatarUrl: isSafeHttpUrl(item.avatarUrl) ? item.avatarUrl : null,
        thumbnailUrl: safeThumb,
        videoSrc: isDirectVideo ? item.videoSrc : null,
        isActive: Boolean(item.isActive),
        durationSeconds: Number.isFinite(item.durationSeconds)
          ? item.durationSeconds
          : null,
        width: Number.isFinite(item.width) ? item.width : null,
        height: Number.isFinite(item.height) ? item.height : null,
        sizeBytes: Number.isFinite(item.sizeBytes) ? item.sizeBytes : null,
        source: item.source === 'gobird' ? 'gobird' : 'dom',
      });
    });
    return safeItems;
  }

  function broadcastXFeedItems(items, senderTabId) {
    var safeItems = sanitizeXFeedItems(items);
    if (safeItems.length === 0) return;
    try {
      var pending = api.runtime.sendMessage({
        type: 'MD_X_FEED_UPDATE',
        items: safeItems,
        senderTabId: senderTabId,
      });
      if (pending && typeof pending.catch === 'function') {
        pending.catch(function () {
          /* No feed panel is open. */
        });
      }
    } catch (e) {
      /* Ignore messages while the extension is reloading. */
    }
  }

  function isMissingContentReceiverError(error) {
    var message = (error && error.message) || String(error || '');
    return /could not establish connection|receiving end does not exist/i.test(message);
  }

  async function sendTikTokSyncMessage(tabId) {
    var request = { type: 'MD_SYNC_TIKTOK_COLLECTIONS' };
    try {
      return await api.tabs.sendMessage(tabId, request);
    } catch (error) {
      if (
        !isMissingContentReceiverError(error) ||
        !api.scripting ||
        typeof api.scripting.executeScript !== 'function'
      ) {
        throw error;
      }

      // A TikTok tab may have been opened before the extension was installed
      // or reloaded. Inject the same guarded content script used at page load.
      try {
        await api.scripting.executeScript({
          target: { tabId: tabId, frameIds: [0] },
          files: ['url_policy.js', 'theme.js', 'x_actions.js', 'content.js'],
        });
        return await api.tabs.sendMessage(tabId, request);
      } catch (injectionError) {
        logDiag(
          'TIKTOK_SYNC_INJECT_ERR',
          (injectionError && injectionError.message) || String(injectionError),
        );
        throw new Error('collection_items_unavailable');
      }
    }
  }

  function syncTikTokCollections(requestId) {
    logDiag('TIKTOK_SYNC_TRIGGERED', 'Looking for tiktok tabs');
    return api.tabs.query({ url: '*://*.tiktok.com/*' }).then(function (tabs) {
      if (!tabs || tabs.length === 0) {
        // No TikTok tab open — inform the app so it can show a proper message.
        logDiag('TIKTOK_SYNC_NO_TAB', 'No TikTok tab available');
        if (socket && socket.readyState === WebSocket.OPEN) {
          try {
            socket.send(JSON.stringify({
              type: 'TIKTOK_COLLECTIONS_SYNC',
              collections: [],
              collectionListComplete: false,
              error: 'no_tiktok_tab',
              requestId: requestId,
            }));
          } catch (e) { /* ignore */ }
        }
        return;
      }
      // Prefer the user's Favorites/Collections tab. An active For You tab
      // cannot expose the visible collection grid when TikTok blocks its API.
      tabs.sort(function (a, b) {
        function priority(tab) {
          var url = tab.url || '';
          if (/\/favorites(?:\/|\?|$)|\/collection\/|[?&]tab=favorites/.test(url)) return 2;
          return tab.active ? 1 : 0;
        }
        return priority(b) - priority(a);
      });
      // The desktop app can request sync while a different TikTok tab is
      // active. Try every open TikTok tab before reporting no collections.
      return (async function () {
        var lastError = 'empty_response';
        for (var i = 0; i < tabs.length; i++) {
          try {
            var res = await sendTikTokSyncMessage(tabs[i].id);
            if (res && res.ok && Array.isArray(res.collections) && res.collections.length > 0) {
              sendTikTokCollectionsToApp(
                res.collections,
                res.collectionListComplete,
                requestId,
              );
              return;
            }
            if (res && res.error) lastError = res.error;
          } catch (err) {
            lastError = (err && err.message) || 'tab_unavailable';
            logDiag('TIKTOK_SYNC_TAB_ERR', lastError);
          }
        }
        logDiag('TIKTOK_SYNC_EMPTY', lastError);
        if (socket && socket.readyState === WebSocket.OPEN) {
          socket.send(JSON.stringify({
            type: 'TIKTOK_COLLECTIONS_SYNC',
            collections: [],
            collectionListComplete: false,
            error: lastError,
            requestId: requestId,
          }));
        }
      })().catch(function (err) {
        logDiag('TIKTOK_SYNC_ERR', (err && err.message) || String(err));
      });
    }).catch(function (err) {
      logDiag('TIKTOK_SYNC_QUERY_ERR', (err && err.message) || String(err));
    });
  }

  function sendTikTokCollectionsToApp(collections, collectionListComplete, requestId) {
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      logDiag('TIKTOK_SEND_ERR', 'Socket not open');
      return false;
    }
    try {
      socket.send(JSON.stringify({
        type: 'TIKTOK_COLLECTIONS_SYNC',
        collections: collections,
        collectionListComplete: collectionListComplete === true,
        requestId: requestId,
      }));
      logDiag('TIKTOK_COLLECTIONS_SENT', 'Count=' + collections.length);
      return true;
    } catch (e) {
      console.warn('Failed to send TikTok collections to app', e);
      return false;
    }
  }

  // NOTE: TikTok API fetches are intentionally NOT done here.
  // The Service Worker runs under the extension CSP which only permits
  // ws://127.0.0.1:* in connect-src. Fetching https://www.tiktok.com from
  // the SW is a CSP violation (blocked by Chrome). All TikTok API calls must
  // happen inside the content script (extension/shared/content.js) which runs
  // in the page context and is subject to TikTok's own CSP, not the extension's.

  api.runtime.onMessage.addListener(function (message, sender, sendResponse) {
    if (!message || !message.type) return false;

    var senderTabId = sender && sender.tab && sender.tab.id;

    if (message.type === 'MD_TRIGGER_TIKTOK_SYNC') {
      syncTikTokCollections(message.requestId);
      sendResponse({ ok: true });
      return false;
    }

    if (message.type === 'MD_TIKTOK_COLLECTIONS_DATA') {
      var sent = Array.isArray(message.collections) &&
        sendTikTokCollectionsToApp(
          message.collections,
          message.collectionListComplete,
          message.requestId,
        );
      sendResponse({ ok: !!sent });
      return false;
    }

    if (message.type === 'MD_DEEP_SCAN_PROGRESS' || message.type === 'MD_PAGE_NAVIGATED') {
      try {
        var forwardMsg = Object.assign({}, message, { senderTabId: senderTabId });
        api.runtime.sendMessage(forwardMsg).catch(function () {});
      } catch (e) {}
      sendResponse({ ok: true });
      return false;
    }

    if (message.type === 'MD_X_FEED_ITEMS' || message.type === 'MD_FEED_ITEMS') {
      broadcastXFeedItems(message.items, senderTabId);
      sendResponse({ ok: true });
      return false;
    }

    if (message.type === 'MD_KEEPALIVE') {
      if (!socket || socket.readyState !== WebSocket.OPEN) {
        connect();
      } else if (isConnected) {
        try { socket.send(JSON.stringify({ type: 'PING' })); } catch (e) { /* ignore */ }
      }
      sendResponse({ ok: true });
      return false;
    }

    if (message.type === 'GET_TAB_URL') {
      var tabUrl = sender && sender.tab && sender.tab.url;
      sendResponse({ ok: !!tabUrl, url: tabUrl || null });
      return false;
    }

    if (message.type === 'DOWNLOAD_BTN_CLICK') {
      handleDownloadRequest(message.url, message.pageUrl, message.options, {
        tweetId: message.tweetId,
        mediaId: message.mediaId,
        tikTokId: message.tikTokId,
        thumbnailUrl: message.thumbnailUrl,
      }).then(sendResponse);
      return true;
    }

    if (message.type === 'MD_DOWNLOAD_COMMAND' || message.type === 'MD_QUEUE_SNAPSHOT_REQUEST' ||
        message.type === 'MD_X_ACTION' || message.type === 'MD_PAIRING_RETRY') {
      // Queue control, X actions and pairing retries belong to the extension's own pages, never to content scripts.
      if (!isExtensionPage(sender)) {
        sendResponse({ ok: false, error: 'forbidden' });
        return false;
      }
    }

    if (message.type === 'MD_PAIRING_RETRY') {
      pairingEvent({ type: 'RETRY' });
      clearReconnect();
      connect();
      sendResponse({ ok: true });
      return false;
    }

    if (message.type === 'MD_DOWNLOAD_COMMAND') {
      sendResponse(sendDownloadCommand(message.command, message.id));
      return false;
    }

    if (message.type === 'MD_X_ACTION') {
      relayXAction(message).then(sendResponse);
      return true;
    }

    if (message.type === 'MD_QUEUE_SNAPSHOT_REQUEST') {
      sendResponse(requestQueueSnapshot() ? { ok: true, sent: true } : { ok: false, error: 'not_connected' });
      return false;
    }

    if (message.type === 'SEND_CURRENT_TAB') {
      sendCurrentTabDownload().then(sendResponse);
      return true;
    }

    if (message.type === 'ANALYZE_X_FEED') {
      requestXFeedFromApp(message.maxItems).then(function (appResult) {
        if (appResult && appResult.ok === true && Array.isArray(appResult.items)) {
          sendResponse(appResult);
          return;
        }

        var gobirdErrorCode = (appResult && (appResult.errorCode || appResult.error)) ||
          'unavailable';
        var gobirdError = (appResult && (appResult.error || appResult.errorCode)) ||
          'gobird unavailable';
        var gobirdDisabled = gobirdErrorCode === 'disabled';

        console.warn(
          'gobird X feed unavailable (' + gobirdErrorCode + '): ' + gobirdError +
          ' — falling back to local DOM',
        );

        return extractActiveXFeed(message.maxItems).then(function (domResult) {
          var result = domResult || { ok: false, error: 'content_unavailable' };
          // Keep DOM results usable, but never hide a gobird failure behind a
          // plain "local" badge when the user enabled the experimental engine.
          if (result && typeof result === 'object') {
            if (!gobirdDisabled) {
              result.fallbackFrom = 'gobird';
              result.gobirdError = gobirdError;
              result.gobirdErrorCode = gobirdErrorCode;
            }
            if (!result.source) result.source = 'dom';
          }
          sendResponse(result);
        });
      }).catch(function (err) {
        console.warn('gobird X feed request failed', err && err.message);
        extractActiveXFeed(message.maxItems).then(function (domResult) {
          var result = domResult || { ok: false, error: 'content_unavailable' };
          if (result && typeof result === 'object') {
            result.fallbackFrom = 'gobird';
            result.gobirdError = (err && err.message) || 'gobird request failed';
            result.gobirdErrorCode = 'request_failed';
            if (!result.source) result.source = 'dom';
          }
          sendResponse(result);
        });
      });
      return true;
    }

    if (message.type === 'TEST_CONNECTION') {
      logDiag('TEST_CONN_REQ', 'isConnected=' + isConnected + ' readyState=' + (socket ? socket.readyState : 'none'));
      if (isConnected && socket && socket.readyState === WebSocket.OPEN) {
        try {
          socket.send(JSON.stringify({ type: 'PING' }));
        } catch (e) {}
        sendResponse({ ok: true, connected: true });
        return false;
      }

      // If disconnected or connecting, trigger connect and wait up to 3 seconds for HELLO_OK
      connect();
      var checkStart = Date.now();
      var checkInterval = setInterval(function () {
        if (isConnected && socket && socket.readyState === WebSocket.OPEN) {
          clearInterval(checkInterval);
          try { socket.send(JSON.stringify({ type: 'PING' })); } catch (e) {}
          logDiag('TEST_CONN_RES', 'ok=true');
          sendResponse({ ok: true, connected: true });
          return;
        }
        if (Date.now() - checkStart > 3000) {
          clearInterval(checkInterval);
          api.storage.local.get(['lastAuthError']).then(function (res) {
            if (res && res.lastAuthError) {
              logDiag('TEST_CONN_RES', 'auth_failed');
              sendResponse({ ok: false, error: 'auth_failed', detail: res.lastAuthError });
            } else {
              logDiag('TEST_CONN_RES', 'app_offline');
              sendResponse({ ok: false, error: 'app_offline' });
            }
          }).catch(function () {
            sendResponse({ ok: false, error: 'app_offline' });
          });
        }
      }, 100);
      return true;
    }

    if (message.type === 'GET_CONNECTION_STATE') {
      sendResponse({ ok: true, connected: isConnected, activeCount: activeDownloadCount });
      return false;
    }

    if (message.type === 'CONFIG_UPDATED') {
      api.storage.local.get(['serverPort', 'apiToken']).then(function (res) {
        var newPort = parseInt(res.serverPort, 10) || 6969;
        var newToken = res.apiToken || '';
        // If already connected with the same port and token, keep the connection intact!
        if (isConnected && socket && socket.readyState === WebSocket.OPEN &&
            newPort === serverPort && newToken === apiToken) {
          logDiag('CONFIG_UPDATED', 'unchanged; keeping socket');
          sendResponse({ ok: true, unchanged: true });
          return;
        }
        logDiag('CONFIG_UPDATED', 'reconnecting with new config');
        clearReconnect();
        closeSocketQuietly();
        isConnected = false;
        publishConnectionState();
        connect();
        sendResponse({ ok: true });
      }).catch(function () {
        connect();
        sendResponse({ ok: true });
      });
      return true;
    }

    return false;
  });

  if (api.commands && api.commands.onCommand) {
    api.commands.onCommand.addListener(function (command) {
      if (command === 'send-current-tab') {
        sendCurrentTabDownload();
      }
    });
  }

  setupContextMenusFull();

  if (api.alarms) {
    try {
      api.alarms.create('md-keepalive', { periodInMinutes: 0.4 });
      api.alarms.onAlarm.addListener(function (alarm) {
        if (alarm.name === 'md-keepalive') {
          if (!socket || socket.readyState !== WebSocket.OPEN) {
            connect();
          } else if (isConnected) {
            try { socket.send(JSON.stringify({ type: 'PING' })); } catch (e) { /* ignore */ }
          }
        }
      });
    } catch (e) {
      /* alarms optional */
    }
  }

  connect();
})();
