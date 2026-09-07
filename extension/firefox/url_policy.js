/**
 * Shared URL helpers for the extension (loaded before connection.js / SW).
 */
(function (root) {
  'use strict';

  var SUPPORTED_DOMAINS = [
    'youtube.com', 'youtu.be',
    'instagram.com',
    'twitter.com', 'x.com',
    'tiktok.com',
    'twitch.tv',
    'facebook.com', 'fb.watch',
    'kick.com',
  ];

  var ALLOWED_DOWNLOAD_DOMAINS = [
    'youtube.com', 'youtu.be',
    'instagram.com',
    'twitter.com', 'x.com',
    'tiktok.com',
    'twitch.tv',
    'facebook.com', 'fb.watch',
    'kick.com',
    'reddit.com', 'redd.it',
    'vimeo.com',
    'dailymotion.com',
    'soundcloud.com',
    'bilibili.com',
    'rumble.com',
    'threads.net',
    'bsky.app',
  ];

  var ADULT_DOMAINS = [
    'pornhub.com',
    'xvideos.com',
    'xnxx.com',
    'xhamster.com',
  ];

  function hostMatchesDomain(hostname, domain) {
    var host = String(hostname || '').toLowerCase().replace(/^\./, '');
    var d = String(domain || '').toLowerCase().replace(/^\./, '');
    if (!host || !d) return false;
    return host === d || host.endsWith('.' + d);
  }

  function isSupportedDomain(hostname, includeAdult) {
    if (!hostname) return false;
    var host = String(hostname).toLowerCase();
    if (host === 'localhost' || host === '127.0.0.1') return false;
    if (!includeAdult) {
      if (ADULT_DOMAINS.some(function (d) { return hostMatchesDomain(host, d); })) return false;
    }
    return true;
  }

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

  function detectPlatform(value) {
    if (!value) return 'generic';
    var hostname = '';
    try {
      hostname = new URL(value).hostname.toLowerCase();
    } catch (e) {
      hostname = String(value).toLowerCase();
    }
    if (hostMatchesDomain(hostname, 'x.com') || hostMatchesDomain(hostname, 'twitter.com')) {
      return 'x';
    }
    if (hostMatchesDomain(hostname, 'instagram.com')) {
      return 'instagram';
    }
    if (hostMatchesDomain(hostname, 'tiktok.com')) {
      return 'tiktok';
    }
    if (hostMatchesDomain(hostname, 'youtube.com') || hostMatchesDomain(hostname, 'youtu.be')) {
      return 'youtube';
    }
    if (hostMatchesDomain(hostname, 'facebook.com') || hostMatchesDomain(hostname, 'fb.watch')) {
      return 'facebook';
    }
    if (hostMatchesDomain(hostname, 'twitch.tv')) {
      return 'twitch';
    }
    if (hostMatchesDomain(hostname, 'kick.com')) {
      return 'kick';
    }
    // Dynamic universal extraction (e.g. reddit, vimeo, dailymotion, pinterest, threads, bluesky...)
    var cleanHost = hostname.replace(/^www\./, '');
    var parts = cleanHost.split('.');
    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    return cleanHost || 'generic';
  }

  function isXStatusPermalink(value) {
    if (!isSafeHttpUrl(value)) return null;
    try {
      var url = new URL(value);
      var hostname = url.hostname.toLowerCase();
      if (!hostMatchesDomain(hostname, 'x.com') &&
          !hostMatchesDomain(hostname, 'twitter.com')) {
        return null;
      }
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

  function canonicalMediaUrl(value, pageUrl) {
    var raw = isSafeHttpUrl(value) ? value : (isSafeHttpUrl(pageUrl) ? pageUrl : null);
    if (!raw) return null;
    try {
      var url = new URL(raw);
      var hostname = url.hostname.toLowerCase();
      var path = url.pathname;

      // X / Twitter
      if (hostMatchesDomain(hostname, 'x.com') || hostMatchesDomain(hostname, 'twitter.com')) {
        return isXStatusPermalink(url.href);
      }

      // Instagram Reels / Posts
      if (hostMatchesDomain(hostname, 'instagram.com')) {
        var igMatch = path.match(/\/(?:reels?|p)\/([A-Za-z0-9_-]+)/);
        if (igMatch) {
          var type = path.indexOf('/p/') !== -1 ? 'p' : 'reel';
          return 'https://www.instagram.com/' + type + '/' + igMatch[1] + '/';
        }
      }

      // TikTok
      if (hostMatchesDomain(hostname, 'tiktok.com')) {
        var ttMatch = path.match(/\/(@[A-Za-z0-9._-]+)\/video\/(\d+)/);
        if (ttMatch) {
          return 'https://www.tiktok.com/' + ttMatch[1] + '/video/' + ttMatch[2];
        }
        var ttShortMatch = path.match(/\/(?:v|video)\/(\d+)/);
        if (ttShortMatch) {
          return 'https://www.tiktok.com/video/' + ttShortMatch[1];
        }
      }

      // YouTube Shorts & Watch
      if (hostMatchesDomain(hostname, 'youtube.com') || hostMatchesDomain(hostname, 'youtu.be')) {
        var shortsMatch = path.match(/\/shorts\/([A-Za-z0-9_-]+)/);
        if (shortsMatch) {
          return 'https://www.youtube.com/shorts/' + shortsMatch[1];
        }
        if (hostMatchesDomain(hostname, 'youtu.be')) {
          var ytShort = path.replace(/^\/+/, '').split('/')[0];
          if (ytShort) return 'https://youtu.be/' + ytShort;
        }
        var watchV = url.searchParams ? url.searchParams.get('v') : null;
        if (watchV) {
          return 'https://www.youtube.com/watch?v=' + watchV;
        }
      }

      // Facebook Reels & Watch
      if (hostMatchesDomain(hostname, 'facebook.com') || hostMatchesDomain(hostname, 'fb.watch')) {
        var fbReel = path.match(/\/reel\/(\d+)/);
        if (fbReel) {
          return 'https://www.facebook.com/reel/' + fbReel[1] + '/';
        }
        var fbWatch = url.searchParams ? url.searchParams.get('v') : null;
        if (fbWatch) {
          return 'https://www.facebook.com/watch/?v=' + fbWatch;
        }
      }

      // Clean default query tracking
      url.search = '';
      url.hash = '';
      return url.href;
    } catch (e) {
      return null;
    }
  }

  function isReelOrShortsUrl(value) {
    if (!value) return false;
    var str = String(value).toLowerCase();
    return str.indexOf('/reel/') !== -1 ||
      str.indexOf('/reels/') !== -1 ||
      str.indexOf('/shorts/') !== -1 ||
      (str.indexOf('tiktok.com') !== -1 && str.indexOf('/video/') !== -1);
  }

  function isAllowedDownloadUrl(value, adultSitesEnabled) {
    if (isXStatusPermalink(value)) return true;
    if (!isSafeHttpUrl(value)) return false;
    var canonical = canonicalMediaUrl(value);
    if (canonical && canonical !== value) {
      value = canonical;
    }
    try {
      var hostname = new URL(value).hostname.toLowerCase();
      // Block localhost loopback attacks
      if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1' || hostname.endsWith('.local')) {
        return false;
      }
      if (!adultSitesEnabled) {
        var isAdult = ADULT_DOMAINS.some(function (d) {
          return hostMatchesDomain(hostname, d);
        });
        if (isAdult) return false;
      }
      // Any public web URL is allowed by the universal engine!
      return true;
    } catch (e) {
      return false;
    }
  }

  root.MDUrl = {
    SUPPORTED_DOMAINS: SUPPORTED_DOMAINS,
    ALLOWED_DOWNLOAD_DOMAINS: ALLOWED_DOWNLOAD_DOMAINS,
    ADULT_DOMAINS: ADULT_DOMAINS,
    hostMatchesDomain: hostMatchesDomain,
    isSupportedDomain: isSupportedDomain,
    isSafeHttpUrl: isSafeHttpUrl,
    isRestrictedPageUrl: isRestrictedPageUrl,
    detectPlatform: detectPlatform,
    canonicalMediaUrl: canonicalMediaUrl,
    isReelOrShortsUrl: isReelOrShortsUrl,
    isXStatusPermalink: isXStatusPermalink,
    isAllowedDownloadUrl: isAllowedDownloadUrl,
  };
})(typeof globalThis !== 'undefined' ? globalThis : self);
