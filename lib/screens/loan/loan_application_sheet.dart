import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

///  Reusable Modal Bottom Sheet untuk Pengajuan Pinjaman Baru
/// Dilengkapi batasan tinggi fleksibel (FractionallySizedBox), SingleChildScrollView,
/// dan padding insets dinamis untuk mencegah overflow 48px saat keyboard aktif.
class LoanApplicationSheet extends StatefulWidget {
  final VoidCallback? onSuccess;

  const LoanApplicationSheet({
    super.key,
    this.onSuccess,
  });

  /// Helper statis untuk memanggil bottom sheet dengan aman
  static Future<void> show(BuildContext context, {VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: LoanApplicationSheet(onSuccess: onSuccess),
      ),
    );
  }

  @override
  State<LoanApplicationSheet> createState() => _LoanApplicationSheetState();
}

class _LoanApplicationSheetState extends State<LoanApplicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _collateralController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();

  String _selectedTenor = '12 Bulan';
  String _selectedInterestMethod = 'declining_balance'; // 'declining_balance' (2.50%) or 'flat' (1.00%)
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _collateralController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  String _fmtRp(num val) {
    if (val == 0) return 'Rp 0';
    return 'Rp ${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Map<String, double> _calcInstallmentEst(double amount, int tenor, String method, double ratePercent) {
    if (amount <= 0 || tenor <= 0) {
      return {'pokok': 0, 'jasa': 0, 'total': 0};
    }
    final double pokok = (amount / tenor).roundToDouble();
    final double jasa = (amount * (ratePercent / 100)).roundToDouble();
    return {'pokok': pokok, 'jasa': jasa, 'total': pokok + jasa};
  }

  Future<void> _submitApplication() async {
    final cleanAmount = _amountController.text.replaceAll('.', '').replaceAll('Rp', '').trim();
    final purposeText = _purposeController.text.trim();
    final collateralText = _collateralController.text.trim();

    final amountVal = double.tryParse(cleanAmount);
    if (amountVal == null || amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal pinjaman wajib diisi dan harus lebih besar dari 0!'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await AuthService().getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final double rate = _selectedInterestMethod == 'flat' ? 1.00 : 2.50;
      final int tenorMonths = int.tryParse(_selectedTenor.split(' ')[0]) ?? 12;

      final response = await http.post(
        Uri.parse('${AuthService.staticBaseUrl}/user/loans/apply'),
        headers: headers,
        body: jsonEncode({
          'amount': amountVal,
          'tenor': tenorMonths,
          'interest_method': _selectedInterestMethod,
          'interest_rate': rate,
          'purpose': purposeText,
          'collateral': collateralText,
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan Pinjaman Berhasil Dikirim!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSuccess?.call();
      } else {
        final body = jsonDecode(response.body);
        throw body['message'] ?? 'Gagal mengirim pengajuan.';
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double selectedInterestRate = _selectedInterestMethod == 'flat' ? 1.00 : 2.50;
    final String rawAmt = _amountController.text.replaceAll('.', '').trim();
    final double nominalVal = double.tryParse(rawAmt) ?? 0;
    final int tenorVal = int.tryParse(_selectedTenor.split(' ')[0]) ?? 12;
    final est = _calcInstallmentEst(nominalVal, tenorVal, _selectedInterestMethod, selectedInterestRate);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Top drag handle indicator
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Scrollable Form Content (Prevent Bottom Overflow)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 10,
                left: 20,
                right: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengajuan Pinjaman Baru',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Koperasi Credit Union CUM Pelita',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.cardBorder),
                    const Text(
                      'Isi nominal, jangka waktu, dan skema bunga yang Anda butuhkan.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),

                    // 1. Nominal Pinjaman
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final cleanVal = val.replaceAll('.', '').replaceAll('Rp', '').replaceAll(' ', '').replaceAll(',', '').trim();
                        final amount = double.tryParse(cleanVal) ?? 0;
                        setState(() {
                          if (amount >= 50000000) {
                            _selectedInterestMethod = 'flat';
                          } else {
                            _selectedInterestMethod = 'declining_balance';
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Nominal Pinjaman (Rp)',
                        hintText: 'Contoh: 10.000.000',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Tenor Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTenor,
                      decoration: InputDecoration(
                        labelText: 'Jangka Waktu (Tenor)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      items: ['3 Bulan', '6 Bulan', '12 Bulan', '18 Bulan', '24 Bulan', '36 Bulan', '48 Bulan', '60 Bulan']
                          .map((tenor) => DropdownMenuItem(value: tenor, child: Text(tenor)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedTenor = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 3. Pilihan Skema Suku Bunga
                    const Text(
                      'Skema Suku Bunga',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedInterestMethod = 'declining_balance'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _selectedInterestMethod == 'declining_balance'
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedInterestMethod == 'declining_balance'
                                      ? AppColors.primary
                                      : AppColors.cardBorder,
                                  width: _selectedInterestMethod == 'declining_balance' ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _selectedInterestMethod == 'declining_balance'
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        size: 16,
                                        color: _selectedInterestMethod == 'declining_balance'
                                            ? AppColors.primary
                                            : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Saldo Menurun',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '2,50% / bulan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedInterestMethod = 'flat'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _selectedInterestMethod == 'flat'
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedInterestMethod == 'flat'
                                      ? const Color(0xFF3B82F6)
                                      : AppColors.cardBorder,
                                  width: _selectedInterestMethod == 'flat' ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _selectedInterestMethod == 'flat'
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        size: 16,
                                        color: _selectedInterestMethod == 'flat'
                                            ? const Color(0xFF2563EB)
                                            : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Bunga Tetap / Flat',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '1,00% / bulan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 4. Kartu Simulasi Estimasi Angsuran
                    if (nominalVal > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedInterestMethod == 'flat' ? const Color(0xFFF0F7FF) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedInterestMethod == 'flat' ? const Color(0xFF93C5FD) : const Color(0xFF86EFAC),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calculate_rounded,
                                  size: 16,
                                  color: _selectedInterestMethod == 'flat' ? const Color(0xFF1D4ED8) : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedInterestMethod == 'flat'
                                      ? 'Estimasi Tagihan Bulanan (Flat 1.00%)'
                                      : 'Estimasi Tagihan Bulan ke-1 (Menurun 2.50%)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedInterestMethod == 'flat' ? const Color(0xFF1E40AF) : AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _simRow('Angsuran Pokok', _fmtRp(est['pokok']!)),
                            const SizedBox(height: 4),
                            _simRow(
                              _selectedInterestMethod == 'flat' ? 'Jasa Flat 1.00% / bln' : 'Jasa 2.50% (Bln 1)',
                              _fmtRp(est['jasa']!),
                              highlight: true,
                            ),
                            Divider(
                              height: 14,
                              color: _selectedInterestMethod == 'flat' ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                            ),
                            _simRow(
                              _selectedInterestMethod == 'flat' ? 'Total Angsuran per Bulan' : 'Total Tagihan Bln 1',
                              _fmtRp(est['total']!),
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 5. Jaminan / Agunan
                    TextField(
                      controller: _collateralController,
                      decoration: InputDecoration(
                        labelText: 'Jaminan / Agunan',
                        hintText: 'BPKB Motor / Sertifikat Tanah / BPKB Mobil',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. Keperluan / Alasan Pinjaman
                    TextField(
                      controller: _purposeController,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: 'Keperluan / Alasan Pinjaman',
                        hintText: 'Jelaskan alasan pengajuan pinjaman Anda...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // 7. Tombol Kirim Pengajuan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitApplication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Kirim Pengajuan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simRow(String label, String value, {bool bold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: highlight ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
