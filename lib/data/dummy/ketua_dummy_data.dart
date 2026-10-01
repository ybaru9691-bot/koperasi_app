import 'package:flutter/material.dart';
import '../models/approval_data_model.dart';
export '../models/approval_data_model.dart';

/// Model Data Kartu Statistik Eksekutif
class StatCardModel {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> bgGradient;

  const StatCardModel({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgGradient,
  });

  factory StatCardModel.fromJson(Map<String, dynamic> json) {
    return StatCardModel(
      title: json['title'] ?? '',
      value: json['value'] ?? '',
      subtitle: json['subtitle'] ?? '',
      icon: json['icon'] as IconData? ?? Icons.insights_rounded,
      color: json['color'] != null ? Color(json['color'] as int) : const Color(0xFF0284C7),
      bgGradient: (json['bgGradient'] as List<dynamic>?)
              ?.map((c) => Color(c as int))
              .toList() ??
          const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
    );
  }
}

/// Repository Dummy Data khusus Ketua Koperasi
class KetuaDummyData {
  static final List<StatCardModel> statCards = [
    const StatCardModel(
      title: 'Total Anggota Aktif',
      value: '1.542 Anggota',
      subtitle: '+4.2% bulan ini',
      icon: Icons.groups_rounded,
      color: Color(0xFF0284C7),
      bgGradient: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
    ),
    const StatCardModel(
      title: 'Total Aset / Kas Koperasi',
      value: 'Rp 2.450.000.000',
      subtitle: '+8.5% YTD 2026',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF16A34A),
      bgGradient: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
    ),
    const StatCardModel(
      title: 'Total Kas Masuk (KM)',
      value: 'Rp 185.400.000',
      subtitle: 'Periode Juli 2026',
      icon: Icons.arrow_downward_rounded,
      color: Color(0xFF0D9488),
      bgGradient: [Color(0xFFCCFBF1), Color(0xFF99F6E4)],
    ),
    const StatCardModel(
      title: 'Total Kas Keluar (KK)',
      value: 'Rp 62.150.000',
      subtitle: 'Periode Juli 2026',
      icon: Icons.arrow_upward_rounded,
      color: Color(0xFFE11D48),
      bgGradient: [Color(0xFFFFE4E6), Color(0xFFFECDD3)],
    ),
  ];

  static List<ApprovalDataModel> getApprovalRequests() {
    return [
      ApprovalDataModel.fromJson({
        'id': 'PJ-2026-084',
        'applicant': 'St. M. Simanjuntak',
        'memberNo': '2562',
        'category': 'Pinjaman Piutang S-3 (Kredit Usaha)',
        'type': 'pinjaman',
        'date': '30 Juli 2026',
        'amount': 25000000,
        'status': 'menunggu',
        'notes': 'Pengajuan modal kerja toko sembako Duri',
      }),
      ApprovalDataModel.fromJson({
        'id': 'KK-2026-042',
        'applicant': 'Kas Operasional Admin',
        'memberNo': 'OFFICE',
        'category': 'Kas Keluar > 10 Jt (Upgrade Server & Laptop)',
        'type': 'kas_keluar',
        'date': '29 Juli 2026',
        'amount': 15500000,
        'status': 'menunggu',
        'notes': 'Pengadaan perangkat komputer operasional teller',
      }),
      ApprovalDataModel.fromJson({
        'id': 'PJ-2026-085',
        'applicant': 'Farida Suzana',
        'memberNo': '2563',
        'category': 'Pinjaman Piutang S-2 (Biaya Pendidikan)',
        'type': 'pinjaman',
        'date': '28 Juli 2026',
        'amount': 10000000,
        'status': 'menunggu',
        'notes': 'Daftar ulang perguruan tinggi anak',
      }),
      ApprovalDataModel.fromJson({
        'id': 'SP-2026-019',
        'applicant': 'Maria Sitindaon',
        'memberNo': '2564',
        'category': 'Pencairan Simpanan Sukarela Khusus',
        'type': 'kas_keluar',
        'date': '27 Juli 2026',
        'amount': 8200000,
        'status': 'menunggu',
        'notes': 'Penarikan simpanan sukarela untuk renovasi rumah',
      }),
    ];
  }
}
