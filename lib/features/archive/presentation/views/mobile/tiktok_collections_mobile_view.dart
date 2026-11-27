import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tapload/core/design_system/components/app_toast.dart';
import 'package:tapload/core/ui/mobile/back_navigation.dart';
import 'package:tapload/core/ui/mobile/oled/oled_confirm.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';
import 'package:tapload/features/archive/domain/entities/tiktok_archive_catalog.dart';
import 'package:tapload/features/archive/presentation/providers/tiktok_archive_provider.dart';
import 'package:tapload/features/archive/presentation/views/mobile/archive_collection_label.dart';
import 'package:tapload/l10n/l10n_ext.dart';
import 'package:tapload/showcase/showcase_mode.dart';

String _keyOf(TikTokCollectionItem collection) =>
    collection.id ?? collection.name;

/// Phone collection manager: a searchable list, then one screen per
/// collection with its actions. Replaces the desktop manager on phones.
class TikTokCollectionsMobileView extends ConsumerStatefulWidget {
  const TikTokCollectionsMobileView({
    super.key,
    required this.catalog,
    required this.onShowVideos,
  });

  final TikTokArchiveCatalog catalog;

  /// Leaves the manager for the video grid (the collection is already
  /// selected as the filter).
  final VoidCallback onShowVideos;

  @override
  ConsumerState<TikTokCollectionsMobileView> createState() =>
      _TikTokCollectionsMobileViewState();
}

