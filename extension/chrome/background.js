importScripts('common.js');

const Common = self.ModernDownloaderCommon;
const api = chrome;
const action = api.action;
const manifest = api.runtime.getManifest();

const STORAGE_KEYS = {
  local: {
    apiToken: 'apiToken',
    autoSendCookies: 'autoSendCookies',
    connectionLog: 'connectionLog',
    cookieBrowserPreference: 'cookieBrowserPreference',
    debugMode: 'debugMode',
    extensionState: 'extensionState',
    lastSuccessfulSend: 'lastSuccessfulSend',
    notificationsEnabled: 'notificationsEnabled',
    recentDownloads: 'recentDownloads',
    serverPort: 'serverPort',
  },
  sync: {
    siteAccessMode: 'siteAccessMode',
    siteRules: 'siteRules',
  },
};

const DEFAULT_EXTENSION_STATE = {
  status: 'disconnected',
  authenticated: false,
  protocolVersion: Common.PROTOCOL_VERSION,
  extensionVersion: manifest.version,
  appVersion: null,
  legacyMode: false,
  lastError: '',
  retryInMs: 0,
  lastConnectedAt: null,
};

let socket = null;
let currentPort = Common.DEFAULT_LOCAL_SETTINGS.serverPort;
let reconnectAttempt = 0;
let reconnectTimer = null;
let authTimeoutTimer = null;
let connectPromise = null;
let resolveConnectPromise = null;
let contextMenuSyncPromise = null;
let stateCache = { ...DEFAULT_EXTENSION_STATE };
let badgeResetTimer = null;

function storageGet(area, keys) {
  return new Promise((resolve) => api.storage[area].get(keys, resolve));
}

function storageSet(area, values) {
  return new Promise((resolve) => api.storage[area].set(values, resolve));
}

function isWebTab(tab) {
  return Boolean(tab?.url && /^https?:\/\//i.test(tab.url));
}

async function getUserFacingActiveTab() {
  const candidates = await api.tabs.query({ lastFocusedWindow: true });
  const activeWebTab = candidates.find((tab) => tab.active && isWebTab(tab));
  if (activeWebTab) {
    return activeWebTab;
  }

  return candidates.find(isWebTab) || null;
}

async function ensureDefaults() {
  const local = await storageGet('local', Object.keys(Common.DEFAULT_LOCAL_SETTINGS));
  const missingLocal = {};
  for (const [key, value] of Object.entries(Common.DEFAULT_LOCAL_SETTINGS)) {
    if (local[key] === undefined) {
      missingLocal[key] = value;
    }
  }
  if (Object.keys(missingLocal).length > 0) {
    await storageSet('local', missingLocal);
  }

  const sync = await storageGet('sync', Object.keys(Common.DEFAULT_SYNC_SETTINGS));
  const missingSync = {};
  for (const [key, value] of Object.entries(Common.DEFAULT_SYNC_SETTINGS)) {
    if (sync[key] === undefined) {
      missingSync[key] = value;
    }
  }
  if (Object.keys(missingSync).length > 0) {
    await storageSet('sync', missingSync);
  }
}

async function appendConnectionLog(level, message) {
  const result = await storageGet('local', [STORAGE_KEYS.local.connectionLog]);
  const current = Array.isArray(result.connectionLog) ? result.connectionLog : [];
  current.unshift({
    level,
    message: Common.sanitizeText(message, 180),
    timestamp: Date.now(),
  });
  await storageSet('local', {
    [STORAGE_KEYS.local.connectionLog]: current.slice(0, 20),
  });
}

function setBadge(text, color) {
  action.setBadgeText({ text });
  action.setBadgeBackgroundColor({ color });
}

function syncBadgeWithState() {
  if (badgeResetTimer) {
    clearTimeout(badgeResetTimer);
    badgeResetTimer = null;
  }

  switch (stateCache.status) {
    case 'connected':
      setBadge('ON', '#2E7D32');
      break;
    case 'connecting':
      setBadge('...', '#1565C0');
      break;
    case 'auth_error':
    case 'error':
      setBadge('ERR', '#C62828');
      break;
    default:
      setBadge('OFF', '#616161');
      break;
  }
}

async function updateState(patch) {
  stateCache = { ...stateCache, ...patch };
  await storageSet('local', {
    [STORAGE_KEYS.local.extensionState]: stateCache,
  });
  syncBadgeWithState();
}

async function getRuntimeSettings() {
  const local = await storageGet('local', [
    STORAGE_KEYS.local.serverPort,
    STORAGE_KEYS.local.apiToken,
    STORAGE_KEYS.local.autoSendCookies,
    STORAGE_KEYS.local.cookieBrowserPreference,
    STORAGE_KEYS.local.notificationsEnabled,
  ]);
  const sync = await storageGet('sync', [
    STORAGE_KEYS.sync.siteAccessMode,
    STORAGE_KEYS.sync.siteRules,
  ]);

  return {
    serverPort: Common.clampPort(local.serverPort, Common.DEFAULT_LOCAL_SETTINGS.serverPort),
    apiToken: typeof local.apiToken === 'string' ? local.apiToken : '',
    autoSendCookies: local.autoSendCookies !== false,
    cookieBrowserPreference:
      local.cookieBrowserPreference || local.preferredBrowser || Common.DEFAULT_LOCAL_SETTINGS.cookieBrowserPreference,
    notificationsEnabled: local.notificationsEnabled === true,
    siteAccessMode: sync.siteAccessMode || Common.DEFAULT_SYNC_SETTINGS.siteAccessMode,
    siteRules: Common.normalizeRuleList(sync.siteRules),
  };
}

async function notifyUser(title, message) {
  const result = await storageGet('local', [STORAGE_KEYS.local.notificationsEnabled]);
  if (result.notificationsEnabled !== true || !api.notifications) {
    return;
  }

  api.notifications.create({
    type: 'basic',
    iconUrl: 'icons/icon48.png',
    title,
    message,
  });
}

async function fetchLocalJson(port, path) {
  const endpoints = [`http://127.0.0.1:${port}${path}`, `http://localhost:${port}${path}`];

  for (const endpoint of endpoints) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 2500);
      const response = await fetch(endpoint, {
        method: 'GET',
        cache: 'no-store',
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (response.ok) {
        return await response.json();
      }
    } catch (_) {}
  }

  return null;
}

