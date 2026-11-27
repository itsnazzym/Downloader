const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(
  path.join(__dirname, '../../extension/shared/connection.js'),
  'utf8',
);
const start = source.indexOf('  function isMissingContentReceiverError(error) {');
const end = source.indexOf('  function sendTikTokCollectionsToApp(', start);
assert.ok(start >= 0 && end > start, 'TikTok sync transport is available');
const implementation = source.slice(start, end);

function loadSync(api) {
  const socketMessages = [];
  const diagnostics = [];
  const sentCollections = [];
  const context = {
    api,
    socket: { readyState: 1, send: (value) => socketMessages.push(JSON.parse(value)) },
    WebSocket: { OPEN: 1 },
    logDiag: (event, detail) => diagnostics.push({ event, detail }),
    sendTikTokCollectionsToApp: (...args) => sentCollections.push(args),
  };
  vm.createContext(context);
  vm.runInContext(
    `${implementation}\nthis.sync = syncTikTokCollections;`,
    context,
  );
  return { sync: context.sync, socketMessages, diagnostics, sentCollections };
}

test('sync injects the missing TikTok content script and retries the same tab', async () => {
  let sendCount = 0;
  let injection;
  const api = {
    tabs: {
      query: async () => [{ id: 42, active: true, url: 'https://www.tiktok.com/@user' }],
      sendMessage: async () => {
        sendCount++;
        if (sendCount === 1) {
          throw new Error('Could not establish connection. Receiving end does not exist.');
        }
        return {
          ok: true,
          collections: [{ id: 'collection-1', name: 'Favorites', videoIds: [] }],
          collectionListComplete: true,
        };
      },
    },
    scripting: {
      executeScript: async (details) => { injection = details; },
    },
  };
  const result = loadSync(api);

  await result.sync(73);

  assert.equal(sendCount, 2);
  assert.deepEqual(JSON.parse(JSON.stringify(injection)), {
    target: { tabId: 42, frameIds: [0] },
    files: ['url_policy.js', 'theme.js', 'x_actions.js', 'content.js'],
  });
  assert.equal(result.sentCollections.length, 1);
  assert.equal(result.sentCollections[0][2], 73);
  assert.deepEqual(result.socketMessages, []);
});

test('sync reports an actionable code when the browser refuses script injection', async () => {
  const api = {
    tabs: {
      query: async () => [{ id: 42, active: true, url: 'https://www.tiktok.com/@user' }],
      sendMessage: async () => {
        throw new Error('Could not establish connection. Receiving end does not exist.');
      },
    },
    scripting: {
      executeScript: async () => { throw new Error('Cannot access contents of this page'); },
    },
  };
  const result = loadSync(api);

  await result.sync(74);

  assert.equal(result.socketMessages.length, 1);
  assert.deepEqual(result.socketMessages[0], {
    type: 'TIKTOK_COLLECTIONS_SYNC',
    collections: [],
    collectionListComplete: false,
    error: 'collection_items_unavailable',
    requestId: 74,
  });
  assert.ok(result.diagnostics.some((entry) => entry.event === 'TIKTOK_SYNC_INJECT_ERR'));
});
