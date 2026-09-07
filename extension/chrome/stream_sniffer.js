/**
 * Stream Sniffer for Modern Downloader.
 * Intercepts video network streams (.m3u8, .mpd, .mp4, video/*)
 * passively via webRequest API. Zero DOM dependencies, infallible detection.
 */
(function () {
  'use strict';

  var api = typeof chrome !== 'undefined' ? chrome : (typeof browser !== 'undefined' ? browser : null);
  if (!api || !api.webRequest || !api.webRequest.onHeadersReceived) return;

  var TAB_STREAMS = {};
  var SEEN_URLS = {};
  var MAX_STREAMS_PER_TAB = 50;

  var AD_DOMAINS = [
    'doubleclick.net', 'googlesyndication.com', 'adnxs.com', 'outbrain.com',
    'taboola.com', 'criteo.com', 'pubmatic.com', 'scorecardresearch.com',
    'serving-sys.com', 'adform.net', 'bidswitch.net', 'adroll.com',
    'amazon-adsystem.com', 'moatads.com', 'innovid.com'
  ];

  function isAdUrl(url) {
    if (!url) return true;
    var lower = url.toLowerCase();
    for (var i = 0; i < AD_DOMAINS.length; i++) {
      if (lower.indexOf(AD_DOMAINS[i]) !== -1) return true;
    }
    return false;
  }

  function getHeader(headers, name) {
    if (!headers) return null;
    var nameLower = name.toLowerCase();
    for (var i = 0; i < headers.length; i++) {
      if (headers[i].name && headers[i].name.toLowerCase() === nameLower) {
        return headers[i].value;
      }
    }
    return null;
  }

  function detectMediaFormat(url, mimeType) {
    var u = (url || '').toLowerCase().split('?')[0];
    var mime = (mimeType || '').toLowerCase();

    if (u.indexOf('.m3u8') !== -1 || mime.indexOf('mpegurl') !== -1 || mime.indexOf('x-mpegurl') !== -1) {
      return { format: 'HLS (.m3u8)', ext: 'm3u8', isManifest: true };
    }
    if (u.indexOf('.mpd') !== -1 || mime.indexOf('dash+xml') !== -1) {
      return { format: 'DASH (.mpd)', ext: 'mpd', isManifest: true };
    }
    if (u.indexOf('.mp4') !== -1 || mime === 'video/mp4') {
      return { format: 'MP4 Video', ext: 'mp4', isManifest: false };
    }
    if (u.indexOf('.webm') !== -1 || mime === 'video/webm') {
      return { format: 'WebM Video', ext: 'webm', isManifest: false };
    }
    if (u.indexOf('.m4v') !== -1 || mime === 'video/x-m4v') {
      return { format: 'M4V Video', ext: 'm4v', isManifest: false };
    }
    if (mime.indexOf('video/') === 0) {
      return { format: 'Flux Vidéo', ext: 'mp4', isManifest: false };
    }
    return null;
  }

  function updateTabBadge(tabId) {
    if (!api.action || !api.action.setBadgeText) return;
    var streams = TAB_STREAMS[tabId] || [];
    var count = streams.length;
    if (count > 0) {
      api.action.setBadgeText({ text: String(count), tabId: tabId });
      if (api.action.setBadgeBackgroundColor) {
        api.action.setBadgeBackgroundColor({ color: '#6C5DD3', tabId: tabId });
      }
    } else {
      api.action.setBadgeText({ text: '', tabId: tabId });
    }
  }

  function onHeadersReceived(details) {
    var tabId = details.tabId;
    if (typeof tabId !== 'number' || tabId < 0) return;

    var url = details.url;
    if (!url || url.indexOf('http') !== 0) return;
    if (isAdUrl(url)) return;

    var contentType = getHeader(details.responseHeaders, 'Content-Type');
    var contentLength = parseInt(getHeader(details.responseHeaders, 'Content-Length') || '0', 10);

    // Rejeter immédiatement les images (miniatures de flux, avatars, bannières)
    if (contentType && contentType.indexOf('image/') === 0) return;

    var mediaInfo = detectMediaFormat(url, contentType);
    if (!mediaInfo) return;

    // Éliminer les micro-fichiers audio ou fragments de tracking (< 80 Ko sauf si c'est un manifest)
    if (!mediaInfo.isManifest && contentLength > 0 && contentLength < 80000) {
      return;
    }

    var dedupKey = tabId + ':' + url.split('?')[0];
    if (SEEN_URLS[dedupKey]) return;
    SEEN_URLS[dedupKey] = true;

    if (!TAB_STREAMS[tabId]) TAB_STREAMS[tabId] = [];

    if (TAB_STREAMS[tabId].length >= MAX_STREAMS_PER_TAB) {
      TAB_STREAMS[tabId].shift();
    }

    var hostname = '';
    try {
      hostname = new URL(url).hostname.replace(/^www\./, '');
    } catch (e) {}

    var streamItem = {
      id: 'sniff-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
      url: url,
      mimeType: contentType || 'video/mp4',
      format: mediaInfo.format,
      ext: mediaInfo.ext,
      isManifest: mediaInfo.isManifest,
      contentLength: contentLength > 0 ? contentLength : null,
      hostname: hostname,
      timestamp: Date.now(),
    };

    TAB_STREAMS[tabId].push(streamItem);
    updateTabBadge(tabId);

    // Notifier le popup ou side panel si ouvert
    if (api.runtime && api.runtime.sendMessage) {
      try {
        api.runtime.sendMessage({
          type: 'MD_STREAM_SNIFFED',
          tabId: tabId,
          stream: streamItem,
          count: TAB_STREAMS[tabId].length,
        }).catch(function () {});
      } catch (e) {}
    }
  }

  try {
    api.webRequest.onHeadersReceived.addListener(
      onHeadersReceived,
      { urls: ['http://*/*', 'https://*/*'] },
      ['responseHeaders']
    );
  } catch (e) {
    console.error('webRequest.onHeadersReceived registration failed', e);
  }

  if (api.tabs && api.tabs.onUpdated) {
    api.tabs.onUpdated.addListener(function (tabId, changeInfo) {
      if (changeInfo.status === 'loading' && changeInfo.url) {
        delete TAB_STREAMS[tabId];
        updateTabBadge(tabId);
      }
    });
  }
  if (api.tabs && api.tabs.onRemoved) {
    api.tabs.onRemoved.addListener(function (tabId) {
      delete TAB_STREAMS[tabId];
    });
  }

  if (api.runtime && api.runtime.onMessage) {
    api.runtime.onMessage.addListener(function (msg, sender, sendResponse) {
      if (!msg) return;
      if (msg.type === 'GET_SNIFFED_STREAMS') {
        var targetTabId = msg.tabId;
        if (typeof targetTabId !== 'number' && sender && sender.tab) {
          targetTabId = sender.tab.id;
        }
        var list = (targetTabId && TAB_STREAMS[targetTabId]) ? TAB_STREAMS[targetTabId] : [];
        sendResponse({ ok: true, streams: list });
        return true;
      }
    });
  }

  var root = typeof globalThis !== 'undefined' ? globalThis : self;
  root.MDStreamSniffer = {
    getStreams: function (tabId) {
      return (tabId && TAB_STREAMS[tabId]) ? TAB_STREAMS[tabId] : [];
    },
    clearStreams: function (tabId) {
      delete TAB_STREAMS[tabId];
      updateTabBadge(tabId);
    },
  };
})();
