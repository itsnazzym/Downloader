/**
 * Chrome MV3 Service Worker for TapLoad.
 * Directly runs the connection client and WebSocket connection (Chrome 116+).
 */
(function () {
  'use strict';

  if (typeof importScripts === 'function') {
    try {
      importScripts('browser_api.js');
      importScripts('url_policy.js');
      importScripts('badge.js');
      importScripts('stream_sniffer.js');
      importScripts('connection.js');
    } catch (e) {
      console.error('Failed to import extension background scripts', e);
    }
  }
})();
