import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:tapload/core/design_system/components/app_toast.dart';
import 'package:tapload/core/download/download_url_policy.dart';
import 'package:tapload/core/providers/settings_provider.dart';
import 'package:tapload/core/ui/mobile/oled/oled_kit.dart';
import 'package:tapload/core/utils/download_url_validator.dart';
import 'package:tapload/features/downloader/presentation/providers/downloader_provider.dart';
import 'package:tapload/features/downloader/presentation/views/mobile/media_probe.dart';
import 'package:tapload/l10n/app_localizations.dart';
import 'package:tapload/l10n/l10n_ext.dart';

/// Full-height bottom sheet used on mobile to add a download.
/// Supports 1-tap clipboard auto-detection, quality choices and safe area
/// handling.
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

enum _QualityKind { best, hd1080, hd720, sd480, audio }

/// One selectable quality in the format list.
class _QualityOption {
  const _QualityOption({
    required this.value,
    required this.kind,
    required this.readout,
    required this.unit,
  });

  /// Value passed as `preferredQuality` ('best', '1080', ...).
  final String value;

  /// Identifies the localized title/detail resolved at build time.
  final _QualityKind kind;

  /// Hero text shown in the bottom bar (null for 'best': localized "Max").
  final String? readout;
  final String unit;

  String title(AppLocalizations l10n) => switch (kind) {
    _QualityKind.best => l10n.bestQuality,
    _QualityKind.hd1080 => '1080p',
    _QualityKind.hd720 => '720p',
    _QualityKind.sd480 => '480p',
    _QualityKind.audio => 'MP3',
  };

  String detail(AppLocalizations l10n) => switch (kind) {
    _QualityKind.best => l10n.addSheetDetailBest,
    _QualityKind.hd1080 => l10n.addSheetDetail1080,
    _QualityKind.hd720 => l10n.addSheetDetail720,
    _QualityKind.sd480 => l10n.addSheetDetail480,
    _QualityKind.audio => l10n.addSheetDetailAudio,
  };

  String readoutText(AppLocalizations l10n) =>
      kind == _QualityKind.best ? l10n.addSheetReadoutMax : readout!;
}

const List<_QualityOption> _videoOptions = [
  _QualityOption(
    value: 'best',
    kind: _QualityKind.best,
    readout: null,
    unit: '',
  ),
  _QualityOption(
    value: '1080',
    kind: _QualityKind.hd1080,
    readout: '1080',
    unit: 'p',
  ),
  _QualityOption(
    value: '720',
    kind: _QualityKind.hd720,
    readout: '720',
    unit: 'p',
  ),
  _QualityOption(
    value: '480',
    kind: _QualityKind.sd480,
    readout: '480',
    unit: 'p',
  ),
];

const _QualityOption _audioOption = _QualityOption(
  value: 'best',
  kind: _QualityKind.audio,
  readout: 'MP3',
  unit: '',
);

