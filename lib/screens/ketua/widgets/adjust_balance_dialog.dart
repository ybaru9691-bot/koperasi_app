import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/auth_service.dart';
import '../../../utils/currency_input_formatter.dart';

class AdjustBalanceFormDialog extends StatefulWidget {
  final bool isExpense;
  final VoidCallback? onSuccess;

  const AdjustBalanceFormDialog({
    super.key,
    required this.isExpense,
    this.onSuccess,
  });

  @override
  State<AdjustBalanceFormDialog> createState() => _AdjustBalanceFormDialogState();
}

class _AdjustBalanceFormDialogState extends State<AdjustBalanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  List<dynamic> _coaList = [];
  String? _selectedCoa;
  DateTime _selectedDate = DateTime.now();
  
  final TextEditingController _voucherNumberOnlyController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _voucherErrorText;

  @override
  void initState() {
    super.initState();
    _fetchCoaList();
  }

  @override
  void dispose() {
    _voucherNumberOnlyController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoaList() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi tidak valid, harap login kembali.'))
          );
        }
        return;
      }

      final categoryQuery = widget.isExpense ? 'expense' : 'income';
      final uri = Uri.parse('${AuthService.staticBaseUrl}/accounts?category=$categoryQuery');
      
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> accounts = data['data'] ?? [];

          if (mounted) {
            setState(() {
              _coaList = accounts;
              if (_coaList.isNotEmpty) {
                _selectedCoa = _coaList.first['account_code'];
              }
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Gagal memuat data akun'))
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Terjadi kesalahan server (${response.statusCode})'))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data akun: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCoa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Akun COA terlebih dahulu!'))
      );
      return;
    }

    final rawValue = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double amount = double.tryParse(rawValue) ?? 0.0;

    if (amount <= 0) {
      final errorMsg = widget.isExpense
          ? 'Nominal beban wajib diisi dan harus lebih dari 0.'
          : 'Nominal pemasukan wajib diisi dan harus lebih dari 0.';
      _showError(errorMsg);
      return;
    }

    setState(() {
      _voucherErrorText = null;
      _isSubmitting = true;
    });

    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) {
          _showError('Sesi tidak valid, harap login kembali.');
        }
        return;
      }

      final prefix = widget.isExpense ? 'KK ' : 'KM ';
      final cleanNumber = _voucherNumberOnlyController.text.trim();
      final fullVoucherNo = '$prefix$cleanNumber';

      final payload = {
        'voucher_no': fullVoucherNo,
        'account_code': _selectedCoa,
        'coa_id': _selectedCoa,
        'type': widget.isExpense ? 'expense' : 'income',
        'amount': amount,
        'description': _descController.text.trim(),
        'transaction_date': _selectedDate.toIso8601String().split('T')[0],
        'date': _selectedDate.toIso8601String().split('T')[0],
      };

      final uri = Uri.parse('${AuthService.staticBaseUrl}/manager/transactions/adjust-balance');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      Map<String, dynamic> resData = {};
      try {
        resData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (resData['success'] == true) {
          Navigator.of(context).pop(true);
          widget.onSuccess?.call();
          final String successMsg = widget.isExpense
              ? 'Pengeluaran berhasil dicatat ke Buku Kas Keluar (KK)!'
              : 'Pemasukan berhasil dicatat ke Buku Kas Masuk (KM)!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(successMsg)),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          _showError(resData['message'] ?? 'Gagal memproses transaksi');
        }
      } else if (response.statusCode == 422) {
        String errorMsg = resData['message'] ?? 'Validasi gagal';
        String? voucherError;

        if (resData['errors'] != null && resData['errors'] is Map) {
          final errorsMap = resData['errors'] as Map<String, dynamic>;
          if (errorsMap.containsKey('voucher_no') || errorsMap.containsKey('voucher_number') || errorsMap.containsKey('transaction_number')) {
            final vErrors = errorsMap['voucher_no'] ?? errorsMap['voucher_number'] ?? errorsMap['transaction_number'];
            voucherError = vErrors is List && vErrors.isNotEmpty
                ? vErrors.first.toString()
                : vErrors.toString();
            errorMsg = voucherError;
          } else if (errorsMap.isNotEmpty) {
            final firstKey = errorsMap.keys.first;
            final firstErrors = errorsMap[firstKey];
            errorMsg = firstErrors is List && firstErrors.isNotEmpty
                ? firstErrors.first.toString()
                : firstErrors.toString();
          }
        }

        final lowerMsg = (resData['message'] ?? '').toString().toLowerCase();
        if (lowerMsg.contains('nomor bukti') || lowerMsg.contains('voucher') || lowerMsg.contains('transaksi') || lowerMsg.contains('sudah ada')) {
          voucherError = resData['message'].toString();
          errorMsg = voucherError;
        }

        if (voucherError != null) {
          setState(() {
            _voucherErrorText = voucherError;
          });
        }

        _showError(errorMsg);
      } else {
        final rawMsg = (resData['message'] ?? '').toString();
        if (rawMsg.contains('SQLSTATE') || rawMsg.contains('1062') || rawMsg.contains('Duplicate entry') || rawMsg.contains('Integrity constraint violation')) {
          final prefixLabel = widget.isExpense ? 'KK' : 'KM';
          final friendlyMsg = 'Maaf, Transaksi $prefixLabel ini sudah ada coba lagi dengan no berbeda';
          setState(() {
            _voucherErrorText = friendlyMsg;
          });
          _showError(friendlyMsg);
        } else {
          _showError(rawMsg.isNotEmpty ? rawMsg : 'Server error: ${response.statusCode}');
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('SQLSTATE') || errorStr.contains('1062') || errorStr.contains('Duplicate entry') || errorStr.contains('Integrity constraint violation')) {
        final prefixLabel = widget.isExpense ? 'KK' : 'KM';
        final friendlyMsg = 'Maaf, Transaksi $prefixLabel ini sudah ada coba lagi dengan no berbeda';
        setState(() {
          _voucherErrorText = friendlyMsg;
        });
        _showError(friendlyMsg);
      } else {
        _showError('Terjadi kesalahan sistem: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isExpense ? 'Catat Beban / Pengeluaran Operasional' : 'Catat Pemasukan / Tambah Saldo';
    final headerColor = widget.isExpense ? AppColors.danger : AppColors.success;
    final icon = widget.isExpense ? Icons.remove_circle_outline : Icons.add_circle_outline;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: _isLoading 
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(icon, color: headerColor, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.heading2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Lengkapi form berikut untuk menyesuaikan saldo / beban.', style: AppTextStyles.bodyText),
                  const SizedBox(height: 16),

                  // Scrollable Form Fields
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Nomor Bukti (KK / KM)
                          Text(
                            widget.isExpense ? 'No. Bukti Kas Keluar (KK)' : 'No. Bukti Kas Masuk (KM)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _voucherNumberOnlyController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (val) {
                              if (_voucherErrorText != null) {
                                setState(() => _voucherErrorText = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: widget.isExpense ? 'No. Bukti (KK)' : 'No. Bukti (KM)',
                              prefixText: widget.isExpense ? 'KK ' : 'KM ',
                              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
                              hintText: widget.isExpense ? '0120' : '4691',
                              errorText: _voucherErrorText,
                              errorMaxLines: 3,
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Nomor bukti nota wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // 2. COA Dropdown
                          const Text('Pilih Kode Akun (COA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedCoa,
                            isExpanded: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            items: _coaList.map((coa) {
                              final code = (coa['account_code'] ?? '').toString();
                              String name = (coa['account_name'] ?? coa['display_label'] ?? '').toString();
                              name = name.replaceAll(RegExp(r'^\[.*?\]\s*'), '').trim();
                              return DropdownMenuItem<String>(
                                value: coa['account_code'],
                                child: Text('$code - $name'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCoa = val),
                            validator: (val) => val == null ? 'Wajib dipilih' : null,
                          ),
                          const SizedBox(height: 16),

                          // Date Picker
                          const Text('Tanggal Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                                  const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary, size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Amount
                          const Text('Nominal (Rp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CurrencyInputFormatter(),
                            ],
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              hintText: '0',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return widget.isExpense
                                    ? 'Nominal beban wajib diisi dan harus lebih dari 0.'
                                    : 'Nominal pemasukan wajib diisi dan harus lebih dari 0.';
                              }
                              final raw = val.replaceAll(RegExp(r'[^0-9]'), '');
                              final n = double.tryParse(raw) ?? 0.0;
                              if (n <= 0) {
                                return widget.isExpense
                                    ? 'Nominal beban wajib diisi dan harus lebih dari 0.'
                                    : 'Nominal pemasukan wajib diisi dan harus lebih dari 0.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description
                          const Text('Keterangan / Uraian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _descController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Cth: Pembayaran Tagihan Listrik / Pembelian ATK',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Keterangan wajib diisi';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons (Always visible at the bottom)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmitting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Simpan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
