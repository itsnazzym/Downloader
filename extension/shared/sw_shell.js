/**
 * Chrome MV3 service-worker shell.
 * Keeps the offscreen document alive and forwards messages to it.
 */
(function () {
  'use strict';

  if (typeof importScripts === 'function' && typeof MD_API === 'undefined') {
    try {
      importScripts('browser_api.js');
    } catch (e) {
      console.warn('browser_api importScripts failed', e);
    }
  }

  var api = typeof MD_API !== 'undefined' ? MD_API : chrome;
  var action = typeof MD_ACTION !== 'undefined' ? MD_ACTION : (api.action || api.browserAction);

  var OFFSCREEN_URL = 'offscreen.html';
  var OFFSCREEN_REASON = 'WEB_SOCKET';
  var KEEPALIVE_ALARM = 'md-keepalive';
  var creatingOffscreen = null;

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

  function setConnected(connected) {
    try {
      api.storage.local.set({ isConnected: !!connected });
    } catch (e) { /* ignore */ }
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

  async function ensureOffscreen() {
    try {
      var contexts = await chrome.runtime.getContexts({
        contextTypes: ['OFFSCREEN_DOCUMENT'],
        documentUrls: [chrome.runtime.getURL(OFFSCREEN_URL)],
      });
      if (contexts && contexts.length > 0) return;
    } catch (e) {
      /* fall through */
    }
    if (creatingOffscreen) {
      await creatingOffscreen;
      return;
    }
    creatingOffscreen = chrome.offscreen.createDocument({
      url: OFFSCREEN_URL,
      reasons: [OFFSCREEN_REASON],
      justification: 'Maintain WebSocket connection to the local Modern Downloader app',
    }).catch(function (err) {
      if (!err || !/already|exists/i.test(String(err.message || err))) {
        console.error('Offscreen create failed', err);
      }
    }).finally(function () {
      creatingOffscreen = null;
    });
    await creatingOffscreen;
  }

  function forwardToOffscreen(message) {
    return ensureOffscreen().then(function () {
      return new Promise(function (resolve) {
        chrome.runtime.sendMessage(
          Object.assign({}, message, { _mdTarget: 'offscreen' }),
          function (response) {
            void chrome.runtime.lastError;
            resolve(response);
          },
        );
      });
    });
  }

  function setupContextMenus() {
    if (!api.contextMenus) return;
    api.contextMenus.removeAll(function () {
      void api.runtime.lastError;
      api.contextMenus.create({
        id: 'download-with-md',
        title: 'Download with Modern Downloader',
        contexts: ['link', 'video', 'audio', 'page'],
      });
    });
  }

  api.runtime.onInstalled.addListener(function () {
    setupContextMenus();
    ensureOffscreen();
  });
  if (api.runtime.onStartup) {
    api.runtime.onStartup.addListener(function () {
      setupContextMenus();
      ensureOffscreen();
    });
  }

  if (api.alarms) {
    api.alarms.create(KEEPALIVE_ALARM, { periodInMinutes: 0.4 });
    api.alarms.onAlarm.addListener(function (alarm) {
      if (alarm.name === KEEPALIVE_ALARM) {
        ensureOffscreen().then(function () {
          chrome.runtime.sendMessage({ type: 'MD_KEEPALIVE', _mdTarget: 'offscreen' });
        });
      }
    });
  }

  if (api.contextMenus) {
    api.contextMenus.onClicked.addListener(function (info, tab) {
      if (info.menuItemId !== 'download-with-md') return;
      var pageUrl = (tab && tab.url) || info.pageUrl || '';
      if (isRestrictedPageUrl(pageUrl) && isRestrictedPageUrl(info.linkUrl || '')) return;
      var url = info.linkUrl || info.srcUrl || info.pageUrl;
      if (!isSafeHttpUrl(url)) return;
      forwardToOffscreen({
        type: 'DOWNLOAD_BTN_CLICK',
        url: url,
        pageUrl: pageUrl || url,
      });
    });
  }

  if (api.commands && api.commands.onCommand) {
    api.commands.onCommand.addListener(function (command) {
      if (command !== 'send-current-tab') return;
      forwardToOffscreen({ type: 'SEND_CURRENT_TAB' });
    });
  }

  api.runtime.onMessage.addListener(function (message, sender, sendResponse) {
    if (message && message.type === 'MD_CONNECTION_STATE') {
      setConnected(!!message.connected);
      if (typeof message.activeCount === 'number') {
        updateActiveBadge(message.activeCount);
      }
      sendResponse({ ok: true });
      return false;
    }
    if (message && (message.type === 'DOWNLOAD_BTN_CLICK' ||
        message.type === 'CONFIG_UPDATED' ||
        message.type === 'SEND_CURRENT_TAB' ||
        message.type === 'ANALYZE_X_FEED' ||
        message.type === 'MD_X_FEED_ITEMS' ||
        message.type === 'TEST_CONNECTION' ||
        message.type === 'GET_CONNECTION_STATE')) {
      forwardToOffscreen(message).then(function (response) {
        sendResponse(response || { ok: false });
      });
      return true;
    }
    return false;
  });

  ensureOffscreen();
  setupContextMenus();
})();
