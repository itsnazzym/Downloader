(function (root) {
  'use strict';

  function create() {
    var selected = new Set();
    var pressId = null;
    var dragging = false;
    var selecting = true; // drag mode: true = select, false = deselect
    var lastIdx = -1;

    function apply(id) {
      if (selected.has(id) === selecting) return false;
      if (selecting) selected.add(id);
      else selected.delete(id);
      return true;
    }

    function pressEnter(id, orderedIds) {
      var changed = [];
      if (pressId === null) return changed;
      if (!dragging) {
        if (id === pressId) return changed;
        dragging = true;
        selecting = !selected.has(pressId);
        lastIdx = orderedIds.indexOf(pressId);
        if (apply(pressId)) changed.push(pressId);
      }
      var idx = orderedIds.indexOf(id);
      if (idx < 0) return changed;
      if (lastIdx < 0) lastIdx = idx;
      var step = idx >= lastIdx ? 1 : -1;
      for (var i = lastIdx; i !== idx + step; i += step) {
        if (apply(orderedIds[i])) changed.push(orderedIds[i]);
      }
      lastIdx = idx;
      return changed;
    }

    return {
      has: function (id) { return selected.has(id); },
      ids: function () { return Array.from(selected); },
      size: function () { return selected.size; },
      clear: function () { selected.clear(); },
      toggle: function (id) {
        if (selected.delete(id)) return false;
        selected.add(id);
        return true;
      },
      pressStart: function (id) {
        pressId = id;
        dragging = false;
        lastIdx = -1;
      },
      pressEnter: pressEnter,
      pressEnd: function () {
        pressId = null;
        dragging = false;
        lastIdx = -1;
      },
      isDragging: function () { return dragging; },
      // Shift+click: selects and returns every id between the two cards.
      range: function (fromId, toId, orderedIds) {
        var a = orderedIds.indexOf(fromId);
        var b = orderedIds.indexOf(toId);
        if (a < 0 || b < 0) return [];
        var ids = orderedIds.slice(Math.min(a, b), Math.max(a, b) + 1);
        ids.forEach(function (id) { selected.add(id); });
        return ids;
      },
      prune: function (visibleIds) {
        var visible = new Set(visibleIds);
        Array.from(selected).forEach(function (id) {
          if (!visible.has(id)) selected.delete(id);
        });
      },
    };
  }

  // What a pointer release does on its own: only a touch long-press released in
  // place selects the card; mouse clicks are left to the card click handler.
  function releaseAction(p) {
    return p.pointerType === 'touch' && p.armed && !p.dragging && !p.moved ? 'toggle' : 'none';
  }

  root.MDSelection = { create: create, releaseAction: releaseAction };
})(typeof self !== 'undefined' ? self : this);
