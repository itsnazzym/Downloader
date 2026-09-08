import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:protocol_handler/protocol_handler.dart';

import '../android/android_permissions.dart';
import '../android/android_share_service.dart';
import '../logger/logger_service.dart';
import '../platform/platform_info.dart';
import '../providers/settings_provider.dart';
import '../services/clipboard_service.dart';
import '../services/local_server_service.dart';
import '../services/notification_service.dart';
import '../setup/dependency_bootstrap_provider.dart';
import '../../features/archive/presentation/providers/tiktok_archive_provider.dart';
import '../../features/downloader/data/datasources/startup_cleanup_service.dart';
import 'app_warmup_models.dart';

class AppWarmupNotifier extends StateNotifier<AppWarmupState> {
  final Ref _ref;
  bool _started = false;

  AppWarmupNotifier(this._ref, {bool autoStart = true})
      : super(AppWarmupState.initial()) {
    if (autoStart) {
      // Ensure the warmup pipeline is kicked off after microtask queue
      Future.microtask(() => startWarmup());
    }
  }

  void _updateStageStatus(
    WarmupStageId stageId,
    WarmupStageStatus status, {
    String? description,
  }) {
    final updatedStages = state.stages.map((stage) {
      if (stage.id == stageId) {
        return stage.copyWith(
          status: status,
          description: description,
        );
      }
      return stage;
    }).toList();

    state = state.copyWith(stages: updatedStages);
  }

