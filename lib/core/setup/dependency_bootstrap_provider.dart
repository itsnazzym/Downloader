import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger/logger_service.dart';
import '../providers/settings_provider.dart';
import 'dependency_bootstrap_service.dart';

class DependencyBootstrapState {
  const DependencyBootstrapState({
    required this.step,
    required this.toolName,
    required this.isBusy,
    required this.isReady,
    required this.hasFailed,
    this.fraction,
    this.errors = const [],
    this.readyTools = const [],
  });

  factory DependencyBootstrapState.initial() {
    return const DependencyBootstrapState(
      step: SetupStep.checking,
      toolName: '',
      isBusy: true,
      isReady: false,
      hasFailed: false,
    );
  }

  final SetupStep step;
  final String toolName;
  final bool isBusy;
  final bool isReady;
  final bool hasFailed;
  final double? fraction;
  final List<String> errors;
  final List<String> readyTools;

  bool get blocksUi => !isReady;
}

class DependencyBootstrapNotifier
    extends StateNotifier<DependencyBootstrapState> {
  DependencyBootstrapNotifier(
    this._service, {
    this.updateYtDlp = true,
    bool autoStart = true,
  }) : super(DependencyBootstrapState.initial()) {
    if (autoStart) {
      ensureReady();
    }
  }

  factory DependencyBootstrapNotifier.ready() {
    return DependencyBootstrapNotifier(
        DependencyBootstrapService(),
        autoStart: false,
      )
      ..state = const DependencyBootstrapState(
        step: SetupStep.ready,
        toolName: '',
        isBusy: false,
        isReady: true,
        hasFailed: false,
      );
  }

  final DependencyBootstrapService _service;
  final bool updateYtDlp;
  bool _running = false;

  Future<void> ensureReady({bool? updateYtDlp}) async {
    if (_running) return;
    _running = true;
    LoggerService.i('Dependency bootstrap started');
    state = DependencyBootstrapState.initial();
    final startedAt = DateTime.now();
    try {
      await _service.ensureReady(
        updateYtDlp: updateYtDlp ?? this.updateYtDlp,
        onProgress: (progress) {
          state = DependencyBootstrapState(
            step: progress.step,
            toolName: progress.toolName,
            isBusy: progress.step != SetupStep.failed,
            isReady: false,
            hasFailed: progress.step == SetupStep.failed,
            fraction: progress.fraction,
            errors: progress.errors,
            readyTools: progress.readyTools,
          );
        },
      );
      const minVisible = Duration(milliseconds: 1200);
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minVisible && !state.hasFailed) {
        await Future<void>.delayed(minVisible - elapsed);
      }
      if (!state.hasFailed) {
        LoggerService.i('Dependency bootstrap ready');
        state = DependencyBootstrapState(
          step: SetupStep.ready,
          toolName: '',
          isBusy: false,
          isReady: true,
          hasFailed: false,
          readyTools: state.readyTools,
        );
      }
    } catch (e) {
      state = DependencyBootstrapState(
        step: SetupStep.failed,
        toolName: '',
        isBusy: false,
        isReady: false,
        hasFailed: true,
        errors: ['$e'],
      );
    } finally {
      _running = false;
    }
  }

  void continueAnyway() {
    state = DependencyBootstrapState(
      step: SetupStep.ready,
      toolName: '',
      isBusy: false,
      isReady: true,
      hasFailed: false,
      errors: state.errors,
      readyTools: state.readyTools,
    );
  }
}

final dependencyBootstrapProvider =
    StateNotifierProvider<
      DependencyBootstrapNotifier,
      DependencyBootstrapState
    >((ref) {
      final autoUpdate = ref.read(settingsProvider).autoUpdateYtDlp;
      return DependencyBootstrapNotifier(
        DependencyBootstrapService(),
        updateYtDlp: autoUpdate,
      );
    });
