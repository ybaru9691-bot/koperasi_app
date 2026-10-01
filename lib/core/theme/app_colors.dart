import 'package:flutter/material.dart';

/// 🎨 Palet Warna Terpusat & Design System Aplikasi Koperasi CUM Pelita
abstract class AppColors {
  // --- WARNA UTAMA (CORE BRAND) ---
  static const Color primary = Color(0xFF137A43); // Hijau Koperasi Utama
  static const Color primaryDark = Color(0xFF0F5A32);
  static const Color primaryLight = Color(0xFF1C7C54);
  static const Color primaryBackground = Color(0xFFE8F5E9);

  static const Color navy = Color(0xFF000080); // Biru HKBP (Navy)
  static const Color secondary = Color(0xFF000080); // Biru HKBP (Navy)
  static const Color accentBlue = Color(0xFF0284C7); // Sky 600

  // --- WARNA THEME ADMIN VS ANGGOTA ---
  static const Color adminNavy = Color(0xFF0F172A); // Slate 900 (Dark Navy Admin)
  static const Color adminAccent = Color(0xFF38BDF8); // Sky Light 400
  static const Color adminCanvas = Color(0xFFF1F5F9); // Slate 100

  static const Color anggotaGreen = Color(0xFF137A43);
  static const Color anggotaCanvas = Color(0xFFF6F8FA);

  // --- WARNA CANVAS, CARD, & BORDER ---
  static const Color background = Color(0xFFF6F8FA);
  static const Color surface = Colors.white;
  static const Color cardBg = Colors.white;
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color cardBorder = Color(0xFFE2E8F0); // Slate 200

  // --- WARNA TEKS ---
  static const Color textPrimary = Color(0xFF1E293B); // Slate 800
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textInverse = Colors.white;

  // --- WARNA STATUS / BADGE ---
  static const Color success = Color(0xFF15803D); // Green 700
  static const Color successBg = Color(0xFFDCFCE7); // Green 100

  static const Color warning = Color(0xFFB45309); // Amber 700
  static const Color warningBg = Color(0xFFFEF3C7); // Amber 100

  static const Color danger = Color(0xFFB91C1C); // Red 700
  static const Color dangerBg = Color(0xFFFEE2E2); // Red 100
  static const Color dangerAccent = Colors.redAccent;

  static const Color info = Color(0xFF0369A1); // Sky 700
  static const Color infoBg = Color(0xFFE0F2FE); // Sky 100

  // --- ALIAS STATUS UNTUK FREKUENSI PENGGUNAAN LAMA ---
  static const Color statusPending = Color(0xFFF59E0B); // Amber
  static const Color statusApproved = Color(0xFF10B981); // Emerald Green
  static const Color statusRejected = Color(0xFFEF4444); // Red

  static const Color gold = Color(0xFFFFD700);
}
