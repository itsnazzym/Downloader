import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/plugins/feature_catalog.dart';
import '../core/plugins/feature_activation.dart';
import '../core/providers/settings_provider.dart';
import '../core/services/download_stats_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_presets.dart';
import '../core/ui/app_shell.dart';
import '../core/ui/settings/plugins_settings_view.dart';
import '../features/archive/presentation/providers/tiktok_archive_provider.dart';
import '../features/archive/presentation/views/tiktok_archive_view.dart';
import '../features/downloader/data/downloader_data_providers.dart';
import '../features/downloader/presentation/providers/filtered_downloads_provider.dart';
import '../features/downloader/presentation/views/download_view.dart';
import '../features/stats/presentation/views/stats_view.dart';
import '../features/transfer/presentation/transfer_controller.dart';
import '../features/transfer/presentation/transfer_view.dart';
import '../l10n/app_localizations.dart';
import 'showcase_data.dart';
import 'showcase_mode.dart';
import 'showcase_transfer_controller.dart';

/// Production page widgets, with every data source replaced by demo state.
class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({
    super.key,
    required this.catalog,
    this.initialScreen = 'library',
    this.initialTheme = 'ios',
  });

  final FeatureCatalog catalog;
  final String initialScreen;
  final String initialTheme;

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  late ThemePreset _theme = ThemePresets.getById(widget.initialTheme);
  static const screens = {
    'library',
    'downloads',
    'archive',
    'stats',
    'transfer',
    'plugins',
  };

  late final GoRouter _router = GoRouter(
    initialLocation:
        '/${screens.contains(widget.initialScreen) ? widget.initialScreen : 'library'}',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _ShowcaseShell(
          path: state.uri.path,
          theme: _theme,
          onThemeChanged: (theme) => setState(() => _theme = theme),
          child: child,
        ),
        routes: [
          GoRoute(path: '/library', builder: (_, _) => const DownloadView()),
          GoRoute(path: '/downloads', builder: (_, _) => const DownloadView()),
          GoRoute(
            path: '/archive',
            builder: (_, _) => const TikTokArchiveView(),
          ),
          GoRoute(path: '/stats', builder: (_, _) => const StatsView()),
          GoRoute(path: '/transfer', builder: (_, _) => const TransferView()),
          GoRoute(
            path: '/plugins',
            builder: (_, _) => const PluginsSettingsView(),
          ),
          GoRoute(
            path: '/settings/plugins',
            builder: (_, _) => const PluginsSettingsView(),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      showcaseModeProvider.overrideWithValue(true),
      featureCatalogProvider.overrideWithValue(widget.catalog),
      featureActivationProvider.overrideWith(
        (ref) => FeatureActivationController(
          preferences: prefs,
          catalog: widget.catalog,
        ),
      ),
      downloaderRepositoryProvider.overrideWith(
        (ref) => ShowcaseDownloaderRepository(),
      ),
      persistenceServiceProvider.overrideWith(
        (ref) => ShowcasePersistenceService(),
      ),
      downloadStatsProvider.overrideWith((ref) => ShowcaseStatsNotifier()),
      tikTokArchiveRepositoryProvider.overrideWith(
        (ref) => ShowcaseArchiveRepository(),
      ),
      transferControllerProvider.overrideWith(
        (ref) => ShowcaseTransferController(ref),
      ),
      downloadViewModeProvider.overrideWith(
        (ref) => widget.initialScreen == 'library'
            ? DownloadViewMode.detailed
            : DownloadViewMode.list,
      ),
      downloadStatusFilterProvider.overrideWith(
        (ref) => widget.initialScreen == 'library'
            ? DownloadStatusFilter.completed
            : DownloadStatusFilter.all,
      ),
      selectedDownloadIdProvider.overrideWith(
        (ref) => widget.initialScreen == 'downloads'
            ? 'showcase-sintel-remaster'
            : null,
      ),
    ],
    child: MaterialApp.router(
      title: 'TapLoad — mode démo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromPalette(
        _theme,
        Brightness.dark,
        useGoogleFonts: false,
      ),
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    ),
  );
}

class _ShowcaseShell extends ConsumerWidget {
  const _ShowcaseShell({
    required this.path,
    required this.theme,
    required this.onThemeChanged,
    required this.child,
  });

  final String path;
  final ThemePreset theme;
  final ValueChanged<ThemePreset> onThemeChanged;
  final Widget child;

  static const navigation = [
    ('library', 'Bibliothèque', Icons.video_library_outlined),
    ('downloads', 'Téléchargements', Icons.download_outlined),
    ('archive', 'Archives TikTok', Icons.archive_outlined),
    ('stats', 'Statistiques', Icons.bar_chart_outlined),
    ('transfer', 'Transfert', Icons.devices_outlined),
    ('plugins', 'Plugins', Icons.extension_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: theme.background,
    body: Column(
      children: [
        const AppTitleBar(),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 244,
                padding: const EdgeInsets.fromLTRB(12, 25, 12, 18),
                decoration: BoxDecoration(
                  color: theme.surface.withValues(alpha: .65),
                  border: Border(right: BorderSide(color: theme.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 0, 19),
                      child: Row(
                        children: [
                          Icon(
                            Icons.download_rounded,
                            color: theme.primary,
                            size: 23,
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Text(
                              'TapLoad',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 6, 0, 11),
                      child: Text(
                        'BIBLIOTHÈQUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                    for (final (slug, label, icon) in navigation)
                      _navItem(context, ref, slug, label, icon),
                    const Spacer(),
                    Divider(color: theme.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 8, 2),
                      child: Text(
                        'MODE DÉMO\nDonnées temporaires · aucun fichier personnel',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 10,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(top: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 15, color: theme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aperçu Windows · médias libres · actions simulées',
                  style: TextStyle(fontSize: 10, color: theme.textSecondary),
                ),
              ),
              Text(
                'Thème',
                style: TextStyle(fontSize: 11, color: theme.textSecondary),
              ),
              const SizedBox(width: 9),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: theme.id,
                  isDense: true,
                  items: [
                    for (final preset in ThemePresets.all)
                      DropdownMenuItem(
                        value: preset.id,
                        child: Text(
                          preset.name,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) onThemeChanged(ThemePresets.getById(id));
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _navItem(
    BuildContext context,
    WidgetRef ref,
    String slug,
    String label,
    IconData icon,
  ) {
    final active =
        path == '/$slug' || (slug == 'plugins' && path == '/settings/plugins');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active
            ? theme.primary.withValues(alpha: .23)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (slug == 'library' || slug == 'downloads') {
              ref
                  .read(downloadViewModeProvider.notifier)
                  .state = slug == 'library'
                  ? DownloadViewMode.detailed
                  : DownloadViewMode.list;
              ref
                  .read(downloadStatusFilterProvider.notifier)
                  .state = slug == 'library'
                  ? DownloadStatusFilter.completed
                  : DownloadStatusFilter.all;
              ref.read(downloadSearchQueryProvider.notifier).state = '';
            }
            context.go('/$slug');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? theme.primary : theme.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? theme.textPrimary : theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
