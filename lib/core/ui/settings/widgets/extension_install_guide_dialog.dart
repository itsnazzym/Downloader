import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:modern_downloader/core/design_system/components/app_button.dart';
import 'package:modern_downloader/core/design_system/foundation/colors.dart';
import 'package:modern_downloader/core/design_system/foundation/spacing.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/core/services/browser_extension_installer.dart';
import 'package:modern_downloader/l10n/app_localizations.dart';
import 'package:modern_downloader/l10n/l10n_ext.dart';

enum ExtensionInstallFlow {
  chromeInstall,
  chromeZip,
  firefoxInstall,
  firefoxManual,
}

enum _StepPhase { pending, running, done, error }

class _GuideStep {
  _GuideStep({required this.label});

  final String label;
  _StepPhase phase = _StepPhase.pending;
  String? detail;
}

/// Step-by-step guide: download first, then open the browser only on success.
class ExtensionInstallGuideDialog extends StatefulWidget {
  const ExtensionInstallGuideDialog({super.key, required this.flow});

  final ExtensionInstallFlow flow;

  static Future<void> show(BuildContext context, ExtensionInstallFlow flow) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExtensionInstallGuideDialog(flow: flow),
    );
  }

  @override
  State<ExtensionInstallGuideDialog> createState() =>
      _ExtensionInstallGuideDialogState();
}

