const Common = window.ModernDownloaderCommon;

const elements = {
  activeSite: document.getElementById('active-site'),
  appVersion: document.getElementById('app-version'),
  clearRecentBtn: document.getElementById('clear-recent-btn'),
  connectionError: document.getElementById('connection-error'),
  connectionLog: document.getElementById('connection-log'),
  cookieBrowserSelect: document.getElementById('cookie-browser-select'),
  cookiesToggle: document.getElementById('cookies-toggle'),
  debugToggle: document.getElementById('debug-toggle'),
  downloadDetectedBtn: document.getElementById('download-detected-btn'),
  downloadPageBtn: document.getElementById('download-page-btn'),
  downloadsList: document.getElementById('downloads-list'),
  lastSend: document.getElementById('last-send'),
  notificationsToggle: document.getElementById('notifications-toggle'),
  openAppBtn: document.getElementById('open-app-btn'),
  portInput: document.getElementById('port-input'),
  protocolVersion: document.getElementById('protocol-version'),
  recentTitle: document.getElementById('recent-title'),
  resetSettingsBtn: document.getElementById('reset-settings-btn'),
  siteAccessMode: document.getElementById('site-access-mode'),
  siteRulesInput: document.getElementById('site-rules-input'),
  statusIndicator: document.getElementById('status-indicator'),
  statusText: document.getElementById('status-text'),
  testConnectionBtn: document.getElementById('test-connection-btn'),
  toggleCurrentSiteBtn: document.getElementById('toggle-current-site-btn'),
  tokenInput: document.getElementById('token-input'),
};

let popupState = {
  state: null,
  settings: null,
  recentDownloads: [],
  lastSuccessfulSend: null,
  connectionLog: [],
  context: null,
};

function storageSet(area, values) {
  return new Promise((resolve) => chrome.storage[area].set(values, resolve));
}

function sendRuntimeMessage(message) {
  return new Promise((resolve) => {
    chrome.runtime.sendMessage(message, (response) => {
      if (chrome.runtime.lastError) {
        resolve({
          ok: false,
          code: 'RUNTIME_ERROR',
          message: chrome.runtime.lastError.message,
        });
        return;
      }

      resolve(response);
    });
  });
}

function formatDate(timestamp) {
  if (!timestamp) {
    return '-';
  }

  try {
    return new Date(timestamp).toLocaleString();
  } catch (_) {
    return '-';
  }
}

function setButtonState(button, enabled) {
  button.disabled = !enabled;
  button.style.opacity = enabled ? '1' : '0.55';
}

function renderStatus(state) {
  const current = state || { status: 'disconnected', lastError: '' };
  const connected = current.status === 'connected';
  const connecting = current.status === 'connecting';
  const legacyMode = current.legacyMode === true;

  elements.statusIndicator.className = `status-indicator ${connected ? 'connected' : connecting ? 'connecting' : 'offline'}`;
  elements.statusText.textContent = connected
    ? legacyMode
      ? 'Connected in legacy compatibility mode'
      : `Connected to app ${current.appVersion || ''}`.trim()
    : connecting
      ? 'Connecting to local app...'
      : current.status === 'auth_error'
        ? 'Auth failed. Check the port or token.'
        : 'Desktop app offline';

  elements.protocolVersion.textContent = current.protocolVersion || Common.PROTOCOL_VERSION;
  elements.appVersion.textContent = current.appVersion || '-';

  if (current.lastError) {
    elements.connectionError.textContent = current.lastError;
    elements.connectionError.classList.remove('hidden');
  } else {
    elements.connectionError.textContent = '';
    elements.connectionError.classList.add('hidden');
  }
}

function renderLog(entries) {
  elements.connectionLog.textContent = '';
  const items = Array.isArray(entries) ? entries.slice(0, 5) : [];

  if (items.length === 0) {
    return;
  }

  for (const entry of items) {
    const row = document.createElement('div');
    row.className = 'log-item';

    const level = document.createElement('strong');
    level.textContent = entry.level || 'info';

    const text = document.createElement('span');
    const timestamp = formatDate(entry.timestamp);
    text.textContent = `${timestamp} - ${Common.sanitizeText(entry.message, 140)}`;

    row.appendChild(level);
    row.appendChild(text);
    elements.connectionLog.appendChild(row);
  }
}

function createMetaText(left, right) {
  const row = document.createElement('div');
  row.className = 'download-meta';

  const leftSpan = document.createElement('span');
  leftSpan.textContent = Common.sanitizeText(left, 48) || '-';

  const rightSpan = document.createElement('span');
  rightSpan.textContent = Common.sanitizeText(right, 36) || '-';

  row.appendChild(leftSpan);
  row.appendChild(rightSpan);
  return row;
}

