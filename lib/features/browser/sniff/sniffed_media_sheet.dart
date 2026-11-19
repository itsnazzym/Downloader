import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/core/utils/format_utils.dart';
import 'package:modern_downloader/features/browser/sniff/sniffed_media.dart';
import 'package:modern_downloader/features/browser/sniff/stream_probe.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Lists what the in-app browser's page loaded so the user can pick the
/// stream to download, with the session of that browser.
class SniffedMediaSheet extends StatefulWidget {
  const SniffedMediaSheet({
    super.key,
    required this.items,
    required this.onPick,
  });

  final List<SniffedMedia> items;
  final ValueChanged<SniffedMedia> onPick;

  static Future<void> show(
    BuildContext context, {
    required List<SniffedMedia> items,
    required ValueChanged<SniffedMedia> onPick,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SniffedMediaSheet(items: items, onPick: onPick),
    );
  }

  static String kindLabel(AppLocalizations l10n, SniffedKind kind) {
    switch (kind) {
      case SniffedKind.hls:
        return l10n.browserSniffKindHls;
      case SniffedKind.dash:
        return l10n.browserSniffKindDash;
      case SniffedKind.video:
        return l10n.browserSniffKindVideo;
      case SniffedKind.audio:
        return l10n.browserSniffKindAudio;
    }
  }

  @override
  State<SniffedMediaSheet> createState() => _SniffedMediaSheetState();
}

class _SniffedMediaSheetState extends State<SniffedMediaSheet> {
  /// Each manifest is read once, when its row first scrolls into view.
  final Map<String, Future<StreamInfo?>> _probes = {};

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final onPick = widget.onPick;
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: t.line)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
                child: Row(
                  children: [
                    OledIconButton(
                      icon: Icons.close_rounded,
                      tooltip: l10n.close,
                      outlined: false,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Gap(4),
                    Expanded(
                      child: Text(
                        l10n.browserSniffTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OledText.ui(
                          context,
                          size: 20,
                          weight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Text(
                  l10n.browserSniffHint,
                  style: OledText.ui(context, size: 13, color: t.ink2),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Gap(8),
                  itemBuilder: (context, index) {
                    final media = items[index];
                    final probe = _probes.putIfAbsent(
                      media.url,
                      () => probeStream(media),
                    );
                    return OledCard(
                      radius: 16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        onPick(media);
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<StreamInfo?>(
                              future: probe,
                              builder: (context, snapshot) {
                                final info = snapshot.data;
                                final height = info?.height ?? media.heightHint;
                                final title = [
                                  if (height != null) '${height}p',
                                  if (info?.duration != null)
                                    clockLabel(info!.duration!),
                                ].join(' · ');
                                final detail = [
                                  SniffedMediaSheet.kindLabel(l10n, media.kind),
                                  if (info?.bytes != null)
                                    '≈ ${FormatUtils.formatBytes(info!.bytes!)}',
                                  media.host,
                                ].join(' · ');
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title.isEmpty
                                          ? SniffedMediaSheet.kindLabel(
                                              l10n,
                                              media.kind,
                                            )
                                          : title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OledText.ui(
                                        context,
                                        size: 16,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const Gap(2),
                                    Text(
                                      detail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OledText.ui(
                                        context,
                                        size: 12,
                                        color: t.ink2,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const Gap(10),
                          Icon(Icons.download_rounded, size: 20, color: t.ink),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Text(
                  l10n.browserSniffDrmNote,
                  style: OledText.ui(context, size: 12, color: t.ink3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
