import 'package:tapload/core/design_system/design_skin.dart';

import 'studio_home.dart';
import 'studio_settings.dart';
import 'studio_widgets.dart';

/// How Studio draws the shared library rows, settings tiles and toggles (see
/// [DesignSkin]).
const studioSkin = DesignSkin(
  row: studioRow,
  sectionTitle: studioSectionTitle,
  switchTile: studioSwitchTile,
  sliderTile: studioSliderTile,
  dropdownTile: studioDropdownTile,
  actionTile: studioActionTile,
  statusTile: studioStatusTile,
  toggle: studioToggle,
);
