/**
 * Cross-browser API polyfill.
 * Prefer the Promise-based `browser` namespace when available (Firefox);
 * otherwise wrap callback-style `chrome.*` APIs.
 */
(function (global) {
  'use strict';

  function hasPromiseApi(candidate) {
    return (
      candidate &&
      candidate.runtime &&
      typeof candidate.runtime.sendMessage === 'function' &&
      // Firefox browser.* returns promises; chrome.* uses callbacks unless polyfilled.
      (typeof browser !== 'undefined' || candidate === browser)
    );
  }

  var raw =
    typeof browser !== 'undefined' && browser.runtime
      ? browser
      : typeof chrome !== 'undefined'
        ? chrome
        : null;

  if (!raw) {
    throw new Error('No WebExtension API found');
  }

  function promisify(fn, ctx) {
    if (!fn) return undefined;
    return function () {
      var args = Array.prototype.slice.call(arguments);
      var last = args[args.length - 1];
      var hasCallback = typeof last === 'function';

      if (hasCallback) {
        var userCb = args.pop();
        try {
          var res = fn.apply(
            ctx,
            args.concat([
              function (result) {
                // Reading lastError marks it as checked so Chrome does not warn
                var err = raw.runtime && raw.runtime.lastError;
                try {
                  userCb(result);
                } catch (_) {}
              },
            ]),
          );
          if (res && typeof res.catch === 'function') {
            res.catch(function () {});
          }
          return res;
        } catch (e) {
          try { userCb(undefined); } catch (_) {}
          return undefined;
        }
      }

      return new Promise(function (resolve, reject) {
        try {
          var res = fn.apply(
            ctx,
            args.concat([
              function (result) {
                var err = raw.runtime && raw.runtime.lastError;
                if (err) {
                  reject(new Error(err.message || String(err)));
                } else {
                  resolve(result);
                }
              },
            ]),
          );
          if (res && typeof res.then === 'function') {
            res.then(resolve).catch(function (e) {
              var _ = raw.runtime && raw.runtime.lastError;
              reject(e);
            });
          }
        } catch (e) {
          reject(e);
        }
      });
    };
  }

  function wrapStorageArea(area) {
    if (!area) return area;
    // Already promise-based
    try {
      var test = area.get([]);
      if (test && typeof test.then === 'function') return area;
    } catch (_) {
      /* callback style */
    }
    return {
      get: promisify(area.get, area),
      set: promisify(area.set, area),
      remove: area.remove ? promisify(area.remove, area) : undefined,
      clear: area.clear ? promisify(area.clear, area) : undefined,
    };
  }

  var api = raw;

  // Ensure promise helpers for the common Chrome callback APIs we use.
  if (typeof browser === 'undefined') {
    var runtimeWrapper = Object.create(raw.runtime);
    runtimeWrapper.sendMessage = promisify(raw.runtime.sendMessage, raw.runtime);

    api = {
      runtime: runtimeWrapper,
      storage: {
        local: wrapStorageArea(raw.storage && raw.storage.local),
        sync: wrapStorageArea(raw.storage && raw.storage.sync),
        session: raw.storage && raw.storage.session
          ? wrapStorageArea(raw.storage.session)
          : undefined,
        onChanged: raw.storage && raw.storage.onChanged,
      },
      cookies: raw.cookies
        ? {
            getAll: promisify(raw.cookies.getAll, raw.cookies),
            onChanged: raw.cookies.onChanged,
          }
        : undefined,
      tabs: raw.tabs
        ? (function () {
            var tabsWrapper = Object.create(raw.tabs);
            tabsWrapper.query = promisify(raw.tabs.query, raw.tabs);
            tabsWrapper.sendMessage = promisify(raw.tabs.sendMessage, raw.tabs);
            tabsWrapper.create = promisify(raw.tabs.create, raw.tabs);
            if (raw.tabs.get) tabsWrapper.get = promisify(raw.tabs.get, raw.tabs);
            return tabsWrapper;
          })()
        : undefined,
      contextMenus: raw.contextMenus,
      action: raw.action || raw.browserAction,
      browserAction: raw.browserAction || raw.action,
      alarms: raw.alarms,
      offscreen: raw.offscreen,
      sidePanel: raw.sidePanel,
      sidebarAction: raw.sidebarAction,
      commands: raw.commands,
      i18n: raw.i18n,
      permissions: raw.permissions
        ? {
            request: promisify(raw.permissions.request, raw.permissions),
            contains: raw.permissions.contains
              ? promisify(raw.permissions.contains, raw.permissions)
              : undefined,
            remove: raw.permissions.remove
              ? promisify(raw.permissions.remove, raw.permissions)
              : undefined,
          }
        : undefined,
    };
  }

  global.MD_API = api;
  global.MD_ACTION = api.action || api.browserAction || raw.action || raw.browserAction;
})(typeof self !== 'undefined' ? self : this);
