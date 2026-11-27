import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/providers/settings_provider.dart';

/// The Espace's widgets: what they are, their size, their order, saved in
/// SharedPreferences under [kPorcelaineWorkspaceKey].

const kPorcelaineWorkspaceKey = 'porcelaine_workspace_v1';

enum PWidgetType { active, paste, speed, storage, recent, queue }

/// Small 1×1, medium 2×1, large 2×2 grid cells.
enum PWidgetSize {
  small(1, 1),
  medium(2, 1),
  large(2, 2);

  const PWidgetSize(this.cols, this.rows);

  final int cols;
  final int rows;

  static PWidgetSize fromSpan(int cols, int rows) =>
      rows >= 2 ? large : (cols >= 2 ? medium : small);
}

/// Size a widget gets when added from the catalog.
const kPRecommendedSize = {
  PWidgetType.active: PWidgetSize.large,
  PWidgetType.paste: PWidgetSize.medium,
  PWidgetType.speed: PWidgetSize.small,
  PWidgetType.storage: PWidgetSize.small,
  PWidgetType.recent: PWidgetSize.medium,
  PWidgetType.queue: PWidgetSize.medium,
};

class PWidget {
  const PWidget(this.id, this.type, this.size);

  final String id;
  final PWidgetType type;
  final PWidgetSize size;

  PWidget withSize(PWidgetSize s) => PWidget(id, type, s);

  Map<String, String> toJson() => {
    'id': id,
    'type': type.name,
    'size': size.name,
  };
}

const kPDefaultWorkspace = [
  PWidget('w-active', PWidgetType.active, PWidgetSize.large),
  PWidget('w-paste', PWidgetType.paste, PWidgetSize.medium),
  PWidget('w-speed', PWidgetType.speed, PWidgetSize.small),
  PWidget('w-storage', PWidgetType.storage, PWidgetSize.small),
  PWidget('w-recent', PWidgetType.recent, PWidgetSize.medium),
];

/// Reads a saved layout; null when anything in it is off (unknown type or
/// size, missing or duplicate id, a type twice), so a bad value never
/// breaks the page.
List<PWidget>? decodeWorkspace(String? raw) {
  if (raw == null) return null;
  try {
    final list = jsonDecode(raw);
    if (list is! List) return null;
    final out = <PWidget>[];
    final ids = <String>{};
    final types = <PWidgetType>{};
    for (final entry in list) {
      if (entry is! Map) return null;
      final id = entry['id'];
      final type = PWidgetType.values.asNameMap()[entry['type']];
      final size = PWidgetSize.values.asNameMap()[entry['size']];
      if (id is! String || id.isEmpty || type == null || size == null) {
        return null;
      }
      if (!ids.add(id) || !types.add(type)) return null;
      out.add(PWidget(id, type, size));
    }
    return out;
  } catch (_) {
    return null;
  }
}

class PWorkspaceState {
  const PWorkspaceState({required this.widgets, this.editing = false});

  final List<PWidget> widgets;
  final bool editing;

  PWorkspaceState copyWith({List<PWidget>? widgets, bool? editing}) =>
      PWorkspaceState(
        widgets: widgets ?? this.widgets,
        editing: editing ?? this.editing,
      );
}

class PWorkspaceNotifier extends StateNotifier<PWorkspaceState> {
  PWorkspaceNotifier()
    : super(
        PWorkspaceState(
          widgets:
              decodeWorkspace(prefs.getString(kPorcelaineWorkspaceKey)) ??
              kPDefaultWorkspace,
        ),
      );

  void save() {
    prefs.setString(
      kPorcelaineWorkspaceKey,
      jsonEncode([for (final w in state.widgets) w.toJson()]),
    );
  }

  void _commit(List<PWidget> widgets, {bool persist = true}) {
    state = state.copyWith(widgets: widgets);
    if (persist) save();
  }

  void setEditing(bool value) => state = state.copyWith(editing: value);

  void setSize(String id, PWidgetSize size, {bool persist = true}) {
    final list = state.widgets;
    final i = list.indexWhere((w) => w.id == id);
    if (i < 0 || list[i].size == size) {
      if (persist) save();
      return;
    }
    _commit([
      for (final w in list) w.id == id ? w.withSize(size) : w,
    ], persist: persist);
  }

  /// Moves [id] to index [to]; no-op when out of range.
  void move(String id, int to, {bool persist = true}) {
    final list = [...state.widgets];
    final from = list.indexWhere((w) => w.id == id);
    if (from < 0 || to < 0 || to >= list.length || from == to) return;
    list.insert(to, list.removeAt(from));
    _commit(list, persist: persist);
  }

  /// Removes [id]; returns it and where it was, for the undo toast.
  (PWidget, int)? remove(String id) {
    final list = [...state.widgets];
    final i = list.indexWhere((w) => w.id == id);
    if (i < 0) return null;
    final removed = list.removeAt(i);
    _commit(list);
    return (removed, i);
  }

  void restore(PWidget widget, int index) {
    if (state.widgets.any((w) => w.type == widget.type)) return;
    final list = [...state.widgets];
    list.insert(index.clamp(0, list.length), widget);
    _commit(list);
  }

  /// Adds [type] at the end at its recommended size; returns its id.
  String? add(PWidgetType type) {
    if (state.widgets.any((w) => w.type == type)) return null;
    final id = '${type.name}-${DateTime.now().microsecondsSinceEpoch}';
    _commit([...state.widgets, PWidget(id, type, kPRecommendedSize[type]!)]);
    return id;
  }

  void reset() => _commit(kPDefaultWorkspace);
}

final porcelaineWorkspaceProvider =
    StateNotifierProvider<PWorkspaceNotifier, PWorkspaceState>(
      (ref) => PWorkspaceNotifier(),
    );

/// True while the Espace shows the whole library instead of its widgets.
final porcelaineLibraryOpenProvider = StateProvider<bool>((ref) => false);

/// Asks the Espace to open its « Ajouter un widget » sheet (the dock's
/// button lives in the chrome, the sheet needs the page).
final porcelaineCatalogRequestProvider = StateProvider<int>((ref) => 0);

/// Where each widget sits on a [cols]-wide grid, CSS `grid-auto-flow:
/// dense`: every card takes the first free cell from the top-left.
List<(int col, int row)> packWorkspace(
  List<PWidgetSize> sizes,
  int cols, {
  int extraSmall = 0,
}) {
  final taken = <int>{};
  bool free(int c, int r, int w, int h) {
    if (c + w > cols) return false;
    for (var y = r; y < r + h; y++) {
      for (var x = c; x < c + w; x++) {
        if (taken.contains(y * cols + x)) return false;
      }
    }
    return true;
  }

  final out = <(int, int)>[];
  for (final s in [...sizes, for (var i = 0; i < extraSmall; i++) null]) {
    final w = (s?.cols ?? 1).clamp(1, cols);
    final h = s?.rows ?? 1;
    for (var r = 0; ; r++) {
      var placed = false;
      for (var c = 0; c < cols; c++) {
        if (free(c, r, w, h)) {
          for (var y = r; y < r + h; y++) {
            for (var x = c; x < c + w; x++) {
              taken.add(y * cols + x);
            }
          }
          out.add((c, r));
          placed = true;
          break;
        }
      }
      if (placed) break;
    }
  }
  return out;
}
