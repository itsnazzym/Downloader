import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/riverpod.dart';
import '../../features/downloader/presentation/views/download_view.dart';
import '../ui/app_shell.dart';
import '../ui/settings/general_settings_view.dart';
import '../ui/settings/settings_hub_view.dart';
import '../../features/browser/x_browser_view.dart';
import '../ui/settings/output_settings_view.dart';
import '../ui/settings/advanced_settings_view.dart';
import '../ui/settings/performance_settings_view.dart';
import '../ui/settings/system_settings_view.dart';
import '../ui/settings/appearance_settings_view.dart';
import '../ui/settings/plugins_settings_view.dart';
import '../ui/settings/smart_organizer_settings_view.dart';
import '../ui/stats/stats_view.dart';

// Keys for navigation
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DownloadView()),
          GoRoute(
            path: '/browse',
            builder: (context, state) => const XBrowserView(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsView(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const AdaptiveSettingsHome(),
          ),
          GoRoute(
            path: '/settings/general',
            builder: (context, state) => const GeneralSettingsView(),
          ),
          GoRoute(
            path: '/settings/output',
            builder: (context, state) => const OutputSettingsView(),
          ),
          GoRoute(
            path: '/settings/advanced',
            builder: (context, state) => const AdvancedSettingsView(),
          ),
          GoRoute(
            path: '/settings/performance',
            builder: (context, state) => const PerformanceSettingsView(),
          ),
          GoRoute(
            path: '/settings/system',
            builder: (context, state) => const SystemSettingsView(),
          ),
          GoRoute(
            path: '/settings/appearance',
            builder: (context, state) => const AppearanceSettingsView(),
          ),
          GoRoute(
            path: '/settings/plugins',
            builder: (context, state) => const PluginsSettingsView(),
          ),
          GoRoute(
            path: '/settings/smart_organizer',
            builder: (context, state) => const SmartOrganizerSettingsView(),
          ),
        ],
      ),
    ],
  );
});