class _ExtensionInstallGuideDialogState
    extends State<ExtensionInstallGuideDialog> {
  late List<_GuideStep> _steps;
  String? _readyHint;
  bool _success = false;
  int _errorStepIndex = -1;

  @override
  void initState() {
    super.initState();
    _steps = [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final l10n = context.l10n;
    setState(() {
      _steps = _buildStepLabels(l10n);
    });
    await _runFlow();
  }

  List<_GuideStep> _buildStepLabels(AppLocalizations l10n) {
    switch (widget.flow) {
      case ExtensionInstallFlow.chromeInstall:
        return [
          _GuideStep(label: l10n.extensionStepDownload),
          _GuideStep(label: l10n.extensionStepCopyPath),
          _GuideStep(label: l10n.extensionStepOpenBrowser),
        ];
      case ExtensionInstallFlow.chromeZip:
        return [
          _GuideStep(label: l10n.extensionStepDownloadZip),
          _GuideStep(label: l10n.extensionStepCopyPath),
        ];
      case ExtensionInstallFlow.firefoxInstall:
        return [
          _GuideStep(label: l10n.extensionStepDownload),
          _GuideStep(label: l10n.extensionStepLaunchFirefox),
          _GuideStep(label: l10n.extensionStepOpenBrowser),
        ];
      case ExtensionInstallFlow.firefoxManual:
        return [
          _GuideStep(label: l10n.extensionStepDownload),
          _GuideStep(label: l10n.extensionStepCopyPath),
          _GuideStep(label: l10n.extensionStepOpenBrowser),
        ];
    }
  }

  void _setStep(int index, _StepPhase phase, {String? detail}) {
    if (!mounted) return;
    setState(() {
      _steps[index].phase = phase;
      if (detail != null) _steps[index].detail = detail;
      if (phase == _StepPhase.error) _errorStepIndex = index;
    });
  }

  Future<void> _runFlow() async {
    final l10n = context.l10n;
    try {
      switch (widget.flow) {
        case ExtensionInstallFlow.chromeInstall:
          await _runChromeInstall(l10n);
        case ExtensionInstallFlow.chromeZip:
          await _runChromeZip(l10n);
        case ExtensionInstallFlow.firefoxInstall:
          await _runFirefoxInstall(l10n);
        case ExtensionInstallFlow.firefoxManual:
          await _runFirefoxManual(l10n);
      }
      if (!mounted) return;
      setState(() => _success = true);
    } catch (e) {
      if (!mounted) return;
      final idx = _errorStepIndex >= 0 ? _errorStepIndex : 0;
      if (_steps[idx].phase != _StepPhase.error) {
        _setStep(idx, _StepPhase.error, detail: l10n.extensionDownloadFailed);
      }
    }
  }

  Future<void> _runChromeInstall(AppLocalizations l10n) async {
    _setStep(0, _StepPhase.running);
    final dir = await BrowserExtensionInstaller.ensureChromeExtension();
    if (dir == null) {
      _setStep(0, _StepPhase.error, detail: l10n.extensionDownloadFailed);
      throw StateError('chrome download failed');
    }
    _setStep(0, _StepPhase.done, detail: dir.path);

    _setStep(1, _StepPhase.running);
    await BrowserExtensionInstaller.copyPath(dir.path);
    _setStep(1, _StepPhase.done);

    _setStep(2, _StepPhase.running);
    final opened = await BrowserExtensionInstaller.openChromeExtensionsPage();
    if (!opened) {
      _setStep(2, _StepPhase.error, detail: l10n.extensionInstallFailed);
      throw StateError('chrome page failed');
    }
    _setStep(2, _StepPhase.done);
    _readyHint = l10n.extensionStepReadyChrome;
  }

  Future<void> _runChromeZip(AppLocalizations l10n) async {
    _setStep(0, _StepPhase.running);
    final file = await BrowserExtensionInstaller.saveChromeZipToDownloads();
    if (file == null) {
      _setStep(0, _StepPhase.error, detail: l10n.extensionDownloadFailed);
      throw StateError('zip download failed');
    }
    _setStep(0, _StepPhase.done, detail: file.path);

    _setStep(1, _StepPhase.running);
    await BrowserExtensionInstaller.copyPath(file.path);
    _setStep(1, _StepPhase.done);
    _readyHint = l10n.extensionStepReadyZip;
  }

  Future<void> _runFirefoxInstall(AppLocalizations l10n) async {
    _setStep(0, _StepPhase.running);
    final temp = await BrowserExtensionInstaller.downloadFirefoxXpiToTemp();
    if (temp == null) {
      _setStep(0, _StepPhase.error, detail: l10n.extensionDownloadFailed);
      throw StateError('firefox xpi download failed');
    }
    _setStep(0, _StepPhase.done, detail: temp.path);

    _setStep(1, _StepPhase.running);
    final launched = await BrowserExtensionInstaller.launchFirefoxWithXpi(temp);
    if (launched) {
      _setStep(1, _StepPhase.done);
      _setStep(2, _StepPhase.done, detail: l10n.extensionStepSkippedBrowser);
      _readyHint = l10n.extensionStepReadyFirefoxXpi;
      return;
    }
    _setStep(1, _StepPhase.done, detail: l10n.extensionStepFirefoxFallback);

    _setStep(2, _StepPhase.running);
    final dir = await BrowserExtensionInstaller.ensureFirefoxExtension();
    if (dir != null) {
      await BrowserExtensionInstaller.copyPath(dir.path);
    }
    final opened = await BrowserExtensionInstaller.openFirefoxDebuggingPage();
    if (!opened) {
      _setStep(2, _StepPhase.error, detail: l10n.extensionInstallFailed);
      throw StateError('firefox page failed');
    }
    _setStep(2, _StepPhase.done);
    _readyHint = l10n.extensionStepReadyFirefox;
  }

  Future<void> _runFirefoxManual(AppLocalizations l10n) async {
    _setStep(0, _StepPhase.running);
    final dir = await BrowserExtensionInstaller.ensureFirefoxExtension();
    if (dir == null) {
      _setStep(0, _StepPhase.error, detail: l10n.extensionDownloadFailed);
      throw StateError('firefox extract failed');
    }
    _setStep(0, _StepPhase.done, detail: dir.path);

    _setStep(1, _StepPhase.running);
    await BrowserExtensionInstaller.copyPath(dir.path);
    _setStep(1, _StepPhase.done);

    _setStep(2, _StepPhase.running);
    final opened = await BrowserExtensionInstaller.openFirefoxDebuggingPage();
    if (!opened) {
      _setStep(2, _StepPhase.error, detail: l10n.extensionInstallFailed);
      throw StateError('firefox debugging failed');
    }
    _setStep(2, _StepPhase.done);
    _readyHint = l10n.extensionStepReadyFirefox;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final inProgress = !_success && _errorStepIndex < 0;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        l10n.extensionInstallGuideTitle,
        style: AppTypography.h3.copyWith(color: colors.textPrimary),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inProgress)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.m),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                    const Gap(AppSpacing.s),
                    Expanded(
                      child: Text(
                        l10n.extensionInstallInProgress,
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ...List.generate(_steps.length, (i) => _StepRow(step: _steps[i])),
            if (_readyHint != null && _success) ...[
              const Gap(AppSpacing.m),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.success.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, color: colors.success),
                    const Gap(AppSpacing.s),
                    Expanded(
                      child: Text(
                        _readyHint!,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_errorStepIndex >= 0)
          AppButton.secondary(
            label: l10n.extensionInstallRetry,
            icon: Icons.refresh,
            onPressed: inProgress
                ? null
                : () {
                    Navigator.of(context).pop();
                    ExtensionInstallGuideDialog.show(context, widget.flow);
                  },
          ),
        AppButton.primary(
          label: l10n.extensionInstallClose,
          onPressed: inProgress ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final icon = switch (step.phase) {
      _StepPhase.pending => Icon(
        Icons.circle_outlined,
        color: colors.textDisabled,
        size: 20,
      ),
      _StepPhase.running => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
      ),
      _StepPhase.done => Icon(
        Icons.check_circle,
        color: colors.success,
        size: 20,
      ),
      _StepPhase.error => Icon(
        Icons.error_outline,
        color: colors.error,
        size: 20,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const Gap(AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: AppTypography.label.copyWith(
                    color: step.phase == _StepPhase.pending
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
                ),
                if (step.detail != null) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    step.detail!,
                    style: AppTypography.caption.copyWith(
                      color: step.phase == _StepPhase.error
                          ? colors.error
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
