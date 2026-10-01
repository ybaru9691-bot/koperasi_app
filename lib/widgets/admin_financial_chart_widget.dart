import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Model Data Keuangan Bulanan (Kas Masuk vs Kas Keluar)
class MonthlyFinancialData {
  final String month;
  final double kasMasuk;  // KM (Pemasukan)
  final double kasKeluar; // KK (Pengeluaran)

  const MonthlyFinancialData({
    required this.month,
    required this.kasMasuk,
    required this.kasKeluar,
  });
}

/// Widget Stateful Grafik Tren Keuangan (BarChart Comparison KM vs KK)
class AdminFinancialChartWidget extends StatefulWidget {
  final List<MonthlyFinancialData>? monthlyData;

  const AdminFinancialChartWidget({
    super.key,
    this.monthlyData,
  });

  @override
  State<AdminFinancialChartWidget> createState() => _AdminFinancialChartWidgetState();
}

class _AdminFinancialChartWidgetState extends State<AdminFinancialChartWidget> {
  int touchedGroupIndex = -1;

  // Dummy Data Tren 12 Bulan Tahun Anggaran 2026 (Mudah Di-bind ke Backend API)
  late List<MonthlyFinancialData> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.monthlyData ?? const [
      MonthlyFinancialData(month: 'Jan', kasMasuk: 125000000, kasKeluar: 45000000),
      MonthlyFinancialData(month: 'Feb', kasMasuk: 140000000, kasKeluar: 52000000),
      MonthlyFinancialData(month: 'Mar', kasMasuk: 110000000, kasKeluar: 60000000),
      MonthlyFinancialData(month: 'Apr', kasMasuk: 165000000, kasKeluar: 48000000),
      MonthlyFinancialData(month: 'Mei', kasMasuk: 180000000, kasKeluar: 75000000),
      MonthlyFinancialData(month: 'Jun', kasMasuk: 155000000, kasKeluar: 50000000),
      MonthlyFinancialData(month: 'Jul', kasMasuk: 210000000, kasKeluar: 85000000),
      MonthlyFinancialData(month: 'Ags', kasMasuk: 175000000, kasKeluar: 62000000),
      MonthlyFinancialData(month: 'Sep', kasMasuk: 190000000, kasKeluar: 70000000),
      MonthlyFinancialData(month: 'Okt', kasMasuk: 160000000, kasKeluar: 55000000),
      MonthlyFinancialData(month: 'Nov', kasMasuk: 205000000, kasKeluar: 90000000),
      MonthlyFinancialData(month: 'Des', kasMasuk: 240000000, kasKeluar: 110000000),
    ];
  }

  @override
  void didUpdateWidget(covariant AdminFinancialChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.monthlyData != null) {
      _data = widget.monthlyData!;
    }
  }

  static String _formatRupiahShort(double? numVal) {
    final double val = (numVal == null || numVal.isNaN || numVal.isInfinite) ? 0.0 : numVal;
    if (val >= 1000000000) {
      return '${(val / 1000000000).toStringAsFixed(1)}M';
    } else if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(0)}Jt';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}rb';
    }
    return val.toStringAsFixed(0);
  }

  static String _formatRupiahFull(double? numVal) {
    final double val = (numVal == null || numVal.isNaN || numVal.isInfinite) ? 0.0 : numVal;
    final String formattedStr = val.toStringAsFixed(0);
    return "Rp ${formattedStr.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER CARD (Judul, Subjudul & Legend)
          _buildHeaderSection(),

          const SizedBox(height: 24),

          // 2. RESPONSIVE BARCHART CONTAINER
          SizedBox(
            height: 280,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: MediaQuery.of(context).size.width < 600 ? 680 : MediaQuery.of(context).size.width - 100,
                child: BarChart(
                  _mainBarChartData(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Header Section dengan Legend Kotak Warna (Responsive Guard)
  Widget _buildHeaderSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 520;

        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.adminNavy,
                  size: 22,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Grafik Tren Uang Masuk vs Uang Keluar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.adminNavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tahun Anggaran 2026 • Koperasi CUM Pelita',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

        final legendWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendItem(
              color: AppColors.success,
              label: 'Kas Masuk (KM)',
            ),
            const SizedBox(width: 12),
            _buildLegendItem(
              color: AppColors.danger,
              label: 'Kas Keluar (KK)',
            ),
          ],
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 16),
              legendWidget,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleWidget,
            const SizedBox(height: 12),
            legendWidget,
          ],
        );
      },
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  double _calculateInterval(double maxVal) {
    if (maxVal <= 20000000) return 5000000;
    if (maxVal <= 50000000) return 10000000;
    if (maxVal <= 100000000) return 20000000;
    if (maxVal <= 250000000) return 50000000;
    double raw = (maxVal * 1.25 / 4).roundToDouble();
    return raw > 0 ? raw : 10000000;
  }

  /// 2. Konfigurasi Utama BarChartData (fl_chart)
  BarChartData _mainBarChartData() {
    double maxVal = 0.0;
    for (var item in _data) {
      if (item.kasMasuk > maxVal) maxVal = item.kasMasuk;
      if (item.kasKeluar > maxVal) maxVal = item.kasKeluar;
    }
    if (maxVal < 10000000) {
      maxVal = 10000000;
    }
    final double calculatedInterval = _calculateInterval(maxVal);
    final double calculatedMaxY = ((maxVal * 1.25) / calculatedInterval).ceil() * calculatedInterval;

    return BarChartData(
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => AppColors.adminNavy.withValues(alpha: 0.95),
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tooltipMargin: 8,
          tooltipRoundedRadius: 10,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final monthName = _data[groupIndex].month;
            final isKm = rodIndex == 0;
            final label = isKm ? 'KM (Kas Masuk)' : 'KK (Kas Keluar)';
            final amount = isKm ? _data[groupIndex].kasMasuk : _data[groupIndex].kasKeluar;

            return BarTooltipItem(
              '$monthName\n',
              const TextStyle(
                color: AppColors.adminAccent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                TextSpan(
                  text: _formatRupiahFull(amount),
                  style: TextStyle(
                    color: isKm ? AppColors.success : AppColors.dangerAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
        touchCallback: (FlTouchEvent event, barTouchResponse) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                barTouchResponse == null ||
                barTouchResponse.spot == null) {
              touchedGroupIndex = -1;
              return;
            }
            touchedGroupIndex = barTouchResponse.spot!.touchedBarGroupIndex;
          });
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: _getBottomTitles,
            reservedSize: 32,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 52,
            interval: calculatedInterval,
            getTitlesWidget: (val, meta) => _getLeftTitles(val, meta, calculatedInterval),
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 1.5),
          left: BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: calculatedInterval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppColors.cardBorder.withValues(alpha: 0.5),
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      ),
      barGroups: _generateBarGroups(),
      maxY: calculatedMaxY,
    );
  }

  /// Generator Group Batang KM (Hijau) & KK (Merah) Per Bulan
  List<BarChartGroupData> _generateBarGroups() {
    return List.generate(_data.length, (i) {
      final item = _data[i];
      final isTouched = i == touchedGroupIndex;

      return BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          // Batang 1: Kas Masuk (KM - Hijau)
          BarChartRodData(
            toY: item.kasMasuk,
            color: AppColors.success,
            width: isTouched ? 13 : 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          // Batang 2: Kas Keluar (KK - Merah)
          BarChartRodData(
            toY: item.kasKeluar,
            color: AppColors.danger,
            width: isTouched ? 13 : 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.bold,
      fontSize: 11,
    );
    final index = value.toInt();
    if (index >= 0 && index < _data.length) {
      return SideTitleWidget(
        meta: meta,
        space: 6,
        child: Text(_data[index].month, style: style),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _getLeftTitles(double value, TitleMeta meta, double interval) {
    final double remainder = (value % interval).abs();
    final double epsilon = interval * 0.001;
    if (remainder > epsilon && (interval - remainder).abs() > epsilon) {
      return const SizedBox.shrink();
    }
    const style = TextStyle(
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(_formatRupiahShort(value), style: style),
    );
  }
}
