import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:modern_downloader/theme/ios_theme.dart';
import 'package:modern_downloader/theme/palette.dart';

class FloatingNavDock extends StatelessWidget {
  final String currentLocation;
  const FloatingNavDock({super.key, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 20),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: IOSTheme.glassDecoration(
          radius: 32,
          color: Palette.glassBlack,
          borderColor: Palette.borderWhite,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNavItem(
              context,
              icon: Icons.download_rounded,
              label: 'Home',
              path: '/',
              isSelected: currentLocation == '/',
            ),
            SizedBox(height: 20),
            _buildNavItem(
              context,
              icon: Icons.settings_rounded,
              label: 'Settings',
              path: '/settings',
              isSelected: currentLocation == '/settings',
            ),
          ],
        ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.2),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String path,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => context.go(path),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: 200.ms,
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? Palette.neonBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Palette.neonBlue.withValues(alpha: 0.4)
                  : Colors.transparent,
              blurRadius: isSelected ? 12 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Palette.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}
