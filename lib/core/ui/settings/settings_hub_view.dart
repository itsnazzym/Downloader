import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../platform/platform_info.dart';
import 'general_settings_view.dart';

class SettingsHubView extends StatelessWidget {
  const SettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final entries = <_HubEntry>[
      _HubEntry(
        title: l10n.settingsGeneral,
        icon: Icons.tune_rounded,
        path: '/settings/general',
      ),
      _HubEntry(
        title: l10n.settingsOutput,
        icon: Icons.folder_outlined,
        path: '/settings/output',
      ),
      _HubEntry(
        title: l10n.settingsAdvanced,
        icon: Icons.settings_suggest_outlined,
        path: '/settings/advanced',
      ),
      _HubEntry(
        title: l10n.settingsPerformance,
        icon: Icons.speed_rounded,
        path: '/settings/performance',
      ),
      _HubEntry(
        title: l10n.settingsSystem,
        icon: Icons.memory_outlined,
        path: '/settings/system',
      ),
      _HubEntry(
        title: l10n.settingsAppearance,
        icon: Icons.palette_outlined,
        path: '/settings/appearance',
      ),
      _HubEntry(
        title: l10n.settingsPlugins,
        icon: Icons.extension_outlined,
        path: '/settings/plugins',
      ),
      _HubEntry(
        title: l10n.smartOrganization,
        icon: Icons.auto_awesome_motion,
        path: '/settings/smart_organizer',
      ),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        title: Text(
          l10n.settings,
          style: AppTypography.h3.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.xl,
        ),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              leading: Icon(entry.icon, color: colors.textPrimary),
              title: Text(entry.title),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(entry.path),
            ),
          );
        },
      ),
    );
  }
}

class _HubEntry {
  const _HubEntry({
    required this.title,
    required this.icon,
    required this.path,
  });

  final String title;
  final IconData icon;
  final String path;
}

/// Desktop keeps the general page on `/settings`; phones get the hub.
class AdaptiveSettingsHome extends StatelessWidget {
  const AdaptiveSettingsHome({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.useMobileLayout(context)) {
      return const SettingsHubView();
    }
    return const GeneralSettingsView();
  }
}
