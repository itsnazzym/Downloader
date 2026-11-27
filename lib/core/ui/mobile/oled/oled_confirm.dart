import 'package:flutter/material.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';
import 'package:tapload/l10n/l10n_ext.dart';

/// Bottom-sheet confirmation in the OLED language. Resolves to `true` only
/// when the user taps the confirm button.
Future<bool> showOledConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = false,
}) async {
  final t = OledTokens.of(context);
  final cancel = context.l10n.cancel;
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: t.bg,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: t.line),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: OledText.title(sheetContext, size: 22)),
              const SizedBox(height: 10),
              Text(
                body,
                style: OledText.ui(
                  sheetContext,
                  size: 15,
                  weight: FontWeight.w400,
                  color: t.ink2,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              OledButton(
                label: confirmLabel,
                danger: danger,
                filled: !danger,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
              const SizedBox(height: 10),
              OledButton(
                label: cancel,
                filled: false,
                onPressed: () => Navigator.pop(sheetContext, false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
