const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/content.js'), 'utf8').replace(/\r\n/g, '\n');
const start = source.indexOf('  function waitForTikTok(ms) {');
const end = source.indexOf('  function injectTikTokSyncBanner()', start);
assert.ok(start >= 0 && end > start, 'collection implementation is available');
const implementation = source.slice(start, end);

function loadExtractor(
  fetch,
  document,
  findScrollableAncestor = () => null,
  scheduler = {},
  imageExtractor = () => null,
) {
  const context = {
    fetch,
    document,
    findScrollableAncestor,
    extractCleanImageUrl: imageExtractor,
    setTimeout: scheduler.setTimeout || setTimeout,
    clearTimeout: scheduler.clearTimeout || clearTimeout,
    AbortController,
    URL,
    Map,
    Set,
  };
  vm.createContext(context);
  vm.runInContext(implementation + '\nthis.extract = extractTikTokCollections;', context);
  return context.extract;
}

function json(data) {
  const serialized = JSON.stringify(data);
  return {
    ok: true,
    json: async () => data,
    text: async () => serialized,
  };
}

test('sync paginates collection folders and videos', async () => {
  const calls = [];
  const fetch = async (address) => {
    const url = new URL(address);
    calls.push(url);
    if (url.pathname.includes('/collection/list/')) {
      const cursor = url.searchParams.get('cursor');
      return json(cursor === '0'
        ? { collectionList: Array.from({ length: 35 }, (_, i) => ({ id: String(70000000 + i), name: `Folder ${i}`, total: 1 })), hasMore: true, cursor: 35 }
        : { collectionList: [{ id: '70000035', name: 'Folder 35', total: 2 }], hasMore: false });
    }
    if (url.pathname.includes('/collection/item_list/')) {
      assert.equal(url.searchParams.get('aid'), '1988');
      assert.equal(url.searchParams.get('sourceType'), '113');
      assert.equal(url.searchParams.get('count'), '30');
      const id = url.searchParams.get('collectionId');
      const cursor = url.searchParams.get('cursor');
      if (id === '70000035' && cursor === '0') {
        return json({ itemList: [{ id: '7400000000000000001' }], hasMore: true, cursor: 30 });
      }
      if (id === '70000035') {
        return json({ itemList: [{ id: '7400000000000000002' }], hasMore: false });
      }
      return json({ itemList: [{ id: '7400000000000000001' }], hasMore: false });
    }
    throw new Error(`Unexpected URL: ${url}`);
  };
  const document = { querySelector: () => null };
  const result = await loadExtractor(fetch, document)();
  assert.equal(result.ok, true);
  assert.equal(result.found, 36);
  assert.equal(result.collections.length, 36);
  assert.equal(result.collectionListComplete, true);
  const lastCollection = result.collections.find((collection) => collection.name === 'Folder 35');
  assert.equal(lastCollection.videoIds.length, 2);
  assert.equal(lastCollection.complete, true);
  assert.equal(
    lastCollection.videoUrls['7400000000000000001'],
    'https://www.tiktokv.com/share/video/7400000000000000001/',
  );
  assert.equal(calls.filter((url) => url.pathname.includes('/collection/list/')).length, 2);
});

test('uses TikTok-supported collection page size for every video page', async () => {
  const itemCalls = [];
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({
        collectionList: [{ id: '75000001', name: 'Thirty one', total: 31 }],
        hasMore: false,
      });
    }
    itemCalls.push(url);
    const cursor = url.searchParams.get('cursor');
    return json({
      itemList: cursor === '0'
        ? Array.from({ length: 30 }, (_, index) => ({ aweme_id: String(7400000000000000000n + BigInt(index)) }))
        : [{ aweme_id: '7400000000000000030' }],
      hasMore: cursor === '0',
      cursor: cursor === '0' ? '30' : '30',
    });
  };

  const result = await loadExtractor(fetch, { querySelector: () => null })();

  assert.ok(itemCalls.length >= 2);
  assert.ok(itemCalls.every((url) => url.searchParams.get('count') === '30'));
  assert.equal(result.collections[0].videoIds.length, 31);
  assert.equal(result.collections[0].complete, true);
});

