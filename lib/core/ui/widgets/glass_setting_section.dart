import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/design_system/components/glass_card.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';

class GlassSettingSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  final Widget? headerExtra;

  const GlassSettingSection({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
    this.headerExtra,
  });

  Widget _buildOled(BuildContext context) {
    final t = OledTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OledCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: t.ink2),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      title,
                      style: OledText.ui(
                        context,
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (headerExtra != null) headerExtra!,
                ],
              ),
            ),
            Divider(height: 1, color: t.line),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useOledSettingsStyle(context)) return _buildOled(context);
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildIcon(context),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.h3.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (headerExtra != null) headerExtra!,
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withValues(alpha: 0.45), width: 1),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}
