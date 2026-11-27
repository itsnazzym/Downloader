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
  var syncTikTokBtn = document.getElementById('sync-tiktok-btn');
  var qualityToggle = document.getElementById('quality-toggle');
  var messageOverrideUntil = 0;

  var toastTimer = null;
  var lastToast = '';
  function showFeedback(message, error) {
    messageOverrideUntil = Date.now() + 6000;
    lastToast = message;
    connectionMsg.textContent = message;
    connectionMsg.className = 'toast show' + (error ? ' bad' : '');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { connectionMsg.className = 'toast'; }, 4500);
  }

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
        document.documentElement.dir = document.documentElement.lang === 'ar' ? 'rtl' : 'ltr';
      }
    } catch (e) { /* keep existing html lang */ }
  }

  function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      var msg = t(key, el.textContent);
      if (msg) el.textContent = msg;
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(function (el) {
      el.placeholder = t(el.getAttribute('data-i18n-placeholder'), el.placeholder);
    });
    document.querySelectorAll('[data-i18n-aria]').forEach(function (el) {
      el.setAttribute('aria-label', t(el.getAttribute('data-i18n-aria'), el.getAttribute('aria-label') || ''));
    });
  }

  function statusLabel(index) {
    var key = STATUS_KEYS[index];
    var fallback = STATUS_FALLBACKS[index] || t('statusProcessing', 'Processing');
    return key ? t(key, fallback) : fallback;
  }

  function setConnectionUi(connected, detail) {
    document.body.dataset.conn = connected ? 'online' : 'offline';
    var label = connected ? t('connected', 'Connecté') : t('popupNotLinked', 'Non relié');
    statusDot.title = label;
    statusText.textContent = label;
    // Poll results repeat every 2 s: only surface a problem once.
    if (!connected && detail && detail !== lastToast) showFeedback(detail, true);
    if (connected && document.body.dataset.setup && detail) {
      delete document.body.dataset.setup;
    }
  }

  function updateStatus() {
    api.storage.local.get(['isConnected', 'lastAuthError', 'apiToken']).then(function (res) {
      var rawToken = (res.apiToken || '').trim();
      if (rawToken && (rawToken.indexOf('\\') >= 0 || rawToken.indexOf('/') >= 0 || /^[a-zA-Z]:/.test(rawToken))) {
        setConnectionUi(false, t('tokenIsPathError', 'Chemin de dossier détecté au lieu du jeton API !'));
        return;
      }
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

  if (typeof MD_THEME !== 'undefined') MD_THEME.init(api);
  applyDocumentLang();
  applyI18n();
  updateStatus();
  setInterval(updateStatus, 2000);

  // Collection sync only makes sense while a TikTok page is active.
  if (syncTikTokBtn && api.tabs && api.tabs.query) {
    Promise.resolve(api.tabs.query({ active: true, currentWindow: true }))
      .then(function (tabs) {
        var url = tabs && tabs[0] && tabs[0].url;
        var onTikTok = /^https?:\/\/(?:[^/]+\.)?tiktok\.com\//i.test(url || '');
        syncTikTokBtn.disabled = !onTikTok;
        var hint = document.getElementById('sync-hint');
        if (onTikTok && hint) hint.textContent = t('popupSyncHintOn', 'Range tes favoris dans leurs collections.');
      }).catch(function () { syncTikTokBtn.disabled = true; });
  }

  try {
    api.runtime.sendMessage({ type: 'GET_CONNECTION_STATE' }, function (res) {
      if (!api.runtime.lastError && res && res.ok && typeof res.connected === 'boolean') {
        setConnectionUi(res.connected);
      }
    });
  } catch (e) { /* ignore */ }

  api.storage.local.get([
    'serverPort', 'autoSendCookies', 'preferredBrowser', 'apiToken',
    'showQualitySelector', 'adultSitesEnabled',
  ]).then(function (result) {
    portInput.value = result.serverPort || 6969;
    cookiesToggle.checked = result.autoSendCookies !== false;
    if (tokenInput) tokenInput.value = result.apiToken || '';
    if (browserSelect && result.preferredBrowser) {
      browserSelect.value = result.preferredBrowser;
    }
    if (qualityToggle && typeof result.showQualitySelector === 'boolean') {
      qualityToggle.checked = result.showQualitySelector;
    }
  });

  function persistSettings(extra) {
    var port = parseInt(portInput.value, 10);
    if (!port || port < 1024 || port > 65535) {
      showFeedback(t('invalidPort', 'Port must be 1024–65535'), true);
      port = 6969;
      portInput.value = port;
    }
    var payload = {
      serverPort: port,
      autoSendCookies: cookiesToggle.checked,
      apiToken: tokenInput ? tokenInput.value.trim() : '',
      showQualitySelector: qualityToggle ? qualityToggle.checked : true,
      adultSitesEnabled: true,
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

  portInput.addEventListener('change', saveSettings);
  cookiesToggle.addEventListener('change', saveSettings);
  if (tokenInput) {
    var tokenDebounce = null;
    tokenInput.addEventListener('input', function () {
      clearTimeout(tokenDebounce);
      tokenDebounce = setTimeout(saveSettings, 300);
    });
    tokenInput.addEventListener('change', saveSettings);
  }
  var toggleTokenBtn = document.getElementById('toggle-token-btn');
  if (toggleTokenBtn && tokenInput) {
    toggleTokenBtn.addEventListener('click', function () {
      if (tokenInput.type === 'password') {
        tokenInput.type = 'text';
        toggleTokenBtn.setAttribute('aria-label', t('hideToken', 'Hide token'));
        toggleTokenBtn.title = t('hideToken', 'Hide token');
      } else {
        tokenInput.type = 'password';
        toggleTokenBtn.setAttribute('aria-label', t('showToken', 'Show token'));
        toggleTokenBtn.title = t('showToken', 'Show token');
      }
    });
  }
  if (browserSelect) browserSelect.addEventListener('change', saveSettings);
  if (qualityToggle) qualityToggle.addEventListener('change', saveSettings);

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
      statusEl.dataset.tone = item.status === 4 ? 'done'
        : (item.status === 5 || item.status === 6) ? 'bad'
        : (item.status === 1 || item.status === 2 || item.status === 3) ? 'active' : 'idle';
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

  var openSettingsBtn = document.getElementById('open-settings-btn');
  var closeSettingsBtn = document.getElementById('close-settings-btn');
  var editTokenBtn = document.getElementById('edit-token-btn');
  var viewHome = document.getElementById('view-home');
  var viewSettings = document.getElementById('view-settings');
  function showView(name) {
    document.body.dataset.view = name;
    viewHome.hidden = name !== 'home';
    viewSettings.hidden = name !== 'settings';
  }
  if (openSettingsBtn) openSettingsBtn.addEventListener('click', function () { showView('settings'); });
  if (closeSettingsBtn) closeSettingsBtn.addEventListener('click', function () { showView('home'); });
  if (editTokenBtn) editTokenBtn.addEventListener('click', function () {
    document.body.dataset.setup = 'open';
    showView('home');
    if (tokenInput) tokenInput.focus();
  });

  if (sendTabBtn) {
    sendTabBtn.addEventListener('click', function () {
      sendTabBtn.disabled = true;
      api.runtime.sendMessage({ type: 'SEND_CURRENT_TAB' }, function (response) {
        sendTabBtn.disabled = false;
        if (api.runtime.lastError || !response || !response.ok) {
          var err = (response && response.error) || 'failed';
          showFeedback(err === 'app_offline'
            ? t('appOffline', 'App offline')
            : t('sendFailed', 'Could not send tab'), true);
          return;
        }
        showFeedback(t('tabSent', 'Tab sent to app'), false);
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
        showFeedback(t('xFeedOpened', 'Video panel opened'), false);
      }).catch(function () {
        showFeedback(t('xFeedOpenFailed', 'Could not open video panel'), true);
      }).finally(function () {
        openFeedBtn.disabled = false;
      });
    });
  }

  if (testBtn) {
    testBtn.addEventListener('click', function () {
      var rawToken = tokenInput ? tokenInput.value.trim() : '';
      if (rawToken && (rawToken.indexOf('\\') >= 0 || rawToken.indexOf('/') >= 0 || /^[a-zA-Z]:/.test(rawToken))) {
        setConnectionUi(false, t('tokenIsPathError', 'Chemin de dossier détecté au lieu du jeton API !'));
        return;
      }
      testBtn.disabled = true;
      showFeedback(t('connecting', 'Connexion…'), false);
      persistSettings().then(function () {
        api.runtime.sendMessage({ type: 'TEST_CONNECTION' }, function (response) {
          testBtn.disabled = false;
          if (api.runtime.lastError || !response || !response.ok) {
            var reason = (response && response.error);
            var msg = reason === 'auth_failed'
              ? t('authFailed', 'Auth failed — check token')
              : (reason === 'app_offline'
                  ? t('appOffline', 'App offline')
                  : t('testFailed', 'Connection test failed'));
            setConnectionUi(false, msg);
            return;
          }
          setConnectionUi(true, t('testOk', 'PING/PONG OK'));
          showFeedback(t('popupLinked', 'TapLoad est relié.'), false);
        });
      });
    });
  }

  if (syncTikTokBtn) {
    syncTikTokBtn.addEventListener('click', function () {
      syncTikTokBtn.disabled = true;
      var label = syncTikTokBtn.querySelector('.tile-title');
      if (label) label.textContent = t('syncInProgress', 'Synchro en cours…');
      api.runtime.sendMessage({ type: 'MD_TRIGGER_TIKTOK_SYNC' }, function (response) {
        var failed = Boolean(api.runtime.lastError || !response || response.ok === false);
        showFeedback(failed
          ? t('syncOpenTikTok', 'Open TikTok collections and try again.')
          : t('syncStarted', 'Sync started on the TikTok page.'), failed);
        syncTikTokBtn.disabled = false;
        if (label) label.textContent = t('syncTikTok', 'Classer mes favoris');
      });
    });
  }
})();
