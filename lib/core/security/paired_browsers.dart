import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapload/core/providers/settings_provider.dart';

const _kPairedBrowsers = 'paired_browsers_v1';
const _tokenLength = 43; // 32 random bytes, base64url without padding
const _pauseAfterRevoke = Duration(minutes: 10);
const _lastSeenPersistEvery = Duration(minutes: 1);

// Label and origin come from the (attacker-influenced) browser, and everything
// is rewritten into ONE prefs string on each save, so every size is bounded.
const _maxBrowsers = 20;
const _maxBlocked = 50;
const _maxPaused = 100;
const _maxLabel = 80;
const _maxOrigin = 200;
const _maxStoredChars = 256 * 1024; // legit data is well under 60 KB
const _defaultLabel = 'Navigateur';

final _controlChars = RegExp(r'[\u0000-\u001F\u007F-\u009F\u2028\u2029]');
// Zero-width, bidi marks/overrides/isolates, word joiner, BOM.
final _invisibleChars = RegExp(
  r'[\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]',
);
final _sha256Hex = RegExp(r'^[0-9a-f]{64}$');

String _capRunes(String s, int max) =>
    s.runes.length <= max ? s : String.fromCharCodes(s.runes.take(max));

// Pre-truncating first keeps the regexes cheap on a multi-megabyte input.
// Never cuts between the two halves of a surrogate pair.
String _preCap(String s) {
  if (s.length <= 1000) return s;
  final lastIsHigh = (s.codeUnitAt(999) & 0xFC00) == 0xD800;
  return s.substring(0, lastIsHigh ? 999 : 1000);
}

/// Replaces lone surrogates with U+FFFD: Flutter text layout throws on
/// ill-formed UTF-16, and `runes` surfaces a lone surrogate as 0xD800-0xDFFF.
String _wellFormed(String s) => String.fromCharCodes(
  s.runes.map((r) => r >= 0xD800 && r <= 0xDFFF ? 0xFFFD : r),
);

