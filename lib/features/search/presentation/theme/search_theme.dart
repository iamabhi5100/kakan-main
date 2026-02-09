import 'package:flutter/material.dart';

/// Shared design tokens for the search module. Use for consistent, professional UI.
class SearchTheme {
  SearchTheme._();

  // ── Colors ─────────────────────────────────────────────────────────────
  static const Color surfaceBg = Color(0xFFF5F6F8);
  static const Color cardBg = Colors.white;
  static const Color primary = Color(0xFF1A1A2E);
  static const Color primaryLight = Color(0xFF16213E);
  static const Color accent = Color(0xFF0F3460);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color likeRed = Color(0xFFE11D48);
  static const Color repostGreen = Color(0xFF059669);
  static const Color searchBarFill = Color(0xFFF3F4F6);
  static const Color chipSelectedBg = Color(0xFF1A1A2E);
  static const Color chipUnselectedBg = Color(0xFFE5E7EB);
  static const Color chipUnselectedText = Color(0xFF6B7280);

  // ── Dimensions ───────────────────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXXl = 24.0;

  static const double avatarSize = 44.0;
  static const double avatarSizeSm = 40.0;
  static const double listThumbSize = 72.0;
  static const double contentCardPadding = 16.0;

  // ── Typography ───────────────────────────────────────────────────────────
  static const TextStyle titleAppBar = TextStyle(
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle titleCard = TextStyle(
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subtitle = TextStyle(
    color: textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const TextStyle caption = TextStyle(
    color: textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelChip = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle labelChipUnselected = TextStyle(
    color: chipUnselectedText,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle actionCount = TextStyle(
    color: textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle emptyTitle = TextStyle(
    color: textSecondary,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle emptySubtitle = TextStyle(
    color: textMuted,
    fontSize: 14,
    height: 1.4,
  );

  static const TextStyle errorText = TextStyle(
    color: likeRed,
    fontSize: 14,
  );
}
