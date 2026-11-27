/**
 * Download tracker for the feed panel. Turns the desktop app's PROGRESS
 * messages (and QUEUE_SNAPSHOT) into stable per-download state: status group,
 * smoothed speed and ETA, plus a global summary. Pure logic, no DOM.
 */
(function (global) {
  'use strict';

  var ALPHA = 0.3;
  var TOMBSTONE_CAP = 2000;
  // Desktop DownloadStatus index -> tracker status.
  var STATUSES = ['queued', 'running', 'running', 'running', 'done', 'error', 'canceled', 'paused', 'duplicate'];
  var TERMINAL = { done: 1, error: 1, canceled: 1, duplicate: 1 };
  // Null-prototype table: "constructor" & co. must not resolve as units.
  var UNITS = Object.assign(Object.create(null), {
    b: 1,
    kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776,
    kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12
  });
  var SIZE_RE = /^\s*(\d+(?:\.\d+)?)\s*([a-z]+)?(?:\/s)?\s*$/i;

  function statusFromIndex(i) {
    return (typeof i === 'number' && STATUSES[i]) || null;
  }

  // Mirrors the desktop guard (extension_queue_contract.dart): commands each status accepts.
  var COMMANDS = Object.assign(Object.create(null), {
    queued: ['cancel'],
    running: ['pause', 'cancel'],
    paused: ['resume', 'cancel'],
    error: ['retry'],
    canceled: ['retry']
  });

  function allowedCommands(status) {
    var list = typeof status === 'string' && COMMANDS[status];
    return list ? list.slice() : [];
  }

  // Diff of view rows [{id, sig}]: a row whose signature (group, status...) is
  // unchanged is updated in place, so its buttons survive progress ticks.
  function planRowUpdates(prev, next) {
    var before = new Map();
    (prev || []).forEach(function (r) { before.set(r.id, r.sig); });
    var seen = new Set();
    var plan = { update: [], rebuild: [], create: [], remove: [] };
    (next || []).forEach(function (r) {
      seen.add(r.id);
      if (!before.has(r.id)) plan.create.push(r.id);
      else if (before.get(r.id) === r.sig) plan.update.push(r.id);
      else plan.rebuild.push(r.id);
    });
    before.forEach(function (sig, id) { if (!seen.has(id)) plan.remove.push(id); });
    return plan;
  }

  // "3.2MiB/s" -> bytes/s. A unit is mandatory so "Unknown" / "" / "N/A" stay null.
  function parseSpeed(raw) {
    if (typeof raw !== 'string') return null;
    var m = SIZE_RE.exec(raw);
    if (!m || !m[2]) return null;
    var unit = UNITS[m[2].toLowerCase()];
    return unit ? finiteOrNull(parseFloat(m[1]) * unit) : null;
  }

  function finiteOrNull(n) {
    return isFinite(n) ? n : null;
  }

  // "MM:SS" or "HH:MM:SS" -> seconds.
  function parseEta(raw) {
    if (typeof raw !== 'string') return null;
    var m = /^\s*(?:(\d+):)?(\d{1,2}):(\d{2})\s*$/.exec(raw);
    if (!m) return null;
    var h = m[1] ? parseInt(m[1], 10) : 0;
    var min = parseInt(m[2], 10);
    var s = parseInt(m[3], 10);
    if (s > 59 || (m[1] && min > 59)) return null;
    return h * 3600 + min * 60 + s;
  }

  // Sizes may arrive as numbers, numeric strings or "12.5MiB" strings.
  function toBytes(v) {
    if (typeof v === 'string') {
      var m = SIZE_RE.exec(v);
      if (!m) return null;
      var unit = m[2] ? UNITS[m[2].toLowerCase()] : 1;
      return unit ? finiteOrNull(parseFloat(m[1]) * unit) : null;
    }
    return typeof v === 'number' && isFinite(v) && v >= 0 ? v : null;
  }

  function toProgress(v) {
    var n = typeof v === 'string' ? parseFloat(v) : v;
    return typeof n === 'number' && isFinite(n) ? Math.min(1, Math.max(0, n)) : 0;
  }

  function str(v) {
    return typeof v === 'string' && v !== '' ? v : null;
  }

  function create() {
    var items = new Map();      // id -> { dl, progress, dlBytes, sampleAt, remaining }
    var tombstones = new Map(); // id -> updatedAt of a removed terminal item

    // `now` is the receive time and must be monotonic across calls: a strictly
    // newer non-terminal message restarts a terminal item (retry) by design.
    function ingest(p, now) {
      if (!p || p.id == null || p.id === '') return undefined;
      var id = String(p.id);
      var prev = items.get(id);
      var status = statusFromIndex(p.status);
      if (!status) return prev && prev.dl;

      var terminal = !!TERMINAL[status];
      if (prev) {
        var prevAt = prev.dl.updatedAt;
        // Out-of-order message, or a terminal state regressing at the same instant.
        if (now < prevAt || (now === prevAt && TERMINAL[prev.dl.status] && !terminal)) return prev.dl;
      } else {
        var removedAt = tombstones.get(id);
        // A removed terminal item stays removed unless a newer live message restarts it.
        if (removedAt !== undefined && (terminal || now <= removedAt)) return undefined;
      }
      tombstones.delete(id);

      var old = prev && !TERMINAL[prev.dl.status] ? prev : null;
      var total = toBytes(p.totalSize);
      if (!total) total = prev ? prev.dl.totalBytes : null;
      var progress = status === 'done' ? 1 : toProgress(p.progress);
      var dlBytes = toBytes(p.downloadedSize);
      if (dlBytes === null && total) dlBytes = total * progress;

      var speed = null;
      var eta = null;
      if (status === 'running') {
        var sample = parseSpeed(p.speed);
        var oldDl = old && toBytes(p.downloadedSize) !== null ? old.dlBytes : null;
        if (sample === null && oldDl !== null && now > old.sampleAt && dlBytes >= oldDl) {
          sample = (dlBytes - oldDl) / ((now - old.sampleAt) / 1000);
        }
        var before = old ? old.dl.speedBps : null;
        speed = sample === null ? before : before === null ? sample : ALPHA * sample + (1 - ALPHA) * before;
      }
      var remaining = total ? Math.max(0, dlBytes !== null ? total - dlBytes : total * (1 - progress)) : null;
      if (status === 'running') {
        eta = parseEta(p.eta);
        if (eta === null && remaining !== null && speed > 0) eta = remaining / speed;
        if (eta !== null && !isFinite(eta)) eta = null;
      }

      var dl = {
        id: id,
        title: str(p.title) || (prev && prev.dl.title) || null,
        url: str(p.url) || (prev && prev.dl.url) || null,
        tweetId: str(p.tweetId) || (prev && prev.dl.tweetId) || null,
        tikTokId: str(p.tikTokId) || (prev && prev.dl.tikTokId) || null,
        status: status,
        pct: Math.round(progress * 100),
        speedBps: speed,
        etaSeconds: eta,
        totalBytes: total || null,
        error: status === 'error' ? str(p.error) : null,
        updatedAt: now
      };
      items.set(id, { dl: dl, progress: progress, dlBytes: dlBytes, sampleAt: now, remaining: remaining });
      return dl;
    }

    // The snapshot is the desktop's full queue: tracked items it omits are gone
    // (no tombstone). Same monotonic `now` contract as ingest.
    function ingestSnapshot(list, now) {
      if (!Array.isArray(list)) return;
      var seen = new Set();
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].id != null) seen.add(String(list[i].id));
        ingest(list[i], now);
      }
      Array.from(items.keys()).forEach(function (id) {
        if (!seen.has(id)) items.delete(id);
      });
    }

    function forget(id) {
      var rec = items.get(id);
      if (!rec) return;
      if (TERMINAL[rec.dl.status]) {
        tombstones.set(id, rec.dl.updatedAt);
        if (tombstones.size > TOMBSTONE_CAP) tombstones.delete(tombstones.keys().next().value);
      }
      items.delete(id);
    }

    function findByCardKey(key) {
      if (!key) return undefined;
      var fields = [['tweetId', key.tweetId], ['tikTokId', key.tikTokId], ['url', key.url]];
      for (var f = 0; f < fields.length; f++) {
        var value = fields[f][1];
        if (!value) continue;
        var best;
        items.forEach(function (rec) {
          if (rec.dl[fields[f][0]] === value && (!best || rec.dl.updatedAt >= best.updatedAt)) best = rec.dl;
        });
        if (best) return best;
      }
      return undefined;
    }

    function groups() {
      var g = { running: [], queued: [], paused: [], error: [], done: [] };
      items.forEach(function (rec) {
        var s = rec.dl.status;
        g[s === 'canceled' ? 'error' : s === 'duplicate' ? 'done' : s].push(rec.dl);
      });
      return g;
    }

    function summary() {
      var running = 0, queued = 0, speed = 0, remaining = 0, remainingKnown = true;
      var weightSum = 0, weighted = 0, plain = 0, allTotals = true;
      items.forEach(function (rec) {
        var s = rec.dl.status;
        if (s !== 'running' && s !== 'queued') return;
        if (s === 'running') { running++; speed += rec.dl.speedBps || 0; } else queued++;
        plain += rec.progress;
        if (rec.dl.totalBytes) { weightSum += rec.dl.totalBytes; weighted += rec.dl.totalBytes * rec.progress; } else allTotals = false;
        if (rec.remaining === null) remainingKnown = false; else remaining += rec.remaining;
      });
      var active = running + queued;
      var pct = !active ? 0 : allTotals && weightSum > 0 ? weighted / weightSum : plain / active;
      return {
        running: running,
        queued: queued,
        pct: Math.round(pct * 100),
        speedBps: speed,
        etaSeconds: active && remainingKnown && speed > 0 ? remaining / speed : null
      };
    }

    function clearDone() {
      Array.from(items.keys()).forEach(function (id) {
        var s = items.get(id).dl.status;
        if (s === 'done' || s === 'duplicate') forget(id);
      });
    }

    return {
      ingest: ingest,
      ingestSnapshot: ingestSnapshot,
      get: function (id) { var r = items.get(id); return r && r.dl; },
      findByCardKey: findByCardKey,
      groups: groups,
      summary: summary,
      remove: forget,
      clearDone: clearDone
    };
  }

  global.MDDownloads = {
    statusFromIndex: statusFromIndex,
    allowedCommands: allowedCommands,
    planRowUpdates: planRowUpdates,
    parseSpeed: parseSpeed,
    parseEta: parseEta,
    create: create
  };
})(typeof self !== 'undefined' ? self : this);
