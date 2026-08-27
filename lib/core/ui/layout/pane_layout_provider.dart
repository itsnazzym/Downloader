import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';

class PaneLayout {
  static const double sidebarDefault = 250;
  static const double sidebarMin = 176;
  static const double sidebarMax = 420;
  static const double sidebarRail = 64;
  static const double sidebarCollapseBelow = 140;

  static const double inspectorDefault = 300;
  static const double inspectorMin = 240;
  static const double inspectorMax = 560;
  static const double inspectorRail = 40;
  static const double inspectorCollapseBelow = 180;

  final double sidebarWidth;
  final double inspectorWidth;
  final bool sidebarCollapsed;
  final bool inspectorCollapsed;

  const PaneLayout({
    this.sidebarWidth = sidebarDefault,
    this.inspectorWidth = inspectorDefault,
    this.sidebarCollapsed = false,
    this.inspectorCollapsed = false,
  });

  double get visibleSidebarWidth =>
      sidebarCollapsed ? sidebarRail : sidebarWidth;

  double get visibleInspectorWidth =>
      inspectorCollapsed ? inspectorRail : inspectorWidth;

  PaneLayout copyWith({
    double? sidebarWidth,
    double? inspectorWidth,
    bool? sidebarCollapsed,
    bool? inspectorCollapsed,
  }) {
    return PaneLayout(
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      inspectorWidth: inspectorWidth ?? this.inspectorWidth,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      inspectorCollapsed: inspectorCollapsed ?? this.inspectorCollapsed,
    );
  }

  static double clampSidebar(double width) {
    return width.clamp(sidebarMin, sidebarMax);
  }

  static double clampInspector(double width) {
    return width.clamp(inspectorMin, inspectorMax);
  }

  /// Live sash follow: never snap-collapse, so the handle stays under the pointer.
  static PaneLayout applySidebarDragLive(PaneLayout current, double width) {
    return current.copyWith(
      sidebarCollapsed: false,
      sidebarWidth: width.clamp(sidebarRail, sidebarMax),
    );
  }

  static PaneLayout applyInspectorDragLive(PaneLayout current, double width) {
    return current.copyWith(
      inspectorCollapsed: false,
      inspectorWidth: width.clamp(inspectorRail, inspectorMax),
    );
  }

  /// Snap to rail or to the expanded min only after the pointer is released.
  static PaneLayout commitSidebarDrag(PaneLayout current) {
    if (current.sidebarWidth < sidebarCollapseBelow) {
      return current.copyWith(sidebarCollapsed: true);
    }
    return current.copyWith(
      sidebarCollapsed: false,
      sidebarWidth: clampSidebar(current.sidebarWidth),
    );
  }

  static PaneLayout commitInspectorDrag(PaneLayout current) {
    if (current.inspectorWidth < inspectorCollapseBelow) {
      return current.copyWith(inspectorCollapsed: true);
    }
    return current.copyWith(
      inspectorCollapsed: false,
      inspectorWidth: clampInspector(current.inspectorWidth),
    );
  }
}

final paneResizeActiveProvider = StateProvider<bool>((ref) => false);

const _kSidebarWidth = 'pane_sidebar_width';
const _kInspectorWidth = 'pane_inspector_width';
const _kSidebarCollapsed = 'pane_sidebar_collapsed';
const _kInspectorCollapsed = 'pane_inspector_collapsed';

class PaneLayoutNotifier extends StateNotifier<PaneLayout> {
  PaneLayoutNotifier() : super(const PaneLayout()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    try {
      final storedSidebar = prefs.getDouble(_kSidebarWidth);
      final storedInspector = prefs.getDouble(_kInspectorWidth);
      final storedSidebarCollapsed = prefs.getBool(_kSidebarCollapsed);
      final storedInspectorCollapsed = prefs.getBool(_kInspectorCollapsed);
      state = PaneLayout(
        sidebarWidth: PaneLayout.clampSidebar(
          storedSidebar ?? PaneLayout.sidebarDefault,
        ),
        inspectorWidth: PaneLayout.clampInspector(
          storedInspector ?? PaneLayout.inspectorDefault,
        ),
        sidebarCollapsed: storedSidebarCollapsed ?? false,
        inspectorCollapsed: storedInspectorCollapsed ?? false,
      );
    } on StateError {
      // SharedPreferences not initialized (widget tests).
    }
  }

  void setSidebarWidth(double width) {
    final next = PaneLayout.applySidebarDragLive(state, width);
    if (next.sidebarWidth == state.sidebarWidth &&
        next.sidebarCollapsed == state.sidebarCollapsed) {
      return;
    }
    state = next;
  }

  void setInspectorWidth(double width) {
    final next = PaneLayout.applyInspectorDragLive(state, width);
    if (next.inspectorWidth == state.inspectorWidth &&
        next.inspectorCollapsed == state.inspectorCollapsed) {
      return;
    }
    state = next;
  }

  void commitSidebarDrag() {
    final next = PaneLayout.commitSidebarDrag(state);
    if (next.sidebarWidth == state.sidebarWidth &&
        next.sidebarCollapsed == state.sidebarCollapsed) {
      return;
    }
    state = next;
  }

  void commitInspectorDrag() {
    final next = PaneLayout.commitInspectorDrag(state);
    if (next.inspectorWidth == state.inspectorWidth &&
        next.inspectorCollapsed == state.inspectorCollapsed) {
      return;
    }
    state = next;
  }

  void toggleSidebarCollapsed() {
    if (state.sidebarCollapsed) {
      state = state.copyWith(
        sidebarCollapsed: false,
        sidebarWidth: PaneLayout.clampSidebar(state.sidebarWidth),
      );
      return;
    }
    state = state.copyWith(sidebarCollapsed: true);
  }

  void toggleInspectorCollapsed() {
    if (state.inspectorCollapsed) {
      state = state.copyWith(
        inspectorCollapsed: false,
        inspectorWidth: PaneLayout.clampInspector(state.inspectorWidth),
      );
      return;
    }
    state = state.copyWith(inspectorCollapsed: true);
  }

  void expandSidebar() {
    if (!state.sidebarCollapsed) return;
    state = state.copyWith(
      sidebarCollapsed: false,
      sidebarWidth: PaneLayout.clampSidebar(state.sidebarWidth),
    );
  }

  void expandInspector() {
    if (!state.inspectorCollapsed) return;
    state = state.copyWith(
      inspectorCollapsed: false,
      inspectorWidth: PaneLayout.clampInspector(state.inspectorWidth),
    );
  }

  Future<void> persist() async {
    try {
      final SharedPreferences store = prefs;
      await store.setDouble(_kSidebarWidth, state.sidebarWidth);
      await store.setDouble(_kInspectorWidth, state.inspectorWidth);
      await store.setBool(_kSidebarCollapsed, state.sidebarCollapsed);
      await store.setBool(_kInspectorCollapsed, state.inspectorCollapsed);
    } on StateError {
      // Tests without prefs.
    }
  }
}

final paneLayoutProvider =
    StateNotifierProvider<PaneLayoutNotifier, PaneLayout>((ref) {
      return PaneLayoutNotifier();
    });
