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
      clear: function () { order = []; byId = Object.create(null); seq = 0; },
      newSince: newSince,
      lastSeq: function () { return seq; },
    };
  }

  global.MDFeedStore = { create: create };
})(typeof self !== 'undefined' ? self : this);