class _MobileAddDownloadSheetState
    extends ConsumerState<MobileAddDownloadSheet> {
  late final TextEditingController _urlController;
  bool _isLoading = false;
  bool _audioOnly = false;
  String _selectedQuality = 'best'; // 'best', '1080', '720', '480'
  late bool _useBrowserSession;
  String? _detectedClipboardUrl;

  // Media preview and size estimates, loaded once the link looks valid.
  MediaProbe? _probe;
  bool _probing = false;
  bool _probeFailed = false;
  Timer? _probeTimer;
  int _probeToken = 0;
  String _probedUrl = '';

  bool get _hasBrowserSession =>
      widget.initialCookies != null && widget.initialCookies!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _urlController.addListener(_scheduleProbe);
    _useBrowserSession = _hasBrowserSession;
    _checkClipboard();
    _scheduleProbe();
  }

  void _scheduleProbe() {
    final url = _urlController.text.trim();
    if (url == _probedUrl) return;
    _probeTimer?.cancel();
    _probeToken++;
    _probedUrl = url;
    final valid = DownloadUrlValidator.isValidHttpUrl(url);
    if (!valid) {
      if (_probe != null || _probing || _probeFailed) {
        setState(() {
          _probe = null;
          _probing = false;
          _probeFailed = false;
        });
      }
      return;
    }
    final token = _probeToken;
    _probeTimer = Timer(
      const Duration(milliseconds: 650),
      () => _runProbe(url, token),
    );
  }

  Future<void> _runProbe(String url, int token) async {
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    if (!DownloadUrlPolicy.isAllowed(
      url,
      includeAdult: settings.adultSitesEnabled,
    )) {
      return;
    }
    setState(() {
      _probing = true;
      _probeFailed = false;
    });
    try {
      final metadata = await ref
          .read(downloaderRepositoryProvider)
          .fetchMetadata(
            url,
            cookies: _useBrowserSession ? widget.initialCookies : null,
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted || token != _probeToken) return;
      final probe = MediaProbe.fromMetadata(
        metadata,
        untitledTitle: context.l10n.addSheetUntitledMedia,
      );
      setState(() {
        _probe = probe;
        _probing = false;
        // Drop a choice the source cannot serve.
        final q = int.tryParse(_selectedQuality);
        if (q != null && !probe.offers(q)) _selectedQuality = 'best';
      });
    } catch (_) {
      if (!mounted || token != _probeToken) return;
      setState(() {
        _probe = null;
        _probing = false;
        _probeFailed = true;
      });
    }
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
    _probeTimer?.cancel();
    _urlController.removeListener(_scheduleProbe);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    if (!DownloadUrlValidator.isValidHttpUrl(url)) {
      AppToast.showError(context, context.l10n.addSheetInvalidUrl);
      return;
    }

    final settings = ref.read(settingsProvider);
    if (!DownloadUrlPolicy.isAllowed(
      url,
      includeAdult: settings.adultSitesEnabled,
    )) {
      AppToast.showError(context, context.l10n.addSheetUnsupportedUrl);
      return;
    }

    setState(() => _isLoading = true);
    await HapticFeedback.mediumImpact();

    try {
      await ref
          .read(downloadListProvider.notifier)
          .startDownload(
            url,
            rawCookies: _useBrowserSession ? widget.initialCookies : null,
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
        AppToast.showError(context, context.l10n.addSheetError('$e'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _QualityOption get _currentOption {
    if (_audioOnly) return _audioOption;
    for (final option in _videoOptions) {
      if (option.value == _selectedQuality) return option;
    }
    return _videoOptions.first;
  }

  @override
  Widget build(BuildContext context) {
    final t = OledTokens.of(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.94;
    final options = _audioOnly
        ? const [_audioOption]
        : [
            for (final o in _videoOptions)
              if (o.value == 'best' ||
                  (_probe?.offers(int.parse(o.value)) ?? true))
                o,
          ];
    final current = _currentOption;
    final approxSize = formatApproxSize(
      _probe?.estimateBytes(_selectedQuality, audioOnly: _audioOnly),
      kb: l10n.sizeUnitKb,
      mb: l10n.sizeUnitMb,
      gb: l10n.sizeUnitGb,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
                child: Row(
                  children: [
                    OledIconButton(
                      icon: Icons.close_rounded,
                      tooltip: l10n.close,
                      outlined: false,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Gap(4),
                    Expanded(
                      child: Text(
                        l10n.addSheetTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OledText.ui(
                          context,
                          size: 20,
                          weight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Clipboard auto-detect
                      if (_detectedClipboardUrl != null) ...[
                        OledCard(
                          radius: 14,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          onTap: () {
                            _urlController.text = _detectedClipboardUrl!;
                            setState(() => _detectedClipboardUrl = null);
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.content_paste_go_rounded,
                                size: 18,
                                color: t.ink,
                              ),
                              const Gap(10),
                              Expanded(
                                child: Text(
                                  l10n.addSheetPasteCopiedLink(
                                    _detectedClipboardUrl!,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OledText.ui(
                                    context,
                                    size: 13,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(12),
                      ],

                      // URL input
                      _buildUrlField(context, t),

                      if (_probing || _probe != null || _probeFailed) ...[
                        const Gap(12),
                        _buildPreview(context, t),
                      ],

                      const Gap(14),

                      // Video / audio
                      OledSegmented<bool>(
                        options: {
                          false: l10n.addSheetModeVideo,
                          true: l10n.addSheetModeAudioOnly,
                        },
                        value: _audioOnly,
                        onChanged: (value) =>
                            setState(() => _audioOnly = value),
                      ),

                      const Gap(10),

                      // Format list
                      for (final option in options) ...[
                        _buildFormatRow(
                          context,
                          t,
                          option,
                          _audioOnly || option.value == _selectedQuality,
                        ),
                        const Gap(6),
                      ],

                      // Options
                      if (_hasBrowserSession) ...[
                        const Gap(6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OledChip(
                              label: l10n.addSheetBrowserSession,
                              selected: _useBrowserSession,
                              onTap: () => setState(
                                () => _useBrowserSession = !_useBrowserSession,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom bar
              DecoratedBox(
                decoration: BoxDecoration(
                  color: t.bg,
                  border: Border(top: BorderSide(color: t.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                approxSize == null
                                    ? l10n.addSheetQualityChosen
                                    : l10n.addSheetQualityChosenWithSize(
                                        approxSize,
                                      ),
                                style: OledText.ui(
                                  context,
                                  size: 12,
                                  color: t.ink2,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Flexible(
                                    child: Text(
                                      current.readoutText(l10n),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OledText.dot(context, size: 40),
                                    ),
                                  ),
                                  if (current.unit.isNotEmpty) ...[
                                    const Gap(5),
                                    Text(
                                      current.unit,
                                      style: OledText.ui(
                                        context,
                                        size: 14,
                                        weight: FontWeight.w600,
                                        color: t.ink2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Gap(12),
                        OledButton(
                          label: _isLoading
                              ? l10n.addSheetStarting
                              : l10n.addSheetDownload,
                          onPressed: _isLoading ? null : _submit,
                          expand: false,
                          height: 58,
                        ),
                      ],
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

  Widget _buildPreview(BuildContext context, OledTokens t) {
    final probe = _probe;
    final duration = probe?.durationSeconds;
    return OledCard(
      radius: 16,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          OledThumb(
            url: probe?.thumbnail,
            width: 96,
            height: 54,
            radius: 10,
            badge: duration != null && duration > 0
                ? formatClock(duration)
                : null,
          ),
          const Gap(12),
          Expanded(
            child: probe == null
                ? Text(
                    _probeFailed
                        ? context.l10n.addSheetPreviewUnavailable
                        : context.l10n.addSheetAnalyzing,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: OledText.ui(context, size: 13, color: t.ink2),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        probe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: OledText.ui(
                          context,
                          size: 14,
                          weight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if (probe.uploader != null && probe.uploader!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            probe.uploader!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OledText.ui(
                              context,
                              size: 12,
                              color: t.ink2,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlField(BuildContext context, OledTokens t) {
    final hasText = _urlController.text.trim().isNotEmpty;
    final isValid =
        hasText &&
        DownloadUrlValidator.isValidHttpUrl(_urlController.text.trim());
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.lineStrong),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              autofocus: widget.initialUrl == null,
              cursorColor: t.ink,
              style: OledText.ui(context, size: 15),
              decoration: InputDecoration(
                hintText: context.l10n.addSheetUrlHint,
                hintStyle: OledText.ui(context, size: 15, color: t.ink3),
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (isValid) ...[
            const Gap(8),
            Semantics(
              label: context.l10n.addSheetValidLink,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 15, color: t.onInk),
              ),
            ),
          ],
          if (hasText)
            OledIconButton(
              icon: Icons.close_rounded,
              tooltip: context.l10n.addSheetClear,
              outlined: false,
              color: t.ink2,
              onPressed: () {
                _urlController.clear();
                setState(() {});
              },
            )
          else
            OledIconButton(
              icon: Icons.content_paste_rounded,
              tooltip: context.l10n.addSheetPaste,
              outlined: false,
              color: t.ink2,
              onPressed: () async {
                final d = await Clipboard.getData(Clipboard.kTextPlain);
                if (d?.text != null) {
                  _urlController.text = d!.text!.trim();
                  if (mounted) setState(() {});
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFormatRow(
    BuildContext context,
    OledTokens t,
    _QualityOption option,
    bool selected,
  ) {
    final l10n = context.l10n;
    final size = formatApproxSize(
      _probe?.estimateBytes(option.value, audioOnly: _audioOnly),
      kb: l10n.sizeUnitKb,
      mb: l10n.sizeUnitMb,
      gb: l10n.sizeUnitGb,
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: OledCard(
        radius: 16,
        highlight: selected,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: _audioOnly
            ? null
            : () => setState(() => _selectedQuality = option.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? t.ink : t.lineStrong,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: t.ink,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.title(l10n),
                      style: OledText.ui(
                        context,
                        size: 17,
                        weight: FontWeight.w600,
                        letterSpacing: -0.17,
                      ),
                    ),
                    Text(
                      option.detail(l10n),
                      style: OledText.ui(context, size: 12, color: t.ink2),
                    ),
                  ],
                ),
              ),
              if (size != null) ...[
                const Gap(8),
                Text(
                  size,
                  style: OledText.ui(
                    context,
                    size: 13,
                    weight: FontWeight.w600,
                    color: selected ? t.ink : t.ink2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
