import 'package:flutter/material.dart';

/// Model Kartu Statistik Admin
class AdminStatModel {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String? subtitle;

  // Field terpisah untuk penampungan nilai statistik spesifik
  final double? totalSahamTetap;       // Modal Permanen (SP & SW)
  final double? totalSimpananSukarela; // Simpanan Sukarela (SS Buku Biru)
  final double? totalTabunganHarian;    // Tabungan Harian (Buku Putih)
  final double? totalKasBank;
  final double? sahamEkuitas;

  const AdminStatModel({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.subtitle,
    this.totalSahamTetap,
    this.totalSimpananSukarela,
    this.totalTabunganHarian,
    this.totalKasBank,
    this.sahamEkuitas,
  });

  factory AdminStatModel.fromJson(Map<String, dynamic> json) {
    return AdminStatModel(
      title: json['title'] ?? '',
      value: json['value'] ?? '',
      subtitle: json['subtitle'],
      icon: json['icon'] as IconData? ?? Icons.account_balance_wallet_rounded,
      iconBg: json['iconBg'] != null ? Color(json['iconBg'] as int) : const Color(0xFFDCFCE7),
      iconColor: json['iconColor'] != null ? Color(json['iconColor'] as int) : const Color(0xFF16A34A),
      totalSahamTetap: (json['total_saham_tetap'] ?? json['saham_tetap'] ?? json['total_permanent_share'] as num?)?.toDouble(),
      totalSimpananSukarela: (json['total_simpanan_sukarela'] ?? json['simpanan_sukarela'] ?? json['total_voluntary'] as num?)?.toDouble(),
      totalTabunganHarian: (json['total_tabungan_harian'] ?? json['tabungan_harian'] ?? json['total_daily_savings'] ?? json['total_daily'] ?? json['simpanan_bisa_ditarik'] as num?)?.toDouble(),
      totalKasBank: (json['total_kas_bank'] as num?)?.toDouble(),
      sahamEkuitas: (json['saham_ekuitas'] as num?)?.toDouble(),
    );
  }
}
