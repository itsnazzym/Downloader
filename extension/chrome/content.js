(function () {
  const Common = window.ModernDownloaderCommon;
  const api = chrome;
  const QUALITY_OPTIONS = [
    { label: 'Best', value: 'best' },
    { label: '1080p', value: '1080p' },
    { label: '720p', value: '720p' },
  ];
  const overlayRegistry = new Map();
  let syncSettings = { ...Common.DEFAULT_SYNC_SETTINGS };
  let observer = null;
  let scanTimer = null;
  let layoutFrame = null;

  function storageGet(area, keys) {
    return new Promise((resolve) => api.storage[area].get(keys, resolve));
  }

  function sanitizeLabel(value, fallback) {
    const cleaned = Common.sanitizeText(value, 64);
    return cleaned || fallback;
  }

  function isCurrentSiteAllowed() {
    return Common.isSiteAllowed(window.location.hostname, syncSettings.siteAccessMode, syncSettings.siteRules);
  }

  function getSiteSelectors() {
    const siteKey = Common.getSiteKey(window.location.hostname);
    switch (siteKey) {
      case 'youtube':
        return ['a#thumbnail[href*="/watch"]', 'a[href*="/shorts/"]', 'a[href*="/clip/"]'];
      case 'instagram':
        return ['a[href*="/reel/"]', 'a[href*="/reels/"]'];
      case 'tiktok':
        return ['a[href*="/video/"]'];
      case 'twitch':
        return ['a[href*="/videos/"]', 'a[href*="/clip/"]', 'a[href*="/clips/"]'];
      case 'facebook':
        return ['a[href*="/watch/"]', 'a[href*="/videos/"]', 'a[href*="fb.watch"]', 'a[href*="/reel/"]'];
      default:
        return [];
    }
  }

  function hasVisualThumbnail(anchor) {
    if (!anchor) {
      return false;
    }

    const rect = anchor.getBoundingClientRect();
    if (rect.width < 96 || rect.height < 54) {
      return false;
    }

    return Boolean(anchor.querySelector('img, picture, video, canvas'));
  }

  function getTargetLabel(element, fallback) {
    if (!element) {
      return fallback;
    }

    const text = element.getAttribute('aria-label') || element.textContent || element.title || fallback;
    return sanitizeLabel(text, fallback);
  }

  function resolveVideoElementCandidate(video) {
    if (!video || !video.isConnected) {
      return null;
    }

    const pageUrl = window.location.href;
    const directMedia = video.currentSrc && !video.currentSrc.startsWith('blob:') ? video.currentSrc : '';
    let mediaUrl = directMedia;
    let label = getTargetLabel(video.closest('article, section, main, [role="dialog"]'), 'Detected video');
    let anchor = video;

    const container = video.closest('article, section, main, [role="dialog"], .player, .video-player');
    const siteKey = Common.getSiteKey(window.location.hostname);

    if (siteKey === 'youtube') {
      mediaUrl = '';
      label = sanitizeLabel(document.title, 'YouTube video');
      anchor = video;
    } else if (siteKey === 'twitter') {
      const permalink = container?.querySelector('a[href*="/status/"]');
      mediaUrl = permalink?.href || '';
      label = getTargetLabel(container, 'Tweet video');
      anchor = container || video;
    } else if (siteKey === 'instagram') {
      const reelLink = container?.querySelector('a[href*="/reel/"], a[href*="/reels/"]');
      mediaUrl = reelLink?.href || '';
      label = getTargetLabel(container, 'Instagram reel');
      anchor = container || video;
    } else if (siteKey === 'facebook') {
      const watchLink = container?.querySelector('a[href*="/watch/"], a[href*="/videos/"], a[href*="fb.watch"]');
      mediaUrl = watchLink?.href || directMedia || '';
      label = getTargetLabel(container, 'Facebook video');
      anchor = container || video;
    } else if (siteKey === 'tiktok') {
      mediaUrl = Common.isLikelyVideoPageUrl(pageUrl) ? '' : directMedia;
      label = getTargetLabel(container, 'TikTok video');
      anchor = container || video;
    } else if (siteKey === 'twitch') {
      mediaUrl = Common.isLikelyVideoPageUrl(pageUrl) ? '' : directMedia;
      label = getTargetLabel(container, 'Twitch video');
      anchor = container || video;
    }

    const validation = Common.validateVideoTarget(mediaUrl, pageUrl);
    if (!validation.ok) {
      return null;
    }

    return {
      key: validation.preferredUrl,
      pageUrl,
      mediaUrl,
      label,
      anchor,
    };
  }

  function resolveAnchorCandidate(anchor) {
    if (!anchor?.href || !hasVisualThumbnail(anchor)) {
      return null;
    }

    const validation = Common.validateVideoTarget(anchor.href, anchor.href);
    if (!validation.ok) {
      return null;
    }

    return {
      key: validation.preferredUrl,
      pageUrl: anchor.href,
      mediaUrl: anchor.href,
      label: getTargetLabel(anchor, 'Video page'),
      anchor,
    };
  }

  function collectCandidates() {
    if (!isCurrentSiteAllowed()) {
      return [];
    }

    const candidates = [];
    const seenKeys = new Set();

    document.querySelectorAll('video').forEach((video) => {
      const candidate = resolveVideoElementCandidate(video);
      if (candidate && !seenKeys.has(candidate.key)) {
        seenKeys.add(candidate.key);
        candidates.push(candidate);
      }
    });

    for (const selector of getSiteSelectors()) {
      document.querySelectorAll(selector).forEach((anchor) => {
        const candidate = resolveAnchorCandidate(anchor);
        if (candidate && !seenKeys.has(candidate.key)) {
          seenKeys.add(candidate.key);
          candidates.push(candidate);
        }
      });
    }

    return candidates;
  }

  function setButtonState(entry, state, message) {
    entry.button.dataset.state = state;
    entry.button.textContent =
      state === 'sending'
        ? 'Sending...'
        : state === 'sent'
          ? 'Sent'
          : state === 'offline'
            ? 'Offline'
            : state === 'error'
              ? 'Error'
              : 'Download';
    entry.button.title = message || entry.candidate.label;
  }

  function createOverlayEntry(candidate) {
    const wrapper = document.createElement('div');
    wrapper.className = 'md-video-btn';
    Object.assign(wrapper.style, {
      position: 'fixed',
      zIndex: '2147483647',
      display: 'flex',
      alignItems: 'center',
      gap: '6px',
      pointerEvents: 'auto',
    });

    const select = document.createElement('select');
    Object.assign(select.style, {
      height: '30px',
      borderRadius: '8px',
      border: '1px solid rgba(255, 255, 255, 0.16)',
      background: 'rgba(17, 20, 27, 0.94)',
      color: '#f4f6fb',
      padding: '0 8px',
      fontSize: '12px',
      boxShadow: '0 10px 24px rgba(0, 0, 0, 0.28)',
      backdropFilter: 'blur(12px)',
    });
    QUALITY_OPTIONS.forEach((option) => {
      const item = document.createElement('option');
      item.value = option.value;
      item.textContent = option.label;
      select.appendChild(item);
    });

    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = 'Download';
    Object.assign(button.style, {
      height: '30px',
      borderRadius: '999px',
      border: '1px solid rgba(255, 255, 255, 0.12)',
      padding: '0 12px',
      background: 'linear-gradient(135deg, rgba(32, 163, 158, 0.96), rgba(17, 108, 130, 0.96))',
      color: '#ffffff',
      fontFamily: "'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
      fontSize: '12px',
      fontWeight: '700',
      cursor: 'pointer',
      boxShadow: '0 10px 24px rgba(0, 0, 0, 0.28)',
      backdropFilter: 'blur(12px)',
    });
    button.title = candidate.label;

    button.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      setButtonState(entry, 'sending', candidate.label);

      api.runtime.sendMessage(
        {
          type: 'DOWNLOAD_BTN_CLICK',
          mediaUrl: candidate.mediaUrl,
          pageUrl: candidate.pageUrl,
          options: {
            preferredQuality: select.value,
          },
        },
        (response) => {
          if (api.runtime.lastError) {
            setButtonState(entry, 'offline', 'Desktop app is offline.');
            return;
          }

          if (response?.ok) {
            setButtonState(entry, 'sent', 'Download sent to the desktop app.');
            setTimeout(() => setButtonState(entry, 'ready', candidate.label), 1800);
            return;
          }

          const code = response?.code || 'ERROR';
          setButtonState(entry, code === 'APP_OFFLINE' ? 'offline' : 'error', response?.message || 'Send failed.');
        },
      );
    });

    wrapper.appendChild(select);
    wrapper.appendChild(button);
    document.documentElement.appendChild(wrapper);

    const entry = {
      candidate,
      wrapper,
      button,
      select,
    };

    return entry;
  }

  function cleanupStaleEntries(activeKeys) {
    for (const [key, entry] of overlayRegistry.entries()) {
      if (!activeKeys.has(key) || !entry.candidate.anchor?.isConnected) {
        entry.wrapper.remove();
        overlayRegistry.delete(key);
      }
    }
  }

  function layoutOverlays() {
    layoutFrame = null;
    for (const entry of overlayRegistry.values()) {
      const rect = entry.candidate.anchor.getBoundingClientRect();
      const visible =
        rect.width >= 40 &&
        rect.height >= 24 &&
        rect.bottom > 0 &&
        rect.right > 0 &&
        rect.top < window.innerHeight &&
        rect.left < window.innerWidth;

      if (!visible) {
        entry.wrapper.style.display = 'none';
        continue;
      }

      entry.wrapper.style.display = 'flex';
      entry.wrapper.style.top = `${Math.max(8, rect.top + 8)}px`;
      entry.wrapper.style.left = `${Math.max(8, rect.left + 8)}px`;
    }
  }

  function scheduleLayout() {
    if (layoutFrame) {
      return;
    }

    layoutFrame = window.requestAnimationFrame(layoutOverlays);
  }

  function runScan() {
    scanTimer = null;
    if (!isCurrentSiteAllowed()) {
      cleanupStaleEntries(new Set());
      return;
    }

    const candidates = collectCandidates();
    const activeKeys = new Set();
    for (const candidate of candidates) {
      activeKeys.add(candidate.key);
      if (overlayRegistry.has(candidate.key)) {
        overlayRegistry.get(candidate.key).candidate = candidate;
      } else {
        overlayRegistry.set(candidate.key, createOverlayEntry(candidate));
      }
    }

    cleanupStaleEntries(activeKeys);
    scheduleLayout();
  }

  function scheduleScan() {
    if (scanTimer) {
      clearTimeout(scanTimer);
    }
    scanTimer = setTimeout(runScan, 200);
  }

  async function refreshSettings() {
    const result = await storageGet('sync', ['siteAccessMode', 'siteRules']);
    syncSettings = {
      siteAccessMode: result.siteAccessMode || Common.DEFAULT_SYNC_SETTINGS.siteAccessMode,
      siteRules: Common.normalizeRuleList(result.siteRules),
    };
    scheduleScan();
  }

  api.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type === 'GET_PAGE_CONTEXT') {
      const detectedTargets = collectCandidates().slice(0, 5).map((candidate) => ({
        key: candidate.key,
        label: candidate.label,
        mediaUrl: candidate.mediaUrl,
        pageUrl: candidate.pageUrl,
      }));

      sendResponse({
        ok: true,
        siteAllowed: isCurrentSiteAllowed(),
        canDownloadPage: Common.isLikelyVideoPageUrl(window.location.href),
        detectedTargets,
      });
    }
  });

  api.storage.onChanged.addListener((changes, area) => {
    if (area === 'sync' && (changes.siteAccessMode || changes.siteRules)) {
      refreshSettings();
    }
  });

  refreshSettings().then(() => {
    runScan();
    observer = new MutationObserver(scheduleScan);
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src', 'href'],
    });
    window.addEventListener('scroll', scheduleLayout, true);
    window.addEventListener('resize', scheduleLayout);
  });
})();
