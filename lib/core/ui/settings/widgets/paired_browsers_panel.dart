import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/components/app_toast.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/security/extension_origin.dart';
import 'package:tapload/core/security/paired_browsers.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/l10n/l10n_ext.dart';

/// Paired browser extensions: list, revoke, blocked origins, and the manual
/// token (collapsed). Shared by every settings design.
class PairedBrowsersPanel extends ConsumerWidget {
  const PairedBrowsersPanel({super.key});

  // Origins are 'scheme://<32-char id>': keep the scheme and both ends.
  static String shortOrigin(String o) =>
      o.length <= 32 ? o : '${o.substring(0, 22)}…${o.substring(o.length - 6)}';

  /// The stored label, except the neutral unknown-browser one, translated.
  static String browserName(AppLocalizations l10n, String label) =>
      label == ExtensionOrigin.unknownBrowser ? l10n.unknownBrowser : label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final store = ref.read(pairedBrowsersProvider.notifier);
    final state = ref.watch(pairedBrowsersProvider);
    final token = ref.watch(settingsProvider.select((s) => s.apiToken));
    final material = MaterialLocalizations.of(context);
    String when(DateTime d) => material.formatShortDate(d.toLocal());

    Future<void> confirm(String message, Future<void> Function() action) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.revokeBrowser),
            ),
          ],
        ),
      );
      if (ok == true) await action();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.pairedBrowsersTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (state.browsers.isNotEmpty)
              TextButton(
                onPressed: () =>
                    confirm(l10n.revokeAllConfirm, store.revokeAll),
                child: Text(l10n.revokeAll),
              ),
          ],
        ),
        if (state.browsers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.pairedBrowsersEmpty),
          ),
        for (final b in state.browsers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(browserName(l10n, b.label)),
            subtitle: Text(
              '${shortOrigin(b.origin)}\n'
              '${l10n.pairedBrowsersPairedOn(when(b.createdAt))} · '
              '${b.lastSeenAt == null ? l10n.pairedBrowsersNeverSeen : l10n.pairedBrowsersLastSeen(when(b.lastSeenAt!))}',
            ),
            isThreeLine: true,
            // Names the browser, or a screen reader hears N identical buttons.
            trailing: Tooltip(
              message: '${l10n.revokeBrowser} ${browserName(l10n, b.label)}',
              child: TextButton(
                onPressed: () => confirm(
                  l10n.revokeBrowserConfirm(browserName(l10n, b.label)),
                  () => store.revoke(b.id),
                ),
                child: Text(l10n.revokeBrowser),
              ),
            ),
          ),
        if (state.blockedOrigins.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l10n.blockedOriginsTitle, style: theme.textTheme.titleSmall),
          for (final o in state.blockedOrigins)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(shortOrigin(o)),
              trailing: Tooltip(
                message: '${l10n.unblockOrigin} ${shortOrigin(o)}',
                child: TextButton(
                  onPressed: () => unawaited(store.unblock(o)),
                  child: Text(l10n.unblockOrigin),
                ),
              ),
            ),
        ],
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(l10n.manualTokenAdvanced),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: SelectableText(
                token.isEmpty ? l10n.generatedOnFirstLaunch : token,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: l10n.copyToken,
                onPressed: token.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: token));
                        if (context.mounted) {
                          AppToast.showSuccess(context, l10n.tokenCopiedHint);
                        }
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
