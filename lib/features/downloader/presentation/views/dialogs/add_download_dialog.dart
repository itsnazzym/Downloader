import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/components/app_button.dart';
import 'package:modern_downloader/core/design_system/components/app_text_field.dart';
import 'package:modern_downloader/core/design_system/components/app_toast.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/download/download_url_policy.dart';
import 'package:modern_downloader/core/utils/download_url_validator.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';
import 'package:modern_downloader/core/ui/widgets/animated_input_field.dart';
import 'quality_selection_dialog.dart';

class AddDownloadDialog extends ConsumerStatefulWidget {
  final String? initialUrl;
  final String? initialCookies;
  final String? userAgent;
  const AddDownloadDialog({
    super.key,
    this.initialUrl,
    this.initialCookies,
    this.userAgent,
  });

  @override
  ConsumerState<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends ConsumerState<AddDownloadDialog> {
  late final TextEditingController _urlController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedBrowser; // Default null (None)

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    final formOk = AppColors.of(context).isIosChrome
        ? DownloadUrlValidator.isAcceptableDownloadUrl(url)
        : (_formKey.currentState?.validate() ?? false);
    if (!formOk) {
      if (AppColors.of(context).isIosChrome &&
          DownloadUrlValidator.isValidHttpUrl(url) &&
          !DownloadUrlValidator.isAcceptableDownloadUrl(url)) {
        AppToast.showError(
          context,
          DownloadUrlValidator.isNonMediaPageUrl(url)
              ? context.l10n.unsupportedDownloadUrl
              : context.l10n.xCdnUrlRejected,
        );
      }
      return;
    }
    if (formOk) {
      final settings = ref.read(settingsProvider);
      if (!DownloadUrlPolicy.isAllowed(
        url,
        includeAdult: settings.adultSitesEnabled,
      )) {
        AppToast.showError(
          context,
          'URL non supportée (Discord, hôte inconnu, etc.).',
        );
        return;
      }
      setState(() => _isLoading = true);

      // Check for playlist
      try {
        // Simple heuristic first to avoid delay on obvious non-playlists?
        // No, best to just check if user asks for precision.
        // Actually, let's treat it as potential playlist.
        final repo = ref.read(downloaderRepositoryProvider);
        final items = await repo.fetchPlaylist(url);

        if (!mounted) return;

        if (items.length > 1) {
          // Playlist Detected
          setState(() => _isLoading = false);
          // Show Selection Dialog
          await _showPlaylistSelection(items, url);
          if (mounted) Navigator.of(context).pop();
        } else {
          // Single Video
          final settings = ref.read(settingsProvider);
          String? selectedFormatId;

          if (settings.preferredQuality == 'manual' ||
              settings.preferredQuality == 'manual+') {
            setState(() => _isLoading = true);
            try {
              final metadata = await repo.fetchMetadata(
                url,
                cookies: widget.initialCookies,
              );
              final title = metadata['title'] as String? ?? url;

              bool shouldShowDialog = settings.preferredQuality == 'manual';

              if (!shouldShowDialog && settings.preferredQuality == 'manual+') {
                // Check size (> 500MB)
                final formats = (metadata['formats'] as List? ?? []);
                int maxBytes = 0;
                for (final f in formats) {
                  final size =
                      (f['filesize'] as num? ??
                              f['filesize_approx'] as num? ??
                              0)
                          .toInt();
                  if (size > maxBytes) maxBytes = size;
                }

                if (maxBytes > 500 * 1024 * 1024) {
                  shouldShowDialog = true;
                }
              }

              if (shouldShowDialog) {
                if (!mounted) return;
                selectedFormatId = await showDialog<String>(
                  context: context,
                  builder: (context) =>
                      QualitySelectionDialog(metadata: metadata, title: title),
                );

                // If user cancelled, don't start download
                if (selectedFormatId == null) {
                  setState(() => _isLoading = false);
                  return;
                }
              }
            } catch (e) {
              // Fallback to best if metadata fails
              if (mounted) {
                AppToast.showError(context, context.l10n.failedFetchQuality);
              }
            }
          }

          await ref
              .read(downloadListProvider.notifier)
              .startDownload(
                url,
                rawCookies: widget.initialCookies,
                userAgent: widget.userAgent,
                cookiesFilePath: settings.cookiesFilePath,
                organizeBySite: settings.organizeBySite,
                cookieBrowser: _selectedBrowser,
                videoFormatId: selectedFormatId == 'best'
                    ? null
                    : selectedFormatId,
              );

          if (mounted) {
            AppToast.showSuccess(context, context.l10n.downloadStarted);
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        // Fallback to single download if check fails
        await ref
            .read(downloadListProvider.notifier)
            .startDownload(
              url,
              rawCookies: widget.initialCookies,
              cookieBrowser: _selectedBrowser,
            );
        if (mounted) Navigator.of(context).pop();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPlaylistSelection(
    List<Map<String, dynamic>> items,
    String originalUrl,
  ) async {
    // Map of index -> selected
    // INTELLIGENT SELECTION:
    // If the URL points to a specific video (e.g. v=ID), only select that video by default.
    // Otherwise (playlist URL), select all.
    List<bool> selected;
    String? targetId;

    try {
      if (originalUrl.contains('youtu')) {
        final uri = Uri.parse(originalUrl);
        if (uri.queryParameters.containsKey('v')) {
          targetId = uri.queryParameters['v'];
        }
      }
    } catch (_) {}

    if (targetId != null) {
      // Check if this ID exists in items
      bool found = false;
      selected = List<bool>.filled(items.length, false);
      for (int i = 0; i < items.length; i++) {
        if (items[i]['id'] == targetId) {
          selected[i] = true;
          found = true;
        }
      }
      // If not found (weird?), fallback to all
      if (!found) {
        selected = List<bool>.filled(items.length, true);
      }
    } else {
      selected = List.generate(items.length, (index) => true);
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.l10n.playlistDetected(items.length)),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              for (var i = 0; i < selected.length; i++) {
                                selected[i] = true;
                              }
                            });
                          },
                          child: Text(context.l10n.selectAll),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              for (var i = 0; i < selected.length; i++) {
                                selected[i] = false;
                              }
                            });
                          },
                          child: Text(context.l10n.deselectAll),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final title =
                              item['title'] ??
                              item['url'] ??
                              context.l10n.unknown;
                          return CheckboxListTile(
                            value: selected[index],
                            title: Text(
                              title,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (v) {
                              setDialogState(
                                () => selected[index] = v ?? false,
                              );
                            },
                            dense: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Start selected
                    int count = 0;
                    final notifier = ref.read(downloadListProvider.notifier);
                    for (int i = 0; i < items.length; i++) {
                      if (selected[i]) {
                        final itemUrl = items[i]['url'] as String?;
                        // If no URL (flat playlist sometimes gives id), construct it
                        String finalUrl = itemUrl ?? originalUrl;
                        if (items[i]['id'] != null &&
                            (itemUrl == null || !itemUrl.startsWith('http'))) {
                          // Assume youtube logic if ID present? Or generic
                          // yt-dlp flat playlist usually gives 'url': 'https://...' for generic sites
                          // For youtube it gives id.
                          if (items[i]['ie_key'] == 'Youtube' ||
                              originalUrl.contains('youtu')) {
                            finalUrl =
                                'https://www.youtube.com/watch?v=${items[i]['id']}';
                          } else {
                            // Fallback, use the single entry url if available
                            if (itemUrl != null) finalUrl = itemUrl;
                          }
                        }

                        notifier.startDownload(
                          finalUrl,
                          rawCookies: widget.initialCookies,
                          userAgent: widget.userAgent,
                          cookieBrowser: _selectedBrowser,
                        );
                        count++;
                      }
                    }
                    AppToast.showSuccess(
                      context,
                      context.l10n.startedCountDownloads(count),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    context.l10n.downloadSelected(
                      selected.where((e) => e).length,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      backgroundColor: AppColors.of(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.of(context).border),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.newDownload, style: AppTypography.h3),
              const Gap(AppSpacing.m),
              const Gap(AppSpacing.m),
              AppColors.of(context).isIosChrome
                  ? AnimatedInputField(
                      controller: _urlController,
                      hintText: l10n.pasteUrl,
                      onSubmitted: (_) => _submit(),
                    )
                  : AppTextField(
                      controller: _urlController,
                      hint: l10n.pasteUrl,
                      label: l10n.urlLabel,
                      prefixIcon: Icon(
                        Icons.link,
                        color: AppColors.of(context).textSecondary,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterUrl;
                        }
                        if (!DownloadUrlValidator.isValidHttpUrl(value)) {
                          return l10n.enterValidUrl;
                        }
                        if (DownloadUrlValidator.isNonMediaPageUrl(value)) {
                          return l10n.unsupportedDownloadUrl;
                        }
                        if (!DownloadUrlValidator.isAcceptableDownloadUrl(
                          value,
                        )) {
                          return l10n.xCdnUrlRejected;
                        }
                        return null;
                      },
                      onSubmitted: (_) => _submit(),
                      autofocus: true,
                    ),
              const Gap(AppSpacing.m),
              DropdownButtonFormField<String?>(
                dropdownColor: AppColors.of(context).surface,
                style: AppTypography.body.copyWith(
                  color: AppColors.of(context).textPrimary,
                ),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.of(context).textSecondary,
                ),
                decoration: InputDecoration(
                  labelText: l10n.cookiesFromBrowser,
                  labelStyle: AppTypography.label.copyWith(
                    color: AppColors.of(context).textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.of(context).surface,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mediumBorder,
                    borderSide: BorderSide(color: AppColors.of(context).border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mediumBorder,
                    borderSide: BorderSide(color: AppColors.of(context).border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mediumBorder,
                    borderSide: BorderSide(
                      color: AppColors.of(context).primary,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                initialValue: _selectedBrowser,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      l10n.cookiesNoneDefault,
                      style: AppTypography.body.copyWith(
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'chrome',
                    child: Text(
                      'Google Chrome',
                      style: AppTypography.body.copyWith(
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'firefox',
                    child: Text(
                      'Mozilla Firefox',
                      style: AppTypography.body.copyWith(
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'brave',
                    child: Text(
                      'Brave',
                      style: AppTypography.body.copyWith(
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'edge',
                    child: Text(
                      'Microsoft Edge',
                      style: AppTypography.body.copyWith(
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'opera',
                    child: Text(
                      'Opera',
                      style: AppTypography.body.copyWith(
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'vivaldi',
                    child: Text(
                      'Vivaldi',
                      style: AppTypography.body.copyWith(
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'safari',
                    child: Text(
                      'Safari',
                      style: AppTypography.body.copyWith(
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'chromium',
                    child: Text(
                      'Chromium',
                      style: AppTypography.body.copyWith(
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _selectedBrowser = val);
                },
              ),
              const Gap(AppSpacing.l),
              if (_isLoading)
                const Center(child: LinearProgressIndicator())
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton.ghost(
                      label: l10n.cancel,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Gap(AppSpacing.xs),
                    AppButton.primary(
                      label: l10n.startDownload,
                      icon: Icons.download,
                      onPressed: _submit,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
