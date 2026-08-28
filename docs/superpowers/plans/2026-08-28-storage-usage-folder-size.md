# Storage Usage Folder Size Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the recursive on-disk size of the effective download folder on the Settings > Output Storage Usage card, beside volume used/free, using a 3-segment donut and a compact folder-details block.

**Architecture:** A new `FolderSizeService` scans the target folder in an isolate (`compute` + top-level `scanFolderSize`), caches snapshots in memory for 10 minutes keyed by a normalized Windows path, and never calls `DiskSpaceService`. `StorageChart` loads volume stats immediately via injectable `loadDisk`, peeks the folder cache for the first paint, then applies `FolderSizeResult`. `OutputSettingsView` passes the effective path from `DownloadPathResolver.resolve` with `itemFolders: []`.

**Tech Stack:** Flutter Windows (`modern_downloader`), `dart:io` + `compute`, `fl_chart`, `flutter_localizations` ARB (en/fr/ar), `FormatUtils.formatBytes`, `DownloadFileResolver` extension lists, `flutter_test`.

## Global Constraints

- Recursive on-disk folder size (root files + subfolders + `.part` / `.ytdl` / `.aria2` / thumbnails). Not library-only.
- Do not reuse, extend, or call `DiskSpaceService` (different TTL, PowerShell, system-drive free space).
- In-memory cache only. Do not persist cache to disk. Lost when the process exits.
- Do not update totals live during a download. Refresh forces disk + folder.
- Do not add a page, tile, or Explorer navigation. Do not show more than 3 subfolders or a full tree.
- Do not scan a random disk if the output folder is empty: resolve `%USERPROFILE%\Downloads` via `DownloadPathResolver` (`itemFolders: []`).
- Do not edit generated `lib/l10n/app_localizations*.dart` by hand; run `flutter gen-l10n`.
- Do not modify `lib/core/services/disk_space_service.dart`, the stats screen, library, or download queue.
- No hardcoded user-visible strings in `storage_chart.dart` (use l10n keys from this plan).
- Donut colors: Folder = `AppColors.warning`, Other used = `AppColors.primary`, Free = `AppColors.success`. Do not use `AppColors.accent` on the donut.
- Cache TTL: `Duration(minutes: 10)`. Fresh means age **strictly less than** 10 minutes. Age `>= 10 minutes` rescans.
- Percentages: one decimal, `toStringAsFixed(1)`, point separator. Thin slice: part **< 5.0%** of volume total → `titlePositionPercentageOffset = 1.4` and `textPrimary`; else `0.5` and white.
- Widget must not rethrow folder exceptions to the framework (`try/catch` + `debugPrint`).
- Windows PowerShell: commits use `git commit -m "subject"` (no bash HEREDOC). Do not update git config. Do not skip hooks.
- Execution worktree (if used) must come from `superpowers:using-git-worktrees` at execution time — do not create one while writing this plan.

---

## File structure

| File | Responsibility |
| --- | --- |
| Create: `lib/core/services/folder_size_service.dart` | `FolderSizeSnapshot`, `FolderSizeEntry`, sealed `FolderSizeResult`, top-level `scanFolderSize`, `FolderSizeService` (peek / getSize / resetCache / isFresh, in-memory TTL cache, in-flight map, default `compute` scanner) |
| Create: `test/core/services/folder_size_service_test.dart` | Real temp trees for scanner tests; fake clock + call-counting scanner for TTL / path / error |
| Modify: `lib/l10n/app_en.arb` | New `storage*` keys (template) |
| Modify: `lib/l10n/app_fr.arb` | Same keys, French |
| Modify: `lib/l10n/app_ar.arb` | Same keys, Arabic |
| Generated (do not hand-edit): `lib/l10n/app_localizations*.dart` | From `flutter gen-l10n` |
| Modify: `lib/core/ui/settings/widgets/storage_chart.dart` | Inject `FolderSizeService` + `loadDisk`; `DiskChartData`; 3-segment donut; legend %; folder details; states; `FormatUtils.formatBytes` |
| Create: `test/core/ui/settings/widgets/storage_chart_test.dart` | Fake service + fake `loadDisk`; no real `DiskSpace` |
| Modify: `lib/core/ui/settings/output_settings_view.dart` | Effective path via `DownloadPathResolver` |
| Modify: `test/core/download/download_path_resolver_test.dart` | Null `userProfile` → `null` (view maps to `''`) |
| Unchanged: `lib/core/utils/format_utils.dart` | Call `formatBytes` with `.round()` from the chart; no API change |

Do not create a new FormatUtils helper. Do not extract a new chart file.

---

### Task 1: FolderSizeService scanner

**Files:**
- Create: `lib/core/services/folder_size_service.dart`
- Test: `test/core/services/folder_size_service_test.dart`

**Interfaces:**
- Consumes: `DownloadFileResolver.isVideoPath` / `isAudioPath` (`lib/core/download/download_file_resolver.dart`), `dart:io`, `package:path/path.dart`
- Produces:
  - `class FolderSizeEntry { const FolderSizeEntry({required String name, required int bytes}); final String name; final int bytes; }`
  - `class FolderSizeSnapshot { const FolderSizeSnapshot({required String path, required int totalBytes, required int fileCount, required List<FolderSizeEntry> topSubfolders, required int videoBytes, required int audioBytes, required int otherBytes, required DateTime scannedAt}); FolderSizeSnapshot copyWith({DateTime? scannedAt}); }`
  - `sealed class FolderSizeResult {}`
  - `class FolderSizeOk extends FolderSizeResult { FolderSizeOk(this.snapshot); final FolderSizeSnapshot snapshot; }`
  - `class FolderSizeError extends FolderSizeResult { FolderSizeError(this.path); final String path; }`
  - `typedef FolderScanner = Future<FolderSizeSnapshot> Function(String path);`
  - `Future<FolderSizeSnapshot> scanFolderSize(String path);` — production isolate entrypoint; tests call this directly (no `compute`)
  - `class FolderSizeService { FolderSizeService({FolderScanner? scanner, DateTime Function()? clock}); static const Duration cacheTtl = Duration(minutes: 10); FolderSizeSnapshot? peek(String path); Future<FolderSizeResult> getSize(String path, {bool force = false}); void resetCache(); bool isFresh(FolderSizeSnapshot snapshot); }`
  - Default `scanner`: `(path) => compute(scanFolderSize, path)`. Tests always pass `scanner: scanFolderSize` (no isolate).

- [ ] **Step 1: Write the failing scanner tests**