  Future<void> startWarmup() async {
    if (_started) return;
    _started = true;
    LoggerService.i('Starting application real warmup pipeline...');

    try {
      // =======================================================================
      // STAGE 1 : Moteur Média & Dépendances Binaires (0% -> 25%)
      // =======================================================================
      _updateStageStatus(
        WarmupStageId.mediaEngine,
        WarmupStageStatus.running,
        description: 'Vérification des binaires et initialisation MediaKit...',
      );
      state = state.copyWith(
        progress: 0.10,
        statusMessage: 'Vérification du moteur multimédia...',
      );

      try {
        final depNotifier = _ref.read(dependencyBootstrapProvider.notifier);
        await depNotifier.ensureReady();
        final depState = _ref.read(dependencyBootstrapProvider);

        if (depState.hasFailed && depState.blocksUi) {
          _updateStageStatus(
            WarmupStageId.mediaEngine,
            WarmupStageStatus.failed,
            description: 'Téléchargement de composants requis en attente.',
          );
          state = state.copyWith(
            canContinueAnyway: true,
            error: depState.errors.isNotEmpty ? depState.errors.first : null,
          );
          return;
        }
      } catch (e) {
        LoggerService.w('Dependency bootstrap check warning: $e');
      }

      try {
        MediaKit.ensureInitialized();
      } catch (e) {
        LoggerService.w('MediaKit initialization warning: $e');
      }

      _updateStageStatus(
        WarmupStageId.mediaEngine,
        WarmupStageStatus.completed,
        description: 'Moteur multimédia et outils prêts',
      );
      state = state.copyWith(
        progress: 0.28,
        statusMessage: 'Moteur média prêt. Démarrage des services locaux...',
      );
      await Future.delayed(const Duration(milliseconds: 120));

      // =======================================================================
      // STAGE 2 : Services Réseau & WebSocket (25% -> 50%)
      // =======================================================================
      _updateStageStatus(
        WarmupStageId.localServices,
        WarmupStageStatus.running,
        description: 'Démarrage du serveur WebSocket et des notifications...',
      );
      state = state.copyWith(
        progress: 0.38,
        statusMessage: 'Connexion aux services locaux & extension...',
      );

      try {
        await _ref.read(localServerServiceProvider).start();
      } catch (e) {
        LoggerService.w('LocalServerService start warning: $e');
      }

      try {
        await NotificationService().init();
      } catch (e) {
        LoggerService.w('NotificationService init warning: $e');
      }

      _updateStageStatus(
        WarmupStageId.localServices,
        WarmupStageStatus.completed,
        description: 'Serveur local et notifications actifs',
      );
      state = state.copyWith(
        progress: 0.54,
        statusMessage: 'Services locaux actifs. Enregistrement protocoles...',
      );
      await Future.delayed(const Duration(milliseconds: 120));

      // =======================================================================
      // STAGE 3 : Protocoles Système & Presse-papiers (50% -> 75%)
      // =======================================================================
      _updateStageStatus(
        WarmupStageId.systemIntegrations,
        WarmupStageStatus.running,
        description: 'Activation du moniteur et des deep-links...',
      );
      state = state.copyWith(
        progress: 0.65,
        statusMessage: 'Enregistrement des intégrations système...',
      );

      if (PlatformInfo.isDesktop) {
        try {
          await protocolHandler.register('moderndownloader');
        } catch (e) {
          LoggerService.w('Protocol handler warning: $e');
        }

        try {
          _ref.read(clipboardServiceProvider).startMonitoring();
        } catch (e) {
          LoggerService.w('Clipboard monitoring warning: $e');
        }
      } else if (PlatformInfo.isAndroid) {
        try {
          await AndroidPermissions.ensure();
          AndroidShareService.instance.start();
        } catch (e) {
          LoggerService.w('Android integrations warning: $e');
        }
      }

      _updateStageStatus(
        WarmupStageId.systemIntegrations,
        WarmupStageStatus.completed,
        description: 'Intégrations et presse-papiers configurés',
      );
      state = state.copyWith(
        progress: 0.78,
        statusMessage: 'Intégrations prêtes. Préchauffage des catalogues...',
      );
      await Future.delayed(const Duration(milliseconds: 120));

      // =======================================================================
      // STAGE 4 : Stockage, Nettoyage & Catalogues (75% -> 95%)
      // =======================================================================
      _updateStageStatus(
        WarmupStageId.storageCatalog,
        WarmupStageStatus.running,
        description: 'Indexation du catalogue TikTok et nettoyage du cache...',
      );
      state = state.copyWith(
        progress: 0.88,
        statusMessage: 'Indexation des archives et optimisation cache...',
      );

      try {
        final settings = _ref.read(settingsProvider);
        await StartupCleanupService.cleanup(settings.outputFolder);
      } catch (e) {
        LoggerService.w('Startup cleanup warning: $e');
      }

      try {
        // Await TikTok archive notifier cache indexing
        await _ref.read(tikTokArchiveProvider.notifier).initialized;
      } catch (e) {
        LoggerService.w('TikTok archive warmup warning: $e');
      }

      _updateStageStatus(
        WarmupStageId.storageCatalog,
        WarmupStageStatus.completed,
        description: 'Catalogues indexés et caches nettoyés',
      );
      state = state.copyWith(
        progress: 0.98,
        statusMessage: 'Finalisation et chargement de l\'interface...',
      );
      await Future.delayed(const Duration(milliseconds: 150));

      // =======================================================================
      // STAGE 5 : Handover Fluide (100%)
      // =======================================================================
      state = state.copyWith(
        progress: 1.0,
        statusMessage: 'Prêt !',
      );
      await Future.delayed(const Duration(milliseconds: 200));

      state = state.copyWith(isCompleted: true);
      LoggerService.i('Application real warmup pipeline completed successfully.');
    } catch (e, st) {
      LoggerService.e('Warmup pipeline error: $e', e, st);
      // Fallback: don't permanently block the user
      state = state.copyWith(
        isCompleted: true,
        canContinueAnyway: true,
        error: e.toString(),
      );
    }
  }

  void continueAnyway() {
    state = state.copyWith(
      isCompleted: true,
      canContinueAnyway: false,
    );
  }
}

final appWarmupProvider =
    StateNotifierProvider<AppWarmupNotifier, AppWarmupState>((ref) {
  return AppWarmupNotifier(ref);
});
