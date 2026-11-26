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
    this.toggle,
  });

  final Widget Function(BuildContext context, DesignRow row)? row;
  final Widget Function(BuildContext context, SectionTitle tile)? sectionTitle;
  final Widget Function(BuildContext context, SwitchTile tile)? switchTile;
  final Widget Function(BuildContext context, SliderTile tile)? sliderTile;
  final Widget Function(BuildContext context, DropdownTile tile)? dropdownTile;
  final Widget Function(BuildContext context, ActionTile tile)? actionTile;
  final Widget Function(BuildContext context, StatusTile tile)? statusTile;

  /// An on/off switch the shared views draw with fixed colours of their own
  /// (the Plugins list), which a design's theme cannot reach.
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
