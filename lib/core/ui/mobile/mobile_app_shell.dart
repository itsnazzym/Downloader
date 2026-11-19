import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/core/design_system/components/app_toast.dart';
import 'package:modern_downloader/core/plugins/feature_activation.dart';
import 'package:modern_downloader/core/ui/mobile/back_navigation.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_provider.dart';
import 'package:modern_downloader/core/ui/media_player/media_player_view.dart';
import 'package:modern_downloader/core/ui/mobile/oled/oled_kit.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/download_library_counts.dart';
import 'package:modern_downloader/features/downloader/domain/entities/download_item.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/features/downloader/presentation/views/mobile/already_downloaded_sheet.dart';
import 'package:modern_downloader/features/downloader/presentation/views/mobile/mobile_add_download_sheet.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// Android shell: pure black ground with a dot grid, and a docked bottom bar
/// with a central "add" action. Statistics and the TikTok archive are reached
/// from the library header, so they highlight the library tab.
class MobileAppShell extends ConsumerStatefulWidget {
  final Widget child;

  const MobileAppShell({super.key, required this.child});

  @override
  ConsumerState<MobileAppShell> createState() => _MobileAppShellState();
}

class _MobileAppShellState extends ConsumerState<MobileAppShell> {
  final _exit = DoubleBackExit();

  Future<void> _onBack(BuildContext context, String location) async {
    if (ref.read(mediaPlayerProvider).isOpen) {
      unawaited(ref.read(mediaPlayerProvider.notifier).close());
      return;
    }
    // A screen with its own history (web view, inner page) goes first.
    if (await ref.read(backInterceptorsProvider).handle()) return;
    if (!context.mounted) return;
    final target = mobileBackTarget(location);
    if (target != null) {
      context.go(target);
      return;
    }
    if (_exit.press()) {
      await SystemNavigator.pop();
      return;
    }
    AppToast.showInfo(context, context.l10n.backAgainToExit);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    // A download that was already on disk: say so instead of a silent "done".
    ref.listen<DownloadItem?>(alreadyDownloadedProvider, (previous, next) {
      if (next == null) return;
      ref.read(alreadyDownloadedProvider.notifier).state = null;
      unawaited(AlreadyDownloadedSheet.show(context, ref, next));
    });
    final counts = ref.watch(downloadLibraryCountsProvider);
    final location = GoRouterState.of(context).uri.path;
    final features = ref.watch(featureActivationProvider);
    final l10n = context.l10n;

    final tabs = <_NavTab>[
      _NavTab(
        icon: Icons.video_library_outlined,
        selectedIcon: Icons.video_library,
        label: l10n.shellTabLibrary,
        route: '/',
        alsoMatches: const ['/stats', '/archive'],
      ),
      if (features.isEnabledById('x_browser'))
        _NavTab(
          icon: Icons.travel_explore_outlined,
          selectedIcon: Icons.travel_explore,
          label: l10n.shellTabBrowse,
          route: '/browse',
        ),
      if (features.isEnabledById('device_transfer'))
        _NavTab(
          icon: Icons.swap_horiz_rounded,
          selectedIcon: Icons.swap_horiz_rounded,
          label: l10n.shellTabSend,
          route: '/transfer',
        ),
      _NavTab(
        icon: Icons.tune_rounded,
        selectedIcon: Icons.tune_rounded,
        label: l10n.shellTabSettings,
        route: '/settings',
      ),
    ];

    var selected = tabs.indexWhere((tab) => tab.matches(location));
    if (selected < 0) selected = tabs.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_onBack(context, location));
      },
      child: Stack(
        children: [
          OledBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(bottom: false, child: child),
              bottomNavigationBar: _OledNavBar(
                tabs: tabs,
                selected: selected,
                activeCount: counts.active,
                onSelect: (index) => context.go(tabs[index].route),
                onAdd: () => MobileAddDownloadSheet.show(context),
              ),
            ),
          ),
          if (ref.watch(mediaPlayerProvider.select((s) => s.isOpen)))
            const Positioned.fill(child: MediaPlayerView()),
        ],
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
    this.alsoMatches = const [],
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
  final List<String> alsoMatches;

  bool matches(String location) {
    if (route == '/') {
      if (location == '/') return true;
    } else if (location == route || location.startsWith('$route/')) {
      return true;
    }
    for (final extra in alsoMatches) {
      if (location == extra || location.startsWith('$extra/')) return true;
    }
    return false;
  }
}

class _OledNavBar extends StatelessWidget {
  const _OledNavBar({
    required this.tabs,
    required this.selected,
    required this.activeCount,
    required this.onSelect,
    required this.onAdd,
  });

  final List<_NavTab> tabs;
  final int selected;
  final int activeCount;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    // The add action sits in the middle of the tabs.
    final addAt = tabs.length ~/ 2;
    final children = <Widget>[];
    for (var i = 0; i < tabs.length; i++) {
      if (i == addAt) {
        children.add(
          Expanded(
            child: Center(child: _AddButton(onTap: onAdd)),
          ),
        );
      }
      children.add(
        Expanded(
          child: _NavItem(
            tab: tabs[i],
            selected: i == selected,
            badge: tabs[i].route == '/' ? activeCount : 0,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(i);
            },
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: children),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final _NavTab tab;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final fg = selected ? t.onInk : t.ink2;
    Widget icon = Icon(
      selected ? tab.selectedIcon : tab.icon,
      size: 22,
      color: fg,
    );
    if (badge > 0) {
      icon = Badge.count(
        count: badge,
        backgroundColor: OledTokens.live,
        textColor: Colors.white,
        child: icon,
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 52,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? t.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: icon,
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OledText.ui(
                  context,
                  size: 12,
                  weight: FontWeight.w600,
                  color: selected ? t.ink : t.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return Semantics(
      button: true,
      label: context.l10n.newDownload,
      child: Material(
        color: t.ink,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: SizedBox(
            width: 54,
            height: 54,
            child: Icon(Icons.add_rounded, size: 28, color: t.onInk),
          ),
        ),
      ),
    );
  }
}
