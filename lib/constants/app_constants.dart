import 'package:flutter/material.dart';
import 'app_colors.dart';
export 'app_colors.dart';
export 'app_assets.dart';

/// Konfigurasi & Kontak Terpusat Aplikasi Koperasi
abstract class AppConstants {
  static const String appTitle = 'CREDO UNION MODIFIKASI';
  static const String appDescription =
      'APLIKASI RESMI UNTUK CREDO UNION MODIFIKASI';

  static const String adminPhoneNumber = '6281276547189';
  static const String adminDisplayPhoneNumber = '0812-7654-7189';

  static const Duration splashAnimationDuration = Duration(milliseconds: 3800);
  static const Duration tabTransitionDuration = Duration(milliseconds: 200);
  static const Duration apiSimulationDelay = Duration(seconds: 2);
}

/// Dimensi & Padding Terpusat
abstract class AppSizes {
  static const double p4 = 4.0;
  static const double p8 = 8.0;
  static const double p12 = 12.0;
  static const double p16 = 16.0;
  static const double p20 = 20.0;
  static const double p24 = 24.0;
  static const double p32 = 32.0;

  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;

  static const EdgeInsets pAll16 = EdgeInsets.all(p16);
}

/// Tipografi & Style Terpusat
abstract class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle appBarTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
  );
}
