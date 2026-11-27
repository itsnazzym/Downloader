import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/security/paired_browsers.dart';

const _pause = Duration(minutes: 10);
const _rateWindow = Duration(hours: 1);
const _maxPerWindow = 3;
const _maxTrackedOrigins = 100;

/// A pairing invitation waiting for the user's decision in the app. The code
/// is shown to the user and relayed to the extension to compare; it is never
/// logged, and nothing but the app UI can approve the request.
class PairingRequest {
  PairingRequest({
    required this.id,
    required String origin,
    required String label,
    required this.code,
    required this.createdAt,
  }) : origin = cleanPairingOrigin(origin),
       label = cleanPairingLabel(label);

  final String id;
  final String origin;
  final String label;
  final String code;
  final DateTime createdAt;
}

sealed class PairingOutcome {
  const PairingOutcome();
}

class PairingApproved extends PairingOutcome {
  const PairingApproved(this.token);
  final String token;
}

/// The user refused, or the pairing could not be stored (e.g. 20 browsers).
class PairingDenied extends PairingOutcome {
  const PairingDenied(this.retryAfter);
  final Duration retryAfter;
}

class PairingExpired extends PairingOutcome {
  const PairingExpired();
}

enum PairingRefusal { paused, blocked, rateLimited, busy }

/// Either a [request] with its [outcome], or a [refusal] (with [retryAfter]
/// for paused / rateLimited).
class PairingSubmit {
  const PairingSubmit({
    this.request,
    this.outcome,
    this.refusal,
    this.retryAfter,
  });

  final PairingRequest? request;
  final Future<PairingOutcome>? outcome;
  final PairingRefusal? refusal;
  final Duration? retryAfter;
}

class _Pending {
  _Pending(this.request);
  final PairingRequest request;
  final completer = Completer<PairingOutcome>();
  late Timer timer;
  var approving = false;
}

/// Owns the pairing rules the store does not enforce: one pending request,
/// per-origin pause / block / rate limit, a fresh comparison code, expiry.
/// [state] is the pending request the UI must show.
class PairingCoordinator extends StateNotifier<PairingRequest?> {
  PairingCoordinator(
    this._store, {
    DateTime Function()? clock,
    Random? random,
    Duration expiry = const Duration(minutes: 2),
    Timer Function(Duration, void Function())? schedule,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure(),
       _expiry = expiry,
       _schedule = schedule ?? Timer.new,
       super(null);

  final PairedBrowsersStore _store;
  final DateTime Function() _clock;
  final Random _random;
  final Duration _expiry;
  final Timer Function(Duration, void Function()) _schedule;

  _Pending? _pending;
  // Submission times per origin, oldest first. Insertion order = recency of
  // the origin's last submission; capped at [_maxTrackedOrigins].
  final _submissions = <String, List<DateTime>>{};

  @visibleForTesting
  int get trackedOriginCount => _submissions.length;

  PairingSubmit submit({required String origin, required String label}) {
    final o = cleanPairingOrigin(origin);
    if (o.isEmpty || _store.isBlocked(o)) {
      return const PairingSubmit(refusal: PairingRefusal.blocked);
    }
    final paused = _store.pauseRemaining(o);
    if (paused != null) {
      return PairingSubmit(refusal: PairingRefusal.paused, retryAfter: paused);
    }
    final pending = _pending;
    if (pending != null) {
      if (pending.request.origin != o) {
        return const PairingSubmit(refusal: PairingRefusal.busy);
      }
      return PairingSubmit(
        request: pending.request,
        outcome: pending.completer.future,
      );
    }
    final now = _clock();
    final retry = _rateLimitedFor(o, now);
    if (retry != null) {
      return PairingSubmit(
        refusal: PairingRefusal.rateLimited,
        retryAfter: retry,
      );
    }
    _recordSubmission(o, now);

    final p = _Pending(
      PairingRequest(
        id: _hex(8),
        origin: o,
        label: label,
        code: _random.nextInt(10000).toString().padLeft(4, '0'),
        createdAt: now,
      ),
    );
    p.timer = _schedule(_expiry, () {
      if (identical(_pending, p) && !p.approving) {
        _finish(p, const PairingExpired());
      }
    });
    _pending = p;
    state = p.request;
    return PairingSubmit(request: p.request, outcome: p.completer.future);
  }

  /// True only if THIS call issued a token: the request must still be the
  /// pending one, unexpired and not already being approved.
  Future<bool> approve(String requestId) async {
    final p = _pending;
    if (p == null || p.request.id != requestId || p.approving) return false;
    if (!_clock().isBefore(p.request.createdAt.add(_expiry))) {
      _finish(p, const PairingExpired());
      return false;
    }
    // Stays the pending request (UI still shows it, others stay busy) until
    // the store answers, but a second approve / the timer can no longer act.
    p.approving = true;
    PairingOutcome outcome;
    try {
      final (_, token) = await _store.pair(
        origin: p.request.origin,
        label: p.request.label,
      );
      outcome = PairingApproved(token);
    } catch (_) {
      outcome = const PairingDenied(_pause);
    }
    // Disposed meanwhile: the outcome is already completed, the token is lost.
    if (!identical(_pending, p)) return false;
    _finish(p, outcome);
    return outcome is PairingApproved;
  }

  Future<void> deny(String requestId, {bool always = false}) async {
    final p = _pending;
    if (p == null || p.request.id != requestId || p.approving) return;
    // Started before resolving so the pause / block is in place synchronously.
    Future<void> persisted;
    try {
      final origin = p.request.origin;
      persisted = always ? _store.block(origin) : _store.pauseOrigin(origin);
    } catch (_) {
      persisted = Future.value();
    }
    _finish(p, const PairingDenied(_pause));
    try {
      await persisted;
    } catch (_) {
      // The request is already refused; failing to persist must not leak.
    }
  }

  @override
  void dispose() {
    final p = _pending;
    _pending = null;
    if (p != null) {
      p.timer.cancel();
      if (!p.completer.isCompleted) {
        p.completer.complete(const PairingExpired());
      }
    }
    super.dispose();
  }

  void _finish(_Pending p, PairingOutcome outcome) {
    _pending = null;
    p.timer.cancel();
    if (mounted) state = null;
    if (!p.completer.isCompleted) p.completer.complete(outcome);
  }

  /// Time until [origin] may submit again, or null if it has a free slot.
  Duration? _rateLimitedFor(String origin, DateTime now) {
    final times = _submissions[origin];
    if (times == null) return null;
    times.removeWhere((t) => now.difference(t) >= _rateWindow);
    if (times.isEmpty) {
      _submissions.remove(origin);
      return null;
    }
    if (times.length < _maxPerWindow) return null;
    return times.first.add(_rateWindow).difference(now);
  }

  void _recordSubmission(String origin, DateTime now) {
    final times = _submissions.remove(origin) ?? <DateTime>[];
    _submissions[origin] = times..add(now);
    if (_submissions.length <= _maxTrackedOrigins) return;
    _submissions.removeWhere(
      (_, l) => l.every((t) => now.difference(t) >= _rateWindow),
    );
    // shortcut: under a flood of distinct origins the oldest history is
    // forgotten, which only gives those origins a fresh allowance.
    while (_submissions.length > _maxTrackedOrigins) {
      _submissions.remove(_submissions.keys.first);
    }
  }

  String _hex(int bytes) => List.generate(
    bytes,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

final pairingCoordinatorProvider =
    StateNotifierProvider<PairingCoordinator, PairingRequest?>(
      (ref) => PairingCoordinator(ref.watch(pairedBrowsersProvider.notifier)),
    );
