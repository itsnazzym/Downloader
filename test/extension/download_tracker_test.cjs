const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/download_tracker.js'), 'utf8');

function load() {
  const context = {};
  context.self = context;
  vm.createContext(context);
  vm.runInContext(source, context);
  return context.MDDownloads;
}

const MB = 1024 * 1024;
const p = (id, extra) => Object.assign({ id, title: 'T ' + id, url: 'https://x.com/' + id, status: 2, progress: 0.5 }, extra);
const assertClean = (value, where) => {
  const bad = [];
  (function walk(v, k) {
    if (typeof v === 'number' && !Number.isFinite(v)) bad.push(k);
    else if (v && typeof v === 'object') Object.keys(v).forEach((key) => walk(v[key], k + '.' + key));
  })(value, where || 'root');
  assert.deepEqual(bad, [], 'non-finite numbers found');
};

test('statusFromIndex maps every desktop status and rejects unknown indices', () => {
  const { statusFromIndex } = load();
  const expected = ['queued', 'running', 'running', 'running', 'done', 'error', 'canceled', 'paused', 'duplicate'];
  // expected[0..8] follows: queued, extracting, downloading, processing, completed, failed, canceled, paused, duplicate
  assert.deepEqual(expected.map((_, i) => statusFromIndex(i)), expected);
  assert.equal(statusFromIndex(2), 'running');
  assert.equal(statusFromIndex(4), 'done');
  assert.equal(statusFromIndex(7), 'paused');
  assert.equal(statusFromIndex(9), null);
  assert.equal(statusFromIndex(-1), null);
  assert.equal(statusFromIndex(1.5), null);
  assert.equal(statusFromIndex(undefined), null);
  assert.equal(statusFromIndex('2'), null);
});

test('parseSpeed reads binary and decimal units and rejects the rest', () => {
  const { parseSpeed } = load();
  assert.ok(Math.abs(parseSpeed('3.2MiB/s') - 3355443) <= 1);
  assert.equal(parseSpeed('850KiB/s'), 850 * 1024);
  assert.equal(parseSpeed('1.5MB/s'), 1500000);
  assert.equal(parseSpeed('900B/s'), 900);
  assert.equal(parseSpeed('2GiB/s'), 2 * 1024 ** 3);
  assert.equal(parseSpeed('Unknown'), null);
  assert.equal(parseSpeed(''), null);
  assert.equal(parseSpeed('N/A'), null);
  assert.equal(parseSpeed(null), null);
  assert.equal(parseSpeed(undefined), null);
  assert.equal(parseSpeed(42), null);
});

test('parseEta reads MM:SS and HH:MM:SS and rejects the rest', () => {
  const { parseEta } = load();
  assert.equal(parseEta('01:05'), 65);
  assert.equal(parseEta('1:02:03'), 3723);
  assert.equal(parseEta('00:00'), 0);
  assert.equal(parseEta('N/A'), null);
  assert.equal(parseEta('Unknown'), null);
  assert.equal(parseEta(''), null);
  assert.equal(parseEta('12'), null);
  assert.equal(parseEta('aa:bb'), null);
  assert.equal(parseEta('01:75'), null);
  assert.equal(parseEta(null), null);
});

test('ingest builds a Dl with pct, parsed speed and eta', () => {
  const t = load().create();
  const dl = t.ingest(p('a', { progress: 0.456, speed: '1MiB/s', eta: '00:12', totalSize: 100 * MB, downloadedSize: 45 * MB }), 1000);
  assert.equal(dl.id, 'a');
  assert.equal(dl.status, 'running');
  assert.equal(dl.pct, 46);
  assert.equal(dl.speedBps, MB);
  assert.equal(dl.etaSeconds, 12);
  assert.equal(dl.totalBytes, 100 * MB);
  assert.equal(dl.error, null);
  assert.equal(dl.updatedAt, 1000);
  assert.equal(t.get('a').pct, 46);
});

test('pct is rounded and clamped, progress may be a string', () => {
  const t = load().create();
  assert.equal(t.ingest(p('a', { progress: 1.7 }), 1).pct, 100);
  assert.equal(t.ingest(p('b', { progress: -3 }), 1).pct, 0);
  assert.equal(t.ingest(p('c', { progress: '0.25' }), 1).pct, 25);
  assert.equal(t.ingest(p('d', { progress: undefined }), 1).pct, 0);
  assert.equal(t.ingest(p('e', { progress: NaN }), 1).pct, 0);
});

