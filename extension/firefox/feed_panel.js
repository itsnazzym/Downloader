(function () {
  'use strict';

  var api = typeof MD_API !== 'undefined'
    ? MD_API
    : (typeof browser !== 'undefined' ? browser : chrome);
  var MAX_ITEMS = 500;
  var feedItems = [];
  var selectedIds = new Set();
  var busy = false;

  var analyzeButton = document.getElementById('analyze-btn');
  var openXButton = document.getElementById('open-x-btn');
  var selectAllButton = document.getElementById('select-all-btn');
  var clearSelectionButton = document.getElementById('clear-selection-btn');
  var downloadSelectedButton = document.getElementById('download-selected-btn');
  var selectionCount = document.getElementById('selection-count');
  var scanInfo = document.getElementById('scan-info');
  var feedStatus = document.getElementById('feed-status');
  var feedList = document.getElementById('feed-list');
  var sourcePill = document.getElementById('source-pill');
  var activeSource = 'dom';
  var gobirdFallbackActive = false;
  var gobirdFallbackErrorCode = '';
  var gobirdFallbackError = '';

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

  function normalizedMediaUrl(value) {
    try {
      var url = new URL(value);
      if (
        (url.protocol !== 'http:' && url.protocol !== 'https:') ||
        !url.hostname ||
        !isXHost(url.hostname)
      ) {
        return null;
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

  function setSource(source, options) {
    var opts = options || {};
    activeSource = source === 'gobird' ? 'gobird' : 'dom';
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
      return t('xFeedDurationUnknown', 'Duration unavailable');
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
      return t('xFeedResolutionUnknown', 'Resolution unavailable');
    }
    return item.width + '×' + item.height;
  }

  function formatSize(item) {
    if (!Number.isFinite(item.sizeBytes) || item.sizeBytes <= 0) {
      return t('xFeedSizeUnknown', 'Size checked by app');
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

  function createThumbnail(item) {
    if (isSafeHttpUrl(item.thumbnailUrl)) {
      var image = document.createElement('img');
      image.className = 'thumbnail';
      image.loading = 'lazy';
      image.alt = item.title || t('xFeedVideoAlt', 'Video thumbnail');
      image.src = item.thumbnailUrl;
      image.addEventListener('error', function () {
        var placeholder = document.createElement('div');
        placeholder.className = 'thumbnail thumbnail-placeholder';
        placeholder.textContent = t('xFeedVideo', 'Video');
        image.replaceWith(placeholder);
      });
      return image;
    }

    var emptyThumbnail = document.createElement('div');
    emptyThumbnail.className = 'thumbnail thumbnail-placeholder';
    emptyThumbnail.textContent = t('xFeedVideo', 'Video');
    return emptyThumbnail;
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
        title: String(item.title || t('xFeedVideo', 'X video')),
        author: String(item.author || t('xFeedAuthorUnknown', 'X user')),
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
    return normalized;
  }

  function mergeItems(items) {
    var normalized = normalizeItems(items);
    var indexes = {};
    feedItems.forEach(function (item, index) {
      indexes[item.id] = index;
    });

    var added = 0;
    normalized.forEach(function (item) {
      var existingIndex = indexes[item.id];
      if (existingIndex === undefined) {
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
        thumbnailUrl: existing.thumbnailUrl || item.thumbnailUrl,
        durationSeconds: existing.durationSeconds || item.durationSeconds,
        width: existing.width || item.width,
        height: existing.height || item.height,
        sizeBytes: existing.sizeBytes || item.sizeBytes,
        source: preferIncoming ? item.source : existing.source,
      };
    });
    return added;
  }

  function updateFeedCountStatus() {
    var foundMessage = replaceCount(
      t('xFeedFound', '{count} video posts found'),
      feedItems.length,
    );
    scanInfo.textContent = foundMessage + ' · ' +
      t('xFeedLive', 'live collection');
    setStatus(
      feedItems.length > 0
        ? foundMessage
        : t('xFeedNoItems', 'No loaded video posts found.'),
      feedItems.length > 0 ? 'success' : '',
    );
  }

  function updateSelectionUi() {
    var count = selectedIds.size;
    selectionCount.textContent = replaceCount(
      t('xFeedSelection', '{count} selected'),
      count,
    );
    downloadSelectedButton.disabled = busy || count === 0;
    selectAllButton.disabled = busy || feedItems.length === 0;
    clearSelectionButton.disabled = busy || count === 0;
  }

  function createFeedCard(item) {
    var card = document.createElement('article');
    card.className = 'feed-card' + (selectedIds.has(item.id) ? ' selected' : '');
    card.dataset.feedId = item.id;

    var checkbox = document.createElement('input');
    checkbox.className = 'feed-checkbox';
    checkbox.type = 'checkbox';
    checkbox.checked = selectedIds.has(item.id);
    checkbox.setAttribute('aria-label', item.title);
    checkbox.addEventListener('change', function () {
      if (checkbox.checked) selectedIds.add(item.id);
      else selectedIds.delete(item.id);
      card.classList.toggle('selected', checkbox.checked);
      updateSelectionUi();
    });

    var body = document.createElement('div');
    body.className = 'card-body';

    var author = document.createElement('div');
    author.className = 'card-author';
    author.textContent = item.author;

    var title = document.createElement('div');
    title.className = 'card-title';
    title.title = item.title;
    title.textContent = item.title;

    var metadata = document.createElement('div');
    metadata.className = 'card-meta';
    [formatDuration(item.durationSeconds), formatResolution(item), formatSize(item)]
      .forEach(function (value) {
        var detail = document.createElement('span');
        detail.textContent = value;
        metadata.appendChild(detail);
      });

    body.appendChild(author);
    body.appendChild(title);
    body.appendChild(metadata);
    card.appendChild(checkbox);
    card.appendChild(createThumbnail(item));
    card.appendChild(body);
    return card;
  }

  function renderItems() {
    var empty = feedList.querySelector('.empty-state');
    if (feedItems.length === 0) {
      if (!empty) {
        empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.textContent = t('xFeedNoItems', 'No loaded video posts found.');
        feedList.appendChild(empty);
      }
      updateSelectionUi();
      return;
    }

    if (empty) empty.remove();
    var renderedIds = {};
    feedList.querySelectorAll('.feed-card').forEach(function (card) {
      renderedIds[card.dataset.feedId] = true;
    });
    feedItems.forEach(function (item) {
      if (renderedIds[item.id]) return;
      feedList.appendChild(createFeedCard(item));
    });
    updateSelectionUi();
  }

  function analyzeLoadedFeed() {
    setBusy(true);
    scanInfo.textContent = '';
    setStatus(t('xFeedAnalyzing', 'Analyzing loaded X posts…'));

    sendRuntimeMessage({
      type: 'ANALYZE_X_FEED',
      maxItems: MAX_ITEMS,
    }).then(function (result) {
      if (!result || !result.ok) {
        if (feedItems.length === 0) renderItems();
        if (result && result.error === 'not_x_page') {
          setStatus(t('xFeedNotXPage', 'Open X.com in the active tab first.'), 'error');
        } else {
          setStatus(
            t('xFeedAnalyzeFailed', 'Could not analyze the loaded X feed.'),
            'error',
          );
        }
        return;
      }

      mergeItems(result.items);
      renderItems();
      var usedGobird = result.source === 'gobird';
      var fellBackFromGobird = !usedGobird && result.fallbackFrom === 'gobird';
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
        ? t('xFeedGobirdSource', 'gobird experimental')
        : (fellBackFromGobird
          ? t('xFeedFallbackSource', 'Local fallback (gobird failed)')
          : t('xFeedLocalSource', 'For You — local'));
      scanInfo.textContent = foundMessage + ' · ' + sourceHint + ' · ' +
        t('xFeedLive', 'live collection');
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
        t('xFeedAnalyzeFailed', 'Could not analyze the loaded X feed.'),
        'error',
      );
    }).finally(function () {
      setBusy(false);
    });
  }

  function handleLiveFeedUpdate(message) {
    if (!message || message.type !== 'MD_X_FEED_UPDATE') return;
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
    try {
      if (!api.tabs || !api.tabs.create) {
        setStatus(t('xFeedOpenFailed', 'Could not open X.com.'), 'error');
        return;
      }
      api.tabs.create({ url: 'https://x.com/home' }).catch(function () {
        setStatus(t('xFeedOpenFailed', 'Could not open X.com.'), 'error');
      });
    } catch (e) {
      setStatus(t('xFeedOpenFailed', 'Could not open X.com.'), 'error');
    }
  }

  function downloadSelected() {
    var selectedItems = feedItems.filter(function (item) {
      return selectedIds.has(item.id);
    });
    if (selectedItems.length === 0) {
      setStatus(t('xFeedNoSelection', 'Select at least one video.'), 'error');
      return;
    }

    var mediaKeys = new Set();
    var skippedDuplicates = 0;
    selectedItems = selectedItems.filter(function (item) {
      var key = normalizedMediaUrl(item.url);
      if (key && mediaKeys.has(key)) {
        skippedDuplicates++;
        return false;
      }
      if (key) mediaKeys.add(key);
      return true;
    });

    setBusy(true);
    var completed = 0;
    var failed = 0;

    function sendNext(index) {
      if (index >= selectedItems.length) return Promise.resolve();
      var item = selectedItems[index];
      return sendRuntimeMessage({
        type: 'DOWNLOAD_BTN_CLICK',
        url: item.url,
        pageUrl: item.pageUrl,
        options: {},
      }).then(function (result) {
        if (result && result.ok) completed++;
        else failed++;
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
      if (failed > 0) {
        resultMessage += ' — ' + replaceCount(
          t('xFeedFailed', '{count} failed'),
          failed,
        );
      }
      if (skippedDuplicates > 0) {
        resultMessage += ' — ' + replaceCount(
          t('xFeedDuplicatesSkipped', '{count} duplicates skipped'),
          skippedDuplicates,
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
    feedItems.forEach(function (item) {
      selectedIds.add(item.id);
    });
    renderItems();
  });
  clearSelectionButton.addEventListener('click', function () {
    if (busy) return;
    selectedIds.clear();
    renderItems();
  });
  downloadSelectedButton.addEventListener('click', downloadSelected);

  if (api.runtime && api.runtime.onMessage) {
    api.runtime.onMessage.addListener(handleLiveFeedUpdate);
  }

  applyI18n();
  setSource('dom');
  renderItems();
  // gobird only runs on Analyze. Request it as soon as the panel opens so
  // the badge is not stuck on "local" while the user only scrolls.
  setTimeout(analyzeLoadedFeed, 400);
})();
