/**
 * TapLoad content script — limited to video platform pages.
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
  var tiktokSyncBannerTimer = null;
  var injectedButtons = [];
  var downloadedTweetIds = Object.create(null);
  var downloadedMediaIds = Object.create(null);
  var downloadedTikTokIds = Object.create(null);

  var VIDEO_PATTERNS = [
    '/watch?v=',
    '/watch/',
    '/reels/',
    '/reel/',
    '/status/',
    '/video/',
    '/videos/',
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

  var inIframe = false;
  try {
    inIframe = window.self !== window.top;
  } catch (e) {
    inIframe = true;
  }
  var tabPageUrl = window.location.href;

  var SETTINGS = {
    showQualitySelector: true,
  };

  function loadSettings() {
    var area = (api.storage && api.storage.local) || api.storage.sync;
    if (!area) return;
    area.get(
      [
        'showQualitySelector',
        'downloadedKeys',
      ],
      function (items) {
        if (api.runtime.lastError) return;
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
      var needsRefresh = false;
      if (changes.showQualitySelector) {
        SETTINGS.showQualitySelector = changes.showQualitySelector.newValue;
        needsRefresh = true;
      }
      if (changes.downloadedKeys) {
        applyStoredKeys(changes.downloadedKeys.newValue);
        needsRefresh = true;
      }
      if (needsRefresh) {
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

  function currentPlatform() {
    var host = String(window.location.hostname || '').toLowerCase();
    if (host === 'x.com' || host.endsWith('.x.com') || host === 'twitter.com' || host.endsWith('.twitter.com')) return 'x';
    if (host.indexOf('tiktok.com') !== -1) return 'tiktok';
    if (host.indexOf('instagram.com') !== -1) return 'instagram';
    if (host.indexOf('youtube.com') !== -1 || host.indexOf('youtu.be') !== -1) return 'youtube';
    if (host.indexOf('facebook.com') !== -1 || host.indexOf('fb.watch') !== -1) return 'facebook';
    if (host.indexOf('kick.com') !== -1) return 'kick';
    return 'generic';
  }

  function isSponsoredContent(element) {
    if (!element) return false;
    var curr = element;
    var depth = 0;
    var adRegex = /\b(sponsoris[ée]|sponsored|commandit[ée]|partenariat r[ée]mun[ée]r[ée]|paid partnership|promoted|publicit[ée]|advertisement|annonce)\b/i;
    var adClassRegex = /(^|\b)(ad|ads|advert|banner|sponsor|promot|commercial|pub|sponsorise|ad-slot|ad-container|ad-wrapper|video-ad)($|\b)/i;

    while (curr && depth < 12) {
      if (curr.nodeType === 1) {
        var className = typeof curr.className === 'string' ? curr.className : '';
        var idName = typeof curr.id === 'string' ? curr.id : '';
        if (adClassRegex.test(className) || adClassRegex.test(idName)) return true;

        if (curr.hasAttribute && (
          curr.hasAttribute('data-ad') ||
          curr.hasAttribute('data-ad-slot') ||
          curr.hasAttribute('data-ad-client') ||
          curr.hasAttribute('data-google-query-id') ||
          curr.getAttribute('data-e2e') === 'ad-tag' ||
          curr.getAttribute('data-ad') === 'true' ||
          curr.getAttribute('data-testid') === 'placementTracking'
        )) return true;

        if (curr.tagName === 'IFRAME') {
          var src = (curr.src || '').toLowerCase();
          if (/doubleclick|googlesyndication|adsystem|outbrain|taboola|criteo|adnxs|adroll/.test(src)) return true;
        }

        var tag = curr.tagName ? curr.tagName.toLowerCase() : '';
        if (tag.indexOf('ad-') === 0 || tag.indexOf('-ad') !== -1 || tag === 'ins' || tag === 'ytd-ad-slot-renderer') return true;
        if (curr.classList && (curr.classList.contains('ad-showing') || curr.classList.contains('ad-interrupting'))) return true;

        var labels = curr.querySelectorAll ? curr.querySelectorAll('span, div, p, a') : [];
        for (var i = 0; i < Math.min(labels.length, 12); i++) {
          var txt = labels[i].textContent ? labels[i].textContent.trim() : '';
          if (txt.length > 0 && txt.length < 35 && adRegex.test(txt)) {
            var cls = String(labels[i].className || '');
            var aria = String(labels[i].getAttribute('aria-label') || '');
            if (adClassRegex.test(cls) || adRegex.test(aria) || labels[i].closest('article') || labels[i].closest('[class*="video"]')) {
              return true;
            }
          }
        }
      }
      curr = curr.parentElement;
      depth++;
    }
    return false;
  }

  function cleanText(value) {
    return String(value || '').replace(/\s+/g, ' ').trim();
  }

  function safeHttpUrl(value) {
    if (!value || typeof value !== 'string') return null;
    try {
      var url = new URL(value, window.location.href);
      return (url.protocol === 'http:' || url.protocol === 'https:')
        ? url.href
        : null;
    } catch (e) {
      return null;
    }
  }

  function extractCleanImageUrl(element) {
    if (!element) return null;

    function isPlaceholderUrl(str) {
      if (!str || typeof str !== 'string') return true;
      var s = str.trim().toLowerCase();
      if (!s) return true;
      if (/^data:image\/[a-z0-9+]+;base64,R0lGOD/i.test(s)) return true;
      if (/^data:image\/svg\+xml/i.test(s) && (s.length < 300 || s.indexOf('placeholder') !== -1 || s.indexOf('viewbox') !== -1)) return true;
      if (/placeholder|spacer|transparent|blank\.gif|pixel\.gif|1x1/i.test(s)) return true;
      return false;
    }

    function cleanUrlCandidate(candidate) {
      if (!candidate || typeof candidate !== 'string') return null;
      candidate = candidate.trim();
      if (!candidate || isPlaceholderUrl(candidate)) return null;
      // Unwrap Next.js optimizer URLs: e.g. /_next/image?url=https%3A%2F%2F...&w=...
      if (candidate.indexOf('_next/image') !== -1 && candidate.indexOf('url=') !== -1) {
        try {
          var parsed = new URL(candidate, window.location.href);
          var inner = parsed.searchParams.get('url');
          if (inner && (inner.indexOf('http://') === 0 || inner.indexOf('https://') === 0)) {
            return inner;
          }
        } catch (e) {}
      }
      return safeHttpUrl(candidate);
    }

    function parseSrcset(srcset) {
      if (!srcset || typeof srcset !== 'string') return null;
      var parts = srcset.split(',').map(function (s) { return s.trim(); }).filter(Boolean);
      for (var i = parts.length - 1; i >= 0; i--) {
        var candidate = parts[i].split(/\s+/)[0];
        var cleaned = cleanUrlCandidate(candidate);
        if (cleaned) return cleaned;
      }
      return null;
    }

    // 1. If element is an IMG
    if (element.tagName === 'IMG') {
      var lazyAttrs = [
        'data-src',
        'data-thumbnail',
        'data-thumb',
        'data-preview',
        'data-original',
        'data-original-src',
        'data-lazy-src',
        'data-lazy',
        'data-poster',
        'data-image',
        'data-fallback-src',
        'data-url',
      ];
      for (var aIdx = 0; aIdx < lazyAttrs.length; aIdx++) {
        var cleanLazy = cleanUrlCandidate(element.getAttribute(lazyAttrs[aIdx]));
        if (cleanLazy) return cleanLazy;
      }

      var fromSrcset = parseSrcset(element.getAttribute('data-srcset') || element.getAttribute('srcset') || element.srcset);
      if (fromSrcset) return fromSrcset;

      var fromCurrent = cleanUrlCandidate(element.currentSrc);
      if (fromCurrent) return fromCurrent;

      var fromSrc = cleanUrlCandidate(element.src || element.getAttribute('src'));
      if (fromSrc) return fromSrc;
    }

    // 2. Search children for img or picture source
    if (element.querySelectorAll) {
      var sources = element.querySelectorAll('source[data-srcset], source[srcset]');
      for (var k = 0; k < sources.length; k++) {
        var srcUrl = parseSrcset(sources[k].getAttribute('data-srcset') || sources[k].getAttribute('srcset'));
        if (srcUrl) return srcUrl;
      }

      var imgs = element.querySelectorAll('img');
      for (var j = 0; j < imgs.length; j++) {
        var imgUrl = extractCleanImageUrl(imgs[j]);
        if (imgUrl) return imgUrl;
      }
    }

    // 3. Check data attributes on container itself (e.g. div with data-src/data-thumb)
    if (element.getAttribute) {
      var directData = cleanUrlCandidate(
        element.getAttribute('data-thumb') ||
        element.getAttribute('data-thumbnail') ||
        element.getAttribute('data-src') ||
        element.getAttribute('data-preview') ||
        element.getAttribute('data-poster') ||
        element.getAttribute('data-bg')
      );
      if (directData) return directData;
    }

    // 4. Check CSS background-image
    try {
      var bg = window.getComputedStyle(element).backgroundImage || '';
      var match = bg.match(/url\(["']?([^"')]+)["']?\)/);
      if (match && match[1]) {
        var cleanedBg = cleanUrlCandidate(match[1]);
        if (cleanedBg) return cleanedBg;
      }
    } catch (e) {}

    return null;
  }

  function isAdFrameHost() {
    var host = String(window.location.hostname || '').toLowerCase();
    return /doubleclick|googlesyndication|adsystem|outbrain|taboola|criteo|adnxs|adroll|moatads|innovid|amazon-adsystem/.test(host);
  }

  function isExcludedNavigation(el) {
    if (!el) return false;
    try {
      if (el.closest && el.closest('aside, nav, header, footer, [role="navigation"], [class*="sidebar"], [class*="sidebar-"], [class*="recommend"], [class*="following"], [class*="drawer"], [id*="sidebar"], [id*="navigation"], [class*="chat"], #chat, [class*="channel-sidebar"], [class*="side-nav"], [class*="sideNav"], [class*="navigation"]')) {
        return true;
      }
    } catch (e) {}
    return false;
  }

  function isKickVideoLink(href) {
    if (!href || typeof href !== 'string') return false;
    return /\/(video|videos|clip|clips)\/([A-Za-z0-9_-]+)/i.test(href) ||
           /[?&](video|clip)=([A-Za-z0-9_-]+)/i.test(href);
  }

  function isValidCandidateTitle(candidate, author) {
    if (!candidate || typeof candidate !== 'string') return false;
    var t = candidate.trim();
    if (t.length < 2) return false;
    // Pure numbers (e.g. "6140", "3976", "5708", "5601")
    if (/^\d+$/.test(t)) return false;
    // Formatted numbers / views: "6,1 k vues", "10k views", "1.2M vues", "6,1 k", "4456 vues", "6.2k"
    if (/^[\d,.\s]+(k|m|b)?\s*(vues?|views?|spectateurs?|viewers?)?$/i.test(t)) return false;
    // Durations: "08:14:42", "06:21:06", "352:17", "11:03:39", "08:14"
    if (/^\d{1,3}:\d{2}(:\d{2})?$/.test(t)) return false;
    // Relative dates: "il y a 3 semaines", "3 days ago", "hier", "yesterday", "il y a ..."
    if (/^(il y a|\d+\s*(h|m|s|j|d|w|semaines?|jours?|heures?|minutes?|mois|years?|ans?)|yesterday|hier)/i.test(t)) return false;
    // Common Kick badges and meta labels
    if (/^(abonné-seulement|abonn-seulement|sub-only|subscriber-only|en direct|live|rediffusion|rerun|vod|clip)$/i.test(t)) return false;
    // If it's just the author name or @author:
    if (author && (t.toLowerCase() === author.toLowerCase() || t.toLowerCase() === ('@' + author).toLowerCase())) return false;
    return true;
  }

  function isJunkPath(pathname) {
    if (/\/(video|videos|clip|clips)\//i.test(pathname || '')) return false;
    return /\/(tag|tags|search|login|signup|register|account|settings|privacy|terms|about|contact|category|categories|channels?|models?|pornstars?|playlist|feed|trending)(\/|$)/i.test(
      pathname || '',
    );
  }

  function isSameOriginHttp(href) {
    try {
      var u = new URL(href, window.location.href);
      return (u.protocol === 'http:' || u.protocol === 'https:') &&
        u.origin === window.location.origin;
    } catch (e) {
      return false;
    }
  }

  function looksLikeContentLink(href) {
    try {
      var u = new URL(href, window.location.href);
      if (!isSameOriginHttp(u.href)) return false;
      var path = u.pathname || '';
      if (path === '/' || path.length < 3) return false;
      if (isJunkPath(path)) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  function looksLikeVideoCard(anchor) {
    if (!anchor || !anchor.href) return false;
    if (isExcludedNavigation(anchor)) return false;
    var platform = currentPlatform();
    if (platform === 'kick' && !isKickVideoLink(anchor.href)) return false;
    if (!looksLikeContentLink(anchor.href)) return false;
    var rect = anchor.getBoundingClientRect();
    var hasSize = (rect.width >= 100 && rect.height >= 50 && rect.width <= 1200 && rect.height <= 900);
    var card = anchor.closest ? anchor.closest('div, article, li, figure') : null;
    var cardRect = card ? card.getBoundingClientRect() : null;
    var cardHasSize = cardRect && (cardRect.width >= 120 && cardRect.height >= 70 && cardRect.width <= 1200 && cardRect.height <= 900);
    if (!hasSize && !cardHasSize) return false;
    if (anchor.querySelector('img, video, source, picture')) return true;
    if (card && card.querySelector('img, video, source, picture')) return true;
    var bg = '';
    try {
      bg = window.getComputedStyle(anchor).backgroundImage || (card ? window.getComputedStyle(card).backgroundImage : '');
    } catch (e) {
      bg = '';
    }
    return bg && bg !== 'none';
  }

  function findGenericPermalink(el) {
    var curr = el;
    var depth = 0;
    while (curr && depth < 14) {
      if (curr.tagName === 'A' && looksLikeContentLink(curr.href)) {
        return curr.href.split('#')[0];
      }
      depth++;
      curr = curr.parentElement;
    }
    var card = el.closest
      ? el.closest('a, article, li, figure, [class*="thumb"], [class*="video"], [class*="item"], [class*="card"]')
      : null;
    if (!card) return null;
    if (card.tagName === 'A' && looksLikeContentLink(card.href)) {
      return card.href.split('#')[0];
    }
    var links = card.querySelectorAll ? card.querySelectorAll('a[href]') : [];
    for (var i = 0; i < links.length; i++) {
      if (looksLikeContentLink(links[i].href) && links[i].href.indexOf('preview') === -1) {
        return links[i].href.split('#')[0];
      }
    }
    return null;
  }

  function isUsableVideo(video) {
    if (!video) return false;
    var rect = video.getBoundingClientRect();
    if (rect.width >= 80 && rect.height >= 45) return true;
    return video.videoWidth >= 160 && video.videoHeight >= 90;
  }

  function pageUrlFallback() {
    return tabPageUrl || window.location.href;
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
    downloadedTikTokIds = Object.create(null);
    if (!keys || typeof keys !== 'object') return;
    (keys.tweetIds || []).forEach(function (id) {
      if (id) downloadedTweetIds[String(id)] = true;
    });
    (keys.mediaIds || []).forEach(function (id) {
      if (id) downloadedMediaIds[String(id)] = true;
    });
    (keys.tikTokIds || []).forEach(function (id) {
      if (id) downloadedTikTokIds[String(id)] = true;
    });
  }

  function mergeLocalKeys(tweetIds, mediaIds, removedTweetIds, tikTokIds, removedTikTokIds) {
    (tweetIds || []).forEach(function (id) {
      if (id) downloadedTweetIds[String(id)] = true;
    });
    (mediaIds || []).forEach(function (id) {
      if (id) downloadedMediaIds[String(id)] = true;
    });
    (tikTokIds || []).forEach(function (id) {
      if (id) downloadedTikTokIds[String(id)] = true;
    });
    (removedTweetIds || []).forEach(function (id) {
      if (id) delete downloadedTweetIds[String(id)];
    });
    (removedTikTokIds || []).forEach(function (id) {
      if (id) delete downloadedTikTokIds[String(id)];
    });
  }

  function isKnownDownloaded(tweetId, mediaId, tikTokId) {
    return (!!tweetId && !!downloadedTweetIds[tweetId]) ||
      (!!mediaId && !!downloadedMediaIds[mediaId]) ||
      (!!tikTokId && !!downloadedTikTokIds[tikTokId]);
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
      if (typeof entry.applyStyles === 'function') entry.applyStyles();
      if (isKnownDownloaded(entry.tweetId, entry.mediaId, entry.tikTokId)) {
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
    var post = findXPostLink(article);
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

  function findXVideoElements(article) {
    var videos = article.querySelectorAll('video');
    var playable = [];
    for (var i = 0; i < videos.length; i++) {
      var video = videos[i];
      // Off-screen tweets often report 0×0 before layout. Only reject
      // decoded audio-only / empty frames (readyState > 0 and 0×0).
      if (video.readyState > 0 && video.videoWidth === 0 && video.videoHeight === 0) {
        continue;
      }
      playable.push(video);
    }
    if (playable.length > 0) return playable;
    return Array.prototype.slice.call(
      article.querySelectorAll('[data-testid="videoPlayer"]'),
    );
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

  function extractTikTokFeed(limit, seenIds, items) {
    var candidates = [];
    var seenContainers = new Set();

    function addCandidate(el) {
      if (!el || seenContainers.has(el)) return;
      seenContainers.add(el);
      candidates.push(el);
    }

    // Direct video links: essential for collection, playlist, and profile grid views
    document.querySelectorAll('a[href*="/video/"]').forEach(function (a) {
      var tile = (a.closest && a.closest('[data-e2e="user-post-item"], div[class*="DivItemContainer"], div[class*="Card"], div[class*="Item"]')) || a.parentElement || a;
      addCandidate(tile);
    });

    // Standard feed containers
    var selectors = [
      '[data-e2e="recommend-list-item-container"]',
      'div[data-e2e="feed-item"]',
      'section[data-e2e="feed-item"]',
      'div[class*="DivItemContainer"]',
      'div[class*="DivVideoWrapper"]',
      'div[class*="DivBasicPlayerWrapper"]',
      '[data-e2e="feed-video"]',
      '[data-e2e="browse-video"]',
      '[data-e2e="user-post-item"]',
    ];
    document.querySelectorAll(selectors.join(', ')).forEach(addCandidate);

    // Fallback: check all video elements on TikTok
    document.querySelectorAll('video').forEach(function (v) {
      var parent = (v.closest && v.closest('article, section, div[class*="Item"], div[class*="Container"], div[tabindex]')) || v.parentElement;
      if (parent) addCandidate(parent);
    });

    candidates.forEach(function (container) {
      if (items.length >= limit) return;
      if (isSponsoredContent(container)) return;
      var video = container.querySelector ? (container.querySelector('video') || (container.tagName === 'VIDEO' ? container : null)) : null;

      var link = (container.tagName === 'A' && container.href.indexOf('/video/') !== -1)
        ? container
        : (container.querySelector ? container.querySelector('a[href*="/video/"]') : null);
      var url = link ? link.href : window.location.href;
      var canonical = (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl)
        ? MDUrl.canonicalMediaUrl(url)
        : url.split('?')[0];

      // If missing video link inside container, try finding nearest anchor or xgwrapper ID
      if ((!canonical || canonical.indexOf('/video/') === -1) && container.parentElement) {
        var nearbyLink = container.parentElement.querySelector('a[href*="/video/"]');
        if (nearbyLink) {
          canonical = (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl)
            ? MDUrl.canonicalMediaUrl(nearbyLink.href)
            : nearbyLink.href.split('?')[0];
        }
      }

      if (!canonical || canonical.indexOf('/video/') === -1) {
        var xgFeed = container.querySelector ? (container.querySelector('[id^="xgwrapper-"]') || (container.id && container.id.indexOf('xgwrapper-') === 0 ? container : null)) : null;
        if (xgFeed) {
          var xgMatchFeed = xgFeed.id.match(/xgwrapper-\d+-(\d+)/);
          if (xgMatchFeed) {
            var feedAuthorEl = container.querySelector('a[href*="/@"]');
            var feedAuthorMatch = feedAuthorEl ? feedAuthorEl.href.match(/@([a-zA-Z0-9_.-]+)/) : null;
            var feedAuthor = feedAuthorMatch ? '@' + feedAuthorMatch[1] : '';
            canonical = feedAuthor ? 'https://www.tiktok.com/' + feedAuthor + '/video/' + xgMatchFeed[1] : 'https://www.tiktok.com/video/' + xgMatchFeed[1];
          }
        }
      }

      if ((!canonical || canonical.indexOf('/video/') === -1) && window.location.href.indexOf('/video/') !== -1) {
        canonical = window.location.href.split('?')[0];
      }

      if (!canonical || canonical.indexOf('/video/') === -1) {
        var awemeId = null;
        var idNodes = container.querySelectorAll
          ? container.querySelectorAll('[id*="xgwrapper"], [id*="xgplayer"], [id*="video"]')
          : [];
        for (var xi = 0; xi < idNodes.length; xi++) {
          var idm = String(idNodes[xi].id || '').match(/(\d{8,})/);
          if (idm) {
            awemeId = idm[1];
            break;
          }
        }
        if (!awemeId && video) {
          var src = String(video.currentSrc || video.src || '');
          var srcm = src.match(/item_id=(\d+)/) || src.match(/\/(\d{15,})(?:\/|\?|$)/);
          if (srcm) awemeId = srcm[1];
        }
        if (awemeId) {
          var authorHref = container.querySelector ? container.querySelector('a[href*="/@"]') : null;
          var am = authorHref ? String(authorHref.href).match(/@([a-zA-Z0-9_.-]+)/) : null;
          canonical = am
            ? 'https://www.tiktok.com/@' + am[1] + '/video/' + awemeId
            : 'https://www.tiktok.com/video/' + awemeId;
        }
      }

      if (!canonical || canonical.indexOf('/video/') === -1) return;

      var matchId = canonical.match(/\/video\/(\d+)/);
      var itemId = matchId ? 'tt-' + matchId[1] : 'tt-' + canonical;
      if (seenIds[itemId]) return;
      seenIds[itemId] = true;

      // Extract author (@handle or nickname)
      var authorEl = container.querySelector ? container.querySelector(
        '[data-e2e="feed-author-nickname"], [data-e2e="feed-author-uniqueid"], [data-e2e="video-author-uniqueid"], [data-e2e="browse-username"], a[href^="/@"]',
      ) : null;
      var author = cleanText(authorEl && authorEl.textContent);
      if (!author || author.indexOf('@') === -1) {
        var userMatch = canonical.match(/@([a-zA-Z0-9_.-]+)/);
        if (userMatch) {
          author = '@' + userMatch[1];
        } else {
          var pageUserMatch = window.location.pathname.match(/@([a-zA-Z0-9_.-]+)/);
          if (pageUserMatch) {
            author = '@' + pageUserMatch[1];
            if (canonical.indexOf('/@') === -1 && matchId) {
              canonical = 'https://www.tiktok.com/@' + pageUserMatch[1] + '/video/' + matchId[1];
            }
          } else if (!author) {
            author = 'Créateur TikTok';
          }
        }
      }

      // Extract description / caption
      var descEl = container.querySelector ? container.querySelector(
        '[data-e2e="feed-video-desc"], [data-e2e="video-desc"], [data-e2e="browse-video-desc"], [data-e2e="user-post-item-desc"], div[class*="DivText"], span[class*="SpanText"], h1, div[title]',
      ) : null;
      var title = cleanText(descEl && (descEl.getAttribute('title') || descEl.textContent));
      if (!title && link) {
        title = cleanText(link.getAttribute('title') || link.getAttribute('aria-label'));
      }
      if (!title && container.querySelector) {
        var imgAlt = container.querySelector('img[alt]');
        if (imgAlt) title = cleanText(imgAlt.getAttribute('alt'));
      }
      if (!title || title.indexOf('Collection ') === 0) {
        title = 'TikTok — ' + author;
      }

      // Extract music / audio
      var musicEl = container.querySelector ? container.querySelector(
        '[data-e2e="feed-video-music"], [data-e2e="video-music"], [data-e2e="browse-music"], h4[class*="H4Music"], a[href*="/music/"]',
      ) : null;
      var music = cleanText(musicEl && musicEl.textContent) || null;

      // Extract creator avatar
      var avatarImg = container.querySelector ? container.querySelector(
        '[data-e2e="feed-author-avatar"] img, img[class*="ImgAvatar"], img[src*="avatar"]',
      ) : null;
      var avatarUrl = avatarImg ? safeHttpUrl(avatarImg.currentSrc || avatarImg.src) : null;
      if (!avatarUrl && typeof document !== 'undefined') {
        var profileHeaderAvatar = document.querySelector('[data-e2e="user-avatar"] img, [class*="AvatarContainer"] img, [data-e2e="user-title"] ~ * img, header img');
        if (profileHeaderAvatar) {
          avatarUrl = safeHttpUrl(profileHeaderAvatar.currentSrc || profileHeaderAvatar.src);
        }
      }

      // Extract HD thumbnail (video poster, largest img preview, or live canvas frame)
      var thumb = (video && safeHttpUrl(video.poster)) || null;
      if (!thumb && container.querySelector) {
        var posterImg = container.querySelector('img[class*="ImgPoster"], img[src*="tiktokcdn"], img[src*="tos-"], img[src*="byteoversea"], img[src*="muscdn"]');
        if (posterImg) {
          var pSrc = posterImg.currentSrc || posterImg.src || posterImg.getAttribute('data-src') || posterImg.getAttribute('src');
          thumb = safeHttpUrl(pSrc);
        }
      }
      if (!thumb && container.querySelectorAll) {
        var anyImgs = Array.from(container.querySelectorAll('img'));
        for (var im = 0; im < anyImgs.length; im++) {
          var iSrc = anyImgs[im].currentSrc || anyImgs[im].src || anyImgs[im].getAttribute('data-src') || anyImgs[im].getAttribute('src');
          if (iSrc && iSrc.indexOf('avatar') === -1 && (anyImgs[im].width > 40 || anyImgs[im].naturalWidth > 40 || iSrc.indexOf('tiktokcdn') !== -1 || iSrc.indexOf('tos-') !== -1 || iSrc.indexOf('byteoversea') !== -1)) {
            thumb = safeHttpUrl(iSrc);
            if (thumb) break;
          }
        }
      }
      var durationSec = null;
      var width = null;
      var height = null;
      var isActive = false;
      if (video) {
        if (Number.isFinite(video.duration) && video.duration > 0) {
          durationSec = Math.round(video.duration);
        }
        if (video.videoWidth > 0) width = video.videoWidth;
        if (video.videoHeight > 0) height = video.videoHeight;
        if (!video.paused && video.currentTime > 0) {
          isActive = true;
        }
      }
      if (matchId && window.location.href.indexOf(matchId[1]) !== -1) {
        isActive = true;
      }

      var rawTikTokId = matchId ? matchId[1] : null;
      var isDownloaded = Boolean(rawTikTokId && downloadedTikTokIds[rawTikTokId]);

      items.push({
        id: itemId,
        tikTokId: rawTikTokId,
        url: canonical,
        pageUrl: canonical,
        title: title,
        author: author,
        music: music,
        avatarUrl: avatarUrl,
        platform: 'tiktok',
        thumbnailUrl: thumb,
        videoSrc: video ? (video.currentSrc || video.src) : null,
        isActive: isActive,
        isDownloaded: isDownloaded,
        durationSeconds: durationSec,
        width: width,
        height: height,
        sizeBytes: null,
        source: 'dom',
        sourceLabel: 'TikTok HD Sans Filigrane',
      });
    });
  }

  function extractInstagramFeed(limit, seenIds, items) {
    var containers = document.querySelectorAll('article, div[role="dialog"], [class*="Reels"], div[style*="aspect-ratio"]');
    containers.forEach(function (container) {
      if (items.length >= limit) return;
      if (isSponsoredContent(container)) return;
      var video = container.querySelector('video');
      if (!video) return;
      var link = container.querySelector('a[href*="/reel/"], a[href*="/reels/"], a[href*="/p/"]');
      var url = link ? link.href : window.location.href;
      var canonical = (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl)
        ? MDUrl.canonicalMediaUrl(url)
        : url.split('?')[0];
      if (!canonical) return;

      var matchId = canonical.match(/\/(?:reels?|p)\/([A-Za-z0-9_-]+)/);
      var itemId = matchId ? 'ig-' + matchId[1] : 'ig-' + canonical;
      if (seenIds[itemId]) return;
      seenIds[itemId] = true;

      var authorEl = container.querySelector('header a, a[role="link"]');
      var author = cleanText(authorEl && authorEl.textContent) || 'Instagram user';
      var descEl = container.querySelector('h1, span[class*="Caption"], span[dir="auto"]');
      var title = cleanText(descEl && descEl.textContent) || ('Instagram Reel — ' + author);
      var thumb = safeHttpUrl(video.poster);

      items.push({
        id: itemId,
        url: canonical,
        pageUrl: window.location.href,
        title: title,
        author: author,
        platform: 'instagram',
        thumbnailUrl: thumb,
        durationSeconds: Number.isFinite(video.duration) && video.duration > 0 ? Math.round(video.duration) : null,
        width: video.videoWidth || null,
        height: video.videoHeight || null,
        sizeBytes: null,
        source: 'dom',
        sourceLabel: 'Instagram — Reel',
      });
    });
  }

  function extractShortsFeed(limit, seenIds, items) {
    var containers = document.querySelectorAll('ytd-reel-video-renderer');
    containers.forEach(function (container) {
      if (items.length >= limit) return;
      if (isSponsoredContent(container)) return;
      var video = container.querySelector('video');
      var link = container.querySelector('a[href*="/shorts/"]');
      var url = link ? link.href : window.location.href;
      var canonical = (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl)
        ? MDUrl.canonicalMediaUrl(url)
        : url.split('?')[0];
      if (!canonical) return;

      var matchId = canonical.match(/\/shorts\/([A-Za-z0-9_-]+)/);
      var itemId = matchId ? 'yt-' + matchId[1] : 'yt-' + canonical;
      if (seenIds[itemId]) return;
      seenIds[itemId] = true;

      var authorEl = container.querySelector('#channel-name, .ytd-channel-name, ytd-reel-player-header-renderer a');
      var author = cleanText(authorEl && authorEl.textContent) || 'YouTube creator';
      var titleEl = container.querySelector('.title, #video-title, ytd-reel-player-header-renderer h2');
      var title = cleanText(titleEl && titleEl.textContent) || ('YouTube Shorts — ' + author);
      var thumb = video ? safeHttpUrl(video.poster) : null;

      items.push({
        id: itemId,
        url: canonical,
        pageUrl: window.location.href,
        title: title,
        author: author,
        platform: 'youtube',
        thumbnailUrl: thumb,
        durationSeconds: video && Number.isFinite(video.duration) && video.duration > 0 ? Math.round(video.duration) : null,
        width: video ? video.videoWidth : null,
        height: video ? video.videoHeight : null,
        sizeBytes: null,
        source: 'dom',
        sourceLabel: 'YouTube — Shorts',
      });
    });
  }

  function extractKickFeed(limit, seenIds, items) {
    var pathSegments = window.location.pathname.split('/').filter(Boolean);
    var defaultAuthor = (pathSegments.length > 0 && ['video', 'videos', 'categories', 'clips', 'search', 'following'].indexOf(pathSegments[0].toLowerCase()) === -1)
      ? pathSegments[0]
      : 'Kick Creator';

    // 1. If currently on a watch / live page with a playing video:
    var videos = document.querySelectorAll('video');
    videos.forEach(function (video) {
      if (items.length >= limit) return;
      if (isExcludedNavigation(video) || isExcludedNavigation(video.parentElement)) return;
      if (!isUsableVideo(video)) return;
      if (isSponsoredContent(video)) return;

      var currentUrl = window.location.href.split('#')[0];
      var cleanKey = currentUrl.replace(/[^a-zA-Z0-9]/g, '').slice(-32);
      var itemId = 'kick-player-' + cleanKey;
      if (seenIds[itemId]) return;
      seenIds[itemId] = true;

      var titleEl = document.querySelector('h1, h2, [class*="stream_title"], [class*="stream-title"]');
      var candidateTitle = cleanText(titleEl && titleEl.textContent);
      var title = (candidateTitle && isValidCandidateTitle(candidateTitle, defaultAuthor))
        ? candidateTitle
        : (document.title && isValidCandidateTitle(document.title, defaultAuthor) ? document.title : (defaultAuthor + ' en direct sur Kick'));
      var cardContainer = video.closest('div[class*="player"], div[class*="video"], main') || video.parentElement;
      var thumb = extractCleanImageUrl(cardContainer) || safeHttpUrl(video.poster);

      items.push({
        id: itemId,
        url: currentUrl,
        pageUrl: currentUrl,
        title: title,
        author: defaultAuthor,
        platform: 'kick',
        thumbnailUrl: thumb,
        videoSrc: video.currentSrc || video.src || null,
        isActive: !video.paused && video.currentTime > 0,
        durationSeconds: Number.isFinite(video.duration) && video.duration > 0 ? Math.round(video.duration) : null,
        width: video.videoWidth || null,
        height: video.videoHeight || null,
        sizeBytes: null,
        source: 'dom',
        sourceLabel: 'Kick Direct / VOD',
      });
    });

    // 2. Scan all video, VOD, and clip cards on the page
    var anchors = document.querySelectorAll('a[href]');
    anchors.forEach(function (anchor) {
      if (items.length >= limit) return;
      if (isExcludedNavigation(anchor)) return;
      if (isSponsoredContent(anchor)) return;

      var fullHref = '';
      try {
        var u = new URL(anchor.href, window.location.href);
        if (u.origin !== window.location.origin) return;
        fullHref = u.href.split('#')[0];
      } catch (e) {
        return;
      }

      var isVideoLink = isKickVideoLink(fullHref);

      // Don't match the current list page itself (e.g. /balti/videos)
      var normCurrent = window.location.href.split('#')[0].replace(/\/$/, '');
      if (fullHref.replace(/\/$/, '') === normCurrent) return;

      var path = '';
      try {
        path = new URL(fullHref).pathname;
      } catch (e) {
        return;
      }
      if (isJunkPath(path)) return;

      if (!isVideoLink) {
        // If on a channel videos or clips page, also check if anchor is inside a grid card
        var isChannelVideosPage = /\/videos|\/clips/i.test(window.location.pathname);
        if (isChannelVideosPage) {
          var segments = path.split('/').filter(Boolean);
          if (segments.length >= 2 && (segments[1] === 'videos' || segments[0] === 'video' || segments[1] === 'clips' || segments[0] === 'clips')) {
            isVideoLink = true;
          }
        }
      }

      if (!isVideoLink) return;

      var canonical = (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl)
        ? (MDUrl.canonicalMediaUrl(fullHref) || fullHref)
        : fullHref;

      var cleanKey = canonical.replace(/[^a-zA-Z0-9]/g, '').slice(-36);
      var itemId = 'kick-' + cleanKey;
      if (seenIds[itemId]) return;

      // Find the card container
      var card = (anchor.closest && anchor.closest('div[class*="group"], div[class*="card"], article, li')) || anchor.parentElement || anchor;

      // Extract author
      var author = defaultAuthor;
      var authorEl = card.querySelector ? card.querySelector('a[href^="/"]:not([href*="video"]):not([href*="clip"]), [class*="channel"], [class*="creator"]') : null;
      if (authorEl) {
        var aText = cleanText(authorEl.textContent);
        if (aText && aText.length < 35 && aText.indexOf('/') === -1) {
          author = aText.replace(/^@/, '');
        }
      }

      // Extract title robustly
      var title = '';

      // Check specific title elements or links pointing to the video
      var titleLinks = card.querySelectorAll ? card.querySelectorAll('a[href*="/video/"], a[href*="/videos/"], a[href*="/clips/"], a[href*="/clip/"]') : [];
      for (var l = 0; l < titleLinks.length; l++) {
        var tVal = cleanText(titleLinks[l].getAttribute('title') || titleLinks[l].getAttribute('aria-label'));
        if (isValidCandidateTitle(tVal, author)) {
          title = tVal;
          break;
        }
      }

      // Check headings inside card
      if (!title && card.querySelectorAll) {
        var headings = card.querySelectorAll('h1, h2, h3, h4, h5, [class*="title"], [class*="Title"], [data-testid*="title"]');
        for (var h = 0; h < headings.length; h++) {
          var hVal = cleanText(headings[h].getAttribute('title') || headings[h].textContent);
          if (isValidCandidateTitle(hVal, author)) {
            title = hVal;
            break;
          }
        }
      }

      // Check img alt in card
      if (!title && card.querySelector) {
        var cardImg = card.querySelector('img[alt]:not([alt=""]):not([alt*="avatar"])');
        if (cardImg) {
          var altVal = cleanText(cardImg.getAttribute('alt'));
          if (isValidCandidateTitle(altVal, author)) {
            title = altVal;
          }
        }
      }

      // Check any element with [title] attribute, strictly filtering out view counts / pure digits
      if (!title && card.querySelectorAll) {
        var titledEls = card.querySelectorAll('[title]');
        for (var tIdx = 0; tIdx < titledEls.length; tIdx++) {
          var candidateVal = cleanText(titledEls[tIdx].getAttribute('title'));
          if (isValidCandidateTitle(candidateVal, author)) {
            title = candidateVal;
            break;
          }
        }
      }

      // Fallback to text lines within the card (ignoring views, duration, author, badges)
      if (!title && card.innerText) {
        var lines = card.innerText.split('\n').map(function (s) { return s.trim(); }).filter(function (s) {
          return isValidCandidateTitle(s, author);
        });
        if (lines.length > 0) {
          title = lines[0];
        }
      }

      if (!title) {
        var fallbackAnchorTitle = cleanText(anchor.getAttribute('title') || anchor.getAttribute('aria-label'));
        title = (isValidCandidateTitle(fallbackAnchorTitle, author) ? fallbackAnchorTitle : '') || (defaultAuthor + ' — Vidéo Kick');
      }

      // Extract thumbnail
      var thumb = extractCleanImageUrl(anchor) ||
                  extractCleanImageUrl(card) ||
                  extractCleanImageUrl(anchor.parentElement);

      // Extract duration
      var durationSec = null;
      var durationBadges = card.querySelectorAll ? card.querySelectorAll('span, div, p') : [];
      for (var i = 0; i < durationBadges.length; i++) {
        var badgeText = (durationBadges[i].textContent || '').trim();
        var durMatch = badgeText.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
        if (durMatch) {
          if (durMatch[3] !== undefined) {
            durationSec = parseInt(durMatch[1], 10) * 3600 + parseInt(durMatch[2], 10) * 60 + parseInt(durMatch[3], 10);
          } else {
            durationSec = parseInt(durMatch[1], 10) * 60 + parseInt(durMatch[2], 10);
          }
          break;
        }
      }

      seenIds[itemId] = true;
      items.push({
        id: itemId,
        url: canonical,
        pageUrl: canonical,
        title: title,
        author: author,
        platform: 'kick',
        thumbnailUrl: thumb,
        durationSeconds: durationSec,
        width: null,
        height: null,
        sizeBytes: null,
        source: 'dom',
        sourceLabel: 'Kick VOD / Clip',
      });
    });
  }

  function extractUniversalFeed(maxItems) {
    var platform = currentPlatform();
    if (platform === 'x') {
      return extractXFeed(maxItems);
    }

    var limit = parseInt(maxItems, 10);
    if (!Number.isFinite(limit) || limit < 1) limit = X_FEED_MAX_ITEMS;
    limit = Math.min(limit, X_FEED_MAX_ITEMS);

    var items = [];
    var seenIds = {};

    if (platform === 'tiktok') {
      extractTikTokFeed(limit, seenIds, items);
    } else if (platform === 'instagram') {
      extractInstagramFeed(limit, seenIds, items);
    } else if (platform === 'youtube') {
      extractShortsFeed(limit, seenIds, items);
    } else if (platform === 'kick') {
      extractKickFeed(limit, seenIds, items);
    }

    // Universal DOM Video Scanner: works on Reddit, Vimeo, Twitch, Facebook, Dailymotion, news sites, video blogs, etc.
    // Any site without a dedicated feed extractor above uses this universal scanner:
    if (platform !== 'tiktok' && platform !== 'instagram' && platform !== 'youtube' && platform !== 'x' && platform !== 'kick' && items.length < limit) {
      document.querySelectorAll('video').forEach(function (video) {
        if (items.length >= limit) return;
        if (isSponsoredContent(video) || (video.parentElement && isSponsoredContent(video.parentElement))) return;
        if (!isUsableVideo(video)) return;

        var url = findPlatformSpecificUrl(video);
        if (!url) return;
        var canonical = (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl)
          ? MDUrl.canonicalMediaUrl(url)
          : url.split('?')[0];
        if (!canonical) canonical = url;

        var cleanKey = canonical.replace(/[^a-zA-Z0-9]/g, '').substring(0, 32);
        var itemId = 'media-' + cleanKey;
        if (seenIds[itemId]) return;
        seenIds[itemId] = true;

        var hostClean = window.location.hostname.replace(/^www\./, '');
        var card = (video.closest && video.closest('div[class*="item"], div[class*="card"], div[class*="video"], article, li, figure')) || video.parentElement;

        var candidateTitle = cleanText(video.title || video.getAttribute('aria-label'));
        if (!candidateTitle && card && card.querySelector) {
          var titleEl = card.querySelector('h1, h2, h3, h4, [class*="title"], [class*="name"], a[href*="/video/"]');
          if (titleEl) {
            var tVal = cleanText(titleEl.getAttribute('title') || titleEl.textContent);
            if (isValidCandidateTitle(tVal, hostClean)) candidateTitle = tVal;
          }
        }
        if (!candidateTitle && document.title && isValidCandidateTitle(document.title, hostClean)) {
          if (!/^(free porn|watch free|home|videos|trending|search|accueil)/i.test(document.title)) {
            candidateTitle = document.title;
          }
        }
        var title = candidateTitle || (hostClean + ' video');

        var thumb = safeHttpUrl(video.poster) ||
                    (card ? extractCleanImageUrl(card) : null) ||
                    extractCleanImageUrl(video.parentElement) ||
                    extractCleanImageUrl(video) ||
                    null;

        items.push({
          id: itemId,
          url: canonical,
          pageUrl: pageUrlFallback(),
          title: title,
          author: hostClean,
          platform: platform,
          thumbnailUrl: thumb,
          durationSeconds: Number.isFinite(video.duration) && video.duration > 0 ? Math.round(video.duration) : null,
          width: video.videoWidth || null,
          height: video.videoHeight || null,
          sizeBytes: null,
          source: 'dom',
          sourceLabel: hostClean,
        });
      });

      if (!inIframe) {
        document.querySelectorAll('a[href]').forEach(function (anchor) {
          if (items.length >= limit) return;
          if (!looksLikeVideoCard(anchor)) return;
          if (isSponsoredContent(anchor)) return;
          var href = anchor.href.split('#')[0];
          var canonical = (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl)
            ? (MDUrl.canonicalMediaUrl(href) || href)
            : href.split('?')[0];
          var cleanKey = canonical.replace(/[^a-zA-Z0-9]/g, '').substring(0, 40);
          var itemId = 'card-' + cleanKey;

          var hostClean = window.location.hostname.replace(/^www\./, '');
          var card = (anchor.closest && anchor.closest('div[class*="item"], div[class*="card"], div[class*="video"], article, li, figure')) || anchor.parentElement || anchor;

          var thumb = extractCleanImageUrl(card) ||
                      extractCleanImageUrl(anchor) ||
                      extractCleanImageUrl(anchor.parentElement);

          var cardText = '';
          if (card && card.querySelector) {
            var titleEl = card.querySelector('h1, h2, h3, h4, [class*="title"], [class*="name"], a[title]');
            if (titleEl) {
              var tText = cleanText(titleEl.getAttribute('title') || titleEl.textContent);
              if (isValidCandidateTitle(tText, hostClean)) cardText = tText;
            }
          }
          if (!cardText && anchor.innerText) {
            var lines = anchor.innerText.split('\n').map(function (s) { return s.trim(); }).filter(function (s) {
              return isValidCandidateTitle(s, hostClean);
            });
            if (lines.length > 0) cardText = lines[0];
          }
          var img = anchor.querySelector('img') || (card && card.querySelector('img'));
          var candidateTitle = cardText || cleanText(
            (img && (img.alt || img.title)) ||
              anchor.getAttribute('title') ||
              anchor.getAttribute('aria-label') ||
              '',
          );

          if (!isValidCandidateTitle(candidateTitle, hostClean)) {
            // Slug fallback e.g. /8abc/video/my_video_slug
            try {
              var p = new URL(canonical).pathname.split('/').filter(Boolean);
              if (p.length >= 2 && (p[1] === 'video' || p[0] === 'video' || p[1] === 'v')) {
                var slug = (p[1] === 'video' && p[2]) ? p[2] : ((p[0] === 'video' && p[1]) ? p[1] : '');
                if (slug) {
                  var unslug = slug.replace(/[-_+]/g, ' ').trim();
                  if (unslug.length > 2) {
                    candidateTitle = unslug.charAt(0).toUpperCase() + unslug.slice(1);
                  }
                }
              }
            } catch (e) {}
          }

          var title = (isValidCandidateTitle(candidateTitle, hostClean) ? candidateTitle : '') || (hostClean + ' video');

          var durationSec = null;
          var durEl = card ? card.querySelector('.l, [class*="duration"], [class*="time"], [class*="length"]') : null;
          if (durEl) {
            var dText = (durEl.textContent || '').trim();
            var dMatch = dText.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
            if (dMatch) {
              durationSec = dMatch[3] !== undefined
                ? parseInt(dMatch[1], 10) * 3600 + parseInt(dMatch[2], 10) * 60 + parseInt(dMatch[3], 10)
                : parseInt(dMatch[1], 10) * 60 + parseInt(dMatch[2], 10);
            }
          }

          var authorName = hostClean;
          var userEl = card ? card.querySelector('.user a, .user, [class*="uploader"], [class*="author"], [class*="channel"]') : null;
          if (userEl) {
            var uName = cleanText(userEl.textContent).replace(/^@/, '');
            if (uName && uName.length < 35 && isValidCandidateTitle(uName, hostClean)) {
              authorName = uName;
            }
          }

          if (seenIds[itemId]) {
            // Enhance previously added item from preview <video> loop
            for (var itIdx = 0; itIdx < items.length; itIdx++) {
              if (items[itIdx].id === itemId) {
                if (!items[itIdx].thumbnailUrl && thumb) items[itIdx].thumbnailUrl = thumb;
                if ((!items[itIdx].title || items[itIdx].title === (hostClean + ' video') || items[itIdx].title.indexOf('Free Porn') !== -1) && title && title !== (hostClean + ' video')) {
                  items[itIdx].title = title;
                }
                if (!items[itIdx].durationSeconds && durationSec) items[itIdx].durationSeconds = durationSec;
                if (authorName && authorName !== hostClean) items[itIdx].author = authorName;
                break;
              }
            }
            return;
          }
          seenIds[itemId] = true;

          items.push({
            id: itemId,
            url: canonical,
            pageUrl: canonical,
            title: title,
            author: authorName,
            platform: platform,
            thumbnailUrl: thumb,
            durationSeconds: durationSec,
            width: null,
            height: null,
            sizeBytes: null,
            source: 'dom',
            sourceLabel: hostClean,
          });
        });
      }
    }

    return {
      ok: true,
      source: 'dom',
      mode: 'universal-feed',
      platform: platform,
      pageUrl: window.location.href,
      scannedArticles: items.length,
      truncated: false,
      items: items,
    };
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
      if (isSponsoredContent(article)) return;
      var videoElements = findXVideoElements(article);
      if (videoElements.length === 0) return;

      var post = findXPostLink(article);
      if (!post) return;

      videoElements.forEach(function (videoElement, videoIndex) {
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
          platform: 'x',
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
    var platform = currentPlatform();
    if (platform === 'generic') return;

    var result = extractUniversalFeed(X_FEED_MAX_ITEMS);
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
      var markAsEmitted = function () {
        newItems.forEach(function (item) {
          var id = String(item && item.id || '');
          if (id) X_FEED_EMITTED_IDS[id] = true;
        });
      };
      var p1 = api.runtime.sendMessage({
        type: 'MD_X_FEED_ITEMS',
        items: newItems,
        pageUrl: window.location.href,
        platform: platform,
      });
      var p2 = api.runtime.sendMessage({
        type: 'MD_FEED_ITEMS',
        items: newItems,
        pageUrl: window.location.href,
        platform: platform,
      });
      if (p1 && typeof p1.then === 'function') {
        p1.then(markAsEmitted).catch(function () {});
      } else {
        markAsEmitted();
      }
    } catch (e) {
      /* The extension context may be shutting down during navigation. */
    }
  }

  function scheduleXFeedUpdate(delay) {
    var platform = currentPlatform();
    if (platform === 'generic' || xFeedUpdateTimer) return;
    var wait = (typeof delay === 'number') ? delay : (platform === 'tiktok' ? 1200 : 250);
    xFeedUpdateTimer = setTimeout(publishNewXFeedItems, wait);
  }

  var deepScanActive = false;
  var deepScanTimer = null;
  var deepScanTarget = 1000;
  var deepScanLastCount = 0;
  var deepScanStagnantRounds = 0;
  var deepScanTotalRounds = 0;
  var deepScanBusy = false;
  var deepScanEpoch = 0;

  function isTikTokSnapFeedPage() {
    if (currentPlatform() !== 'tiktok') return false;
    var path = String(window.location.pathname || '/');
    if (
      path.indexOf('/collection/') !== -1 ||
      path.indexOf('/playlist/') !== -1 ||
      path.indexOf('/tag/') !== -1 ||
      path.indexOf('/music/') !== -1
    ) {
      return false;
    }
    if (/^\/@[^/]+\/?$/.test(path)) return false;
    if (document.querySelector('[data-e2e="recommend-list-item-container"]')) {
      return true;
    }
    if (path === '/' || path.indexOf('/foryou') === 0 || path.indexOf('/following') === 0) {
      return true;
    }
    return path.indexOf('/video/') !== -1;
  }

  function findScrollableAncestor(el) {
    var node = el;
    var hops = 0;
    while (node && hops < 18) {
      if (node === document.body || node === document.documentElement) break;
      try {
        var style = window.getComputedStyle(node);
        var overflowY = style.overflowY;
        if (
          (overflowY === 'auto' || overflowY === 'scroll' || overflowY === 'overlay') &&
          node.scrollHeight > node.clientHeight + 40
        ) {
          return node;
        }
      } catch (e) {}
      node = node.parentElement;
      hops += 1;
    }
    var scrolling = document.scrollingElement;
    if (scrolling && scrolling.scrollHeight > scrolling.clientHeight + 40) {
      return scrolling;
    }
    return null;
  }

  function isElementDisplayed(el) {
    if (!el || el.nodeType !== 1) return false;
    try {
      var style = window.getComputedStyle(el);
      if (style.display === 'none' || style.visibility === 'hidden') return false;
    } catch (e) {}
    return true;
  }

  function tiktokControlFingerprint(el) {
    if (!el) return '';
    return [
      el.getAttribute && el.getAttribute('data-e2e'),
      el.getAttribute && el.getAttribute('aria-label'),
      el.getAttribute && el.getAttribute('title'),
      el.textContent,
    ].join(' ').toLowerCase();
  }

  function isUnsafeTikTokControl(el) {
    var text = tiktokControlFingerprint(el);
    return /like|comment|share|partag|bookmark|favorite|music|follow|suivre|search|inbox|download|t[eé]l[eé]charg|report|copy link|copier le lien|not interested/.test(text);
  }

  function dismissShareIfOpen() {
    var share = document.querySelector(
      '[data-e2e="share-board"], [data-e2e="video-share-container"], [data-e2e="bottom-share-board"]',
    );
    if (!share) return;
    try {
      document.dispatchEvent(new KeyboardEvent('keydown', {
        key: 'Escape',
        code: 'Escape',
        keyCode: 27,
        which: 27,
        bubbles: true,
        cancelable: true,
      }));
    } catch (e) {}
    var close = document.querySelector(
      '[data-e2e="modal-close-inner-button"], [data-e2e="bottom-close"]',
    );
    if (close && typeof close.click === 'function') {
      try { close.click(); } catch (e) {}
    }
  }

  function findSnapScroller(fromEl) {
    var node = fromEl;
    var hops = 0;
    var minHeight = Math.min(240, (window.innerHeight || 600) * 0.35);
    while (node && hops < 24) {
      if (node === document.body || node === document.documentElement) break;
      try {
        var style = window.getComputedStyle(node);
        var overflowY = String(style.overflowY || '');
        var snap = String(style.scrollSnapType || '');
        var canScroll = node.scrollHeight > node.clientHeight + 24;
        var overflowOk =
          overflowY === 'auto' ||
          overflowY === 'scroll' ||
          overflowY === 'overlay' ||
          overflowY === 'hidden';
        var snapOk =
          snap.indexOf('y') !== -1 ||
          snap.indexOf('mandatory') !== -1 ||
          snap.indexOf('proximity') !== -1;
        if (canScroll && (overflowOk || snapOk)) {
          var rect = node.getBoundingClientRect();
          if (rect.height >= minHeight) return node;
        }
      } catch (e) {}
      node = node.parentElement;
      hops += 1;
    }
    return findScrollableAncestor(fromEl);
  }

  function findPrimaryFeedScroller() {
    var seeds = [
      document.querySelector('[data-e2e="user-post-item-list"]'),
      document.querySelector('[data-e2e="playlist-video-list"]'),
      document.querySelector('[class*="DivItemContainerList"]'),
      document.querySelector('[class*="DivThreeColumnContainer"]'),
      document.querySelector('[class*="DivVideoFeed"]'),
      document.querySelector('main'),
    ];
    for (var i = 0; i < seeds.length; i++) {
      if (!seeds[i]) continue;
      var scroller = findScrollableAncestor(seeds[i]);
      if (scroller) return scroller;
    }
    var se = document.scrollingElement || document.documentElement;
    if (se && se.scrollHeight > se.clientHeight + 40) return se;
    return null;
  }

  function scrollPrimaryFeed(delta, smooth) {
    var el = findPrimaryFeedScroller();
    if (!el) return false;
    var amount = Math.round(delta || window.innerHeight * 0.82 || 640);
    try {
      el.scrollBy({ top: amount, behavior: smooth ? 'smooth' : 'auto' });
    } catch (e) {
      el.scrollTop += amount;
    }
    return true;
  }

  function clickTikTokNextControl() {
    var nodes = document.querySelectorAll(
      '[data-e2e="arrow-down"], [data-e2e="browse-arrow-down"], ' +
      'button[aria-label*="Next"], button[aria-label*="next"], ' +
      'button[aria-label*="suivante"], button[aria-label*="Suivante"]',
    );
    for (var i = 0; i < nodes.length; i++) {
      var btn = nodes[i].closest('button') || nodes[i];
      if (!btn || typeof btn.click !== 'function' || !isElementDisplayed(btn)) continue;
      if (isUnsafeTikTokControl(btn)) continue;
      try {
        btn.click();
        return true;
      } catch (e) {}
    }
    return false;
  }

  function visibleSnapItem() {
    var items = document.querySelectorAll(
      '[data-e2e="recommend-list-item-container"], [data-e2e="feed-video"]',
    );
    if (!items.length) return null;
    var mid = window.innerHeight * 0.45;
    for (var i = 0; i < items.length; i++) {
      var box = items[i].getBoundingClientRect();
      if (box.top <= mid && box.bottom > mid) {
        return { items: items, index: i, el: items[i] };
      }
    }
    return { items: items, index: 0, el: items[0] };
  }

  function advanceTikTokSnapFeed() {
    dismissShareIfOpen();
    if (clickTikTokNextControl()) return true;

    var vis = visibleSnapItem();
    if (vis && vis.index + 1 < vis.items.length) {
      var next = vis.items[vis.index + 1];
      try {
        next.scrollIntoView({ behavior: 'instant', block: 'start', inline: 'nearest' });
      } catch (e) {
        try { next.scrollIntoView(true); } catch (e2) {}
      }
      return true;
    }

    var column = (vis && vis.el) || document.querySelector('video') || document.body;
    var scroller = findSnapScroller(column);
    if (scroller) {
      var step = Math.round(
        (vis && vis.el ? vis.el.getBoundingClientRect().height : 0) ||
        scroller.clientHeight ||
        window.innerHeight ||
        800,
      );
      var before = scroller.scrollTop;
      try {
        scroller.scrollBy({ top: step, behavior: 'instant' });
      } catch (e) {
        scroller.scrollTop = before + step;
      }
      // scrollBy can be asynchronous; checking scrollTop here used to mistake
      // a real navigation for a stall on TikTok's snap feed.
      return true;
    }
    // Synthetic wheel events are untrusted and TikTok ignores them. Report
    // inability to advance so the panel can show a useful error.
    return false;
  }

  function scrollAllFeedContainers(amount) {
    scrollPrimaryFeed(amount, true);
  }

  function performDeepScanStep() {
    if (!deepScanActive || deepScanBusy) return;
    deepScanBusy = true;
    var epoch = deepScanEpoch;

    var snapFeed = isTikTokSnapFeedPage();
    var isBg = typeof document !== 'undefined' && document.hidden;

    document.querySelectorAll('[data-e2e="load-more-btn"]').forEach(function (btn) {
      if (btn && typeof btn.click === 'function') {
        try { btn.click(); } catch (e) {}
      }
    });

    if (snapFeed) {
      if (!advanceTikTokSnapFeed()) {
        finishDeepScan(X_FEED_CACHE.length, 'navigation_unavailable');
        return;
      }
    } else {
      var lastTile = document.querySelector(
        'div[data-e2e="user-post-item"]:last-of-type, [data-e2e="loading-more"]',
      );
      if (lastTile && typeof lastTile.scrollIntoView === 'function' && deepScanTotalRounds % 4 === 0) {
        try {
          lastTile.scrollIntoView({ behavior: isBg ? 'auto' : 'smooth', block: 'end' });
        } catch (e) {}
      } else {
        scrollPrimaryFeed(Math.round(window.innerHeight * 0.82) || 640, !isBg);
      }
    }

    publishNewXFeedItems();
    var count = X_FEED_CACHE.length;

    try {
      api.runtime.sendMessage({
        type: 'MD_DEEP_SCAN_PROGRESS',
        count: count,
        target: deepScanTarget,
        done: false,
      });
    } catch (e) {}

    if (count >= deepScanTarget) {
      finishDeepScan(count);
      return;
    }

    if (count === deepScanLastCount) {
      deepScanStagnantRounds++;
    } else {
      deepScanStagnantRounds = 0;
      deepScanLastCount = count;
    }

    // FYP advances 1 video per tick; allow a longer stall before giving up.
    var maxStagnant = snapFeed ? (isBg ? 120 : 60) : (isBg ? 80 : 30);
    if (deepScanStagnantRounds >= maxStagnant || deepScanTotalRounds >= 500) {
      finishDeepScan(count);
      return;
    }

    deepScanTotalRounds++;
    setTimeout(function () {
      if (epoch === deepScanEpoch) deepScanBusy = false;
    }, snapFeed ? 720 : 480);
  }

  function startDeepScan(targetMax) {
    stopDeepScan();
    deepScanActive = true;
    deepScanTarget = Math.min(parseInt(targetMax, 10) || 1000, 2000);
    deepScanLastCount = 0;
    deepScanStagnantRounds = 0;
    deepScanTotalRounds = 0;

    performDeepScanStep();

    if (deepScanTimer) clearInterval(deepScanTimer);
    var stepMs = isTikTokSnapFeedPage() ? 1300 : 1100;
    deepScanTimer = setInterval(function () {
      if (!deepScanActive) {
        clearInterval(deepScanTimer);
        deepScanTimer = null;
        return;
      }
      performDeepScanStep();
    }, stepMs);
  }

  function finishDeepScan(finalCount, error) {
    deepScanEpoch += 1;
    deepScanActive = false;
    deepScanBusy = false;
    if (deepScanTimer) {
      clearInterval(deepScanTimer);
      deepScanTimer = null;
    }
    try {
      api.runtime.sendMessage({
        type: 'MD_DEEP_SCAN_PROGRESS',
        count: finalCount,
        target: deepScanTarget,
        done: true,
        error: error || null,
      });
    } catch (e) {}
  }

  function stopDeepScan() {
    deepScanEpoch += 1;
    deepScanActive = false;
    deepScanBusy = false;
    if (deepScanTimer) {
      clearInterval(deepScanTimer);
      deepScanTimer = null;
    }
    try { window.dispatchEvent(new CustomEvent('__MD_STOP_BG_FORCE__')); } catch (e) {}
  }

  var lastObservedUrl = window.location.href;
  function checkUrlChange() {
    if (window.location.href !== lastObservedUrl) {
      lastObservedUrl = window.location.href;
      X_FEED_CACHE = [];
      X_FEED_CACHE_INDEX = Object.create(null);
      X_FEED_EMITTED_IDS = {};
      try {
        api.runtime.sendMessage({
          type: 'MD_PAGE_NAVIGATED',
          pageUrl: window.location.href,
          title: document.title,
        });
      } catch (e) {}
      setTimeout(publishNewXFeedItems, 350);
    }
  }
  window.addEventListener('popstate', checkUrlChange);
  setInterval(checkUrlChange, 1200);

  function findPlatformSpecificUrl(element) {
    var pageUrl = window.location.href;
    var platform = currentPlatform();

    if (platform === 'x') {
      var permalink = resolveXPermalinkFromElement(element);
      if (permalink) return permalink;
      return null;
    }

    if (platform === 'tiktok') {
      var ttContainer = (element.closest && element.closest('[data-e2e="recommend-list-item-container"], div[class*="DivItemContainer"], [data-e2e="feed-video"], section')) || element.parentElement;
      if (ttContainer) {
        var ttLink = ttContainer.querySelector('a[href*="/video/"]');
        if (ttLink && ttLink.href) {
          return (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl) ? MDUrl.canonicalMediaUrl(ttLink.href) : ttLink.href.split('?')[0];
        }
        var xgEl = ttContainer.querySelector('[id^="xgwrapper-"]') || (ttContainer.id && ttContainer.id.indexOf('xgwrapper-') === 0 ? ttContainer : null);
        if (!xgEl && element.closest) xgEl = element.closest('[id^="xgwrapper-"]');
        if (xgEl) {
          var xgMatch = xgEl.id.match(/xgwrapper-\d+-(\d+)/);
          if (xgMatch) {
            var authorEl = ttContainer.querySelector('a[href*="/@"]');
            var authorM = authorEl ? authorEl.href.match(/@([a-zA-Z0-9_.-]+)/) : null;
            var authorHandle = authorM ? '@' + authorM[1] : '';
            return authorHandle ? 'https://www.tiktok.com/' + authorHandle + '/video/' + xgMatch[1] : 'https://www.tiktok.com/video/' + xgMatch[1];
          }
        }
      }
      if (pageUrl.indexOf('/video/') !== -1) {
        return (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl) ? MDUrl.canonicalMediaUrl(pageUrl) : pageUrl.split('?')[0];
      }
    }

    if (platform === 'instagram') {
      var igContainer = (element.closest && element.closest('article, div[role="dialog"], [class*="Reels"], div[style*="aspect-ratio"]')) || element.parentElement;
      if (igContainer) {
        var igLink = igContainer.querySelector('a[href*="/reel/"], a[href*="/reels/"], a[href*="/p/"]');
        if (igLink && igLink.href) {
          return (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl) ? MDUrl.canonicalMediaUrl(igLink.href) : igLink.href.split('?')[0];
        }
      }
      if (pageUrl.indexOf('/reel/') !== -1 || pageUrl.indexOf('/reels/') !== -1 || pageUrl.indexOf('/p/') !== -1) {
        return (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl) ? MDUrl.canonicalMediaUrl(pageUrl) : pageUrl.split('?')[0];
      }
    }

    if (platform === 'youtube') {
      var ytContainer = (element.closest && element.closest('ytd-reel-video-renderer, ytd-rich-item-renderer, ytd-video-renderer, #player')) || element.parentElement;
      if (ytContainer) {
        var ytLink = ytContainer.querySelector('a[href*="/shorts/"], a[href*="/watch?v="]');
        if (ytLink && ytLink.href) {
          return (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl) ? MDUrl.canonicalMediaUrl(ytLink.href) : ytLink.href.split('&')[0];
        }
      }
      if (pageUrl.indexOf('/shorts/') !== -1 || pageUrl.indexOf('/watch?v=') !== -1) {
        return (typeof MDUrl !== 'undefined' && MDUrl.canonicalMediaUrl) ? MDUrl.canonicalMediaUrl(pageUrl) : pageUrl.split('&')[0];
      }
    }

    if (platform === 'kick') {
      return pageUrl.split('?')[0];
    }

    function findNearestPermalink(el) {
      var generic = findGenericPermalink(el);
      if (generic) return generic;
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
        'a[href*="/watch?v="], a[href*="/reel/"], a[href*="/reels/"], a[href*="/video/"]',
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
      var sources = element.querySelectorAll ? element.querySelectorAll('source[src]') : [];
      for (var s = 0; s < sources.length; s++) {
        var sUrl = sources[s].src;
        if (sUrl && sUrl.indexOf('blob:') !== 0) return sUrl;
      }
      return pageUrlFallback();
    } else if (element.tagName === 'A') {
      return element.href;
    }

    return pageUrlFallback();
  }

  function resolveBestDownloadUrl(targetUrl, callback) {
    if (targetUrl && targetUrl.indexOf('blob:') !== 0 && targetUrl.indexOf('http') === 0) {
      callback(targetUrl);
      return;
    }
    if (api.runtime && api.runtime.sendMessage) {
      try {
        api.runtime.sendMessage({ type: 'GET_SNIFFED_STREAMS' }, function (res) {
          if (!api.runtime.lastError && res && res.ok && Array.isArray(res.streams) && res.streams.length > 0) {
            var latest = res.streams[res.streams.length - 1];
            if (latest && latest.url) {
              callback(latest.url);
              return;
            }
          }
          callback(targetUrl || window.location.href);
        });
        return;
      } catch (e) {}
    }
    callback(targetUrl || window.location.href);
  }

  function sendDownload(targetUrl, opts, extra, onResult) {
    resolveBestDownloadUrl(targetUrl, function (resolvedUrl) {
      try {
        api.runtime.sendMessage(
          {
            type: 'DOWNLOAD_BTN_CLICK',
            url: resolvedUrl,
            pageUrl: pageUrlFallback(),
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
    });
  }

  function createButtonUI(targetUrl, tweetId, mediaId, container, options) {
    options = options || {};
    var isCardOverlay = Boolean(options.isCardOverlay);
    var parentCard = options.parentCard || container;

    var host = document.createElement('div');
    host.className = 'md-dl-host';
    if (tweetId) host.dataset.tweetId = tweetId;
    if (mediaId) host.dataset.mediaId = mediaId;
    Object.assign(host.style, {
      position: 'absolute',
      zIndex: '2147483647',
      pointerEvents: 'none',
    });

    var isVerticalVideo = false;
    if (container) {
      var rect = container.getBoundingClientRect ? container.getBoundingClientRect() : null;
      if (rect && rect.height > rect.width * 1.05) {
        isVerticalVideo = true;
      }
    }
    if (!isVerticalVideo && typeof MDUrl !== 'undefined' && MDUrl.isReelOrShortsUrl && MDUrl.isReelOrShortsUrl(targetUrl || window.location.href)) {
      isVerticalVideo = true;
    }

    var shadow = host.attachShadow({ mode: 'closed' });
    var style = document.createElement('style');
    shadow.appendChild(style);

    function applyStyles() {
      var isLeftAligned = isVerticalVideo;
      if (isVerticalVideo) {
        host.style.top = '16px';
        host.style.left = '16px';
        host.style.right = 'auto';
        host.style.bottom = 'auto';
      } else {
        host.style.top = '8px';
        host.style.right = '8px';
        host.style.left = 'auto';
        host.style.bottom = 'auto';
      }

      var menuPosCss = isLeftAligned ? 'left:0;right:auto;' : 'right:0;left:auto;';
      style.textContent =
        ':host{all:initial}' +
        '.wrap{display:flex;align-items:center;pointer-events:auto;font-family:Inter,Segoe UI,Arial,sans-serif;border:1px solid #55555b;border-radius:8px;background:#1f1f23;box-shadow:0 3px 10px rgba(0,0,0,.32)}' +
        'button{min-height:44px;border:0;color:#fafafa;cursor:pointer;font-size:12px;font-weight:600;display:inline-flex;align-items:center;justify-content:center;gap:6px;user-select:none;background:transparent}' +
        'button:focus-visible{outline:2px solid #50d4c7;outline-offset:2px}' +
        'button:disabled{cursor:default}' +
        '.main{border-radius:8px 0 0 8px;padding:6px 10px;line-height:1.3}' +
        '.main.solo{border-radius:8px}' +
        '.main:hover,.toggle:hover{background:#303036}' +
        '.toggle{min-width:44px;border-radius:0 8px 8px 0;padding:6px 9px;border-left:1px solid #444449;line-height:1.3}' +
        '.menu{position:absolute;top:100%;' + menuPosCss + 'display:none;flex-direction:column;min-width:140px;background:#27272b;border:1px solid #55555b;border-radius:8px;overflow:hidden;box-shadow:0 7px 20px rgba(0,0,0,.4);margin-top:4px;z-index:100}' +
        '.menu.open{display:flex}' +
        '.item{min-height:44px;padding:8px 12px;color:#fafafa;justify-content:flex-start;border-radius:0}' +
        '.item:hover,.item:focus-visible{background:#3a3a41}' +
        '.ok{color:#86efac!important}.err{color:#fca5a5!important}';
    }
    applyStyles();

    if (isCardOverlay && parentCard) {
      host.style.opacity = '0';
      host.style.pointerEvents = 'none';
      host.style.transition = 'opacity 0.2s ease, transform 0.2s ease';
      host.style.transform = 'translateY(-2px)';

      var showHost = function () {
        host.style.opacity = '1';
        host.style.pointerEvents = 'auto';
        host.style.transform = 'translateY(0)';
      };

      var hideHost = function () {
        if (markedDownloaded) return;
        if (menu && menu.classList.contains('open')) return;
        if (host.matches(':focus-within')) return;
        host.style.opacity = '0';
        host.style.pointerEvents = 'none';
        host.style.transform = 'translateY(-2px)';
      };

      parentCard.addEventListener('mouseenter', showHost, { passive: true });
      parentCard.addEventListener('mouseleave', hideHost, { passive: true });
      parentCard.addEventListener('focusin', showHost);
      parentCard.addEventListener('focusout', function () { setTimeout(hideHost, 0); });
      parentCard.addEventListener('touchstart', showHost, { passive: true });
      if (container !== parentCard) {
        container.addEventListener('mouseenter', showHost, { passive: true });
        container.addEventListener('mouseleave', hideHost, { passive: true });
      }
      if (window.matchMedia && window.matchMedia('(hover: none)').matches) showHost();
    }

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
      toggle.setAttribute('aria-expanded', 'false');
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
        var item = document.createElement('button');
        item.type = 'button';
        item.className = 'item';
        item.textContent = opt.label;
        item.addEventListener('click', function (e) {
          e.stopPropagation();
          if (markedDownloaded) return;
          selectedQuality = opt.val;
          btn.textContent = opt.val === 'audio' ? t('qualityAudio', 'Audio') : opt.label;
          menu.classList.remove('open');
          toggle.setAttribute('aria-expanded', 'false');
        });
        menu.appendChild(item);
      });

      toggle.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        if (markedDownloaded) return;
        menu.classList.toggle('open');
        toggle.setAttribute('aria-expanded', String(menu.classList.contains('open')));
      });
      wrap.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && menu.classList.contains('open')) {
          menu.classList.remove('open');
          toggle.setAttribute('aria-expanded', 'false');
          toggle.focus();
        }
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
              ? t('unsupportedUrl', 'Unsupported')
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
      applyStyles: applyStyles,
    };
  }

  function findVideoContainer(video) {
    if (!video || !video.parentElement) return null;
    var platform = currentPlatform();

    if (platform === 'tiktok') {
      var ttWrapper = video.closest(
        '[class*="DivBasicPlayerWrapper"], [class*="DivContainer"], [class*="PlayerContainer"], [data-e2e="recommend-list-item-container"], [data-e2e="feed-video"]'
      );
      if (ttWrapper) {
        var ttRect = ttWrapper.getBoundingClientRect();
        if (ttRect.height > 80) return ttWrapper;
      }
    }

    if (platform === 'instagram') {
      var igWrapper = video.closest('article, div[role="dialog"], [class*="Reels"], div[style*="aspect-ratio"]');
      if (igWrapper) {
        var igRect = igWrapper.getBoundingClientRect();
        if (igRect.height > 80) return igWrapper;
      }
    }

    if (platform === 'youtube') {
      var ytWrapper = video.closest('ytd-reel-video-renderer, ytd-player, #player, .html5-video-player');
      if (ytWrapper) {
        var ytRect = ytWrapper.getBoundingClientRect();
        if (ytRect.height > 80) return ytWrapper;
      }
    }

    // Generic fallback:
    // If video is position:absolute or parent has zero height, search upwards for nearest positioned ancestor with real height
    var parent = video.parentElement;
    var vPos = window.getComputedStyle(video).position;
    var pRect = parent.getBoundingClientRect();
    if (vPos === 'absolute' || pRect.height < 30) {
      var curr = parent;
      while (curr && curr !== document.body && curr !== document.documentElement) {
        var cPos = window.getComputedStyle(curr).position;
        var cRect = curr.getBoundingClientRect();
        if (cPos !== 'static' && cRect.height > 40) {
          return curr;
        }
        curr = curr.parentElement;
      }
    }

    return parent;
  }

  function ensureRelative(container) {
    if (!container) return;
    var rect = container.getBoundingClientRect();
    // NEVER mutate a 0-height container: it would collapse absolute children to 0px height!
    if (rect.height <= 0 || rect.width <= 0) return;
    var style = window.getComputedStyle(container);
    if (style.position === 'static') {
      // Do not change position if container has absolute video children that rely on outer container
      var hasAbsVideo = false;
      for (var i = 0; i < container.children.length; i++) {
        if (container.children[i].tagName === 'VIDEO' && window.getComputedStyle(container.children[i]).position === 'absolute') {
          hasAbsVideo = true;
          break;
        }
      }
      if (!hasAbsVideo) {
        container.style.position = 'relative';
      }
    }
  }

  function injectButton(container, targetUrl, options) {
    if (!container || PROCESSED.has(container)) return;
    if (isSponsoredContent(container)) return;
    options = options || {};
    var parentCard = options.parentCard || container;
    if (parentCard.querySelector && parentCard.querySelector('.md-dl-host')) return;

    ensureRelative(container);
    var tweetId = xTweetIdFromUrl(targetUrl);
    var mediaId = findMediaAssetIdNear(container);
    var ui = createButtonUI(targetUrl, tweetId, mediaId, container, options);
    container.appendChild(ui.host);
    injectedButtons.push(ui);
    PROCESSED.add(container);
    if (parentCard && parentCard !== container) PROCESSED.add(parentCard);
    if (isKnownDownloaded(tweetId, mediaId)) {
      ui.setDownloaded();
    }
  }

  function scan() {
    if (!document.body) return;
    if (isAdFrameHost()) return;

    document.querySelectorAll('video').forEach(function (video) {
      if (!video.parentElement) return;
      if (isExcludedNavigation(video) || isExcludedNavigation(video.parentElement)) return;
      if (isSponsoredContent(video) || isSponsoredContent(video.parentElement)) return;
      if (!isUsableVideo(video)) return;
      var url = findPlatformSpecificUrl(video);
      if (!url) return;
      var targetContainer = findVideoContainer(video);
      if (targetContainer) injectButton(targetContainer, url);
    });

    var platform = currentPlatform();
    if (platform === 'x' || platform === 'facebook') {
      document.querySelectorAll('a').forEach(function (a) {
        if (PROCESSED.has(a)) return;
        if (isExcludedNavigation(a)) return;
        if (isSponsoredContent(a)) return;
        var href = a.href;
        if (!href || !VIDEO_PATTERNS.some(function (p) { return href.indexOf(p) !== -1; })) return;
        var rect = a.getBoundingClientRect();
        if (rect.width > 100 && rect.height > 60) {
          injectButton(a, href);
        }
      });
    } else if (!inIframe && (platform === 'generic' || platform === 'kick')) {
      document.querySelectorAll('a[href]').forEach(function (a) {
        if (PROCESSED.has(a)) return;
        if (isExcludedNavigation(a)) return;
        if (platform === 'kick' && !isKickVideoLink(a.href)) return;
        if (!looksLikeVideoCard(a)) return;
        if (isSponsoredContent(a)) return;

        // Strictly 1 button per card container
        var card = (a.closest && a.closest('div[class*="group"], div[class*="card"], div[class*="item"], article, li, figure')) || a.parentElement || a;
        if (card) {
          if (PROCESSED.has(card) || (card.querySelector && card.querySelector('.md-dl-host'))) {
            PROCESSED.add(a);
            return;
          }
        }

        // Mount on the thumbnail image/video container rather than raw text links
        var mountTarget = a;
        if (card && !a.querySelector('img, video')) {
          var imgEl = card.querySelector('img, video');
          if (imgEl) {
            var thumbParent = imgEl.closest('a') || imgEl.parentElement;
            if (thumbParent) mountTarget = thumbParent;
          }
        }

        injectButton(mountTarget, a.href, { isCardOverlay: true, parentCard: card });
        PROCESSED.add(a);
        if (card) PROCESSED.add(card);
      });
    }

    scheduleXFeedUpdate();
  }

  function clearFullscreenOverlay() {
    var old = document.querySelector('.md-dl-fs-host');
    if (old && old.parentNode) old.parentNode.removeChild(old);
  }

  function injectFullscreenButton() {
    clearFullscreenOverlay();
    var fs = document.fullscreenElement || document.webkitFullscreenElement;
    if (!fs) return;
    var video = fs.tagName === 'VIDEO' ? fs : (fs.querySelector ? fs.querySelector('video') : null);
    if (!video) return;
    if (isSponsoredContent(video)) return;
    var url = findPlatformSpecificUrl(video) || pageUrlFallback();
    if (fs.tagName === 'VIDEO') {
      var mount = fs.parentElement;
      if (!mount || mount === document.body) return;
      var ui = createButtonUI(url, xTweetIdFromUrl(url), findMediaAssetIdNear(video), mount);
      ui.host.classList.add('md-dl-fs-host');
      ui.host.style.position = 'fixed';
      ui.host.style.top = '16px';
      ui.host.style.right = '16px';
      ui.host.style.left = 'auto';
      ui.host.style.bottom = 'auto';
      try {
        fs.appendChild(ui.host);
      } catch (e) {
        mount.appendChild(ui.host);
      }
      injectedButtons.push(ui);
      return;
    }
    injectButton(fs, url);
    var hosts = fs.querySelectorAll ? fs.querySelectorAll('.md-dl-host') : [];
    if (hosts.length) hosts[hosts.length - 1].classList.add('md-dl-fs-host');
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
    if (isAdFrameHost()) return;
    if (!document.body) {
      document.addEventListener('DOMContentLoaded', start, { once: true });
      return;
    }
    if (inIframe && api.runtime && api.runtime.sendMessage) {
      try {
        api.runtime.sendMessage({ type: 'GET_TAB_URL' }, function (res) {
          if (!api.runtime.lastError && res && res.url) {
            tabPageUrl = res.url;
          }
        });
      } catch (e) {}
    }
    scan();
    document.addEventListener('fullscreenchange', function () {
      injectFullscreenButton();
    });
    document.addEventListener('webkitfullscreenchange', function () {
      injectFullscreenButton();
    });
    var observer = new MutationObserver(function (mutations) {
      var hasNodes = false;
      for (var i = 0; i < mutations.length; i++) {
        if (mutations[i].addedNodes && mutations[i].addedNodes.length > 0) {
          hasNodes = true;
          break;
        }
      }
      if (!hasNodes) return;
      scheduleScan();
      scheduleXFeedUpdate(1200);
      scheduleTikTokSyncBanner(150);
    });
    observer.observe(document.body, { childList: true, subtree: true });

    window.addEventListener('scroll', function () {
      scheduleXFeedUpdate(1200);
    }, { passive: true });
  }

  function locateMediaOnPage(item) {
    if (!item) return false;
    var targetUrl = (item.url || item.pageUrl || '').split('?')[0].replace(/\/$/, '');
    var targetPath = '';
    try {
      if (targetUrl) targetPath = new URL(targetUrl).pathname.replace(/\/$/, '');
    } catch (e) {}

    var candidate = null;

    // 1. Search anchor tags
    if (targetUrl || targetPath) {
      var anchors = document.querySelectorAll('a[href]');
      for (var i = 0; i < anchors.length; i++) {
        var a = anchors[i];
        var href = (a.href || '').split('#')[0].split('?')[0].replace(/\/$/, '');
        if (targetUrl && href === targetUrl) {
          candidate = a;
          break;
        }
        if (targetPath && targetPath.length > 3 && href.indexOf(targetPath) !== -1) {
          candidate = a;
          break;
        }
      }
    }

    // 2. Search videos
    if (!candidate && item.videoSrc) {
      var videos = document.querySelectorAll('video');
      for (var v = 0; v < videos.length; v++) {
        var vid = videos[v];
        if (vid.currentSrc === item.videoSrc || vid.src === item.videoSrc) {
          candidate = vid;
          break;
        }
      }
    }

    // 3. Search thumbnail image
    if (!candidate && item.thumbnailUrl) {
      var cleanThumb = item.thumbnailUrl.split('?')[0];
      var imgs = document.querySelectorAll('img[src], img[data-src], img[data-thumbnail], img[data-thumb]');
      for (var m = 0; m < imgs.length; m++) {
        var img = imgs[m];
        var src = (img.currentSrc || img.src || img.getAttribute('data-src') || img.getAttribute('data-thumbnail') || '').split('?')[0];
        if (src && cleanThumb && (src === cleanThumb || src.indexOf(cleanThumb) !== -1 || cleanThumb.indexOf(src) !== -1)) {
          candidate = img;
          break;
        }
      }
    }

    // 4. Search by title
    if (!candidate && item.title && item.title.length > 5 && item.title !== 'Vidéo') {
      var headings = document.querySelectorAll('h1, h2, h3, h4, a[title], [class*="title"]');
      for (var h = 0; h < headings.length; h++) {
        var heading = headings[h];
        if ((heading.textContent || '').trim().indexOf(item.title.trim()) !== -1) {
          candidate = heading;
          break;
        }
      }
    }

    // 5. Fallback: if currently on active video page and item corresponds to current page
    if (!candidate && targetUrl && window.location.href.split('?')[0].replace(/\/$/, '') === targetUrl) {
      candidate = document.querySelector('video') || document.querySelector('main') || document.body;
    }

    if (!candidate) return false;

    // Resolve nearest card / player container
    var box = candidate.closest ? candidate.closest(
      'article, [class*="card"], [class*="item"], [class*="video-item"], [data-e2e*="item"], [class*="player"], figure, li'
    ) : null;
    var el = box || candidate;

    try {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      var origOutline = el.style.outline;
      var origOffset = el.style.outlineOffset;
      var origShadow = el.style.boxShadow;
      var origTransition = el.style.transition;
      var origZ = el.style.zIndex;

      el.style.transition = 'outline 0.25s ease, box-shadow 0.25s ease, transform 0.25s ease';
      el.style.outline = '2px solid #0d9488';
      el.style.outlineOffset = '4px';
      el.style.boxShadow = '0 0 0 4px rgba(13, 148, 136, 0.18)';
      el.style.transform = 'scale(1.02)';

      setTimeout(function () {
        el.style.transform = '';
      }, 300);

      setTimeout(function () {
        el.style.outline = origOutline || '';
        el.style.outlineOffset = origOffset || '';
        el.style.boxShadow = origShadow || '';
        el.style.transition = origTransition || '';
        el.style.zIndex = origZ || '';
      }, 3000);

      return true;
    } catch (e) {
      return false;
    }
  }

  if (api.runtime && api.runtime.onMessage) {
    api.runtime.onMessage.addListener(function (message, sender, sendResponse) {
      if (!message || typeof message.type !== 'string') return false;
      if (message.type === 'MD_X_ACTION') {
        if (window !== window.top || !isXPage()) return false;
        // Only the extension's background relays X actions (tabs.sendMessage has no sender.tab).
        if (!sender || sender.id !== api.runtime.id || sender.tab) {
          sendResponse({ ok: false, error: 'forbidden' });
          return false;
        }
        if (!self.MDXActions) {
          sendResponse({ ok: false, code: 'unknown', message: 'Rechargez l’onglet x.com.' });
          return false;
        }
        self.MDXActions.perform(message.op, message.tweetId, {
          // Firefox: content.fetch sends the request as the page (x.com origin), like Chrome's fetch does.
          fetch: typeof content === 'object' && content && typeof content.fetch === 'function'
            ? content.fetch.bind(content) : window.fetch.bind(window),
          document: document,
          now: Date.now,
          sleep: function (ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); },
        }).then(sendResponse, function () {
          sendResponse({ ok: false, code: 'unknown', message: 'Action impossible pour le moment.' });
        });
        return true;
      }
      if (message.type === 'MD_CLEAR_CACHE') {
        stopDeepScan();
        X_FEED_CACHE = [];
        X_FEED_CACHE_INDEX = Object.create(null);
        X_FEED_EMITTED_IDS = {};
        sendResponse({ ok: true });
        return false;
      }
      if (message.type === 'MD_START_DEEP_SCAN') {
        if (window !== window.top) return false;
        startDeepScan(message.maxTarget || 1000);
        sendResponse({ ok: true });
        return false;
      }
      if (message.type === 'MD_DEEP_SCAN_PULSE') {
        if (window !== window.top) return false;
        if (!deepScanActive) {
          startDeepScan(message.maxTarget || 1000);
        }
        sendResponse({ ok: true, active: deepScanActive });
        return false;
      }
      if (message.type === 'MD_STOP_DEEP_SCAN') {
        if (window !== window.top) return false;
        stopDeepScan();
        sendResponse({ ok: true });
        return false;
      }
      if (message.type === 'MD_DOWNLOAD_STATE') {
        mergeLocalKeys(
          message.tweetIds,
          message.mediaIds,
          message.removedTweetIds,
          message.tikTokIds,
          message.removedTikTokIds,
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
      if (message.type === 'MD_LOCATE_MEDIA') {
        try {
          var found = locateMediaOnPage(message.item);
          sendResponse({ ok: true, found: found });
        } catch (e) {
          sendResponse({ ok: false, found: false });
        }
        return false;
      }
      if (message.type === 'MD_SYNC_TIKTOK_COLLECTIONS') {
        if (window !== window.top) return false;
        if (syncCard.running) {
          sendResponse({ ok: false, error: 'sync_already_running' });
          return false;
        }
        syncCard.running = true;
        syncCardRunning(null);
        extractTikTokCollections({
          update: function (_message, info) { syncCardRunning(info || null); },
        }).then(function (res) {
          if (res && res.ok && res.collections && res.collections.length) {
            syncCardDone(res, countRecoveredVideos(res.collections));
          } else {
            syncCardError(syncCardReason(res, null));
          }
          sendResponse(res);
        }).catch(function (err) {
          syncCardError(syncCardReason(null, err));
          sendResponse({ ok: false, error: (err && err.message) || String(err) });
        }).finally(function () {
          syncCard.running = false;
        });
        return true;
      }
      if (message.type === 'MD_EXTRACT_X_FEED' || message.type === 'MD_EXTRACT_FEED') {
        try {
          var result = extractUniversalFeed(message.maxItems);
          if (result && result.ok === true && Array.isArray(result.items)) {
            rememberXFeedItems(result.items);
            result.items = X_FEED_CACHE.map(function (id) {
              return X_FEED_CACHE_INDEX[id];
            }).filter(Boolean);
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
      }
    });
  }

  function waitForTikTok(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  function unwrapTikTokApiData(value) {
    var merged = {};
    var current = value;
    for (var depth = 0; depth < 4; depth++) {
      if (!current || typeof current !== 'object' || Array.isArray(current)) break;
      var statusCode = current.statusCode;
      if (statusCode == null) statusCode = current.status_code;
      if (statusCode != null && String(statusCode).trim() !== '0') {
        throw new Error('TikTok API rejected request');
      }
      Object.keys(current).forEach(function (key) {
        if (key !== 'data') merged[key] = current[key];
      });
      if (!current.data || typeof current.data !== 'object' || Array.isArray(current.data)) break;
      current = current.data;
    }
    return merged;
  }

  function parseTikTokJson(text) {
    // Preserve int64 identifiers and cursors before JSON.parse rounds them to
    // JavaScript's 53-bit number range.
    var safeText = String(text).replace(
      /(\"(?:collectionId|collection_id|collectId|collect_id|aweme_id|awemeId|aweme_id_str|awemeIdStr|video_id|videoId|item_id|itemId|id_str|idStr|id|cursor|next_cursor|nextCursor)\"\s*:\s*)(-?\d{16,})(?=\s*[,}])/g,
      '$1"$2"',
    );
    return JSON.parse(safeText);
  }

  async function fetchTikTokJson(url) {
    var attempt = 0;
    while (true) {
      var controller = new AbortController();
      var timer = setTimeout(function () { controller.abort(); }, 15000);
      try {
        var response = await fetch(url, {
          credentials: 'include',
          headers: { Accept: 'application/json' },
          signal: controller.signal,
        });
        if (!response.ok) {
          if ((response.status === 429 || response.status >= 500) && attempt < 3) {
            attempt++;
            await waitForTikTok(1000 * Math.pow(2, attempt));
            continue;
          }
          throw new Error('HTTP ' + response.status);
        }
        var payload = typeof response.text === 'function'
          ? parseTikTokJson(await response.text())
          : await response.json();
        return unwrapTikTokApiData(payload);
      } catch (e) {
        if (((e && e.name === 'AbortError') || /Failed to fetch|NetworkError|rejected request|rate limit/i.test((e && e.message) || '')) && attempt < 3) {
          attempt++;
          await waitForTikTok(1000 * Math.pow(2, attempt));
          continue;
        }
        throw e;
      } finally {
        clearTimeout(timer);
      }
    }
  }

  function parseTikTokCount(value) {
    if (typeof value === 'number') {
      return Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0;
    }
    if (typeof value !== 'string') return 0;
    var digits = value.replace(/[^\d]/g, '');
    return digits ? parseInt(digits, 10) || 0 : 0;
  }

  function normalizeCollectionToken(value) {
    return String(value || '')
      .normalize('NFKD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '');
  }

  function collectionLabelDetails(label, slug) {
    var rawTokens = String(label || '').trim().split(/\s+/).filter(Boolean);
    var normalizedTokens = rawTokens.map(normalizeCollectionToken);
    var slugTokens = String(slug || '')
      .replace(/[-_]+/g, ' ')
      .trim()
      .split(/\s+/)
      .map(normalizeCollectionToken)
      .filter(Boolean);

    // TikTok renders the collection name in more than one nested label on some
    // cards. Strip those exact slug prefixes before parsing the trailing count.
    var countTokens = normalizedTokens.slice();
    for (var removals = 0; slugTokens.length && removals < 3; removals++) {
      var matchAt = -1;
      for (var start = 0; start <= countTokens.length - slugTokens.length; start++) {
        var matchesSlug = slugTokens.every(function (token, index) {
          return countTokens[start + index] === token;
        });
        if (matchesSlug) {
          matchAt = start;
          break;
        }
      }
      if (matchAt < 0) break;
      countTokens.splice(matchAt, slugTokens.length);
    }

    var count = 0;
    var countTokenLength = 0;
    var lastToken = countTokens[countTokens.length - 1] || '';
    if (/^videos?$/.test(lastToken)) {
      countTokenLength = 1;
      var numericParts = [];
      for (var i = countTokens.length - 2; i >= 0; i--) {
        if (!/^[\d.,]+$/.test(countTokens[i])) break;
        numericParts.unshift(countTokens[i]);
        countTokenLength++;
      }
      if (numericParts.length) {
        count = parseTikTokCount(numericParts.join(''));
      } else {
        countTokenLength = 0;
      }
    }

    var nameTokens = countTokenLength
      ? rawTokens.slice(0, Math.max(0, rawTokens.length - countTokenLength))
      : rawTokens.slice();
    if (slugTokens.length) {
      // Keep the first visible copy of the name and remove repeated copies.
      var hasRepeatedSlugPrefix = true;
      while (hasRepeatedSlugPrefix && nameTokens.length >= slugTokens.length * 2) {
        hasRepeatedSlugPrefix = slugTokens.every(function (token, index) {
          return normalizeCollectionToken(nameTokens[index]) === token &&
            normalizeCollectionToken(nameTokens[index + slugTokens.length]) === token;
        });
        if (hasRepeatedSlugPrefix) {
          nameTokens.splice(slugTokens.length, slugTokens.length);
        }
      }
    }
    return { name: nameTokens.join(' ').trim(), total: count };
  }

  function normalizeTikTokImageUrl(value) {
    if (!value || typeof value !== 'string') return null;
    try {
      var url = new URL(value, 'https://www.tiktok.com');
      if (url.protocol !== 'https:') return null;
      var host = url.hostname.toLowerCase();
      var trustedHost = [
        'tiktokcdn.com',
        'tiktokv.com',
        'byteoversea.com',
        'ibytedtos.com',
        'byteimg.com',
      ].some(function (domain) {
        return host === domain || host.endsWith('.' + domain);
      });
      return trustedHost ? url.href : null;
    } catch (e) {
      return null;
    }
  }

  function tikTokCollectionCover(value, depth) {
    if (depth > 4 || value == null) return null;
    if (typeof value === 'string') return normalizeTikTokImageUrl(value);
    if (Array.isArray(value)) {
      for (var i = 0; i < value.length; i++) {
        var fromArray = tikTokCollectionCover(value[i], depth + 1);
        if (fromArray) return fromArray;
      }
      return null;
    }
    if (typeof value !== 'object') return null;
    var keys = [
      'coverUrl',
      'cover_url',
      'originCover',
      'origin_cover',
      'dynamicCover',
      'dynamic_cover',
      'thumbnail',
      'cover',
      'image',
      'urlList',
      'url_list',
      'url',
    ];
    for (var keyIndex = 0; keyIndex < keys.length; keyIndex++) {
      var candidate = value[keys[keyIndex]];
      if (candidate == null) continue;
      var fromProperty = tikTokCollectionCover(candidate, depth + 1);
      if (fromProperty) return fromProperty;
    }
    return null;
  }

  function collectionDescriptor(col) {
    var id = String(col.collectionId || col.collection_id || col.collectId || col.collect_id || col.id || '');
    if (!/^\d{8,}$/.test(id)) return null;
    var name = String(col.collectionName || col.name || col.collection_name || '').trim();
    if (!name) name = 'Collection ' + id;
    var totalFields = [
      col.total,
      col.item_count,
      col.itemCount,
      col.video_count,
      col.videoCount,
      col.aweme_count,
      col.awemeCount,
    ];
    var total = 0;
    for (var fieldIndex = 0; fieldIndex < totalFields.length; fieldIndex++) {
      total = parseTikTokCount(totalFields[fieldIndex]);
      if (total > 0) break;
    }
    var coverUrl = tikTokCollectionCover(col, 0);
    return { id: id, name: name, total: total, coverUrl: coverUrl };
  }

  function readTikTokHasMore(data) {
    var value = data.hasMore;
    if (value == null) value = data.has_more;
    if (value === true || value === 1) return true;
    if (value === false || value === 0) return false;
    if (typeof value === 'string') {
      var normalized = value.trim().toLowerCase();
      if (normalized === 'true' || normalized === '1') return true;
      if (normalized === 'false' || normalized === '0') return false;
    }
    return null;
  }

  function tikTokProfileSecUid() {
    var state = document.getElementById && document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__');
    if (!state || !state.textContent) return '';
    try {
      var scope = JSON.parse(state.textContent).__DEFAULT_SCOPE__ || {};
      var contextUser = scope['webapp.app-context'] && scope['webapp.app-context'].user;
      var profile = scope['webapp.user-detail'] && scope['webapp.user-detail'].userInfo;
      var profileUser = profile && profile.user;
      return String((profileUser && profileUser.secUid) || (contextUser && contextUser.secUid) || '');
    } catch (e) {
      return '';
    }
  }

  async function listTikTokCollectionsFromApi() {
    var secUid = tikTokProfileSecUid();
    var endpoints = [
      'https://www.tiktok.com/api/user/collection_list/',
      'https://www.tiktok.com/api/user/collection/list/',
      'https://www.tiktok.com/api/collection/list/',
    ];
    var best = { collections: [], complete: false, error: 'collections_unavailable' };
    for (var endpointIndex = 0; endpointIndex < endpoints.length; endpointIndex++) {
      var found = new Map();
      var cursor = '0';
      var seenCursors = new Set();
      var complete = false;
      var error = null;
      try {
        for (var page = 0; page < 20; page++) {
          if (seenCursors.has(cursor)) {
            error = 'collection_cursor_loop';
            break;
          }
          seenCursors.add(cursor);
          var url = endpoints[endpointIndex] + '?aid=1988&count=30&cursor=' + encodeURIComponent(cursor) +
            (endpointIndex === 0 && secUid ? '&secUid=' + encodeURIComponent(secUid) : '');
          var data = await fetchTikTokJson(url);
          var list = data.collectionList || data.collection_list || data.collections || data.items;
          if (!Array.isArray(list)) {
            error = 'invalid_collection_page';
            break;
          }
          list.forEach(function (col) {
            var item = collectionDescriptor(col);
            if (item) found.set(item.id, item);
          });
          var next = String(data.cursor == null ? '' : data.cursor);
          var hasMore = readTikTokHasMore(data);
          if (hasMore === true) {
            if (!list.length || !next || next === cursor) {
              error = 'collection_pagination_incomplete';
              break;
            }
            if (page === 19) {
              error = 'collection_page_limit';
              break;
            }
            cursor = next;
            continue;
          }
          if (hasMore !== false) {
            if (list.length && next && next !== cursor) {
              if (page === 19) {
                error = 'collection_page_limit';
                break;
              }
              cursor = next;
              continue;
            }
            error = 'collection_pagination_status_missing';
            break;
          }
          complete = true;
          cursor = next;
          break;
        }
      } catch (e) {
        error = (e && e.message) || 'collection_list_failed';
      }
      var candidate = {
        collections: Array.from(found.values()),
        complete: complete,
        error: error,
      };
      if (candidate.collections.length > best.collections.length ||
          (candidate.collections.length === best.collections.length && candidate.complete)) {
        best = candidate;
      }
      if (candidate.collections.length && candidate.complete) return candidate;
    }
    return best;
  }

  function visibleTikTokCollectionCards() {
    var found = new Map();
    document.querySelectorAll('a[href*="/collection/"]').forEach(function (link) {
      var url;
      try { url = new URL(link.href); } catch (e) { return; }
      if (!/(^|\.)tiktok\.com$/.test(url.hostname)) return;
      var match = url.pathname.match(/\/@[^/]+\/collection\/(.+)-(\d{8,})\/?$/);
      if (!match) return;
      var label = String(link.innerText || link.textContent || '').trim();
      var slug = match[1];
      var id = match[2];
      var decodedSlug = slug;
      try { decodedSlug = decodeURIComponent(slug); } catch (e) {}
      var details = collectionLabelDetails(label, decodedSlug);
      var name = details.name || decodedSlug.replace(/[-_]+/g, ' ').trim();
      if (!name) name = 'Collection ' + id;
      var rawCoverUrl = extractCleanImageUrl(link);
      found.set(id, {
        id: id,
        name: name,
        total: details.total,
        coverUrl: normalizeTikTokImageUrl(rawCoverUrl),
      });
    });
    return found;
  }

  async function listTikTokCollectionsFromPage(progress) {
    var found = visibleTikTokCollectionCards();
    if (!found.size) {
      return { collections: [], complete: false, declaredTotal: 0 };
    }
    var tabText = String(document.body && document.body.innerText || '');
    var declaredMatch = tabText.match(/Collections\s+(\d+)/i);
    var declared = declaredMatch ? parseInt(declaredMatch[1], 10) : 0;
    var first = document.querySelector('a[href*="/collection/"]');
    var scroller = findScrollableAncestor(first) || document.scrollingElement || document.documentElement;
    var originalTop = scroller ? scroller.scrollTop : 0;
    var stagnant = 0;
    try {
      for (var round = 0; round < 180 && stagnant < 30 && (!declared || found.size < declared); round++) {
        var cards = document.querySelectorAll('a[href*="/collection/"]');
        var last = cards[cards.length - 1];
        if (last && last.scrollIntoView) last.scrollIntoView({ block: 'end', behavior: 'instant' });
        if (scroller) scroller.scrollTop += Math.max(240, scroller.clientHeight * 0.55);
        await waitForTikTok(650);
        var now = visibleTikTokCollectionCards();
        now.forEach(function (value, key) { found.set(key, value); });
        stagnant = found.size > (progress.lastFound || 0) ? 0 : stagnant + 1;
        progress.lastFound = found.size;
        if (progress.update) progress.update(t('contentSyncDiscovering', 'Collections repérées') + ' : ' + found.size + (declared ? '/' + declared : ''), { phase: 'discover', found: found.size, declared: declared });
      }
      // Virtualized grids can skip cards while loading. Sweep back through
      // the visible list before declaring folders absent.
      if (scroller && declared && found.size < declared) {
        for (var back = 0; back < 180 && scroller.scrollTop > 0 && found.size < declared; back++) {
          scroller.scrollTop = Math.max(0, scroller.scrollTop - Math.max(240, scroller.clientHeight * 0.55));
          await waitForTikTok(350);
          visibleTikTokCollectionCards().forEach(function (value, key) { found.set(key, value); });
        }
      }
    } finally {
      if (scroller) scroller.scrollTop = originalTop;
    }
    return {
      collections: Array.from(found.values()),
      complete: declared > 0 && found.size >= declared,
      declaredTotal: declared,
    };
  }

  function tikTokItemId(item) {
    if (typeof item === 'string' || typeof item === 'number') {
      if (typeof item === 'number' && !Number.isSafeInteger(item)) return '';
      var scalarId = String(item);
      return /^\d{8,}$/.test(scalarId) ? scalarId : '';
    }
    if (!item || typeof item !== 'object') return '';
    var fields = [
      item.aweme_id,
      item.awemeId,
      item.aweme_id_str,
      item.awemeIdStr,
      item.video_id,
      item.videoId,
      item.item_id,
      item.itemId,
      item.id_str,
      item.idStr,
      item.id,
    ];
    for (var i = 0; i < fields.length; i++) {
      var value = fields[i];
      if (typeof value === 'number' && !Number.isSafeInteger(value)) continue;
      var id = String(value == null ? '' : value);
      if (/^\d{8,}$/.test(id)) return id;
    }
    var nestedItems = [item.aweme, item.awemeInfo, item.aweme_info, item.video, item.item];
    for (var nestedIndex = 0; nestedIndex < nestedItems.length; nestedIndex++) {
      if (nestedItems[nestedIndex] && nestedItems[nestedIndex] !== item) {
        var nestedId = tikTokItemId(nestedItems[nestedIndex]);
        if (nestedId) return nestedId;
      }
    }
    return '';
  }

  function tikTokVideoUrl(item, videoId) {
    if (item && typeof item === 'object') {
      var candidates = [
        item.share_url,
        item.shareUrl,
        item.url,
        item.web_url,
        item.webUrl,
        item.share_info && item.share_info.share_url,
        item.shareInfo && item.shareInfo.shareUrl,
      ];
      var nested = [item.aweme, item.awemeInfo, item.aweme_info, item.video, item.item];
      for (var nestedIndex = 0; nestedIndex < nested.length; nestedIndex++) {
        if (nested[nestedIndex] && nested[nestedIndex] !== item) {
          var nestedUrl = tikTokVideoUrl(nested[nestedIndex], videoId);
          if (nestedUrl.indexOf('/video/' + videoId) >= 0) return nestedUrl;
        }
      }
      for (var candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
        var candidate = String(candidates[candidateIndex] || '').trim();
        if (!candidate) continue;
        try {
          var parsed = new URL(candidate, 'https://www.tiktok.com');
          if (/(^|\.)tiktok\.com$/i.test(parsed.hostname) &&
              new RegExp('/@[^/]+/video/' + videoId + '(?:/|$)').test(parsed.pathname)) {
            return parsed.href;
          }
        } catch (e) {}
      }
      var author = item.author || item.authorInfo || item.author_info || {};
      var username = String(
        author.unique_id || author.uniqueId || author.username || author.user_name || '',
      ).trim();
      if (/^[A-Za-z0-9._]{1,64}$/.test(username)) {
        return 'https://www.tiktok.com/@' + encodeURIComponent(username) + '/video/' + videoId;
      }
    }
    // TikTok's share redirect resolves the creator URL from the stable item ID.
    return 'https://www.tiktokv.com/share/video/' + videoId + '/';
  }

  async function fetchCollectionItemsRecursive(collectionId, totalDeclared) {
    var allIds = new Set();
    var videoUrls = Object.create(null);
    var cursor = '0';
    var seenCursors = new Set();
    try {
      for (var page = 0; page < 500; page++) {
        if (seenCursors.has(cursor)) {
          return { ids: Array.from(allIds), videoUrls: videoUrls, complete: allIds.size > 0, error: allIds.size > 0 ? null : 'item_cursor_loop' };
        }
        seenCursors.add(cursor);
        var url = 'https://www.tiktok.com/api/collection/item_list/?aid=1988&sourceType=113&collectionId=' +
          encodeURIComponent(collectionId) + '&count=30&cursor=' + encodeURIComponent(cursor);
        var data;
        try {
          data = await fetchTikTokJson(url);
        } catch (fetchErr) {
          // Ids already read are real memberships, but the folder is not whole.
          if (allIds.size > 0) {
            return { ids: Array.from(allIds), videoUrls: videoUrls, complete: false, error: (fetchErr && fetchErr.message) || 'item_fetch_failed' };
          }
          throw fetchErr;
        }
        var hasMore = readTikTokHasMore(data);
        var list = data.itemList || data.item_list || data.items || data.videos || data.aweme_list || data.awemeList || data.awemes;
        if (!Array.isArray(list)) {
          if (hasMore === true) {
            await waitForTikTok(500);
            try {
              data = await fetchTikTokJson(url);
              hasMore = readTikTokHasMore(data);
              list = data.itemList || data.item_list || data.items || data.videos || data.aweme_list || data.awemeList || data.awemes;
            } catch (_) {}
          }
          if (!Array.isArray(list)) {
            list = [];
            hasMore = false;
          }
        }
        list.forEach(function (item) {
          var id = tikTokItemId(item);
          if (id) {
            allIds.add(id);
            if (!videoUrls[id]) videoUrls[id] = tikTokVideoUrl(item, id);
          }
        });
        var nextValue = data.cursor;
        if (nextValue == null) nextValue = data.nextCursor;
        if (nextValue == null) nextValue = data.next_cursor;
        var next = String(nextValue == null ? '' : nextValue);
        if (hasMore === false || hasMore === 0) {
          return { ids: Array.from(allIds), videoUrls: videoUrls, complete: true, error: null };
        }
        if (!list.length) {
          return { ids: Array.from(allIds), videoUrls: videoUrls, complete: true, error: null };
        }
        if (hasMore === true) {
          if (!next || next === cursor) {
            return { ids: Array.from(allIds), videoUrls: videoUrls, complete: false, error: 'item_cursor_stuck' };
          }
          if (page === 499) {
            return { ids: Array.from(allIds), videoUrls: videoUrls, complete: false, error: 'item_page_limit' };
          }
          cursor = next;
          await waitForTikTok(200);
          continue;
        }
        if (next && next !== cursor) {
          cursor = next;
          await waitForTikTok(200);
          continue;
        }
        return { ids: Array.from(allIds), videoUrls: videoUrls, complete: true, error: null };
      }
      return { ids: Array.from(allIds), videoUrls: videoUrls, complete: true, error: null };
    } catch (e) {
      return { ids: Array.from(allIds), videoUrls: videoUrls, complete: false, error: (e && e.message) || 'fetch_failed' };
    }
  }

  async function extractTikTokCollections(progress) {
    progress = progress || {};
    var apiResult = await listTikTokCollectionsFromApi();
    var descriptors = apiResult.collections;
    var collectionListComplete = apiResult.complete;
    var visibleResult = { collections: [], complete: false, declaredTotal: 0 };
    // The API may expose only the first page even when the account visibly
    // has more folders. Merge cards from the user's own Collections grid.
    if (document.querySelector('a[href*="/collection/"]')) {
      visibleResult = await listTikTokCollectionsFromPage(progress);
      var byId = new Map();
      descriptors.forEach(function (item) { byId.set(item.id, item); });
      visibleResult.collections.forEach(function (item) {
        var previous = byId.get(item.id);
        byId.set(item.id, {
          id: item.id,
          name: item.name || (previous && previous.name) || ('Collection ' + item.id),
          total: item.total || (previous && previous.total) || 0,
          coverUrl: item.coverUrl || (previous && previous.coverUrl) || null,
        });
      });
      descriptors = Array.from(byId.values());
      if (visibleResult.complete && descriptors.length >= visibleResult.declaredTotal) {
        collectionListComplete = true;
      } else if (visibleResult.declaredTotal && descriptors.length < visibleResult.declaredTotal) {
        collectionListComplete = false;
      }
    }
    if (!descriptors.length) {
      return {
        ok: false,
        collections: [],
        collectionListComplete: false,
        error: 'no_collections',
      };
    }
    var collections = new Array(descriptors.length);
    var failed = 0;
    var completed = 0;
    var videosSeen = 0;
    var nextIndex = 0;
    async function worker() {
      while (nextIndex < descriptors.length) {
        var index = nextIndex++;
        var col = descriptors[index];
        var result = await fetchCollectionItemsRecursive(col.id, col.total);
        videosSeen += result.ids.length;
        if (!result.complete) failed++;
        collections[index] = {
          id: col.id,
          name: col.name,
          coverUrl: col.coverUrl || null,
          declaredTotal: col.total > 0 ? col.total : null,
          videoIds: result.ids,
          videoUrls: result.videoUrls,
          complete: result.complete,
          error: result.error,
        };
        completed++;
        if (progress.update) {
          progress.update(t('contentSyncProgress', 'Collections traitées') + ' : ' + completed + '/' + descriptors.length, { phase: 'items', done: completed, total: descriptors.length, videos: videosSeen });
        }
        await waitForTikTok(100);
      }
    }
    await Promise.all(Array.from({ length: Math.min(2, descriptors.length) }, worker));
    var count = collections.length;
    var expectedTotal = Math.max(descriptors.length, visibleResult.declaredTotal || 0);
    return {
      ok: count > 0,
      collections: collections,
      collectionListComplete: collectionListComplete,
      found: descriptors.length,
      declaredTotal: expectedTotal,
      failed: failed,
      error: count && failed === count ? 'collection_items_unavailable' : null,
    };
  }

  function scheduleTikTokSyncBanner(delayMs) {
    if (window !== window.top) return;
    if (window.location.hostname.indexOf('tiktok.com') === -1) return;
    if (document.getElementById('md-tiktok-sync-pill')) return;
    if (tiktokSyncBannerTimer) clearTimeout(tiktokSyncBannerTimer);
    tiktokSyncBannerTimer = setTimeout(function () {
      tiktokSyncBannerTimer = null;
      injectTikTokSyncBanner();
    }, delayMs == null ? 150 : delayMs);
  }

  // In-page sync card (shadow DOM, so TikTok's CSS cannot touch it).
  var syncCard = { host: null, root: null, running: false };

  var SYNC_CARD_CSS =
    ':host{all:initial;--a:#f4b3cb;--on-a:#151515;--b:#f2da7e;--on-b:#151515;--c:#b9a8f2;--on-c:#151515;--ok:#a9c98b;--on-ok:#151515;--bad:#f08a8a;--on-bad:#151515;--r-card:26px;--r-ctl:999px}' +
    '.wrap{position:fixed;right:20px;bottom:20px;z-index:2147483647;font:13px/1.4 "Segoe UI Variable Display","Segoe UI",system-ui,sans-serif;-webkit-font-smoothing:antialiased}' +
    '.chip,.card{--t:var(--c);--on:var(--on-c);background:var(--t);color:var(--on)}' +
    '.card.done{--t:var(--ok);--on:var(--on-ok)}.card.error{--t:var(--bad);--on:var(--on-bad)}' +
    '.chip{display:flex;align-items:center;gap:10px;height:48px;padding:0 20px 0 8px;border:0;border-radius:var(--r-ctl);font:800 14px "Segoe UI Variable Display","Segoe UI",system-ui,sans-serif;letter-spacing:-.02em;cursor:pointer;box-shadow:0 10px 30px rgba(0,0,0,.35);transition:transform .15s}' +
    '.chip:hover{transform:translateY(-2px)}' +
    '.chip i{width:32px;height:32px;display:grid;place-items:center;border-radius:50%;background:color-mix(in srgb,var(--on) 14%,transparent)}' +
    '.card{width:320px;padding:18px;border-radius:var(--r-card);box-shadow:0 14px 40px rgba(0,0,0,.4)}' +
    '.title{margin:0 0 10px;font-size:13px;font-weight:700;opacity:.8}' +
    '.big{margin:0;font:800 44px/1 "Segoe UI Variable Display","Segoe UI",system-ui,sans-serif;letter-spacing:-.05em;font-variant-numeric:tabular-nums}' +
    '.big small{font-size:22px;font-weight:700;opacity:.55;letter-spacing:-.03em}' +
    '.label{margin:6px 0 0;font-size:14px;font-weight:600}' +
    '.bar{height:8px;margin:14px 0 10px;border-radius:999px;background:color-mix(in srgb,var(--on) 18%,transparent);overflow:hidden}' +
    '.bar b{display:block;height:100%;width:0;border-radius:999px;background:var(--on);transition:width .3s ease}' +
    '.note{margin:12px 0 0;padding:10px 14px;border-radius:calc(var(--r-card) * .6);background:color-mix(in srgb,var(--on) 14%,transparent);font-size:12px;font-weight:600}' +
    '.hint{margin:0;font-size:12px;opacity:.75}' +
    '.row{display:flex;gap:8px;margin-top:14px}' +
    '.btn{flex:1;height:40px;border:0;border-radius:var(--r-ctl);background:var(--on);color:var(--t);font:700 13px "Segoe UI Variable Display","Segoe UI",system-ui,sans-serif;cursor:pointer}' +
    '.btn.ghost{background:color-mix(in srgb,var(--on) 16%,transparent);color:var(--on)}' +
    '.btn:focus-visible,.chip:focus-visible{outline:2px solid var(--on);outline-offset:2px}' +
    '@media (prefers-reduced-motion:reduce){*{transition:none!important}}';

  // The card wears the desktop app's design (stored by connection.js).
  var syncCardThemeWatching = false;
  function syncCardWearTheme() {
    if (typeof MD_THEME === 'undefined' || !api.storage || !api.storage.local) return;
    function wear(theme) {
      if (theme && syncCard.host && syncCard.host.isConnected) MD_THEME.apply(theme, syncCard.host);
    }
    api.storage.local.get(['appTheme']).then(function (res) { wear(res && res.appTheme); }).catch(function () {});
    if (!syncCardThemeWatching && api.storage.onChanged) {
      syncCardThemeWatching = true;
      api.storage.onChanged.addListener(function (changes, area) {
        if (area === 'local' && changes.appTheme) wear(changes.appTheme.newValue);
      });
    }
  }

  function syncCardEl(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text != null) node.textContent = text;
    return node;
  }

  function syncCardFormat(message, values) {
    return String(message).replace(/\{(\w+)\}/g, function (_, key) {
      return values && values[key] != null ? values[key] : '';
    });
  }

  function syncCardMount() {
    if (syncCard.host && syncCard.host.isConnected) return true;
    if (!document.body) return false;
    var host = document.createElement('div');
    host.id = 'md-tiktok-sync-pill';
    var root = host.attachShadow({ mode: 'open' });
    var style = document.createElement('style');
    style.textContent = SYNC_CARD_CSS;
    root.appendChild(style);
    root.appendChild(syncCardEl('div', 'wrap'));
    syncCard.host = host;
    syncCard.root = root;
    document.body.appendChild(host);
    syncCardWearTheme();
    return true;
  }

  function syncCardShow(node, live) {
    if (!syncCardMount()) return;
    var wrap = syncCard.root.querySelector('.wrap');
    wrap.textContent = '';
    wrap.setAttribute('role', 'status');
    wrap.setAttribute('aria-live', live ? 'polite' : 'off');
    wrap.appendChild(node);
  }

  function syncCardIdle() {
    var chip = syncCardEl('button', 'chip');
    chip.type = 'button';
    var icon = syncCardEl('i');
    icon.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 7a8 8 0 0 0-14-1M4 3v4h4M4 17a8 8 0 0 0 14 1m2 3v-4h-4"></path></svg>';
    chip.appendChild(icon);
    chip.appendChild(syncCardEl('span', '', t('contentSyncButton', 'Classer mes favoris')));
    chip.addEventListener('click', function () { runTikTokSyncFromPage(); });
    syncCardShow(chip, false);
  }

  function syncCardRunning(info) {
    var card = syncCardEl('div', 'card');
    card.appendChild(syncCardEl('p', 'title', t('contentSyncRunningTitle', 'Synchro en cours')));
    var big = syncCardEl('p', 'big');
    var bar = syncCardEl('div', 'bar');
    var fill = syncCardEl('b');
    bar.appendChild(fill);
    if (info && info.phase === 'items') {
      big.textContent = info.done + '';
      big.appendChild(syncCardEl('small', '', '/' + info.total));
      card.appendChild(big);
      card.appendChild(syncCardEl('p', 'label', t('contentSyncItemsLabel', 'collections lues')));
      fill.style.width = Math.round((info.done / Math.max(1, info.total)) * 100) + '%';
      card.appendChild(bar);
      card.appendChild(syncCardEl('p', 'hint', syncCardFormat(t('contentSyncVideosFound', '{n} vidéos retrouvées'), { n: info.videos || 0 })));
    } else {
      big.textContent = (info && info.found) || '…';
      card.appendChild(big);
      card.appendChild(syncCardEl('p', 'label', t('contentSyncDiscoverLabel', 'collections repérées')));
      card.appendChild(bar);
    }
    card.appendChild(syncCardEl('p', 'hint', t('contentSyncKeepOpen', 'Garde cet onglet TikTok ouvert.')));
    syncCardShow(card, true);
  }

  function syncCardDone(res, recovered) {
    var collections = res.collections || [];
    var synced = collections.filter(function (c) { return c.complete; }).length;
    var incomplete = Math.max(0, collections.length - synced);
    var card = syncCardEl('div', 'card done');
    card.appendChild(syncCardEl('p', 'title', t('contentSyncDoneTitle', 'Favoris classés')));
    card.appendChild(syncCardEl('p', 'big', String(recovered)));
    card.appendChild(syncCardEl('p', 'label', syncCardFormat(t('contentSyncDoneLabel', 'vidéos rangées dans {n} collections'), { n: collections.length })));
    var partial = incomplete > 0;
    if (partial) {
      card.appendChild(syncCardEl('p', 'note', syncCardFormat(t('contentSyncPartialNote', '{n} collections incomplètes : TikTok n’a pas tout renvoyé. Relance pour compléter.'), { n: incomplete })));
    } else if (res.collectionListComplete === false) {
      card.appendChild(syncCardEl('p', 'note', t('contentSyncListPartial', 'Certaines collections n’ont peut-être pas été repérées. Relance pour vérifier.')));
      partial = true;
    }
    var row = syncCardEl('div', 'row');
    if (partial) {
      var retry = syncCardEl('button', 'btn', t('contentSyncRetry', 'Relancer'));
      retry.type = 'button';
      retry.addEventListener('click', function () { runTikTokSyncFromPage(); });
      row.appendChild(retry);
    }
    var close = syncCardEl('button', 'btn ghost', t('contentSyncClose', 'Fermer'));
    close.type = 'button';
    close.addEventListener('click', syncCardIdle);
    row.appendChild(close);
    card.appendChild(row);
    syncCardShow(card, true);
  }

  function syncCardError(message) {
    var card = syncCardEl('div', 'card error');
    card.appendChild(syncCardEl('p', 'title', t('contentSyncErrorTitle', 'Synchro impossible')));
    card.appendChild(syncCardEl('p', 'label', message));
    var row = syncCardEl('div', 'row');
    var retry = syncCardEl('button', 'btn', t('contentSyncRetry', 'Relancer'));
    retry.type = 'button';
    retry.addEventListener('click', function () { runTikTokSyncFromPage(); });
    var close = syncCardEl('button', 'btn ghost', t('contentSyncClose', 'Fermer'));
    close.type = 'button';
    close.addEventListener('click', syncCardIdle);
    row.appendChild(retry);
    row.appendChild(close);
    card.appendChild(row);
    syncCardShow(card, true);
  }

  function syncCardReason(res, err) {
    if (err && err.message === 'app_offline') {
      return t('contentSyncAppOffline', 'TapLoad n’est pas ouvert ou pas relié. Ouvre l’application, puis relance.');
    }
    if (res && res.found) {
      return t('contentSyncNoVideos', 'Collections visibles, mais TikTok n’a renvoyé aucune vidéo. Recharge la page et relance.');
    }
    if (res && res.error && res.error !== 'no_collections') {
      return t('contentSyncFailed', 'Synchronisation impossible') + ' (' + res.error + ')';
    }
    if (err) return t('contentSyncFailed', 'Synchronisation impossible') + ' (' + (err.message || err) + ')';
    return t('contentSyncNoCollections', 'Aucune collection visible. Ouvre Favoris, puis Collections sur TikTok.');
  }

  function countRecoveredVideos(collections) {
    var ids = new Set();
    (collections || []).forEach(function (c) {
      (c.videoIds || []).forEach(function (id) { ids.add(id); });
    });
    return ids.size;
  }

  // One run, whether started from the card or from the app/popup.
  function runTikTokSyncFromPage() {
    if (syncCard.running) return Promise.resolve();
    syncCard.running = true;
    syncCardRunning(null);
    return extractTikTokCollections({
      update: function (_message, info) { syncCardRunning(info || null); },
    }).then(function (res) {
      if (!(res && res.ok && Array.isArray(res.collections) && res.collections.length > 0)) {
        syncCardError(syncCardReason(res, null));
        return;
      }
      return api.runtime.sendMessage({
        type: 'MD_TIKTOK_COLLECTIONS_DATA',
        collections: res.collections,
        collectionListComplete: res.collectionListComplete,
      }).then(function (ack) {
        if (!ack || !ack.ok) throw new Error('app_offline');
        syncCardDone(res, countRecoveredVideos(res.collections));
      });
    }).catch(function (err) {
      syncCardError(syncCardReason(null, err));
    }).finally(function () {
      syncCard.running = false;
    });
  }

  function injectTikTokSyncBanner() {
    if (window !== window.top) return;
    if (window.location.hostname.indexOf('tiktok.com') === -1) return;
    if (document.getElementById('md-tiktok-sync-pill')) return;
    syncCardIdle();
  }

  start();
  scheduleTikTokSyncBanner(500);
})();