test('speed is smoothed with an EMA of alpha 0.3', () => {
  const t = load().create();
  t.ingest(p('a', { speed: '1000B/s' }), 1000);
  const dl = t.ingest(p('a', { speed: '2000B/s' }), 2000);
  assert.ok(Math.abs(dl.speedBps - 1300) < 1e-6);
  const dl3 = t.ingest(p('a', { speed: '2000B/s' }), 3000);
  assert.ok(Math.abs(dl3.speedBps - (0.3 * 2000 + 0.7 * 1300)) < 1e-6);
});

test('speed falls back to downloadedSize deltas when the speed string is unreadable', () => {
  const t = load().create();
  t.ingest(p('a', { speed: 'Unknown', downloadedSize: 0, totalSize: 100 * MB }), 1000);
  const dl = t.ingest(p('a', { speed: 'Unknown', downloadedSize: 2 * MB, totalSize: 100 * MB }), 3000);
  assert.ok(Math.abs(dl.speedBps - MB) < 1); // 2 MiB over 2 s
});

test('ETA is computed from remaining bytes and smoothed speed when eta is empty', () => {
  const t = load().create();
  const dl = t.ingest(p('a', { speed: '1MiB/s', eta: '', totalSize: 100 * MB, downloadedSize: 40 * MB }), 1000);
  assert.equal(dl.etaSeconds, 60);
  // total/downloaded may arrive as numeric strings
  const dl2 = t.ingest(p('b', { speed: '1MiB/s', eta: 'N/A', totalSize: String(10 * MB), downloadedSize: String(4 * MB) }), 1000);
  assert.equal(dl2.etaSeconds, 6);
});

test('ETA and speed are null when nothing is known, never NaN or Infinity', () => {
  const t = load().create();
  const dl = t.ingest(p('a', { speed: 'Unknown', eta: 'N/A', totalSize: 0, downloadedSize: 0 }), 1000);
  assert.equal(dl.speedBps, null);
  assert.equal(dl.etaSeconds, null);
  assert.equal(dl.totalBytes, null);
  const z = t.ingest(p('z', { speed: '0B/s', totalSize: 10 * MB, downloadedSize: MB }), 1000);
  assert.equal(z.etaSeconds, null);
  assertClean(t.groups(), 'groups');
  assertClean(t.summary(1000), 'summary');
});

test('done then an older downloading message stays done', () => {
  const t = load().create();
  t.ingest(p('a', { status: 4, progress: 1 }), 2000);
  const dl = t.ingest(p('a', { status: 2, progress: 0.4 }), 1500);
  assert.equal(dl.status, 'done');
  assert.equal(t.get('a').status, 'done');
  assert.equal(t.get('a').pct, 100);
});

test('a terminal status is not regressed by a non-terminal message with the same timestamp', () => {
  const t = load().create();
  t.ingest(p('a', { status: 5, error: 'boom' }), 2000);
  assert.equal(t.ingest(p('a', { status: 2 }), 2000).status, 'error');
  assert.equal(t.get('a').error, 'boom');
  t.ingest(p('c', { status: 6 }), 2000);
  assert.equal(t.ingest(p('c', { status: 1 }), 2000).status, 'canceled');
});

test('a strictly newer message may restart a terminal item', () => {
  const t = load().create();
  t.ingest(p('a', { status: 5, error: 'boom' }), 2000);
  const dl = t.ingest(p('a', { status: 0, progress: 0 }), 2500);
  assert.equal(dl.status, 'queued');
  assert.equal(dl.error, null);
  assert.equal(dl.speedBps, null);
});

test('unknown status index is ignored', () => {
  const t = load().create();
  assert.equal(t.ingest(p('a', { status: 42 }), 1), undefined);
  assert.equal(t.get('a'), undefined);
  t.ingest(p('b'), 1);
  assert.equal(t.ingest(p('b', { status: 42, progress: 0.9 }), 2).pct, 50);
  assert.equal(t.get('b').pct, 50);
  assert.equal(t.ingest({ status: 2 }, 1), undefined); // no id
});

test('failed items carry their error; canceled ones have none', () => {
  const t = load().create();
  assert.equal(t.ingest(p('a', { status: 5, error: 'Network down' }), 1).error, 'Network down');
  assert.equal(t.ingest(p('b', { status: 6, error: 'ignored' }), 1).error, null);
});

