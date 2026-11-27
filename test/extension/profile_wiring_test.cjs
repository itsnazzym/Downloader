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

// Argument lists of every call to `name`, definitions excluded.
function callArgs(name) {
  return [...source.matchAll(new RegExp('(function\\s+)?\\b' + name + '\\(([^()]*)\\)', 'g'))]
    .filter((m) => !m[1])
    .map((m) => m[2].split(',').map((a) => a.trim()).filter(Boolean));
}

function definitionParams(name) {
  const m = source.match(new RegExp('function\\s+' + name + '\\(([^)]*)\\)'));
  assert.ok(m, `${name} is not defined`);
  return m[1].split(',').map((a) => a.trim()).filter(Boolean);
}

test('creator entry points take the platform explicitly and every caller passes it', () => {
  const expected = { openCreatorModal: 2, loadAllCreatorVideos: 2, selectCreatorFilter: 2 };
  for (const [name, count] of Object.entries(expected)) {
    assert.equal(definitionParams(name).length, count, `${name} must declare ${count} parameters`);
    for (const args of callArgs(name)) {
      assert.equal(args.length, count, `${name}(${args.join(', ')}) needs ${count} arguments`);
    }
  }
  // These two have live callers, so a regression to one argument cannot slip through unnoticed.
  assert.ok(callArgs('loadAllCreatorVideos').length >= 2);
  assert.ok(callArgs('selectCreatorFilter').length >= 1);
});

test('the platform travels with the selected creator, never guessed from the feed', () => {
  assert.doesNotMatch(source, /handleProfileUrl/);
  assert.doesNotMatch(source, /feedItems\[0\]/);
  assert.match(source, /var activeCreatorPlatform/);
  assert.match(source, /currentCreatorPlatform/);
  assert.match(source, /MDProfile\.creatorKey\(/);
  // The creator filter must compare platform+handle keys, not bare handles.
  assert.doesNotMatch(source, /targetHandle/);
});

test('profileUnavailable is translated in every locale', () => {
  for (const lang of ['fr', 'en', 'ar']) {
    const messages = JSON.parse(fs.readFileSync(path.join(shared, '_locales', lang, 'messages.json'), 'utf8'));
    assert.ok(messages.profileUnavailable && messages.profileUnavailable.message, `${lang} is missing profileUnavailable`);
  }
});