async function ensureApiToken(port) {
  const current = await storageGet('local', [STORAGE_KEYS.local.apiToken]);
  if (Common.isValidToken(current.apiToken)) {
    return current.apiToken;
  }

  const config = await fetchLocalJson(port, '/extension-config');
  if (config && Common.isValidToken(config.apiToken)) {
    await storageSet('local', { [STORAGE_KEYS.local.apiToken]: config.apiToken });
    return config.apiToken;
  }

  return '';
}

async function probeServerStatus(port) {
  const status = await fetchLocalJson(port, '/status');
  if (!status || status.status !== 'running') {
    return null;
  }

  return status;
}

async function tryLegacyHandshakeFallback() {
  const status = await probeServerStatus(currentPort);
  if (!status) {
    return false;
  }

  const isLegacyServer = !status.protocolVersion && !status.appVersion && status.authRequired !== true;
  if (!isLegacyServer) {
    return false;
  }

  reconnectAttempt = 0;
  await updateState({
    status: 'connected',
    authenticated: true,
    protocolVersion: 'legacy',
    appVersion: 'legacy',
    legacyMode: true,
    lastError: '',
    retryInMs: 0,
    lastConnectedAt: Date.now(),
  });
  await appendConnectionLog('warn', 'Connected in legacy compatibility mode. Update the desktop app to enable authenticated handshake.');
  settleConnectPromise(true);

  const runtimeSettings = await getRuntimeSettings();
  if (runtimeSettings.autoSendCookies) {
    setTimeout(sendCurrentTabCookies, 1000);
  }

  return true;
}

function clearReconnectTimer() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
}

function clearAuthTimer() {
  if (authTimeoutTimer) {
    clearTimeout(authTimeoutTimer);
    authTimeoutTimer = null;
  }
}

function settleConnectPromise(result) {
  if (resolveConnectPromise) {
    resolveConnectPromise(result);
    resolveConnectPromise = null;
    connectPromise = null;
  }
}

