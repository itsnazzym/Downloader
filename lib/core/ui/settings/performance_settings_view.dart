import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../providers/settings_provider.dart';
import '../settings_view.dart';

class PerformanceSettingsView extends ConsumerWidget {
  const PerformanceSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: SizedBox(),
        backgroundColor: AppColors.background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          "Performance Settings",
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.border.withValues(alpha: 0.5),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  [
                        const SectionTitle("Performance"),
                        SliderTile(
                          title: "Simultaneous Downloads",
                          subtitle: "Max active downloads at once",
                          value: settings.maxConcurrent.toDouble().clamp(
                            1.0,
                            60.0,
                          ),
                          min: 1,
                          max: 60,
                          divisions: 59,
                          onChanged: (v) =>
                              settingsNotifier.setMaxConcurrent(v.toInt()),
                          icon: Icons.layers_outlined,
                        ),
                        SliderTile(
                          title: "Threads per Download",
                          subtitle: "Parallel connections (fragments) per file",
                          value: settings.concurrentFragments.toDouble().clamp(
                            1.0,
                            64.0,
                          ),
                          min: 1,
                          max: 64,
                          divisions: 63,
                          onChanged: (v) => settingsNotifier
                              .setConcurrentFragments(v.toInt()),
                          icon: Icons.bolt_rounded,
                        ),
                      ]
                      .animate(interval: 50.ms)
                      .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                      .slideY(begin: 0.1, end: 0, duration: 300.ms),
            ),
          ),
        ),
      ),
    );
  }
}
