/// 📊 Model Data Laporan Eksekutif Ketua Koperasi CUM Pelita
class ExecutiveReportModel {
  final String period; // 'Bulan Ini', 'Triwulan (Q3)', 'Tahun Ini (2026)'
  final String reportDate;
  final double totalKasMasuk;
  final double totalKasKeluar;
  final double netCashflow;

  // Breakdown Kas Masuk (KM)
  final List<CategoryDetailModel> kmCategories;

  // Breakdown Kas Keluar (KK)
  final List<CategoryDetailModel> kkCategories;

  // Rekapitulasi Transaksi Admin
  final int totalInputAdmin;
  final int autoApprovedCount;
  final int manualApprovalPendingCount;
  final int rejectedCount;

  // Financial Health Metrics
  final double liquidityRatioPercentage;
  final double operationalCoverageRatio;
  final double loanCollectibilityPercentage;

  // SHU Allocation from API
  final double benchmarkNetProfit;
  final double allocatedShu;
  final double shuPercentage;
  final bool isManualBenchmark;
  double get netShu => benchmarkNetProfit;

  // Interest Processed / Distributed Status (Buku Putih BM)
  final bool isDistributed;
  bool get isInterestProcessed => isDistributed;

  ExecutiveReportModel({
    required this.period,
    required this.reportDate,
    required this.totalKasMasuk,
    required this.totalKasKeluar,
    required this.netCashflow,
    required this.kmCategories,
    required this.kkCategories,
    required this.totalInputAdmin,
    required this.autoApprovedCount,
    required this.manualApprovalPendingCount,
    required this.rejectedCount,
    required this.liquidityRatioPercentage,
    required this.operationalCoverageRatio,
    required this.loanCollectibilityPercentage,
    this.benchmarkNetProfit = 0.0,
    this.allocatedShu = 0.0,
    this.shuPercentage = 25.0,
    this.isManualBenchmark = false,
    this.isDistributed = false,
    bool? isInterestProcessed,
  });

