/**
 * Wears the desktop app's design. TapLoad sends a THEME message after every
 * connection and whenever the design changes; connection.js stores it as
 * `appTheme`, and this file turns it into CSS variables on the page root.
 * Only #rrggbb colours and bounded numbers are accepted.
 */
(function (global) {
  'use strict';

  var HEX = /^#[0-9a-f]{6}$/i;

  function colour(value) {
    return typeof value === 'string' && HEX.test(value) ? value : null;
  }

  function bounded(value, min, max) {
    var n = Number(value);
    return isFinite(n) ? Math.min(max, Math.max(min, n)) : null;
  }

  function toVars(theme) {
    var vars = {};
    if (!theme || typeof theme !== 'object') return vars;
    var plain = { canvas: '--canvas', panel: '--panel', panel2: '--panel-2', line: '--line', ink: '--ink', sub: '--sub', mute: '--mute' };
    Object.keys(plain).forEach(function (key) {
      var value = colour(theme[key]);
      if (value) vars[plain[key]] = value;
    });
    function pair(entry, name) {
      var bg = entry && colour(entry.bg);
      var on = entry && colour(entry.on);
      if (bg && on) {
        vars['--' + name] = bg;
        vars['--on-' + name] = on;
      }
    }
    var tiles = Array.isArray(theme.tiles) ? theme.tiles.filter(Boolean) : [];
    ['a', 'b', 'c'].forEach(function (name, index) {
      pair(tiles[index] || tiles[tiles.length - 1], name);
    });
    pair(theme.ok, 'ok');
    pair(theme.bad, 'bad');
    var card = bounded(theme.cardRadius, 0, 36);
    if (card !== null) vars['--r-card'] = card + 'px';
    var control = bounded(theme.controlRadius, 0, 999);
    if (control !== null) vars['--r-ctl'] = (control >= 100 ? 999 : control) + 'px';
    return vars;
  }

  function apply(theme, root) {
    var el = root || document.documentElement;
    var vars = toVars(theme);
    Object.keys(vars).forEach(function (name) { el.style.setProperty(name, vars[name]); });
    if (el === document.documentElement && theme && typeof theme.dark === 'boolean') {
      el.style.colorScheme = theme.dark ? 'dark' : 'light';
    }
    return vars;
  }

  function init(api) {
    if (!api || !api.storage || !api.storage.local) return;
    api.storage.local.get(['appTheme']).then(function (res) {
      if (res && res.appTheme) apply(res.appTheme);
    }).catch(function () {});
    if (api.storage.onChanged) {
      api.storage.onChanged.addListener(function (changes, area) {
        if (area === 'local' && changes.appTheme && changes.appTheme.newValue) apply(changes.appTheme.newValue);
      });
    }
  }

  global.MD_THEME = { toVars: toVars, apply: apply, init: init };
})(typeof self !== 'undefined' ? self : this);