test('groups sorts items by status, canceled in error and duplicate in done', () => {
  const t = load().create();
  t.ingest(p('run', { status: 2 }), 1);
  t.ingest(p('ext', { status: 1 }), 1);
  t.ingest(p('q', { status: 0 }), 1);
  t.ingest(p('pa', { status: 7 }), 1);
  t.ingest(p('er', { status: 5, error: 'x' }), 1);
  t.ingest(p('ca', { status: 6 }), 1);
  t.ingest(p('do', { status: 4 }), 1);
  t.ingest(p('du', { status: 8 }), 1);
  const g = t.groups();
  const ids = (a) => Array.from(a, (d) => d.id).sort();
  assert.deepEqual(ids(g.running), ['ext', 'run']);
  assert.deepEqual(ids(g.queued), ['q']);
  assert.deepEqual(ids(g.paused), ['pa']);
  assert.deepEqual(ids(g.error), ['ca', 'er']);
  assert.deepEqual(ids(g.done), ['do', 'du']);
  assert.equal(t.get('ca').status, 'canceled');
  assert.equal(t.get('du').status, 'duplicate');
});

test('findByCardKey matches tweetId, then tikTokId, then url', () => {
  const t = load().create();
  t.ingest(p('a', { tweetId: '111', url: 'https://x.com/u/status/111' }), 1);
  t.ingest(p('b', { tikTokId: '222', url: 'https://tiktok.com/v/222' }), 1);
  t.ingest(p('c', { url: 'https://example.com/clip' }), 1);
  assert.equal(t.findByCardKey({ tweetId: '111' }).id, 'a');
  assert.equal(t.findByCardKey({ tikTokId: '222' }).id, 'b');
  assert.equal(t.findByCardKey({ url: 'https://example.com/clip' }).id, 'c');
  assert.equal(t.findByCardKey({ tweetId: '999', url: 'https://example.com/clip' }).id, 'c');
  assert.equal(t.findByCardKey({ tweetId: '111', url: 'https://example.com/clip' }).id, 'a');
  assert.equal(t.findByCardKey({ tweetId: '999' }), undefined);
  assert.equal(t.findByCardKey({}), undefined);
  assert.equal(t.findByCardKey(), undefined);
});

test('summary adds running speeds and derives a global ETA', () => {
  const t = load().create();
  t.ingest(p('a', { speed: '1MiB/s', totalSize: 100 * MB, downloadedSize: 50 * MB, progress: 0.5 }), 1);
  t.ingest(p('b', { speed: '3MiB/s', totalSize: 100 * MB, downloadedSize: 70 * MB, progress: 0.7 }), 1);
  t.ingest(p('q', { status: 0, progress: 0, totalSize: 100 * MB, downloadedSize: 0 }), 1);
  t.ingest(p('d', { status: 4, progress: 1 }), 1);
  const s = t.summary(1);
  assert.equal(s.running, 2);
  assert.equal(s.queued, 1);
  assert.equal(s.speedBps, 4 * MB);
  // remaining = 50 + 30 + 100 = 180 MiB at 4 MiB/s
  assert.equal(s.etaSeconds, 45);
  // weighted by bytes: (50 + 70 + 0) / 300
  assert.equal(s.pct, 40);
  assertClean(s, 'summary');
});

test('summary pct falls back to equal weights when a total is unknown', () => {
  const t = load().create();
  t.ingest(p('a', { progress: 0.2 }), 1);
  t.ingest(p('b', { progress: 0.6 }), 1);
  assert.equal(t.summary(1).pct, 40);
});

test('summary of an empty or idle tracker is zero with a null ETA', () => {
  const t = load().create();
  assert.deepEqual({ ...t.summary(1) }, { running: 0, queued: 0, pct: 0, speedBps: 0, etaSeconds: null });
  t.ingest(p('d', { status: 4 }), 1);
  assert.deepEqual({ ...t.summary(1) }, { running: 0, queued: 0, pct: 0, speedBps: 0, etaSeconds: null });
});

test('summary ETA is null when speed is unknown or a total is unknown', () => {
  const t = load().create();
  t.ingest(p('a', { speed: 'Unknown', totalSize: 10 * MB, downloadedSize: MB }), 1);
  assert.equal(t.summary(1).etaSeconds, null);
  t.ingest(p('b', { speed: '1MiB/s' }), 1);
  assert.equal(t.summary(1).etaSeconds, null);
});

