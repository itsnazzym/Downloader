const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Source-level checks of the Task 13 layout (feed_panel.js is one DOM-bound IIFE, not loadable here).
const read = (f) => fs.readFileSync(path.join(__dirname, '../../extension/shared', f), 'utf8').replace(/\r\n/g, '\n');
const html = read('feed_panel.html');
const panel = read('feed_panel.js');
const css = read('feed_panel.css');

test('every control the panel script looks up still exists in the page', () => {
  const ids = [...panel.matchAll(/getElementById\('([\w-]+)'\)/g)].map((m) => m[1]);
  const missing = [...new Set(ids)].filter((id) => !html.includes('id="' + id + '"'));
  assert.deepEqual(missing, []);
});

test('header: app icon, name, live indicator and a settings button that opens the menu', () => {
  assert.match(html, /<img class="panel-logo" src="icons\/icon48\.png"/);
  assert.match(html, /<h1 class="panel-brand">TapLoad<\/h1>/);
  const btn = html.match(/<button[^>]*id="panel-menu-btn"[^>]*>/)[0];
  assert.match(btn, /aria-expanded="false"/);
  assert.match(btn, /aria-controls="panel-menu"/);
  assert.match(btn, /data-i18n-aria="panelMenu"/);
  assert.match(html, /<div id="panel-menu"[^>]*\bhidden\b/);
  // Page actions moved into the menu keep their ids.
  for (const id of ['hook-action-btn', 'analyze-btn', 'deep-scan-btn', 'open-x-btn', 'jump-active-btn', 'recover-accounts-btn', 'clear-feed-btn',
    'video-layout-switch', 'hide-downloaded-checkbox', 'auto-clear-checkbox', 'sniffed-count']) {
    const at = html.indexOf('id="' + id + '"');
    assert.ok(at > html.indexOf('id="panel-menu"') && at < html.indexOf('id="view-mode-bar"'), id + ' belongs to the menu');
  }
  assert.match(panel, /function setPanelMenu\(open\)/);
  assert.match(panel, /e\.key !== 'Escape' \|\| panelMenu\.hidden/);
});

