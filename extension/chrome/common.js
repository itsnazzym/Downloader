(function (root, factory) {
  const api = factory();
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
  root.ModernDownloaderCommon = api;
})(typeof self !== 'undefined' ? self : globalThis, function () {
  const PROTOCOL_VERSION = '1';
  const DIRECT_VIDEO_RE = /\.(mp4|webm|mkv|mov|m4v|ts|m3u8|mpd)(?:$|[?#])/i;
  const DIRECT_IMAGE_RE = /\.(jpg|jpeg|png|gif|webp|bmp|avif|svg|heic|heif)(?:$|[?#])/i;
  const PHOTO_PATH_RE = /\/(?:photo|photos|gallery|image|images)(?:\/|$)/i;
  const DEFAULT_LOCAL_SETTINGS = {
    serverPort: 6969,
    apiToken: '',
    autoSendCookies: true,
    cookieBrowserPreference: 'auto',
    notificationsEnabled: false,
    debugMode: false,
  };
  const DEFAULT_SYNC_SETTINGS = {
    siteAccessMode: 'supported',
    siteRules: [],
  };
  const SUPPORTED_SITES = [
    {
      id: 'youtube',
      label: 'YouTube',
      hosts: ['youtube.com', 'youtu.be'],
      videoPagePatterns: [/^\/watch(?:\/|$|\?)/i, /^\/shorts\//i, /^\/live(?:\/|$)/i, /^\/clip\//i],
    },
    {
      id: 'instagram',
      label: 'Instagram',
      hosts: ['instagram.com'],
      videoPagePatterns: [/^\/reel\//i, /^\/reels\//i, /^\/stories\//i, /^\/tv\//i],
    },
    {
      id: 'twitter',
      label: 'X / Twitter',
      hosts: ['x.com', 'twitter.com'],
      videoPagePatterns: [/\/status\/\d+/i],
    },
    {
      id: 'tiktok',
      label: 'TikTok',
      hosts: ['tiktok.com'],
      videoPagePatterns: [/\/video\//i, /^\/t\//i],
    },
    {
      id: 'twitch',
      label: 'Twitch',
      hosts: ['twitch.tv'],
      videoPagePatterns: [/^\/videos\//i, /^\/clip\//i, /^\/clips\//i],
    },
    {
      id: 'facebook',
      label: 'Facebook',
      hosts: ['facebook.com', 'fb.com', 'fb.watch'],
      videoPagePatterns: [/^\/watch(?:\/|$)/i, /^\/reel\//i, /^\/videos\//i, /^\/share\/v\//i, /^\/share\/r\//i],
    },
  ];

  function normalizeHostname(hostname) {
    return String(hostname || '')
      .trim()
      .toLowerCase()
      .replace(/^\.+/, '')
      .replace(/\.+$/, '');
  }

  function stripCommonPrefixes(hostname) {
    return normalizeHostname(hostname).replace(/^(www|m|mobile)\./, '');
  }

  function unique(values) {
    return Array.from(new Set(values.filter(Boolean)));
  }

  function toUrl(rawUrl) {
    if (!rawUrl || typeof rawUrl !== 'string') {
      return null;
    }

    try {
      return new URL(rawUrl);
    } catch (_) {
      return null;
    }
  }

  function canonicalizeUrl(rawUrl) {
    const parsed = toUrl(rawUrl);
    if (!parsed) {
      return '';
    }

    parsed.hash = '';
    return parsed.toString();
  }

  function findSiteDefinition(hostname) {
    const normalized = stripCommonPrefixes(hostname);
    return (
      SUPPORTED_SITES.find((site) =>
        site.hosts.some((host) => normalized === host || normalized.endsWith(`.${host}`)),
      ) || null
    );
  }

  function getSiteKey(hostname) {
    return findSiteDefinition(hostname)?.id || null;
  }

  function getSiteLabel(hostname) {
    return findSiteDefinition(hostname)?.label || 'Unsupported';
  }

  function isSupportedHostname(hostname) {
    return Boolean(findSiteDefinition(hostname));
  }

  function isLikelyPhotoUrl(rawUrl) {
    const parsed = toUrl(rawUrl);
    const input = parsed ? `${parsed.pathname}${parsed.search}` : String(rawUrl || '');
    return DIRECT_IMAGE_RE.test(input) || PHOTO_PATH_RE.test(input);
  }

  function isLikelyVideoMediaUrl(rawUrl) {
    const parsed = toUrl(rawUrl);
    if (!parsed) {
      return false;
    }

    const target = `${parsed.pathname}${parsed.search}`;
    if (DIRECT_IMAGE_RE.test(target)) {
      return false;
    }

    if (DIRECT_VIDEO_RE.test(target)) {
      return true;
    }

    const query = parsed.search.toLowerCase();
    return query.includes('mime=video') || query.includes('type=video') || query.includes('format=m3u8');
  }

  function isLikelyVideoPageUrl(rawUrl) {
    const parsed = toUrl(rawUrl);
    if (!parsed) {
      return false;
    }

    const site = findSiteDefinition(parsed.hostname);
    if (!site) {
      return false;
    }

    if (site.id === 'facebook' && stripCommonPrefixes(parsed.hostname) === 'fb.watch') {
      return true;
    }

    return site.videoPagePatterns.some((pattern) => pattern.test(parsed.pathname));
  }

  function validateVideoTarget(mediaUrl, pageUrl) {
    const parsedMedia = toUrl(mediaUrl);
    const parsedPage = toUrl(pageUrl);

    if (mediaUrl && isLikelyPhotoUrl(mediaUrl)) {
      return { ok: false, code: 'PHOTO_NOT_SUPPORTED', message: 'Photo and gallery URLs are blocked.' };
    }

    if (pageUrl && isLikelyPhotoUrl(pageUrl)) {
      return { ok: false, code: 'PHOTO_NOT_SUPPORTED', message: 'Photo and gallery pages are blocked.' };
    }

    if (mediaUrl && isLikelyVideoMediaUrl(mediaUrl)) {
      return {
        ok: true,
        preferredUrl: canonicalizeUrl(mediaUrl),
        siteKey: getSiteKey(parsedPage?.hostname || parsedMedia?.hostname),
      };
    }

    if (mediaUrl && isLikelyVideoPageUrl(mediaUrl)) {
      return {
        ok: true,
        preferredUrl: canonicalizeUrl(mediaUrl),
        siteKey: getSiteKey(parsedMedia?.hostname || parsedPage?.hostname),
      };
    }

    if (pageUrl && isLikelyVideoPageUrl(pageUrl)) {
      return {
        ok: true,
        preferredUrl: canonicalizeUrl(pageUrl),
        siteKey: getSiteKey(parsedPage?.hostname),
      };
    }

    const host = parsedPage?.hostname || parsedMedia?.hostname;
    if (host && isSupportedHostname(host)) {
      return { ok: false, code: 'VIDEO_NOT_DETECTED', message: 'No valid video was detected on this page.' };
    }

    return { ok: false, code: 'UNSUPPORTED_SITE', message: 'This site is not supported by the extension.' };
  }

  function clampPort(value, fallback) {
    const parsed = Number.parseInt(String(value ?? ''), 10);
    if (Number.isInteger(parsed) && parsed > 0 && parsed <= 65535) {
      return parsed;
    }
    return fallback ?? DEFAULT_LOCAL_SETTINGS.serverPort;
  }

  function sanitizeText(value, maxLength) {
    const normalized = String(value ?? '')
      .replace(/[\u0000-\u001f\u007f]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    if (!maxLength || normalized.length <= maxLength) {
      return normalized;
    }

    return `${normalized.slice(0, Math.max(0, maxLength - 3))}...`;
  }

  function normalizeRuleList(rawRules) {
    if (Array.isArray(rawRules)) {
      return unique(rawRules.map(stripCommonPrefixes));
    }

    return unique(
      String(rawRules || '')
        .split(/\r?\n|,|;/)
        .map(stripCommonPrefixes),
    );
  }

  function matchesRule(hostname, rawRule) {
    const host = stripCommonPrefixes(hostname);
    const rule = stripCommonPrefixes(rawRule);
    return Boolean(rule) && (host === rule || host.endsWith(`.${rule}`));
  }

  function isSiteAllowed(hostname, accessMode, siteRules) {
    const normalizedHost = stripCommonPrefixes(hostname);
    const rules = normalizeRuleList(siteRules);
    const isSupported = isSupportedHostname(normalizedHost);

    if (!isSupported) {
      return false;
    }

    if (accessMode === 'allowlist') {
      return rules.some((rule) => matchesRule(normalizedHost, rule));
    }

    if (accessMode === 'blocklist') {
      return !rules.some((rule) => matchesRule(normalizedHost, rule));
    }

    return true;
  }

  function getCookieDomainCandidatesFromUrls(urls) {
    const candidates = [];

    for (const rawUrl of urls || []) {
      const parsed = toUrl(rawUrl);
      if (!parsed) {
        continue;
      }

      const hostname = normalizeHostname(parsed.hostname);
      if (!hostname) {
        continue;
      }

      candidates.push(hostname, stripCommonPrefixes(hostname));
      const site = findSiteDefinition(hostname);
      if (site) {
        candidates.push(...site.hosts);
      }
    }

    return unique(candidates);
  }

  function isValidHelloAck(message) {
    return Boolean(
      message &&
        message.type === 'HELLO_ACK' &&
        typeof message.protocolVersion === 'string' &&
        typeof message.appVersion === 'string',
    );
  }

  function isValidProgressMessage(message) {
    return Boolean(
      message &&
        message.type === 'PROGRESS' &&
        message.data &&
        typeof message.data.id === 'string' &&
        typeof message.data.status === 'number',
    );
  }

  function isValidErrorMessage(message) {
    return Boolean(message && message.type === 'ERROR' && typeof message.code === 'string');
  }

  function isValidToken(value) {
    return typeof value === 'string' && value.trim().length >= 8;
  }

  return {
    PROTOCOL_VERSION,
    SUPPORTED_SITES,
    DEFAULT_LOCAL_SETTINGS,
    DEFAULT_SYNC_SETTINGS,
    canonicalizeUrl,
    clampPort,
    findSiteDefinition,
    getCookieDomainCandidatesFromUrls,
    getSiteKey,
    getSiteLabel,
    isLikelyPhotoUrl,
    isLikelyVideoMediaUrl,
    isLikelyVideoPageUrl,
    isSiteAllowed,
    isSupportedHostname,
    isValidErrorMessage,
    isValidHelloAck,
    isValidProgressMessage,
    isValidToken,
    matchesRule,
    normalizeHostname,
    normalizeRuleList,
    sanitizeText,
    stripCommonPrefixes,
    toUrl,
    validateVideoTarget,
  };
});