  factory ExecutiveReportModel.fromJson(Map<String, dynamic> json) {
    final kmList = (json['km_categories'] as List<dynamic>?)
            ?.map((e) => CategoryDetailModel.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    final kkList = (json['kk_categories'] as List<dynamic>?)
            ?.map((e) => CategoryDetailModel.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    final bool distributedStatus = json['is_distributed'] == true ||
        json['has_executed'] == true ||
        json['is_interest_processed'] == true ||
        json['already_distributed'] == true ||
        json['already_processed'] == true ||
        json['is_processed'] == true ||
        json['has_distributed'] == true ||
        json['interest_processed'] == true;

    final double rawNetProfit = (json['benchmark_net_profit'] ??
            json['laba_bersih_acuan'] ??
            json['net_profit'] ??
            json['net_shu'] as num?)
        ?.toDouble() ??
        0.0;
    final double rawAllocatedShu = (json['allocated_shu'] ??
            json['dividend_pool'] ??
            json['allocated_dividend'] ??
            json['alokasi_shu_70'] as num?)
        ?.toDouble() ??
        0.0;
    final double rawShuPct = (json['shu_percentage'] ??
            json['dividend_percent'] ??
            json['dividend_allocation_percent'] as num?)
        ?.toDouble() ??
        25.0;
    final bool isManualBm = json['is_manual_benchmark'] == true;

    return ExecutiveReportModel(
      period: json['period'] ?? 'Bulan Ini (Juli 2026)',
      reportDate: json['report_date'] ?? '30 Juli 2026',
      totalKasMasuk: (json['total_kas_masuk'] as num?)?.toDouble() ?? 0.0,
      totalKasKeluar: (json['total_kas_keluar'] as num?)?.toDouble() ?? 0.0,
      netCashflow: (json['net_cashflow'] as num?)?.toDouble() ?? 0.0,
      kmCategories: kmList,
      kkCategories: kkList,
      totalInputAdmin: json['total_input_admin'] as int? ?? 0,
      autoApprovedCount: json['auto_approved_count'] as int? ?? 0,
      manualApprovalPendingCount: json['manual_approval_pending_count'] as int? ?? 0,
      rejectedCount: json['rejected_count'] as int? ?? 0,
      liquidityRatioPercentage: (json['liquidity_ratio'] as num?)?.toDouble() ?? 0.0,
      operationalCoverageRatio: (json['operational_coverage_ratio'] as num?)?.toDouble() ?? 0.0,
      loanCollectibilityPercentage: (json['loan_collectibility'] as num?)?.toDouble() ?? 0.0,
      benchmarkNetProfit: rawNetProfit,
      allocatedShu: rawAllocatedShu,
      shuPercentage: rawShuPct,
      isManualBenchmark: isManualBm,
      isDistributed: distributedStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'report_date': reportDate,
      'total_kas_masuk': totalKasMasuk,
      'total_kas_keluar': totalKasKeluar,
      'net_cashflow': netCashflow,
      'km_categories': kmCategories.map((e) => e.toJson()).toList(),
      'kk_categories': kkCategories.map((e) => e.toJson()).toList(),
      'total_input_admin': totalInputAdmin,
      'auto_approved_count': autoApprovedCount,
      'manual_approval_pending_count': manualApprovalPendingCount,
      'rejected_count': rejectedCount,
      'liquidity_ratio': liquidityRatioPercentage,
      'operational_coverage_ratio': operationalCoverageRatio,
      'loan_collectibility': loanCollectibilityPercentage,
      'allocated_shu': allocatedShu,
      'shu_percentage': shuPercentage,
      'is_distributed': isDistributed,
      'is_interest_processed': isDistributed,
    };
  }

  static ExecutiveReportModel getDummyMonthlyReport() {
    return ExecutiveReportModel(
      period: 'Bulan Ini (Juli 2026)',
      reportDate: '30 Juli 2026',
      totalKasMasuk: 185400000,
      totalKasKeluar: 62150000,
      netCashflow: 123250000,
      kmCategories: [
        CategoryDetailModel(code: '101.1', categoryName: 'Simpanan Pokok & Wajib', amount: 48500000, percentage: 26.2),
        CategoryDetailModel(code: '101.2', categoryName: 'Angsuran Piutang Pokok', amount: 82400000, percentage: 44.4),
        CategoryDetailModel(code: '101.3', categoryName: 'Jasa Piutang Pinjaman', amount: 31200000, percentage: 16.8),
        CategoryDetailModel(code: '101.4', categoryName: 'Simpanan Sukarela Khusus', amount: 23300000, percentage: 12.6),
      ],
      kkCategories: [
        CategoryDetailModel(code: '201.1', categoryName: 'Pencairan Pinjaman Piutang', amount: 45000000, percentage: 72.4),
        CategoryDetailModel(code: '201.2', categoryName: 'Biaya Operasional & ATK', amount: 9850000, percentage: 15.8),
        CategoryDetailModel(code: '201.3', categoryName: 'Penarikan Simpanan Sukarela', amount: 7300000, percentage: 11.8),
      ],
      totalInputAdmin: 142,
      autoApprovedCount: 128,
      manualApprovalPendingCount: 11,
      rejectedCount: 3,
      liquidityRatioPercentage: 184.5,
      operationalCoverageRatio: 2.98,
      loanCollectibilityPercentage: 97.4,
      allocatedShu: 86275000,
      shuPercentage: 70.0,
      isInterestProcessed: false,
    );
  }
}

class CategoryDetailModel {
  final String code;
  final String categoryName;
  final double amount;
  final double percentage;

  CategoryDetailModel({
    required this.code,
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });

  factory CategoryDetailModel.fromJson(Map<String, dynamic> json) {
    return CategoryDetailModel(
      code: json['code'] ?? '',
      categoryName: json['category_name'] ?? json['name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'category_name': categoryName,
      'amount': amount,
      'percentage': percentage,
    };
  }
}
