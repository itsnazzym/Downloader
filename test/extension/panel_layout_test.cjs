const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Source-level checks of the Task 13 layout (feed_panel.js is one DOM-bound IIFE, not loadable here).
const read = (f) => fs.readFileSync(path.join(__dirname, '../../extension/shared', f), 'utf8');
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
  assert.match(cardSource, /var profileHref = MDProfile\.profileUrl\(itemPlatform\(item\), item\.author\);/);
  assert.match(cardSource, /if \(profileHref\) \{\s*var creatorBtn/);
  assert.match(cardSource, /api\.tabs\.create\(\{ url: profileHref \}\)/);
  assert.doesNotMatch(cardSource, /setViewMode\('creators'\)/);
  assert.match(cardSource, /t\('feedOpenAccountTitle'/);
  // The URLs it gets: same platform as the video, none for an unknown platform.
  const ctx = {};
  ctx.self = ctx;
  vm.createContext(ctx);
  vm.runInContext(read('profile_url.js'), ctx);
  assert.equal(ctx.MDProfile.profileUrl('x', '@studio_nova'), 'https://x.com/studio_nova');
  assert.equal(ctx.MDProfile.profileUrl('tiktok', '@fanny_run'), 'https://www.tiktok.com/@fanny_run');
  assert.equal(ctx.MDProfile.profileUrl('web', '@someone'), null);
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