Create `test/core/services/folder_size_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/folder_size_service.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('folder_size_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  FolderSizeService serviceWithProdScanner({DateTime Function()? clock}) {
    return FolderSizeService(
      scanner: scanFolderSize,
      clock: clock,
    );
  }

  Future<File> writeBytes(String relativePath, int length) async {
    final file = File('${tempRoot.path}${Platform.pathSeparator}$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(length, 1), flush: true);
    return file;
  }

  FolderSizeSnapshot okSnapshot(FolderSizeResult result) {
    expect(result, isA<FolderSizeOk>());
    return (result as FolderSizeOk).snapshot;
  }

  test('sums nested files into totalBytes and fileCount', () async {
    await writeBytes('root.bin', 10);
    await writeBytes('sub${Platform.pathSeparator}nested.bin', 25);
    final service = serviceWithProdScanner();

    final snapshot = okSnapshot(await service.getSize(tempRoot.path));

    expect(snapshot.totalBytes, 35);
    expect(snapshot.fileCount, 2);
    expect(snapshot.videoBytes + snapshot.audioBytes + snapshot.otherBytes, 35);
  });

  test('missing folder is FolderSizeOk with zeros', () async {
    final missing = '${tempRoot.path}${Platform.pathSeparator}does-not-exist';
    final clock = DateTime(2026, 8, 28, 14, 5);
    final service = serviceWithProdScanner(clock: () => clock);

    final snapshot = okSnapshot(await service.getSize(missing));

    expect(snapshot.totalBytes, 0);
    expect(snapshot.fileCount, 0);
    expect(snapshot.topSubfolders, isEmpty);
    expect(snapshot.videoBytes, 0);
    expect(snapshot.audioBytes, 0);
    expect(snapshot.otherBytes, 0);
    expect(snapshot.scannedAt, clock);
  });

  test('includes partials and thumbnails in otherBytes', () async {
    await writeBytes('clip.mp4.part', 40);
    await writeBytes('thumb.jpg', 15);
    final service = serviceWithProdScanner();

    final snapshot = okSnapshot(await service.getSize(tempRoot.path));

    expect(snapshot.totalBytes, 55);
    expect(snapshot.fileCount, 2);
    expect(snapshot.otherBytes, 55);
    expect(snapshot.videoBytes, 0);
    expect(snapshot.audioBytes, 0);
  });

  test('classifies video, audio, and other by final extension', () async {
    await writeBytes('a.mp4', 8);
    await writeBytes('b.mp3', 5);
    await writeBytes('c.part', 3);
    final service = serviceWithProdScanner();

    final snapshot = okSnapshot(await service.getSize(tempRoot.path));

    expect(snapshot.videoBytes, 8);
    expect(snapshot.audioBytes, 5);
    expect(snapshot.otherBytes, 3);
    expect(snapshot.totalBytes, 16);
  });

  test('keeps the 3 heaviest direct subfolders; ties sort by name ascending', () async {
    await writeBytes('alpha${Platform.pathSeparator}f.bin', 30);
    await writeBytes('beta${Platform.pathSeparator}f.bin', 50);
    await writeBytes('gamma${Platform.pathSeparator}f.bin', 50);
    await writeBytes('delta${Platform.pathSeparator}f.bin', 10);
    final service = serviceWithProdScanner();

    final snapshot = okSnapshot(await service.getSize(tempRoot.path));

    expect(snapshot.topSubfolders.map((e) => e.name).toList(), ['beta', 'gamma', 'alpha']);
    expect(snapshot.topSubfolders.map((e) => e.bytes).toList(), [50, 50, 30]);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/folder_size_service_test.dart`

Expected: FAIL to compile (`folder_size_service.dart` does not exist / `FolderSizeService` is undefined).

- [ ] **Step 3: Write the scanner + service (minimal cache is OK)**

Create `lib/core/services/folder_size_service.dart`:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../download/download_file_resolver.dart';

class FolderSizeEntry {
  const FolderSizeEntry({required this.name, required this.bytes});

  final String name;
  final int bytes;
}

class FolderSizeSnapshot {
  const FolderSizeSnapshot({
    required this.path,
    required this.totalBytes,
    required this.fileCount,
    required this.topSubfolders,
    required this.videoBytes,
    required this.audioBytes,
    required this.otherBytes,
    required this.scannedAt,
  });

  final String path;
  final int totalBytes;
  final int fileCount;
  final List<FolderSizeEntry> topSubfolders;
  final int videoBytes;
  final int audioBytes;
  final int otherBytes;
  final DateTime scannedAt;

  FolderSizeSnapshot copyWith({DateTime? scannedAt}) {
    return FolderSizeSnapshot(
      path: path,
      totalBytes: totalBytes,
      fileCount: fileCount,
      topSubfolders: topSubfolders,
      videoBytes: videoBytes,
      audioBytes: audioBytes,
      otherBytes: otherBytes,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}

sealed class FolderSizeResult {}

class FolderSizeOk extends FolderSizeResult {
  FolderSizeOk(this.snapshot);
  final FolderSizeSnapshot snapshot;
}

class FolderSizeError extends FolderSizeResult {
  FolderSizeError(this.path);
  final String path;
}

typedef FolderScanner = Future<FolderSizeSnapshot> Function(String path);

FolderSizeSnapshot _emptySnapshot(String path, DateTime scannedAt) {
  return FolderSizeSnapshot(
    path: path,
    totalBytes: 0,
    fileCount: 0,
    topSubfolders: const [],
    videoBytes: 0,
    audioBytes: 0,
    otherBytes: 0,
    scannedAt: scannedAt,
  );
}

Future<FolderSizeSnapshot> scanFolderSize(String path) async {
  final trimmed = path.trim();
  final scannedAt = DateTime.now();
  if (trimmed.isEmpty) {
    return _emptySnapshot(path, scannedAt);
  }

  final dir = Directory(trimmed);
  final exists = dir.existsSync();
  if (!exists) {
    return _emptySnapshot(trimmed, scannedAt);
  }

  final subfolderBytes = <String, int>{};
  try {
    await for (final entity in dir.list(followLinks: false).handleError((Object _, StackTrace __) {})) {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        subfolderBytes[p.basename(entity.path)] = 0;
      }
    }
  } on FileSystemException {
    rethrow;
  }

  var totalBytes = 0;
  var fileCount = 0;
  var videoBytes = 0;
  var audioBytes = 0;
  var otherBytes = 0;

  try {
    await for (final entity in dir.list(recursive: true, followLinks: false).handleError((Object _, StackTrace __) {})) {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) {
        continue;
      }
      late final int length;
      try {
        length = File(entity.path).lengthSync();
      } on FileSystemException {
        continue;
      }
      totalBytes += length;
      fileCount += 1;
      if (DownloadFileResolver.isVideoPath(entity.path)) {
        videoBytes += length;
      } else if (DownloadFileResolver.isAudioPath(entity.path)) {
        audioBytes += length;
      } else {
        otherBytes += length;
      }
      final rel = p.relative(entity.path, from: dir.path);
      final parts = p.split(rel);
      if (parts.length > 1) {
        final name = parts.first;
        subfolderBytes[name] = (subfolderBytes[name] ?? 0) + length;
      }
    }
  } on FileSystemException {
    rethrow;
  }

  final ranked = subfolderBytes.entries.toList()
    ..sort((a, b) {
      final byBytes = b.value.compareTo(a.value);
      if (byBytes != 0) {
        return byBytes;
      }
      return a.key.compareTo(b.key);
    });
  final topSubfolders = ranked
      .take(3)
      .map((e) => FolderSizeEntry(name: e.key, bytes: e.value))
      .toList(growable: false);

