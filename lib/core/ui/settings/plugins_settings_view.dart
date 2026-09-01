import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:flutter_animate/flutter_animate.dart';

import 'package:gap/gap.dart';

import '../../design_system/foundation/colors.dart';

import '../../design_system/foundation/spacing.dart';

import '../../design_system/foundation/typography.dart';

import '../../design_system/components/app_button.dart';

import '../../design_system/components/app_toast.dart';

import '../../plugins/plugin_manager.dart';

import '../../providers/settings_provider.dart';
import '../settings_view.dart';

import '../../services/browser_extension_installer.dart';
import 'widgets/extension_install_guide_dialog.dart';

import 'package:modern_downloader/l10n/app_localizations.dart';

import 'package:modern_downloader/l10n/l10n_ext.dart';

class PluginsSettingsView extends ConsumerWidget {
  const PluginsSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final pluginState = ref.watch(pluginManagerProvider);

    final pluginManager = ref.read(pluginManagerProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,

      backgroundColor: AppColors.of(context).background,

      appBar: AppBar(
        leading: settingsLeading(context),

        backgroundColor: AppColors.of(
          context,
        ).background.withValues(alpha: 0.8),

        elevation: 0,

        centerTitle: true,

        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),

            child: Container(color: Colors.transparent),
          ),
        ),

        title: Text(
          l10n.plugins,

          style: AppTypography.h3.copyWith(
            color: AppColors.of(context).textPrimary,

            fontWeight: FontWeight.w600,
          ),
        ),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),

          child: Container(
            color: AppColors.of(context).border.withValues(alpha: 0.5),

            height: 1,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,

          vertical: AppSpacing.xl + 20,
        ),

        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),

            child: !pluginState.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        l10n.pluginsSectionTitle,

                        style: AppTypography.h3.copyWith(
                          color: AppColors.of(context).textPrimary,
                        ),
                      ),

                      const Gap(AppSpacing.xs),

                      Text(
                        l10n.pluginsSectionHint,

                        style: AppTypography.bodySmall,
                      ),

                      const Gap(AppSpacing.m),

                      if (pluginState.plugins.isEmpty)
                        _buildEmptyState(context, context.l10n)
                      else
                        ...pluginState.plugins
                            .map(
                              (entry) => _PluginCard(
                                entry: entry,

                                onToggle: (enabled) {
                                  pluginManager.togglePlugin(
                                    entry.plugin.id,

                                    enabled,
                                  );
                                },
                              ),
                            )
                            .toList()
                            .animate(interval: 80.ms)
                            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                            .slideY(begin: 0.1, end: 0, duration: 300.ms),

                      const Gap(AppSpacing.xl),

                      const _BrowserExtensionsPanel(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),

      child: Column(
        children: [
          Icon(
            Icons.extension_off_outlined,

            size: 40,

            color: AppColors.of(context).textDisabled,
          ),

          const Gap(AppSpacing.s),

          Text(
            l10n.noPluginsInstalled,

            style: AppTypography.label.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginCard extends StatelessWidget {
  final PluginEntry entry;

  final ValueChanged<bool> onToggle;

  const _PluginCard({required this.entry, required this.onToggle});

  IconData _getIcon(String name) {
    switch (name) {
      case 'drive_file_rename_outline':
        return Icons.drive_file_rename_outline;

      case 'extension':
        return Icons.extension;

      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),

      padding: const EdgeInsets.all(AppSpacing.m),

      decoration: BoxDecoration(
        color: AppColors.of(context).surface,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(
          color: entry.isEnabled
              ? AppColors.of(context).border
              : AppColors.of(context).border.withValues(alpha: 0.5),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 44,

            height: 44,

            decoration: BoxDecoration(
              color: entry.isEnabled
                  ? AppColors.of(context).surfaceHighlight
                  : AppColors.of(context).background,

              borderRadius: BorderRadius.circular(10),
            ),

            child: Icon(
              _getIcon(entry.plugin.iconName),

              color: entry.isEnabled
                  ? AppColors.of(context).textPrimary
                  : AppColors.of(context).textDisabled,

              size: 22,
            ),
          ),

          const Gap(AppSpacing.m),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.plugin.name,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: AppTypography.label.copyWith(
                          color: entry.isEnabled
                              ? AppColors.of(context).textPrimary
                              : AppColors.of(context).textSecondary,
                        ),
                      ),
                    ),

                    const Gap(AppSpacing.xs),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,

                        vertical: 2,
                      ),

                      decoration: BoxDecoration(
                        color: AppColors.of(context).surfaceHighlight,

                        borderRadius: BorderRadius.circular(4),
                      ),

                      child: Text(
                        'v${entry.plugin.version}',

                        style: AppTypography.caption.copyWith(fontSize: 10),
                      ),
                    ),

                    if (entry.plugin.isBuiltIn) ...[
                      const Gap(AppSpacing.xxs),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,

                          vertical: 2,
                        ),

                        decoration: BoxDecoration(
                          color: AppColors.of(
                            context,
                          ).info.withValues(alpha: 0.15),

                          borderRadius: BorderRadius.circular(4),
                        ),

                        child: Text(
                          l10n.builtIn,

                          style: AppTypography.caption.copyWith(
                            fontSize: 10,

                            color: AppColors.of(context).info,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const Gap(AppSpacing.xxs),

                Text(
                  entry.plugin.description,

                  style: AppTypography.bodySmall,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,
                ),

                if (entry.error != null) ...[
                  const Gap(AppSpacing.xxs),

                  Text(
                    l10n.pluginError('${entry.error}'),

                    style: AppTypography.caption.copyWith(
                      color: AppColors.of(context).error,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (entry.plugin.id == 'builtin_smart_organizer') ...[
            IconButton(
              icon: Icon(
                Icons.build_circle_outlined,

                color: AppColors.of(context).textSecondary,
              ),

              onPressed: () => context.push('/settings/smart_organizer'),

              tooltip: l10n.configurePlugin,
            ),

            const Gap(AppSpacing.s),
          ],

          Switch(
            value: entry.isEnabled,

            onChanged: onToggle,

            activeThumbColor: AppColors.of(context).success,

            inactiveThumbColor: AppColors.of(context).textDisabled,

            inactiveTrackColor: AppColors.of(context).surfaceHighlight,
          ),
        ],
      ),
    );
  }
}

class _BrowserExtensionsPanel extends ConsumerWidget {
  const _BrowserExtensionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final colors = AppColors.of(context);

    final token = ref.watch(settingsProvider.select((s) => s.apiToken));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          l10n.browserExtensionsTitle,

          style: AppTypography.h3.copyWith(color: colors.textPrimary),
        ),

        const Gap(AppSpacing.xs),

        Text(l10n.browserExtensionsHint, style: AppTypography.bodySmall),

        const Gap(AppSpacing.m),

        _BrowserInstallCard(
          title: l10n.chromeExtensionTitle,

          steps: l10n.chromeExtensionSteps,

          primaryLabel: l10n.installInChrome,

          onPrimary: () => ExtensionInstallGuideDialog.show(
            context,
            ExtensionInstallFlow.chromeInstall,
          ),
          secondaryLabel: l10n.downloadExtensionZip,
          secondaryIcon: Icons.download_outlined,
          onSecondary: () => ExtensionInstallGuideDialog.show(
            context,
            ExtensionInstallFlow.chromeZip,
          ),
        ),

        const Gap(AppSpacing.s),

        _BrowserInstallCard(
          title: l10n.firefoxExtensionTitle,

          steps: l10n.firefoxExtensionSteps,

          primaryLabel: l10n.installInFirefox,

          onPrimary: () => ExtensionInstallGuideDialog.show(
            context,
            ExtensionInstallFlow.firefoxInstall,
          ),
          secondaryLabel: l10n.firefoxManualInstall,
          secondaryIcon: Icons.build_outlined,
          onSecondary: () => ExtensionInstallGuideDialog.show(
            context,
            ExtensionInstallFlow.firefoxManual,
          ),
        ),

        const Gap(AppSpacing.m),

        Container(
          width: double.infinity,

          padding: const EdgeInsets.all(AppSpacing.m),

          decoration: BoxDecoration(
            color: colors.surface,

            borderRadius: BorderRadius.circular(12),

            border: Border.all(color: colors.border),
          ),

          child: Row(
            children: [
              Icon(Icons.vpn_key_outlined, color: colors.textSecondary),

              const Gap(AppSpacing.m),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      l10n.extensionApiToken,

                      style: AppTypography.label.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),

                    const Gap(AppSpacing.xxs),

                    Text(
                      token.isEmpty ? l10n.generatedOnFirstLaunch : token,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: AppTypography.mono.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),

              AppButton.secondary(
                label: l10n.copyToken,

                icon: Icons.copy,

                onPressed: token.isEmpty
                    ? null
                    : () async {
                        try {
                          await BrowserExtensionInstaller.copyPath(token);

                          if (!context.mounted) return;

                          AppToast.showSuccess(context, l10n.tokenCopiedHint);
                        } catch (e) {
                          if (!context.mounted) return;

                          AppToast.showError(
                            context,

                            l10n.extensionInstallFailed,
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrowserInstallCard extends StatelessWidget {
  final String title;

  final String steps;

  final String primaryLabel;

  final VoidCallback? onPrimary;

  final String secondaryLabel;

  final IconData secondaryIcon;

  final VoidCallback? onSecondary;

  const _BrowserInstallCard({
    required this.title,

    required this.steps,

    required this.primaryLabel,

    required this.onPrimary,

    required this.secondaryLabel,

    this.secondaryIcon = Icons.download_outlined,

    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(AppSpacing.m),

      decoration: BoxDecoration(
        color: colors.surface,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: colors.border),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: AppTypography.label.copyWith(color: colors.textPrimary),
          ),

          const Gap(AppSpacing.xs),

          Text(steps, style: AppTypography.bodySmall),

          const Gap(AppSpacing.m),

          Wrap(
            spacing: AppSpacing.s,

            runSpacing: AppSpacing.s,

            children: [
              AppButton.primary(
                label: primaryLabel,

                icon: Icons.download_outlined,

                onPressed: onPrimary,
              ),

              AppButton.secondary(
                label: secondaryLabel,

                icon: secondaryIcon,

                onPressed: onSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