test('tool row: select-all circle, Tous / X / TikTok and the order toggle', () => {
  assert.match(html, /id="select-all-btn"[^>]*aria-pressed="false"/);
  assert.match(html, /data-filter="x"[^>]*>X <span class="pill-count" id="x-count">/);
  assert.match(html, /id="feed-order-btn"[\s\S]{0,300}class="order-label"/);
  assert.match(panel, /function syncSelectAllButton\(/);
  assert.match(panel, /function syncPlatformPillState\(/);
  assert.match(panel, /querySelector\('\.order-label'\)/);
});

test('every button is a real button with a type, icon-only ones carry a name', () => {
  for (const tag of html.match(/<button\b[^>]*>/g)) assert.match(tag, /type="button"/, tag);
  for (const id of ['panel-menu-btn', 'select-all-btn', 'preview-close-btn', 'creator-dialog-close']) {
    assert.match(html.match(new RegExp('<button[^>]*id="' + id + '"[^>]*>'))[0], /aria-label="/, id);
  }
});

test('the card: 80 px thumb with duration and circle, meta + detail lines, one action, hover actions, bottom progress', () => {
  for (const token of ["'card-thumb'", "'thumb-duration'", "'card-meta-text'", "'card-detail'", "'card-actions'",
    "'card-dl-state'", "'card-single-dl-btn'", "'card-progress-bar-wrap'", "'feed-checkbox'"]) {
    assert.ok(panel.includes(token), 'createFeedCard misses ' + token);
  }
  assert.match(panel, /card\.appendChild\(progressWrap\)/);
  assert.match(panel, /thumbWrap\.appendChild\(checkbox\)/);
  assert.match(panel, /creatorBtn\.setAttribute\('aria-label'/);
  assert.match(panel, /mode === 'download' && downloaded \? 'done' : mode/);
  assert.match(css, /\.card-thumb \{[^}]*width: 80px; height: 80px;[^}]*min\(calc\(var\(--r-card\) \* \.55\), 14px\)/);
  // Hover-only controls are also reachable from the keyboard.
  assert.match(css, /\.feed-card:focus-within \.card-actions/);
  assert.match(css, /\.feed-card:focus-within \.feed-checkbox/);
  assert.match(css, /:focus-visible \{ outline: 2px solid var\(--ink\)/);
});

test('docks and toast', () => {
  assert.match(html, /<button type="button" id="activity-dock"[^>]*hidden>/);
  assert.match(html, /<div id="toast" class="toast" role="status" aria-live="polite" hidden>/);
  assert.match(panel, /function renderActivityDock\(active\)/);
  assert.match(panel, /function showToast\(message\)/);
  assert.match(panel, /document\.body\.dataset\.hasSelection = String\(count > 0\)/);
  assert.match(css, /body\[data-view-mode="videos"\]:not\(\[data-has-selection="true"\]\) \.panel-footer \{ display: none; \}/);
  assert.match(css, /body\[data-has-selection="true"\] \.activity-dock/);
});

test('controls use the theme radii: square in a radius-0 design', () => {
  const radii = [...css.matchAll(/border-radius:\s*([^;}]+)/g)].map((m) => m[1].trim());
  // Only the logo, status dots and flush grid thumbs keep a fixed radius.
  const fixed = radii.filter((r) => !/var\(--r-(card|ctl)\)/.test(r));
  assert.deepEqual([...new Set(fixed)].sort(), ['0', '50%', '8px']);
});

test('the new strings exist in fr, en and ar', () => {
  const keys = ['panelMenu', 'menuFilters', 'feedDeselectAll', 'feedOrderTitle', 'feedOrderFlux', 'feedOrderRecent', 'feedFilterOn', 'feedFilterClear'];
  for (const lang of ['fr', 'en', 'ar']) {
    const messages = JSON.parse(read('_locales/' + lang + '/messages.json'));
    for (const key of keys) assert.ok(messages[key] && messages[key].message, lang + ' lacks ' + key);
    assert.match(messages.feedFilterOn.message, /\{name\}/, lang);
    assert.equal(messages.cardShowAccount, undefined, lang + ' keeps the dead cardShowAccount key');
  }
  for (const key of ['panelMenu', 'menuFilters', 'feedOrderTitle', 'feedFilterClear']) assert.match(html, new RegExp('data-i18n(-aria|-title)?="' + key + '"'));
});

// Body of createFeedCard, to check what the card itself wires.
const cardSource = panel.slice(panel.indexOf('function createFeedCard('), panel.indexOf('function replaceItems('));

test('the card profile button opens the author on the video platform, and only when a URL exists', () => {
  assert.match(cardSource, /if \(profileHref\) \{\s*var creatorBtn/);
  assert.match(cardSource, /api\.tabs\.create\(\{ url: profileHref \}\)/);
  assert.doesNotMatch(cardSource, /setViewMode\('creators'\)/);
  assert.match(cardSource, /t\('feedOpenAccountTitle'/);
  // Run the card's own lines (itemHandle + the profileHref computation) against real items.
  const helper = panel.match(/\n  function itemHandle\(item\) \{[\s\S]*?\n  \}\n/)[0];
  const lines = cardSource.match(/ {4}var cardHandle = [^\n]*\n {4}var profileHref = [^\n]*\n/)[0];
  const ctx = {};
  ctx.self = ctx;
  vm.createContext(ctx);
  vm.runInContext(read('profile_url.js'), ctx);
  vm.runInContext('function itemPlatform(item) { return item.platform; }' + helper +
    'function cardProfileHref(item) {' + lines + ' return profileHref; }', ctx);
  const href = (item) => ctx.cardProfileHref(item);
  assert.equal(href({ platform: 'x', author: 'Studio Nova@studio_nova·2h', url: 'https://x.com/studio_nova/status/123', pageUrl: 'https://x.com/home' }), 'https://x.com/studio_nova');
  assert.equal(href({ platform: 'tiktok', author: 'Fanny', url: 'https://www.tiktok.com/@fanny_run/video/9' }), 'https://www.tiktok.com/@fanny_run');
  assert.equal(href({ platform: 'tiktok', author: '@fanny_run', url: 'https://www.tiktok.com/video/9' }), null);
  assert.equal(href({ platform: 'youtube', author: 'Camille', url: 'https://www.youtube.com/shorts/abc' }), null);
  assert.equal(href({ platform: 'instagram', author: 'Reels', url: 'https://www.instagram.com/reel/abc/' }), null);
  assert.equal(href({ platform: 'web', author: '@someone', url: 'https://example.com/v.mp4' }), null);
  for (const lang of ['fr', 'en', 'ar']) {
    const messages = JSON.parse(read('_locales/' + lang + '/messages.json'));
    assert.doesNotMatch(messages.feedOpenAccountTitle.message, /Comptes|Accounts|الحسابات/, lang);
  }
});

test('hover actions sit at the end of the meta line, never over the title, and hide while downloading', () => {
  assert.match(cardSource, /metadata\.appendChild\(hoverActions\)/);
  assert.doesNotMatch(cardSource, /card\.appendChild\(hoverActions\)/);
  const rule = css.match(/\.card-actions \{[^}]*\}/)[0];
  assert.doesNotMatch(rule, /position: absolute/);
  assert.match(rule, /opacity: 0/); // invisible but still taking its room: no jump on hover
  assert.match(css, /\.feed-card\[data-dl-state="running"\] \.card-actions \{ visibility: hidden; \}/);
});

test('a filter picked in the menu shows a removable chip and a dot on the settings button', () => {
  assert.match(html, /<div id="active-filter-note" class="active-filter-note" hidden>/);
  assert.match(html, /<button type="button" id="active-filter-clear"[^>]*aria-label="Retirer le filtre"[^>]*data-i18n-aria="feedFilterClear"/);
  assert.match(panel, /note\.hidden = !menuFilter/);
  assert.match(panel, /menuBtn\.classList\.toggle\('has-filter', !!menuFilter\)/);
  assert.match(panel, /activeFilterClear\.addEventListener\('click', function \(\) \{ selectPlatformFilter\('all'\); \}\)/);
  assert.match(css, /\.icon-btn\.has-filter::after/);
  assert.match(css, /body\[data-view-mode="downloads"\] :is\([^)]*\.active-filter-note/);
});

test('accounts and the meta line use the handle from the post URL, never a messy display name', () => {
  assert.match(panel, /var pUrl = handle \? MDProfile\.profileUrl\(plat, handle\) : null;/);
  assert.match(panel, /return MDProfile\.creatorKey\(itemPlatform\(item\), itemHandle\(item\) \|\| item\.author\);/);
  assert.match(cardSource, /itemAuthorLabel\(item\)/);
  assert.match(cardSource, /metaText\.title = metaText\.textContent/);
  const helpers = panel.match(/\n  function itemHandle\(item\) \{[\s\S]*?\n  function itemAuthorLabel\(item\) \{[\s\S]*?\n  \}\n/)[0];
  const ctx = {};
  ctx.self = ctx;
  vm.createContext(ctx);
  vm.runInContext(read('profile_url.js'), ctx);
  vm.runInContext('function itemPlatform(item) { return item.platform; }' + helpers, ctx);
  const messy = 'Studio Nova@studio_nova·2h';
  assert.equal(ctx.itemAuthorLabel({ platform: 'x', author: messy, url: 'https://x.com/studio_nova/status/1' }), '@studio_nova');
  assert.equal(ctx.itemAuthorLabel({ platform: 'x', author: messy, url: 'https://x.com/i/status/1' }), '');
  assert.equal(ctx.itemAuthorLabel({ platform: 'instagram', author: 'Camille' }), 'Camille');
  assert.equal(ctx.itemCreatorKey({ platform: 'x', author: messy, url: 'https://x.com/Studio_Nova/status/1' }), 'x:studio_nova');
});

// Runs the panel's own creator-banner code (syncCreatorProfileBanner, loadAllCreatorVideos,
// creatorHandleFor and the item helpers) in a vm, with stub elements and a fixed feed.
function creatorHarness(items) {
  const fn = (name) => panel.match(new RegExp(String.raw`\n  function ${name}\([^)]*\) \{[\s\S]*?\n  \}\n`))[0];
  const el = () => ({ textContent: '', hidden: false, disabled: false, src: '', style: { display: '', setProperty() {}, removeProperty() {} },
    classList: { add() {}, remove() {} }, querySelector() { return { textContent: '' }; } });
  const ctx = { items, log: { status: [], updates: [], created: [], tabs: 0 } };
  ctx.self = ctx;
  vm.createContext(ctx);
  vm.runInContext(read('profile_url.js'), ctx);
  vm.runInContext(`
    var activeCreatorFilter = 'all', activeCreatorPlatform = '', activeTabUrl = '', previousPlaylistUrl = '';
    var creatorProfileBanner = el(), creatorBannerHandle = el(), creatorBannerAvatar = el(), creatorBannerSubtitle = el();
    var loadCreatorProfileBtn = el(), dlCreatorProfileBtn = el(), backToPlaylistBtn = el();
    var api = { tabs: { update: function (id, o) { log.updates.push(o.url); }, create: function (o) { log.created.push(o.url); } } };
    function t(k, f) { return f; }
    function tf(k, f) { return f; }
    function setStatus(m, s) { log.status.push(s + ':' + m); }
    function getTargetTab(cb) { log.tabs++; cb({ id: 1, url: 'https://x.com/home' }); }
    function startDeepScan() {}
    function renderItems() {}
    function updateFeedCountStatus() {}
    function setTimeout() {}
    function allItems() { return items; }
    function itemPlatform(item) { return item.platform; }
  `, Object.assign(ctx, { el }));
  for (const name of ['itemHandle', 'itemCreatorKey', 'creatorHandleFor', 'syncCreatorProfileBanner', 'loadAllCreatorVideos']) vm.runInContext(fn(name), ctx);
  ctx.banner = (platform, filter) => {
    vm.runInContext('activeCreatorPlatform = ' + JSON.stringify(platform) + '; activeCreatorFilter = ' + JSON.stringify(filter) + '; syncCreatorProfileBanner();', ctx);
    const shown = vm.runInContext('loadCreatorProfileBtn.style.display !== "none" && dlCreatorProfileBtn.style.display !== "none"', ctx);
    return { shown, handle: vm.runInContext('creatorBannerHandle.textContent', ctx) };
  };
  return ctx;
}

const FEED = [
  { platform: 'x', author: 'Studio Nova@studio_nova·2h', url: 'https://x.com/studio_nova/status/1', pageUrl: 'https://x.com/home' },
  { platform: 'tiktok', author: 'Fanny', url: 'https://www.tiktok.com/@fanny_run/video/9' },
  { platform: 'tiktok', author: 'Camille', url: 'https://www.tiktok.com/video/8' },
  { platform: 'youtube', author: 'Camille', url: 'https://www.youtube.com/shorts/abc' },
  { platform: 'instagram', author: 'Reels', url: 'https://www.instagram.com/reel/abc/' },
];

test('the creator banner offers profile actions only for a handle proven by a post URL', () => {
  const h = creatorHarness(FEED);
  assert.deepEqual(h.banner('x', 'studio_nova'), { shown: true, handle: '@studio_nova' });
  assert.deepEqual(h.banner('tiktok', 'fanny_run'), { shown: true, handle: '@fanny_run' });
  // Display names from the Accounts tab ("Voir les vidéos") never get Load all / Send account.
  assert.deepEqual(h.banner('youtube', 'Camille'), { shown: false, handle: 'Camille' });
  assert.deepEqual(h.banner('instagram', 'Reels'), { shown: false, handle: 'Reels' });
  assert.deepEqual(h.banner('tiktok', 'Camille'), { shown: false, handle: 'Camille' });
  assert.match(panel, /var resolved = creatorHandleFor\(activeCreatorPlatform, clean\);/); // Send account button
});

test('loadAllCreatorVideos refuses a creator whose handle no post URL confirms', () => {
  const h = creatorHarness(FEED);
  for (const [platform, name] of [['youtube', 'Camille'], ['instagram', 'Reels'], ['tiktok', 'Camille']]) {
    vm.runInContext('loadAllCreatorVideos(' + JSON.stringify(name) + ', ' + JSON.stringify(platform) + ')', h);
  }
  assert.equal(h.log.tabs, 0, 'no tab touched');
  assert.deepEqual([...h.log.updates, ...h.log.created], []);
  assert.equal(h.log.status.length, 3);
  for (const s of h.log.status) assert.equal(s, 'error:Profil indisponible sur cette plateforme');
  // The messy X author still resolves through the status URL.
  vm.runInContext("loadAllCreatorVideos('studio_nova', 'x')", h);
  assert.deepEqual([...h.log.updates], ['https://x.com/studio_nova']);
  assert.equal(vm.runInContext('activeCreatorFilter', h), 'studio_nova');
});
