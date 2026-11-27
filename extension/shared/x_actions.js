/**
 * Like / bookmark X posts with the user's own x.com session (content script only).
 * Identifiers (GraphQL queryIds, web-app bearer) are read from X's own bundle at
 * runtime; the csrf token comes from document.cookie. Nothing leaves x.com.
 */
(function (global) {
  'use strict';

  var OPS = ['FavoriteTweet', 'UnfavoriteTweet', 'CreateBookmark', 'DeleteBookmark'];
  // Real button to click for each op, and the button shown once the post is already in that state.
  var BUTTONS = {
    FavoriteTweet: ['like', 'unlike'],
    UnfavoriteTweet: ['unlike', 'like'],
    CreateBookmark: ['bookmark', 'removeBookmark'],
    DeleteBookmark: ['removeBookmark', 'bookmark'],
  };
  var TWEET_ID = /^\d{1,25}$/;
  var MAX_WAIT_MS = 70000;
  var MESSAGES = {
    ok: 'Action effectuée.',
    already: 'Déjà fait.',
    auth: 'Connectez-vous à x.com dans ce navigateur.',
    rate: 'Trop d’actions : X limite temporairement. Réessayez plus tard.',
    stale: 'X a changé : action impossible pour le moment.',
    unknown: 'Action impossible pour le moment.',
  };

  function isOp(op) {
    return OPS.indexOf(op) !== -1;
  }

  function result(ok, code) {
    return { ok: ok, code: code, message: MESSAGES[code] };
  }

  function parseQueryIds(source) {
    var text = String(source || '');
    var key = function (name) { return '["\']?' + name + '["\']?\\s*:\\s*'; };
    var ids = {};
    OPS.forEach(function (op) {
      var name = '["\']' + op + '["\']';
      var value = '["\']([\\w-]+)["\']';
      var m = text.match(new RegExp(key('queryId') + value + '\\s*,\\s*' + key('operationName') + name)) ||
        text.match(new RegExp(key('operationName') + name + '\\s*,\\s*' + key('queryId') + value));
      if (m) ids[op] = m[1];
    });
    // Full web-app token shape (body, %3D, tail) so base64 'A' padding never passes for it.
    // Bounded, and only tried where an alphanumeric run starts, so a huge run of 'A' stays linear.
    var bearer = text.match(/(?<![A-Za-z0-9])A{20}[A-Za-z0-9]{1,200}%3D[A-Za-z0-9]{1,200}/);
    if (bearer) ids.bearer = bearer[0];
    return ids;
  }

  function buildRequest(op, ids, tweetId, ct0) {
    if (!isOp(op)) throw new Error('unknown op');
    if (!TWEET_ID.test(String(tweetId))) throw new Error('invalid tweet id');
    var queryId = ids && ids[op];
    if (!queryId || !ids.bearer) throw new Error('missing identifiers');
    return {
      url: 'https://x.com/i/api/graphql/' + queryId + '/' + op,
      init: {
        method: 'POST',
        credentials: 'include',
        headers: {
          authorization: 'Bearer ' + ids.bearer,
          'x-csrf-token': String(ct0),
          'content-type': 'application/json',
          'x-twitter-auth-type': 'OAuth2Session',
          'x-twitter-active-user': 'yes',
        },
        body: JSON.stringify({ variables: { tweet_id: String(tweetId) }, queryId: queryId }),
      },
    };
  }

  function mapResult(status, body) {
    if (status === 401 || status === 403) return result(false, 'auth');
    if (status === 429) return result(false, 'rate');
    if (status === 400 || status === 404) return result(false, 'stale');
    if (status !== 200) return result(false, 'unknown');
    if (!body || typeof body !== 'object') return result(false, 'unknown');
    var errors = Array.isArray(body.errors) ? body.errors : [];
    if (errors.length === 0) return result(true, 'ok');
    var text = errors.map(function (e) { return String((e && e.message) || ''); }).join(' | ');
    // Stale patterns first: "operation not found" must not read as "already done".
    if (/query ?id|cannot query field|unknown operation|operation[^|]*not found/i.test(text)) return result(false, 'stale');
    // Only an explicit "already ..." is success; "Tweet/User not found" is a real failure.
    if (/already (favorited|bookmarked)/i.test(text)) return result(true, 'already');
    return result(false, 'unknown');
  }

  function createLimiter(opts, now) {
    var stamps = [];
    return {
      next: function () {
        var t = now();
        var at = stamps.length ? Math.max(t, stamps[stamps.length - 1] + opts.minGapMs) : t;
        while (stamps.length && stamps[0] <= at - 60000) stamps.shift();
        if (stamps.length >= opts.perMinute) {
          at = Math.max(at, stamps[stamps.length - opts.perMinute] + 60000);
        }
        // Record the scheduled time so back-to-back calls queue up instead of firing together.
        stamps.push(at);
        return { waitMs: at - t };
      },
    };
  }

  var limiter = null;
  var idsPromise = null;

  function readCookie(doc, name) {
    var m = String((doc && doc.cookie) || '').match(new RegExp('(?:^|;\\s*)' + name + '=([^;]*)'));
    return m ? m[1] : '';
  }

  function bundleUrls(doc) {
    var urls = [];
    var scripts = doc.querySelectorAll('script[src]');
    for (var i = 0; i < scripts.length; i++) {
      var src = String(scripts[i].src || '');
      if (src.indexOf('abs.twimg.com/responsive-web/client-web') !== -1) urls.push(src);
    }
    // main.* holds the mutations and the bearer; the rest are only a fallback.
    return urls.filter(function (u) { return /\/main\.[^/]*\.js/.test(u); })
      .concat(urls.filter(function (u) { return !/\/main\.[^/]*\.js/.test(u); }))
      .slice(0, 8);
  }

  // One shared load for concurrent actions; dropped again when it lacks what an action needs.
  function loadIds(op, env) {
    var pending = idsPromise || (idsPromise = fetchIds(env));
    return pending.then(function (ids) {
      if ((!ids[op] || !ids.bearer) && idsPromise === pending) idsPromise = null;
      return ids;
    });
  }

  async function fetchIds(env) {
    var urls = bundleUrls(env.document);
    var ids = {};
    for (var i = 0; i < urls.length; i++) {
      var found;
      try {
        var res = await env.fetch(urls[i], { credentials: 'omit' });
        if (!res || !res.ok) continue;
        found = parseQueryIds(await res.text());
      } catch (e) {
        continue; // A missing id afterwards reports 'stale'.
      }
      Object.keys(found).forEach(function (k) { if (!ids[k]) ids[k] = found[k]; });
      if (OPS.every(function (o) { return ids[o]; }) && ids.bearer) break;
    }
    return ids;
  }

  function findArticle(doc, tweetId) {
    var articles = doc.querySelectorAll('article');
    var own = new RegExp('/status/' + tweetId + '(?:[/?#]|$)');
    for (var i = 0; i < articles.length; i++) {
      var time = articles[i].querySelector('time');
      var link = time && time.closest ? time.closest('a[href]') : null;
      var href = link ? String(link.getAttribute('href') || link.href || '') : '';
      if (own.test(href)) return articles[i];
    }
    return null;
  }

  function domFallback(op, tweetId, doc, apiResult) {
    try {
      var article = findArticle(doc, tweetId);
      if (!article) return apiResult;
      var pair = BUTTONS[op];
      var button = article.querySelector('[data-testid="' + pair[0] + '"]');
      if (button) {
        button.click();
        return result(true, 'ok');
      }
      // Clicking anything now would toggle the post the wrong way.
      if (article.querySelector('[data-testid="' + pair[1] + '"]')) return result(true, 'already');
    } catch (e) {
      /* fall through */
    }
    return apiResult;
  }

  async function perform(op, tweetId, env) {
    tweetId = String(tweetId);
    if (!isOp(op) || !TWEET_ID.test(tweetId)) return result(false, 'unknown');
    if (!limiter) limiter = createLimiter({ minGapMs: 1500, perMinute: 30 }, env.now);
    var waitMs = limiter.next().waitMs;
    // Refuse rather than fire early: a capped sleep would let a burst go out all at once.
    if (waitMs > MAX_WAIT_MS) return result(false, 'rate');
    if (waitMs > 0) await env.sleep(waitMs);

    var ct0 = readCookie(env.document, 'ct0');
    if (!ct0) return result(false, 'auth');

    var apiResult;
    try {
      var ids = await loadIds(op, env);
      if (!ids[op] || !ids.bearer) {
        apiResult = result(false, 'stale');
      } else {
        var req = buildRequest(op, ids, tweetId, ct0);
        var res = await env.fetch(req.url, req.init);
        var body = null;
        try { body = await res.json(); } catch (e) { body = null; }
        apiResult = mapResult(res.status, body);
      }
    } catch (e) {
      apiResult = result(false, 'unknown');
    }
    // A wrong bearer (auth) or outdated ids (stale) must not stick for the page's lifetime.
    if (apiResult.code === 'auth' || apiResult.code === 'stale') idsPromise = null;
    if (apiResult.code === 'stale' || apiResult.code === 'unknown') {
      return domFallback(op, tweetId, env.document, apiResult);
    }
    return apiResult;
  }

  global.MDXActions = {
    parseQueryIds: parseQueryIds,
    buildRequest: buildRequest,
    mapResult: mapResult,
    createLimiter: createLimiter,
    perform: perform,
  };
})(typeof self !== 'undefined' ? self : this);