function renderDownloads(items) {
  const list = Array.isArray(items) ? items : [];
  elements.recentTitle.textContent = `Recent Jobs (${list.length})`;
  elements.downloadsList.textContent = '';

  if (list.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'empty-state';
    empty.textContent = 'No recent jobs';
    elements.downloadsList.appendChild(empty);
    return;
  }

  const statusMap = ['Queued', 'Queued', 'Extracting', 'Downloading', 'Completed', 'Failed', 'Paused', 'Canceled', 'Duplicate'];

  for (const item of list) {
    const card = document.createElement('div');
    card.className = 'download-item';

    const top = document.createElement('div');
    top.className = 'download-top';

    const title = document.createElement('div');
    title.className = 'download-title';
    title.textContent = Common.sanitizeText(item.title || item.request?.url || 'Untitled job', 90);
    title.title = item.request?.url || item.title || '';

    const status = document.createElement('div');
    status.className = 'download-status';
    status.textContent = statusMap[item.status] || 'Processing';

    top.appendChild(title);
    top.appendChild(status);
    card.appendChild(top);

    if (item.status === 2 || item.status === 3) {
      const progressBar = document.createElement('div');
      progressBar.className = 'progress-bar';
      const fill = document.createElement('div');
      fill.className = 'progress-fill';
      fill.style.width = `${Math.max(0, Math.min(100, Number(item.progress || 0) * 100))}%`;
      progressBar.appendChild(fill);
      card.appendChild(progressBar);
    }

    card.appendChild(
      createMetaText(
        item.request?.url || item.id || '',
        [item.totalSize || '', item.speed || ''].filter(Boolean).join('  '),
      ),
    );

    elements.downloadsList.appendChild(card);
  }
}

function renderLastSend(item) {
  if (!item) {
    elements.lastSend.textContent = '-';
    return;
  }

  const site = item.site || 'Unknown';
  elements.lastSend.textContent = `${site} - ${formatDate(item.sentAt)}`;
}

function renderContext(context) {
  popupState.context = context;
  const host = context?.activeSiteHost ? Common.stripCommonPrefixes(context.activeSiteHost) : '';
  elements.activeSite.textContent = host || 'Unsupported';

  setButtonState(elements.downloadPageBtn, Boolean(context?.canDownloadPage));
  setButtonState(elements.downloadDetectedBtn, Array.isArray(context?.detectedTargets) && context.detectedTargets.length > 0);

  const settings = popupState.settings || Common.DEFAULT_SYNC_SETTINGS;
  const enabled = host
    ? Common.isSiteAllowed(host, settings.siteAccessMode, settings.siteRules)
    : false;
  elements.toggleCurrentSiteBtn.textContent = enabled ? 'Disable on current site' : 'Enable on current site';
  setButtonState(elements.toggleCurrentSiteBtn, Boolean(host));
}

function renderSettings(settings) {
  const current = settings || { ...Common.DEFAULT_LOCAL_SETTINGS, ...Common.DEFAULT_SYNC_SETTINGS };
  popupState.settings = current;

  elements.portInput.value = Common.clampPort(current.serverPort, Common.DEFAULT_LOCAL_SETTINGS.serverPort);
  elements.tokenInput.value = current.apiToken || '';
  elements.cookiesToggle.checked = current.autoSendCookies !== false;
  elements.cookieBrowserSelect.value = current.cookieBrowserPreference || 'auto';
  elements.notificationsToggle.checked = current.notificationsEnabled === true;
  elements.debugToggle.checked = current.debugMode === true;
  elements.siteAccessMode.value = current.siteAccessMode || 'supported';
  elements.siteRulesInput.value = Common.normalizeRuleList(current.siteRules).join('\n');
}

async function loadState() {
  const response = await sendRuntimeMessage({ type: 'GET_EXTENSION_STATE' });
  if (response?.ok) {
    popupState = {
      ...popupState,
      state: response.state,
      settings: response.settings,
      recentDownloads: response.recentDownloads,
      lastSuccessfulSend: response.lastSuccessfulSend,
      connectionLog: response.connectionLog,
    };
  }

  const contextResponse = await sendRuntimeMessage({ type: 'GET_ACTIVE_TAB_CONTEXT' });
  renderStatus(popupState.state);
  renderSettings(popupState.settings);
  renderDownloads(popupState.recentDownloads);
  renderLastSend(popupState.lastSuccessfulSend);
  renderLog(popupState.connectionLog);
  renderContext(contextResponse?.ok ? contextResponse.context : null);
}

