import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 🎨 Reusable Card Decorations, Borders, and Shadows
abstract class AppDecorations {
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 8,
    offset: Offset(0, 3),
  );

  static final BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.cardBorder),
    boxShadow: const [cardShadow],
  );

  static final BoxDecoration dialogDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
  );

  static final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  static final RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  static final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  );
}
