import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modern_downloader/features/downloader/presentation/providers/video_thumbnail_provider.dart';

/// The preview taken from the downloaded file itself, for a tile whose
/// remote thumbnail is missing or no longer loads (expired CDN address);
/// [placeholder] until it is ready or when there is none.
class LocalVideoThumb extends ConsumerWidget {
  const LocalVideoThumb({
    super.key,
    required this.filePath,
    required this.placeholder,
    this.cacheWidth,
  });

  final String? filePath;
  final Widget placeholder;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = filePath;
    if (path == null || path.isEmpty) return placeholder;
    final thumb = ref.watch(videoThumbnailProvider(path)).valueOrNull;
    if (thumb == null) return placeholder;
    return Image.file(
      File(thumb),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}