test('sync uses visible collection grid when the list API is unavailable', async () => {
  let loaded = false;
  const scroller = { scrollTop: 0, clientHeight: 700 };
  const makeLink = (name, id) => ({
    href: `https://www.tiktok.com/@owner/collection/${name}-${id}`,
    innerText: `${name}\n2 vidéos`,
    textContent: `${name}\n2 vidéos`,
    coverUrl: id === '75000001' ? 'https://p16-sign-va.tiktokcdn.com/cover.jpg' : null,
    scrollIntoView() { loaded = true; },
  });
  const links = [makeLink('One', '75000001'), makeLink('Two', '75000002'), makeLink('Three', '75000003')];
  const document = {
    body: { innerText: 'Collections 3' },
    scrollingElement: scroller,
    documentElement: scroller,
    querySelector: () => links[0],
    querySelectorAll: () => loaded ? links : links.slice(0, 2),
  };
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) throw new Error('blocked');
    const id = url.searchParams.get('collectionId');
    return json({
      itemList: [{ id: `${id}01` }, { id: `${id}02` }],
      hasMore: false,
    });
  };
  const result = await loadExtractor(
    fetch,
    document,
    () => scroller,
    {},
    (link) => link.coverUrl,
  )();
  assert.equal(result.ok, true);
  assert.equal(result.found, 3);
  assert.equal(result.collectionListComplete, true);
  assert.deepEqual(Array.from(result.collections, (collection) => collection.name).sort(), ['One', 'Three', 'Two']);
  assert.equal(
    result.collections.find((collection) => collection.id === '75000001').coverUrl,
    'https://p16-sign-va.tiktokcdn.com/cover.jpg',
  );
  assert.ok(result.collections.every((collection) => collection.complete));
  assert.equal(scroller.scrollTop, 0);
});

test('sync retains TikTok CDN collection covers from the collection API', async () => {
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({
        collectionList: [{
          id: '75000004',
          name: 'With cover',
          total: 1,
          cover: { originCover: 'https://p16-sign-va.tiktokcdn.com/cover.jpg' },
        }],
        hasMore: false,
      });
    }
    return json({ itemList: [{ aweme_id: '7400000000000000040' }], hasMore: false });
  };
  const result = await loadExtractor(fetch, { querySelector: () => null })();

  assert.equal(
    result.collections[0].coverUrl,
    'https://p16-sign-va.tiktokcdn.com/cover.jpg',
  );
});

test('a collection whose stream reaches hasMore false completes even if declared total has deleted videos', async () => {
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({
        collectionList: [{ id: '76000001', name: 'Partial', total: 2 }],
        hasMore: false,
      });
    }
    return json({ itemList: [{ id: '7400000000000000001' }], hasMore: false });
  };
  const result = await loadExtractor(fetch, { querySelector: () => null })();
  assert.equal(result.collectionListComplete, true);
  assert.equal(result.collections.length, 1);
  assert.equal(result.collections[0].complete, true);
  assert.equal(result.collections[0].error, null);
});

test('a collection with terminal page missing itemList completes cleanly', async () => {
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({
        collectionList: [{ id: '76000002', name: 'TerminalEmpty', total: 100 }],
        hasMore: false,
      });
    }
    const cursor = url.searchParams.get('cursor');
    if (cursor === '0') {
      return json({
        itemList: [{ id: '7400000000000000010' }],
        hasMore: true,
        cursor: '30',
      });
    }
    // TikTok returns statusCode 0 and hasMore false without itemList on terminal page
    return json({
      statusCode: 0,
      hasMore: false,
      cursor: '100',
    });
  };
  const result = await loadExtractor(fetch, { querySelector: () => null })();
  assert.equal(result.collectionListComplete, true);
  assert.equal(result.collections.length, 1);
  assert.equal(result.collections[0].complete, true);
  assert.equal(result.collections[0].error, null);
  assert.equal(result.collections[0].videoIds.length, 1);
});

test('a collection with terminal page missing both itemList and hasMore completes cleanly without crashing', async () => {
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({
        collectionList: [{ id: '76000003', name: 'NoHasMoreField', total: 200 }],
        hasMore: false,
      });
    }
    const cursor = url.searchParams.get('cursor');
    if (cursor === '0') {
      return json({
        itemList: [{ id: '7400000000000000020' }],
        hasMore: true,
        cursor: '30',
      });
    }
    // TikTok omits itemList AND omits hasMore completely when exhausted
    return json({
      statusCode: 0,
      cursor: '30',
    });
  };
  const result = await loadExtractor(fetch, { querySelector: () => null })();
  assert.equal(result.collectionListComplete, true);
  assert.equal(result.collections.length, 1);
  assert.equal(result.collections[0].complete, true);
  assert.equal(result.collections[0].error, null);
  assert.equal(result.collections[0].videoIds.length, 1);
});

