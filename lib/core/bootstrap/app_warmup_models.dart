import 'package:flutter/foundation.dart';

enum WarmupStageId {
  mediaEngine,
  localServices,
  systemIntegrations,
  storageCatalog,
}

enum WarmupStageStatus {
  pending,
  running,
  completed,
  failed,
}

@immutable
class WarmupStageItem {
  final WarmupStageId id;
  final String title;
  final String description;
  final WarmupStageStatus status;

  const WarmupStageItem({
    required this.id,
    required this.title,
    required this.description,
    this.status = WarmupStageStatus.pending,
  });

  WarmupStageItem copyWith({
    WarmupStageStatus? status,
    String? description,
  }) {
    return WarmupStageItem(
      id: id,
      title: title,
      description: description ?? this.description,
      status: status ?? this.status,
    );
  }
}

@immutable
class AppWarmupState {
  final double progress;
  final String statusMessage;
  final List<WarmupStageItem> stages;
  final bool isCompleted;
  final String? error;
  final bool canContinueAnyway;

  const AppWarmupState({
    required this.progress,
    required this.statusMessage,
    required this.stages,
    required this.isCompleted,
    this.error,
    this.canContinueAnyway = false,
  });

  factory AppWarmupState.initial() {
    return const AppWarmupState(
      progress: 0.0,
      statusMessage: 'Initialisation du système...',
      isCompleted: false,
      stages: [
        WarmupStageItem(
          id: WarmupStageId.mediaEngine,
          title: 'Moteur média & Binaires',
          description: 'Vérification de yt-dlp, ffmpeg et moteur vidéo natif',
        ),
        WarmupStageItem(
          id: WarmupStageId.localServices,
          title: 'Services locaux & Réseau',
          description: 'Démarrage du serveur WebSocket et notifications',
        ),
        WarmupStageItem(
          id: WarmupStageId.systemIntegrations,
          title: 'Protocoles & Presse-papiers',
          description: 'Enregistrement des deep-links et moniteur d\'URL',
        ),
        WarmupStageItem(
          id: WarmupStageId.storageCatalog,
          title: 'Stockage & Catalogues',
          description: 'Préchauffage de l\'index TikTok et nettoyage du cache',
        ),
      ],
    );
  }

  AppWarmupState copyWith({
    double? progress,
    String? statusMessage,
    List<WarmupStageItem>? stages,
    bool? isCompleted,
    String? error,
    bool? canContinueAnyway,
  }) {
    return AppWarmupState(
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      stages: stages ?? this.stages,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error,
      canContinueAnyway: canContinueAnyway ?? this.canContinueAnyway,
    );
  }
}
