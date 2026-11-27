const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = (f) => fs.readFileSync(path.join(__dirname, '../../extension/shared', f), 'utf8');
const panel = read('feed_panel.js');
const html = read('feed_panel.html');
const css = read('feed_panel.css');

const NEW_KEYS = [
  'tabDownloads', 'feedViewDownloadsTitle',
  'dlQueuedLine', 'dlEtaLeft', 'dlPaused', 'dlFailed', 'dlCanceled',
  'dlSectionRunning', 'dlSectionQueued', 'dlSectionFailed', 'dlSectionDone',
  'dlClearDone', 'dlDoneHidden', 'dlCancelAll', 'dlSummaryCounts', 'dlEmpty',
  'dlCmdCancel', 'dlCmdRemove', 'dlCmdPause', 'dlCmdResume', 'dlCmdRetry',
  'dlErrInvalidState', 'dlErrUnknownId', 'dlErrCommandFailed', 'dlErrNotConnected', 'appOffline',
];

test('the panel owns one download tracker fed by progress and snapshots', () => {
  assert.equal((panel.match(/MDDownloads\.create\(\)/g) || []).length, 1);
  assert.match(panel, /\.ingest\(message\.data, /);
  assert.match(panel, /\.ingestSnapshot\(message\.items, /);
  assert.match(panel, /'MD_QUEUE_SNAPSHOT'/);
  assert.match(panel, /'MD_DOWNLOAD_COMMAND_RESULT'/);
});

test('snapshots are requested at start and when the app reconnects', () => {
  assert.match(panel, /type: 'MD_QUEUE_SNAPSHOT_REQUEST'/);
  assert.match(panel, /'MD_CONNECTION_STATE'/);
  // Only on a false -> true transition: connection state is republished on every PROGRESS.
  assert.match(panel, /message\.connected && !appConnected/);
});

test('the old progress handler with wrong status comments is gone', () => {
  assert.equal(/Extracting or downloading progress/.test(panel), false);
  assert.equal(/d\.status === [0-9]/.test(panel), false);
  assert.match(panel, /MDDownloads\.statusFromIndex\(d\.status\)/);
});

test('cards read their state from the tracker and offer commands', () => {
  assert.match(panel, /findByCardKey\(/);
  assert.match(panel, /function applyCardDownloadState\(/);
  assert.match(panel, /type: 'MD_DOWNLOAD_COMMAND'/);
  assert.match(panel, /MDDownloads\.allowedCommands\(/);
});

test('downloads view mode and tab exist', () => {
  assert.match(panel, /'downloads'/);
  assert.match(html, /data-mode="downloads"/);
  assert.match(html, /data-i18n="tabDownloads"/);
  assert.match(html, /id="view-mode-downloads-count"/);
  assert.match(html, /id="downloads-view"/);
  assert.match(panel, /\.groups\(\)/);
  assert.match(panel, /\.summary\(/);
  assert.match(panel, /clearDone\(\)/);
  assert.match(panel, /'cancel_all'/);
  assert.match(css, /data-view-mode="downloads"/);
});

test('download rendering is throttled to about 4 frames per second', () => {
  assert.match(panel, /DL_RENDER_MS = 250/);
  assert.match(panel, /function scheduleDownloadRender\(/);
});

test('new strings exist in fr, en and ar', () => {
  for (const lang of ['fr', 'en', 'ar']) {
    const messages = JSON.parse(read('_locales/' + lang + '/messages.json'));
    for (const key of NEW_KEYS) {
      assert.ok(messages[key] && messages[key].message, lang + ' missing ' + key);
    }
  }
});

test('new download CSS uses theme variables only', () => {
  const start = css.indexOf('/* Download tracking');
  assert.ok(start > css.indexOf(':root'), 'download block comes after :root');
  const downloadRules = css.slice(start);
  assert.equal(/#[0-9a-f]{3,8}\b|rgba?\(|hsla?\(/i.test(downloadRules), false);
  for (const v of downloadRules.match(/var\(--[a-z0-9-]+\)/g) || []) {
    assert.ok(['--canvas', '--panel', '--panel-2', '--line', '--ink', '--sub', '--mute', '--a', '--on-a', '--ok', '--bad', '--r-card', '--r-ctl'].includes(v.slice(4, -1)), 'unexpected ' + v);
  }
});

test('the downloads view updates rows in place instead of rebuilding them', () => {
  const start = panel.indexOf('function renderDownloadsView(');
  const end = panel.indexOf('\n  }\n', start);
  const body = panel.slice(start, end);
  assert.ok(start > -1);
  assert.equal(/downloadsView\.(textContent|innerHTML)\s*=/.test(body), false, 'no full rebuild per render');
  assert.match(body, /MDDownloads\.planRowUpdates\(/);
  assert.match(body, /MDFeedStore\.domMoves\(/);
});

test('a canceled card offers retry, like the Downloads tab', () => {
  assert.match(panel, /CARD_COMMAND = \{[^}]*canceled: 'retry'/);
});

test('cancel all only shows when something is queued or running', () => {
  assert.match(panel, /cancelAll\.hidden = offline \|\| s\.running \+ s\.queued === 0/);
});

test('live downloads read offline when the app is unreachable, with their actions off', () => {
  // cards, rows, summary and dock all go through MDDownloads.displayStatus + the connection flag
  assert.match(panel, /function connectionFlag\(\) \{\s*return connectionKnown \? appConnected : undefined;/);
  assert.match(panel, /dl\.status === 'duplicate' \? 'done' : MDDownloads\.displayStatus\(dl\.status, connectionFlag\(\)\)/);
  assert.match(panel, /return section \+ '\|' \+ MDDownloads\.displayStatus\(dl\.status, connectionFlag\(\)\)/);
  assert.match(panel, /var commands = MDDownloads\.allowedCommands\(shown\)/);
  assert.match(panel, /btn\.disabled = mode === 'offline'/);
  assert.match(panel, /=== 'offline'\) return t\('appOffline'/);
  // a connection change repaints the cards and rows; the panel asks for the state when it opens
  assert.match(panel, /connectionKnown = true;\s*\/\/ Live downloads read "offline"[^\n]*\n\s*if \(connectionFlag\(\) !== wasFlag\) scheduleDownloadRender\(\)/);
  assert.match(panel, /type: 'GET_CONNECTION_STATE'/);
  assert.match(css, /\[data-dl-state="offline"\]/);
});

test('a reconnect waits for the snapshot the background asks for, and asks only if none arrives', () => {
  assert.match(panel, /if \(message\.connected && !appConnected\) expectQueueSnapshot\(\)/);
  const start = panel.indexOf('function expectQueueSnapshot(');
  const body = panel.slice(start, panel.indexOf('\n  }\n', start));
  assert.match(body, /downloads\.noteSnapshotRequest\(since\)/);
  assert.match(body, /if \(!downloads\.snapshotSince\(since\)\) requestQueueSnapshot\(\)/);
  assert.equal(/sendRuntimeMessage/.test(body), false);
});

test('the panel asks for a snapshot at most once per 3 s', () => {
  const start = panel.indexOf('function requestQueueSnapshot(');
  const body = panel.slice(start, panel.indexOf('\n  }\n', start));
  assert.match(body, /if \(!downloads\.snapshotDue\(now\)\) return;\s*downloads\.noteSnapshotRequest\(now\);\s*sendRuntimeMessage\(\{ type: 'MD_QUEUE_SNAPSHOT_REQUEST' \}\)/);
  assert.equal((panel.match(/type: 'MD_QUEUE_SNAPSHOT_REQUEST'/g) || []).length, 1);
});

test('the finished section builds at most 50 rows and counts the others', () => {
  assert.match(panel, /DL_DONE_SHOWN = 50/);
  assert.match(panel, /MDDownloads\.capRecent\(groups\.done, DL_DONE_SHOWN\)/);
  assert.match(panel, /done: done\.shown/);
  assert.match(panel, /tf\('dlDoneHidden', '\{count\} autres masqués', \{ count: hidden \}\)/);
  // the "N more" line sits outside the row list that domMoves walks
  assert.match(panel, /box\.appendChild\(list\);\s*\/\/[^\n]*\n\s*var more = dlElement\('div', 'dl-section-more'\)/);
  assert.match(css, /\.dl-section-more \{/);
});

test('queue positions and groups come from the tracker caches, not a scan per row', () => {
  assert.match(panel, /pos: downloads\.queuePosition\(dl\.id\)/);
  assert.equal(/groups\(\)\.queued\.indexOf/.test(panel), false);
});
