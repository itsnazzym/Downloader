import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/components/app_toast.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/download/download_url_policy.dart';
import 'package:modern_downloader/core/providers/settings_provider.dart';
import 'package:modern_downloader/core/utils/download_url_validator.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

/// BottomSheet component replacing the desktop AddDownloadDialog on mobile devices.
/// Supports 1-tap clipboard auto-detection, quality presets, and safe area handling.
class MobileAddDownloadSheet extends ConsumerStatefulWidget {
  final String? initialUrl;
  final String? initialCookies;
  final String? userAgent;

  const MobileAddDownloadSheet({
    super.key,
    this.initialUrl,
    this.initialCookies,
    this.userAgent,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialUrl,
    String? initialCookies,
    String? userAgent,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileAddDownloadSheet(
        initialUrl: initialUrl,
        initialCookies: initialCookies,
        userAgent: userAgent,
      ),
    );
  }

  @override
  ConsumerState<MobileAddDownloadSheet> createState() =>
      _MobileAddDownloadSheetState();
}

class _MobileAddDownloadSheetState
    extends ConsumerState<MobileAddDownloadSheet> {
  late final TextEditingController _urlController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _audioOnly = false;
  String _selectedQuality = 'best'; // 'best', '1080', '720', 'worst'
  String? _detectedClipboardUrl;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty && DownloadUrlValidator.isValidHttpUrl(text)) {
        if (text != _urlController.text && mounted) {
          setState(() {
            _detectedClipboardUrl = text;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    if (!DownloadUrlValidator.isValidHttpUrl(url)) {
      AppToast.showError(context, 'Veuillez saisir une URL valide.');
      return;
    }

    final settings = ref.read(settingsProvider);
    if (!DownloadUrlPolicy.isAllowed(
      url,
      includeAdult: settings.adultSitesEnabled,
    )) {
      AppToast.showError(
        context,
        'URL non supportée ou domaine restreint.',
      );
      return;
    }

    setState(() => _isLoading = true);
    await HapticFeedback.mediumImpact();

    try {
      await ref.read(downloadListProvider.notifier).startDownload(
            url,
            rawCookies: widget.initialCookies,
            userAgent: widget.userAgent,
            cookiesFilePath: settings.cookiesFilePath,
            organizeBySite: settings.organizeBySite,
            organizeByCreator: settings.organizeByCreator,
            audioOnly: _audioOnly,
            preferredQuality: _selectedQuality,
          );

      if (mounted) {
        AppToast.showSuccess(context, context.l10n.downloadStarted);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Erreur : $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.borderSubtle, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const Gap(12),

              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_link_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const Gap(10),
                  Text(
                    l10n.newDownload,
                    style: AppTypography.h2.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const Gap(12),

              // Clipboard auto-detect badge
              if (_detectedClipboardUrl != null) ...[
                Material(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _urlController.text = _detectedClipboardUrl!;
                      setState(() => _detectedClipboardUrl = null);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.content_paste_go_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              'Coller le lien : ${_detectedClipboardUrl!}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Gap(4),
                          Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(12),
              ],

              // URL Input
              Form(
                key: _formKey,
                child: TextField(
                  controller: _urlController,
                  autofocus: widget.initialUrl == null,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Collez le lien de la vidéo ou du média ici...',
                    hintStyle: TextStyle(
                      color: colors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: colors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                    suffixIcon: _urlController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _urlController.clear();
                              setState(() {});
                            },
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.content_paste_rounded,
                              size: 18,
                            ),
                            tooltip: 'Coller',
                            onPressed: () async {
                              final d =
                                  await Clipboard.getData(Clipboard.kTextPlain);
                              if (d?.text != null) {
                                _urlController.text = d!.text!.trim();
                                setState(() {});
                              }
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ),

              const Gap(14),

              // Format / Quality Presets
              Text(
                'Options de téléchargement',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              const Gap(8),

              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Vidéo (Meilleure)'),
                    selected: !_audioOnly && _selectedQuality == 'best',
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _audioOnly = false;
                          _selectedQuality = 'best';
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('1080p'),
                    selected: !_audioOnly && _selectedQuality == '1080',
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _audioOnly = false;
                          _selectedQuality = '1080';
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Audio seul (MP3)'),
                    selected: _audioOnly,
                    onSelected: (val) {
                      setState(() {
                        _audioOnly = val;
                      });
                    },
                  ),
                ],
              ),

              const Gap(20),

              // Start Download CTA
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    _isLoading ? 'Démarrage...' : 'Télécharger maintenant',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
