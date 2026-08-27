import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/ui/layout/pane_layout_provider.dart';

void main() {
  group('PaneLayout drag', () {
    test('live sidebar drag follows width without collapsing', () {
      const current = PaneLayout(sidebarWidth: 250);
      final next = PaneLayout.applySidebarDragLive(current, 120);
      expect(next.sidebarCollapsed, isFalse);
      expect(next.sidebarWidth, 120);
      expect(next.visibleSidebarWidth, 120);
    });

    test('commit collapses sidebar only after release below threshold', () {
      const dragged = PaneLayout(sidebarWidth: 120);
      final next = PaneLayout.commitSidebarDrag(dragged);
      expect(next.sidebarCollapsed, isTrue);
      expect(next.visibleSidebarWidth, PaneLayout.sidebarRail);
    });

    test('live drag from collapsed expands and tracks width', () {
      const current = PaneLayout(sidebarCollapsed: true, sidebarWidth: 250);
      final next = PaneLayout.applySidebarDragLive(current, 200);
      expect(next.sidebarCollapsed, isFalse);
      expect(next.sidebarWidth, 200);
      expect(next.visibleSidebarWidth, 200);
    });

    test('commit clamps inspector to min when released above collapse', () {
      const dragged = PaneLayout(inspectorWidth: 200);
      final next = PaneLayout.commitInspectorDrag(dragged);
      expect(next.inspectorCollapsed, isFalse);
      expect(next.inspectorWidth, PaneLayout.inspectorMin);
    });

    test('commit collapses inspector below threshold', () {
      const dragged = PaneLayout(inspectorWidth: 160);
      final next = PaneLayout.commitInspectorDrag(dragged);
      expect(next.inspectorCollapsed, isTrue);
      expect(next.visibleInspectorWidth, PaneLayout.inspectorRail);
    });
  });
}
