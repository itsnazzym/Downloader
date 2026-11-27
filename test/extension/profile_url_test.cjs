const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/profile_url.js'), 'utf8');

function load() {
  const context = {};
  context.self = context;
  vm.createContext(context);
  vm.runInContext(source, context);
  return context.MDProfile;
}

test('builds the profile URL for each supported platform', () => {
  const p = load();
  assert.equal(p.profileUrl('x', '@Alice'), 'https://x.com/Alice');
  assert.equal(p.profileUrl('tiktok', 'alice'), 'https://www.tiktok.com/@alice');
  assert.equal(p.profileUrl('instagram', 'alice'), 'https://www.instagram.com/alice/');
  assert.equal(p.profileUrl('youtube', 'alice'), 'https://www.youtube.com/@alice');
  assert.equal(p.profileUrl('facebook', 'alice'), 'https://www.facebook.com/alice');
  assert.equal(p.profileUrl('twitch', 'alice'), 'https://www.twitch.tv/alice');
});

test('unknown platforms and unsafe handles give null', () => {
  const p = load();
  assert.equal(p.profileUrl('generic', 'alice'), null);
  assert.equal(p.profileUrl('x', ''), null);
  assert.equal(p.profileUrl('x', 'a/b'), null);
  assert.equal(p.profileUrl('x', '..'), null);
  assert.equal(p.profileUrl('x', 'a b'), null);
  assert.equal(p.profileUrl('x', 'a'.repeat(51)), null);
  assert.equal(p.profileUrl('x', null), null);
});

test('normalizeHandle strips one leading @ and trims', () => {
  const p = load();
  assert.equal(p.normalizeHandle('  @Alice_1.b '), 'Alice_1.b');
  assert.equal(p.normalizeHandle('@@alice'), null);
  assert.equal(p.normalizeHandle('@'), null);
});

test('supportsProfile mirrors profileUrl', () => {
  const p = load();
  assert.equal(p.supportsProfile('youtube', ''), false);
  assert.equal(p.supportsProfile('generic', 'alice'), false);
  assert.equal(p.supportsProfile('youtube', 'alice'), true);
});

test('creatorKey separates the same handle on different platforms and normalises casing', () => {
  const p = load();
  const x = p.creatorKey('x', 'Bob');
  const tiktok = p.creatorKey('tiktok', '@bob ');
  assert.equal(x, 'x:bob');
  assert.equal(tiktok, 'tiktok:bob');
  assert.notEqual(x, tiktok);
  assert.equal(p.creatorKey('x', '@BOB'), x);
  assert.notEqual(p.profileUrl('x', 'bob'), p.profileUrl('tiktok', 'bob'));
});

test('handleFromItem reads X handles from the post URL, never from the display text', () => {
  const p = load();
  const messy = 'Studio Nova@studio_nova·2h';
  assert.equal(p.handleFromItem({ platform: 'x', author: messy, url: 'https://x.com/studio_nova/status/123', pageUrl: 'https://x.com/home' }), 'studio_nova');
  assert.equal(p.handleFromItem({ platform: 'x', author: messy, url: 'https://twitter.com/Studio_Nova/status/123?s=20' }), 'Studio_Nova');
  assert.equal(p.handleFromItem({ platform: 'x', author: messy, url: 'https://mobile.x.com/abc/status/9' }), 'abc');
  // Reserved first segments and non-post pages name nobody.
  assert.equal(p.handleFromItem({ platform: 'x', author: '@studio_nova', url: 'https://x.com/i/status/1', pageUrl: 'https://x.com/home' }), null);
  assert.equal(p.handleFromItem({ platform: 'x', author: '@studio_nova', url: 'https://x.com/i/web/status/1' }), null);
  assert.equal(p.handleFromItem({ platform: 'x', url: 'https://video.twimg.com/a.mp4', pageUrl: 'https://x.com/someone' }), null);
  // The post URL may sit in pageUrl (status page) when url is the media file.
  assert.equal(p.handleFromItem({ platform: 'x', url: 'https://video.twimg.com/a.mp4', pageUrl: 'https://x.com/lea_en_voyage/status/7' }), 'lea_en_voyage');
  // X handles are 1-15 word characters; other hosts never count.
  assert.equal(p.handleFromItem({ platform: 'x', url: 'https://x.com/this_is_too_long_x/status/1' }), null);
  assert.equal(p.handleFromItem({ platform: 'x', url: 'https://notx.com/abc/status/1' }), null);
});

test('handleFromItem reads TikTok handles from the video URL, else only from an @author', () => {
  const p = load();
  assert.equal(p.handleFromItem({ platform: 'tiktok', author: 'Fanny', url: 'https://www.tiktok.com/@fanny_run/video/9' }), 'fanny_run');
  assert.equal(p.handleFromItem({ platform: 'tiktok', author: '@fanny_run', url: 'https://www.tiktok.com/video/9' }), 'fanny_run');
  assert.equal(p.handleFromItem({ platform: 'tiktok', author: 'Camille', url: 'https://www.tiktok.com/video/9' }), null);
  assert.equal(p.handleFromItem({ platform: 'tiktok', author: 'Camille Cuisine', url: 'https://www.tiktok.com/foryou' }), null);
  // A collection page belongs to its owner, not to the video's author.
  assert.equal(p.handleFromItem({ platform: 'tiktok', author: 'Camille', url: 'https://www.tiktok.com/video/9', pageUrl: 'https://www.tiktok.com/@owner/collection/x-1' }), null);
});

test('handleFromItem gives nothing for platforms without a reliable handle', () => {
  const p = load();
  assert.equal(p.handleFromItem({ platform: 'youtube', author: 'Camille', url: 'https://www.youtube.com/shorts/abc' }), null);
  assert.equal(p.handleFromItem({ platform: 'instagram', author: 'Reels', url: 'https://www.instagram.com/reel/abc/' }), null);
  assert.equal(p.handleFromItem({ platform: 'instagram', author: '@camille', url: 'https://www.instagram.com/reel/abc/' }), null);
  assert.equal(p.handleFromItem({ platform: 'web', author: '@someone', url: 'https://example.com/v.mp4' }), null);
  assert.equal(p.handleFromItem(null), null);
  assert.equal(p.handleFromItem({ platform: 'x' }), null);
});