async function saveLocalSettings() {
  const port = Common.clampPort(elements.portInput.value, Common.DEFAULT_LOCAL_SETTINGS.serverPort);
  const payload = {
    serverPort: port,
    apiToken: elements.tokenInput.value.trim(),
    autoSendCookies: elements.cookiesToggle.checked,
    cookieBrowserPreference: elements.cookieBrowserSelect.value,
    notificationsEnabled: elements.notificationsToggle.checked,
    debugMode: elements.debugToggle.checked,
  };
  await storageSet('local', payload);
}

async function saveSyncSettings() {
  const payload = {
    siteAccessMode: elements.siteAccessMode.value,
    siteRules: Common.normalizeRuleList(elements.siteRulesInput.value),
  };
  await storageSet('sync', payload);
}

async function toggleCurrentSite() {
  const host = popupState.context?.activeSiteHost;
  if (!host) {
    return;
  }

  const normalizedHost = Common.stripCommonPrefixes(host);
  const currentMode = elements.siteAccessMode.value;
  const currentRules = Common.normalizeRuleList(elements.siteRulesInput.value);
  const exists = currentRules.some((rule) => Common.matchesRule(normalizedHost, rule));

  let nextMode = currentMode;
  const nextRules = [...currentRules];

  if (currentMode === 'allowlist') {
    if (exists) {
      const filtered = nextRules.filter((rule) => !Common.matchesRule(normalizedHost, rule));
      elements.siteRulesInput.value = filtered.join('\n');
    } else {
      nextRules.push(normalizedHost);
      elements.siteRulesInput.value = Common.normalizeRuleList(nextRules).join('\n');
    }
  } else {
    nextMode = 'blocklist';
    elements.siteAccessMode.value = nextMode;
    if (exists) {
      elements.siteRulesInput.value = nextRules
        .filter((rule) => !Common.matchesRule(normalizedHost, rule))
        .join('\n');
    } else {
      nextRules.push(normalizedHost);
      elements.siteRulesInput.value = Common.normalizeRuleList(nextRules).join('\n');
    }
  }

  await saveSyncSettings();
  await loadState();
}

elements.openAppBtn.addEventListener('click', () => {
  window.open('moderndownloader://open', '_blank');
});

elements.testConnectionBtn.addEventListener('click', async () => {
  elements.testConnectionBtn.textContent = 'Testing...';
  const result = await sendRuntimeMessage({ type: 'TEST_CONNECTION' });
  elements.testConnectionBtn.textContent = 'Test Connection';
  if (!result?.ok) {
    elements.connectionError.textContent = result?.message || 'Connection test failed.';
    elements.connectionError.classList.remove('hidden');
  }
  await loadState();
});

elements.downloadPageBtn.addEventListener('click', async () => {
  if (!popupState.context?.pageUrl) {
    return;
  }
  await sendRuntimeMessage({ type: 'DOWNLOAD_CURRENT_PAGE', pageUrl: popupState.context.pageUrl });
  await loadState();
});

elements.downloadDetectedBtn.addEventListener('click', async () => {
  await sendRuntimeMessage({ type: 'DOWNLOAD_DETECTED_VIDEO' });
  await loadState();
});

elements.clearRecentBtn.addEventListener('click', async () => {
  await sendRuntimeMessage({ type: 'CLEAR_RECENT' });
  await loadState();
});

elements.resetSettingsBtn.addEventListener('click', async () => {
  await sendRuntimeMessage({ type: 'RESET_SETTINGS' });
  await loadState();
});

elements.toggleCurrentSiteBtn.addEventListener('click', async () => {
  await toggleCurrentSite();
});

elements.portInput.addEventListener('change', saveLocalSettings);
elements.tokenInput.addEventListener('change', saveLocalSettings);
elements.cookiesToggle.addEventListener('change', saveLocalSettings);
elements.cookieBrowserSelect.addEventListener('change', saveLocalSettings);
elements.notificationsToggle.addEventListener('change', saveLocalSettings);
elements.debugToggle.addEventListener('change', saveLocalSettings);
elements.siteAccessMode.addEventListener('change', async () => {
  await saveSyncSettings();
  await loadState();
});
elements.siteRulesInput.addEventListener('change', async () => {
  await saveSyncSettings();
  await loadState();
});

chrome.storage.onChanged.addListener(async (changes, area) => {
  if (area === 'local' || area === 'sync') {
    const interestingKeys = [
      'extensionState',
      'recentDownloads',
      'lastSuccessfulSend',
      'connectionLog',
      'serverPort',
      'apiToken',
      'autoSendCookies',
      'cookieBrowserPreference',
      'notificationsEnabled',
      'debugMode',
      'siteAccessMode',
      'siteRules',
    ];

    if (interestingKeys.some((key) => Boolean(changes[key]))) {
      await loadState();
    }
  }
});

loadState();