async function scheduleReconnect(reason) {
  clearReconnectTimer();
  reconnectAttempt += 1;
  const retryInMs = Math.min(30000, 1000 * Math.pow(2, reconnectAttempt - 1));
  await appendConnectionLog('warn', `${reason}. Reconnect in ${Math.round(retryInMs / 1000)}s.`);
  await updateState({
    status: stateCache.status === 'auth_error' ? 'auth_error' : 'disconnected',
    authenticated: false,
    retryInMs,
  });

  reconnectTimer = setTimeout(() => {
    connect({ force: true }).catch(() => {});
  }, retryInMs);
}

async function connect(options = {}) {
  await ensureDefaults();

  if (!options.force && socket && socket.readyState === WebSocket.OPEN && stateCache.authenticated) {
    return true;
  }

  if (connectPromise) {
    return connectPromise;
  }

  connectPromise = new Promise((resolve) => {
    resolveConnectPromise = resolve;
  });

  clearReconnectTimer();
  clearAuthTimer();

  const settings = await getRuntimeSettings();
  currentPort = settings.serverPort;
  const token = await ensureApiToken(currentPort);

  await updateState({
    status: 'connecting',
    authenticated: false,
    legacyMode: false,
    lastError: '',
    retryInMs: 0,
    appVersion: null,
  });
  await appendConnectionLog('info', `Connecting to local app on port ${currentPort}.`);

  try {
    socket = new WebSocket(`ws://127.0.0.1:${currentPort}`);
  } catch (error) {
    socket = null;
    await updateState({
      status: 'error',
      lastError: 'Unable to create the WebSocket connection.',
    });
    await appendConnectionLog('error', `WebSocket creation failed: ${error?.message || error}`);
    settleConnectPromise(false);
    scheduleReconnect('Connection setup failed');
    return connectPromise;
  }

  socket.onopen = async () => {
    const hello = {
      type: 'HELLO',
      protocolVersion: Common.PROTOCOL_VERSION,
      extensionVersion: manifest.version,
      token,
      client: 'chrome-extension',
    };

    socket.send(JSON.stringify(hello));
    authTimeoutTimer = setTimeout(async () => {
      if (!stateCache.authenticated) {
        const legacyAccepted = await tryLegacyHandshakeFallback();
        if (legacyAccepted) {
          return;
        }

        await updateState({
          status: 'auth_error',
          lastError: 'Handshake timeout. The app did not confirm authentication.',
        });
        await appendConnectionLog('error', 'Handshake timeout.');
        settleConnectPromise(false);
        socket?.close();
      }
    }, 4000);
  };

  socket.onmessage = async (event) => {
    let message;

    try {
      message = JSON.parse(event.data);
    } catch (_) {
      await appendConnectionLog('error', 'Received invalid JSON from the desktop app.');
      return;
    }

    if (Common.isValidHelloAck(message)) {
      clearAuthTimer();
      reconnectAttempt = 0;
      await updateState({
        status: 'connected',
        authenticated: true,
        protocolVersion: message.protocolVersion,
        appVersion: message.appVersion,
        legacyMode: false,
        lastError: '',
        retryInMs: 0,
        lastConnectedAt: Date.now(),
      });
      await appendConnectionLog('info', `Authenticated against app ${message.appVersion}.`);
      settleConnectPromise(true);

      const runtimeSettings = await getRuntimeSettings();
      if (runtimeSettings.autoSendCookies) {
        setTimeout(sendCurrentTabCookies, 1000);
      }
      return;
    }

    if (message?.type === 'PONG') {
      return;
    }

    if (Common.isValidProgressMessage(message)) {
      await upsertRecentDownload(message.data);
      updateBadgeFromProgress(message.data);
      return;
    }

    if (Common.isValidErrorMessage(message)) {
      const authError = message.code === 'AUTH_INVALID' || message.code === 'PROTOCOL_MISMATCH';
      await updateState({
        status: authError ? 'auth_error' : 'error',
        authenticated: false,
        lastError: message.message || 'The desktop app returned an error.',
      });
      await appendConnectionLog('error', `${message.code}: ${message.message}`);
      settleConnectPromise(false);

      if (authError) {
        const nextToken = await ensureApiToken(currentPort);
        if (socket && socket.readyState === WebSocket.OPEN) {
          socket.close();
        }

        if (Common.isValidToken(nextToken)) {
          setTimeout(() => {
            connect({ force: true }).catch(() => {});
          }, 250);
        }
      }
      return;
    }
  };

  socket.onclose = async () => {
    clearAuthTimer();
    const wasAuthenticated = stateCache.authenticated;
    socket = null;
    await updateState({
      status: stateCache.status === 'auth_error' ? 'auth_error' : 'disconnected',
      authenticated: false,
    });
    if (!wasAuthenticated) {
      settleConnectPromise(false);
    }
    scheduleReconnect('Desktop app disconnected');
  };

  socket.onerror = async () => {
    await updateState({
      status: 'error',
      authenticated: false,
      lastError: 'Unable to reach the desktop app.',
    });
    await appendConnectionLog('error', 'WebSocket error.');
  };

  return connectPromise;
}