test('reads nested TikTok payloads and snake-case video IDs', async () => {
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({
        data: {
          collectionList: [{
            collectionId: '77000001',
            collectionName: 'Nested',
            item_count: 2,
          }],
          hasMore: 0,
          cursor: 0,
        },
      });
    }
    if (url.searchParams.get('cursor') === '0') {
      return json({
        data: {
          itemList: [{ aweme_id: '7400000000000000001', author: { unique_id: 'creator' } }],
          hasMore: '1',
          cursor: '1',
        },
      });
    }
    return json({
      data: {
        itemList: [{ aweme_id: '7400000000000000002' }],
        hasMore: '0',
        cursor: '1',
      },
    });
  };

  const result = await loadExtractor(fetch, { querySelector: () => null })();

  assert.equal(result.collections[0].complete, true);
  assert.deepEqual(Array.from(result.collections[0].videoIds), [
    '7400000000000000001',
    '7400000000000000002',
  ]);
  assert.equal(
    result.collections[0].videoUrls['7400000000000000001'],
    'https://www.tiktok.com/@creator/video/7400000000000000001',
  );
});

test('does not treat digits in a collection title as part of its video count', async () => {
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({ collectionList: [], hasMore: false });
    }

    const cursor = Number(url.searchParams.get('cursor'));
    const start = Number.isFinite(cursor) ? cursor : 0;
    const count = Math.min(30, 191 - start);
    const itemList = Array.from({ length: count }, (_, index) => ({
      id: String(7400000000000000001n + BigInt(start + index)),
    }));
    return json({
      itemList,
      hasMore: start + count < 191,
      cursor: start + count,
    });
  };
  const link = {
    href: 'https://www.tiktok.com/@owner/collection/18-77000002',
    innerText: '18 191 vidéos',
    textContent: '18 191 vidéos',
  };
  const document = {
    body: { innerText: 'Collections 1' },
    querySelector: () => link,
    querySelectorAll: () => [link],
  };

  const result = await loadExtractor(fetch, document)();

  assert.equal(result.collections[0].name, '18');
  assert.equal(result.collections[0].declaredTotal, 191);
  assert.equal(result.collections[0].videoIds.length, 191);
  assert.equal(result.collections[0].complete, true);
});

test('retries a temporarily rate-limited TikTok request', async () => {
  let listAttempts = 0;
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      listAttempts++;
      if (listAttempts === 1) return { ok: false, status: 429 };
      return json({
        collectionList: [{ id: '78000001', name: 'Retry', total: 1 }],
        hasMore: false,
      });
    }
    return json({ itemList: [{ id: '7400000000000000001' }], hasMore: false });
  };
  const scheduler = {
    setTimeout(callback, milliseconds) {
      if (milliseconds <= 1000) {
        queueMicrotask(callback);
        return 1;
      }
      return setTimeout(callback, milliseconds);
    },
    clearTimeout,
  };

  const result = await loadExtractor(
    fetch,
    { querySelector: () => null },
    () => null,
    scheduler,
  )();

  assert.equal(listAttempts, 2);
  assert.equal(result.collections[0].complete, true);
});

test('preserves exact int64 video IDs from TikTok JSON', async () => {
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({
        collectionList: [{ id: '79000001', name: 'Int64', total: 1 }],
        hasMore: false,
      });
    }
    return {
      ok: true,
      text: async () => '{"itemList":[{"aweme_id":7400000000000000001}],"hasMore":false}',
    };
  };

  const result = await loadExtractor(fetch, { querySelector: () => null })();

  assert.equal(result.collections[0].complete, true);
  assert.equal(result.collections[0].videoIds[0], '7400000000000000001');
});

