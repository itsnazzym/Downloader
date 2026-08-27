import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:window_manager/window_manager.dart';

import '../../config/app_config.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import '../../setup/dependency_bootstrap_provider.dart';
import '../../setup/dependency_bootstrap_service.dart';
import '../../setup/dependency_catalog.dart';

/// Full-window gate shown until download tools are present.
class DependencySetupOverlay extends ConsumerWidget {
  const DependencySetupOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dependencyBootstrapProvider);
    if (!state.blocksUi) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final percent = state.fraction == null
        ? null
        : (state.fraction!.clamp(0, 1) * 100).round();

    return Material(
      color: colors.background,
      child: SizedBox.expand(
        child: DragToMoveArea(
          child: ColoredBox(
            color: colors.background,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_for_offline_outlined,
                        size: 64,
                        color: colors.primary,
                      ),
                      const Gap(AppSpacing.m),
                      Text(
                        AppConfig.appName,
                        style: AppTypography.h2.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const Gap(AppSpacing.xs),
                      Text(
                        l10n.setupPreparing,
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const Gap(AppSpacing.l),
                      if (state.isBusy) ...[
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: colors.primary,
                          ),
                        ),
                        const Gap(AppSpacing.m),
                        Text(
                          _stepLabel(l10n, state),
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        if (percent != null) ...[
                          const Gap(AppSpacing.s),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: state.fraction,
                              minHeight: 8,
                              color: colors.primary,
                              backgroundColor: colors.surfaceHighlight,
                            ),
                          ),
                          const Gap(AppSpacing.xs),
                          Text(
                            l10n.setupDownloadPercent(percent),
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                      const Gap(AppSpacing.l),
                      ...DependencyCatalog.allSetupExecutableNames().map((
                        name,
                      ) {
                        final ready = state.readyTools
                            .map((item) => item.toLowerCase())
                            .contains(name.toLowerCase());
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                ready
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: ready
                                    ? colors.success
                                    : colors.textDisabled,
                              ),
                              const Gap(AppSpacing.s),
                              Text(
                                name.replaceAll('.exe', ''),
                                style: AppTypography.body.copyWith(
                                  color: ready
                                      ? colors.textPrimary
                                      : colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (state.hasFailed) ...[
                        const Gap(AppSpacing.m),
                        Text(
                          l10n.setupFailed,
                          style: AppTypography.body.copyWith(
                            color: colors.error,
                          ),
                        ),
                        const Gap(AppSpacing.xs),
                        Text(
                          state.errors.join('\n'),
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const Gap(AppSpacing.m),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppButton.secondary(
                              label: l10n.setupContinueAnyway,
                              onPressed: () {
                                ref
                                    .read(dependencyBootstrapProvider.notifier)
                                    .continueAnyway();
                              },
                            ),
                            const Gap(AppSpacing.s),
                            AppButton.primary(
                              label: l10n.setupRetry,
                              onPressed: () {
                                ref
                                    .read(dependencyBootstrapProvider.notifier)
                                    .ensureReady();
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stepLabel(AppLocalizations l10n, DependencyBootstrapState state) {
    switch (state.step) {
      case SetupStep.checking:
        return l10n.setupCheckingTools;
      case SetupStep.downloading:
        return l10n.setupDownloading(state.toolName);
      case SetupStep.extracting:
        return l10n.setupExtracting(state.toolName);
      case SetupStep.verifying:
        return l10n.setupVerifying(state.toolName);
      case SetupStep.updating:
        return l10n.setupUpdatingYtDlp;
      case SetupStep.ready:
        return l10n.setupReady;
      case SetupStep.failed:
        return l10n.setupFailed;
    }
  }
}
