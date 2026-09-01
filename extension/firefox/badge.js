/**
 * Toolbar badge helpers shared by the service worker and connection client.
 */
(function (root) {
  'use strict';

  var api = typeof MD_API !== 'undefined'
    ? MD_API
    : (typeof browser !== 'undefined' ? browser : chrome);
  var action = typeof MD_ACTION !== 'undefined'
    ? MD_ACTION
    : (api.action || api.browserAction);

  function setConnected(connected) {
    try {
      api.storage.local.set({ isConnected: !!connected });
    } catch (e) {
      /* ignore */
    }
    if (!action || !action.setBadgeText) return;
    if (connected) {
      action.setBadgeBackgroundColor({ color: '#6C5DD3' });
    } else {
      action.setBadgeText({ text: 'OFF' });
      action.setBadgeBackgroundColor({ color: '#FF4757' });
    }
  }

  function updateActiveBadge(count) {
    if (!action || !action.setBadgeText) return;
    if (count > 0) {
      action.setBadgeText({ text: String(count > 99 ? '99+' : count) });
      action.setBadgeBackgroundColor({ color: '#4CAF50' });
    } else {
      action.setBadgeText({ text: '' });
    }
  }

  root.MDBadge = {
    setConnected: setConnected,
    updateActiveBadge: updateActiveBadge,
  };
})(typeof globalThis !== 'undefined' ? globalThis : self);
