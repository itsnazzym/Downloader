const test = require('node:test');
const assert = require('node:assert/strict');
const Common = require('../common.js');

test('normalizeHostname strips common prefixes', () => {
  assert.equal(Common.stripCommonPrefixes('WWW.YouTube.com'), 'youtube.com');
  assert.equal(Common.stripCommonPrefixes('m.instagram.com'), 'instagram.com');
});

test('validateVideoTarget accepts video pages and rejects photo pages', () => {
  assert.equal(
    Common.validateVideoTarget('', 'https://www.youtube.com/watch?v=abc').ok,
    true,
  );
  assert.equal(
    Common.validateVideoTarget('https://x.com/user/status/1234567890', '').ok,
    true,
  );
  assert.equal(
    Common.validateVideoTarget('', 'https://www.instagram.com/p/example/').code,
    'VIDEO_NOT_DETECTED',
  );
  assert.equal(
    Common.validateVideoTarget('https://cdn.example.com/image.jpg', 'https://www.youtube.com/watch?v=abc').code,
    'PHOTO_NOT_SUPPORTED',
  );
});

test('site policy supports allowlist and blocklist', () => {
  assert.equal(Common.isSiteAllowed('www.youtube.com', 'supported', []), true);
  assert.equal(Common.isSiteAllowed('www.youtube.com', 'allowlist', ['youtube.com']), true);
  assert.equal(Common.isSiteAllowed('www.youtube.com', 'allowlist', ['tiktok.com']), false);
  assert.equal(Common.isSiteAllowed('m.youtube.com', 'blocklist', ['youtube.com']), false);
});

test('cookie domain candidates include canonical site hosts', () => {
  const domains = Common.getCookieDomainCandidatesFromUrls([
    'https://m.youtube.com/watch?v=abc',
    'https://r3---sn.googlevideo.com/videoplayback?id=abc',
  ]);

  assert.ok(domains.includes('youtube.com'));
  assert.ok(domains.includes('m.youtube.com'));
});

test('clampPort keeps valid values and falls back otherwise', () => {
  assert.equal(Common.clampPort('8080'), 8080);
  assert.equal(Common.clampPort('0', 6969), 6969);
  assert.equal(Common.clampPort('90000', 6969), 6969);
});