async function testConnection() {
  clearReconnectTimer();
  if (socket) {
    try {
      socket.close();
    } catch (_) {}
  }

  const ok = await connect({ force: true });
  return {
    ok,
    state: stateCache,
  };
}

async function upsertRecentDownload(item) {
  const result = await storageGet('local', [STORAGE_KEYS.local.recentDownloads]);
  const downloads = Array.isArray(result.recentDownloads) ? result.recentDownloads : [];
  const next = downloads.filter((entry) => entry.id !== item.id);
  next.unshift(item);

  const update = {
    [STORAGE_KEYS.local.recentDownloads]: next.slice(0, 15),
  };

  if (item.status === 4) {
    let site = 'Unknown';
    try {
      site = Common.getSiteLabel(new URL(item.request?.url || '').hostname);
    } catch (_) {}
    update[STORAGE_KEYS.local.lastSuccessfulSend] = {
      id: item.id,
      url: item.request?.url || '',
      title: item.title || '',
      site,
      sentAt: Date.now(),
    };
  }

  await storageSet('local', update);
}

function updateBadgeFromProgress(item) {
  if (badgeResetTimer) {
    clearTimeout(badgeResetTimer);
    badgeResetTimer = null;
  }

  if (item.status === 2 || item.status === 3) {
    setBadge('DL', '#2E7D32');
    badgeResetTimer = setTimeout(syncBadgeWithState, 2000);
  } else if (item.status === 4) {
    setBadge('OK', '#2E7D32');
    badgeResetTimer = setTimeout(syncBadgeWithState, 2500);
  } else if (item.status === 5) {
    setBadge('ERR', '#C62828');
    badgeResetTimer = setTimeout(syncBadgeWithState, 2500);
  } else {
    syncBadgeWithState();
  }
}

function formatCookiesToNetscape(cookieSets) {
  const lines = [
    '# Netscape HTTP Cookie File',
    '# This file was generated by Modern Downloader Chrome Extension',
    '',
  ];
  const seen = new Set();

  for (const cookie of cookieSets) {
    const key = `${cookie.domain}|${cookie.path}|${cookie.name}`;
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);

    const domain = cookie.domain;
    const includeSubdomains = domain.startsWith('.') ? 'TRUE' : 'FALSE';
    const secure = cookie.secure ? 'TRUE' : 'FALSE';
    const expiration = Math.floor(cookie.expirationDate || Date.now() / 1000 + 3600);

    lines.push(
      [domain, includeSubdomains, cookie.path, secure, expiration, cookie.name, cookie.value].join('\t'),
    );
  }

  return lines.join('\n');
}

async function collectCookiesForRequest(pageUrl, mediaUrl) {
  if (!api.cookies) {
    return '';
  }

  const domains = Common.getCookieDomainCandidatesFromUrls([pageUrl, mediaUrl]);
  const collected = [];

  for (const domain of domains) {
    try {
      const cookies = await api.cookies.getAll({ domain });
      collected.push(...cookies);
    } catch (_) {}
  }

  if (collected.length === 0) {
    return '';
  }

  return formatCookiesToNetscape(collected);
}