test('remove and clearDone drop items', () => {
  const t = load().create();
  t.ingest(p('a', { status: 4 }), 1);
  t.ingest(p('b', { status: 8 }), 1);
  t.ingest(p('c', { status: 5, error: 'x' }), 1);
  t.ingest(p('d', { status: 2 }), 1);
  t.clearDone();
  assert.equal(t.get('a'), undefined);
  assert.equal(t.get('b'), undefined);
  assert.ok(t.get('c') && t.get('d'));
  t.remove('c');
  assert.equal(t.get('c'), undefined);
  t.remove('nope'); // no throw
});

test('ingestSnapshot adds and updates items, ignoring unknown statuses', () => {
  const t = load().create();
  t.ingest(p('a', { progress: 0.1 }), 1000);
  t.ingestSnapshot([p('a', { progress: 0.6 }), p('b', { status: 0, progress: 0 }), p('x', { status: 99 })], 2000);
  assert.equal(t.get('a').pct, 60);
  assert.equal(t.get('b').status, 'queued');
  assert.equal(t.get('x'), undefined);
  t.ingestSnapshot(null, 3000); // no throw
});

test('ingestSnapshot does not override a newer terminal state', () => {
  const t = load().create();
  t.ingest(p('a', { status: 4, progress: 1 }), 3000);
  t.ingestSnapshot([p('a', { status: 2, progress: 0.5 })], 2000);
  assert.equal(t.get('a').status, 'done');
});

test('ingestSnapshot does not resurrect a removed terminal item', () => {
  const t = load().create();
  t.ingest(p('a', { status: 4, progress: 1 }), 3000);
  t.remove('a');
  t.ingestSnapshot([p('a', { status: 4, progress: 1 })], 3500);
  assert.equal(t.get('a'), undefined);
  t.ingestSnapshot([p('a', { status: 2, progress: 0.5 })], 2500);
  assert.equal(t.get('a'), undefined);
  t.ingest(p('c', { status: 8 }), 3000);
  t.clearDone();
  t.ingestSnapshot([p('c', { status: 8 })], 4000);
  assert.equal(t.get('c'), undefined);
  // a genuinely newer non-terminal message restarts it
  t.ingest(p('a', { status: 0, progress: 0 }), 5000);
  assert.equal(t.get('a').status, 'queued');
});

test('500 items x 20 updates stay under 200 ms', () => {
  const t = load().create();
  const start = Date.now();
  for (let u = 0; u < 20; u++) {
    for (let i = 0; i < 500; i++) {
      t.ingest(p('id' + i, { progress: u / 20, speed: '1MiB/s', totalSize: 100 * MB, downloadedSize: u * MB }), 1000 + u * 100);
    }
  }
  const s = t.summary(5000);
  t.findByCardKey({ tweetId: 'nope' });
  t.groups();
  assert.ok(Date.now() - start < 200, 'took ' + (Date.now() - start) + ' ms');
  assert.equal(s.running, 500);
});

test('ingestSnapshot prunes tracked items that are absent from the snapshot', () => {
  const t = load().create();
  t.ingest(p('g', { speed: '1MiB/s', progress: 0.3 }), 1000);
  t.ingest(p('k', { speed: '1MiB/s', progress: 0.3 }), 1000);
  t.ingest(p('d', { status: 4 }), 1000);
  t.ingestSnapshot([p('k', { speed: '2MiB/s', progress: 0.6 })], 2000);
  assert.equal(t.get('g'), undefined);
  assert.equal(t.get('d'), undefined);
  assert.equal(t.get('k').pct, 60);
  const s = t.summary(2000);
  assert.equal(s.running, 1);
  assert.ok(Math.abs(s.speedBps - 1.3 * MB) < 1); // EMA of 1 then 2 MiB/s
  t.ingestSnapshot([], 3000);
  assert.equal(t.get('k'), undefined);
  assert.equal(t.summary(3000).running, 0);
});

test('pruning keeps tombstones so cleared terminal items stay removed', () => {
  const t = load().create();
  t.ingest(p('a', { status: 4 }), 1000);
  t.remove('a');
  t.ingestSnapshot([], 2000);
  t.ingestSnapshot([p('a', { status: 4 })], 3000);
  assert.equal(t.get('a'), undefined);
});

test('a snapshot item that is ignored as older is still kept', () => {
  const t = load().create();
  t.ingest(p('a', { status: 4 }), 3000);
  t.ingestSnapshot([p('a', { status: 2 })], 2000);
  assert.equal(t.get('a').status, 'done');
});

