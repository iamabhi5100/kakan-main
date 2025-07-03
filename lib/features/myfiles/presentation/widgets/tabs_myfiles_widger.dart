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

  BoxDecoration _activeDecoration() {
    return BoxDecoration(
      color: appTheme.primaryColor,
      border: Border.all(color: appTheme.primaryColor, width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(20)),
    );
  }

  BoxDecoration _inactiveDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey, width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () {
            if (!isVideoActive) {
              onTabChanged(true);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: isVideoActive ? _activeDecoration() : _inactiveDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_collection_outlined,
                  color: isVideoActive ? Colors.white : Colors.grey,
                  size: 20,
                ),
                const Gap(10),
                Text(
                  'Videos',
                  style: appTheme.textTheme.titleLarge?.copyWith(
                    color: isVideoActive ? Colors.white : Colors.grey,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(20),
        InkWell(
          onTap: () {
            if (isVideoActive) {
              onTabChanged(false);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: !isVideoActive ? _activeDecoration() : _inactiveDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_note,
                  color: !isVideoActive ? Colors.white : Colors.grey,
                  size: 20,
                ),
                const Gap(10),
                Text(
                  'Songs',
                  style: appTheme.textTheme.titleLarge?.copyWith(
                    color: !isVideoActive ? Colors.white : Colors.grey,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}