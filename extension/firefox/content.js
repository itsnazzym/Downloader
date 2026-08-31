/**
 * Modern Downloader content script — limited to video platform pages.
 * Debounced MutationObserver (no 1s interval). Overlay via Shadow DOM.
 */
(function () {
  'use strict';

  if (window.__MD_CONTENT_LOADED__) return;
  window.__MD_CONTENT_LOADED__ = true;

  var api = typeof browser !== 'undefined' ? browser : chrome;
  var PROCESSED = new WeakSet();
  var scanScheduled = false;
  var scanTimer = null;
  var injectedButtons = [];
  var downloadedTweetIds = Object.create(null);
  var downloadedMediaIds = Object.create(null);

  var VIDEO_PATTERNS = [
    '/watch?v=',
    '/reels/',
    '/reel/',
    '/status/',
    'tiktok.com',
    'instagram.com/p/',
    'instagram.com/reel',
    'youtube.com/watch',
    'youtu.be/',
    'twitch.tv/',
    'kick.com',
    'facebook.com/watch',
    'fb.watch/',
  ];

  var SETTINGS = {
    btnColor: '#6C5DD3',
    btnPosition: 'top-right',
    btnSize: 'normal',
    showQualitySelector: true,
  };

  function loadSettings() {
    var area = (api.storage && api.storage.local) || api.storage.sync;
    if (!area) return;
    area.get(
      [
        'btnColor',
        'btnPosition',
        'btnSize',
        'showQualitySelector',
        'downloadedKeys',
      ],
      function (items) {
        if (api.runtime.lastError) return;
        if (items.btnColor) SETTINGS.btnColor = items.btnColor;
        if (items.btnPosition) SETTINGS.btnPosition = items.btnPosition;
        if (items.btnSize) SETTINGS.btnSize = items.btnSize;
        if (typeof items.showQualitySelector === 'boolean') {
          SETTINGS.showQualitySelector = items.showQualitySelector;
        }
        applyStoredKeys(items.downloadedKeys);
        refreshInjectedButtons();
      },
    );
  }
  loadSettings();
  if (api.storage && api.storage.onChanged) {
    api.storage.onChanged.addListener(function (changes, areaName) {
      if (areaName !== 'local' && areaName !== 'sync') return;
      if (changes.btnColor) SETTINGS.btnColor = changes.btnColor.newValue;
      if (changes.btnPosition) SETTINGS.btnPosition = changes.btnPosition.newValue;
      if (changes.btnSize) SETTINGS.btnSize = changes.btnSize.newValue;
      if (changes.showQualitySelector) {
        SETTINGS.showQualitySelector = changes.showQualitySelector.newValue;
      }
      if (changes.downloadedKeys) {
        applyStoredKeys(changes.downloadedKeys.newValue);
        refreshInjectedButtons();
      }
    });
  }

  var X_FEED_MAX_ITEMS = 500;
  var X_FEED_CACHE_LIMIT = 10000;
  var X_FEED_EMITTED_IDS = {};
  var X_FEED_CACHE = [];
  var X_FEED_CACHE_INDEX = Object.create(null);
  var xFeedUpdateTimer = null;

  function isXPage() {
    var hostname = String(window.location.hostname || '').toLowerCase();
    return hostname === 'x.com' ||
      hostname.endsWith('.x.com') ||
      hostname === 'twitter.com' ||
      hostname.endsWith('.twitter.com');
  }

  function cleanText(value) {
    return String(value || '').replace(/\s+/g, ' ').trim();
  }

  function safeHttpUrl(value) {
    if (!value) return null;
    try {
      var url = new URL(value, window.location.href);
      if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
      return url.href;
    } catch (e) {
      return null;
    }
  }

  function parseXStatusLink(href) {
    try {
      var url = new URL(href, window.location.href);
      var hostname = url.hostname.toLowerCase();
      if (
        hostname !== 'x.com' &&
        !hostname.endsWith('.x.com') &&
        hostname !== 'twitter.com' &&
        !hostname.endsWith('.twitter.com')
      ) {
        return null;
      }
      var match = url.pathname.match(
        /^\/(?:[^/]+\/status|i\/(?:web\/)?status)\/(\d+)/,
      );
      if (!match) return null;
      url.search = '';
      url.hash = '';
      return { id: match[1], url: url.href };
    } catch (e) {
      return null;
    }
  }

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

  function downloadLabel() {
    return t('download', 'Download');
  }

  function downloadedLabel() {
    return t('downloaded', 'Downloaded');
  }

  function xTweetIdFromUrl(value) {
    var parsed = parseXStatusLink(value);
    return parsed ? parsed.id : null;
  }

  function xMediaAssetId(value) {
    if (!value) return null;
    var match = String(value).match(
      /\/(?:ext_tw_video(?:_thumb)?|amplify_video(?:_thumb)?|tweet_video(?:_thumb)?)\/(\d{15,20})(?:\/|\.|$)/i,
    );
    return match ? match[1] : null;
  }

  function applyStoredKeys(keys) {
    downloadedTweetIds = Object.create(null);
    downloadedMediaIds = Object.create(null);
    if (!keys || typeof keys !== 'object') return;
    (keys.tweetIds || []).forEach(function (id) {
      if (id) downloadedTweetIds[String(id)] = true;
    });
    (keys.mediaIds || []).forEach(function (id) {
      if (id) downloadedMediaIds[String(id)] = true;
    });
  }

  function mergeLocalKeys(tweetIds, mediaIds, removedTweetIds) {
    (tweetIds || []).forEach(function (id) {
      if (id) downloadedTweetIds[String(id)] = true;
    });
    (mediaIds || []).forEach(function (id) {
      if (id) downloadedMediaIds[String(id)] = true;
    });
    (removedTweetIds || []).forEach(function (id) {
      if (id) delete downloadedTweetIds[String(id)];
    });
  }

  function isKnownDownloaded(tweetId, mediaId) {
    return (!!tweetId && !!downloadedTweetIds[tweetId]) ||
      (!!mediaId && !!downloadedMediaIds[mediaId]);
  }

  function findMediaAssetIdNear(container) {
    if (!container) return null;
    var video = container.tagName === 'VIDEO'
      ? container
      : container.querySelector('video');
    if (video) {
      var fromPoster = xMediaAssetId(video.poster);
      if (fromPoster) return fromPoster;
      var fromSrc = xMediaAssetId(video.currentSrc || video.src);
      if (fromSrc) return fromSrc;
    }
    var article = findXArticle(container);
    if (!article) return null;
    return xMediaAssetId(findXPreviewUrl(article, video));
  }

  function refreshInjectedButtons() {
    injectedButtons = injectedButtons.filter(function (entry) {
      return entry.host && entry.host.isConnected;
    });
    injectedButtons.forEach(function (entry) {
      if (isKnownDownloaded(entry.tweetId, entry.mediaId)) {
        entry.setDownloaded();
      } else {
        entry.setIdle();
      }
    });
  }

  function findXArticle(element) {
    if (!element) return null;
    if (element.closest) {
      var closestArticle = element.closest(
        'article[data-testid="tweet"], article',
      );
      if (closestArticle) return closestArticle;
    }
    var curr = element.parentElement;
    var depth = 0;
    while (curr && depth < 12) {
      var testId = curr.getAttribute && curr.getAttribute('data-testid');
      if (curr.tagName === 'ARTICLE' || testId === 'tweet') return curr;
      curr = curr.parentElement;
      depth++;
    }
    return null;
  }

  function findXPostLink(article) {
    if (!article) return null;
    var timeEl = article.querySelector('time');
    if (timeEl) {
      var timeAnchor = timeEl.closest ? timeEl.closest('a[href]') : null;
      if (timeAnchor) {
        var fromTime = parseXStatusLink(timeAnchor.href);
        if (fromTime) return fromTime;
      }
    }
    var links = article.querySelectorAll('a[href]');
    for (var i = 0; i < links.length; i++) {
      var parsed = parseXStatusLink(links[i].href);
      if (parsed) return parsed;
    }
    return null;
  }

  function statusPermalinkFromPage() {
    try {
      var loc = new URL(window.location.href);
      var statusMatch = loc.pathname.match(
        /^\/(?:[^/]+\/status|i\/(?:web\/)?status)\/(\d+)/,
      );
      if (!statusMatch) return null;
      loc.search = '';
      loc.hash = '';
      return loc.href;
    } catch (e) {
      return null;
    }
  }

  function resolveXPermalinkFromElement(element, srcUrl) {
    var article = findXArticle(element);
    var post = findXPostLinkNear(element) || findXPostLink(article);
    if (post && post.url) return post.url;
    if (srcUrl) {
      var videos = document.querySelectorAll('video');
      for (var i = 0; i < videos.length; i++) {
        var src = videos[i].currentSrc || videos[i].src || '';
        if (!src) continue;
        try {
          var left = new URL(src, window.location.href);
          var right = new URL(srcUrl, window.location.href);
          left.search = '';
          right.search = '';
          if (left.href !== right.href) continue;
        } catch (e) {
          continue;
        }
        var fromVideo = findXPostLink(findXArticle(videos[i]));
        if (fromVideo && fromVideo.url) return fromVideo.url;
      }
    }
    return statusPermalinkFromPage();
  }

  function findXPostLinkNear(element) {
    var curr = element;
    var depth = 0;
    while (curr && depth < 20) {
      if (curr.tagName === 'A') {
        var fromSelf = parseXStatusLink(curr.href);
        if (fromSelf) return fromSelf;
      }
      var role = curr.getAttribute && curr.getAttribute('role');
      if (role === 'link' && curr.querySelector) {
        var quoteLinks = curr.querySelectorAll('a[href]');
        for (var q = 0; q < quoteLinks.length; q++) {
          var fromQuote = parseXStatusLink(quoteLinks[q].href);
          if (fromQuote) return fromQuote;
        }
      }
      curr = curr.parentElement;
      depth++;
    }
    return findXPostLink(findXArticle(element));
  }

  function findXVideoElements(article) {
    var videos = article.querySelectorAll('video');
    if (videos.length > 0) return Array.prototype.slice.call(videos);
    var player = article.querySelector('[data-testid="videoPlayer"]');
    if (!player) return [];
    var preview = findXPreviewUrl(article, null);
    if (
      preview &&
      (xMediaAssetId(preview) || preview.indexOf('video.twimg.com') !== -1)
    ) {
      return [player];
    }
    return [];
  }

  function findXPreviewUrl(article, videoElement) {
    if (videoElement && videoElement.poster) {
      var poster = safeHttpUrl(videoElement.poster);
      if (poster) return poster;
    }

    var playerImage = article.querySelector(
      '[data-testid="videoPlayer"] img[src], [data-testid="videoPlayer"] img[currentSrc]',
    );
    if (playerImage) {
      var playerSource = safeHttpUrl(playerImage.currentSrc || playerImage.src);
      if (playerSource) return playerSource;
    }

    var mediaImages = article.querySelectorAll(
      'img[src*="pbs.twimg.com"], img[src*="video.twimg.com"]',
    );
    for (var i = 0; i < mediaImages.length; i++) {
      var mediaSource = safeHttpUrl(mediaImages[i].currentSrc || mediaImages[i].src);
      if (mediaSource) return mediaSource;
    }

    return null;
  }

  function findXAuthor(article) {
    var authorElement = article.querySelector('[data-testid="User-Name"]');
    var author = cleanText(authorElement && authorElement.textContent);
    if (author) return author;

    var links = article.querySelectorAll('a[href^="/"]');
    for (var i = 0; i < links.length; i++) {
      var label = cleanText(links[i].textContent);
      if (label && label.charAt(0) === '@') return label;
    }
    return '';
  }

  function readXVideoDetails(videoElement) {
    var details = {
      durationSeconds: null,
      width: null,
      height: null,
    };
    if (!videoElement || videoElement.tagName !== 'VIDEO') return details;

    if (Number.isFinite(videoElement.duration) && videoElement.duration > 0) {
      details.durationSeconds = Math.round(videoElement.duration);
    }
    if (videoElement.videoWidth > 0) details.width = videoElement.videoWidth;
    if (videoElement.videoHeight > 0) details.height = videoElement.videoHeight;
    return details;
  }

  function extractXFeed(maxItems) {
    if (!isXPage()) return { ok: false, error: 'not_x_page' };

    var limit = parseInt(maxItems, 10);
    if (!Number.isFinite(limit) || limit < 1) limit = X_FEED_MAX_ITEMS;
    limit = Math.min(limit, X_FEED_MAX_ITEMS);

    var articles = document.querySelectorAll('article[data-testid="tweet"], article');
    var items = [];
    var seenIds = {};
    var videoPostsFound = 0;

    articles.forEach(function (article) {
      var videoElements = findXVideoElements(article);
      if (videoElements.length === 0) return;

      videoElements.forEach(function (videoElement, videoIndex) {
        var post = findXPostLinkNear(videoElement) || findXPostLink(article);
        if (!post) return;

        videoPostsFound++;
        if (items.length >= limit) return;
        var itemId = videoIndex === 0
          ? post.id
          : post.id + '-video-' + videoIndex;
        if (seenIds[itemId]) return;
        seenIds[itemId] = true;

        var author = findXAuthor(article);
        var textElement = article.querySelector('[data-testid="tweetText"]');
        var title = cleanText(textElement && textElement.textContent);
        if (!title) title = author ? 'X video — ' + author : 'X video';

        var details = readXVideoDetails(videoElement);
        items.push({
          id: itemId,
          url: post.url,
          pageUrl: window.location.href,
          title: title,
          author: author || 'X user',
          thumbnailUrl: findXPreviewUrl(article, videoElement),
          durationSeconds: details.durationSeconds,
          width: details.width,
          height: details.height,
          sizeBytes: null,
          source: 'dom',
          sourceLabel: 'For You — local',
        });
      });
    });

    return {
      ok: true,
      source: 'dom',
      mode: 'local-for-you',
      pageUrl: window.location.href,
      scannedArticles: articles.length,
      truncated: videoPostsFound > limit,
      items: items,
    };
  }

  function rememberXFeedItems(items) {
    if (!Array.isArray(items)) return;
    items.forEach(function (item) {
      var id = String(item && item.id || '');
      if (!id) return;
      if (X_FEED_CACHE_INDEX[id] === undefined) {
        X_FEED_CACHE.push(id);
      }
      X_FEED_CACHE_INDEX[id] = item;
    });

    while (X_FEED_CACHE.length > X_FEED_CACHE_LIMIT) {
      var removed = X_FEED_CACHE.shift();
      var removedId = String(removed || '');
      if (removedId) delete X_FEED_CACHE_INDEX[removedId];
    }
  }

  function publishNewXFeedItems() {
    xFeedUpdateTimer = null;
    if (!isXPage()) return;

    var result = extractXFeed(X_FEED_MAX_ITEMS);
    if (!result || result.ok !== true || !Array.isArray(result.items)) return;
    rememberXFeedItems(result.items);

    var newItems = [];
    result.items.forEach(function (item) {
      var id = String(item && item.id || '');
      if (!id || X_FEED_EMITTED_IDS[id]) return;
      newItems.push(item);
    });
    if (newItems.length === 0) return;

    try {
      var pending = api.runtime.sendMessage({
        type: 'MD_X_FEED_ITEMS',
        items: newItems,
        pageUrl: window.location.href,
      });
      var markAsEmitted = function () {
        newItems.forEach(function (item) {
          var id = String(item && item.id || '');
          if (id) X_FEED_EMITTED_IDS[id] = true;
        });
      };
      if (pending && typeof pending.then === 'function') {
        pending.then(markAsEmitted).catch(function () {
          /* The panel may not be open yet. */
        });
      } else {
        markAsEmitted();
      }
    } catch (e) {
      /* The extension context may be shutting down during navigation. */
    }
  }

  function scheduleXFeedUpdate() {
    if (!isXPage() || xFeedUpdateTimer) return;
    xFeedUpdateTimer = setTimeout(publishNewXFeedItems, 180);
  }

  function findPlatformSpecificUrl(element) {
    var pageUrl = window.location.href;
    var hostname = window.location.hostname || '';
    if (isXPage()) {
      var permalink = resolveXPermalinkFromElement(element);
      if (permalink) return permalink;
      return null;
    }
    if (hostname.indexOf('kick.com') !== -1) {
      return pageUrl.split('?')[0];
    }

    function findNearestPermalink(el) {
      if (el.tagName === 'A' && el.href && VIDEO_PATTERNS.some(function (p) { return el.href.indexOf(p) !== -1; })) {
        return el.href;
      }
      var curr = el.parentElement;
      var depth = 0;
      while (curr && depth < 10) {
        if (
          curr.tagName === 'A' &&
          curr.href &&
          VIDEO_PATTERNS.some(function (p) { return curr.href.indexOf(p) !== -1; }) &&
          curr.href.indexOf('preview') === -1
        ) {
          return curr.href;
        }
        depth++;
        curr = curr.parentElement;
      }
      return null;
    }

    function findLinkInContainer(el) {
      var container = el.closest(
        'article, .user-post, [data-testid="tweet"], .feed-shared-update-v2, ytd-rich-item-renderer, ytd-video-renderer',
      );
      if (!container) return null;
      var twitterLink = container.querySelector('a[href*="/status/"]');
      if (twitterLink) return twitterLink.href;
      var link = container.querySelector(
        'a[href*="/watch?v="], a[href*="/reel/"], a[href*="/reels/"]',
      );
      if (link) return link.href;
      return null;
    }

    if (element.tagName === 'VIDEO') {
      var deepLink = findNearestPermalink(element);
      if (deepLink) return deepLink;
      deepLink = findLinkInContainer(element);
      if (deepLink) return deepLink;
      var mediaUrl = element.currentSrc || element.src;
      if (mediaUrl && mediaUrl.indexOf('blob:') !== 0 && mediaUrl.indexOf('preview') === -1) {
        return mediaUrl;
      }
    } else if (element.tagName === 'A') {
      return element.href;
    }

    if (VIDEO_PATTERNS.some(function (p) { return pageUrl.indexOf(p) !== -1; })) {
      return pageUrl;
    }
    return null;
  }

  function sendDownload(targetUrl, opts, extra, onResult) {
    try {
      api.runtime.sendMessage(
        {
          type: 'DOWNLOAD_BTN_CLICK',
          url: targetUrl,
          pageUrl: window.location.href,
          options: opts || {},
          tweetId: extra && extra.tweetId ? extra.tweetId : null,
          mediaId: extra && extra.mediaId ? extra.mediaId : null,
        },
        function (response) {
          if (api.runtime.lastError) {
            onResult({ ok: false, error: 'app_offline' });
            return;
          }
          onResult(response || { ok: false, error: 'no_response' });
        },
      );
    } catch (e) {
      onResult({ ok: false, error: 'send_failed' });
    }
  }

  function createButtonUI(targetUrl, tweetId, mediaId) {
    var host = document.createElement('div');
    host.className = 'md-dl-host';
    if (tweetId) host.dataset.tweetId = tweetId;
    if (mediaId) host.dataset.mediaId = mediaId;
    Object.assign(host.style, {
      position: 'absolute',
      zIndex: '2147483647',
      pointerEvents: 'none',
    });
    var offset = '8px';
    if (SETTINGS.btnPosition === 'top-right') {
      host.style.top = offset;
      host.style.right = offset;
    } else if (SETTINGS.btnPosition === 'top-left') {
      host.style.top = offset;
      host.style.left = offset;
    } else if (SETTINGS.btnPosition === 'bottom-right') {
      host.style.bottom = offset;
      host.style.right = offset;
    } else {
      host.style.bottom = offset;
      host.style.left = offset;
    }

    var shadow = host.attachShadow({ mode: 'closed' });
    var style = document.createElement('style');
    style.textContent =
      ':host{all:initial}' +
      '.wrap{display:flex;align-items:center;gap:0;pointer-events:auto;font-family:Segoe UI,Helvetica,sans-serif}' +
      'button{border:none;color:#fff;cursor:pointer;font-weight:600;display:inline-flex;align-items:center;gap:6px}' +
      'button:disabled{cursor:default}' +
      '.main{background:' + SETTINGS.btnColor + ';border-radius:6px 0 0 6px;padding:6px 12px;font-size:13px}' +
      '.main.solo{border-radius:6px}' +
      '.toggle{background:' + SETTINGS.btnColor + ';filter:brightness(0.9);border-radius:0 6px 6px 0;padding:6px 8px;border-left:1px solid rgba(255,255,255,.2)}' +
      '.menu{position:absolute;top:100%;right:0;display:none;flex-direction:column;min-width:120px;background:#1E1E24;border:1px solid #333;border-radius:6px;overflow:hidden}' +
      '.menu.open{display:flex}' +
      '.item{padding:8px 12px;color:#eee;font-size:12px;cursor:pointer}' +
      '.item:hover{background:' + SETTINGS.btnColor + '}' +
      '.ok{background:#4CAF50!important}' +
      '.err{background:#F44336!important}';
    shadow.appendChild(style);

    var wrap = document.createElement('div');
    wrap.className = 'wrap';
    shadow.appendChild(wrap);

    var btn = document.createElement('button');
    btn.className = 'main' + (SETTINGS.showQualitySelector ? '' : ' solo');
    btn.type = 'button';
    btn.textContent = downloadLabel();
    wrap.appendChild(btn);

    var selectedQuality = 'best';
    var toggle = null;
    var menu = null;
    var markedDownloaded = false;

    function setDownloaded() {
      markedDownloaded = true;
      btn.textContent = downloadedLabel();
      btn.disabled = true;
      btn.classList.add('ok');
      btn.classList.remove('err');
      if (toggle) {
        toggle.disabled = true;
        toggle.classList.add('ok');
        toggle.classList.remove('err');
      }
      if (menu) menu.classList.remove('open');
    }

    function setIdle() {
      if (isKnownDownloaded(tweetId, mediaId)) {
        setDownloaded();
        return;
      }
      markedDownloaded = false;
      btn.textContent = downloadLabel();
      btn.disabled = false;
      btn.classList.remove('ok', 'err');
      if (toggle) {
        toggle.disabled = false;
        toggle.classList.remove('ok', 'err');
      }
    }

    if (SETTINGS.showQualitySelector) {
      toggle = document.createElement('button');
      toggle.className = 'toggle';
      toggle.type = 'button';
      toggle.setAttribute('aria-label', t('quality', 'Quality'));
      toggle.textContent = '▾';
      wrap.appendChild(toggle);

      menu = document.createElement('div');
      menu.className = 'menu';
      wrap.appendChild(menu);

      [
        { label: t('qualityBest', 'Best Quality'), val: 'best' },
        { label: '1080p', val: '1080p' },
        { label: '720p', val: '720p' },
        { label: t('qualityAudioOnly', 'Audio Only'), val: 'audio' },
      ].forEach(function (opt) {
        var item = document.createElement('div');
        item.className = 'item';
        item.textContent = opt.label;
        item.addEventListener('click', function (e) {
          e.stopPropagation();
          if (markedDownloaded) return;
          selectedQuality = opt.val;
          btn.textContent = opt.val === 'audio' ? t('qualityAudio', 'Audio') : opt.label;
          menu.classList.remove('open');
        });
        menu.appendChild(item);
      });

      toggle.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        if (markedDownloaded) return;
        menu.classList.toggle('open');
      });
    }

    btn.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      if (markedDownloaded) return;
      var opts = {};
      if (selectedQuality === 'audio') opts.isAudioOnly = true;
      else if (selectedQuality !== 'best') opts.preferredQuality = selectedQuality;

      btn.textContent = '…';
      btn.disabled = true;

      sendDownload(targetUrl, opts, { tweetId: tweetId, mediaId: mediaId }, function (result) {
        if (result && result.ok) {
          if (tweetId) downloadedTweetIds[tweetId] = true;
          if (mediaId) downloadedMediaIds[mediaId] = true;
          setDownloaded();
          return;
        }
        var err = (result && result.error) || 'failed';
        btn.textContent = err === 'app_offline'
          ? t('offline', 'Offline')
          : err === 'need_tweet_url'
            ? t('needTweet', 'Need tweet')
            : err === 'unsupported_url'
              ? t('unsupportedUrl', 'Not a video')
              : t('failed', 'Failed');
        btn.classList.add('err');
        if (toggle) toggle.classList.add('err');
        setTimeout(function () {
          if (!markedDownloaded) setIdle();
        }, 2000);
      });
    });

    return {
      host: host,
      tweetId: tweetId,
      mediaId: mediaId,
      setDownloaded: setDownloaded,
      setIdle: setIdle,
    };
  }

  function ensureRelative(container) {
    // Do not mutate host position permanently — use a fixed overlay wrapper if static.
    var style = window.getComputedStyle(container);
    if (style.position === 'static') {
      var overlay = container.querySelector(':scope > .md-dl-overlay-root');
      if (!overlay) {
        overlay = document.createElement('div');
        overlay.className = 'md-dl-overlay-root';
        Object.assign(overlay.style, {
          position: 'absolute',
          inset: '0',
          pointerEvents: 'none',
          zIndex: '2147483646',
        });
        // Parent may still be static — set relative only on a wrapper we own.
        var wrap = document.createElement('div');
        wrap.className = 'md-dl-position-host';
        Object.assign(wrap.style, {
          position: 'relative',
          display: 'contents',
        });
        // Safer: just set relative on container (minimal) when needed for absolute children.
        container.style.position = 'relative';
      }
    }
  }

  function injectButton(container, targetUrl) {
    if (!container || PROCESSED.has(container)) return;
    ensureRelative(container);
    var tweetId = xTweetIdFromUrl(targetUrl);
    var mediaId = findMediaAssetIdNear(container);
    var ui = createButtonUI(targetUrl, tweetId, mediaId);
    container.appendChild(ui.host);
    injectedButtons.push(ui);
    PROCESSED.add(container);
    if (isKnownDownloaded(tweetId, mediaId)) {
      ui.setDownloaded();
    }
  }

  function scan() {
    if (!document.body) return;

    document.querySelectorAll('video').forEach(function (video) {
      if (!video.parentElement) return;
      // Skip tiny / ad-like videos
      var rect = video.getBoundingClientRect();
      if (rect.width < 80 || rect.height < 45) return;
      var url = findPlatformSpecificUrl(video);
      if (url) injectButton(video.parentElement, url);
    });

    document.querySelectorAll('a').forEach(function (a) {
      if (PROCESSED.has(a)) return;
      var href = a.href;
      if (!href || !VIDEO_PATTERNS.some(function (p) { return href.indexOf(p) !== -1; })) return;
      var rect = a.getBoundingClientRect();
      if (rect.width > 100 && rect.height > 60) {
        injectButton(a, href);
      }
    });

    scheduleXFeedUpdate();
  }

  function scheduleScan() {
    if (scanScheduled) return;
    scanScheduled = true;
    if (scanTimer) clearTimeout(scanTimer);
    scanTimer = setTimeout(function () {
      scanScheduled = false;
      requestAnimationFrame(scan);
    }, 250);
  }

  function start() {
    if (!document.body) {
      document.addEventListener('DOMContentLoaded', start, { once: true });
      return;
    }
    scan();
    var observer = new MutationObserver(function () {
      scheduleScan();
      scheduleXFeedUpdate();
    });
    observer.observe(document.body, { childList: true, subtree: true });
    document.addEventListener('scroll', scheduleXFeedUpdate, true);
  }

  if (api.runtime && api.runtime.onMessage) {
    api.runtime.onMessage.addListener(function (message, sender, sendResponse) {
      if (!message || typeof message.type !== 'string') return false;
      if (message.type === 'MD_DOWNLOAD_STATE') {
        mergeLocalKeys(
          message.tweetIds,
          message.mediaIds,
          message.removedTweetIds,
        );
        refreshInjectedButtons();
        sendResponse({ ok: true });
        return false;
      }
      if (message.type === 'MD_RESOLVE_X_PERMALINK') {
        try {
          var url = resolveXPermalinkFromElement(
            document.activeElement,
            message.srcUrl,
          );
          sendResponse({ ok: !!url, url: url || null });
        } catch (e) {
          sendResponse({ ok: false, error: 'resolve_failed' });
        }
        return false;
      }
      if (message.type !== 'MD_EXTRACT_X_FEED') return false;
      try {
        var result = extractXFeed(message.maxItems);
        if (result && result.ok === true && Array.isArray(result.items)) {
          rememberXFeedItems(result.items);
          result.items = X_FEED_CACHE.map(function (id) {
            return X_FEED_CACHE_INDEX[id];
          });
          result.items.forEach(function (item) {
            var id = String(item && item.id || '');
            if (id) X_FEED_EMITTED_IDS[id] = true;
          });
        }
        sendResponse(result);
      } catch (e) {
        sendResponse({ ok: false, error: 'extract_failed' });
      }
      return false;
    });
  }

  start();
})();
