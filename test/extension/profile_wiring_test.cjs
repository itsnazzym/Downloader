const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const shared = path.join(__dirname, '../../extension/shared');
const source = fs.readFileSync(path.join(shared, 'feed_panel.js'), 'utf8');

test('feed_panel.js never builds a TikTok profile URL by hand', () => {
  assert.doesNotMatch(source, /https:\/\/www\.tiktok\.com\/@/);
  assert.doesNotMatch(source, /https:\/\/x\.com\/['"]\s*\+/);
  assert.match(source, /MDProfile\.profileUrl\(/);
});

test('every openCreatorModal call passes handle and platform', () => {
  const calls = [...source.matchAll(/openCreatorModal\(([^)]*)\)/g)];
  assert.ok(calls.length > 0);
  for (const [, args] of calls) {
    assert.equal(args.split(',').length, 2, `openCreatorModal(${args}) needs two arguments`);
  }
  assert.match(source, /currentCreatorPlatform/);
});

test('profileUnavailable is translated in every locale', () => {
  for (const lang of ['fr', 'en', 'ar']) {
    const messages = JSON.parse(fs.readFileSync(path.join(shared, '_locales', lang, 'messages.json'), 'utf8'));
    assert.ok(messages.profileUnavailable && messages.profileUnavailable.message, `${lang} is missing profileUnavailable`);
  }
});
