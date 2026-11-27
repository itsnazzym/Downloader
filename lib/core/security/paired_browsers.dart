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
  }

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final Random _random;
  final _revoked = StreamController<PairedBrowser>.broadcast();

  /// Emits each browser removed by [revoke] / [revokeAll], so the server can
  /// close its sockets.
  Stream<PairedBrowser> get revoked => _revoked.stream;

  static String hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  /// Creates a pairing. The returned token is the only copy ever in clear.
  Future<(PairedBrowser, String)> pair({
    required String origin,
    required String label,
  }) async {
    final token = base64Url.encode(_bytes(32)).replaceAll('=', '');
    final browser = PairedBrowser(
      id: _hex(_bytes(8)),
      origin: origin,
      label: label,
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
    final previous = match.lastSeenAt;
    final browsers = [
      for (final b in state.browsers) b.id == seen.id ? seen : b,
    ];
    // Disk write only when the stored value is stale: authenticate is hot.
    if (previous == null || now.difference(previous) >= _lastSeenPersistEvery) {
      unawaited(_save(browsers: browsers));
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

  Future<void> block(String origin) =>
      _save(blocked: {...state.blockedOrigins, origin});

  Future<void> unblock(String origin) =>
      _save(blocked: {...state.blockedOrigins}..remove(origin));

  bool isBlocked(String origin) => state.blockedOrigins.contains(origin);

  /// Time left on the post-revocation pause for [origin], or null if none.
  Duration? pauseRemaining(String origin) {
    final until = state.pausedUntil[origin];
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
    final until = _clock().add(_pauseAfterRevoke);
    await _save(
      browsers: state.browsers.where((b) => !ids.contains(b.id)).toList(),
      paused: {...state.pausedUntil, for (final b in gone) b.origin: until},
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

  /// Corrupt or oddly typed data yields an empty (or partial) state, never
  /// an exception; pauses already over are dropped.
  PairedBrowsersState _load() {
    try {
      final raw = _prefs.getString(_kPairedBrowsers);
      if (raw == null) return const PairedBrowsersState();
      final j = jsonDecode(raw);
      if (j is! Map) return const PairedBrowsersState();

      final browsers = <PairedBrowser>[];
      final rawBrowsers = j['browsers'];
      if (rawBrowsers is List) {
        for (final e in rawBrowsers) {
          try {
            browsers.add(
              PairedBrowser.fromJson(Map<String, dynamic>.from(e as Map)),
            );
          } catch (_) {
            // Skip an unreadable entry, keep the others.
          }
        }
      }
      final rawBlocked = j['blockedOrigins'];
      final blocked = rawBlocked is List
          ? rawBlocked.whereType<String>().toSet()
          : <String>{};

      final now = _clock();
      final paused = <String, DateTime>{};
      final rawPaused = j['pausedUntil'];
      if (rawPaused is Map) {
        for (final e in rawPaused.entries) {
          final until = e.value is String ? DateTime.tryParse(e.value) : null;
          if (e.key is String && until != null && until.isAfter(now)) {
            paused[e.key as String] = until;
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