async function resolveCookieBrowser() {
  const result = await storageGet('local', [
    STORAGE_KEYS.local.cookieBrowserPreference,
    'preferredBrowser',
  ]);
  const selected = result.cookieBrowserPreference || result.preferredBrowser || 'auto';
  if (selected && selected !== 'auto') {
    return selected;
  }

  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes('edg/')) return 'edge';
  if (ua.includes('opr/') || ua.includes('opera')) return 'opera';
  if (ua.includes('vivaldi')) return 'vivaldi';
  return 'chrome';
}

async function waitForAuthenticatedSocket() {
  if (socket && socket.readyState === WebSocket.OPEN && stateCache.authenticated) {
    return true;
  }

  return connect({ force: true });
}

async function sendPayloadToApp(payload) {
  const connected = await waitForAuthenticatedSocket();
  if (!connected || !socket || socket.readyState !== WebSocket.OPEN || !stateCache.authenticated) {
    return {
      ok: false,
      code: 'APP_OFFLINE',
      message: 'The desktop app is offline or not authenticated.',
    };
  }

  socket.send(JSON.stringify(payload));
  return { ok: true };
}

async function handleDownloadRequest({ mediaUrl, pageUrl, options = {} }) {
  const settings = await getRuntimeSettings();
  const validation = Common.validateVideoTarget(mediaUrl, pageUrl);

  if (!validation.ok) {
    await updateState({
      lastError: validation.message,
      status: stateCache.authenticated ? 'connected' : 'error',
    });
    await appendConnectionLog('warn', validation.message);
    await notifyUser('Modern Downloader', validation.message);
    return validation;
  }

  if (pageUrl) {
    const page = Common.toUrl(pageUrl);
    if (
      page &&
      !Common.isSiteAllowed(page.hostname, settings.siteAccessMode, settings.siteRules)
    ) {
      return {
        ok: false,
        code: 'SITE_DISABLED',
        message: 'The extension is disabled for this site.',
      };
    }
  }

  const cookies = settings.autoSendCookies ? await collectCookiesForRequest(pageUrl, mediaUrl) : '';
  const cookieBrowser = await resolveCookieBrowser();
  const payload = {
    type: 'DOWNLOAD',
    url: validation.preferredUrl,
    pageUrl: pageUrl || validation.preferredUrl,
    mediaUrl: mediaUrl || '',
    cookies,
    userAgent: navigator.userAgent,
    referrer: pageUrl || validation.preferredUrl,
    cookieBrowser,
    preferredQuality: options.preferredQuality || 'best',
    isAudioOnly: false,
    isPlaylist: false,
  };

  const result = await sendPayloadToApp(payload);
  if (!result.ok) {
    await notifyUser('Modern Downloader', result.message);
    return result;
  }

  const siteLabel = Common.getSiteLabel(Common.toUrl(validation.preferredUrl)?.hostname || '');
  await storageSet('local', {
    [STORAGE_KEYS.local.lastSuccessfulSend]: {
      id: `send-${Date.now()}`,
      url: validation.preferredUrl,
      pageUrl: pageUrl || '',
      title: '',
      site: siteLabel,
      sentAt: Date.now(),
    },
  });
  await appendConnectionLog('info', `Sent video URL to app: ${validation.preferredUrl}`);
  await notifyUser('Modern Downloader', `Video queued from ${siteLabel}.`);

  return {
    ok: true,
    url: validation.preferredUrl,
    site: siteLabel,
  };
}

async function sendCurrentTabCookies() {
  if (!stateCache.authenticated || !socket || socket.readyState !== WebSocket.OPEN) {
    return;
  }

  const tab = await getUserFacingActiveTab();
  if (!tab?.url) {
    return;
  }

  const parsed = Common.toUrl(tab.url);
  if (!parsed || !Common.isSupportedHostname(parsed.hostname)) {
    return;
  }

  const cookies = await collectCookiesForRequest(tab.url, tab.url);
  if (!cookies) {
    return;
  }

  socket.send(
    JSON.stringify({
      type: 'HEARTBEAT_COOKIES',
      domain: Common.stripCommonPrefixes(parsed.hostname),
      cookies,
    }),
  );
}