  return FolderSizeSnapshot(
    path: trimmed,
    totalBytes: totalBytes,
    fileCount: fileCount,
    topSubfolders: topSubfolders,
    videoBytes: videoBytes,
    audioBytes: audioBytes,
    otherBytes: otherBytes,
    scannedAt: scannedAt,
  );
}

class FolderSizeService {
  FolderSizeService({
    FolderScanner? scanner,
    DateTime Function()? clock,
  }) : _scanner = scanner ?? ((path) => compute(scanFolderSize, path)),
       _clock = clock ?? DateTime.now;

  static const Duration cacheTtl = Duration(minutes: 10);

  final FolderScanner _scanner;
  final DateTime Function() _clock;
  final Map<String, FolderSizeSnapshot> _cache = {};
  final Map<String, Future<FolderSizeResult>> _inFlight = {};

  String _cacheKey(String path) {
    return path.trim().replaceAll('/', '\\').toLowerCase();
  }

  bool isFresh(FolderSizeSnapshot snapshot) {
    return _clock().difference(snapshot.scannedAt) < cacheTtl;
  }

  FolderSizeSnapshot? peek(String path) {
    return _cache[_cacheKey(path)];
  }

  void resetCache() {
    _cache.clear();
    _inFlight.clear();
  }

  Future<FolderSizeResult> getSize(String path, {bool force = false}) async {
    try {
      final snapshot = (await _scanner(path)).copyWith(scannedAt: _clock());
      _cache[_cacheKey(path)] = snapshot;
      return FolderSizeOk(snapshot);
    } catch (_) {
      return FolderSizeError(path);
    }
  }
}
```

Notes for this step:
- `getSize` always scans (no TTL / force / in-flight yet). Task 2 adds those.
- Stamp `scannedAt` with `_clock()` after the scanner returns so missing-folder tests see the fake clock.
- Empty trimmed path must return zeros (never scan the process cwd).
- Classify with `DownloadFileResolver.isVideoPath` / `isAudioPath` on the full path so `video.mp4.part` is **other** (final extension `.part`).
- Ignore nested `FileSystemException` via `handleError`; rethrow if the **root** `list` throws before the stream is handled.
- `topSubfolders` is at most 3. Zero direct directories → empty list.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/folder_size_service_test.dart`

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/services/folder_size_service.dart test/core/services/folder_size_service_test.dart
git commit -m "feat: add FolderSizeService on-disk folder scanner"
```

---

### Task 2: Cache TTL, path keys, in-flight join, root errors

**Files:**
- Modify: `lib/core/services/folder_size_service.dart` (`getSize`, `_inFlight`)
- Test: `test/core/services/folder_size_service_test.dart`

**Interfaces:**
- Consumes: `FolderSizeService`, `scanFolderSize`, `FolderSizeOk`, `FolderSizeError`, `cacheTtl` from Task 1
- Produces: same signatures; `getSize(force: false)` returns cached `FolderSizeOk` when `isFresh`; `getSize(force: true)` always scans or joins the in-flight `Future` for that cache key; root scanner throw → `FolderSizeError` without deleting a previous cache entry; `peek(pathB)` is null until `pathB` has been scanned

- [ ] **Step 1: Write the failing cache tests**

Append inside `main()` in `test/core/services/folder_size_service_test.dart`:

```dart
  test('TTL: second getSize skips scanner while age < 10 min; rescans at 10 min', () async {
    await writeBytes('a.bin', 4);
    var now = DateTime(2026, 8, 28, 12, 0);
    var scans = 0;
    final service = FolderSizeService(
      clock: () => now,
      scanner: (path) async {
        scans += 1;
        return scanFolderSize(path);
      },
    );

    await service.getSize(tempRoot.path);
    expect(scans, 1);

    await service.getSize(tempRoot.path);
    expect(scans, 1);

    now = now.add(const Duration(minutes: 10));
    await service.getSize(tempRoot.path);
    expect(scans, 2);
  });

  test('path A cache is never returned for path B', () async {
    await writeBytes('a.bin', 4);
    final other = await Directory.systemTemp.createTemp('folder_size_b_');
    addTearDown(() async {
      if (await other.exists()) {
        await other.delete(recursive: true);
      }
    });
    final service = FolderSizeService(scanner: scanFolderSize);

    final snapA = okSnapshot(await service.getSize(tempRoot.path));
    expect(service.peek(other.path), isNull);

    final snapB = okSnapshot(await service.getSize(other.path));
    expect(snapA.path, isNot(snapB.path));
    expect(service.peek(tempRoot.path)!.totalBytes, snapA.totalBytes);
    expect(service.peek(other.path)!.totalBytes, snapB.totalBytes);
  });

  test('root PathAccessException is FolderSizeError and keeps prior cache', () async {
    await writeBytes('a.bin', 7);
    var scans = 0;
    var fail = false;
    final service = FolderSizeService(
      scanner: (path) async {
        scans += 1;
        if (fail) {
          throw PathAccessException('list', const OSError('Access denied', 5), path);
        }
        return scanFolderSize(path);
      },
    );

    final first = okSnapshot(await service.getSize(tempRoot.path));
    expect(first.totalBytes, 7);
    expect(scans, 1);

    fail = true;
    final second = await service.getSize(tempRoot.path, force: true);
    expect(second, isA<FolderSizeError>());
    expect((second as FolderSizeError).path, tempRoot.path);
    expect(service.peek(tempRoot.path)!.totalBytes, 7);
    expect(scans, 2);
  });

  test('joins an in-flight scan for the same cache key', () async {
    await writeBytes('a.bin', 3);
    var starts = 0;
    final gate = Completer<void>();
    final service = FolderSizeService(
      scanner: (path) async {
        starts += 1;
        await gate.future;
        return scanFolderSize(path);
      },
    );

    final first = service.getSize(tempRoot.path);
    final second = service.getSize(tempRoot.path);
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
    gate.complete();

    expect(okSnapshot(await first).totalBytes, 3);
    expect(okSnapshot(await second).totalBytes, 3);
    expect(starts, 1);
  });
```

Add `import 'dart:async';` at the top of the test file.

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/core/services/folder_size_service_test.dart`

Expected: FAIL on TTL (second call still increments `scans`), and/or in-flight (`starts` is 2), depending on current `getSize`. Path isolation may already pass.

- [ ] **Step 3: Implement TTL, force, in-flight, preserve cache on error**

Replace `getSize` in `lib/core/services/folder_size_service.dart` with:

```dart
  Future<FolderSizeResult> getSize(String path, {bool force = false}) async {
    final key = _cacheKey(path);
    final pending = _inFlight[key];
    if (pending != null) {
      return pending;
    }

    if (!force) {
      final cached = _cache[key];
      if (cached != null && isFresh(cached)) {
        return FolderSizeOk(cached);
      }
    }

    final future = _scanAndStore(key, path);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  Future<FolderSizeResult> _scanAndStore(String key, String path) async {
    try {
      final snapshot = (await _scanner(path)).copyWith(scannedAt: _clock());
      _cache[key] = snapshot;
      return FolderSizeOk(snapshot);
    } catch (_) {
      return FolderSizeError(path);
    }
  }
```

