import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/security/pairing_coordinator.dart';
import 'package:tapload/l10n/l10n_ext.dart';

/// Asks the user to compare the code with the one in the extension popup.
/// Closing the dialog without a choice denies; it closes itself when the
/// request expires or is replaced.
Future<void> showPairingInvite(
  BuildContext context,
  WidgetRef ref,
  PairingRequest request,
) async {
  final coordinator = ref.read(pairingCoordinatorProvider.notifier);
  await showDialog<void>(
    context: context,
    builder: (_) => _PairingInvite(request: request),
  );
  // No-op when a button already resolved it or it is being approved.
  unawaited(coordinator.deny(request.id));
}

class _PairingInvite extends ConsumerStatefulWidget {
  const _PairingInvite({required this.request});
  final PairingRequest request;

  @override
  ConsumerState<_PairingInvite> createState() => _PairingInviteState();
}

class _PairingInviteState extends ConsumerState<_PairingInvite> {
  var _closed = false;

  void _close() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final request = widget.request;
    final coordinator = ref.read(pairingCoordinatorProvider.notifier);
    ref.listen<PairingRequest?>(pairingCoordinatorProvider, (_, next) {
      if (next?.id != request.id) _close();
    });
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.pairingInviteTitle(request.label)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.pairingInviteBody(request.code)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              request.code.split('').join(' '),
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 4,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.pairingInviteHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            unawaited(coordinator.deny(request.id, always: true));
            _close();
          },
          child: Text(l10n.pairingAlwaysDeny),
        ),
        TextButton(onPressed: _close, child: Text(l10n.pairingDeny)),
        FilledButton(
          onPressed: () {
            unawaited(coordinator.approve(request.id));
            _close();
          },
          child: Text(l10n.pairingAllow),
        ),
      ],
    );
  }
}