class _TikTokCollectionsMobileViewState
    extends ConsumerState<TikTokCollectionsMobileView> {
  final _search = TextEditingController();
  String _query = '';
  String? _openKey;
  VoidCallback? _unregisterBack;

  @override
  void initState() {
    super.initState();
    _unregisterBack = ref.read(backInterceptorsProvider).register(() {
      if (_openKey == null) return false;
      _close();
      return true;
    });
  }

  @override
  void dispose() {
    _unregisterBack?.call();
    _search.dispose();
    super.dispose();
  }

  TikTokArchiveNotifier get _notifier =>
      ref.read(tikTokArchiveProvider.notifier);

  void _open(TikTokCollectionItem collection) {
    HapticFeedback.selectionClick();
    final key = _keyOf(collection);
    // Selecting it makes the filtered video list the collection's videos.
    _notifier.selectCollection(key);
    setState(() => _openKey = key);
  }

  void _close() {
    _notifier.selectCollection(null);
    setState(() => _openKey = null);
  }

  Future<void> _reset(TikTokCollectionItem collection, int count) async {
    final l10n = context.l10n;
    final label = archiveCollectionLabel(l10n, collection.name);
    final ok = await showOledConfirm(
      context,
      title: l10n.archiveCollResetTitle,
      body: l10n.archiveCollResetBody(count, label),
      confirmLabel: l10n.archiveCollResetConfirm,
    );
    if (!ok || !mounted) return;
    await _notifier.resetCollectionToUnclassified(_keyOf(collection));
    if (mounted) {
      AppToast.showSuccess(context, l10n.archiveCollResetDone(label));
    }
  }

  Future<void> _delete(TikTokCollectionItem collection, int count) async {
    final l10n = context.l10n;
    final label = archiveCollectionLabel(l10n, collection.name);
    final ok = await showOledConfirm(
      context,
      title: l10n.archiveCollDelete,
      body: l10n.archiveCollDeleteBody(count, label),
      confirmLabel: l10n.archiveCollDeleteConfirm,
      danger: true,
    );
    if (!ok || !mounted) return;
    await _notifier.deleteCollection(_keyOf(collection));
    if (!mounted) return;
    setState(() => _openKey = null);
    AppToast.showSuccess(context, l10n.archiveCollDeleteDone(label));
  }

  Future<void> _clearArchive() async {
    final l10n = context.l10n;
    final ok = await showOledConfirm(
      context,
      title: l10n.archiveCollClear,
      body: l10n.archiveCollClearBody,
      confirmLabel: l10n.archiveCollClearConfirm,
      danger: true,
    );
    if (!ok || !mounted) return;
    await _notifier.clearCatalog();
    if (mounted) AppToast.showSuccess(context, l10n.archiveCollClearDone);
  }

  Future<void> _downloadAll(List<TikTokArchiveItem> videos) async {
    AppToast.showInfo(context, context.l10n.archiveMobileBatchStarted);
    await _notifier.downloadBatch(videos, limit: videos.length);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tikTokArchiveProvider);
    final catalog = state.catalog ?? widget.catalog;
    final key = _openKey;
    if (key != null) {
      final collection = catalog.collections
          .where((c) => _keyOf(c) == key)
          .firstOrNull;
      if (collection != null) {
        return _buildDetail(context, state, collection);
      }
    }
    return _buildList(context, catalog);
  }

  Widget _buildList(BuildContext context, TikTokArchiveCatalog catalog) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final query = _query.trim().toLowerCase();
    final collections = catalog.collections.where((c) {
      if (query.isEmpty) return true;
      return archiveCollectionLabel(l10n, c.name).toLowerCase().contains(query);
    }).toList();
    final isShowcase = ref.watch(showcaseModeProvider);

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: color),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          style: OledText.ui(context, size: 14),
          cursorColor: t.ink,
          decoration: InputDecoration(
            hintText: l10n.archiveCollSearch,
            hintStyle: OledText.ui(context, size: 14, color: t.ink3),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: t.ink2),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.archiveMobileClearSearch,
                    icon: Icon(Icons.close_rounded, size: 18, color: t.ink2),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: t.fill,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: border(t.line),
            enabledBorder: border(t.line),
            focusedBorder: border(t.lineStrong),
          ),
        ),
        const SizedBox(height: 16),
        if (collections.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                l10n.archiveCollEmpty,
                style: OledText.ui(context, size: 14, color: t.ink2),
              ),
            ),
          )
        else
          Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: t.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < collections.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
                  _CollectionRow(
                    label: archiveCollectionLabel(l10n, collections[i].name),
                    count: collections[i].videoCount,
                    onTap: () => _open(collections[i]),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 24),
        if (!isShowcase)
          OledButton(
            label: l10n.archiveCollClear,
            filled: false,
            danger: true,
            onPressed: _clearArchive,
          ),
      ],
    );
  }

  Widget _buildDetail(
    BuildContext context,
    TikTokArchiveState state,
    TikTokCollectionItem collection,
  ) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final videos = ref.watch(filteredTikTokVideosProvider);
    final label = archiveCollectionLabel(l10n, collection.name);
    final isShowcase = ref.watch(showcaseModeProvider);
    final canManage =
        !isSystemCollection(collection.name) &&
        videos.isNotEmpty &&
        !isShowcase;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Row(
          children: [
            OledIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: l10n.archiveMobileBackToLibrary,
              onPressed: _close,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OledText.title(context, size: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OledCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${videos.length}', style: OledText.dot(context, size: 56)),
              const SizedBox(height: 8),
              Text(
                l10n.archiveMobileVideoCount(videos.length),
                style: OledText.ui(context, size: 13, color: t.ink2),
              ),
              const SizedBox(height: 18),
              OledButton(
                label: l10n.archiveCollShowVideos,
                onPressed: videos.isEmpty ? null : widget.onShowVideos,
              ),
              const SizedBox(height: 10),
              OledButton(
                label: l10n.archiveCollDownloadAll(videos.length),
                icon: Icons.download_rounded,
                filled: false,
                onPressed:
                    videos.isEmpty || isShowcase || state.isBatchDownloading
                    ? null
                    : () => unawaited(_downloadAll(videos)),
              ),
            ],
          ),
        ),
        if (canManage) ...[
          const SizedBox(height: 24),
          OledButton(
            label: l10n.archiveCollReset,
            filled: false,
            onPressed: () => unawaited(_reset(collection, videos.length)),
          ),
          const SizedBox(height: 10),
          OledButton(
            label: l10n.archiveCollDelete,
            filled: false,
            danger: true,
            onPressed: () => unawaited(_delete(collection, videos.length)),
          ),
        ],
      ],
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OledText.ui(context, size: 15),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$count',
              style: OledText.ui(context, size: 14, color: t.ink2),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: t.ink3),
          ],
        ),
      ),
    );
  }
}
