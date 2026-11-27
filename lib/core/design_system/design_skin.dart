import 'package:flutter/widgets.dart';
import 'package:modern_downloader/core/platform/platform_info.dart';
import 'package:modern_downloader/core/theme/design_spec.dart';
import 'package:modern_downloader/core/ui/settings/widgets/settings_tiles.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';

/// One library row as the shared list hands it to a design: the item, its
/// selection and the actions the shared row would offer (retry and delete
/// already ask before removing a file). The context menu, selection and
/// keyboard handling stay shared around what the design draws.
class DesignRow {
  const DesignRow({
    required this.item,
    required this.isSelected,
    required this.grid,
    required this.onTap,
    required this.onRetry,
    required this.onCancel,
  });

  final DownloadItem item;
  final bool isSelected;

  /// Drawn as a grid card rather than a list row.
  final bool grid;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
}

/// How a desktop design draws the shared pieces every page reuses: library
/// rows and settings tiles. A null builder keeps today's look; the shared
/// widget passes itself, so the design reads its title, value and callbacks.
class DesignSkin {
  const DesignSkin({
    this.row,
    this.sectionTitle,
    this.switchTile,
    this.sliderTile,
    this.dropdownTile,
    this.actionTile,
    this.statusTile,
    this.panel,
    this.toggle,
  });

  final Widget Function(BuildContext context, DesignRow row)? row;
  final Widget Function(BuildContext context, SectionTitle tile)? sectionTitle;
  final Widget Function(BuildContext context, SwitchTile tile)? switchTile;
  final Widget Function(BuildContext context, SliderTile tile)? sliderTile;
  final Widget Function(BuildContext context, DropdownTile tile)? dropdownTile;
  final Widget Function(BuildContext context, ActionTile tile)? actionTile;
  final Widget Function(BuildContext context, StatusTile tile)? statusTile;

  /// The surface of a hand-drawn card in a shared view (plugin cards, the
  /// storage chart); receives today's decoration.
  final BoxDecoration Function(BuildContext context, BoxDecoration base)? panel;

  /// An on/off switch a shared view draws outside the tiles (plugins).
  final Widget Function(
    BuildContext context,
    bool value,
    ValueChanged<bool>? onChanged,
  )?
  toggle;

  static final _byId = <String, DesignSkin>{};

  /// Called once at startup by each design (see `registerDesignSkins`).
  static void register(String designId, DesignSkin skin) =>
      _byId[designId] = skin;

  /// The active design's skin on desktop; null on phones and for the
  /// platform looks (OLED, iOS), which keep the shared widgets.
  static DesignSkin? of(BuildContext context) {
    if (PlatformInfo.isMobile || !PlatformInfo.isDesktop) return null;
    return _byId[DesignSpec.of(context).id];
  }
}

/// [base], or the active design's own card surface (see [DesignSkin.panel]).
BoxDecoration designPanel(BuildContext context, BoxDecoration base) =>
    DesignSkin.of(context)?.panel?.call(context, base) ?? base;

/// The active design's own switch, or null to keep the shared one.
Widget? designToggle(
  BuildContext context,
  bool value,
  ValueChanged<bool>? onChanged,
) => DesignSkin.of(context)?.toggle?.call(context, value, onChanged);
