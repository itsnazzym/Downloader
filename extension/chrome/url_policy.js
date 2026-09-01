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

  var ADULT_DOMAINS = ['pornhub.com'];

  function hostMatchesDomain(hostname, domain) {
    var host = String(hostname || '').toLowerCase().replace(/^\./, '');
    var d = String(domain || '').toLowerCase().replace(/^\./, '');
    if (!host || !d) return false;
    return host === d || host.endsWith('.' + d);
  }

  function isSupportedDomain(hostname, includeAdult) {
    var list = SUPPORTED_DOMAINS.slice();
    if (includeAdult) list = list.concat(ADULT_DOMAINS);
    return list.some(function (d) {
      return hostMatchesDomain(hostname, d);
    });
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

  function isAllowedDownloadUrl(value, adultSitesEnabled) {
    if (isXStatusPermalink(value)) return true;
    if (!isSafeHttpUrl(value)) return false;
    try {
      return isSupportedDomain(new URL(value).hostname, !!adultSitesEnabled);
    } catch (e) {
      return false;
    }
  }

  root.MDUrl = {
    SUPPORTED_DOMAINS: SUPPORTED_DOMAINS,
    ADULT_DOMAINS: ADULT_DOMAINS,
    hostMatchesDomain: hostMatchesDomain,
    isSupportedDomain: isSupportedDomain,
    isSafeHttpUrl: isSafeHttpUrl,
    isRestrictedPageUrl: isRestrictedPageUrl,
    isXStatusPermalink: isXStatusPermalink,
    isAllowedDownloadUrl: isAllowedDownloadUrl,
  };
})(typeof globalThis !== 'undefined' ? globalThis : self);
