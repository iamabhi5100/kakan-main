import 'package:flutter/material.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/features/search/presentation/theme/search_theme.dart';

/// Reusable profile header row for search content screens (video, image, carousel, song).
class SearchContentProfileRow extends StatelessWidget {
  final SearchResult meta;

  const SearchContentProfileRow({super.key, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SearchTheme.spacingSm),
      child: Row(
        children: [
          CircleAvatar(
            radius: SearchTheme.avatarSizeSm / 2,
            backgroundColor: SearchTheme.divider,
            backgroundImage: meta.profileImage != null && meta.profileImage!.isNotEmpty
                ? NetworkImage(meta.profileImage!)
                : null,
            child: meta.profileImage == null || meta.profileImage!.isEmpty
                ? Icon(Icons.person_rounded, color: SearchTheme.textMuted, size: 22)
                : null,
          ),
          const SizedBox(width: SearchTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.name ?? 'Unknown',
                  style: SearchTheme.titleCard.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${meta.username ?? ''}',
                  style: SearchTheme.caption.copyWith(color: SearchTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: SearchTheme.textMuted, size: 24),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// Reusable action row: like, repost, share.
class SearchContentActionRow extends StatelessWidget {
  final bool flagLiked;
  final int likes;
  final int reposts;
  final VoidCallback onLike;
  final VoidCallback onRepost;
  final VoidCallback onShare;

  const SearchContentActionRow({
    super.key,
    required this.flagLiked,
    required this.likes,
    required this.reposts,
    required this.onLike,
    required this.onRepost,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SearchTheme.spacingSm),
      child: Row(
        children: [
          _ActionChip(
            icon: flagLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            iconColor: flagLiked ? SearchTheme.likeRed : SearchTheme.textSecondary,
            label: '$likes',
            suffix: 'Likes',
            onTap: onLike,
          ),
          const SizedBox(width: SearchTheme.spacingLg),
          _ActionChip(
            icon: Icons.repeat_rounded,
            iconColor: SearchTheme.repostGreen,
            label: '$reposts',
            suffix: 'Reposts',
            onTap: onRepost,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.send_rounded, color: SearchTheme.textPrimary, size: 24),
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String suffix;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.suffix,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SearchTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 4),
              Text(
                '$label $suffix',
                style: SearchTheme.actionCount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps content screen body in consistent padding and card styling.
Widget searchContentCard({required Widget child}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: SearchTheme.spacingLg),
    padding: const EdgeInsets.all(SearchTheme.contentCardPadding),
    decoration: BoxDecoration(
      color: SearchTheme.cardBg,
      borderRadius: BorderRadius.circular(SearchTheme.radiusLg),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}
