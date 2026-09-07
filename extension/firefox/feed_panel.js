(function () {
  'use strict';

  var api = typeof MD_API !== 'undefined'
    ? MD_API
    : (typeof browser !== 'undefined' ? browser : chrome);
  var MAX_ITEMS = 10000;
  var feedItems = [];
  var selectedIds = new Set();
  var busy = false;
  var liveCollectionEnabled = true;
  var displayLimit = 100;
  var followAllDisplayed = false;

  var analyzeButton = document.getElementById('analyze-btn');
  var deepScanBtn = document.getElementById('deep-scan-btn');
  var deepScanBanner = document.getElementById('deep-scan-banner');
  var deepScanCounter = document.getElementById('deep-scan-counter');
  var deepScanStopBtn = document.getElementById('deep-scan-stop-btn');
  var jumpActiveBtn = document.getElementById('jump-active-btn');
  var openXButton = document.getElementById('open-x-btn');
  var selectAllButton = document.getElementById('select-all-btn');
  var clearSelectionButton = document.getElementById('clear-selection-btn');
  var downloadSelectedButton = document.getElementById('download-selected-btn');
  var clearFeedBtn = document.getElementById('clear-feed-btn');
  var hookBanner = document.getElementById('hook-banner');
  var hookTabInfo = document.getElementById('hook-tab-info');
  var hookPulseDot = document.getElementById('hook-pulse-dot');
  var hookLabel = document.getElementById('hook-label');
  var hookActionBtn = document.getElementById('hook-action-btn');
  var hookBtnText = document.getElementById('hook-btn-text');
  var creatorProfileBanner = document.getElementById('creator-profile-banner');
  var creatorBannerAvatar = document.getElementById('creator-banner-avatar');
  var creatorBannerHandle = document.getElementById('creator-banner-handle');
  var creatorBannerBadge = document.getElementById('creator-banner-badge');
  var creatorBannerSubtitle = document.getElementById('creator-banner-subtitle');
  var loadCreatorProfileBtn = document.getElementById('load-creator-profile-btn');
  var dlCreatorProfileBtn = document.getElementById('dl-creator-profile-btn');
  var backToPlaylistBtn = document.getElementById('back-to-playlist-btn');
  var previousPlaylistUrl = '';

  var isHooked = false;
  var hookedTabId = null;
  var hookedTabUrl = '';
  var hookedTabTitle = '';
  var selectionCount = document.getElementById('selection-count');
  var scanInfo = document.getElementById('scan-info');
  var feedStatus = document.getElementById('feed-status');
  var feedList = document.getElementById('feed-list');
  var sourcePill = document.getElementById('source-pill');
  var displaySlider = document.getElementById('display-limit-slider');
  var displayLimitValue = document.getElementById('display-limit-value');
  var selectCountInput = document.getElementById('select-count-input');
  var autoClearCheckbox = document.getElementById('auto-clear-checkbox');
  var autoClearEnabled = true;
  if (autoClearCheckbox) {
    autoClearCheckbox.addEventListener('change', function () {
      autoClearEnabled = autoClearCheckbox.checked;
    });
  }

  var hideDownloadedCheckbox = document.getElementById('hide-downloaded-checkbox');
  var hideDownloadedEnabled = true;
  if (hideDownloadedCheckbox) {
    hideDownloadedCheckbox.addEventListener('change', function () {
      hideDownloadedEnabled = hideDownloadedCheckbox.checked;
      renderItems();
      updateSelectionUi();
      updateFeedCountStatus();
    });
  }

  var downloadedTikTokSet = new Set();
  var downloadedTweetSet = new Set();
  var downloadedMediaSet = new Set();

  function extractTikTokIdFromItem(item) {
    if (!item) return null;
    if (item.tikTokId && /^\d{15,25}$/.test(String(item.tikTokId).trim())) {
      return String(item.tikTokId).trim();
    }
    var str = String(item.id || '') + ' ' + String(item.url || '') + ' ' + String(item.pageUrl || '');
    var match = str.match(/(?:video|v)\/(\d{15,25})/);
    if (match) return match[1];
    var ttMatch = str.match(/\btt-(\d{15,25})\b/);
    if (ttMatch) return ttMatch[1];
    var xgMatch = str.match(/xgwrapper-\d+-(\d{15,25})/);
    if (xgMatch) return xgMatch[1];
    return null;
  }

  function isItemDownloaded(item) {
    if (!item) return false;
    if (item.isDownloaded === true) return true;
    var ttId = extractTikTokIdFromItem(item);
    if (ttId && downloadedTikTokSet.has(ttId)) return true;
    if (item.tweetId && downloadedTweetSet.has(String(item.tweetId))) return true;
    if (item.mediaId && downloadedMediaSet.has(String(item.mediaId))) return true;
    return false;
  }

  function applyDownloadedKeys(keys) {
    if (!keys || typeof keys !== 'object') return;
    (keys.tikTokIds || []).forEach(function (id) {
      if (id) downloadedTikTokSet.add(String(id));
    });
    (keys.tweetIds || []).forEach(function (id) {
      if (id) downloadedTweetSet.add(String(id));
    });
    (keys.mediaIds || []).forEach(function (id) {
      if (id) downloadedMediaSet.add(String(id));
    });
  }

  function loadDownloadedKeys() {
    try {
      api.storage.local.get(['downloadedKeys']).then(function (res) {
        var keys = res && res.downloadedKeys;
        if (keys && typeof keys === 'object') {
          applyDownloadedKeys(keys);
          renderItems();
          updateSelectionUi();
          updateFeedCountStatus();
        }
      }).catch(function () {});
    } catch (e) {}
  }

  loadDownloadedKeys();

  if (api.storage && api.storage.onChanged) {
    api.storage.onChanged.addListener(function (changes, areaName) {
      if (areaName === 'local' && changes.downloadedKeys && changes.downloadedKeys.newValue) {
        applyDownloadedKeys(changes.downloadedKeys.newValue);
        renderItems();
        updateSelectionUi();
        updateFeedCountStatus();
      }
    });
  }

  var previewModal = document.getElementById('preview-modal');
  var previewVideoPlayer = document.getElementById('preview-video-player');
  var previewFallbackImg = document.getElementById('preview-fallback-img');
  var previewModalTitle = document.getElementById('preview-modal-title');
  var previewDlBtn = document.getElementById('preview-dl-btn');
  var previewCloseBtn = document.getElementById('preview-close-btn');
  var previewBackdrop = document.getElementById('preview-backdrop');
  var currentPreviewItem = null;

  var creatorModal = document.getElementById('creator-modal');
  var creatorBackdrop = document.getElementById('creator-backdrop');
  var creatorDialogClose = document.getElementById('creator-dialog-close');
  var creatorDialogHandle = document.getElementById('creator-dialog-handle');
  var creatorAppDownloadAction = document.getElementById('creator-app-download-action');
  var creatorScanAction = document.getElementById('creator-scan-action');
  var creatorFilterAction = document.getElementById('creator-filter-action');
  var currentCreatorHandle = '';
  var isDeepScanning = false;
  var deepScanPulseTimer = null;

  var activeSource = 'dom';
  var gobirdFallbackActive = false;
  var gobirdFallbackErrorCode = '';
  var gobirdFallbackError = '';

  var currentViewMode = 'videos'; // 'videos' or 'creators'
  var selectedCreatorHandles = new Set();

  var viewModeBar = document.getElementById('view-mode-bar');
  var viewModeVideosBtn = document.getElementById('view-mode-videos-btn');
  var viewModeCreatorsBtn = document.getElementById('view-mode-creators-btn');
  var viewModeVideosCount = document.getElementById('view-mode-videos-count');
  var viewModeCreatorsCount = document.getElementById('view-mode-creators-count');
  var recoverAccountsBtn = document.getElementById('recover-accounts-btn');
  var recoverAccountsModal = document.getElementById('recover-accounts-modal');
  var recoverAccountsBackdrop = document.getElementById('recover-accounts-backdrop');
  var recoverAccountsClose = document.getElementById('recover-accounts-close');
  var recoverAccountsTitle = document.getElementById('recover-accounts-title');
  var recoverSendAppAction = document.getElementById('recover-send-app-action');
  var recoverSwitchViewAction = document.getElementById('recover-switch-view-action');
  var recoverCopyUrlsAction = document.getElementById('recover-copy-urls-action');
  var recoverExportTxtAction = document.getElementById('recover-export-txt-action');
  var copyCreatorsBtn = document.getElementById('copy-creators-btn');
  var exportCreatorsBtn = document.getElementById('export-creators-btn');

  function t(key, fallback) {
    try {
      if (api.i18n && api.i18n.getMessage) {
        var message = api.i18n.getMessage(key);
        if (message) return message;
      }
    } catch (e) {
      /* Use the built-in fallback when localization is unavailable. */
    }
    return fallback;
  }

  function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(function (element) {
      var key = element.getAttribute('data-i18n');
      var message = t(key, element.textContent);
      if (message) element.textContent = message;
    });
  }

  function isSafeHttpUrl(value) {
    try {
      var url = new URL(value);
      return (url.protocol === 'http:' || url.protocol === 'https:') &&
        !!url.hostname;
    } catch (e) {
      return false;
    }
  }

  function isSafeThumbnailUrl(value) {
    if (!value || typeof value !== 'string') return false;
    if (value.indexOf('data:image/') === 0) return true;
    return isSafeHttpUrl(value);
  }

  function isTrackingParameter(name) {
    var normalized = String(name || '').toLowerCase();
    return normalized.indexOf('utm_') === 0 ||
      [
        'fbclid',
        'gclid',
        'dclid',
        'msclkid',
        'mc_cid',
        'mc_eid',
        '_hsenc',
        '_hsmi',
        'igshid',
        'ref',
        'ref_src',
        'ref_url',
        'feature',
        's',
      ].indexOf(normalized) !== -1;
  }

  function isXHost(hostname) {
    var normalized = String(hostname || '').toLowerCase();
    return normalized === 'x.com' ||
      normalized.endsWith('.x.com') ||
      normalized === 'twitter.com' ||
      normalized.endsWith('.twitter.com');
  }

  function isXCdnHost(hostname) {
    var normalized = String(hostname || '').toLowerCase();
    return normalized === 'twimg.com' ||
      normalized.endsWith('.twimg.com') ||
      normalized === 'pscp.tv' ||
      normalized.endsWith('.pscp.tv');
  }

  function xStatusPermalink(value) {
    if (!isSafeHttpUrl(value)) return null;
    try {
      var url = new URL(value);
      if (!isXHost(url.hostname)) return null;
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

  function downloadUrlForFeedItem(item) {
    if (!item) return null;
    if (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl) {
      var canonical = MDUrl.canonicalMediaUrl(item.url) || MDUrl.canonicalMediaUrl(item.pageUrl);
      if (canonical) return canonical;
    }
    var fromItem = xStatusPermalink(item && item.url);
    if (fromItem) return fromItem;
    var fromPage = xStatusPermalink(item && item.pageUrl);
    if (fromPage) return fromPage;
    if (isSafeHttpUrl(item.url)) return item.url;
    if (isSafeHttpUrl(item.pageUrl)) return item.pageUrl;
    return null;
  }

  function normalizedMediaUrl(value) {
    try {
      var url = new URL(value);
      if (
        (url.protocol !== 'http:' && url.protocol !== 'https:') ||
        !url.hostname
      ) {
        return null;
      }

      if (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl) {
        var canon = MDUrl.canonicalMediaUrl(url.href);
        if (canon) return canon;
      }

      var parameters = [];
      url.searchParams.forEach(function (parameterValue, parameterName) {
        if (!isTrackingParameter(parameterName)) {
          parameters.push([parameterName, parameterValue]);
        }
      });
      parameters.sort(function (first, second) {
        var firstKey = first[0] + '\u0000' + first[1];
        var secondKey = second[0] + '\u0000' + second[1];
        return firstKey.localeCompare(secondKey);
      });

      url.protocol = url.protocol.toLowerCase();
      url.hostname = url.hostname.toLowerCase();
      url.hash = '';
      url.search = '';
      parameters.forEach(function (parameter) {
        url.searchParams.append(parameter[0], parameter[1]);
      });
      return url.toString();
    } catch (e) {
      return null;
    }
  }

  function sendRuntimeMessage(message) {
    return new Promise(function (resolve, reject) {
      try {
        if (
          typeof browser !== 'undefined' &&
          browser.runtime &&
          browser.runtime.sendMessage
        ) {
          var promise = browser.runtime.sendMessage(message);
          if (promise && typeof promise.then === 'function') {
            promise.then(resolve).catch(reject);
          } else {
            resolve(promise);
          }
          return;
        }

        api.runtime.sendMessage(message, function (response) {
          if (api.runtime.lastError) {
            reject(new Error(api.runtime.lastError.message || 'message_failed'));
            return;
          }
          resolve(response);
        });
      } catch (error) {
        reject(error);
      }
    });
  }

  function replaceCount(template, count) {
    return String(template).replace(/\{count\}/g, String(count));
  }

  function setPanelDescription(source) {
    var description = document.querySelector('[data-i18n="xFeedDescription"]');
    if (!description) return;
    if (source === 'gobird') {
      description.textContent = t(
        'xFeedGobirdDescription',
        'gobird paginates the home feed, and new videos from scrolling stay in this list.',
      );
      return;
    }
    description.textContent = t(
      'xFeedDescription',
      'Scroll X to collect videos; new posts stay in this list.',
    );
  }

  function setSource(source, options) {
    var opts = options || {};
    activeSource = source === 'gobird' ? 'gobird' : 'dom';
    liveCollectionEnabled = true;
    setPanelDescription(activeSource);
    if (!sourcePill) return;
    var isFallback = activeSource === 'dom' && !!opts.fallbackFrom;
    gobirdFallbackActive = isFallback;
    gobirdFallbackErrorCode = isFallback ? String(opts.errorCode || '') : '';
    gobirdFallbackError = isFallback ? String(opts.error || '') : '';
    sourcePill.className = 'source-pill' +
      (activeSource === 'gobird'
        ? ' source-gobird'
        : (isFallback ? ' source-fallback' : ' source-local'));
    if (activeSource === 'gobird') {
      sourcePill.textContent = t('xFeedGobirdSource', 'gobird experimental');
    } else if (isFallback) {
      sourcePill.textContent = t(
        'xFeedFallbackSource',
        'Local fallback (gobird failed)',
      );
    } else {
      sourcePill.textContent = t('xFeedLocalSource', 'For You — local');
    }
  }

  function gobirdFailureHint(errorCode, errorText) {
    var code = String(errorCode || '');
    if (code === 'missingBinary') {
      return t(
        'xFeedGobirdMissingBinary',
        'gobird binary not found in the app. Re-run prepare_gobird or use a release build.',
      );
    }
    if (code === 'auth') {
      return t(
        'xFeedGobirdAuthFailed',
        'gobird did not receive X session cookies. Stay logged in on x.com with Auto-Cookies enabled, then click Analyze.',
      );
    }
    if (code === 'rateLimit') {
      return t('xFeedGobirdRateLimited', 'gobird was rate-limited by X. Try again later.');
    }
    if (code === 'disabled') {
      return t('xFeedGobirdDisabled', 'gobird is disabled in app settings.');
    }
    if (code === 'app_offline' || code === 'request_timeout') {
      return t(
        'xFeedGobirdAppOffline',
        'Modern Downloader is offline or did not answer. Start the app and retry.',
      );
    }
    var detail = String(errorText || code || '').trim();
    if (!detail) {
      return t('xFeedGobirdFailed', 'gobird failed. Showing the local DOM feed instead.');
    }
    return t('xFeedGobirdFailed', 'gobird failed. Showing the local DOM feed instead.') +
      ' (' + detail.slice(0, 160) + ')';
  }

  function setStatus(message, state) {
    feedStatus.className = 'feed-status' + (state ? ' ' + state : '');
    feedStatus.textContent = message;
  }

  function setBusy(value) {
    busy = value;
    analyzeButton.disabled = value;
    openXButton.disabled = value;
    updateSelectionUi();
  }

  function formatDuration(seconds) {
    if (!Number.isFinite(seconds) || seconds <= 0) {
      return null;
    }
    var totalSeconds = Math.floor(seconds);
    var minutes = Math.floor(totalSeconds / 60);
    var remainingSeconds = String(totalSeconds % 60).padStart(2, '0');
    return minutes + ':' + remainingSeconds;
  }

  function formatResolution(item) {
    if (
      !Number.isFinite(item.width) ||
      !Number.isFinite(item.height) ||
      item.width <= 0 ||
      item.height <= 0
    ) {
      return null;
    }
    return item.width + '×' + item.height;
  }

  function formatSize(item) {
    if (!Number.isFinite(item.sizeBytes) || item.sizeBytes <= 0) {
      return null;
    }
    var units = ['B', 'KB', 'MB', 'GB'];
    var size = item.sizeBytes;
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return size.toFixed(unitIndex === 0 ? 0 : 1) + ' ' + units[unitIndex];
  }

  function openVideoPreview(item) {
    if (!item) return;
    currentPreviewItem = item;
    if (!previewModal) return;
    previewModal.hidden = false;
    if (previewModalTitle) {
      previewModalTitle.textContent = item.title || item.author || 'Aperçu vidéo';
    }

    var videoSource = item.videoSrc || item.url;
    var isDirectStream = videoSource && (
      videoSource.indexOf('blob:') === 0 ||
      videoSource.indexOf('.mp4') !== -1 ||
      videoSource.indexOf('tiktokcdn') !== -1 ||
      (videoSource.indexOf('http') === 0 && videoSource.indexOf('tiktok.com/@') === -1)
    );

    if (previewVideoPlayer && isDirectStream) {
      previewVideoPlayer.style.display = 'block';
      if (previewFallbackImg) previewFallbackImg.style.display = 'none';
      previewVideoPlayer.src = videoSource;
      previewVideoPlayer.play().catch(function () {
        fallbackToImagePreview(item);
      });
    } else {
      fallbackToImagePreview(item);
    }
  }

  function fallbackToImagePreview(item) {
    if (previewVideoPlayer) {
      previewVideoPlayer.pause();
      previewVideoPlayer.src = '';
      previewVideoPlayer.style.display = 'none';
    }
    if (previewFallbackImg) {
      if (item.thumbnailUrl) {
        previewFallbackImg.src = item.thumbnailUrl;
        previewFallbackImg.style.display = 'block';
      } else {
        previewFallbackImg.style.display = 'none';
      }
    }
  }

  function closeVideoPreview() {
    if (!previewModal) return;
    previewModal.hidden = true;
    if (previewVideoPlayer) {
      previewVideoPlayer.pause();
      previewVideoPlayer.removeAttribute('src');
      previewVideoPlayer.load();
    }
    currentPreviewItem = null;
  }

  if (previewCloseBtn) previewCloseBtn.addEventListener('click', closeVideoPreview);
  if (previewBackdrop) previewBackdrop.addEventListener('click', closeVideoPreview);
  if (previewDlBtn) {
    previewDlBtn.addEventListener('click', function () {
      if (currentPreviewItem) {
        var card = feedList.querySelector('.feed-card[data-feed-id="' + currentPreviewItem.id + '"]');
        var btn = card ? card.querySelector('.card-single-dl-btn') : null;
        downloadSingleItem(currentPreviewItem, card, btn);
        closeVideoPreview();
      }
    });
  }

  function clearFeed() {
    activeCreatorFilter = 'all';
    feedItems = [];
    selectedIds.clear();
    sniffedStreams = [];
    updateSniffedCount();
    renderItems();
    updateFeedCountStatus();
    getTargetTab(function (tab) {
      if (tab && tab.id && api.tabs && api.tabs.sendMessage) {
        api.tabs.sendMessage(tab.id, { type: 'MD_CLEAR_CACHE' }, function () {});
      }
    });
  }
  if (clearFeedBtn) {
    clearFeedBtn.addEventListener('click', clearFeed);
  }

  function jumpToActiveVideo() {
    var activeCard = feedList.querySelector('.feed-card[data-is-active="true"]');
    if (!activeCard) {
      var activeItem = feedItems.find(function (it) { return it.isActive; });
      if (activeItem) {
        activeCard = feedList.querySelector('.feed-card[data-feed-id="' + activeItem.id + '"]');
      }
    }
    if (activeCard) {
      activeCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
      activeCard.classList.remove('card-highlight-pulse');
      void activeCard.offsetWidth;
      activeCard.classList.add('card-highlight-pulse');
      setStatus('Vidéo en cours ciblée 🎯', 'success');
    } else {
      setStatus('Aucune vidéo active en cours de lecture détectée.', '');
    }
  }
  if (jumpActiveBtn) {
    jumpActiveBtn.addEventListener('click', jumpToActiveVideo);
  }

  function startDeepScan() {
    if (isDeepScanning) return;
    isDeepScanning = true;
    if (displayLimit < 1000) {
      displayLimit = 1000;
      if (displaySlider) displaySlider.value = 1000;
      if (displayLimitValue) displayLimitValue.textContent = '1000';
      if (typeof syncPresetPills === 'function') syncPresetPills();
    }
    if (deepScanBanner) {
      deepScanBanner.classList.remove('hidden');
      deepScanBanner.removeAttribute('hidden');
      deepScanBanner.style.setProperty('display', 'flex', 'important');
    }
    if (deepScanBtn) deepScanBtn.disabled = true;
    if (deepScanCounter) deepScanCounter.textContent = 'Défilement intelligent en cours…';
    getTargetTab(function (tab) {
      if (tab && tab.id && api.tabs && api.tabs.sendMessage) {
        api.tabs.sendMessage(tab.id, {
          type: 'MD_START_DEEP_SCAN',
          maxTarget: 1000,
        }, function () {
          if (api.runtime && api.runtime.lastError) {
            setStatus(
              'Scan impossible sur cet onglet. Rechargez la page TikTok (Pour Toi) puis relancez Tout charger.',
              'error',
            );
            stopDeepScan();
          }
        });
      } else {
        setStatus('Aucun onglet TikTok cible. Ouvrez Pour Toi puis réessayez.', 'error');
        stopDeepScan();
      }
    });

    if (deepScanPulseTimer) clearInterval(deepScanPulseTimer);
    deepScanPulseTimer = setInterval(function () {
      if (!isDeepScanning) {
        clearInterval(deepScanPulseTimer);
        deepScanPulseTimer = null;
        return;
      }
      getTargetTab(function (tab) {
        if (tab && tab.id && api.tabs && api.tabs.sendMessage) {
          api.tabs.sendMessage(tab.id, {
            type: 'MD_DEEP_SCAN_PULSE',
            maxTarget: displayLimit,
          }, function () {});
        }
      });
    }, 4500);
  }

  function stopDeepScan() {
    isDeepScanning = false;
    if (deepScanPulseTimer) {
      clearInterval(deepScanPulseTimer);
      deepScanPulseTimer = null;
    }
    if (deepScanBanner) {
      deepScanBanner.classList.add('hidden');
      deepScanBanner.setAttribute('hidden', '');
      deepScanBanner.style.setProperty('display', 'none', 'important');
    }
    if (deepScanBtn) deepScanBtn.disabled = false;
    getTargetTab(function (tab) {
      if (tab && tab.id && api.tabs && api.tabs.sendMessage) {
        api.tabs.sendMessage(tab.id, { type: 'MD_STOP_DEEP_SCAN' }, function () {});
      }
    });
  }
  if (deepScanBtn) deepScanBtn.addEventListener('click', startDeepScan);
  if (deepScanStopBtn) deepScanStopBtn.addEventListener('click', stopDeepScan);

  function openCreatorModal(authorHandle) {
    if (!authorHandle || !creatorModal) return;
    var clean = String(authorHandle).replace(/^@/, '').trim();
    if (!clean || clean.toLowerCase() === 'utilisateur' || clean.toLowerCase() === 'créateur tiktok') return;
    currentCreatorHandle = clean;
    if (creatorDialogHandle) {
      creatorDialogHandle.textContent = '@' + currentCreatorHandle;
    }
    creatorModal.classList.remove('hidden');
    creatorModal.removeAttribute('hidden');
    creatorModal.style.setProperty('display', 'flex', 'important');
  }

  function closeCreatorModal() {
    if (!creatorModal) return;
    creatorModal.classList.add('hidden');
    creatorModal.setAttribute('hidden', '');
    creatorModal.style.setProperty('display', 'none', 'important');
    currentCreatorHandle = '';
  }
  if (creatorDialogClose) creatorDialogClose.addEventListener('click', closeCreatorModal);
  if (creatorBackdrop) creatorBackdrop.addEventListener('click', closeCreatorModal);

  if (creatorAppDownloadAction) {
    creatorAppDownloadAction.addEventListener('click', function () {
      if (!currentCreatorHandle) return;
      var profileUrl = 'https://www.tiktok.com/@' + currentCreatorHandle;
      sendRuntimeMessage({
        type: 'DOWNLOAD_BTN_CLICK',
        url: profileUrl,
        pageUrl: profileUrl,
        options: { noWatermark: true }
      }).then(function (res) {
        if (res && res.ok) {
          setStatus('Profil @' + currentCreatorHandle + ' envoyé à l\'App pour téléchargement complet !', 'success');
        } else {
          setStatus('Échec d\'envoi à l\'App', 'error');
        }
      }).catch(function () {
        setStatus('Échec d\'envoi à l\'App', 'error');
      });
      closeCreatorModal();
    });
  }

  if (creatorScanAction) {
    creatorScanAction.addEventListener('click', function () {
      if (!currentCreatorHandle) return;
      var profileUrl = 'https://www.tiktok.com/@' + currentCreatorHandle;
      if (api.tabs && api.tabs.update) {
        if (isHooked && hookedTabId) {
          api.tabs.update(hookedTabId, { url: profileUrl });
        } else {
          api.tabs.update({ url: profileUrl });
        }
      } else if (api.tabs && api.tabs.create) {
        api.tabs.create({ url: profileUrl });
      }
      clearFeed();
      closeCreatorModal();
      setStatus('Ouverture du profil @' + currentCreatorHandle + ' et scan en cours…', 'success');
    });
  }

  if (creatorFilterAction) {
    creatorFilterAction.addEventListener('click', function () {
      if (!currentCreatorHandle) return;
      selectCreatorFilter(currentCreatorHandle);
      closeCreatorModal();
    });
  }

  function createThumbnail(item) {
    var container = document.createElement('div');
    container.className = 'thumbnail-container';

    var isVertical = item.platform === 'tiktok' ||
      (Number.isFinite(item.height) && Number.isFinite(item.width) && item.height > item.width * 1.1);
    if (isVertical) container.classList.add('vertical-thumb');

    if (isSafeThumbnailUrl(item.thumbnailUrl)) {
      var image = document.createElement('img');
      image.className = 'thumbnail';
      image.loading = 'lazy';
      image.alt = item.title || t('xFeedVideoAlt', 'Miniature');
      image.src = item.thumbnailUrl;
      image.addEventListener('error', function () {
        image.style.display = 'none';
        if (!container.querySelector('.thumbnail-placeholder')) {
          var placeholder = document.createElement('div');
          placeholder.className = 'thumbnail thumbnail-placeholder';
          placeholder.textContent = 'Aperçu';
          container.insertBefore(placeholder, container.firstChild);
        }
      });
      container.appendChild(image);
    } else {
      var emptyThumbnail = document.createElement('div');
      emptyThumbnail.className = 'thumbnail thumbnail-placeholder';
      emptyThumbnail.textContent = 'Aperçu';
      container.appendChild(emptyThumbnail);
    }

    var playOverlay = document.createElement('div');
    playOverlay.className = 'thumbnail-play-overlay';
    playOverlay.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg>';
    container.appendChild(playOverlay);

    container.title = 'Aperçu vidéo (cliquer pour lire)';
    container.addEventListener('click', function (e) {
      e.stopPropagation();
      openVideoPreview(item);
    });

    return container;
  }

  function normalizeItems(items) {
    if (!Array.isArray(items)) return [];
    var seen = {};
    var normalized = [];
    items.forEach(function (item) {
      if (!item || typeof item !== 'object') return;
      var id = String(item.id || '');
      var url = String(item.url || '');
      if (!id || seen[id] || !isSafeHttpUrl(url)) return;
      seen[id] = true;
      normalized.push({
        id: id,
        url: url,
        pageUrl: isSafeHttpUrl(item.pageUrl) ? item.pageUrl : url,
        title: String(item.title || t('xFeedVideo', 'Vidéo')),
        author: String(item.author || t('xFeedAuthorUnknown', 'Créateur')),
        platform: item.platform || (typeof MDUrl !== 'undefined' && MDUrl.detectPlatform ? MDUrl.detectPlatform(url) : 'generic'),
        music: item.music ? String(item.music) : null,
        avatarUrl: isSafeHttpUrl(item.avatarUrl) ? item.avatarUrl : null,
        thumbnailUrl: isSafeThumbnailUrl(item.thumbnailUrl)
          ? item.thumbnailUrl
          : null,
        videoSrc: (isSafeHttpUrl(item.videoSrc) || (typeof item.videoSrc === 'string' && item.videoSrc.indexOf('blob:') === 0))
          ? item.videoSrc
          : null,
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
    return normalized;
  }

  function mergeItems(items) {
    var normalized = normalizeItems(items);
    if (normalized.length === 0) return 0;

    // Slider = 1: Single active TikTok mode (track current playing video)
    if (displayLimit === 1) {
      var activeItem = normalized.find(function (it) { return it.isActive; }) || normalized[0];
      if (activeItem) {
        var currentFirst = feedItems.length > 0 ? feedItems[0] : null;
        if (!currentFirst || currentFirst.id !== activeItem.id) {
          feedItems = [activeItem];
          selectedIds.clear();
          return 1;
        } else {
          feedItems[0] = activeItem;
          return 0;
        }
      }
      return 0;
    }

    var indexes = {};
    feedItems.forEach(function (item, index) {
      indexes[item.id] = index;
    });

    var added = 0;
    normalized.forEach(function (item) {
      var existingIndex = indexes[item.id];
      if (existingIndex === undefined) {
        if (feedItems.length >= displayLimit) return;
        indexes[item.id] = feedItems.length;
        feedItems.push(item);
        added++;
        return;
      }

      var existing = feedItems[existingIndex];
      var preferIncoming = item.source === 'gobird' &&
        existing.source !== 'gobird';
      feedItems[existingIndex] = {
        id: existing.id,
        url: preferIncoming ? item.url : existing.url,
        pageUrl: preferIncoming ? item.pageUrl : existing.pageUrl,
        title: existing.title || item.title,
        author: existing.author || item.author,
        platform: existing.platform || item.platform,
        music: existing.music || item.music,
        avatarUrl: existing.avatarUrl || item.avatarUrl,
        thumbnailUrl: item.thumbnailUrl || existing.thumbnailUrl,
        videoSrc: item.videoSrc || existing.videoSrc,
        isActive: item.isActive !== undefined ? item.isActive : existing.isActive,
        durationSeconds: existing.durationSeconds || item.durationSeconds,
        width: existing.width || item.width,
        height: existing.height || item.height,
        sizeBytes: existing.sizeBytes || item.sizeBytes,
        source: preferIncoming ? item.source : existing.source,
      };
    });
    return added;
  }

  var activePlatformFilter = 'all';
  var activeCreatorFilter = 'all';
  var activeTabUrl = '';
  var sniffedStreams = [];

  function getTargetTab(callback) {
    if (isHooked && hookedTabId !== null) {
      if (api.tabs && api.tabs.get) {
        api.tabs.get(hookedTabId, function (tab) {
          if (api.runtime && api.runtime.lastError) {
            releaseHook('Onglet verrouillé fermé. Retour au suivi direct.');
            fallbackToActiveTab(callback);
            return;
          }
          if (!tab) {
            releaseHook('Onglet verrouillé introuvable. Retour au suivi direct.');
            fallbackToActiveTab(callback);
            return;
          }
          callback(tab);
        });
        return;
      }
    }
    fallbackToActiveTab(callback);
  }

  function fallbackToActiveTab(callback) {
    if (api.tabs && api.tabs.query) {
      api.tabs.query({ active: true, currentWindow: true }, function (tabs) {
        callback((tabs && tabs[0]) || null);
      });
    } else {
      callback(null);
    }
  }

  function updateHookUi(targetTab) {
    if (!hookBanner || !hookActionBtn) return;
    if (isHooked) {
      hookBanner.classList.add('is-hooked');
      var domain = '';
      try {
        if (hookedTabUrl) domain = new URL(hookedTabUrl).hostname.replace(/^www\./, '');
      } catch (e) {}
      var displayLabel = 'Verrouillé : ' + (domain || (targetTab && targetTab.title) || 'Page cible');
      if (hookLabel) hookLabel.textContent = displayLabel;
      if (hookTabInfo) hookTabInfo.title = 'L\'extension est verrouillée sur cette page. Elle continue à capturer et défiler même si vous changez d\'onglet ou de fenêtre.';
      if (hookBtnText) hookBtnText.textContent = 'Détacher';
      hookActionBtn.classList.add('active');
      hookActionBtn.title = 'Détacher l\'extension pour réactiver le suivi dynamique de l\'onglet actif';
    } else {
      hookBanner.classList.remove('is-hooked');
      var activeDomain = '';
      try {
        if (targetTab && targetTab.url) activeDomain = new URL(targetTab.url).hostname.replace(/^www\./, '');
      } catch (e) {}
      if (hookLabel) hookLabel.textContent = 'Suivi : ' + (activeDomain ? activeDomain : 'Onglet actif');
      if (hookTabInfo) hookTabInfo.title = 'Cliquez pour verrouiller l\'extension sur cet onglet';
      if (hookBtnText) hookBtnText.textContent = 'Verrouiller';
      hookActionBtn.classList.remove('active');
      hookActionBtn.title = 'Verrouiller sur cet onglet pour continuer les actions en arrière-plan';
    }
  }

  function toggleHook() {
    if (isHooked) {
      releaseHook('Verrouillage relâché. Suivi dynamique actif.');
    } else {
      fallbackToActiveTab(function (tab) {
        if (!tab || !tab.id) {
          setStatus('Impossible de verrouiller : aucun onglet actif détecté.', 'error');
          return;
        }
        isHooked = true;
        hookedTabId = tab.id;
        hookedTabUrl = tab.url || '';
        hookedTabTitle = tab.title || '';
        activeTabUrl = hookedTabUrl;
        updateHookUi(tab);
        syncPlaylistBanner();
        fetchSniffedStreams();
        setStatus('Extension verrouillée sur cet onglet ! Les actions continuent en arrière-plan.', 'success');
      });
    }
  }

  function releaseHook(statusHint) {
    isHooked = false;
    hookedTabId = null;
    hookedTabUrl = '';
    hookedTabTitle = '';
    fallbackToActiveTab(function (tab) {
      if (tab && tab.url) {
        activeTabUrl = tab.url;
        syncPlaylistBanner();
        fetchSniffedStreams();
      }
      updateHookUi(tab);
      if (statusHint) {
        setStatus(statusHint, '');
      }
    });
  }

  if (hookActionBtn) {
    hookActionBtn.addEventListener('click', toggleHook);
  }
  if (hookTabInfo) {
    hookTabInfo.addEventListener('click', toggleHook);
  }

  if (api.tabs && api.tabs.onRemoved) {
    api.tabs.onRemoved.addListener(function (closedTabId) {
      if (isHooked && closedTabId === hookedTabId) {
        releaseHook('Onglet verrouillé fermé. Retour au suivi direct.');
      }
    });
  }

  if (api.tabs && api.tabs.onActivated) {
    api.tabs.onActivated.addListener(function () {
      if (!isHooked) {
        updateActiveTabUrl();
      }
    });
  }

  function fetchSniffedStreams() {
    try {
      getTargetTab(function (tab) {
        if (tab && tab.id) {
          api.runtime.sendMessage({
            type: 'GET_SNIFFED_STREAMS',
            tabId: tab.id,
          }, function (res) {
            if (res && res.ok && Array.isArray(res.streams)) {
              sniffedStreams = res.streams;
              updateSniffedCount();
              if (activePlatformFilter === 'sniffed') {
                renderItems();
              }
            }
          });
        }
      });
    } catch (e) {}
  }

  function updateSniffedCount() {
    var el = document.getElementById('sniffed-count');
    if (el) el.textContent = String(sniffedStreams.length);
  }

  function updateActiveTabUrl() {
    try {
      getTargetTab(function (tab) {
        if (tab && tab.url) {
          activeTabUrl = tab.url;
          syncPlaylistBanner();
          fetchSniffedStreams();
          updateHookUi(tab);
        }
      });
    } catch (e) {}
  }
  updateActiveTabUrl();

  function syncPlaylistBanner() {
    var banner = document.getElementById('playlist-banner');
    var titleEl = document.getElementById('playlist-banner-title');
    if (!banner) return;

    var isTiktokPlaylist = activeTabUrl && (
      activeTabUrl.indexOf('tiktok.com') !== -1 && (
        activeTabUrl.indexOf('/collection/') !== -1 ||
        activeTabUrl.indexOf('/playlist/') !== -1 ||
        activeTabUrl.indexOf('/tag/') !== -1
      )
    );

    if (!isTiktokPlaylist) {
      banner.classList.add('hidden');
      banner.hidden = true;
      banner.style.setProperty('display', 'none', 'important');
      return;
    }

    banner.classList.remove('hidden');
    banner.hidden = false;
    banner.style.removeProperty('display');

    if (titleEl) {
      if (activeTabUrl.indexOf('/collection/') !== -1) {
        var match = activeTabUrl.match(/\/collection\/([^/?#]+)/);
        titleEl.textContent = 'Collection TikTok ' + (match ? decodeURIComponent(match[1]).replace(/-\d+$/, '').replace(/-/g, ' ') : '');
      } else if (activeTabUrl.indexOf('/playlist/') !== -1) {
        var matchP = activeTabUrl.match(/\/playlist\/([^/?#]+)/);
        titleEl.textContent = 'Playlist TikTok ' + (matchP ? decodeURIComponent(matchP[1]).replace(/-\d+$/, '').replace(/-/g, ' ') : '');
      } else {
        titleEl.textContent = 'Collection / Playlist TikTok';
      }
    }
  }

  var downloadPlaylistBtn = document.getElementById('download-playlist-btn');
  if (downloadPlaylistBtn) {
    downloadPlaylistBtn.addEventListener('click', function () {
      if (!activeTabUrl || busy) return;
      downloadPlaylistBtn.disabled = true;
      downloadPlaylistBtn.textContent = 'Envoi…';
      sendRuntimeMessage({
        type: 'DOWNLOAD_BTN_CLICK',
        url: activeTabUrl,
        pageUrl: activeTabUrl,
        options: { noWatermark: true }
      }).then(function (res) {
        downloadPlaylistBtn.disabled = false;
        downloadPlaylistBtn.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg><span>Tout télécharger (App)</span>';
        if (res && res.ok) {
          setStatus('Collection complète envoyée à l\'App ! Le téléchargement des 600+ vidéos démarre…', 'success');
        } else {
          setStatus('Échec d\'envoi de la playlist à l\'App', 'error');
        }
      }).catch(function () {
        downloadPlaylistBtn.disabled = false;
        downloadPlaylistBtn.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg><span>Tout télécharger (App)</span>';
        setStatus('Échec d\'envoi de la playlist à l\'App', 'error');
      });
    });
  }

  function itemPlatform(item) {
    if (!item) return 'web';
    if (item.platform && item.platform !== 'generic') return item.platform;
    if (typeof MDUrl !== 'undefined' && MDUrl.detectPlatform) {
      var detected = MDUrl.detectPlatform(item.url || item.pageUrl);
      if (detected && detected !== 'generic') return detected;
    }
    try {
      var u = new URL(item.pageUrl || item.url);
      return u.hostname.replace(/^www\./, '');
    } catch (e) {
      return 'web';
    }
  }

  function filteredItems() {
    if (activePlatformFilter === 'sniffed') {
      return sniffedStreams.map(function (s) {
        return {
          id: s.id,
          url: s.url,
          pageUrl: activeTabUrl || s.url,
          title: (s.format || 'Vidéo') + ' (' + (s.hostname || 'Flux direct') + ')',
          author: s.hostname || 'Réseau',
          platform: 'network',
          thumbnailUrl: null,
          durationSeconds: null,
          width: null,
          height: null,
          sizeBytes: s.contentLength,
          source: 'sniffer',
          sourceLabel: 'RÉSEAU ' + (s.ext ? s.ext.toUpperCase() : ''),
        };
      });
    }
    var items = feedItems;
    if (activePlatformFilter === 'current') {
      if (!activeTabUrl) return feedItems;
      try {
        var currentHost = new URL(activeTabUrl).hostname.replace(/^www\./, '');
        items = feedItems.filter(function (item) {
          try {
            var itemHost = new URL(item.pageUrl || item.url).hostname.replace(/^www\./, '');
            return itemHost === currentHost;
          } catch (e) {
            return false;
          }
        });
      } catch (e) {
        items = feedItems;
      }
    } else if (activePlatformFilter !== 'all') {
      items = feedItems.filter(function (item) {
        return itemPlatform(item) === activePlatformFilter;
      });
    }

    if (activeCreatorFilter && activeCreatorFilter !== 'all') {
      var targetHandle = activeCreatorFilter.toLowerCase().replace(/^@/, '').trim();
      items = items.filter(function (item) {
        var a = String(item.author || '').toLowerCase().replace(/^@/, '').trim();
        return a === targetHandle;
      });
    }

    if (hideDownloadedEnabled) {
      items = items.filter(function (item) {
        return !isItemDownloaded(item);
      });
    }

    return items;
  }

  function syncPlatformFilterPills() {
    var container = document.getElementById('platform-filters');
    if (!container) return;
    var platforms = {};
    feedItems.forEach(function (item) {
      var p = itemPlatform(item);
      if (p) platforms[p] = (platforms[p] || 0) + 1;
    });

    var tiktokCountEl = document.getElementById('tiktok-count');
    if (tiktokCountEl) {
      tiktokCountEl.textContent = String(platforms['tiktok'] || 0);
    }

    var staticBtns = Array.prototype.slice.call(
      container.querySelectorAll('[data-filter="all"], [data-filter="current"], [data-filter="tiktok"], [data-filter="sniffed"]'),
    );
    container.innerHTML = '';
    staticBtns.forEach(function (b) {
      b.classList.toggle('active', b.dataset.filter === activePlatformFilter);
      container.appendChild(b);
    });

    updateSniffedCount();

    Object.keys(platforms).sort().forEach(function (p) {
      if (p === 'tiktok' || p === 'all' || p === 'current' || p === 'sniffed') return;
      var pill = document.createElement('button');
      pill.type = 'button';
      pill.className = 'platform-pill' + (activePlatformFilter === p ? ' active' : '');
      pill.dataset.filter = p;
      pill.textContent = p.toUpperCase() + ' (' + platforms[p] + ')';
      pill.addEventListener('click', function () {
        selectPlatformFilter(p);
      });
      container.appendChild(pill);
    });
  }

  function selectPlatformFilter(filter) {
    activePlatformFilter = filter;
    var container = document.getElementById('platform-filters');
    if (container) {
      container.querySelectorAll('.platform-pill').forEach(function (pill) {
        pill.classList.toggle('active', pill.dataset.filter === filter);
      });
    }
    renderItems();
    updateFeedCountStatus();
  }

  function selectCreatorFilter(filter) {
    var clean = (filter === 'all' || !filter) ? 'all' : String(filter).replace(/^@/, '').trim();
    if (activeCreatorFilter.toLowerCase() === clean.toLowerCase()) {
      activeCreatorFilter = 'all';
    } else {
      activeCreatorFilter = clean;
    }
    selectedIds.clear();
    syncCreatorProfileBanner();
    renderItems();
    updateFeedCountStatus();
  }

  function syncCreatorProfileBanner() {
    if (!creatorProfileBanner) return;
    if (activeCreatorFilter === 'all' || !activeCreatorFilter) {
      creatorProfileBanner.classList.add('hidden');
      creatorProfileBanner.hidden = true;
      creatorProfileBanner.style.setProperty('display', 'none', 'important');
      return;
    }

    var cleanHandle = String(activeCreatorFilter).replace(/^@/, '').trim();
    var matchingItems = feedItems.filter(function (it) {
      var a = String(it.author || '').toLowerCase().replace(/^@/, '').trim();
      return a === cleanHandle.toLowerCase();
    });

    creatorProfileBanner.classList.remove('hidden');
    creatorProfileBanner.hidden = false;
    creatorProfileBanner.style.removeProperty('display');

    if (creatorBannerHandle) {
      creatorBannerHandle.textContent = '@' + cleanHandle;
    }

    var firstWithAvatar = matchingItems.find(function (it) { return it.avatarUrl; });
    if (creatorBannerAvatar) {
      if (firstWithAvatar && firstWithAvatar.avatarUrl) {
        creatorBannerAvatar.src = firstWithAvatar.avatarUrl;
        creatorBannerAvatar.style.display = 'block';
      } else {
        creatorBannerAvatar.style.display = 'none';
      }
    }

    var isOnProfilePage = activeTabUrl && activeTabUrl.toLowerCase().indexOf('/@' + cleanHandle.toLowerCase()) !== -1;

    if (creatorBannerSubtitle) {
      if (isOnProfilePage) {
        creatorBannerSubtitle.textContent = matchingItems.length + ' vidéo(s) chargée(s) depuis le profil public de @' + cleanHandle;
      } else {
        creatorBannerSubtitle.textContent = matchingItems.length + ' vidéo(s) dans cette collection · Cliquez pour charger toutes les vidéos publiées de @' + cleanHandle;
      }
    }

    if (loadCreatorProfileBtn) {
      var btnText = loadCreatorProfileBtn.querySelector('span');
      if (btnText) {
        btnText.textContent = isOnProfilePage
          ? 'Scanner tout le profil (Auto)'
          : 'Charger toutes ses vidéos (Profil)';
      }
    }

    if (backToPlaylistBtn) {
      var backText = backToPlaylistBtn.querySelector('span');
      if (backText) {
        backText.textContent = previousPlaylistUrl ? '↩ Collection' : 'Tous';
      }
    }
  }

  function loadAllCreatorVideos(handle) {
    if (!handle || handle === 'all') return;
    var clean = String(handle).replace(/^@/, '').trim();
    if (!clean) return;

    if (activeTabUrl && (activeTabUrl.indexOf('/collection/') !== -1 || activeTabUrl.indexOf('/playlist/') !== -1 || activeTabUrl.indexOf('/tag/') !== -1)) {
      previousPlaylistUrl = activeTabUrl;
    }

    var profileUrl = 'https://www.tiktok.com/@' + clean;
    activeCreatorFilter = clean;

    getTargetTab(function (tab) {
      if (tab && tab.id) {
        var currentUrl = tab.url || '';
        var isAlreadyOnProfile = currentUrl.toLowerCase().indexOf('/@' + clean.toLowerCase()) !== -1;

        if (isAlreadyOnProfile) {
          setStatus('Scan du profil @' + clean + ' en cours pour charger toutes ses vidéos…', 'success');
          startDeepScan();
        } else {
          if (api.tabs && api.tabs.update) {
            api.tabs.update(tab.id, { url: profileUrl });
          }
          setStatus('Ouverture de @' + clean + ' et lancement du scan pour charger toutes ses vidéos publiées…', 'success');
          setTimeout(function () {
            startDeepScan();
          }, 1500);
        }
      } else {
        if (api.tabs && api.tabs.create) {
          api.tabs.create({ url: profileUrl });
        }
      }
    });

    renderItems();
    updateFeedCountStatus();
  }

  if (loadCreatorProfileBtn) {
    loadCreatorProfileBtn.addEventListener('click', function () {
      if (activeCreatorFilter && activeCreatorFilter !== 'all') {
        loadAllCreatorVideos(activeCreatorFilter);
      }
    });
  }

  if (dlCreatorProfileBtn) {
    dlCreatorProfileBtn.addEventListener('click', function () {
      if (!activeCreatorFilter || activeCreatorFilter === 'all') return;
      var clean = String(activeCreatorFilter).replace(/^@/, '').trim();
      var profileUrl = 'https://www.tiktok.com/@' + clean;
      dlCreatorProfileBtn.disabled = true;
      dlCreatorProfileBtn.textContent = 'Envoi…';
      sendRuntimeMessage({
        type: 'DOWNLOAD_BTN_CLICK',
        url: profileUrl,
        pageUrl: profileUrl,
        options: { noWatermark: true }
      }).then(function (res) {
        dlCreatorProfileBtn.disabled = false;
        dlCreatorProfileBtn.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg><span>Tout télécharger (App)</span>';
        if (res && res.ok) {
          setStatus('Profil complet @' + clean + ' envoyé à l\'App ! Téléchargement de toutes ses vidéos en cours.', 'success');
        } else {
          setStatus('Échec d\'envoi à l\'App', 'error');
        }
      }).catch(function () {
        dlCreatorProfileBtn.disabled = false;
        dlCreatorProfileBtn.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg><span>Tout télécharger (App)</span>';
        setStatus('Échec d\'envoi à l\'App', 'error');
      });
    });
  }

  if (backToPlaylistBtn) {
    backToPlaylistBtn.addEventListener('click', function () {
      activeCreatorFilter = 'all';
      if (previousPlaylistUrl) {
        var returnUrl = previousPlaylistUrl;
        previousPlaylistUrl = '';
        getTargetTab(function (tab) {
          if (tab && tab.id && api.tabs && api.tabs.update) {
            api.tabs.update(tab.id, { url: returnUrl });
          }
        });
      }
      renderItems();
      updateFeedCountStatus();
    });
  }

  function getDetectedCreators() {
    var itemsToAnalyze = activePlatformFilter === 'all'
      ? feedItems
      : (activePlatformFilter === 'current'
          ? feedItems.filter(function (it) {
              if (!activeTabUrl) return true;
              try {
                return new URL(it.pageUrl || it.url).hostname.replace(/^www\./, '') === new URL(activeTabUrl).hostname.replace(/^www\./, '');
              } catch (e) { return true; }
            })
          : feedItems.filter(function (it) { return itemPlatform(it) === activePlatformFilter; }));

    var creators = {};
    itemsToAnalyze.forEach(function (it) {
      var author = String(it.author || '').trim();
      if (!author || author === 'Créateur' || author === 'Auteur' || author === 'Inconnu') return;
      var clean = author.replace(/^@/, '').trim();
      if (!clean) return;
      var key = clean.toLowerCase();
      if (!creators[key]) {
        var plat = itemPlatform(it) || 'tiktok';
        var pUrl = plat === 'x' ? ('https://x.com/' + clean) : ('https://www.tiktok.com/@' + clean);
        creators[key] = {
          handle: clean,
          displayName: author.indexOf('@') === 0 ? author : ('@' + author),
          count: 0,
          avatarUrl: it.avatarUrl || null,
          platform: plat,
          profileUrl: pUrl,
        };
      }
      creators[key].count++;
      if (!creators[key].avatarUrl && it.avatarUrl) {
        creators[key].avatarUrl = it.avatarUrl;
      }
    });

    var creatorKeys = Object.keys(creators);
    creatorKeys.sort(function (a, b) {
      return creators[b].count - creators[a].count;
    });

    return creatorKeys.map(function (k) { return creators[k]; });
  }

  function syncViewModeCounts() {
    var detectedCreators = getDetectedCreators();
    if (viewModeVideosCount) {
      viewModeVideosCount.textContent = String(feedItems.length);
    }
    if (viewModeCreatorsCount) {
      viewModeCreatorsCount.textContent = String(detectedCreators.length);
    }
    if (recoverAccountsBtn) {
      var count = detectedCreators.length;
      recoverAccountsBtn.style.display = count > 0 ? 'inline-flex' : 'none';
      var textEl = recoverAccountsBtn.querySelector('span');
      if (textEl) {
        textEl.textContent = 'Récupérer les comptes' + (count > 0 ? (' (' + count + ')') : '');
      }
    }
  }

  function setViewMode(mode) {
    currentViewMode = mode;
    if (viewModeVideosBtn) viewModeVideosBtn.classList.toggle('active', mode === 'videos');
    if (viewModeCreatorsBtn) viewModeCreatorsBtn.classList.toggle('active', mode === 'creators');

    var displayToolbar = document.querySelector('.display-toolbar');
    var feedOptionsBar = document.querySelector('.feed-options-bar');
    var playlistBanner = document.getElementById('playlist-banner');
    var creatorProfileBanner = document.getElementById('creator-profile-banner');

    if (mode === 'creators') {
      if (displayToolbar) displayToolbar.style.display = 'none';
      if (feedOptionsBar) feedOptionsBar.style.display = 'none';
      if (playlistBanner) playlistBanner.style.setProperty('display', 'none', 'important');
      if (creatorProfileBanner) creatorProfileBanner.style.setProperty('display', 'none', 'important');
      if (copyCreatorsBtn) {
        copyCreatorsBtn.classList.remove('hidden');
        copyCreatorsBtn.removeAttribute('hidden');
        copyCreatorsBtn.style.setProperty('display', 'inline-flex', 'important');
      }
      if (exportCreatorsBtn) {
        exportCreatorsBtn.classList.remove('hidden');
        exportCreatorsBtn.removeAttribute('hidden');
        exportCreatorsBtn.style.setProperty('display', 'inline-flex', 'important');
      }
      renderCreatorsList();
      syncCreatorsSelection();
    } else {
      if (displayToolbar) displayToolbar.style.removeProperty('display');
      if (feedOptionsBar) feedOptionsBar.style.removeProperty('display');
      if (copyCreatorsBtn) {
        copyCreatorsBtn.classList.add('hidden');
        copyCreatorsBtn.setAttribute('hidden', '');
        copyCreatorsBtn.style.setProperty('display', 'none', 'important');
      }
      if (exportCreatorsBtn) {
        exportCreatorsBtn.classList.add('hidden');
        exportCreatorsBtn.setAttribute('hidden', '');
        exportCreatorsBtn.style.setProperty('display', 'none', 'important');
      }
      renderItems();
      updateFeedCountStatus();
      syncCardSelection();
    }
  }

  function renderCreatorsList() {
    if (!feedList) return;
    feedList.innerHTML = '';

    var creators = getDetectedCreators();
    if (creators.length === 0) {
      var empty = document.createElement('div');
      empty.className = 'empty-state';
      empty.textContent = 'Aucun compte créateur détecté pour le moment.';
      feedList.appendChild(empty);
      setStatus('Aucun compte créateur disponible.', '');
      if (selectionCount) selectionCount.textContent = '0 compte(s) sélectionné(s)';
      if (downloadSelectedButton) downloadSelectedButton.disabled = true;
      return;
    }

    setStatus(creators.length + ' compte' + (creators.length > 1 ? 's' : '') + ' créateur(s) détecté(s) · Prêt à récupérer', 'success');
    if (scanInfo) {
      scanInfo.textContent = creators.length + ' compte(s) au total';
    }

    creators.forEach(function (c) {
      var isSelected = selectedCreatorHandles.has(c.handle);
      var card = document.createElement('div');
      card.className = 'creator-card' + (isSelected ? ' selected' : '');
      card.setAttribute('data-handle', c.handle);

      var checkWrap = document.createElement('div');
      checkWrap.className = 'creator-card-checkbox';
      var cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.checked = isSelected;
      cb.setAttribute('aria-label', 'Sélectionner ' + c.displayName);
      cb.addEventListener('click', function (e) {
        e.stopPropagation();
        toggleCreatorSelection(c.handle);
      });
      checkWrap.appendChild(cb);
      card.appendChild(checkWrap);

      if (c.avatarUrl) {
        var av = document.createElement('img');
        av.className = 'creator-card-avatar';
        av.src = c.avatarUrl;
        av.alt = '';
        av.loading = 'lazy';
        av.addEventListener('error', function () {
          av.style.display = 'none';
        });
        card.appendChild(av);
      } else {
        var ph = document.createElement('span');
        ph.className = 'creator-card-avatar-placeholder';
        ph.textContent = (c.handle.charAt(0) || '?').toUpperCase();
        card.appendChild(ph);
      }

      var body = document.createElement('div');
      body.className = 'creator-card-body';

      var handleRow = document.createElement('div');
      handleRow.className = 'creator-card-handle';
      handleRow.textContent = c.displayName;
      body.appendChild(handleRow);

      var metaRow = document.createElement('div');
      metaRow.className = 'creator-card-meta';
      var badge = document.createElement('span');
      badge.className = 'creator-card-badge';
      badge.textContent = c.count + ' vidéo' + (c.count > 1 ? 's' : '') + ' dans la collection';
      metaRow.appendChild(badge);
      body.appendChild(metaRow);

      card.appendChild(body);

      var actions = document.createElement('div');
      actions.className = 'creator-card-actions';

      var loadBtn = document.createElement('button');
      loadBtn.type = 'button';
      loadBtn.className = 'creator-card-btn primary';
      loadBtn.title = 'Ouvrir le profil et charger toutes les vidéos publiées de ' + c.displayName;
      loadBtn.innerHTML = '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg><span>⚡ Tout charger</span>';
      loadBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        loadAllCreatorVideos(c.handle);
      });
      actions.appendChild(loadBtn);

      var dlBtn = document.createElement('button');
      dlBtn.type = 'button';
      dlBtn.className = 'creator-card-btn secondary';
      dlBtn.title = 'Télécharger toutes les vidéos publiées de ce profil via Modern Downloader';
      dlBtn.innerHTML = '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg><span>App</span>';
      dlBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        sendCreatorToApp(c, dlBtn);
      });
      actions.appendChild(dlBtn);

      var openBtn = document.createElement('button');
      openBtn.type = 'button';
      openBtn.className = 'creator-card-btn secondary';
      openBtn.title = 'Ouvrir le profil dans un nouvel onglet';
      openBtn.innerHTML = '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path><polyline points="15 3 21 3 21 9"></polyline><line x1="10" y1="14" x2="21" y2="3"></line></svg>';
      openBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        if (api.tabs && api.tabs.create) {
          api.tabs.create({ url: c.profileUrl });
        }
      });
      actions.appendChild(openBtn);

      card.appendChild(actions);

      card.addEventListener('click', function () {
        toggleCreatorSelection(c.handle);
      });

      feedList.appendChild(card);
    });

    syncCreatorsSelection();
  }

  function toggleCreatorSelection(handle) {
    if (selectedCreatorHandles.has(handle)) {
      selectedCreatorHandles.delete(handle);
    } else {
      selectedCreatorHandles.add(handle);
    }
    syncCreatorsSelection();
  }

  function syncCreatorsSelection() {
    if (!feedList) return;
    var cards = feedList.querySelectorAll('.creator-card');
    cards.forEach(function (card) {
      var h = card.getAttribute('data-handle');
      var isSel = selectedCreatorHandles.has(h);
      card.classList.toggle('selected', isSel);
      var cb = card.querySelector('input[type="checkbox"]');
      if (cb) cb.checked = isSel;
    });

    if (selectionCount) {
      selectionCount.textContent = selectedCreatorHandles.size + ' compte(s) sélectionné(s)';
    }

    if (downloadSelectedButton) {
      downloadSelectedButton.disabled = selectedCreatorHandles.size === 0;
      var span = downloadSelectedButton.querySelector('span');
      if (span) {
        span.textContent = 'Télécharger les comptes (' + selectedCreatorHandles.size + ')';
      }
    }
  }

  function downloadSelectedCreators() {
    var creators = getDetectedCreators().filter(function (c) {
      return selectedCreatorHandles.has(c.handle);
    });

    if (creators.length === 0) {
      setStatus('Sélectionnez au moins un compte créateur.', 'error');
      return;
    }

    setBusy(true);
    setStatus('Envoi de ' + creators.length + ' compte(s) à Modern Downloader…', '');

    var completed = 0;
    var failed = 0;

    function sendNextCreator(index) {
      if (index >= creators.length) return Promise.resolve();
      var c = creators[index];
      return sendRuntimeMessage({
        type: 'DOWNLOAD_BTN_CLICK',
        url: c.profileUrl,
        pageUrl: c.profileUrl,
        options: {
          noWatermark: true,
        },
        thumbnailUrl: c.avatarUrl || null,
      }).then(function (res) {
        if (res && res.ok) {
          completed++;
          var card = feedList.querySelector('.creator-card[data-handle="' + c.handle + '"]');
          if (card) {
            var dlBtn = card.querySelector('.creator-card-btn.secondary');
            if (dlBtn) {
              dlBtn.className = 'creator-card-btn sent';
              dlBtn.innerHTML = '<span>✓ Envoyé</span>';
            }
          }
        } else {
          failed++;
        }
      }).catch(function () {
        failed++;
      }).then(function () {
        return sendNextCreator(index + 1);
      });
    }

    sendNextCreator(0).then(function () {
      setBusy(false);
      var msg = completed + ' compte(s) créateur(s) envoyé(s) à Modern Downloader !';
      if (failed > 0) {
        msg += ' (' + failed + ' échec(s))';
      }
      setStatus(msg, completed > 0 ? 'success' : 'error');
    });
  }

  function sendCreatorToApp(c, btn) {
    if (!c || !c.profileUrl) return;
    if (btn) {
      btn.disabled = true;
      btn.textContent = 'Envoi…';
    }
    sendRuntimeMessage({
      type: 'DOWNLOAD_BTN_CLICK',
      url: c.profileUrl,
      pageUrl: c.profileUrl,
      options: { noWatermark: true },
      thumbnailUrl: c.avatarUrl || null,
    }).then(function (res) {
      if (btn) {
        btn.disabled = false;
        if (res && res.ok) {
          btn.className = 'creator-card-btn sent';
          btn.innerHTML = '<span>✓ Envoyé</span>';
          setStatus('Profil @' + c.handle + ' envoyé à l\'App avec succès !', 'success');
        } else {
          btn.innerHTML = '<span>Erreur</span>';
          setStatus('Échec d\'envoi à l\'App pour @' + c.handle, 'error');
        }
      }
    }).catch(function () {
      if (btn) {
        btn.disabled = false;
        btn.innerHTML = '<span>Erreur</span>';
        setStatus('Échec d\'envoi à l\'App pour @' + c.handle, 'error');
      }
    });
  }

  function copyCreatorUrls(customHandles) {
    var handles = customHandles || Array.from(selectedCreatorHandles);
    if (handles.length === 0) {
      var allCreators = getDetectedCreators();
      handles = allCreators.map(function (c) { return c.handle; });
    }
    if (handles.length === 0) {
      setStatus('Aucun compte à copier.', 'error');
      return;
    }

    var urls = handles.map(function (h) {
      return 'https://www.tiktok.com/@' + h.replace(/^@/, '');
    }).join('\n');

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(urls).then(function () {
        setStatus(handles.length + ' URL(s) de profil copiée(s) dans le presse-papier !', 'success');
      }).catch(function () {
        setStatus('Impossible de copier dans le presse-papier.', 'error');
      });
    } else {
      setStatus('Presse-papier non disponible.', 'error');
    }
  }

  function exportCreatorUrls(customHandles) {
    var handles = customHandles || Array.from(selectedCreatorHandles);
    if (handles.length === 0) {
      var allCreators = getDetectedCreators();
      handles = allCreators.map(function (c) { return c.handle; });
    }
    if (handles.length === 0) {
      setStatus('Aucun compte à exporter.', 'error');
      return;
    }

    var lines = handles.map(function (h) {
      return 'https://www.tiktok.com/@' + h.replace(/^@/, '');
    }).join('\r\n');

    try {
      var blob = new Blob([lines], { type: 'text/plain;charset=utf-8' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = 'comptes_tiktok.txt';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      setStatus(handles.length + ' compte(s) exporté(s) dans comptes_tiktok.txt', 'success');
    } catch (e) {
      setStatus('Échec de l\'export du fichier.', 'error');
    }
  }

  function openRecoverAccountsModal() {
    var creators = getDetectedCreators();
    if (!recoverAccountsModal) return;
    if (recoverAccountsTitle) {
      recoverAccountsTitle.textContent = creators.length + ' compte(s) détecté(s)';
    }
    recoverAccountsModal.classList.remove('hidden');
    recoverAccountsModal.removeAttribute('hidden');
    recoverAccountsModal.style.setProperty('display', 'flex', 'important');
  }

  function closeRecoverAccountsModal() {
    if (!recoverAccountsModal) return;
    recoverAccountsModal.classList.add('hidden');
    recoverAccountsModal.setAttribute('hidden', '');
    recoverAccountsModal.style.setProperty('display', 'none', 'important');
  }

  function syncCreatorFilterPills() {
    var bar = document.getElementById('creator-filters-bar');
    var list = document.getElementById('creator-filters-list');
    var hint = document.getElementById('creator-filters-hint');
    if (!bar || !list) return;

    var creators = getDetectedCreators();
    syncViewModeCounts();

    if (activePlatformFilter === 'sniffed' || feedItems.length === 0) {
      bar.classList.add('hidden');
      bar.hidden = true;
      bar.style.setProperty('display', 'none', 'important');
      return;
    }

    if (creators.length < 2 && activeCreatorFilter === 'all') {
      bar.classList.add('hidden');
      bar.hidden = true;
      bar.style.setProperty('display', 'none', 'important');
      return;
    }

    bar.classList.remove('hidden');
    bar.hidden = false;
    bar.style.removeProperty('display');

    if (hint) {
      hint.textContent = creators.length + ' compte' + (creators.length > 1 ? 's' : '');
    }

    list.innerHTML = '';

    // "Tous" pill
    var allPill = document.createElement('button');
    allPill.type = 'button';
    allPill.className = 'creator-pill' + (activeCreatorFilter === 'all' ? ' active' : '');
    allPill.setAttribute('role', 'tab');
    allPill.setAttribute('aria-selected', activeCreatorFilter === 'all' ? 'true' : 'false');

    var allName = document.createElement('span');
    allName.className = 'creator-pill-name';
    allName.textContent = 'Tous';
    allPill.appendChild(allName);

    var allCount = document.createElement('span');
    allCount.className = 'creator-pill-count';
    allCount.textContent = String(feedItems.length);
    allPill.appendChild(allCount);

    allPill.addEventListener('click', function () {
      selectCreatorFilter('all');
    });
    list.appendChild(allPill);

    // Creator pills
    creators.forEach(function (c) {
      var isAct = activeCreatorFilter.toLowerCase() === c.handle.toLowerCase();
      var pill = document.createElement('button');
      pill.type = 'button';
      pill.className = 'creator-pill' + (isAct ? ' active' : '');
      pill.setAttribute('role', 'tab');
      pill.setAttribute('aria-selected', isAct ? 'true' : 'false');
      pill.title = c.displayName + ' (' + c.count + ' vidéo' + (c.count > 1 ? 's' : '') + ' dans la collection)';

      if (c.avatarUrl) {
        var avatar = document.createElement('img');
        avatar.className = 'creator-pill-avatar';
        avatar.src = c.avatarUrl;
        avatar.alt = '';
        avatar.loading = 'lazy';
        avatar.addEventListener('error', function () {
          avatar.style.display = 'none';
        });
        pill.appendChild(avatar);
      } else {
        var placeholder = document.createElement('span');
        placeholder.className = 'creator-pill-avatar creator-pill-avatar-placeholder';
        placeholder.textContent = (c.handle.charAt(0) || '?').toUpperCase();
        pill.appendChild(placeholder);
      }

      var nameSpan = document.createElement('span');
      nameSpan.className = 'creator-pill-name';
      nameSpan.textContent = c.displayName;
      pill.appendChild(nameSpan);

      var countSpan = document.createElement('span');
      countSpan.className = 'creator-pill-count';
      countSpan.textContent = String(c.count);
      pill.appendChild(countSpan);

      var quickAction = document.createElement('span');
      quickAction.className = 'creator-pill-quick-action';
      quickAction.title = 'Charger toutes les vidéos publiées de ' + c.displayName + ' (Profil)';
      quickAction.textContent = '⚡';
      quickAction.addEventListener('click', function (e) {
        e.stopPropagation();
        loadAllCreatorVideos(c.handle);
      });
      pill.appendChild(quickAction);

      pill.addEventListener('click', function () {
        selectCreatorFilter(c.handle);
      });
      list.appendChild(pill);
    });
  }

  function displayedItems() {
    return filteredItems().slice(0, visibleCount());
  }

  function visibleCount() {
    var items = filteredItems();
    if (items.length === 0) return 0;
    return Math.min(items.length, displayLimit, MAX_ITEMS);
  }

  function parseDigitCount(value) {
    var raw = String(value || '').trim();
    if (!raw || !/^\d+$/.test(raw)) return null;
    var count = parseInt(raw, 10);
    if (!Number.isFinite(count) || count < 1) return null;
    return count;
  }

  function digitsOnlyValue(value) {
    return String(value || '').replace(/\D/g, '');
  }

  function syncDisplaySlider() {
    if (!displaySlider) return;
    displaySlider.min = '1';
    displaySlider.max = '1000';
    displaySlider.value = String(displayLimit);
    displaySlider.disabled = false;
    if (displayLimitValue) {
      displayLimitValue.textContent = displayLimit === 1 ? '1 (Actif)' : String(displayLimit);
    }
    displaySlider.setAttribute(
      'aria-label',
      t('xFeedDisplayLimit', 'Afficher') + ' ' + (displayLimit === 1 ? '1 actif' : String(displayLimit)),
    );
  }

  function pruneHiddenSelection() {
    var visibleIds = {};
    displayedItems().forEach(function (item) {
      visibleIds[item.id] = true;
    });
    Array.from(selectedIds).forEach(function (id) {
      if (!visibleIds[id]) selectedIds.delete(id);
    });
  }

  function selectFirstDisplayed(count) {
    var visible = displayedItems();
    selectedIds.clear();
    var added = 0;
    // Prefer non-downloaded items first
    for (var i = 0; i < visible.length && added < count; i++) {
      var it = visible[i];
      if (isItemDownloaded(it)) continue;
      selectedIds.add(it.id);
      added++;
    }
    // If all items are downloaded and user requested selection, fallback to selecting them
    if (added === 0 && count > 0 && visible.length > 0) {
      for (var j = 0; j < Math.min(count, visible.length); j++) {
        selectedIds.add(visible[j].id);
        added++;
      }
    }
    if (selectCountInput) {
      selectCountInput.value = added > 0 ? String(added) : '';
    }
    syncCardSelection();
  }

  function applySelectCountFromInput() {
    if (!selectCountInput || busy) return;
    var parsed = parseDigitCount(selectCountInput.value);
    if (parsed == null) return;
    if (currentViewMode === 'creators') {
      var creators = getDetectedCreators();
      selectedCreatorHandles.clear();
      for (var i = 0; i < Math.min(parsed, creators.length); i++) {
        selectedCreatorHandles.add(creators[i].handle);
      }
      syncCreatorsSelection();
    } else {
      var max = visibleCount();
      if (max === 0) return;
      selectFirstDisplayed(Math.min(parsed, max));
    }
  }

  function updateFeedCountStatus(options) {
    var opts = options || {};
    var filtered = filteredItems();
    var foundMessage = replaceCount(
      t('xFeedFound', '{count} video posts found'),
      feedItems.length,
    );
    if (activeCreatorFilter && activeCreatorFilter !== 'all') {
      foundMessage = filtered.length + ' vidéo' + (filtered.length > 1 ? 's' : '') + ' de @' + activeCreatorFilter;
    } else if (hideDownloadedEnabled) {
      var downloadedCount = feedItems.filter(isItemDownloaded).length;
      if (downloadedCount > 0) {
        foundMessage += ' (' + downloadedCount + ' déjà téléchargé' + (downloadedCount > 1 ? 's' : '') + ' masqué' + (downloadedCount > 1 ? 's' : '') + ')';
      }
    }
    var suffix = activeSource === 'gobird'
      ? t('xFeedSnapshotLive', 'snapshot + live collection')
      : (liveCollectionEnabled
        ? t('xFeedLive', 'live collection')
        : t('xFeedSnapshot', 'full snapshot'));
    var limitHint = '';
    var shown = visibleCount();
    if (shown > 0 && shown < filtered.length) {
      limitHint = ' · ' + replaceCount(
        t('xFeedShowing', 'showing {count}'),
        shown,
      );
    }
    if (opts.truncated) {
      limitHint += ' · ' + replaceCount(
        t('xFeedLimitReached', 'First {count} shown'),
        MAX_ITEMS,
      );
    }
    scanInfo.textContent = foundMessage + ' · ' + suffix + limitHint;
    setStatus(
      filtered.length > 0
        ? foundMessage
        : (activeCreatorFilter !== 'all' ? ('Aucune vidéo pour @' + activeCreatorFilter) : t('xFeedNoItems', 'No loaded video posts found.')),
      filtered.length > 0 ? 'success' : '',
    );
  }

  function updateSelectionUi() {
    if (currentViewMode === 'creators') {
      syncCreatorsSelection();
      return;
    }
    var count = selectedIds.size;
    selectionCount.textContent = replaceCount(
      t('xFeedSelection', '{count} selected'),
      count,
    );
    downloadSelectedButton.disabled = busy || count === 0;
    var dlSpan = downloadSelectedButton.querySelector('span');
    if (dlSpan) dlSpan.textContent = 'Télécharger';
    selectAllButton.disabled = busy || visibleCount() === 0;
    clearSelectionButton.disabled = busy || count === 0;
    if (selectCountInput) {
      selectCountInput.disabled = busy || visibleCount() === 0;
    }
  }

  function syncCardSelection() {
    feedList.querySelectorAll('.feed-card').forEach(function (card) {
      var selected = selectedIds.has(card.dataset.feedId);
      card.classList.toggle('selected', selected);
      var checkbox = card.querySelector('.feed-checkbox');
      if (checkbox) checkbox.checked = selected;
    });
    updateSelectionUi();
  }

  function downloadSingleItem(item, card, btn) {
    if (!item || busy) return;
    var downloadUrl = downloadUrlForFeedItem(item);
    if (!downloadUrl) {
      setStatus(t('itemUrlInvalid', 'URL invalide.'), 'error');
      return;
    }

    if (btn) {
      btn.disabled = true;
      btn.classList.add('downloading');
      btn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 12a9 9 0 1 1-6.219-8.56"></path></svg>';
    }
    if (card) {
      var pWrap = card.querySelector('.card-progress-bar-wrap');
      if (pWrap) pWrap.style.display = 'block';
    }

    var isTiktok = item.platform === 'tiktok';
    sendRuntimeMessage({
      type: 'DOWNLOAD_BTN_CLICK',
      url: downloadUrl,
      pageUrl: item.pageUrl,
      options: {
        noWatermark: isTiktok ? true : undefined,
      },
      thumbnailUrl: item.thumbnailUrl || null,
      tweetId: item.platform === 'x' ? (String(item.id || '').split('-')[0] || null) : null,
      tikTokId: isTiktok ? String(item.id || '').replace(/^tt-/, '') : null,
    }).then(function (result) {
      if (result && result.ok) {
        setStatus(t('itemSent', 'Téléchargement envoyé à l’application…'), 'success');
      } else {
        if (btn) {
          btn.disabled = false;
          btn.classList.remove('downloading');
          btn.classList.add('error');
          setTimeout(function () { btn.classList.remove('error'); }, 3000);
        }
        if (card) {
          var errWrap = card.querySelector('.card-progress-bar-wrap');
          if (errWrap) errWrap.style.display = 'none';
        }
        setStatus(t('itemSendFailed', 'Échec de l’envoi.'), 'error');
      }
    }).catch(function () {
      if (btn) {
        btn.disabled = false;
        btn.classList.remove('downloading');
        btn.classList.add('error');
        setTimeout(function () { btn.classList.remove('error'); }, 3000);
      }
      if (card) {
        var errWrap = card.querySelector('.card-progress-bar-wrap');
        if (errWrap) errWrap.style.display = 'none';
      }
      setStatus(t('itemSendFailed', 'Échec de l’envoi.'), 'error');
    });
  }

  function removeFeedCardOnSuccess(identifier) {
    if (!identifier) return;
    var cleanId = String(identifier).trim();
    var targetIndex = -1;
    var targetId = null;

    for (var i = 0; i < feedItems.length; i++) {
      var it = feedItems[i];
      if (
        it.id === cleanId ||
        it.url === cleanId ||
        it.pageUrl === cleanId ||
        (cleanId.indexOf('tt-') === 0 && it.id === cleanId) ||
        (it.id.indexOf('tt-') === 0 && cleanId === it.id.replace('tt-', '')) ||
        (it.url && it.url.indexOf(cleanId) !== -1) ||
        (cleanId.indexOf('http') === 0 && (it.url === cleanId || it.pageUrl === cleanId))
      ) {
        targetIndex = i;
        targetId = it.id;
        break;
      }
    }

    if (targetIndex !== -1 && targetId) {
      var card = feedList.querySelector('.feed-card[data-feed-id="' + targetId + '"]');
      if (card) {
        card.classList.add('card-removing');
        setTimeout(function () {
          if (card.isConnected) card.remove();
          var visible = displayedItems();
          if (visible.length === 0) renderItems();
        }, 320);
      }
      feedItems.splice(targetIndex, 1);
      selectedIds.delete(targetId);
      updateSelectionUi();
      updateFeedCountStatus();
      syncPlatformFilterPills();
    }
  }

  function createFeedCard(item) {
    var downloaded = isItemDownloaded(item);
    var card = document.createElement('article');
    card.className = 'feed-card' +
      (selectedIds.has(item.id) ? ' selected' : '') +
      (downloaded ? ' is-downloaded' : '');
    card.dataset.feedId = item.id;
    card.dataset.isActive = String(Boolean(item.isActive));
    if (downloaded) card.dataset.isDownloaded = 'true';

    var checkbox = document.createElement('input');
    checkbox.className = 'feed-checkbox';
    checkbox.type = 'checkbox';
    checkbox.checked = selectedIds.has(item.id);
    checkbox.setAttribute('aria-label', item.title);
    if (downloaded) {
      checkbox.title = 'Déjà téléchargé ou doublon';
    }
    checkbox.addEventListener('change', function () {
      if (checkbox.checked) selectedIds.add(item.id);
      else selectedIds.delete(item.id);
      card.classList.toggle('selected', checkbox.checked);
      updateSelectionUi();
    });

    var isVertical = item.platform === 'tiktok' ||
      (Number.isFinite(item.height) && Number.isFinite(item.width) && item.height > item.width * 1.1);

    var thumbnail = createThumbnail(item);
    if (isVertical) thumbnail.classList.add('vertical-thumb');

    var body = document.createElement('div');
    body.className = 'card-body';

    // Author row with optional avatar, active badge and creator actions
    var authorRow = document.createElement('div');
    authorRow.className = 'card-author-row';
    if (item.avatarUrl && isSafeHttpUrl(item.avatarUrl)) {
      var avatar = document.createElement('img');
      avatar.className = 'card-author-avatar';
      avatar.src = item.avatarUrl;
      avatar.alt = item.author;
      authorRow.appendChild(avatar);
    }
    var author = document.createElement('div');
    author.className = 'card-author';
    author.textContent = item.author;
    authorRow.appendChild(author);

    if (item.isActive) {
      var activeBadge = document.createElement('span');
      activeBadge.className = 'active-indicator-badge';
      activeBadge.textContent = 'En lecture';
      authorRow.appendChild(activeBadge);
    }

    if (item.author) {
      var creatorBtn = document.createElement('button');
      creatorBtn.type = 'button';
      creatorBtn.className = 'card-creator-btn';
      creatorBtn.title = 'Options créateur (' + item.author + ')';
      creatorBtn.innerHTML = '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg><span>Profil</span>';
      creatorBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        openCreatorModal(item.author);
      });
      authorRow.appendChild(creatorBtn);
    }

    var title = document.createElement('div');
    title.className = 'card-title';
    title.title = item.title;
    title.textContent = item.title;

    var metadata = document.createElement('div');
    metadata.className = 'card-meta';
    [formatDuration(item.durationSeconds), formatResolution(item), formatSize(item)]
      .forEach(function (value) {
        if (!value) return;
        var detail = document.createElement('span');
        detail.className = 'meta-chip';
        detail.textContent = value;
        metadata.appendChild(detail);
      });

    var platform = itemPlatform(item);
    var platformBadge = document.createElement('span');
    platformBadge.className = 'card-platform-pill platform-' + platform;
    platformBadge.textContent = platform.toUpperCase();
    metadata.appendChild(platformBadge);

    if (platform === 'tiktok') {
      var noWmBadge = document.createElement('span');
      noWmBadge.className = 'card-platform-pill hd-clean';
      noWmBadge.textContent = 'HD SANS FILIGRANE';
      metadata.appendChild(noWmBadge);
    }

    if (downloaded) {
      var dlBadge = document.createElement('span');
      dlBadge.className = 'meta-chip downloaded-chip';
      dlBadge.innerHTML = '<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6"><polyline points="20 6 9 17 4 12"></polyline></svg>DÉJÀ TÉLÉCHARGÉ';
      metadata.appendChild(dlBadge);
    }

    body.appendChild(authorRow);
    body.appendChild(title);

    if (item.music) {
      var musicRow = document.createElement('div');
      musicRow.className = 'card-music';
      var musicIcon = document.createElement('span');
      musicIcon.textContent = '♪ ';
      musicRow.appendChild(musicIcon);
      var musicText = document.createElement('span');
      musicText.textContent = item.music;
      musicRow.appendChild(musicText);
      body.appendChild(musicRow);
    }

    body.appendChild(metadata);

    // Live progress bar
    var progressWrap = document.createElement('div');
    progressWrap.className = 'card-progress-bar-wrap';
    progressWrap.style.display = 'none';
    var progressFill = document.createElement('div');
    progressFill.className = 'card-progress-bar-fill';
    progressFill.style.width = '0%';
    progressWrap.appendChild(progressFill);
    body.appendChild(progressWrap);

    // Individual action column ("1 par 1")
    var actionCol = document.createElement('div');
    actionCol.className = 'card-action-col';
    var singleBtn = document.createElement('button');
    singleBtn.type = 'button';
    singleBtn.className = 'card-single-dl-btn';
    singleBtn.title = downloaded ? 'Déjà téléchargé (cliquez pour re-télécharger)' : t('downloadSingle', 'Télécharger cette vidéo');
    singleBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>';
    singleBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      downloadSingleItem(item, card, singleBtn);
    });
    actionCol.appendChild(singleBtn);

    card.appendChild(checkbox);
    card.appendChild(thumbnail);
    card.appendChild(body);
    card.appendChild(actionCol);
    return card;
  }

  function replaceItems(items) {
    feedItems = normalizeItems(items);
    selectedIds.clear();
    feedList.querySelectorAll('.feed-card').forEach(function (card) {
      card.remove();
    });
  }

  function renderItems() {
    syncDisplaySlider();
    syncPlatformFilterPills();
    syncCreatorFilterPills();
    syncCreatorProfileBanner();
    syncViewModeCounts();
    if (currentViewMode === 'creators') {
      renderCreatorsList();
      return;
    }
    var visible = displayedItems();
    var empty = feedList.querySelector('.empty-state');
    if (visible.length === 0) {
      feedList.querySelectorAll('.feed-card').forEach(function (card) {
        card.remove();
      });
      if (!empty) {
        empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.textContent = t('xFeedNoItems', 'No loaded video posts found.');
        feedList.appendChild(empty);
      }
      pruneHiddenSelection();
      updateSelectionUi();
      return;
    }

    if (empty) empty.remove();
    var visibleIds = {};
    visible.forEach(function (item) {
      visibleIds[item.id] = true;
    });
    feedList.querySelectorAll('.feed-card').forEach(function (card) {
      if (!visibleIds[card.dataset.feedId]) card.remove();
    });
    var renderedIds = {};
    feedList.querySelectorAll('.feed-card').forEach(function (card) {
      renderedIds[card.dataset.feedId] = true;
    });
    visible.forEach(function (item) {
      if (renderedIds[item.id]) return;
      feedList.appendChild(createFeedCard(item));
    });
    pruneHiddenSelection();
    updateSelectionUi();
  }

  function analyzeLoadedFeed() {
    if (busy) return;
    setBusy(true);
    scanInfo.textContent = '';

    function handleDomExtraction(domRes) {
      setBusy(false);
      if (domRes && domRes.ok && Array.isArray(domRes.items)) {
        mergeItems(domRes.items);
        renderItems();
        var msg = replaceCount(t('xFeedFound', '{count} video posts found'), feedItems.length);
        scanInfo.textContent = msg + ' · ' + t('xFeedLive', 'live collection');
        setStatus(feedItems.length > 0 ? msg : t('xFeedNoItems', 'Aucune vidéo trouvée sur cette page.'), feedItems.length > 0 ? 'success' : '');
        return;
      }
      setStatus(t('xFeedNoItems', 'Aucune vidéo trouvée sur cette page.'), '');
    }

    getTargetTab(function (tab) {
      var isX = tab && tab.url && (tab.url.indexOf('x.com') !== -1 || tab.url.indexOf('twitter.com') !== -1);
      if (!isX && tab && tab.id && api.tabs && api.tabs.sendMessage) {
        api.tabs.sendMessage(tab.id, { type: 'MD_EXTRACT_FEED', maxItems: Math.max(displayLimit, 1000) }, handleDomExtraction);
        return;
      }

        // On X: request Gobird from app
        setStatus(t(
          'xFeedGobirdPaginating',
          'gobird pagination in progress… local videos keep appearing.',
        ));
        sendRuntimeMessage({
          type: 'ANALYZE_X_FEED',
          maxItems: MAX_ITEMS,
        }).then(function (result) {
          if (!result || !result.ok) {
            if (feedItems.length === 0) renderItems();
            if (tab && tab.id) {
              api.tabs.sendMessage(tab.id, { type: 'MD_EXTRACT_FEED', maxItems: MAX_ITEMS }, handleDomExtraction);
              return;
            }
            setStatus(t('xFeedAnalyzeFailed', 'Could not analyze the loaded feed.'), 'error');
            setBusy(false);
            return;
          }

          var usedGobird = result.source === 'gobird';
          var fellBackFromGobird = !usedGobird && result.fallbackFrom === 'gobird';
          mergeItems(result.items);
          renderItems();
          setSource(usedGobird ? 'gobird' : 'dom', {
            fallbackFrom: fellBackFromGobird ? 'gobird' : null,
            errorCode: fellBackFromGobird ? result.gobirdErrorCode : null,
            error: fellBackFromGobird ? result.gobirdError : null,
          });
          var foundMessage = replaceCount(
            t('xFeedFound', '{count} video posts found'),
            feedItems.length,
          );
          var sourceHint = usedGobird
            ? t('xFeedSnapshotLive', 'snapshot + live collection')
            : (fellBackFromGobird
              ? t('xFeedFallbackSource', 'Local fallback (gobird failed)')
              : t('xFeedLive', 'live collection'));
          var limitHint = '';
          var shown = visibleCount();
          if (shown > 0 && shown < feedItems.length) {
            limitHint = ' · ' + replaceCount(
              t('xFeedShowing', 'showing {count}'),
              shown,
            );
          }
          if (result.truncated) {
            limitHint += ' · ' + replaceCount(
              t('xFeedLimitReached', 'First {count} shown'),
              MAX_ITEMS,
            );
          }
          scanInfo.textContent = foundMessage + ' · ' + sourceHint + limitHint;
          if (fellBackFromGobird) {
            setStatus(
              gobirdFailureHint(result.gobirdErrorCode, result.gobirdError),
              'error',
            );
          } else {
            setStatus(
              feedItems.length > 0
                ? foundMessage
                : t('xFeedNoItems', 'No loaded video posts found.'),
              feedItems.length > 0 ? 'success' : '',
            );
          }
        }).catch(function () {
          if (feedItems.length === 0) renderItems();
          setStatus(
            t('xFeedAnalyzeFailed', 'Could not analyze the loaded feed.'),
            'error',
          );
        }).finally(function () {
          setBusy(false);
        });
      });
  }

  function handleLiveFeedUpdate(message) {
    if (!message) return;

    if (message.type === 'MD_DEEP_SCAN_PROGRESS') {
      if (isHooked && hookedTabId !== null && message.senderTabId && message.senderTabId !== hookedTabId) {
        return;
      }
      if (deepScanCounter) {
        deepScanCounter.textContent = (message.count || 0) + ' vidéo(s) capturée(s)';
      }
      if (message.done) {
        stopDeepScan();
        setStatus((message.count || 0) + ' vidéos chargées avec succès !', 'success');
      }
      return;
    }

    if (message.type === 'MD_PAGE_NAVIGATED') {
      if (isHooked && hookedTabId !== null) {
        if (message.senderTabId && message.senderTabId !== hookedTabId) {
          return;
        }
        if (message.pageUrl && hookedTabUrl) {
          try {
            var nUrl = new URL(message.pageUrl);
            var hUrl = new URL(hookedTabUrl);
            if (nUrl.hostname !== hUrl.hostname || nUrl.pathname !== hUrl.pathname) {
              return;
            }
          } catch (e) {}
        }
      }
      activeCreatorFilter = 'all';
      feedItems = [];
      selectedIds.clear();
      renderItems();
      updateFeedCountStatus();
      setTimeout(analyzeLoadedFeed, 400);
      return;
    }
    if (message.type === 'MD_STREAM_SNIFFED' && message.stream) {
      var exists = sniffedStreams.some(function (s) { return s.url === message.stream.url; });
      if (!exists) {
        sniffedStreams.push(message.stream);
        updateSniffedCount();
        if (activePlatformFilter === 'sniffed') {
          renderItems();
        }
      }
      return;
    }

    if (message.type === 'MD_DOWNLOAD_PROGRESS' && message.data) {
      var d = message.data;
      // status 4 = DownloadStatus.completed, status 8 = DownloadStatus.duplicate
      if (d.status === 4 || d.status === 8) {
        if (d.tikTokId) downloadedTikTokSet.add(String(d.tikTokId));
        if (d.tweetId) downloadedTweetSet.add(String(d.tweetId));
        if (d.mediaId) downloadedMediaSet.add(String(d.mediaId));
        if (autoClearEnabled) {
          var key = d.tikTokId ? ('tt-' + d.tikTokId) : (d.tweetId || d.url || d.id);
          removeFeedCardOnSuccess(key);
          if (d.url) removeFeedCardOnSuccess(d.url);
        } else {
          var markId = d.tikTokId ? ('tt-' + d.tikTokId) : (d.tweetId || d.url || d.id);
          var mCard = feedList.querySelector('.feed-card[data-feed-id="' + markId + '"]');
          if (mCard) {
            mCard.classList.add('is-downloaded');
            mCard.dataset.isDownloaded = 'true';
            var sBtn = mCard.querySelector('.card-single-dl-btn');
            if (sBtn) {
              sBtn.classList.remove('downloading');
              sBtn.title = 'Déjà téléchargé';
            }
          }
        }
      } else if (d.status === 5) {
        // status 5 = DownloadStatus.failed
        var failId = d.tikTokId ? ('tt-' + d.tikTokId) : (d.tweetId || d.url || d.id);
        var errCard = feedList.querySelector('.feed-card[data-feed-id="' + failId + '"]');
        if (errCard) {
          var sBtn = errCard.querySelector('.card-single-dl-btn');
          if (sBtn) {
            sBtn.disabled = false;
            sBtn.classList.remove('downloading');
            sBtn.classList.add('error');
          }
          var pWrap = errCard.querySelector('.card-progress-bar-wrap');
          if (pWrap) pWrap.style.display = 'none';
        }
      } else if (d.status === 2 || d.status === 3) {
        // Extracting or downloading progress
        var pId = d.tikTokId ? ('tt-' + d.tikTokId) : (d.tweetId || d.url || d.id);
        var pCard = feedList.querySelector('.feed-card[data-feed-id="' + pId + '"]');
        if (pCard) {
          var wrap = pCard.querySelector('.card-progress-bar-wrap');
          var fill = pCard.querySelector('.card-progress-bar-fill');
          if (wrap && fill) {
            wrap.style.display = 'block';
            var pct = Math.round((d.progress || 0) * 100);
            fill.style.width = Math.max(5, pct) + '%';
          }
        }
      }
      return;
    }

    if (message.type !== 'MD_X_FEED_UPDATE' && message.type !== 'MD_FEED_UPDATE') return;
    if (isHooked && hookedTabId !== null && message.senderTabId && message.senderTabId !== hookedTabId) {
      return;
    }
    if (!liveCollectionEnabled) return;
    var added = mergeItems(message.items);
    if (added === 0) return;

    if (activeSource !== 'gobird') {
      setSource('dom', {
        fallbackFrom: gobirdFallbackActive ? 'gobird' : null,
        errorCode: gobirdFallbackErrorCode,
        error: gobirdFallbackError,
      });
    }
    renderItems();
    if (gobirdFallbackActive) {
      setStatus(
        gobirdFailureHint(gobirdFallbackErrorCode, gobirdFallbackError),
        'error',
      );
    } else {
      updateFeedCountStatus();
    }
  }

  function openXPage() {
    var targetUrl = 'https://x.com/home';
    if (activePlatformFilter === 'current' && activeTabUrl) {
      targetUrl = activeTabUrl;
    } else if (activePlatformFilter && activePlatformFilter !== 'all' && activePlatformFilter !== 'current') {
      if (activePlatformFilter === 'tiktok') targetUrl = 'https://www.tiktok.com/foryou';
      else if (activePlatformFilter === 'instagram') targetUrl = 'https://www.instagram.com/reels/';
      else if (activePlatformFilter === 'youtube') targetUrl = 'https://www.youtube.com/shorts';
      else if (activePlatformFilter === 'x') targetUrl = 'https://x.com';
      else if (activePlatformFilter.indexOf('.') !== -1) targetUrl = 'https://' + activePlatformFilter;
      else targetUrl = 'https://www.' + activePlatformFilter + '.com';
    }

    try {
      if (!api.tabs || !api.tabs.create) {
        setStatus(t('xFeedOpenFailed', 'Could not open website.'), 'error');
        return;
      }
      api.tabs.create({ url: targetUrl }).catch(function () {
        setStatus(t('xFeedOpenFailed', 'Could not open website.'), 'error');
      });
    } catch (e) {
      setStatus(t('xFeedOpenFailed', 'Could not open website.'), 'error');
    }
  }

  function downloadSelected() {
    if (currentViewMode === 'creators') {
      downloadSelectedCreators();
      return;
    }
    var selectedItems = displayedItems().filter(function (item) {
      return selectedIds.has(item.id);
    });
    if (selectedItems.length === 0) {
      setStatus(t('xFeedNoSelection', 'Select at least one video.'), 'error');
      return;
    }

    var mediaKeys = new Set();
    var skippedDuplicates = 0;
    var skippedItems = [];
    selectedItems = selectedItems.filter(function (item) {
      if (isItemDownloaded(item)) {
        skippedDuplicates++;
        skippedItems.push(item);
        return false;
      }
      var key = normalizedMediaUrl(item.url);
      if (key && mediaKeys.has(key)) {
        skippedDuplicates++;
        skippedItems.push(item);
        return false;
      }
      if (key) mediaKeys.add(key);
      return true;
    });

    if (autoClearEnabled && skippedItems.length > 0) {
      skippedItems.forEach(function (it) {
        removeFeedCardOnSuccess(it.id);
      });
    }

    if (selectedItems.length === 0) {
      setBusy(false);
      var allSkippedMsg = skippedDuplicates > 0
        ? (skippedDuplicates + ' doublon(s) déjà téléchargé(s) ignoré(s)' + (autoClearEnabled ? ' et retiré(s).' : '.'))
        : t('xFeedNoSelection', 'Select at least one video.');
      setStatus(allSkippedMsg, 'success');
      return;
    }

    setBusy(true);
    var completed = 0;
    var failed = 0;

    function sendNext(index) {
      if (index >= selectedItems.length) return Promise.resolve();
      var item = selectedItems[index];
      var downloadUrl = downloadUrlForFeedItem(item);
      if (!downloadUrl) {
        failed++;
        return sendNext(index + 1);
      }
      var isTiktok = item.platform === 'tiktok';
      return sendRuntimeMessage({
        type: 'DOWNLOAD_BTN_CLICK',
        url: downloadUrl,
        pageUrl: item.pageUrl,
        options: {
          noWatermark: isTiktok ? true : undefined,
        },
        thumbnailUrl: item.thumbnailUrl || null,
        tweetId: item.platform === 'x' ? (String(item.id || '').split('-')[0] || null) : null,
        tikTokId: isTiktok ? String(item.id || '').replace(/^tt-/, '') : null,
      }).then(function (result) {
        if (result && result.ok) {
          completed++;
          var card = feedList.querySelector('.feed-card[data-feed-id="' + item.id + '"]');
          if (card) {
            var btn = card.querySelector('.card-single-dl-btn');
            if (btn) btn.classList.add('downloading');
            var pWrap = card.querySelector('.card-progress-bar-wrap');
            if (pWrap) pWrap.style.display = 'block';
          }
        } else {
          failed++;
        }
      }).catch(function () {
        failed++;
      }).then(function () {
        return sendNext(index + 1);
      });
    }

    setStatus(
      replaceCount(
        t('xFeedSending', 'Sending {count} videos to Modern Downloader…'),
        selectedItems.length,
      ),
    );
    sendNext(0).then(function () {
      var resultMessage = replaceCount(
        t('xFeedSent', '{count} videos sent'),
        completed,
      );
      if (skippedDuplicates > 0) {
        resultMessage += ' — ' + skippedDuplicates + ' doublon(s) ignoré(s)';
        if (autoClearEnabled) resultMessage += ' et retiré(s)';
      }
      if (failed > 0) {
        resultMessage += ' — ' + replaceCount(
          t('xFeedFailed', '{count} failed'),
          failed,
        );
      }
      setStatus(resultMessage, failed > 0 ? 'error' : 'success');
    }).catch(function () {
      setStatus(t('xFeedSendFailed', 'Could not send selected videos.'), 'error');
    }).finally(function () {
      setBusy(false);
    });
  }

  analyzeButton.addEventListener('click', analyzeLoadedFeed);
  openXButton.addEventListener('click', openXPage);
  selectAllButton.addEventListener('click', function () {
    if (busy) return;
    if (currentViewMode === 'creators') {
      var creators = getDetectedCreators();
      creators.forEach(function (c) {
        selectedCreatorHandles.add(c.handle);
      });
      syncCreatorsSelection();
    } else {
      selectFirstDisplayed(visibleCount());
    }
  });
  clearSelectionButton.addEventListener('click', function () {
    if (busy) return;
    if (currentViewMode === 'creators') {
      selectedCreatorHandles.clear();
      if (selectCountInput) selectCountInput.value = '';
      syncCreatorsSelection();
    } else {
      selectedIds.clear();
      if (selectCountInput) selectCountInput.value = '';
      syncCardSelection();
    }
  });
  function syncPresetPills() {
    document.querySelectorAll('.preset-pill').forEach(function (pill) {
      var cap = parseInt(pill.getAttribute('data-capacity'), 10);
      pill.classList.toggle('active', cap === displayLimit);
    });
  }

  if (displaySlider) {
    displaySlider.addEventListener('input', function () {
      var next = parseInt(displaySlider.value, 10);
      if (!Number.isFinite(next) || next < 1) next = 1;
      displayLimit = Math.min(next, 1000);
      if (displayLimitValue) {
        displayLimitValue.textContent = displayLimit === 1 ? '1 (Actif)' : String(displayLimit);
      }
      syncPresetPills();
      if (displayLimit === 1 && feedItems.length > 1) {
        var active = feedItems.find(function (it) { return it.isActive; }) || feedItems[0];
        feedItems = active ? [active] : [];
        selectedIds.clear();
      } else if (feedItems.length > displayLimit) {
        feedItems = feedItems.slice(0, displayLimit);
      }
      renderItems();
      if (scanInfo && feedItems.length > 0) {
        var foundMessage = replaceCount(
          t('xFeedFound', '{count} video posts found'),
          feedItems.length,
        );
        var shown = visibleCount();
        var showingHint = shown < feedItems.length
          ? ' · ' + replaceCount(t('xFeedShowing', 'showing {count}'), shown)
          : '';
        scanInfo.textContent = foundMessage + showingHint;
      }
    });
  }

  document.querySelectorAll('.preset-pill').forEach(function (pill) {
    pill.addEventListener('click', function () {
      var cap = parseInt(pill.getAttribute('data-capacity'), 10);
      if (!Number.isFinite(cap) || cap < 1) cap = 1;
      if (displaySlider) {
        displaySlider.value = cap;
        displaySlider.dispatchEvent(new Event('input'));
      }
    });
  });
  if (selectCountInput) {
    selectCountInput.placeholder = t('xFeedSelectCountPlaceholder', 'Number');
    selectCountInput.setAttribute(
      'aria-label',
      t('xFeedSelectCountLabel', 'Select'),
    );
    selectCountInput.addEventListener('keydown', function (event) {
      if (
        event.key === '.' ||
        event.key === ',' ||
        event.key === '+' ||
        event.key === '-' ||
        event.key === 'e' ||
        event.key === 'E'
      ) {
        event.preventDefault();
        return;
      }
      if (event.key === 'Enter') {
        event.preventDefault();
        applySelectCountFromInput();
      }
    });
    selectCountInput.addEventListener('input', function () {
      var digits = digitsOnlyValue(selectCountInput.value);
      if (selectCountInput.value !== digits) {
        selectCountInput.value = digits;
      }
    });
    selectCountInput.addEventListener('change', applySelectCountFromInput);
    selectCountInput.addEventListener('blur', applySelectCountFromInput);
  }
  downloadSelectedButton.addEventListener('click', downloadSelected);

  if (api.runtime && api.runtime.onMessage) {
    api.runtime.onMessage.addListener(handleLiveFeedUpdate);
  }

  document.querySelectorAll('.platform-pill').forEach(function (pill) {
    pill.addEventListener('click', function () {
      selectPlatformFilter(pill.getAttribute('data-filter') || 'all');
    });
  });

  if (viewModeVideosBtn) {
    viewModeVideosBtn.addEventListener('click', function () {
      setViewMode('videos');
    });
  }
  if (viewModeCreatorsBtn) {
    viewModeCreatorsBtn.addEventListener('click', function () {
      setViewMode('creators');
    });
  }

  if (recoverAccountsBtn) {
    recoverAccountsBtn.addEventListener('click', openRecoverAccountsModal);
  }
  if (recoverAccountsClose) {
    recoverAccountsClose.addEventListener('click', closeRecoverAccountsModal);
  }
  if (recoverAccountsBackdrop) {
    recoverAccountsBackdrop.addEventListener('click', closeRecoverAccountsModal);
  }

  if (recoverSendAppAction) {
    recoverSendAppAction.addEventListener('click', function () {
      closeRecoverAccountsModal();
      var creators = getDetectedCreators();
      creators.forEach(function (c) {
        selectedCreatorHandles.add(c.handle);
      });
      setViewMode('creators');
      downloadSelectedCreators();
    });
  }

  if (recoverSwitchViewAction) {
    recoverSwitchViewAction.addEventListener('click', function () {
      closeRecoverAccountsModal();
      setViewMode('creators');
    });
  }

  if (recoverCopyUrlsAction) {
    recoverCopyUrlsAction.addEventListener('click', function () {
      closeRecoverAccountsModal();
      copyCreatorUrls();
    });
  }

  if (recoverExportTxtAction) {
    recoverExportTxtAction.addEventListener('click', function () {
      closeRecoverAccountsModal();
      exportCreatorUrls();
    });
  }

  if (copyCreatorsBtn) {
    copyCreatorsBtn.addEventListener('click', function () {
      copyCreatorUrls();
    });
  }

  if (exportCreatorsBtn) {
    exportCreatorsBtn.addEventListener('click', function () {
      exportCreatorUrls();
    });
  }

  closeCreatorModal();
  closeRecoverAccountsModal();
  stopDeepScan();
  applyI18n();
  setSource('dom');
  syncPresetPills();
  renderItems();
  // gobird only runs on Analyze. Request it as soon as the panel opens so
  // the badge is not stuck on "local" while the user only scrolls.
  setTimeout(analyzeLoadedFeed, 400);
})();
