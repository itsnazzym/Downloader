import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modern_downloader/core/theme/app_colors.dart';
import 'package:modern_downloader/core/design_system/foundation/typography.dart';
import 'package:modern_downloader/features/archive/domain/entities/tiktok_archive_catalog.dart';

class TikTokVideoCard extends StatefulWidget {
  final TikTokArchiveItem item;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onDownload;

  const TikTokVideoCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onDownload,
  });

  @override
  State<TikTokVideoCard> createState() => _TikTokVideoCardState();
}

class _TikTokVideoCardState extends State<TikTokVideoCard> {
  bool _isHovered = false;

  String _formatDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _openUrl(String url) async {
    if (Uri.tryParse(url)?.host.endsWith('.invalid') == true) return;
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final item = widget.item;
    final demoNumber = item.id.startsWith('demo-')
        ? int.tryParse(item.id.substring(5))
        : null;
    final demoIndex = demoNumber == null ? null : (demoNumber - 1) % 4;
    const demoFilms = [
      'Sintel',
      'Tears of Steel',
      'Elephants Dream',
      'Big Buck Bunny',
    ];
    const demoArt = [
      'sintel.jpg',
      'tears-of-steel.jpg',
      'elephants-dream.jpg',
      'big-buck-bunny.png',
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? colors.primary.withValues(alpha: 0.08)
              : _isHovered
              ? colors.surfaceHighlight.withValues(alpha: 0.6)
              : colors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isSelected
                ? colors.primary
                : _isHovered
                ? colors.border
                : colors.borderSubtle,
            width: widget.isSelected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onToggleSelect,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Checkbox selection
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: widget.isSelected,
                      onChanged: (_) => widget.onToggleSelect(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      activeColor: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // The demo uses bundled, licensed stills instead of a video
                  // player or a thumbnail request to a user's archive source.
                  if (demoIndex != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/showcase/${demoArt[demoIndex]}',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        semanticLabel: demoFilms[demoIndex],
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 48,
                          height: 48,
                          color: colors.surfaceHighlight,
                          child: Icon(
                            Icons.movie_outlined,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                    ),
                  const SizedBox(width: 14),

                  // Metadata Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              demoIndex == null
                                  ? 'ID: ${item.id}'
                                  : '${demoFilms[demoIndex]} · extrait ${(demoNumber! - 1) ~/ 4 + 1}',
                              style: AppTypography.mono.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(item.date),
                              style: AppTypography.mono.copyWith(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (item.isFavorite) ...[
                              _Badge(
                                label: 'Favori',
                                color: const Color(
                                  0xFFFE2C55,
                                ), // Signature TikTok Coral Red
                                icon: Icons.bookmark_rounded,
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (item.isLiked) ...[
                              _Badge(
                                label: 'Like',
                                color: const Color(0xFFE91E63),
                                icon: Icons.favorite_rounded,
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (item.collectionName != null) ...[
                              _Badge(
                                label: item.collectionName!,
                                color: colors.primary,
                                icon: Icons.folder_rounded,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Hover-Only Actions (Discrete - Respects user preferences)
                  AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 120),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: 'Copier le lien',
                          splashRadius: 16,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: item.url));
                            _showNotice('Lien copié');
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          tooltip: 'Ouvrir dans le navigateur',
                          splashRadius: 16,
                          onPressed: () => _openUrl(item.url),
                        ),
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          onPressed: widget.onDownload,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 15),
                          label: Text(
                            'Télécharger',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
