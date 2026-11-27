import 'dart:math';

/// Paces requests per site after it refuses (throttling, anti-bot, TikTok's
/// error page). A refusal pauses every job of that site, longer each time,
/// and a success lifts the pause: a batch slows down by itself instead of
/// burning its retries inside the same blocked window.
class SiteBackoff {
  SiteBackoff({Random? random, DateTime Function()? now})
    : _random = random ?? Random(),
      _now = now ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;
  final _pausedUntil = <String, DateTime>{};
  final _refusals = <String, int>{};

  static const _base = Duration(seconds: 5);
  static const _max = Duration(minutes: 2);

  /// TikTok's share host and its web host are the same service.
  static String siteOf(String url) {
    final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
    if (host.endsWith('tiktok.com') || host.endsWith('tiktokv.com')) {
      return 'tiktok';
    }
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// Wait before retry number [retry] (1-based): 5 s, 20 s, 80 s, then 2 min,
  /// each with up to 25 % random spread so parallel jobs don't retry in step.
  Duration retryDelay(int retry) {
    final factor = pow(4, max(0, retry - 1)).toInt();
    final base = _base * factor;
    final capped = base > _max ? _max : base;
    return capped + capped * (_random.nextDouble() * 0.25);
  }

  /// How long a new request to [url]'s site should wait now.
  Duration waitFor(String url) {
    final until = _pausedUntil[siteOf(url)];
    if (until == null) return Duration.zero;
    final left = until.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  void recordRefusal(String url) {
    final site = siteOf(url);
    final count = (_refusals[site] ?? 0) + 1;
    _refusals[site] = count;
    final until = _now().add(retryDelay(count));
    final current = _pausedUntil[site];
    if (current == null || until.isAfter(current)) _pausedUntil[site] = until;
  }

  void recordSuccess(String url) {
    final site = siteOf(url);
    _refusals.remove(site);
    _pausedUntil.remove(site);
  }
}
