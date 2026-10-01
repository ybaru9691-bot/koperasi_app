/// 🔒 Model Data Periode Akuntansi & Tutup Buku Koperasi CUM Pelita
class PeriodModel {
  final String id;
  final String periodName; // 'Juni 2025 - Mei 2026'
  final String startDate;
  final String endDate;
  final String status; // 'terbuka', 'dikunci'
  final int totalTransactions;
  final int remainingDays;
  final bool isLocked;
  final bool isActive;

  PeriodModel({
    required this.id,
    required this.periodName,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalTransactions,
    required this.remainingDays,
    required this.isLocked,
    this.isActive = true,
  });

  static bool parseBool(dynamic val, {bool fallback = false}) {
    if (val == null) return fallback;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'dikunci' || s == 'locked' || s == 'active' || s == 'closed') {
        return true;
      }
      if (s == 'false' || s == '0' || s == 'terbuka' || s == 'open') {
        return false;
      }
    }
    return fallback;
  }

  factory PeriodModel.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? 'terbuka').toString().toLowerCase();

    bool locked = false;
    if (json['is_locked'] != null) {
      locked = parseBool(json['is_locked']);
    } else if (json['is_closed'] != null) {
      locked = parseBool(json['is_closed']);
    } else {
      locked = (rawStatus == 'dikunci' || rawStatus == 'locked' || rawStatus == 'closed');
    }

    bool active = true;
    if (json['is_active'] != null) {
      active = parseBool(json['is_active'], fallback: true);
    } else {
      active = !locked;
    }

    return PeriodModel(
      id: (json['id'] ?? json['period_id'] ?? json['id_periode'] ?? json['periodId'] ?? '').toString(),
      periodName: json['period_name'] ?? json['nama_periode'] ?? json['name'] ?? '',
      startDate: json['start_date'] ?? json['tgl_mulai'] ?? '',
      endDate: json['end_date'] ?? json['tgl_selesai'] ?? '',
      status: rawStatus,
      totalTransactions: (json['total_transactions'] as num?)?.toInt() ?? 
                         (json['total_transaksi'] as num?)?.toInt() ?? 
                         (json['transaction_count'] as num?)?.toInt() ?? 0,
      remainingDays: (json['days_remaining'] as num?)?.toInt() ?? 
                     (json['remaining_days'] as num?)?.toInt() ?? 
                     (json['sisa_hari'] as num?)?.toInt() ?? 0,
      isLocked: locked,
      isActive: active,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'period_name': periodName,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'total_transactions': totalTransactions,
      'remaining_days': remainingDays,
      'is_locked': isLocked,
      'is_active': isActive,
    };
  }

  static PeriodModel getActivePeriod() {
    return PeriodModel(
      id: 'PER-2026-2027',
      periodName: 'Juni 2026 - Mei 2027',
      startDate: '01 Juni 2026',
      endDate: '31 Mei 2027',
      status: 'terbuka',
      totalTransactions: 0,
      remainingDays: 285,
      isLocked: false,
      isActive: true,
    );
  }

  static List<PeriodModel> getPeriodHistory() {
    return [
      PeriodModel(
        id: 'PER-2024-2025',
        periodName: 'Juni 2024 - Mei 2025',
        startDate: '01 Juni 2024',
        endDate: '31 Mei 2025',
        status: 'dikunci',
        totalTransactions: 12850,
        remainingDays: 0,
        isLocked: true,
      ),
      PeriodModel(
        id: 'PER-2023-2024',
        periodName: 'Juni 2023 - Mei 2024',
        startDate: '01 Juni 2023',
        endDate: '31 Mei 2024',
        status: 'dikunci',
        totalTransactions: 11420,
        remainingDays: 0,
        isLocked: true,
      ),
    ];
  }
}
