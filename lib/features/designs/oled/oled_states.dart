import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/ui/shell/desktop_destinations.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/providers/filtered_downloads_provider.dart';
import 'package:tapload/l10n/l10n_ext.dart';

import 'oled_theme.dart';
import 'oled_widgets.dart';

/// The library's situations in OLED's language: a dim dot-matrix glyph (only
/// its live dot is lit), one line, and the way forward.
class OledState extends StatelessWidget {
  const OledState({
    super.key,
    required this.title,
    this.body,
    this.action,
    this.glyph = true,
    this.danger = false,
  });

  final String title;
  final String? body;
  final Widget? action;
  final bool glyph;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph) ...[
            const OledDotGlyph(width: 70),
            const SizedBox(height: 26),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: oledText(
              size: 18,
              weight: FontWeight.w600,
              color: danger ? OledInk.err : OledInk.ink,
            ),
          ),
          if (body != null && body!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                body!,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: oledText(size: 13.5, color: OledInk.mute, height: 1.45),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    );
  }
}

/// Nothing downloaded yet.
class OledEmptyLibrary extends StatelessWidget {
  const OledEmptyLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OledState(
      title: l10n.yourListIsEmpty,
      body: l10n.emptyLibraryHint,
      action: OledPill(
        label: l10n.newDownload,
        kind: OledPillKind.outline,
        onTap: () => openNewDownload(context),
      ),
    );
  }
}

/// A search or a filter that matches nothing.
class OledNoResults extends ConsumerWidget {
  const OledNoResults({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = ref.watch(downloadSearchQueryProvider).trim();
    return OledState(
      glyph: false,
      title: l10n.noResults,
      body: query.isEmpty ? null : '« $query »',
      action: OledPill(label: l10n.clearSearchAndFilters, onTap: onClear),
    );
  }
}

/// The library could not be read.
class OledLoadError extends ConsumerWidget {
  const OledLoadError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return OledState(
      danger: true,
      title: l10n.error,
      body: '$error',
      action: OledPill(
        label: l10n.retry,
        kind: OledPillKind.outline,
        onTap: () => ref.read(downloadListProvider.notifier).refreshList(),
      ),
    );
  }
}

/// The library loading: unlit rows where the real ones will light up.
class OledRowsSkeleton extends StatelessWidget {
  const OledRowsSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: OledInk.track,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    return Semantics(
      label: context.l10n.loading,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OledHoverBox(
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OledInk.line),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.7 - i * 0.07,
                            child: bar(double.infinity, 10),
                          ),
                          const SizedBox(height: 8),
                          bar(120, 7),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