test('unit tables do not leak prototype keys or overflow into NaN/Infinity', () => {
  const { parseSpeed, create } = load();
  assert.equal(parseSpeed('5constructor'), null);
  assert.equal(parseSpeed('5toString/s'), null);
  assert.equal(parseSpeed('5__proto__'), null);
  assert.equal(parseSpeed('9'.repeat(400) + 'MiB/s'), null);
  const t = create();
  const dl = t.ingest(p('a', { totalSize: '5constructor', downloadedSize: '9'.repeat(400) + 'MiB', speed: '9'.repeat(400) + 'GiB/s' }), 1);
  assertClean(dl, 'dl');
  assertClean(t.summary(1), 'summary');
});

test('allowedCommands mirrors the desktop command matrix', () => {
  const { allowedCommands } = load();
  const plain = (s) => JSON.parse(JSON.stringify(allowedCommands(s)));
  assert.deepEqual(plain('queued'), ['cancel']);
  assert.deepEqual(plain('running'), ['pause', 'cancel']);
  assert.deepEqual(plain('paused'), ['resume', 'cancel']);
  assert.deepEqual(plain('error'), ['retry']);
  assert.deepEqual(plain('canceled'), ['retry']);
  assert.deepEqual(plain('done'), []);
  assert.deepEqual(plain('duplicate'), []);
  for (const odd of ['constructor', '__proto__', 'toString', '', 'nope', undefined, null, 2, {}]) {
    assert.deepEqual(plain(odd), [], 'no commands for ' + String(odd));
  }
});

test('allowedCommands returns a fresh array each call', () => {
  const { allowedCommands } = load();
  allowedCommands('queued').push('retry');
  assert.equal(JSON.stringify(allowedCommands('queued')), '["cancel"]');
});

test('planRowUpdates keeps rows whose group and status did not change', () => {
  const { planRowUpdates } = load();
  const plain = (v) => JSON.parse(JSON.stringify(v));
  const prev = [{ id: 'a', sig: 'running|running|x' }, { id: 'b', sig: 'queued|queued|x' }, { id: 'c', sig: 'error|error|x' }];
  // Progress-only tick: same signatures -> every row updated in place.
  assert.deepEqual(plain(planRowUpdates(prev, prev)), { update: ['a', 'b', 'c'], rebuild: [], create: [], remove: [] });
  // b starts running, c disappears, d appears.
  const next = [{ id: 'a', sig: 'running|running|x' }, { id: 'b', sig: 'running|running|x' }, { id: 'd', sig: 'queued|queued|x' }];
  assert.deepEqual(plain(planRowUpdates(prev, next)), { update: ['a'], rebuild: ['b'], create: ['d'], remove: ['c'] });
  assert.deepEqual(plain(planRowUpdates(undefined, [{ id: 'a', sig: 's' }])), { update: [], rebuild: [], create: ['a'], remove: [] });
  assert.deepEqual(plain(planRowUpdates(prev, [])), { update: [], rebuild: [], create: [], remove: ['a', 'b', 'c'] });
});

test('summary ETA stays finite for an absurdly small speed', () => {
  const t = load().create();
  t.ingest(p('a', { speed: '0.' + '0'.repeat(320) + '1B/s', totalSize: 100 * MB, downloadedSize: 1 * MB, progress: 0.01 }), 1);
  const s = t.summary(1);
  assert.ok(s.speedBps > 0 && s.speedBps < 1e-300, 'speed must be the tiny positive value');
  assert.equal(s.etaSeconds, null);
  assertClean(s, 'summary');
});

test('displayStatus shows live downloads as offline while the app is unreachable', () => {
  const { displayStatus } = load();
  for (const live of ['queued', 'running', 'paused']) {
    assert.equal(displayStatus(live, false), 'offline', live);
    assert.equal(displayStatus(live, true), live, live);
  }
  // Settled states keep their meaning, and an unknown connection state is not "offline".
  for (const settled of ['done', 'error', 'canceled', 'duplicate']) assert.equal(displayStatus(settled, false), settled, settled);
  assert.equal(displayStatus('running', undefined), 'running');
  // Offline rows get no commands: allowedCommands('offline') is empty.
  assert.deepEqual(Array.from(load().allowedCommands('offline')), []);
});

test('a snapshot after a reconnect removes the downloads the app no longer has', () => {
  const t = load().create();
  t.ingest(p('ghost', { status: 2 }), 1);
  t.ingest(p('kept', { status: 2 }), 1);
  t.ingestSnapshot([p('kept', { status: 2, progress: 0.9 })], 2);
  assert.equal(t.get('ghost'), undefined);
  assert.equal(t.get('kept').pct, 90);
});
