/**
 * Ordered, deduplicating store for the feed panel. A known item keeps its
 * place; a new item is slotted next to its neighbours in the incoming batch
 * (page order), so the list stays stable while the page keeps loading.
 */
(function (global) {
  'use strict';

  var DIGITS = /^\d+$/;

  // Field-merge rule for an item that already exists (ported from feed_panel.js).
  function mergeFields(existing, item, incomingSource) {
    var preferIncoming = incomingSource === 'gobird' && existing.source !== 'gobird';
    var incomingTitleValid = item.title && !DIGITS.test(String(item.title).trim());
    var existingTitleIsDigits = DIGITS.test(String(existing.title || '').trim());
    return {
      url: preferIncoming ? item.url : existing.url,
      pageUrl: preferIncoming ? item.pageUrl : existing.pageUrl,
      title: (existingTitleIsDigits && incomingTitleValid) ? item.title : (existing.title || item.title),
      author: existing.author || item.author,
      platform: existing.platform || item.platform,
      music: existing.music || item.music,
      avatarUrl: existing.avatarUrl || item.avatarUrl,
      thumbnailUrl: item.thumbnailUrl || existing.thumbnailUrl,
      videoSrc: item.videoSrc || existing.videoSrc,
      isActive: item.isActive !== undefined ? item.isActive : existing.isActive,
      durationSeconds: existing.durationSeconds || item.durationSeconds,
      width: existing.width || item.width,
      height: existing.height || item.height,
      sizeBytes: existing.sizeBytes || item.sizeBytes,
      source: preferIncoming ? incomingSource : existing.source,
    };
  }

  function create() {
    var order = []; // ids in display order
    var byId = Object.create(null);
    var seq = 0;

    function merge(batch, source) {
      var added = 0;
      var changed = 0;
      if (!Array.isArray(batch) || batch.length === 0) return { added: 0, changed: 0 };

      var items = [];
      var seen = Object.create(null);
      batch.forEach(function (item) {
        if (!item || !item.id || seen[item.id]) return;
        seen[item.id] = true;
        items.push(item);
      });

      // nextKnown[i]: first item after i that existed before this merge.
      var nextKnown = new Array(items.length);
      var following = null;
      for (var i = items.length - 1; i >= 0; i--) {
        nextKnown[i] = following;
        if (byId[items[i].id]) following = items[i].id;
      }

      var prev = null;
      items.forEach(function (item, idx) {
        var src = (source === 'gobird' || item.source === 'gobird') ? 'gobird' : 'dom';
        var existing = byId[item.id];
        if (existing) {
          var next = mergeFields(existing, item, src);
          var didChange = false;
          Object.keys(next).forEach(function (key) {
            if (next[key] !== existing[key]) {
              existing[key] = next[key];
              didChange = true;
            }
          });
          if (didChange) changed++;
        } else {
          var stored = Object.assign({}, item, { source: src, seq: ++seq });
          var pos;
          if (nextKnown[idx]) pos = order.indexOf(nextKnown[idx]);
          else if (prev) pos = order.lastIndexOf(prev) + 1;
          else pos = order.length;
          order.splice(pos, 0, stored.id);
          byId[stored.id] = stored;
          added++;
        }
        prev = item.id;
      });
      return { added: added, changed: changed };
    }

    function list(kind) {
      var out = order.map(function (id) { return byId[id]; });
      if (kind === 'recent') out.sort(function (a, b) { return b.seq - a.seq; });
      return out;
    }

    function newSince(since) {
      var n = 0;
      for (var id in byId) if (byId[id].seq > since) n++;
      return n;
    }

    return {
      merge: merge,
      list: list,
      get: function (id) { return byId[id]; },
      size: function () { return order.length; },
      remove: function (id) {
        if (!byId[id]) return;
        delete byId[id];
        order.splice(order.indexOf(id), 1);
      },
      clear: function () { order = []; byId = Object.create(null); seq = 0; },
      newSince: newSince,
      lastSeq: function () { return seq; },
    };
  }

  // insertBefore operations (applied in order, beforeId null = append) that turn
  // the DOM id order into the target order. Cards on a longest increasing
  // subsequence stay put; the others are moved right before their successor.
  function domMoves(currentIds, targetIds) {
    var pos = Object.create(null);
    currentIds.forEach(function (id, i) { pos[id] = i; });
    var tgt = targetIds.filter(function (id) { return id in pos; });
    var p = tgt.map(function (id) { return pos[id]; });

    // Patience LIS over p; tails[k] = index in p of the smallest tail of a run of k+1.
    var tails = [];
    var prevIdx = new Array(p.length);
    p.forEach(function (v, i) {
      var lo = 0;
      var hi = tails.length;
      while (lo < hi) {
        var mid = (lo + hi) >> 1;
        if (p[tails[mid]] < v) lo = mid + 1; else hi = mid;
      }
      prevIdx[i] = lo > 0 ? tails[lo - 1] : -1;
      tails[lo] = i;
    });
    var keep = Object.create(null);
    for (var k = tails.length ? tails[tails.length - 1] : -1; k >= 0; k = prevIdx[k]) keep[k] = true;

    var moves = [];
    for (var i = tgt.length - 1; i >= 0; i--) {
      if (!keep[i]) moves.push({ id: tgt[i], beforeId: i + 1 < tgt.length ? tgt[i + 1] : null });
    }
    return moves;
  }

  global.MDFeedStore = { create: create, domMoves: domMoves };
})(typeof self !== 'undefined' ? self : this);
