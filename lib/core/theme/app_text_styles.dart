import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 🔤 Konfigurasi Reusable TextStyle & Typography System Aplikasi
abstract class AppTextStyles {
  // --- HEADINGS ---
  static const TextStyle heading1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // --- SUBTITLES & CAPTIONS ---
  static const TextStyle subtitle = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
  );

  // --- BODY TEXT ---
  static const TextStyle bodyText = TextStyle(
    fontSize: 13,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyTextBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // --- TABLE STYLES ---
  static const TextStyle tableHeader = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle tableBody = TextStyle(
    fontSize: 10.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle tableBodyBold = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.bold,
    color: AppColors.adminNavy,
  );

  // --- BADGE STYLES ---
  static const TextStyle badgeText = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.bold,
  );
}
