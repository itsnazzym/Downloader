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

  global.MDProfile = { normalizeHandle: normalizeHandle, profileUrl: profileUrl, supportsProfile: supportsProfile };
})(typeof self !== 'undefined' ? self : this);