async function getActiveTabContext() {
  const tab = await getUserFacingActiveTab();
  if (!tab?.url) {
    return {
      activeSiteHost: '',
      activeSiteLabel: 'Unsupported',
      pageUrl: '',
      canDownloadPage: false,
      detectedTargets: [],
    };
  }

  const parsed = Common.toUrl(tab.url);
  const hostname = parsed?.hostname || '';
  const baseContext = {
    activeSiteHost: hostname,
    activeSiteLabel: Common.getSiteLabel(hostname),
    pageUrl: tab.url,
    canDownloadPage: Common.isLikelyVideoPageUrl(tab.url),
    detectedTargets: [],
  };

  try {
    const response = await api.tabs.sendMessage(tab.id, { type: 'GET_PAGE_CONTEXT' });
    if (response?.ok) {
      return {
        ...baseContext,
        ...response,
      };
    }
  } catch (_) {}

  return baseContext;
}

async function createContextMenus() {
  if (!api.contextMenus) {
    return;
  }

  if (contextMenuSyncPromise) {
    return contextMenuSyncPromise;
  }

  contextMenuSyncPromise = new Promise((resolve) => {
    api.contextMenus.removeAll(() => {
      api.contextMenus.create(
        {
          id: 'download-detected-video',
          title: 'Download video with Modern Downloader',
          contexts: ['link', 'video'],
        },
        () => {
          const firstError = api.runtime.lastError;
          if (firstError && !firstError.message.includes('duplicate id')) {
            console.warn(firstError.message);
          }

          api.contextMenus.create(
            {
              id: 'download-current-page-video',
              title: 'Download current video page',
              contexts: ['page'],
              enabled: false,
            },
            () => {
              const secondError = api.runtime.lastError;
              if (secondError && !secondError.message.includes('duplicate id')) {
                console.warn(secondError.message);
              }

              contextMenuSyncPromise = null;
              resolve();
            },
          );
        },
      );
    });
  });

  return contextMenuSyncPromise;
}

function refreshPageContextMenu(url) {
  if (!api.contextMenus) {
    return;
  }

  const enabled = Boolean(url && Common.isLikelyVideoPageUrl(url));
  api.contextMenus.update('download-current-page-video', { enabled }, () => {
    const error = api.runtime.lastError;
    if (error && !error.message.includes('Cannot find menu item')) {
      console.warn(error.message);
    }
  });
}

api.runtime.onInstalled.addListener(async () => {
  await ensureDefaults();
  await createContextMenus();
  await updateState(DEFAULT_EXTENSION_STATE);
  connect({ force: true }).catch(() => {});
});

api.runtime.onStartup?.addListener(() => {
  ensureDefaults().then(() => connect({ force: true })).catch(() => {});
});

api.contextMenus?.onClicked.addListener((info, tab) => {
  if (info.menuItemId === 'download-detected-video') {
    handleDownloadRequest({
      mediaUrl: info.linkUrl || info.srcUrl || '',
      pageUrl: tab?.url || info.pageUrl || '',
    }).catch(() => {});
    return;
  }

  if (info.menuItemId === 'download-current-page-video') {
    handleDownloadRequest({
      mediaUrl: '',
      pageUrl: tab?.url || info.pageUrl || '',
    }).catch(() => {});
  }
});

api.tabs.onActivated.addListener(async ({ tabId }) => {
  try {
    const tab = await api.tabs.get(tabId);
    refreshPageContextMenu(tab?.url || '');
  } catch (_) {}
});

api.tabs.onUpdated.addListener((_tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' || changeInfo.url) {
    refreshPageContextMenu(tab?.url || changeInfo.url || '');
  }
});

api.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && (changes.serverPort || changes.apiToken)) {
    connect({ force: true }).catch(() => {});
  }
});

