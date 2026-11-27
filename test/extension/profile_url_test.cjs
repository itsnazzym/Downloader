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