test('loads all 128 collection cards from a virtualized grid', async () => {
  const scroller = { scrollTop: 0, clientHeight: 600 };
  let elapsed = 0;
  const links = Array.from({ length: 128 }, (_, index) => ({
    href: `https://www.tiktok.com/@owner/collection/folder-${index}-${78000000 + index}`,
    innerText: `Folder ${index}\n1 vidéo`,
    textContent: `Folder ${index}\n1 vidéo`,
  }));
  const visibleBatchSize = 16;
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({
        collectionList: Array.from({ length: 112 }, (_, index) => ({
          id: String(78000000 + index),
          name: `Folder ${index}`,
          total: 1,
        })),
        hasMore: false,
      });
    }
    const collectionId = Number(url.searchParams.get('collectionId'));
    const videoId = String(7400000000000000000n + BigInt(collectionId - 78000000));
    return json({ itemList: [{ aweme_id: videoId }], hasMore: false });
  };
  const document = {
    body: { innerText: 'Collections 128' },
    querySelector: () => links[0],
    querySelectorAll: () => {
      const loadedCount = elapsed < 7500 ? 112 : links.length;
      const available = links.slice(0, loadedCount);
      const batch = Math.min(
        Math.floor(scroller.scrollTop / 510),
        Math.ceil(available.length / visibleBatchSize) - 1,
      );
      return available.slice(batch * visibleBatchSize, (batch + 1) * visibleBatchSize);
    },
  };
  const scheduler = {
    setTimeout(callback, milliseconds) {
      if (milliseconds <= 1000) {
        elapsed += milliseconds;
        queueMicrotask(callback);
        return 1;
      }
      return setTimeout(callback, milliseconds);
    },
    clearTimeout,
  };

  const result = await loadExtractor(fetch, document, () => scroller, scheduler)();

  assert.equal(result.found, 128);
  assert.equal(result.declaredTotal, 128);
  assert.equal(result.collectionListComplete, true);
  assert.equal(result.collections.length, 128);
  assert.equal(result.collections.flatMap((collection) => collection.videoIds).length, 128);
  assert.ok(result.collections.every((collection) => collection.complete));
});

test('unknown collection total is not reported as zero', async () => {
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({ collectionList: [{ id: '79000002', name: 'Unknown' }], hasMore: false });
    }
    return json({ itemList: [{ aweme_id: '7400000000000000002' }], hasMore: false });
  };
  const result = await loadExtractor(fetch, { querySelector: () => null })();
  assert.equal(result.collections[0].declaredTotal, null);
  assert.equal(result.collections[0].complete, true);
  assert.equal(result.collections[0].videoIds.length, 1);
});

test('uses TikTok profile pagination to recover folders absent from the grid', async () => {
  const calls = [];
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname === '/api/user/collection_list/') {
      calls.push(url);
      assert.equal(url.searchParams.get('secUid'), 'profile-sec-uid');
      const start = Number(url.searchParams.get('cursor'));
      return json({
        collectionList: Array.from({ length: Math.min(20, 128 - start) }, (_, i) => ({
          collectionId: String(79000000 + start + i),
          name: `Folder ${start + i}`,
          total: 1,
        })),
        cursor: String(Math.min(128, start + 20)),
        hasMore: start + 20 < 128,
        total: 128,
      });
    }
    return json({ itemList: [{ aweme_id: '7400000000000000002' }], hasMore: false });
  };
  const document = {
    getElementById: () => ({ textContent: JSON.stringify({
      __DEFAULT_SCOPE__: {
        'webapp.user-detail': { userInfo: { user: { secUid: 'profile-sec-uid' } } },
      },
    }) }),
    querySelector: () => null,
  };
  const result = await loadExtractor(fetch, document)();
  assert.equal(calls.length, 7);
  assert.equal(result.found, 128);
  assert.equal(result.collectionListComplete, true);
  assert.equal(result.collections.length, 128);
});

test('a collection whose pagination fails midway keeps its ids but is incomplete', async () => {
  let itemCalls = 0;
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({ collectionList: [{ id: '76000002', name: 'Broken', total: 60 }], hasMore: false });
    }
    if (!url.pathname.includes('item_list')) return json({});
    itemCalls += 1;
    if (itemCalls === 1) {
      return json({ itemList: [{ id: '7400000000000000010' }], hasMore: true, cursor: '30' });
    }
    return { ok: false, status: 403, json: async () => ({}), text: async () => '{}' };
  };
  const result = await loadExtractor(fetch, { querySelector: () => null })();
  assert.deepEqual(Array.from(result.collections[0].videoIds), ['7400000000000000010']);
  assert.equal(result.collections[0].complete, false);
  assert.ok(result.collections[0].error);
});

test('a collection whose cursor never advances is incomplete, not silently complete', async () => {
  const fetch = async (address) => {
    const url = new URL(address);
    if (url.pathname.includes('/collection/list/')) {
      return json({ collectionList: [{ id: '76000003', name: 'Stuck', total: 60 }], hasMore: false });
    }
    return json({ itemList: [{ id: '7400000000000000020' }], hasMore: true, cursor: '0' });
  };
  const result = await loadExtractor(fetch, { querySelector: () => null })();
  assert.equal(result.collections[0].complete, false);
  assert.equal(result.collections[0].error, 'item_cursor_stuck');
});
