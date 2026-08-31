/**
 * Modern Downloader — WebSocket connection client.
 * Runs in Chrome offscreen document or Firefox background.
 */
(function () {
  'use strict';

  var api = typeof MD_API !== 'undefined' ? MD_API : (typeof browser !== 'undefined' ? browser : chrome);
  var action = typeof MD_ACTION !== 'undefined' ? MD_ACTION : (api.action || api.browserAction);

  var SUPPORTED_DOMAINS = [
    'youtube.com', 'youtu.be',
    'instagram.com',
    'twitter.com', 'x.com',
    'tiktok.com',
    'twitch.tv',
    'facebook.com', 'fb.watch',
  ];

  var ADULT_DOMAINS = ['pornhub.com'];

  var ALLOWED_OPTION_KEYS = ['isAudioOnly', 'preferredQuality', 'isPlaylist'];
  var HELLO_TIMEOUT_MS = 2000;

  function hostMatchesDomain(hostname, domain) {
    var host = String(hostname || '').toLowerCase().replace(/^\./, '');
    var d = String(domain || '').toLowerCase().replace(/^\./, '');
    if (!host || !d) return false;
    return host === d || host.endsWith('.' + d);
  }

  function isSupportedDomain(hostname, includeAdult) {
    var list = SUPPORTED_DOMAINS.slice();
    if (includeAdult) list = list.concat(ADULT_DOMAINS);
    return list.some(function (d) {
      return hostMatchesDomain(hostname, d);
    });
  }

  function isSafeHttpUrl(value) {
    try {
      var u = new URL(value);
      return (u.protocol === 'http:' || u.protocol === 'https:') && !!u.hostname;
    } catch (e) {
      return false;
    }
  }

  function isRestrictedPageUrl(value) {
    if (!value || typeof value !== 'string') return true;
    return /^(chrome|chrome-extension|moz-extension|about|edge|devtools):/i.test(value);
  }

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

  function setConnected(connected) {
    try {
      api.storage.local.set({ isConnected: !!connected });
    } catch (e) {
      /* ignore */
    }
    if (!action || !action.setBadgeText) return;
    if (connected) {
      action.setBadgeBackgroundColor({ color: '#6C5DD3' });
    } else {
      action.setBadgeText({ text: 'OFF' });
      action.setBadgeBackgroundColor({ color: '#FF4757' });
    }
  }

  function updateActiveBadge(count) {
    if (!action || !action.setBadgeText) return;
    if (count > 0) {
      action.setBadgeText({ text: String(count > 99 ? '99+' : count) });
      action.setBadgeBackgroundColor({ color: '#4CAF50' });
    } else {
      action.setBadgeText({ text: '' });
    }
  }

    // ==========================================
  // Full connection (offscreen / Firefox)
  // ==========================================
  var serverPort = 6969;
  var apiToken = '';
  var socket = null;
  var isConnected = false;
  var reconnectTimer = null;
  var reconnectDelayMs = 1000;
  var cookieDebounce = null;
  var cookieDebounceByDomain = {};
  var pendingDownloadAcks = [];
  var pendingCorrelated = {};
  var activeDownloadCount = 0;
  var adultSitesEnabled = false;
  var nextRequestId = 1;
  var DOWNLOADED_KEYS_CAP = 4000;
  var DOWNLOAD_STATUS_COMPLETED = 4;
  var DOWNLOAD_STATUS_FAILED = 5;
  var DOWNLOAD_STATUS_CANCELED = 6;
  var DOWNLOAD_STATUS_DUPLICATE = 8;

  function scheduleReconnect() {
    if (reconnectTimer) return;
    reconnectTimer = setTimeout(function () {
      reconnectTimer = null;
      connect();
    }, reconnectDelayMs);
    reconnectDelayMs = Math.min(reconnectDelayMs * 2, 30000);
  }

  function clearReconnect() {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
      reconnectTimer = null;
    }
    reconnectDelayMs = 1000;
  }

  function publishConnectionState() {
    setConnected(isConnected);
    try {
      api.runtime.sendMessage({
        type: 'MD_CONNECTION_STATE',
        connected: isConnected,
        activeCount: activeDownloadCount,
      });
    } catch (e) {
      /* SW may be asleep */
    }
  }

  function closeSocketQuietly() {
    if (!socket) return;
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

  function connect() {
    api.storage.local.get(['serverPort', 'apiToken', 'adultSitesEnabled']).then(function (res) {
      serverPort = parseInt(res.serverPort, 10) || 6969;
      if (serverPort < 1024 || serverPort > 65535) {
        console.warn('Invalid server port; using 6969');
        serverPort = 6969;
      }
      apiToken = res.apiToken || '';
      adultSitesEnabled = res.adultSitesEnabled === true;

      closeSocketQuietly();
      console.log('Connecting to Modern Downloader on 127.0.0.1:' + serverPort + '...');

      try {
        // Token is NOT placed in the URL — only sent in HELLO.
        socket = new WebSocket('ws://127.0.0.1:' + serverPort + '/');

        var helloTimer = setTimeout(function () {
          if (!isConnected && socket) {
            console.warn('HELLO handshake timed out');
            try { socket.close(); } catch (e) { /* ignore */ }
          }
        }, HELLO_TIMEOUT_MS + 500);

        socket.onopen = function () {
          clearTimeout(helloTimer);
          var version = getManifestVersion();
          socket.send(JSON.stringify({
            type: 'HELLO',
            version: version,
            token: apiToken,
          }));
        };

        socket.onclose = function () {
          clearTimeout(helloTimer);
          console.log('Disconnected from App. Reconnecting...');
          isConnected = false;
          socket = null;
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
          console.error('WebSocket error');
        };
      } catch (e) {
        console.error('Critical WebSocket error', e);
        scheduleReconnect();
      }
    }).catch(function (e) {
      console.error('Failed to read settings for connect', e);
      scheduleReconnect();
    });
  }

  function handleAppMessage(message) {
    if (!message || !message.type) return;

    if (message.type === 'HELLO_OK') {
      isConnected = true;
      clearReconnect();
      publishConnectionState();
      console.log('Connected to Modern Downloader App');
      requestLibraryKeys();
      api.storage.local.get(['autoSendCookies']).then(function (cookieRes) {
        if (cookieRes.autoSendCookies !== false) {
          setTimeout(sendCurrentTabCookies, 2000);
        }
      });
      return;
    }

    if (message.type === 'AUTH_FAILED') {
      isConnected = false;
      publishConnectionState();
      api.storage.local.set({ lastAuthError: message.reason || 'auth_failed' });
      console.warn('Auth failed — check token in extension popup');
      try { if (socket) socket.close(); } catch (e) { /* ignore */ }
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

    if (message.type === 'LIBRARY_KEYS_RESULT') {
      if (message.ok !== false) {
        mergeDownloadedKeys(message.tweetIds, message.mediaIds);
      }
      return;
    }

    if (message.type === 'PROGRESS') {
      var item = message.data || {};
      // Persist only sanitized fields (no cookies / paths).
      var sanitized = {
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
      };
      updateBadgeFromProgress(sanitized);
      recordProgressDownloadKeys(item);
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
    var query = { url: [
      '*://x.com/*',
      '*://*.x.com/*',
      '*://twitter.com/*',
      '*://*.twitter.com/*',
    ] };
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

  function mergeDownloadedKeys(tweetIds, mediaIds) {
    var addedTweets = sanitizeIdList(tweetIds);
    var addedMedia = sanitizeIdList(mediaIds);
    if (addedTweets.length === 0 && addedMedia.length === 0) {
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
      };
      return api.storage.local.set({ downloadedKeys: next }).then(function () {
        broadcastDownloadState({
          type: 'MD_DOWNLOAD_STATE',
          tweetIds: addedTweets,
          mediaIds: addedMedia,
          removedTweetIds: [],
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
      };
      return api.storage.local.set({ downloadedKeys: next }).then(function () {
        broadcastDownloadState({
          type: 'MD_DOWNLOAD_STATE',
          tweetIds: [],
          mediaIds: [],
          removedTweetIds: removed,
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
    if (status === DOWNLOAD_STATUS_COMPLETED || status === DOWNLOAD_STATUS_DUPLICATE) {
      mergeDownloadedKeys(
        tweetId ? [tweetId] : [],
        mediaId ? [mediaId] : [],
      );
      return;
    }
    if (status === DOWNLOAD_STATUS_FAILED || status === DOWNLOAD_STATUS_CANCELED) {
      if (tweetId) removeDownloadedTweetIds([tweetId]);
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
    sb += '# This file was generated by Modern Downloader Extension\n\n';
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
    if (!isSafeHttpUrl(value)) return null;
    try {
      var url = new URL(value);
      var hostname = url.hostname.toLowerCase();
      if (!hostMatchesDomain(hostname, 'x.com') &&
          !hostMatchesDomain(hostname, 'twitter.com')) {
        return null;
      }
      var match = url.pathname.match(
        /^\/(?:[^/]+\/status|i\/(?:web\/)?status)\/(\d+)/,
      );
      if (!match) return null;
      url.search = '';
      url.hash = '';
      return url.href;
    } catch (e) {
      return null;
    }
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
    var permalink = xStatusPermalink(value);
    if (permalink) return true;
    if (!isSafeHttpUrl(value)) return false;
    if (isXCdnUrl(value)) return false;
    try {
      var hostname = new URL(value).hostname;
      return isSupportedDomain(hostname, adultSitesEnabled);
    } catch (e) {
      return false;
    }
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
        mergeDownloadedKeys(
          tweetId ? [tweetId] : [],
          mediaId ? [mediaId] : [],
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
          title: 'Download with Modern Downloader',
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
      safeItems.push({
        id: id,
        url: url,
        pageUrl: isSafeHttpUrl(item.pageUrl) ? item.pageUrl : url,
        title: String(item.title || 'X video'),
        author: String(item.author || 'X user'),
        thumbnailUrl: isSafeHttpUrl(item.thumbnailUrl)
          ? item.thumbnailUrl
          : null,
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

  function broadcastXFeedItems(items) {
    var safeItems = sanitizeXFeedItems(items);
    if (safeItems.length === 0) return;
    try {
      var pending = api.runtime.sendMessage({
        type: 'MD_X_FEED_UPDATE',
        items: safeItems,
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

  api.runtime.onMessage.addListener(function (message, sender, sendResponse) {
    if (!message || !message.type) return false;

    if (message.type === 'MD_X_FEED_ITEMS') {
      broadcastXFeedItems(message.items);
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

    if (message.type === 'DOWNLOAD_BTN_CLICK') {
      handleDownloadRequest(message.url, message.pageUrl, message.options, {
        tweetId: message.tweetId,
        mediaId: message.mediaId,
        thumbnailUrl: message.thumbnailUrl,
      }).then(sendResponse);
      return true;
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
      if (!isConnected || !socket || socket.readyState !== WebSocket.OPEN) {
        sendResponse({ ok: false, error: 'app_offline' });
        return false;
      }
      try {
        socket.send(JSON.stringify({ type: 'PING' }));
        sendResponse({ ok: true, connected: true });
      } catch (e) {
        sendResponse({ ok: false, error: 'send_failed' });
      }
      return false;
    }

    if (message.type === 'GET_CONNECTION_STATE') {
      sendResponse({ ok: true, connected: isConnected, activeCount: activeDownloadCount });
      return false;
    }

    if (message.type === 'CONFIG_UPDATED') {
      clearReconnect();
      closeSocketQuietly();
      isConnected = false;
      publishConnectionState();
      connect();
      sendResponse({ ok: true });
      return false;
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

  // Firefox background owns menus; Chrome offscreen leaves menus to the SW shell.
  var runningInOffscreenDoc = typeof document !== 'undefined' &&
    /offscreen\.html/i.test(String((typeof location !== 'undefined' && location.href) || ''));
  if (!runningInOffscreenDoc) {
    setupContextMenusFull();
  }

  connect();
})();
