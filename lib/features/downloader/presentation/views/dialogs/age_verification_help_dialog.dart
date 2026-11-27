import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tapload/core/utils/browser_launch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:tapload/core/android/android_engine_bridge.dart';
import 'package:tapload/core/platform/platform_info.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/theme/app_colors.dart';
import 'package:tapload/core/theme/app_typography.dart';
import 'package:tapload/features/downloader/domain/entities/download_item.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';

class AgeVerificationHelpDialog extends ConsumerStatefulWidget {
  const AgeVerificationHelpDialog({
    super.key,
    required this.item,
  });

  final DownloadItem item;

  static Future<void> show(BuildContext context, DownloadItem item) {
    return showDialog<void>(
      context: context,
      builder: (context) => AgeVerificationHelpDialog(item: item),
    );
  }

  @override
  ConsumerState<AgeVerificationHelpDialog> createState() =>
      _AgeVerificationHelpDialogState();
}

class _AgeVerificationHelpDialogState
    extends ConsumerState<AgeVerificationHelpDialog> {
  bool _isUpdatingEngine = false;
  String? _engineUpdateStatus;

  String _extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return 'Site web';
    }
  }

  Future<void> _updateEngine() async {
    setState(() {
      _isUpdatingEngine = true;
      _engineUpdateStatus = null;
    });
    await HapticFeedback.mediumImpact();
    try {
      if (PlatformInfo.isAndroid) {
        final status = await AndroidEngineBridge.instance.updateYtDlp();
        if (!mounted) return;
        setState(() {
          _isUpdatingEngine = false;
          _engineUpdateStatus = 'Moteur mis à jour ($status)';
        });
      } else {
        final result = await Process.run('cmd', [
          '/c',
          'bin\\yt-dlp.exe',
          '-U',
        ]);
        if (!mounted) return;
        setState(() {
          _isUpdatingEngine = false;
          _engineUpdateStatus = result.exitCode == 0
              ? 'yt-dlp mis à jour avec succès'
              : 'Échec de la mise à jour';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingEngine = false;
        _engineUpdateStatus = 'Erreur : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final host = _extractHost(widget.item.request.url);
    final isMobile = PlatformInfo.isMobile;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.amber,
                      size: 26,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vérification d\'âge requise',
                          style: AppTypography.h2.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Gap(2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            host,
                            style: AppTypography.mono.copyWith(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const Gap(14),

              // Description
              Text(
                'Ce site restreint ses vidéos par une confirmation de majorité (+18 ans) ou un blocage régional (Arcom / UE). Sans validation préalable, aucun flux vidéo n\'est accessible par le moteur.',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                  fontSize: 12.5,
                ),
              ),
              const Gap(16),

              // Title Solutions
              Text(
                'Solutions recommandées',
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Gap(10),

              // Solution 1: Navigateur intégré (Mobile) ou externe
              _buildSolutionCard(
                colors: colors,
                icon: Icons.open_in_browser_rounded,
                iconColor: colors.primary,
                title: isMobile
                    ? '1. Valider dans le navigateur intégré'
                    : '1. Valider dans votre navigateur web',
                subtitle: isMobile
                    ? 'Ouvrez le lien dans l\'application, acceptez l\'avertissement +18 ans, et les cookies seront automatiquement enregistrés.'
                    : 'Consultez la vidéo dans Chrome ou Firefox pour valider l\'âge, puis fermez le navigateur avant de relancer.',
                action: FilledButton.tonalIcon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                    if (isMobile) {
                      context.push('/browse', extra: widget.item.request.url);
                    } else {
                      openInBrowser(widget.item.request.url);
                    }
                  },
                  icon: Icon(
                    isMobile
                        ? Icons.tab_unselected_rounded
                        : Icons.open_in_new_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isMobile
                        ? 'Ouvrir le navigateur intégré'
                        : 'Ouvrir dans le navigateur',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const Gap(10),

              // Solution 2: Proxy Tor (Desktop uniquement)
              if (!isMobile) ...[
                _buildSolutionCard(
                  colors: colors,
                  icon: Icons.security_rounded,
                  iconColor: Colors.deepPurpleAccent,
                  title: '2. Contourner avec le Proxy Tor',
                  subtitle:
                      'Le blocage étant lié aux lois françaises et à votre IP, faire transiter le téléchargement par Tor permet d\'accéder directement à la vidéo.',
                  action: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch.adaptive(
                        value: settings.useTorProxy,
                        onChanged: (val) {
                          settingsNotifier.setUseTorProxy(val);
                        },
                      ),
                      const Gap(6),
                      Text(
                        settings.useTorProxy ? 'Tor activé' : 'Activer Tor',
                        style: TextStyle(
                          fontSize: 12,
                          color: settings.useTorProxy
                              ? colors.primary
                              : colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(10),

                // Solution 3: Navigateur de cookies (Desktop uniquement)
                _buildSolutionCard(
                  colors: colors,
                  icon: Icons.cookie_outlined,
                  iconColor: Colors.teal,
                  title: '3. Navigateur source des cookies',
                  subtitle:
                      'Sélectionnez le navigateur dans lequel vous avez déjà validé la vérification d\'âge.',
                  action: DropdownButton<String>(
                    value: settings.cookieBrowser,
                    isDense: true,
                    borderRadius: BorderRadius.circular(8),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textPrimary,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'firefox',
                        child: Text('Firefox'),
                      ),
                      DropdownMenuItem(
                        value: 'chrome',
                        child: Text('Chrome'),
                      ),
                      DropdownMenuItem(
                        value: 'edge',
                        child: Text('Edge'),
                      ),
                      DropdownMenuItem(
                        value: 'brave',
                        child: Text('Brave'),
                      ),
                      DropdownMenuItem(
                        value: 'vivaldi',
                        child: Text('Vivaldi'),
                      ),
                      DropdownMenuItem(
                        value: 'opera',
                        child: Text('Opera'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        settingsNotifier.setCookieBrowser(val);
                      }
                    },
                  ),
                ),
                const Gap(10),
              ],

              // Solution 4: Mise à jour du moteur
              _buildSolutionCard(
                colors: colors,
                icon: Icons.system_update_alt_rounded,
                iconColor: Colors.blue,
                title: isMobile
                    ? '2. Mettre à jour yt-dlp'
                    : '4. Mettre à jour yt-dlp',
                subtitle:
                    'xHamster change fréquemment son chiffrement. Une mise à jour intègre les derniers déchiffreurs.',
                action: OutlinedButton.icon(
                  onPressed: _isUpdatingEngine ? null : _updateEngine,
                  icon: _isUpdatingEngine
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(
                    _isUpdatingEngine ? 'Mise à jour...' : 'Vérifier la MàJ',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),

              if (_engineUpdateStatus != null) ...[
                const Gap(8),
                Text(
                  _engineUpdateStatus!,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const Gap(18),

              // Bottom buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                  const Gap(8),
                  FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop();
                      ref
                          .read(downloadListProvider.notifier)
                          .retryDownload(widget.item);
                    },
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Réessayer le téléchargement'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolutionCard({
    required AppColors colors,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceHighlight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const Gap(8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const Gap(6),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              color: colors.textSecondary,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          const Gap(8),
          action,
        ],
      ),
    );
  }
}
