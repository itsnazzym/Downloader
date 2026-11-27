import 'package:flutter/material.dart';
import 'package:modern_downloader/core/theme/app_palette.dart';
import 'package:modern_downloader/core/theme/theme_presets.dart';

import 'pastille_kit.dart';

/// Material pieces of a shared view framed by a Pastille page (settings
/// sub-pages, the archive hub, the collections tools, the creator folders)
/// in Pastille's language: espresso cards with a cream ring, pill buttons
/// and fields, round checks, a pastel switch, cream text.
class PastilleScope extends StatelessWidget {
  const PastilleScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final tones = PTones.of(context);
    final p = AppPalette.of(context).preset;
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    );
    final label = WidgetStatePropertyAll(
      pBody(size: 13.5, weight: FontWeight.w700, height: 1.2),
    );
    const pad = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    );
    final ring = pCream.withValues(alpha: 0.08);
    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: c, width: w),
    );
    final theme = base.copyWith(
      extensions: [
        ...base.extensions.values.where((e) => e is! AppPalette),
        AppPalette(
          ThemePreset(
            id: p.id,
            name: p.name,
            primary: tones.butter,
            accent: tones.lav,
            background: pBackground,
            surface: pCard,
            surfaceHighlight: const Color(0xFF2E2A26),
            textPrimary: pCream,
            textSecondary: pMuted,
            textDisabled: pFaint,
            // Opaque: shared views set the border's alpha themselves.
            border: const Color(0xFF34302C),
            borderSubtle: const Color(0xFF2A2724),
            success: tones.sage,
            error: tones.rose,
            warning: tones.butter,
            info: tones.sky,
            inputBackground: const Color(0xFF1E1C1A),
            chrome: p.chrome,
            useMeshBackground: p.useMeshBackground,
            useFloatingDock: p.useFloatingDock,
          ),
        ),
      ],
      cardTheme: CardThemeData(
        color: pCard,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: pCream.withValues(alpha: 0.07)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        iconColor: tones.butter,
        textColor: pCream,
        selectedColor: pInk,
        selectedTileColor: tones.butter,
        titleTextStyle: pBody(
          size: 14.5,
          weight: FontWeight.w700,
          color: pCream,
        ),
        subtitleTextStyle: pBody(
          size: 12.5,
          weight: FontWeight.w500,
          color: pMuted,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? pInk : pCream,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? tones.butter
              : pCream.withValues(alpha: 0.08),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? tones.butter
              : pCream.withValues(alpha: 0.35),
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(2.5),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: pCream.withValues(alpha: 0.5), width: 2),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tones.butter : null,
        ),
        checkColor: const WidgetStatePropertyAll(pInk),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tones.butter : pMuted,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(pill),
          foregroundColor: WidgetStatePropertyAll(tones.butter),
          overlayColor: WidgetStatePropertyAll(pCream.withValues(alpha: 0.06)),
          textStyle: label,
          padding: pad,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(pill),
          backgroundColor: WidgetStatePropertyAll(tones.butter),
          foregroundColor: const WidgetStatePropertyAll(pInk),
          textStyle: label,
          padding: pad,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(pill),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(tones.butter),
          foregroundColor: const WidgetStatePropertyAll(pInk),
          textStyle: label,
          padding: pad,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(pill),
          backgroundColor: WidgetStatePropertyAll(
            pCream.withValues(alpha: 0.08),
          ),
          foregroundColor: const WidgetStatePropertyAll(pCream),
          side: const WidgetStatePropertyAll(BorderSide.none),
          textStyle: label,
          padding: pad,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(pCream),
          backgroundColor: WidgetStatePropertyAll(
            pCream.withValues(alpha: 0.06),
          ),
          shape: const WidgetStatePropertyAll(CircleBorder()),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1C1A),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        hintStyle: pBody(color: pFaint),
        labelStyle: pBody(color: pMuted),
        floatingLabelStyle: pBody(color: tones.butter),
        prefixIconColor: pFaint,
        border: field(pCream.withValues(alpha: 0.1)),
        enabledBorder: field(pCream.withValues(alpha: 0.1)),
        focusedBorder: field(tones.butter, 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: pInkDeep,
        selectedColor: pCream,
        checkmarkColor: pInk,
        side: BorderSide(color: pCream.withValues(alpha: 0.1)),
        shape: pill,
        labelStyle: pBody(size: 13, weight: FontWeight.w700, color: pCream),
        secondaryLabelStyle: pBody(
          size: 13,
          weight: FontWeight.w700,
          color: pInk,
        ),
      ),
      dividerTheme: DividerThemeData(color: ring, thickness: 1.5),
      popupMenuTheme: PopupMenuThemeData(
        color: pCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ring),
        ),
        textStyle: pBody(color: pCream),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tones.butter,
        linearTrackColor: pCream.withValues(alpha: 0.08),
        circularTrackColor: Colors.transparent,
      ),
    );
    return Theme(
      data: theme,
      child: DefaultTextStyle.merge(
        style: pBody(color: pCream),
        child: IconTheme.merge(
          data: const IconThemeData(color: pMuted),
          child: child,
        ),
      ),
    );
  }
}
