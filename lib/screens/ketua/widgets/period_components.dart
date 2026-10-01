import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../data/models/period_model.dart';
import '../../../utils/navigation_utils.dart';

/// 📘 1. CARD STATUS PERIODE AKTIF (DESAIN INDIGO PRESISI)
class ActivePeriodCard extends StatelessWidget {
  final PeriodModel period;

  const ActivePeriodCard({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.adminNavy, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.adminNavy.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BADGE PERIODE AKTIF
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: const Row(
                  children: [
                    Text('● ', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(
                      'PERIODE AKTIF',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // LABEL PERIODE & STATUS
          Text(
            period.periodName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (period.startDate.isNotEmpty && period.endDate.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${period.startDate}  s/d  ${period.endDate}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Status: ${period.isLocked ? "Dikunci & Dibekukan" : "Terbuka untuk Entri Data"}',
            style: TextStyle(
              fontSize: 12.5,
              color: period.isLocked ? AppColors.danger : const Color(0xFF34D399),
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 18),

          // 2 GRID INFO BOX (DATA TRANSAKSI & WAKTU TERSISA)
          Row(
            children: [
              Expanded(
                child: _infoGridBox(
                  label: 'DATA TRANSAKSI',
                  val: '${period.totalTransactions} Entri',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoGridBox(
                  label: 'WAKTU TERSISA',
                  val: '${period.remainingDays} Hari',
                  icon: Icons.timer_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoGridBox({required String label, required String val, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.adminAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9.5, color: Colors.white60, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  val,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔴 2. CARD PERINGATAN KEAMANAN RED BOX
class SecurityWarningCard extends StatelessWidget {
  const SecurityWarningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peringatan Keamanan',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Penutupan buku adalah tindakan permanen. Seluruh data keuangan untuk periode ini akan dibekukan, akses perubahan akan dikunci, dan saldo akhir akan dikonsolidasi menjadi saldo awal periode baru.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔐 3. DIALOG KONFIRMASI RINGKAS TUTUP BUKU
class ClosePeriodConfirmDialog extends StatelessWidget {
  final PeriodModel period;
  final VoidCallback onSubmitClose;

  const ClosePeriodConfirmDialog({
    super.key,
    required this.period,
    required this.onSubmitClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tutup Buku & Kunci Periode?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Text(
          'Periode akuntansi akan dikunci dan seluruh data SHU tahunan akan dikalkulasi secara permanen. Apakah Anda yakin ingin melanjutkan?',
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => NavigationUtils.safePop(context),
          child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            NavigationUtils.safePop(context);
            onSubmitClose();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Ya, Kunci Periode'),
        ),
      ],
    );
  }
}

/// 📅 4. DIALOG BUKA PERIODE BARU / ATUR RENTANG TANGGAL (CUSTOM DATE RANGE PICKER)
class OpenNewPeriodDialog extends StatefulWidget {
  final Function({
    required String periodName,
    required DateTime startDate,
    required DateTime endDate,
  }) onSubmitOpen;

  const OpenNewPeriodDialog({
    super.key,
    required this.onSubmitOpen,
  });

  @override
  State<OpenNewPeriodDialog> createState() => _OpenNewPeriodDialogState();
}

class _OpenNewPeriodDialogState extends State<OpenNewPeriodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _periodNameController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;

  final List<String> _indoMonths = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, 6, 1);
    _endDate = DateTime(now.year + 1, 5, 31);
    _updateDefaultPeriodName();
  }

  void _updateDefaultPeriodName() {
    _periodNameController.text =
        '${_indoMonths[_startDate.month - 1]} ${_startDate.year} - ${_indoMonths[_endDate.month - 1]} ${_endDate.year}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')} ${_indoMonths[dt.month - 1]} ${dt.year}';
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.adminNavy,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.adminNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _updateDefaultPeriodName();
      });
    }
  }

  @override
  void dispose() {
    _periodNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.edit_calendar_rounded, color: AppColors.adminNavy, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Buka Periode Baru / Atur Tanggal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tentukan rentang tanggal mulai dan tanggal selesai periode akuntansi baru sesuai keputusan pengurus/RAT.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _periodNameController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama Periode wajib diisi!';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Nama Periode Akuntansi',
                  hintText: 'Contoh: Juni 2026 - Mei 2027',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outlined),
                ),
              ),

              const SizedBox(height: 14),

              // CUSTOM DATE RANGE SELECTION CARD
              InkWell(
                onTap: _selectDateRange,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rentang Tanggal Periode:',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatDate(_startDate)}  s/d  ${_formatDate(_endDate)}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_outlined, color: AppColors.primary, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => NavigationUtils.safePop(context),
          child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final periodName = _periodNameController.text.trim();
              NavigationUtils.safePop(context);
              widget.onSubmitOpen(
                periodName: periodName,
                startDate: _startDate,
                endDate: _endDate,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.adminNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Simpan & Buka Periode'),
        ),
      ],
    );
  }
}
