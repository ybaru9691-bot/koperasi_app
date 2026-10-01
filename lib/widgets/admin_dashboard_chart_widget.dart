import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class BarTouchDataNotifier {
  static BarTouchData getTouchData() {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (group) => const Color(0xFF1E293B),
        tooltipMargin: 8,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final String valueText = rod.toY.toStringAsFixed(0).replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]}.',
              );
          return BarTooltipItem(
            'Rp $valueText',
            const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          );
        },
      ),
    );
  }
}

class MonthlyTrendChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> monthlyData;
  final bool isLoading;

  const MonthlyTrendChartWidget({
    Key? key,
    required this.monthlyData,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (monthlyData.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Text(
            "Belum ada data transaksi untuk grafik tren tahun ini.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Grafik Tren Uang Masuk vs Uang Keluar",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Tahun Anggaran 2026 • Koperasi CUM Pelita",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildLegendItem("Kas Masuk (KM)", const Color(0xFF10B981)),
                  _buildLegendItem("Kas Keluar (KK)", const Color(0xFFEF4444)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Area
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(),
                barTouchData: BarTouchDataNotifier.getTouchData(),
                titlesData: _getTitlesData(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: _getBarGroups(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getRawMaxVal() {
    double maxVal = 0;
    for (var item in monthlyData) {
      double km = (item['total_km'] ?? 0).toDouble();
      double kk = (item['total_kk'] ?? 0).toDouble();
      if (km > maxVal) maxVal = km;
      if (kk > maxVal) maxVal = kk;
    }
    return maxVal == 0 ? 10000000 : maxVal;
  }

  double _getInterval(double maxVal) {
    if (maxVal <= 20000000) return 5000000;
    if (maxVal <= 50000000) return 10000000;
    if (maxVal <= 100000000) return 20000000;
    if (maxVal <= 250000000) return 50000000;
    return (maxVal * 1.25 / 4).roundToDouble() > 0 ? (maxVal * 1.25 / 4).roundToDouble() : 10000000;
  }

  double _getMaxY() {
    final double maxVal = _getRawMaxVal();
    final double interval = _getInterval(maxVal);
    return ((maxVal * 1.25) / interval).ceil() * interval;
  }

  static String _formatRupiahCompact(double val) {
    if (val == 0) return "0";
    if (val >= 1000000000) return "${(val / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}M";
    if (val >= 1000000) return "${(val / 1000000).toStringAsFixed(1).replaceAll('.0', '')}Jt";
    if (val >= 1000) return "${(val / 1000).toStringAsFixed(0)}Rb";
    return val.toStringAsFixed(0);
  }

  List<BarChartGroupData> _getBarGroups() {
    return List.generate(monthlyData.length, (index) {
      final item = monthlyData[index];
      final double km = (item['total_km'] ?? 0).toDouble();
      final double kk = (item['total_kk'] ?? 0).toDouble();

      return BarChartGroupData(
        x: index,
        barRods: [
          // Batang Kas Masuk (Hijau)
          BarChartRodData(
            toY: km,
            color: const Color(0xFF10B981),
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
          // Batang Kas Keluar (Merah)
          BarChartRodData(
            toY: kk,
            color: const Color(0xFFEF4444),
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  FlTitlesData _getTitlesData() {
    final double maxVal = _getRawMaxVal();
    final double interval = _getInterval(maxVal);

    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 52,
          interval: interval,
          getTitlesWidget: (double value, TitleMeta meta) {
            final double remainder = (value % interval).abs();
            final double epsilon = interval * 0.001;
            if (remainder > epsilon && (interval - remainder).abs() > epsilon) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              space: 4,
              child: Text(
                _formatRupiahCompact(value),
                style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (double value, TitleMeta meta) {
            int index = value.toInt();
            if (index >= 0 && index < monthlyData.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  monthlyData[index]['month'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }
}
