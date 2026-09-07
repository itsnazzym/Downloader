/**
 * In-app WebView overlay — same 1-tap download buttons as the desktop
 * extension, talking to Flutter via the MDAndroid JavaScript channel.
 */
(function () {
  'use strict';

  if (window.__MD_ANDROID_OVERLAY__) return;
  window.__MD_ANDROID_OVERLAY__ = true;
  window.__MD_ACKS = window.__MD_ACKS || {};

  var PROCESSED = new WeakSet();
  var scanScheduled = false;
  var scanTimer = null;

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
    var adRegex = /\b(sponsoris[ée]|sponsored|commandit[ée]|partenariat r[ée]mun[ée]r[ée]|paid partnership|promoted|publicit[ée])\b/i;

    while (curr && depth < 12) {
      if (curr.nodeType === 1) {
        if (curr.getAttribute && curr.getAttribute('data-e2e') === 'ad-tag') return true;
        if (curr.getAttribute && curr.getAttribute('data-ad') === 'true') return true;
        if (curr.querySelector && curr.querySelector('[data-e2e="ad-tag"], [data-ad="true"]')) return true;
        if (curr.querySelector && curr.querySelector('a[href*="/ads/"], [aria-label*="Sponsored"], [aria-label*="Sponsorisé"]')) return true;
        var tag = curr.tagName ? curr.tagName.toLowerCase() : '';
        if (tag === 'ytd-ad-slot-renderer' || tag === 'ytd-in-feed-ad-layout-renderer' || tag === 'ytd-promoted-video-renderer') return true;
        if (curr.classList && (curr.classList.contains('ad-showing') || curr.classList.contains('ad-interrupting'))) return true;
        if (curr.getAttribute && curr.getAttribute('data-testid') === 'placementTracking') return true;
        if (curr.querySelector && curr.querySelector('[data-testid="placementTracking"]')) return true;

        var labels = curr.querySelectorAll ? curr.querySelectorAll('span, div, p, a') : [];
        for (var i = 0; i < Math.min(labels.length, 10); i++) {
          var txt = labels[i].textContent ? labels[i].textContent.trim() : '';
          if (txt.length > 0 && txt.length < 35 && adRegex.test(txt)) {
            var cls = String(labels[i].className || '');
            var aria = String(labels[i].getAttribute('aria-label') || '');
            if (/badge|label|sponsor|promot|ad/i.test(cls) || /sponsor|promot|ad/i.test(aria)) return true;
          }
        }
      }
      curr = curr.parentElement;
      depth++;
    }
    return false;
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
        /^\/(?:([^/]+)\/status|i\/(?:web\/)?status)\/(\d+)/,
      );
      if (!match) return null;
      url.search = '';
      url.hash = '';
      return { url: url.href, id: match[2] };
    } catch (e) {
      return null;
    }
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

  function findPlatformSpecificUrl(element) {
    var pageUrl = window.location.href;
    if (isXPage()) {
      var article = findXArticle(element);
      var post = findXPostLink(article);
      if (post && post.url) return post.url;
      var permalink = statusPermalinkFromPage();
      if (permalink) return permalink;
    }

    function findNearestPermalink(el) {
      if (
        el.tagName === 'A' &&
        el.href &&
        VIDEO_PATTERNS.some(function (p) { return el.href.indexOf(p) !== -1; })
      ) {
        return el.href;
      }
      var curr = el.parentElement;
      var depth = 0;
      while (curr && depth < 10) {
        if (
          curr.tagName === 'A' &&
          curr.href &&
          VIDEO_PATTERNS.some(function (p) { return curr.href.indexOf(p) !== -1; })
        ) {
          return curr.href;
        }
        depth++;
        curr = curr.parentElement;
      }
      return null;
    }

    if (element.tagName === 'VIDEO') {
      var deepLink = findNearestPermalink(element);
      if (deepLink) return deepLink;
      var mediaUrl = element.currentSrc || element.src;
      if (mediaUrl && mediaUrl.indexOf('blob:') !== 0 && mediaUrl.indexOf('preview') === -1) {
        return mediaUrl;
      }
    }
    return pageUrl;
  }

  function xTweetIdFromUrl(url) {
    var parsed = parseXStatusLink(url);
    return parsed ? parsed.id : null;
  }

  function sendDownload(targetUrl, opts, extra, onResult) {
    var id = 'md' + Date.now() + Math.floor(Math.random() * 10000);
    window.__MD_ACKS[id] = onResult;
    try {
      if (typeof MDAndroid === 'undefined' || !MDAndroid.postMessage) {
        onResult({ ok: false, error: 'app_offline' });
        return;
      }
      MDAndroid.postMessage(JSON.stringify({
        id: id,
        type: 'DOWNLOAD_BTN_CLICK',
        url: targetUrl,
        pageUrl: window.location.href,
        options: opts || {},
        tweetId: extra && extra.tweetId ? extra.tweetId : null,
        mediaId: extra && extra.mediaId ? extra.mediaId : null,
      }));
      setTimeout(function () {
        var pending = window.__MD_ACKS[id];
        if (pending) {
          delete window.__MD_ACKS[id];
          pending({ ok: true });
        }
      }, 4000);
    } catch (e) {
      onResult({ ok: false, error: 'send_failed' });
    }
  }

  function createButtonUI(targetUrl, tweetId, container) {
    var host = document.createElement('div');
    host.className = 'md-dl-host';
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
    if (!isVerticalVideo && (window.location.pathname.indexOf('/shorts') !== -1 || window.location.pathname.indexOf('/reel') !== -1 || window.location.href.indexOf('tiktok.com') !== -1)) {
      isVerticalVideo = true;
    }

    var isLeftAligned = false;
    if (isVerticalVideo) {
      host.style.top = '16px';
      host.style.left = '16px';
      host.style.right = 'auto';
      host.style.bottom = 'auto';
      isLeftAligned = true;
    } else {
      host.style.top = '8px';
      host.style.right = '8px';
    }

    var menuAlign = isLeftAligned ? 'left:0;right:auto;' : 'right:0;left:auto;';

    var shadow = host.attachShadow({ mode: 'closed' });
    var style = document.createElement('style');
    style.textContent =
      ':host{all:initial}' +
      '.wrap{display:flex;align-items:center;pointer-events:auto;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;opacity:0.9;border-radius:6px;box-shadow:0 4px 14px rgba(0,0,0,0.4)}' +
      'button{border:none;color:#fff;cursor:pointer;font-weight:600;display:inline-flex;align-items:center;gap:6px}' +
      'button:disabled{cursor:default}' +
      '.main{background:#6C5DD3;border-radius:6px 0 0 6px;padding:8px 14px;font-size:13px;line-height:1.3}' +
      '.toggle{background:#6C5DD3;filter:brightness(0.9);border-radius:0 6px 6px 0;padding:8px 10px;border-left:1px solid rgba(255,255,255,.2);line-height:1.3}' +
      '.menu{position:absolute;top:100%;' + menuAlign + 'display:none;flex-direction:column;min-width:120px;background:#1E1E24;border:1px solid #333;border-radius:6px;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,0.5);margin-top:4px;z-index:100}' +
      '.menu.open{display:flex}' +
      '.item{padding:10px 14px;color:#eee;font-size:13px;cursor:pointer}' +
      '.item:hover{background:#6C5DD3}' +
      '.ok{background:#4CAF50!important}' +
      '.err{background:#F44336!important}';
    shadow.appendChild(style);

    var wrap = document.createElement('div');
    wrap.className = 'wrap';
    shadow.appendChild(wrap);

    var btn = document.createElement('button');
    btn.className = 'main';
    btn.type = 'button';
    btn.textContent = 'Download';
    wrap.appendChild(btn);

    var selectedQuality = 'best';
    var toggle = document.createElement('button');
    toggle.className = 'toggle';
    toggle.type = 'button';
    toggle.textContent = '▾';
    wrap.appendChild(toggle);

    var menu = document.createElement('div');
    menu.className = 'menu';
    wrap.appendChild(menu);

    [
      { label: 'Best', val: 'best' },
      { label: '1080p', val: '1080p' },
      { label: '720p', val: '720p' },
      { label: 'Audio', val: 'audio' },
    ].forEach(function (opt) {
      var item = document.createElement('div');
      item.className = 'item';
      item.textContent = opt.label;
      item.addEventListener('click', function (e) {
        e.stopPropagation();
        selectedQuality = opt.val;
        btn.textContent = opt.label;
        menu.classList.remove('open');
      });
      menu.appendChild(item);
    });

    toggle.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      menu.classList.toggle('open');
    });

    btn.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      var opts = {};
      if (selectedQuality === 'audio') opts.isAudioOnly = true;
      else if (selectedQuality !== 'best') opts.preferredQuality = selectedQuality;
      btn.textContent = '…';
      btn.disabled = true;
      sendDownload(targetUrl, opts, { tweetId: tweetId }, function (result) {
        if (result && result.ok) {
          btn.textContent = 'Saved';
          btn.classList.add('ok');
          toggle.classList.add('ok');
          return;
        }
        btn.textContent = 'Failed';
        btn.classList.add('err');
        setTimeout(function () {
          btn.disabled = false;
          btn.classList.remove('err');
          btn.textContent = 'Download';
        }, 2000);
      });
    });

    return host;
  }

  function injectButton(container, targetUrl) {
    if (!container || PROCESSED.has(container)) return;
    if (isSponsoredContent(container)) return;
    var style = window.getComputedStyle(container);
    if (style.position === 'static') container.style.position = 'relative';
    var tweetId = xTweetIdFromUrl(targetUrl);
    container.appendChild(createButtonUI(targetUrl, tweetId, container));
    PROCESSED.add(container);
  }

  function scan() {
    if (!document.body) return;
    document.querySelectorAll('video').forEach(function (video) {
      if (!video.parentElement) return;
      if (isSponsoredContent(video) || isSponsoredContent(video.parentElement)) return;
      var rect = video.getBoundingClientRect();
      if (rect.width < 80 || rect.height < 45) return;
      var url = findPlatformSpecificUrl(video);
      if (url) injectButton(video.parentElement, url);
    });
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
    var observer = new MutationObserver(scheduleScan);
    observer.observe(document.body, { childList: true, subtree: true });
  }

  start();
})();
