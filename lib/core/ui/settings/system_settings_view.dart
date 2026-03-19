import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import '../../design_system/foundation/colors.dart';
import '../../design_system/foundation/spacing.dart';
import '../../design_system/foundation/typography.dart';
import '../../design_system/components/app_toast.dart';
import '../../../services/binary_verifier.dart';
import '../../services/file_organization_service.dart';
import '../../providers/settings_provider.dart';
import '../settings_view.dart';

class SystemSettingsView extends ConsumerStatefulWidget {
  const SystemSettingsView({super.key});

  @override
  ConsumerState<SystemSettingsView> createState() => _SystemSettingsViewState();
}

class _SystemSettingsViewState extends ConsumerState<SystemSettingsView> {
  BinaryStatus? _ytDlpStatus;
  BinaryStatus? _ffmpegStatus;
  BinaryStatus? _aria2cStatus;
  bool _isVerifying = false;
  bool _isOrganizing = false;
  String _organizingStatus = '';

  Future<void> _verifyBinaries() async {
    setState(() => _isVerifying = true);
    final ytdlp = await BinaryVerifier.checkYtDlp();
    final ffmpeg = await BinaryVerifier.checkFfmpeg();
    final aria2c = await BinaryVerifier.checkAria2c();

    if (mounted) {
      setState(() {
        _ytDlpStatus = ytdlp;
        _ffmpegStatus = ffmpeg;
        _aria2cStatus = aria2c;
        _isVerifying = false;
      });
      AppToast.showSuccess(context, "Dependencies verified");
    }
  }

  Future<void> _organizeLibrary() async {
    final settings = ref.read(settingsProvider);
    final outputFolder = settings.outputFolder;

    if (outputFolder.isEmpty) {
      AppToast.showError(context, "Output folder not configured");
      return;
    }

    setState(() {
      _isOrganizing = true;
      _organizingStatus = 'Starting organization...';
    });

    final service = FileOrganizationService();

    try {
      final result = await service.organizeLibrary(
        outputFolder,
        onProgress: (status, current, total) {
          if (mounted) {
            setState(() {
              _organizingStatus = '$status ($current/$total)';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isOrganizing = false;
          _organizingStatus = '';
        });

        // Show result dialog
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text("Organization Complete"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("📁 Files moved: ${result.filesMoved}"),
                Text("🗑️ Temp files deleted: ${result.filesDeleted}"),
                Text("🖼️ Thumbnails organized: ${result.thumbnailsMoved}"),
                Text("📂 Folders created: ${result.foldersCreated}"),
                Text("🧹 Empty folders deleted: ${result.foldersDeleted}"),
                if (result.hasErrors) ...[
                  const Gap(8),
                  Text(
                    "⚠️ ${result.errors.length} errors occurred",
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text("OK")),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOrganizing = false;
          _organizingStatus = '';
        });
        AppToast.showError(context, "Organization failed: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: SizedBox(),
        backgroundColor: AppColors.background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          "System Settings",
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.border.withValues(alpha: 0.5),
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.xl + 20,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  [
                        const SectionTitle("System"),
                        ActionTile(
                          title: "Check Dependencies",
                          subtitle: _isVerifying
                              ? "Verifying binaries..."
                              : "Check yt-dlp, ffmpeg & aria2c status",
                          icon: Icons.build_circle_outlined,
                          onTap: _isVerifying ? null : _verifyBinaries,
                        ),
                        if (_ytDlpStatus != null) ...[
                          const Gap(AppSpacing.s),
                          StatusTile("yt-dlp", _ytDlpStatus!),
                        ],
                        if (_ffmpegStatus != null)
                          StatusTile("ffmpeg", _ffmpegStatus!),
                        if (_aria2cStatus != null)
                          StatusTile("aria2c", _aria2cStatus!),

                        const Gap(AppSpacing.l),
                        const SectionTitle("Library Management"),
                        ActionTile(
                          title: "Organize Library",
                          subtitle: _isOrganizing
                              ? _organizingStatus
                              : "Sort files by source, move thumbnails to folder, cleanup temp files",
                          icon: Icons.folder_special_outlined,
                          onTap: _isOrganizing ? null : _organizeLibrary,
                        ),
                      ]
                      .animate(interval: 50.ms)
                      .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                      .slideY(begin: 0.1, end: 0, duration: 300.ms),
            ),
          ),
        ),
      ),
    );
  }
}