Rules:
- Fresh cache: `clock().difference(scannedAt) < cacheTtl` (strict `<`). `Duration(minutes: 10)` exactly is stale.
- `force: true` skips the TTL hit but still joins `_inFlight[key]`.
- On catch: do **not** write `_cache[key]`. Existing snapshot stays.
- `peek` returns stale cache too (no TTL filter).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/folder_size_service_test.dart`

Expected: All tests PASS (previous 5 + 4 new).

- [ ] **Step 5: Commit**

```powershell
git add lib/core/services/folder_size_service.dart test/core/services/folder_size_service_test.dart
git commit -m "feat: cache folder size scans for 10 minutes"
```

---

### Task 3: Storage Usage l10n keys

**Files:**
- Modify: `lib/l10n/app_en.arb` (after `storageTotalLabel` / `@storageTotalLabel`)
- Modify: `lib/l10n/app_fr.arb` (same location)
- Modify: `lib/l10n/app_ar.arb` (same location)
- Generated: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_fr.dart`, `app_localizations_ar.dart`

**Interfaces:**
- Consumes: existing `storageUsage`, `storageUsed`, `storageFree`, `storageTotalLabel`, `storageInfoUnavailable`
- Produces (on `AppLocalizations` after `flutter gen-l10n`):
  - `String get storageFolder;`
  - `String get storageOtherUsed;`
  - `String storageFolderOfUsed(String percent);`
  - `String storageFileCount(int count);`
  - `String get storageTypeVideo;`
  - `String get storageTypeAudio;`
  - `String get storageTypeOther;`
  - `String get storageTopSubfolders;`
  - `String get storageScanInProgress;`
  - `String storageLastScanned(String time);`
  - `String get storageScanCached;`
  - `String get storageScanError;`

- [ ] **Step 1: Add ARB keys**

Insert **immediately after** the `@storageTotalLabel` block in each file.

`lib/l10n/app_en.arb`:

```json
  "storageFolder": "Folder",
  "storageOtherUsed": "Other used",
  "storageFolderOfUsed": "{percent}% of used",
  "@storageFolderOfUsed": {
    "placeholders": { "percent": { "type": "String" } }
  },
  "storageFileCount": "{count, plural, =0{0 files} =1{1 file} other{{count} files}}",
  "@storageFileCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "storageTypeVideo": "Video",
  "storageTypeAudio": "Audio",
  "storageTypeOther": "Other",
  "storageTopSubfolders": "Largest folders",
  "storageScanInProgress": "Scanning folder...",
  "storageLastScanned": "Scanned at {time}",
  "@storageLastScanned": {
    "placeholders": { "time": { "type": "String" } }
  },
  "storageScanCached": "Cached",
  "storageScanError": "Could not read this folder",
```

`lib/l10n/app_fr.arb`:

```json
  "storageFolder": "Dossier",
  "storageOtherUsed": "Autre utilisé",
  "storageFolderOfUsed": "{percent}% de l'espace utilisé",
  "@storageFolderOfUsed": {
    "placeholders": { "percent": { "type": "String" } }
  },
  "storageFileCount": "{count, plural, =0{0 fichier} =1{1 fichier} other{{count} fichiers}}",
  "@storageFileCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "storageTypeVideo": "Vidéo",
  "storageTypeAudio": "Audio",
  "storageTypeOther": "Autre",
  "storageTopSubfolders": "Plus gros dossiers",
  "storageScanInProgress": "Analyse du dossier...",
  "storageLastScanned": "Analysé à {time}",
  "@storageLastScanned": {
    "placeholders": { "time": { "type": "String" } }
  },
  "storageScanCached": "Données en cache",
  "storageScanError": "Impossible d'analyser ce dossier",
```

`lib/l10n/app_ar.arb`:

```json
  "storageFolder": "المجلد",
  "storageOtherUsed": "مستخدم آخر",
  "storageFolderOfUsed": "{percent}% من المستخدم",
  "@storageFolderOfUsed": {
    "placeholders": { "percent": { "type": "String" } }
  },
  "storageFileCount": "{count, plural, =0{0 ملف} =1{ملف واحد} other{{count} ملفات}}",
  "@storageFileCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "storageTypeVideo": "فيديو",
  "storageTypeAudio": "صوت",
  "storageTypeOther": "أخرى",
  "storageTopSubfolders": "أكبر المجلدات",
  "storageScanInProgress": "جارٍ تحليل المجلد...",
  "storageLastScanned": "تم التحليل الساعة {time}",
  "@storageLastScanned": {
    "placeholders": { "time": { "type": "String" } }
  },
  "storageScanCached": "مخزّن مؤقتاً",
  "storageScanError": "تعذر قراءة هذا المجلد",
```

Keep valid JSON commas relative to the following `"startingOrganization"` key.

- [ ] **Step 2: Generate l10n and fail a smoke test that needs the getters**

Create `test/core/ui/settings/widgets/storage_chart_test.dart` with only:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