String _cleanLabel(String raw) {
  final s = _wellFormed(_preCap(raw))
      .replaceAll(_invisibleChars, '')
      .replaceAll(_controlChars, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final capped = _capRunes(s, _maxLabel).trim();
  return capped.isEmpty ? _defaultLabel : capped;
}

// Trimmed again after the cap so cleaning twice (e.g. on reload) is a no-op.
String _cleanOrigin(String raw) => _capRunes(
  _wellFormed(
    _preCap(raw),
  ).replaceAll(_invisibleChars, '').replaceAll(_controlChars, '').trim(),
  _maxOrigin,
).trim();

/// The store's own sanitising, for callers that must show or compare the same
/// values the store would keep (pairing requests).
String cleanPairingOrigin(String raw) => _cleanOrigin(raw);
String cleanPairingLabel(String raw) => _cleanLabel(raw);

/// Thrown by [PairedBrowsersStore.pair] when [_maxBrowsers] pairings already
/// exist. The caller should refuse the pairing (the user must revoke one).
class PairedBrowsersFull implements Exception {
  const PairedBrowsersFull();
  @override
  String toString() =>
      'PairedBrowsersFull: at most $_maxBrowsers paired browsers';
}

/// A browser extension that completed pairing. Only the SHA-256 of its
/// token is kept; the token itself is shown once, at pairing time.
class PairedBrowser {
  const PairedBrowser({
    required this.id,
    required this.origin,
    required this.label,
    required this.tokenHash,
    required this.createdAt,
    this.lastSeenAt,
  });

  final String id;
  final String origin;
  final String label;
  final String tokenHash;
  final DateTime createdAt;
  final DateTime? lastSeenAt;

  PairedBrowser _seen(DateTime at) => PairedBrowser(
    id: id,
    origin: origin,
    label: label,
    tokenHash: tokenHash,
    createdAt: createdAt,
    lastSeenAt: at,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin,
    'label': label,
    'tokenHash': tokenHash,
    'createdAt': createdAt.toIso8601String(),
    'lastSeenAt': lastSeenAt?.toIso8601String(),
  };

  /// Throws on a malformed map; the store skips such entries.
  factory PairedBrowser.fromJson(Map<String, dynamic> j) => PairedBrowser(
    id: j['id'] as String,
    origin: j['origin'] as String,
    label: j['label'] as String,
    tokenHash: j['tokenHash'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    lastSeenAt: j['lastSeenAt'] == null
        ? null
        : DateTime.parse(j['lastSeenAt'] as String),
  );
}

class PairedBrowsersState {
  const PairedBrowsersState({
    this.browsers = const [],
    this.blockedOrigins = const {},
    this.pausedUntil = const {},
  });

  final List<PairedBrowser> browsers;
  final Set<String> blockedOrigins;
  final Map<String, DateTime> pausedUntil;
}

class PairedBrowsersStore extends StateNotifier<PairedBrowsersState> {
  PairedBrowsersStore(this._prefs, {DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random.secure(),
      super(const PairedBrowsersState()) {
    state = _load();
    _syncPersistedSeen();
  }

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final Random _random;
  final _revoked = StreamController<PairedBrowser>.broadcast();
  // lastSeenAt as last written to prefs, per browser id (drives the throttle).
  var _persistedSeen = <String, DateTime>{};

  /// Emits each browser removed by [revoke] / [revokeAll], so the server can
  /// close its sockets.
  Stream<PairedBrowser> get revoked => _revoked.stream;

  static String hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  /// Creates a pairing. The returned token is the only copy ever in clear.
  ///
  /// [label] is sanitised (control/bidi chars removed, <= 80 chars, falls back
  /// to "Navigateur"); [origin] is cleaned and capped at 200 chars.
  /// Throws [ArgumentError] if the cleaned origin is empty and
  /// [PairedBrowsersFull] when 20 browsers are already paired.
  Future<(PairedBrowser, String)> pair({
    required String origin,
    required String label,
  }) async {
    final cleanOrigin = _cleanOrigin(origin);
    if (cleanOrigin.isEmpty) throw ArgumentError.value(origin, 'origin');
    if (state.browsers.length >= _maxBrowsers) throw const PairedBrowsersFull();
    final token = base64Url.encode(_bytes(32)).replaceAll('=', '');
    final browser = PairedBrowser(
      id: _hex(_bytes(8)),
      origin: cleanOrigin,
      label: _cleanLabel(label),
      tokenHash: hashToken(token),
      createdAt: _clock(),
    );
    await _save(browsers: [...state.browsers, browser]);
    return (browser, token);
  }

  /// Compares the token's hash against every stored hash without an early
  /// exit, so timing does not reveal which entry (if any) matched.
  PairedBrowser? authenticate(String token) {
    if (token.length != _tokenLength) return null;
    final hash = hashToken(token);
    PairedBrowser? match;
    for (final b in state.browsers) {
      if (_constantTimeEquals(hash, b.tokenHash)) match = b;
    }
    if (match == null) return null;

    final now = _clock();
    final seen = match._seen(now);
    final persisted = _persistedSeen[match.id];
    final browsers = [
      for (final b in state.browsers) b.id == seen.id ? seen : b,
    ];
    // Disk write only when the STORED value is stale: authenticate is hot.
    if (persisted == null ||
        now.difference(persisted) >= _lastSeenPersistEvery) {
      unawaited(_save(browsers: browsers).catchError((_) {}));
    } else {
      state = PairedBrowsersState(
        browsers: browsers,
        blockedOrigins: state.blockedOrigins,
        pausedUntil: state.pausedUntil,
      );
    }
    return seen;
  }

  Future<void> revoke(String id) async {
    final gone = state.browsers.where((b) => b.id == id).toList();
    if (gone.isEmpty) return;
    await _remove(gone);
  }

  Future<void> revokeAll() async {
    if (state.browsers.isEmpty) return;
    await _remove(List.of(state.browsers));
  }

  /// Blocks an origin for NEW invitations only: existing pairings of that
  /// origin keep authenticating (revoke them to cut access). Keeps the 50
  /// newest entries; throws [ArgumentError] on an empty origin.
  Future<void> block(String origin) {
    final o = _cleanOrigin(origin);
    if (o.isEmpty) throw ArgumentError.value(origin, 'origin');
    if (state.blockedOrigins.contains(o)) return Future.value();
    final blocked = {...state.blockedOrigins, o};
    while (blocked.length > _maxBlocked) {
      blocked.remove(blocked.first);
    }
    return _save(blocked: blocked);
  }

  /// Queries clean their argument exactly like [block] / [pair] do, so an
  /// origin stored clamped is found again from its raw form.
  Future<void> unblock(String origin) {
    final o = _cleanOrigin(origin);
    if (!state.blockedOrigins.contains(o)) return Future.value();
    return _save(blocked: {...state.blockedOrigins}..remove(o));
  }

  bool isBlocked(String origin) =>
      state.blockedOrigins.contains(_cleanOrigin(origin));

  /// Pauses NEW pairing requests from [origin] (default 10 min), as [revoke]
  /// does, without removing anything. Throws [ArgumentError] on an empty
  /// origin; keeps the 100 newest pauses.
  Future<void> pauseOrigin(
    String origin, {
    Duration duration = _pauseAfterRevoke,
  }) {
    final o = _cleanOrigin(origin);
    if (o.isEmpty) throw ArgumentError.value(origin, 'origin');
    final now = _clock();
    final paused = {
      for (final e in state.pausedUntil.entries)
        if (e.key != o && e.value.isAfter(now)) e.key: e.value,
      o: now.add(duration),
    };
    while (paused.length > _maxPaused) {
      paused.remove(paused.keys.first);
    }
    return _save(paused: paused);
  }

  /// Time left on the post-revocation pause for [origin], or null if none.
  /// The pause is per origin: revoking one of several browsers sharing an
  /// origin pauses NEW pairings from it, while the others still authenticate.
  Duration? pauseRemaining(String origin) {
    final until = state.pausedUntil[_cleanOrigin(origin)];
    if (until == null) return null;
    final left = until.difference(_clock());
    return left > Duration.zero ? left : null;
  }

  @override
  void dispose() {
    _revoked.close();
    super.dispose();
  }

  Future<void> _remove(List<PairedBrowser> gone) async {
    final ids = gone.map((b) => b.id).toSet();
    final now = _clock();
    final until = now.add(_pauseAfterRevoke);
    await _save(
      browsers: state.browsers.where((b) => !ids.contains(b.id)).toList(),
      paused: {
        for (final e in state.pausedUntil.entries)
          if (e.value.isAfter(now)) e.key: e.value,
        for (final b in gone) b.origin: until,
      },
    );
    if (_revoked.isClosed) return;
    gone.forEach(_revoked.add);
  }

  Future<void> _save({
    List<PairedBrowser>? browsers,
    Set<String>? blocked,
    Map<String, DateTime>? paused,
  }) async {
    final next = PairedBrowsersState(
      browsers: browsers ?? state.browsers,
      blockedOrigins: blocked ?? state.blockedOrigins,
      pausedUntil: paused ?? state.pausedUntil,
    );
    state = next;
    _syncPersistedSeen();
    await _prefs.setString(
      _kPairedBrowsers,
      jsonEncode({
        'browsers': [for (final b in next.browsers) b.toJson()],
        'blockedOrigins': next.blockedOrigins.toList(),
        'pausedUntil': {
          for (final e in next.pausedUntil.entries)
            e.key: e.value.toIso8601String(),
        },
      }),
    );
  }

  void _syncPersistedSeen() => _persistedSeen = {
    for (final b in state.browsers)
      if (b.lastSeenAt != null) b.id: b.lastSeenAt!,
  };

  /// Corrupt, oversized or oddly typed data yields an empty (or partial)
  /// state, never an exception. Entries are re-sanitised, deduped by id and
  /// token hash and capped; pauses already over are dropped.
  PairedBrowsersState _load() {
    try {
      final raw = _prefs.getString(_kPairedBrowsers);
      if (raw == null || raw.length > _maxStoredChars) {
        return const PairedBrowsersState();
      }
      final j = jsonDecode(raw);
      if (j is! Map) return const PairedBrowsersState();

      final browsers = <PairedBrowser>[];
      final ids = <String>{};
      final hashes = <String>{};
      final rawBrowsers = j['browsers'];
      if (rawBrowsers is List) {
        for (final e in rawBrowsers) {
          if (browsers.length >= _maxBrowsers) break;
          try {
            final b = PairedBrowser.fromJson(
              Map<String, dynamic>.from(e as Map),
            );
            final origin = _cleanOrigin(b.origin);
            if (origin.isEmpty ||
                b.id.isEmpty ||
                b.id.length > 64 ||
                !_sha256Hex.hasMatch(b.tokenHash) ||
                ids.contains(b.id) ||
                hashes.contains(b.tokenHash)) {
              continue;
            }
            ids.add(b.id);
            hashes.add(b.tokenHash);
            browsers.add(
              PairedBrowser(
                id: b.id,
                origin: origin,
                label: _cleanLabel(b.label),
                tokenHash: b.tokenHash,
                createdAt: b.createdAt,
                lastSeenAt: b.lastSeenAt,
              ),
            );
          } catch (_) {
            // Skip an unreadable entry, keep the others.
          }
        }
      }
      final rawBlocked = j['blockedOrigins'];
      final blocked = <String>{};
      if (rawBlocked is List) {
        for (final o in rawBlocked.whereType<String>()) {
          final c = _cleanOrigin(o);
          if (c.isNotEmpty) blocked.add(c);
        }
        while (blocked.length > _maxBlocked) {
          blocked.remove(blocked.first); // keep the newest
        }
      }

      final now = _clock();
      final paused = <String, DateTime>{};
      final rawPaused = j['pausedUntil'];
      if (rawPaused is Map) {
        for (final e in rawPaused.entries) {
          final until = e.value is String ? DateTime.tryParse(e.value) : null;
          if (e.key is! String || until == null || !until.isAfter(now)) {
            continue;
          }
          final origin = _cleanOrigin(e.key as String);
          if (origin.isNotEmpty && paused.length < _maxPaused) {
            paused[origin] = until;
          }
        }
      }
      return PairedBrowsersState(
        browsers: browsers,
        blockedOrigins: blocked,
        pausedUntil: paused,
      );
    } catch (_) {
      return const PairedBrowsersState();
    }
  }

  List<int> _bytes(int n) => List<int>.generate(n, (_) => _random.nextInt(256));

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Both inputs are SHA-256 hex strings (64 chars); XOR-accumulate, no early exit.
  static bool _constantTimeEquals(String a, String b) {
    var diff = a.length ^ b.length;
    for (var i = 0; i < a.length && i < b.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

final pairedBrowsersProvider =
    StateNotifierProvider<PairedBrowsersStore, PairedBrowsersState>(
      (ref) => PairedBrowsersStore(prefs),
    );
