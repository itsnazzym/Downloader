import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/core/logger/logger_service.dart';
import 'package:modern_downloader/core/plugins/plugin_manager.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/services/binary/service_providers.dart';
import 'package:modern_downloader/core/setup/dependency_bootstrap_provider.dart';
import 'package:modern_downloader/features/downloader/data/datasources/persistence_service.dart';
import 'package:modern_downloader/features/downloader/data/repositories/downloader_repository_impl.dart';
import 'package:modern_downloader/features/downloader/data/services/library_scanner_service.dart';
import 'package:modern_downloader/features/downloader/data/sources/gallery_dl_source.dart';
import 'package:modern_downloader/features/downloader/data/sources/kick_source.dart';
import 'package:modern_downloader/features/downloader/data/sources/yt_dlp_source.dart';
import 'package:modern_downloader/features/downloader/domain/repositories/i_downloader_repository.dart';

final ytDlpSourceProvider = Provider<YtDlpSource>((ref) {
  return YtDlpSource(
    ref.read(binaryLocatorProvider),
    ref.read(processRunnerProvider),
  );
});

final galleryDlSourceProvider = Provider<GalleryDlSource>((ref) {
  return GalleryDlSource(ref.read(binaryLocatorProvider));
});

final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  return PersistenceService();
});

final libraryScannerServiceProvider = Provider<LibraryScannerService>((ref) {
  return LibraryScannerService(ref.read(binaryLocatorProvider));
});

final kickSourceProvider = Provider<KickSource>((ref) {
  return KickSource();
});

final downloaderRepositoryProvider = Provider<IDownloaderRepository>((ref) {
  final libraryScanGate = Completer<void>();
  void completeIfUnblocked(DependencyBootstrapState state) {
    if (!state.blocksUi && !libraryScanGate.isCompleted) {
      libraryScanGate.complete();
    }
  }

  try {
    completeIfUnblocked(ref.read(dependencyBootstrapProvider));
    ref.listen<DependencyBootstrapState>(dependencyBootstrapProvider, (
      previous,
      next,
    ) {
      completeIfUnblocked(next);
    });
  } catch (e) {
    LoggerService.w('Waiting for setup before library scan failed: $e');
    if (!libraryScanGate.isCompleted) {
      libraryScanGate.complete();
    }
  }

  return DownloaderRepositoryImpl(
    ref.read(ytDlpSourceProvider),
    ref.read(galleryDlSourceProvider),
    ref.read(persistenceServiceProvider),
    ref.read(libraryScannerServiceProvider),
    ref.read(pluginManagerProvider.notifier),
    () => ref.read(settingsProvider).outputFolder,
    kickSource: ref.read(kickSourceProvider),
    waitForLibraryScan: () => libraryScanGate.future,
  );
});
