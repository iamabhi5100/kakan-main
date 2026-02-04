import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:kakan/config/theme.dart';

class TabsMyfilesWidget extends StatelessWidget {
  final bool isVideoActive;
  final Function(bool) onTabChanged;

  const TabsMyfilesWidget({
    super.key,
    required this.isVideoActive,
    required this.onTabChanged,
  });

  Widget _buildTabItem({
    required BuildContext context,
    required IconData iconData,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final Color backgroundColor = isActive ? const Color(0xFF6F42C1) : Colors.grey.shade200;
    final Color foregroundColor = isActive ? Colors.white : Colors.grey.shade700;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(iconData, color: foregroundColor, size: 20),
            const Gap(8),
            Text(
              label,
              style: appTheme.textTheme.bodyLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildTabItem(
          context: context,
          iconData: Icons.video_library_outlined,
          label: 'Videos',
          isActive: isVideoActive,
          onTap: () => onTabChanged(true),
        ),
        const Gap(12),
        _buildTabItem(
          context: context,
          iconData: Icons.music_note_outlined,
          label: 'Songs',
          isActive: !isVideoActive,
          onTap: () => onTabChanged(false),
        ),
      ],
    );
  }
}