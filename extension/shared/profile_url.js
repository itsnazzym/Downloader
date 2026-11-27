/**
 * Resolves a platform + handle to the public profile page. Handles come from
 * page data, so only [A-Za-z0-9._] is accepted and the result is always an
 * https URL on a fixed host.
 */
(function (global) {
  'use strict';

  var HANDLE = /^[A-Za-z0-9._]{1,50}$/;
  var BUILDERS = {
    x: function (h) { return 'https://x.com/' + h; },
    tiktok: function (h) { return 'https://www.tiktok.com/@' + h; },
    instagram: function (h) { return 'https://www.instagram.com/' + h + '/'; },
    youtube: function (h) { return 'https://www.youtube.com/@' + h; },
    facebook: function (h) { return 'https://www.facebook.com/' + h; },
    twitch: function (h) { return 'https://www.twitch.tv/' + h; },
  };

  function normalizeHandle(raw) {
    if (typeof raw !== 'string') return null;
    var h = raw.trim();
    if (h.charAt(0) === '@') h = h.slice(1);
    // Dot-only handles ("..") match the pattern but are path traversal.
    return HANDLE.test(h) && !/^\.+$/.test(h) ? h : null;
  }

  function profileUrl(platform, handle) {
    var h = normalizeHandle(handle);
    var build = typeof platform === 'string' && Object.prototype.hasOwnProperty.call(BUILDERS, platform) ? BUILDERS[platform] : null;
    return h && build ? build(h) : null;
  }

  function supportsProfile(platform, handle) {
    return profileUrl(platform, handle) !== null;
  }

  // Only post URLs name their author: x.com/<handle>/status/<id>, tiktok.com/@<handle>/video/<id>.
  // A page URL (home, a profile, a collection) says nothing about who posted the video.
  var X_POST = /^https?:\/\/(?:[a-z0-9-]+\.)*(?:x|twitter)\.com\/([^/?#]+)\/status\/\d+/i;
  var X_HANDLE = /^[A-Za-z0-9_]{1,15}$/;
  var X_RESERVED = { i: 1, home: 1, search: 1, explore: 1, intent: 1, status: 1, hashtag: 1, settings: 1, messages: 1, notifications: 1 };
  var TIKTOK_POST = /^https?:\/\/(?:[a-z0-9-]+\.)*tiktok\.com\/@([^/?#]+)\/(?:video|photo)\/\d+/i;

  // The account handle of a feed item, or null when it is not known for sure. Display names
  // ("Studio Nova@studio_nova·2h", a YouTube channel name, an Instagram link label) never count.
  function handleFromItem(item) {
    if (!item || typeof item !== 'object') return null;
    var urls = [item.url, item.pageUrl].filter(function (u) { return typeof u === 'string'; });
    var i, m;
    if (item.platform === 'x') {
      for (i = 0; i < urls.length; i++) {
        m = X_POST.exec(urls[i]);
        if (m && X_HANDLE.test(m[1]) && !X_RESERVED[m[1].toLowerCase()]) return m[1];
      }
      return null;
    }
    if (item.platform === 'tiktok') {
      for (i = 0; i < urls.length; i++) {
        m = TIKTOK_POST.exec(urls[i]);
        var fromUrl = m && normalizeHandle(m[1]);
        if (fromUrl) return fromUrl;
      }
      var author = typeof item.author === 'string' ? item.author.trim() : '';
      return author.charAt(0) === '@' ? normalizeHandle(author) : null;
    }
    return null;
  }

  // Identity of a creator: the same handle on two platforms is two creators.
  function creatorKey(platform, handle) {
    return String(platform || '') + ':' + String(handle || '').trim().replace(/^@/, '').toLowerCase();
  }

  global.MDProfile = { normalizeHandle: normalizeHandle, profileUrl: profileUrl, supportsProfile: supportsProfile, creatorKey: creatorKey, handleFromItem: handleFromItem };
})(typeof self !== 'undefined' ? self : this);
