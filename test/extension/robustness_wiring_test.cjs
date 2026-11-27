'use strict';
// Source-level guards for the error paths fixed in the robustness audit (task 15).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = (f) => fs.readFileSync(path.join(__dirname, '../../extension/shared', f), 'utf8').replace(/\r\n/g, '\n');
const content = read('content.js');
const connection = read('connection.js');
const panel = read('feed_panel.js');

test('content script messages to the background never leave a rejected promise behind', () => {
  assert.match(content, /function notifyBackground\(message\) \{[\s\S]*?pending\.catch\(function \(\) \{\}\)/);
  for (const type of ['MD_DEEP_SCAN_PROGRESS', 'MD_PAGE_NAVIGATED']) {
    const bare = new RegExp('api\\.runtime\\.sendMessage\\(\\{\\s*type: \'' + type);
    assert.doesNotMatch(content, bare, type + ' must go through notifyBackground');
  }
  // the second feed message of publishNewXFeedItems was fire-and-forget without a catch
  assert.match(content, /p2\.catch\(function \(\) \{\}\)/);
});

test('the HELLO_OK cookie-preference and PROGRESS storage chains have a catch', () => {
  assert.match(connection, /api\.storage\.local\.set\(\{ recentDownloads: recents \}\);\s*\}\)\.catch\(/);
  assert.match(connection, /setTimeout\(sendCurrentTabCookies, 2000\);\s*\}\s*\}\)\.catch\(/);
});

test('the diagnostics log ignores a failed storage write', () => {
  assert.match(connection, /api\.storage\.local\.set\(\{ _mdDiag: logs \}\)\.catch\(function \(\) \{\}\);/);
});

test('closing or replacing a socket releases the callers waiting on it', () => {
  assert.match(connection, /function closeSocketQuietly\(\) \{\s*if \(!socket\) return;\s*failPending\(\);/);
  assert.match(connection, /activeDownloadCount = 0;[^\n]*\n\s*failPending\(\);\s*publishConnectionState\(\);/);
});

test('the panel keeps at most 50 sniffed streams, like the background', () => {
  assert.match(panel, /sniffedStreams\.push\(message\.stream\);\s*if \(sniffedStreams\.length > 50\) sniffedStreams\.shift\(\);/);
});

test('the panel store is capped at MAX_ITEMS', () => {
  assert.match(panel, /MDFeedStore\.create\(MAX_ITEMS\)/);
});

test('a TikTok video without its own handle is attributed to the page owner only on a profile or video page', () => {
  assert.match(content, /var pageUserMatch = window\.location\.pathname\.match\(\/\^\\\/@\(\[a-zA-Z0-9_\.-\]\+\)\(\?:\\\/\(\?:video\|photo\)\\\/\\d\+\)\?\\\/\?\$\/\);/);
  const re = /^\/@([a-zA-Z0-9_.-]+)(?:\/(?:video|photo)\/\d+)?\/?$/;
  assert.equal(re.exec('/@owner')[1], 'owner');
  assert.equal(re.exec('/@owner/video/7123456789')[1], 'owner');
  assert.equal(re.exec('/@owner/collection/mix-7123456789'), null);
  assert.equal(re.exec('/foryou'), null);
});