void main() {
  test('storage folder l10n keys are generated', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.storageFolder, 'Folder');
    expect(en.storageOtherUsed, 'Other used');
    expect(en.storageFolderOfUsed('12.5'), '12.5% of used');
    expect(en.storageFileCount(0), '0 files');
    expect(en.storageFileCount(1), '1 file');
    expect(en.storageFileCount(3), '3 files');
    expect(en.storageScanError, 'Could not read this folder');
    expect(en.storageLastScanned('14:05'), 'Scanned at 14:05');
    expect(en.storageScanCached, 'Cached');
    expect(en.storageScanInProgress, 'Scanning folder...');
  });
}
```

Run: `flutter test test/core/ui/settings/widgets/storage_chart_test.dart`

Expected: FAIL (`storageFolder` not defined) until gen-l10n.

- [ ] **Step 3: Generate localizations**

Run: `flutter gen-l10n`

Do not hand-edit `app_localizations*.dart`.

- [ ] **Step 4: Re-run the smoke test**

Run: `flutter test test/core/ui/settings/widgets/storage_chart_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/app_ar.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_fr.dart lib/l10n/app_localizations_ar.dart test/core/ui/settings/widgets/storage_chart_test.dart
git commit -m "feat: add Storage Usage folder-size l10n keys"
```

---

### Task 4: Three-segment donut, legend percents, FormatUtils

**Files:**
- Modify: `lib/core/ui/settings/widgets/storage_chart.dart` (constructor, disk load, pie, legend, `_formatBytes` removal)
- Test: `test/core/ui/settings/widgets/storage_chart_test.dart`

**Interfaces:**
- Consumes: `FolderSizeService`, `FolderSizeSnapshot`, `FolderSizeOk`, `FolderSizeError`, `FolderSizeService.cacheTtl` / `isFresh` / `peek` / `getSize` from Tasks 1–2; `AppLocalizations.storageFolder` / `storageOtherUsed` / `storageUsed` / `storageFree` from Task 3; `FormatUtils.formatBytes(int)`; `AppColors.warning` / `primary` / `success`
- Produces:
  - `class DiskChartData { const DiskChartData({required int totalBytes, required int freeBytes}); final int totalBytes; final int freeBytes; }`
  - `StorageChart({Key? key, required String path, FolderSizeService? folderSizeService, Future<DiskChartData> Function(String path)? loadDisk})`
  - Default `folderSizeService`: `FolderSizeService()` (production `compute` scanner)
  - Default `loadDisk`: current `DiskSpace().scan()` logic, returning `DiskChartData` with int sizes
  - Pie values on **volume total**: Folder = `min(folderBytes, usedBytes)` (omit if 0); Other used = `usedBytes - folderSlice` (omit if 0); Free = `freeBytes` (omit if 0)
  - Legend bytes via `FormatUtils.formatBytes(value.round())` — here values are already `int`
  - No snapshot (peek null and no result yet, or error without cache): 2 slices Used (`storageUsed`, `primary`, all used) + Free; 2 legend rows; no Folder row

- [ ] **Step 1: Write failing widget tests for 3 segments and thin-slice offset**

Replace `test/core/ui/settings/widgets/storage_chart_test.dart` with:

```dart
import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/folder_size_service.dart';
import 'package:modern_downloader/core/theme/app_theme.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';
import 'package:modern_downloader/core/ui/settings/widgets/storage_chart.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FolderSizeSnapshot snap({
    String path = r'C:\dl',
    int totalBytes = 10,
    int fileCount = 1,
    List<FolderSizeEntry> topSubfolders = const [],
    int videoBytes = 10,
    int audioBytes = 0,
    int otherBytes = 0,
    DateTime? scannedAt,
  }) {
    return FolderSizeSnapshot(
      path: path,
      totalBytes: totalBytes,
      fileCount: fileCount,
      topSubfolders: topSubfolders,
      videoBytes: videoBytes,
      audioBytes: audioBytes,
      otherBytes: otherBytes,
      scannedAt: scannedAt ?? DateTime(2026, 8, 28, 14, 5),
    );
  }

  FolderSizeService serviceFor(FolderSizeSnapshot snapshot) {
    return FolderSizeService(scanner: (path) async => snapshot);
  }

  Future<DiskChartData> disk100(String path) async {
    return const DiskChartData(totalBytes: 100, freeBytes: 40);
  }

  Widget wrapChart(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.fromPalette(
        ThemePresets.midnight,
        Brightness.dark,
        useGoogleFonts: false,
      ),
      home: Scaffold(
        body: SizedBox(width: 900, height: 700, child: child),
      ),
    );
  }

  List<PieChartSectionData> sectionsOf(WidgetTester tester) {
    return tester.widget<PieChart>(find.byType(PieChart)).data.sections;
  }

  test('storage folder l10n keys are generated', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.storageFolder, 'Folder');
    expect(en.storageFileCount(0), '0 files');
  });

  testWidgets('draws 3 donut segments and legend percents for folder 10 / used 60 / free 40', (tester) async {
    await tester.pumpWidget(
      wrapChart(
        StorageChart(
          path: r'C:\dl',
          folderSizeService: serviceFor(snap(totalBytes: 10)),
          loadDisk: disk100,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sections = sectionsOf(tester).where((s) => s.value > 0).toList();
    expect(sections, hasLength(3));
    expect(sections.map((s) => s.value).toList(), [10, 50, 40]);

    expect(find.text('10.0%'), findsNWidgets(2));
    expect(find.text('50.0%'), findsNWidgets(2));
    expect(find.text('40.0%'), findsNWidgets(2));
    expect(find.text('10.0 B'), findsWidgets);
    expect(find.text('50.0 B'), findsOneWidget);
    expect(find.text('40.0 B'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('Other used'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
  });

  testWidgets('places folder percent outside the ring when the slice is under 5%', (tester) async {
    await tester.pumpWidget(
      wrapChart(
        StorageChart(
          path: r'C:\dl',
          folderSizeService: serviceFor(snap(totalBytes: 2, videoBytes: 2)),
          loadDisk: disk100,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sections = sectionsOf(tester);
    final folder = sections.firstWhere((s) => s.value == 2);
    expect(folder.titlePositionPercentageOffset, greaterThan(1));
    for (final section in sections.where((s) => s.value / 100 >= 0.05)) {
      expect(section.titlePositionPercentageOffset, lessThanOrEqualTo(1));
    }
  });
}
```

Keep the later-task tests out of this file until Task 5.

- [ ] **Step 2: Run widget tests to verify they fail**

Run: `flutter test test/core/ui/settings/widgets/storage_chart_test.dart`

Expected: FAIL (`DiskChartData` / named params undefined, or pie still has 2 sections with Used/Free only).

- [ ] **Step 3: Implement DiskChartData, injection, 3-segment pie, FormatUtils**

Rewrite `lib/core/ui/settings/widgets/storage_chart.dart` to this (folder details / skeleton / error caption come in Task 5; this version must already load folder size so tests 1–2 settle):

```dart
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

import '../../../design_system/foundation/colors.dart';
import '../../../design_system/foundation/spacing.dart';
import '../../../design_system/foundation/typography.dart';
import '../../../services/folder_size_service.dart';
import '../../../utils/format_utils.dart';

class DiskChartData {
  const DiskChartData({required this.totalBytes, required this.freeBytes});

  final int totalBytes;
  final int freeBytes;
}

class StorageChart extends StatefulWidget {
  StorageChart({
    super.key,
    required this.path,
    FolderSizeService? folderSizeService,
    this.loadDisk,
  }) : folderSizeService = folderSizeService ?? FolderSizeService();

  final String path;
  final FolderSizeService folderSizeService;
  final Future<DiskChartData> Function(String path)? loadDisk;

  @override
  State<StorageChart> createState() => _StorageChartState();
}

class _StorageChartState extends State<StorageChart> {
  int _touchedIndex = -1;
  int? _totalSpace;
  int? _freeSpace;
  bool _diskLoading = true;
  FolderSizeSnapshot? _folderSnapshot;
  bool _folderError = false;
  bool _folderScanInFlight = false;

  Future<DiskChartData> _defaultLoadDisk(String path) async {
    final diskSpace = DiskSpace();
    await diskSpace.scan();
    final disks = diskSpace.disks;
    final normalizedPath = path.replaceAll('/', '\\');
    Disk? targetDisk;
    for (final disk in disks) {
      if (normalizedPath.toUpperCase().startsWith(disk.devicePath.toUpperCase())) {
        targetDisk = disk;
        break;
      }
    }
    targetDisk ??= disks.isNotEmpty ? disks.first : null;
    if (targetDisk == null) {
      throw StateError('No volume');
    }
    return DiskChartData(
      totalBytes: targetDisk.totalSize,
      freeBytes: targetDisk.availableSpace,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAll(resetFolder: true);
  }

  @override
  void didUpdateWidget(covariant StorageChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _loadAll(resetFolder: true);
    }
  }

  Future<void> _loadAll({required bool resetFolder, bool forceFolder = false}) async {
    if (resetFolder) {
      _folderSnapshot = null;
      _folderError = false;
    }
    await Future.wait<void>([
      _loadDisk(showFullSpinner: _totalSpace == null),
      _loadFolder(force: forceFolder),
    ]);
  }

  Future<void> _loadDisk({required bool showFullSpinner}) async {
    if (showFullSpinner) {
      setState(() => _diskLoading = true);
    }
    try {
      final loader = widget.loadDisk ?? _defaultLoadDisk;
      final data = await loader(widget.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _totalSpace = data.totalBytes;
        _freeSpace = data.freeBytes;
        _diskLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading disk space: $e');
      if (!mounted) {
        return;
      }
      setState(() => _diskLoading = false);
    }
  }

  Future<void> _loadFolder({required bool force}) async {
    final path = widget.path;
    if (!force) {
      final peeked = widget.folderSizeService.peek(path);
      if (peeked != null) {
        setState(() {
          _folderSnapshot = peeked;
          _folderError = false;
        });
        if (widget.folderSizeService.isFresh(peeked)) {
          return;
        }
      }
    }
    setState(() => _folderScanInFlight = true);
    try {
      final result = await widget.folderSizeService.getSize(path, force: force);
      if (!mounted || widget.path != path) {
        return;
      }
      switch (result) {
        case FolderSizeOk(:final snapshot):
          setState(() {
            _folderSnapshot = snapshot;
            _folderError = false;
            _folderScanInFlight = false;
          });
        case FolderSizeError():
          setState(() {
            _folderError = true;
            _folderScanInFlight = false;
          });
      }
    } catch (e) {
      debugPrint('Error loading folder size: $e');
      if (!mounted || widget.path != path) {
        return;
      }
      setState(() {
        if (_folderSnapshot == null) {
          _folderError = true;
        }
        _folderScanInFlight = false;
      });
    }
  }

  String _percent(num part, int total) {
    if (total <= 0) {
      return '0.0';
    }
    return (part / total * 100).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_diskLoading && _totalSpace == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_totalSpace == null || _freeSpace == null) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          context.l10n.storageInfoUnavailable,
          style: TextStyle(color: AppColors.of(context).textSecondary),
        ),
      );
    }

    final colors = AppColors.of(context);
    final total = _totalSpace!;
    final free = _freeSpace!;
    final used = max(0, total - free);
    final snapshot = _folderSnapshot;
    final folderBytes = snapshot?.totalBytes ?? 0;
    final folderSlice = snapshot == null ? 0 : min(folderBytes, used);
    final otherUsed = snapshot == null ? used : max(0, used - folderSlice);
    final showFolderLegend = snapshot != null;

    final sections = <PieChartSectionData>[];
    void addSection({
      required Color color,
      required int value,
      required String percent,
    }) {
      if (value <= 0) {
        return;
      }
      final index = sections.length;
      final thin = (value / total * 100) < 5.0;
      sections.add(
        PieChartSectionData(
          color: color,
          value: value.toDouble(),
          title: '$percent%',
          radius: _touchedIndex == index ? 60 : 50,
          titlePositionPercentageOffset: thin ? 1.4 : 0.5,
          titleStyle: TextStyle(
            fontSize: _touchedIndex == index ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: thin ? colors.textPrimary : Colors.white,
          ),
        ),
      );
    }

    if (snapshot == null) {
      addSection(color: colors.primary, value: used, percent: _percent(used, total));
      addSection(color: colors.success, value: free, percent: _percent(free, total));
    } else {
      addSection(color: colors.warning, value: folderSlice, percent: _percent(folderSlice, total));
      addSection(color: colors.primary, value: otherUsed, percent: _percent(otherUsed, total));
      addSection(color: colors.success, value: free, percent: _percent(free, total));
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.storageUsage,
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _loadAll(resetFolder: false, forceFolder: true),
                icon: Icon(Icons.refresh, color: colors.textSecondary),
              ),
            ],
          ),
          const Gap(AppSpacing.m),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: sections,
                    ),
                  ),
                ),
              ),
              const Gap(AppSpacing.l),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showFolderLegend) ...[
                      _Indicator(
                        color: colors.warning,
                        text: context.l10n.storageFolder,
                        size: FormatUtils.formatBytes(folderBytes),
                        percent: '${_percent(folderSlice, total)}%',
                        isSquare: false,
                      ),
                      const Gap(AppSpacing.s),
                      _Indicator(
                        color: colors.primary,
                        text: context.l10n.storageOtherUsed,
                        size: FormatUtils.formatBytes(otherUsed),
                        percent: '${_percent(otherUsed, total)}%',
                        isSquare: false,
                      ),
                    ] else ...[
                      _Indicator(
                        color: colors.primary,
                        text: context.l10n.storageUsed,
                        size: FormatUtils.formatBytes(used),
                        percent: '${_percent(used, total)}%',
                        isSquare: false,
                      ),
                    ],
                    const Gap(AppSpacing.s),
                    _Indicator(
                      color: colors.success,
                      text: context.l10n.storageFree,
                      size: FormatUtils.formatBytes(free),
                      percent: '${_percent(free, total)}%',
                      isSquare: false,
                    ),
                    const Gap(AppSpacing.m),
                    Divider(color: colors.border.withValues(alpha: 0.3)),
                    const Gap(AppSpacing.s),
                    Text(
                      context.l10n.storageTotalLabel(FormatUtils.formatBytes(total)),
                      style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.color,
    required this.text,
    required this.size,
    required this.percent,
    required this.isSquare,
  });

  final Color color;
  final String text;
  final String size;
  final String percent;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.of(context).textPrimary,
                ),
              ),
              Text(
                percent,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).textSecondary,
                ),
              ),
              Text(
                size,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

Legend Folder size uses **scanned** `folderBytes` even if the pie slice was clamped. Pie Folder value uses `folderSlice`. Legend Folder **percent** is the slice share of volume (`folderSlice / total`), matching the donut.

Delete `_formatBytes`. Do not import `dart:math` only for `log`; keep `min`/`max`.

Remove unused `dart:io` from the test file if the analyzer flags it (Task 5 uses it only if you add temp dirs; this task does not).

- [ ] **Step 4: Run widget tests to verify they pass**

Run: `flutter test test/core/ui/settings/widgets/storage_chart_test.dart`

Expected: PASS.

If `pumpAndSettle` times out, replace with `await tester.pump(); await tester.pump(const Duration(milliseconds: 50));` after the first frame — `getSize` should already be complete.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/ui/settings/widgets/storage_chart.dart test/core/ui/settings/widgets/storage_chart_test.dart
git commit -m "feat: show folder slice on the Storage Usage donut"
```

---

### Task 5: Folder details block, scan states, refresh spinner

**Files:**
- Modify: `lib/core/ui/settings/widgets/storage_chart.dart` (caption, skeleton, details, type bar, top 3, refresh spinner)
- Test: `test/core/ui/settings/widgets/storage_chart_test.dart`

**Interfaces:**
- Consumes: l10n keys from Task 3; `FolderSizeSnapshot` fields `fileCount`, `videoBytes`, `audioBytes`, `otherBytes`, `topSubfolders`, `scannedAt`; `AppColors.info` / `accent` / `textDisabled` / `border` for the type bar
- Produces: same `StorageChart` / `DiskChartData` signatures as Task 4, plus:
  - Title row: `storageUsage` | scan caption | refresh
  - Caption: `storageScanInProgress` when no snapshot and scan in flight; `storageLastScanned(_hhmm(scannedAt))` when snapshot and not in flight and not error; `storageScanCached` when snapshot and in-flight rescan; `storageScanError` when `_folderError`
  - Details under the donut row: size + `storageFolderOfUsed`; `storageFileCount`; type bar height 8, `borderRadius` 4; top 3 hidden when `topSubfolders.isEmpty`
  - `storageFolderOfUsed`: `(folderBytes / used * 100).toStringAsFixed(1)` or `'0.0'` if `used == 0`
  - Keys: `Key('storage-folder-skeleton')`, `Key('storage-folder-error')`, `Key('storage-folder-details')`
  - Full-card spinner **only** while volume is unknown. Refresh does not clear a visible donut.
  - While rescan with existing snapshot: keep numbers; spinner **on the refresh button** (small `CircularProgressIndicator`), not a full-card spinner

- [ ] **Step 1: Write failing state tests**

Append to `test/core/ui/settings/widgets/storage_chart_test.dart`:

```dart
  testWidgets('shows folder skeleton and Used/Free legend while getSize is pending', (tester) async {
    final gate = Completer<FolderSizeSnapshot>();
    final service = FolderSizeService(scanner: (path) => gate.future);

    await tester.pumpWidget(
      wrapChart(
        StorageChart(
          path: r'C:\dl',
          folderSizeService: service,
          loadDisk: disk100,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('storage-folder-skeleton')), findsOneWidget);
    expect(find.text('Used'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Folder'), findsNothing);
    expect(find.text('Scanning folder...'), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(sectionsOf(tester).where((s) => s.value > 0), hasLength(2));

    gate.complete(snap(totalBytes: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('shows storageScanError and a 2-slice donut when scan fails without cache', (tester) async {
    final service = FolderSizeService(
      scanner: (path) async {
        throw PathAccessException('list', const OSError('Access denied', 5), path);
      },
    );

    await tester.pumpWidget(
      wrapChart(
        StorageChart(
          path: r'C:\dl',
          folderSizeService: service,
          loadDisk: disk100,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('storage-folder-error')), findsOneWidget);
    expect(find.text('Could not read this folder'), findsWidgets);
    expect(find.byType(StorageChart), findsOneWidget);
    expect(sectionsOf(tester).where((s) => s.value > 0), hasLength(2));
    expect(find.text('Folder'), findsNothing);
  });

  testWidgets('empty snapshot shows 0 files, hides top folders, omits folder pie slice', (tester) async {
    await tester.pumpWidget(
      wrapChart(
        StorageChart(
          path: r'C:\dl',
          folderSizeService: serviceFor(
            snap(
              totalBytes: 0,
              fileCount: 0,
              videoBytes: 0,
              topSubfolders: const [],
            ),
          ),
          loadDisk: disk100,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 files'), findsOneWidget);
    expect(find.text('Largest folders'), findsNothing);
    expect(find.byKey(const Key('storage-folder-details')), findsOneWidget);
    final pie = sectionsOf(tester).where((s) => s.value > 0).toList();
    expect(pie.any((s) => s.color == ThemePresets.midnight.warning && s.value > 0), isFalse);
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('0.0 B'), findsWidgets);
  });
```

Add `import 'dart:io';` if `PathAccessException` needs it.

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/core/ui/settings/widgets/storage_chart_test.dart`

Expected: FAIL (`storage-folder-skeleton` / `storage-folder-error` / `0 files` not found).

- [ ] **Step 3: Add caption, details block, skeleton, error, refresh spinner**

In `_StorageChartState.build`, keep the disk-unavailable and full-card spinner branches from Task 4. Extend the title `Row` and append a details `Column` after the donut `Row`.

Add these helpers on `_StorageChartState`:

```dart
  String _hhmm(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String? _scanCaption(BuildContext context) {
    final l10n = context.l10n;
    if (_folderError) {
      return l10n.storageScanError;
    }
    if (_folderSnapshot == null && _folderScanInFlight) {
      return l10n.storageScanInProgress;
    }
    if (_folderSnapshot != null && _folderScanInFlight) {
      return l10n.storageScanCached;
    }
    if (_folderSnapshot != null) {
      return l10n.storageLastScanned(_hhmm(_folderSnapshot!.scannedAt));
    }
    return null;
  }
```

Replace the title `Row` children with:

```dart
          Row(
            children: [
              Text(
                context.l10n.storageUsage,
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_scanCaption(context) != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _scanCaption(context)!,
                    style: AppTypography.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
              IconButton(
                onPressed: _folderScanInFlight && _folderSnapshot == null
                    ? null
                    : () => _loadAll(resetFolder: false, forceFolder: true),
                icon: _folderScanInFlight && _folderSnapshot != null
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.textSecondary,
                        ),
                      )
                    : Icon(Icons.refresh, color: colors.textSecondary),
              ),
            ],
          ),
```

After the donut/legend `Row`, still inside the card `Column`, add:

```dart
          const Gap(AppSpacing.m),
          if (_folderError && _folderSnapshot == null)
            KeyedSubtree(
              key: const Key('storage-folder-error'),
              child: Text(
                context.l10n.storageScanError,
                style: AppTypography.caption.copyWith(color: colors.textSecondary),
              ),
            )
          else if (_folderSnapshot == null)
            KeyedSubtree(
              key: const Key('storage-folder-skeleton'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 180, color: colors.border),
                  const Gap(AppSpacing.s),
                  Container(height: 8, width: double.infinity, color: colors.border),
                  const Gap(AppSpacing.s),
                  Container(height: 14, width: 220, color: colors.border),
                  const Gap(4),
                  Container(height: 14, width: 200, color: colors.border),
                  const Gap(4),
                  Container(height: 14, width: 210, color: colors.border),
                ],
              ),
            )
          else
            _FolderDetails(
              snapshot: _folderSnapshot!,
              usedBytes: used,
            ),
```

Add `_FolderDetails` (same file, private):

```dart
class _FolderDetails extends StatelessWidget {
  const _FolderDetails({required this.snapshot, required this.usedBytes});

  final FolderSizeSnapshot snapshot;
  final int usedBytes;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final ofUsed = usedBytes <= 0
        ? '0.0'
        : (snapshot.totalBytes / usedBytes * 100).toStringAsFixed(1);
    final types = <({Color color, int bytes, String label})>[
      (color: colors.info, bytes: snapshot.videoBytes, label: l10n.storageTypeVideo),
      (color: colors.accent, bytes: snapshot.audioBytes, label: l10n.storageTypeAudio),
      (color: colors.textDisabled, bytes: snapshot.otherBytes, label: l10n.storageTypeOther),
    ];
    final positive = types.where((t) => t.bytes > 0).toList();

    return KeyedSubtree(
      key: const Key('storage-folder-details'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${FormatUtils.formatBytes(snapshot.totalBytes)} · ${l10n.storageFolderOfUsed(ofUsed)}',
            style: AppTypography.caption.copyWith(color: colors.textPrimary),
          ),
          const Gap(4),
          Text(
            l10n.storageFileCount(snapshot.fileCount),
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const Gap(AppSpacing.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              width: double.infinity,
              child: positive.isEmpty
                  ? ColoredBox(color: colors.border)
                  : Row(
                      children: [
                        for (final t in positive)
                          Expanded(
                            flex: t.bytes,
                            child: ColoredBox(color: t.color),
                          ),
                      ],
                    ),
            ),
          ),
          if (snapshot.topSubfolders.isNotEmpty) ...[
            const Gap(AppSpacing.s),
            Text(
              l10n.storageTopSubfolders,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            for (final entry in snapshot.topSubfolders)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(color: colors.textSecondary),
                      ),
                    ),
                    Text(
                      FormatUtils.formatBytes(entry.bytes),
                      style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
```

Error **with** cache: `_folderError` is true but `_folderSnapshot` is kept, so the details block still shows and the caption is `storageScanError` (do not replace numbers with only the error widget). The `if (_folderError && _folderSnapshot == null)` branch is **only** the no-cache case.

Path change: `_loadAll(resetFolder: true)` already clears `_folderSnapshot` so old numbers never paint for the new path.

Refresh: `forceFolder: true` plus `_loadDisk(showFullSpinner: _totalSpace == null)` so a known volume stays on screen.

- [ ] **Step 4: Run widget tests to verify they pass**

Run: `flutter test test/core/ui/settings/widgets/storage_chart_test.dart`

Expected: All tests PASS.

Also run: `flutter test test/core/services/folder_size_service_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/ui/settings/widgets/storage_chart.dart test/core/ui/settings/widgets/storage_chart_test.dart
git commit -m "feat: add Storage Usage folder details and scan states"
```

---

### Task 6: Effective output folder path

**Files:**
- Modify: `lib/core/ui/settings/output_settings_view.dart` (imports + `StorageChart` path)
- Test: `test/core/download/download_path_resolver_test.dart`

**Interfaces:**
- Consumes: `DownloadPathResolver.resolve({required String settingsOutputFolder, required List<String> itemFolders, String? userProfile})` → `String?`
- Produces: `StorageChart(path: resolved ?? '')` where `itemFolders` is always `[]` and `userProfile` is `Platform.environment['USERPROFILE']`. Empty / missing `USERPROFILE` with empty settings folder → `''`, which `scanFolderSize` treats as missing (zeros). Volume matching still uses the existing first-disk fallback inside `_defaultLoadDisk`.

- [ ] **Step 1: Lock the Output-settings resolve contract**

Append to the existing `group('DownloadPathResolver.resolve')` in `test/core/download/download_path_resolver_test.dart`:

```dart
    test('returns null when folder is empty, itemFolders is empty, and userProfile is missing', () {
      expect(
        DownloadPathResolver.resolve(
          settingsOutputFolder: '  ',
          itemFolders: const [],
          userProfile: null,
        ),
        isNull,
      );
    });

    test('uses user Downloads when output folder is empty and itemFolders is empty', () {
      expect(
        DownloadPathResolver.resolve(
          settingsOutputFolder: '',
          itemFolders: const [],
          userProfile: r'C:\Users\me',
        ),
        r'C:\Users\me\Downloads',
      );
    });
```

Output settings must call `resolve` with `itemFolders: const []`. Never pass library/item folders (that would skip Downloads). When `resolve` returns `null`, the view passes `''` into `StorageChart`.

- [ ] **Step 2: Run the resolver tests**

Run: `flutter test test/core/download/download_path_resolver_test.dart`

Expected: PASS (behavior already implemented in `DownloadPathResolver`). This locks the contract the view must call.

- [ ] **Step 3: Pass the effective path from Output settings**

In `lib/core/ui/settings/output_settings_view.dart`:

Add:

```dart
import 'dart:io';

import '../../download/download_path_resolver.dart';
```

Replace:

```dart
StorageChart(path: settings.outputFolder),
```

with:

```dart
StorageChart(
  path: DownloadPathResolver.resolve(
        settingsOutputFolder: settings.outputFolder,
        itemFolders: const [],
        userProfile: Platform.environment['USERPROFILE'],
      ) ??
      '',
),
```

Do not pass `settings.outputFolder` raw. Do not use the first `DiskSpace` volume as a folder-size target.

- [ ] **Step 4: Run the full related suite**

Run:

```
flutter test test/core/download/download_path_resolver_test.dart test/core/services/folder_size_service_test.dart test/core/ui/settings/widgets/storage_chart_test.dart
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/ui/settings/output_settings_view.dart test/core/download/download_path_resolver_test.dart
git commit -m "feat: scan the resolved Downloads folder on Storage Usage"
```

---

## Spec coverage (self-check)

| Spec requirement | Task |
| --- | --- |
| Recursive on-disk totals, partials, thumbnails | 1 |
| video/audio/other via `DownloadFileResolver` | 1 |
| Top 3 direct subfolders, size desc then name asc | 1 |
| Missing/empty folder → 0, not an error | 1, 5 |
| Empty trimmed path → zeros (not cwd) | 1 |
| TTL 10 min, `force`, peek stale, path keys, in-flight join | 2 |
| Root access error → `FolderSizeError`, cache kept | 2, 5 |
| Default scanner `compute(scanFolderSize)` | 1 (default constructor) |
| l10n en/fr/ar, no hardcoded widget copy | 3, 4, 5 |
| Layout B 3-segment donut warning/primary/success | 4 |
| % on donut and legend; thin slice offset 1.4 | 4 |
| Legend bytes from `FormatUtils.formatBytes` | 4 |
| 2-slice Used/Free until a snapshot exists | 4, 5 |
| Folder slice clamped to used; legend shows real size | 4 |
| Disk first; folder skeleton; keep numbers on rescan | 5 |
| Details: of-used, file count, type bar, top 3 | 5 |
| Captions + refresh spinner + error-with-cache | 5 |
| Empty output folder → `%USERPROFILE%\Downloads` | 6 |
| `itemFolders: []`; missing profile → `''` | 6 |
| Do not touch `DiskSpaceService` / stats / library | Global constraint |

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-28-storage-usage-folder-size.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?

**If Subagent-Driven chosen:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (fresh subagent per task + two-stage review).

**If Inline Execution chosen:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (batch execution with checkpoints for review).