api.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    switch (message?.type) {
      case 'DOWNLOAD_BTN_CLICK':
        return handleDownloadRequest({
          mediaUrl: message.mediaUrl || '',
          pageUrl: message.pageUrl || '',
          options: message.options || {},
        });
      case 'DOWNLOAD_CURRENT_PAGE':
        return handleDownloadRequest({
          mediaUrl: '',
          pageUrl: message.pageUrl || '',
        });
      case 'DOWNLOAD_DETECTED_VIDEO': {
        const context = await getActiveTabContext();
        const firstTarget = Array.isArray(context.detectedTargets) ? context.detectedTargets[0] : null;
        if (!firstTarget) {
          return {
            ok: false,
            code: 'VIDEO_NOT_DETECTED',
            message: 'No detected video is available on the active tab.',
          };
        }

        return handleDownloadRequest({
          mediaUrl: firstTarget.mediaUrl || '',
          pageUrl: firstTarget.pageUrl || context.pageUrl || '',
          options: message.options || {},
        });
      }
      case 'GET_EXTENSION_STATE': {
        const stateResult = await storageGet('local', [
          STORAGE_KEYS.local.extensionState,
          STORAGE_KEYS.local.recentDownloads,
          STORAGE_KEYS.local.lastSuccessfulSend,
          STORAGE_KEYS.local.connectionLog,
          STORAGE_KEYS.local.serverPort,
          STORAGE_KEYS.local.apiToken,
          STORAGE_KEYS.local.autoSendCookies,
          STORAGE_KEYS.local.cookieBrowserPreference,
          STORAGE_KEYS.local.notificationsEnabled,
          STORAGE_KEYS.local.debugMode,
        ]);
        const syncResult = await storageGet('sync', [
          STORAGE_KEYS.sync.siteAccessMode,
          STORAGE_KEYS.sync.siteRules,
        ]);
        return {
          ok: true,
          state: stateResult.extensionState || stateCache,
          recentDownloads: Array.isArray(stateResult.recentDownloads) ? stateResult.recentDownloads : [],
          lastSuccessfulSend: stateResult.lastSuccessfulSend || null,
          connectionLog: Array.isArray(stateResult.connectionLog) ? stateResult.connectionLog : [],
          settings: {
            serverPort: Common.clampPort(stateResult.serverPort, Common.DEFAULT_LOCAL_SETTINGS.serverPort),
            apiToken: stateResult.apiToken || '',
            autoSendCookies: stateResult.autoSendCookies !== false,
            cookieBrowserPreference:
              stateResult.cookieBrowserPreference || Common.DEFAULT_LOCAL_SETTINGS.cookieBrowserPreference,
            notificationsEnabled: stateResult.notificationsEnabled === true,
            debugMode: stateResult.debugMode === true,
            siteAccessMode: syncResult.siteAccessMode || Common.DEFAULT_SYNC_SETTINGS.siteAccessMode,
            siteRules: Common.normalizeRuleList(syncResult.siteRules),
          },
        };
      }
      case 'GET_ACTIVE_TAB_CONTEXT':
        return { ok: true, context: await getActiveTabContext() };
      case 'TEST_CONNECTION':
        return await testConnection();
      case 'CLEAR_RECENT':
        await storageSet('local', {
          [STORAGE_KEYS.local.recentDownloads]: [],
          [STORAGE_KEYS.local.lastSuccessfulSend]: null,
        });
        return { ok: true };
      case 'RESET_SETTINGS':
        await storageSet('local', { ...Common.DEFAULT_LOCAL_SETTINGS });
        await storageSet('sync', { ...Common.DEFAULT_SYNC_SETTINGS });
        await connect({ force: true });
        return { ok: true };
      default:
        return { ok: false, code: 'UNKNOWN_MESSAGE', message: 'Unknown message type.' };
    }
  })()
    .then((response) => sendResponse(response))
    .catch((error) => {
      sendResponse({
        ok: false,
        code: 'RUNTIME_ERROR',
        message: error?.message || 'Unexpected extension error.',
      });
    });

  return true;
});

ensureDefaults()
  .then(() => createContextMenus())
  .then(() => storageGet('local', [STORAGE_KEYS.local.extensionState]))
  .then((result) => {
    stateCache = result.extensionState || { ...DEFAULT_EXTENSION_STATE };
    syncBadgeWithState();
    return connect({ force: true });
  })
  .catch(() => {});
