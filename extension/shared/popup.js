(function () {
  'use strict';

  var api = typeof MD_API !== 'undefined' ? MD_API : (typeof browser !== 'undefined' ? browser : chrome);

  var statusDot = document.getElementById('status-indicator');
  var statusText = document.getElementById('status-text');
  var listContainer = document.getElementById('downloads-list');
  var portInput = document.getElementById('port-input');
  var tokenInput = document.getElementById('token-input');
  var cookiesToggle = document.getElementById('cookies-toggle');
  var connectionMsg = document.getElementById('connection-msg');
  var browserSelect = document.getElementById('browser-select');
  var sendTabBtn = document.getElementById('send-tab-btn');
  var testBtn = document.getElementById('test-connection-btn');
  var openFeedBtn = document.getElementById('open-feed-btn');
  var btnColor = document.getElementById('btn-color');
  var btnPosition = document.getElementById('btn-position');
  var btnSize = document.getElementById('btn-size');
  var qualityToggle = document.getElementById('quality-toggle');
  var adultToggle = document.getElementById('adult-toggle');

  var ADULT_ORIGINS = ['*://*.pornhub.com/*'];

  var STATUS_KEYS = [
    'statusQueued', 'statusExtracting', 'statusDownloading', 'statusProcessing',
    'statusCompleted', 'statusFailed', 'statusCanceled', 'statusPaused', 'statusDuplicate',
  ];
  var STATUS_FALLBACKS = [
    'Queued', 'Extracting', 'Downloading', 'Processing',
    'Completed', 'Failed', 'Canceled', 'Paused', 'Duplicate',
  ];

  function t(key, fallback) {
    try {
      if (api.i18n && api.i18n.getMessage) {
        var msg = api.i18n.getMessage(key);
        if (msg) return msg;
      }
    } catch (e) { /* ignore */ }
    return fallback;
  }

  function applyDocumentLang() {
    try {
      var uiLang = api.i18n && api.i18n.getUILanguage ? api.i18n.getUILanguage() : '';
      if (uiLang) {
        document.documentElement.lang = String(uiLang).split(/[-_]/)[0];
      }
    } catch (e) { /* keep existing html lang */ }
  }

  function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      var msg = t(key, el.textContent);
      if (msg) el.textContent = msg;
    });
  }

  function statusLabel(index) {
    var key = STATUS_KEYS[index];
    var fallback = STATUS_FALLBACKS[index] || t('statusProcessing', 'Processing');
    return key ? t(key, fallback) : fallback;
  }

  function setConnectionUi(connected, detail) {
    if (connected) {
      statusDot.className = 'status-dot connected';
      statusDot.title = t('connected', 'Connected');
      statusText.textContent = t('connected', 'Connected');
      connectionMsg.textContent = detail || t('connected', 'Connected');
      connectionMsg.style.color = '#4CAF50';
    } else {
      statusDot.className = 'status-dot disconnected';
      statusDot.title = t('disconnected', 'Disconnected');
      statusText.textContent = t('disconnected', 'Disconnected');
      connectionMsg.textContent = detail || t('disconnectedHint', 'Disconnected (Check App + token)');
      connectionMsg.style.color = '#F44336';
    }
  }

  function updateStatus() {
    api.storage.local.get(['isConnected', 'lastAuthError']).then(function (res) {
      var connected = res.isConnected === true;
      var detail = null;
      if (!connected && res.lastAuthError) {
        detail = t('authFailed', 'Auth failed — check token');
      }
      setConnectionUi(connected, detail);
    }).catch(function () {
      setConnectionUi(false);
    });
  }

  applyDocumentLang();
  applyI18n();
  updateStatus();
  setInterval(updateStatus, 2000);

  api.storage.local.get([
    'serverPort', 'autoSendCookies', 'preferredBrowser', 'apiToken',
    'btnColor', 'btnPosition', 'btnSize', 'showQualitySelector', 'adultSitesEnabled',
  ]).then(function (result) {
    portInput.value = result.serverPort || 6969;
    cookiesToggle.checked = result.autoSendCookies !== false;
    if (tokenInput) tokenInput.value = result.apiToken || '';
    if (browserSelect && result.preferredBrowser) {
      browserSelect.value = result.preferredBrowser;
    }
    if (btnColor && result.btnColor) btnColor.value = result.btnColor;
    if (btnPosition && result.btnPosition) btnPosition.value = result.btnPosition;
    if (btnSize && result.btnSize) btnSize.value = result.btnSize;
    if (qualityToggle && typeof result.showQualitySelector === 'boolean') {
      qualityToggle.checked = result.showQualitySelector;
    }
    if (adultToggle) adultToggle.checked = result.adultSitesEnabled === true;
  });

  function persistSettings(extra) {
    var port = parseInt(portInput.value, 10);
    if (!port || port < 1024 || port > 65535) {
      connectionMsg.textContent = t('invalidPort', 'Port must be 1024–65535');
      connectionMsg.style.color = '#F44336';
      port = 6969;
      portInput.value = port;
    }
    var payload = {
      serverPort: port,
      autoSendCookies: cookiesToggle.checked,
      apiToken: tokenInput ? tokenInput.value.trim() : '',
      btnColor: btnColor ? btnColor.value : '#6C5DD3',
      btnPosition: btnPosition ? btnPosition.value : 'top-right',
      btnSize: btnSize ? btnSize.value : 'normal',
      showQualitySelector: qualityToggle ? qualityToggle.checked : true,
      adultSitesEnabled: adultToggle ? adultToggle.checked : false,
    };
    if (browserSelect) {
      payload.preferredBrowser = browserSelect.value;
    }
    if (extra) {
      Object.keys(extra).forEach(function (k) { payload[k] = extra[k]; });
    }
    return api.storage.local.set(payload).then(function () {
      api.runtime.sendMessage({ type: 'CONFIG_UPDATED' }, function () {
        void api.runtime.lastError;
      });
    });
  }

  function saveSettings() {
    persistSettings();
  }

  function onAdultToggle() {
    if (!adultToggle) return;
    if (adultToggle.checked && api.permissions && api.permissions.request) {
      api.permissions.request({ origins: ADULT_ORIGINS }).then(function (granted) {
        if (!granted) adultToggle.checked = false;
        persistSettings({ adultSitesEnabled: adultToggle.checked });
      }).catch(function () {
        adultToggle.checked = false;
        persistSettings({ adultSitesEnabled: false });
      });
      return;
    }
    persistSettings({ adultSitesEnabled: false });
  }

  portInput.addEventListener('change', saveSettings);
  cookiesToggle.addEventListener('change', saveSettings);
  if (tokenInput) tokenInput.addEventListener('change', saveSettings);
  if (browserSelect) browserSelect.addEventListener('change', saveSettings);
  if (btnColor) btnColor.addEventListener('change', saveSettings);
  if (btnPosition) btnPosition.addEventListener('change', saveSettings);
  if (btnSize) btnSize.addEventListener('change', saveSettings);
  if (qualityToggle) qualityToggle.addEventListener('change', saveSettings);
  if (adultToggle) adultToggle.addEventListener('change', onAdultToggle);

  function renderList(items) {
    listContainer.textContent = '';
    if (!items || items.length === 0) {
      var empty = document.createElement('div');
      empty.className = 'empty-state';
      empty.textContent = t('noDownloads', 'No active downloads');
      listContainer.appendChild(empty);
      return;
    }

    items.forEach(function (item) {
      var div = document.createElement('div');
      div.className = 'download-item';

      var statusTextLabel = statusLabel(item.status);
      var progressPct = ((item.progress || 0) * 100).toFixed(1);
      var title = item.title || item.url || 'Downloading...';

      var row = document.createElement('div');
      row.className = 'item-row';

      var titleEl = document.createElement('div');
      titleEl.className = 'item-title';
      titleEl.title = title;
      titleEl.textContent = title;

      var statusEl = document.createElement('div');
      statusEl.className = 'item-status';
      statusEl.style.color = item.status === 4 ? '#4CAF50' : '#AAA';
      statusEl.textContent = statusTextLabel;

      row.appendChild(titleEl);
      row.appendChild(statusEl);
      div.appendChild(row);

      if (item.status === 1 || item.status === 2 || item.status === 3) {
        var bar = document.createElement('div');
        bar.className = 'progress-bar';
        var fill = document.createElement('div');
        fill.className = 'progress-fill';
        fill.style.width = progressPct + '%';
        bar.appendChild(fill);
        div.appendChild(bar);
      }

      var meta = document.createElement('div');
      meta.className = 'item-meta';
      var size = document.createElement('span');
      size.textContent = item.totalSize || '';
      var speed = document.createElement('span');
      speed.textContent = item.speed || '';
      meta.appendChild(size);
      meta.appendChild(speed);
      div.appendChild(meta);

      listContainer.appendChild(div);
    });
  }

  api.storage.local.get(['recentDownloads']).then(function (result) {
    renderList(result.recentDownloads || []);
  });

  if (api.storage.onChanged) {
    api.storage.onChanged.addListener(function (changes, area) {
      if (area === 'local' && changes.recentDownloads) {
        renderList(changes.recentDownloads.newValue);
      }
      if (area === 'local' && (changes.isConnected || changes.lastAuthError)) {
        updateStatus();
      }
    });
  }

  if (sendTabBtn) {
    sendTabBtn.addEventListener('click', function () {
      sendTabBtn.disabled = true;
      api.runtime.sendMessage({ type: 'SEND_CURRENT_TAB' }, function (response) {
        sendTabBtn.disabled = false;
        if (api.runtime.lastError || !response || !response.ok) {
          var err = (response && response.error) || 'failed';
          connectionMsg.textContent = err === 'app_offline'
            ? t('appOffline', 'App offline')
            : t('sendFailed', 'Could not send tab');
          connectionMsg.style.color = '#F44336';
          return;
        }
        connectionMsg.textContent = t('tabSent', 'Tab sent to app');
        connectionMsg.style.color = '#4CAF50';
      });
    });
  }

  if (openFeedBtn) {
    openFeedBtn.addEventListener('click', function () {
      openFeedBtn.disabled = true;

      var openOperation;
      try {
        if (api.sidebarAction && api.sidebarAction.open) {
          openOperation = api.sidebarAction.open();
        } else if (
          api.sidePanel &&
          api.sidePanel.open &&
          api.tabs &&
          api.tabs.query
        ) {
          openOperation = api.tabs.query({
            active: true,
            currentWindow: true,
          }).then(function (tabs) {
            var tab = tabs && tabs[0];
            if (!tab || typeof tab.windowId !== 'number') {
              throw new Error('window_unavailable');
            }
            return api.sidePanel.open({ windowId: tab.windowId });
          });
        } else {
          throw new Error('feed_panel_unavailable');
        }
      } catch (e) {
        openOperation = Promise.reject(e);
      }

      Promise.resolve(openOperation).then(function () {
        connectionMsg.textContent = t('xFeedOpened', 'X Feed panel opened');
        connectionMsg.style.color = '#4CAF50';
      }).catch(function () {
        connectionMsg.textContent = t('xFeedOpenFailed', 'Could not open X Feed panel');
        connectionMsg.style.color = '#F44336';
      }).finally(function () {
        openFeedBtn.disabled = false;
      });
    });
  }

  if (testBtn) {
    testBtn.addEventListener('click', function () {
      testBtn.disabled = true;
      api.runtime.sendMessage({ type: 'TEST_CONNECTION' }, function (response) {
        testBtn.disabled = false;
        if (api.runtime.lastError || !response || !response.ok) {
          setConnectionUi(false, t('testFailed', 'Connection test failed'));
          return;
        }
        setConnectionUi(true, t('testOk', 'PING/PONG OK'));
      });
    });
  }
})();
