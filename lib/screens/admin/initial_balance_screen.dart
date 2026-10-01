import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/currency_input_formatter.dart';
import '../../utils/navigation_utils.dart';

class InitialBalanceItem {
  final String accountCode;
  String accountName;
  String normalBalance; // 'DEBIT' or 'CREDIT'
  String category;
  final TextEditingController controller;

  InitialBalanceItem({
    required this.accountCode,
    required this.accountName,
    required this.normalBalance,
    required this.category,
    required this.controller,
  });

  int get amount {
    final raw = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }
}

/// Layar Pengaturan Saldo Awal Cut-Off Pembukuan (Debit & Kredit Seimbang)
class InitialBalanceScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const InitialBalanceScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<InitialBalanceScreen> createState() => _InitialBalanceScreenState();
}

class _InitialBalanceScreenState extends State<InitialBalanceScreen> {
  DateTime _cutoffDate = DateTime(2026, 5, 1);
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _savedVoucherNumber;
  bool _isAlreadySaved = false;

  late List<InitialBalanceItem> _items;

  // Daftar Lengkap 17 Akun Standar Baku Pembukuan Koperasi HKBP Dame
  // 6 Akun DEBIT: Kas (1000, 1010), Piutang (1024), Inventaris & Gedung (1700, 1741, 1743)
  // 11 Akun KREDIT: Simpanan (2020, 2021, 2022), Dana-dana (2032, 2033, 2034, 2038), Cadangan Modal (3010, 3020), Akumulasi Penyusutan (3101, 3102)
  final List<Map<String, String>> _defaultAccounts = const [
    {
      'code': '1000',
      'name': 'Kas Utama (Brankas)',
      'normal': 'DEBIT',
      'category': 'Kas & Bank',
    },
    {
      'code': '1010',
      'name': 'Kas Bank BRI',
      'normal': 'DEBIT',
      'category': 'Kas & Bank',
    },
    {
      'code': '1024',
      'name': 'Piutang Pinjaman Anggota',
      'normal': 'DEBIT',
      'category': 'Piutang Pinjaman',
    },
    {
      'code': '1700',
      'name': 'Inventaris Tanah',
      'normal': 'DEBIT',
      'category': 'Aset Tetap',
    },
    {
      'code': '1741',
      'name': 'Inventaris Perl. Kantor',
      'normal': 'DEBIT',
      'category': 'Aset Tetap',
    },
    {
      'code': '1743',
      'name': 'Inventaris Kendaraan Kantor',
      'normal': 'DEBIT',
      'category': 'Aset Tetap',
    },
    {
      'code': '2020',
      'name': 'Simpanan Saham (SP, SW, SS)',
      'normal': 'CREDIT',
      'category': 'Simpanan Saham',
    },
    {
      'code': '2021',
      'name': 'Simpanan Harian (Buku Putih)',
      'normal': 'CREDIT',
      'category': 'Simpanan Harian',
    },
    {
      'code': '2022',
      'name': 'Simpanan Diakonia',
      'normal': 'CREDIT',
      'category': 'Simpanan',
    },
    {
      'code': '2032',
      'name': 'Asuransi Investasi',
      'normal': 'CREDIT',
      'category': 'Dana-dana',
    },
    {
      'code': '2033',
      'name': 'Dana Pegawai / Karyawan',
      'normal': 'CREDIT',
      'category': 'Dana-dana',
    },
    {
      'code': '2034',
      'name': 'Dana Sosial Koperasi',
      'normal': 'CREDIT',
      'category': 'Dana-dana',
    },
    {
      'code': '2038',
      'name': 'Dana Duka Anggota',
      'normal': 'CREDIT',
      'category': 'Dana-dana',
    },
    {
      'code': '3010',
      'name': 'Cadangan Umum',
      'normal': 'CREDIT',
      'category': 'Modal & Cadangan',
    },
    {
      'code': '3020',
      'name': 'Cadangan Modal / Modal Awal',
      'normal': 'CREDIT',
      'category': 'Modal & Cadangan',
    },
    {
      'code': '3101',
      'name': 'Akumulasi Penyusutan Inventaris',
      'normal': 'CREDIT',
      'category': 'Akumulasi Penyusutan',
    },
    {
      'code': '3102',
      'name': 'Akumulasi Penyusutan Gedung',
      'normal': 'CREDIT',
      'category': 'Akumulasi Penyusutan',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initItems();
    _fetchInitialBalances();
  }

  void _initItems() {
    _items = _defaultAccounts.map((acc) {
      final ctrl = TextEditingController();
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      return InitialBalanceItem(
        accountCode: acc['code']!,
        accountName: acc['name']!,
        normalBalance: acc['normal']!,
        category: acc['category']!,
        controller: ctrl,
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.controller.dispose();
    }
    super.dispose();
  }

  int get _totalDebit {
    return _items
        .where((item) => item.normalBalance.toUpperCase() == 'DEBIT')
        .fold(0, (sum, item) => sum + item.amount);
  }

  int get _totalCredit {
    return _items
        .where((item) => item.normalBalance.toUpperCase() == 'CREDIT')
        .fold(0, (sum, item) => sum + item.amount);
  }

  int get _difference {
    return (_totalDebit - _totalCredit).abs();
  }

  bool get _isBalanced {
    return _totalDebit > 0 && (_totalDebit - _totalCredit).abs() == 0;
  }

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  static String _formatCurrencyValue(num val) {
    if (val <= 0) return '';
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  Future<void> _fetchInitialBalances() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_cutoffDate);

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/initial-balances?cutoff_date=$dateStr');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];

        if (data != null) {
          _savedVoucherNumber = data['voucher_number']?.toString();
          _isAlreadySaved = data['is_saved'] == true;

          List itemsData = [];
          if (data is List) {
            itemsData = data;
          } else if (data is Map) {
            if (data['items'] is List) {
              itemsData = data['items'] as List;
            } else if (data['accounts'] is List) {
              itemsData = data['accounts'] as List;
            }
          }

          final Map<String, Map<String, dynamic>> serverItemsMap = {};

          for (var raw in itemsData) {
            if (raw is Map) {
              final code = raw['account_code']?.toString() ?? raw['code']?.toString() ?? '';
              if (code.isNotEmpty) {
                serverItemsMap[code] = Map<String, dynamic>.from(raw);
              }
            }
          }

          // Sinkronisasi data ke list item yang ada (menggunakan nama riil dari response backend)
          final Set<String> populatedCodes = {};
          for (var item in _items) {
            populatedCodes.add(item.accountCode);
            final serverItem = serverItemsMap[item.accountCode];
            if (serverItem != null) {
              final accName = (serverItem['account_name'] ?? serverItem['name'])?.toString();
              if (accName != null && accName.isNotEmpty) {
                item.accountName = accName;
              }
              final normBal = (serverItem['normal_balance'] ?? serverItem['normal'] ?? serverItem['type'])?.toString();
              if (normBal != null && normBal.isNotEmpty) {
                item.normalBalance = normBal.toUpperCase();
              }
              final cat = (serverItem['category'] ?? serverItem['group'])?.toString();
              if (cat != null && cat.isNotEmpty) {
                item.category = cat;
              }
              final amt = (serverItem['amount'] ?? serverItem['balance'] ?? serverItem['initial_balance'] as num?)?.toDouble() ?? 0.0;
              item.controller.text = _formatCurrencyValue(amt);
            } else {
              item.controller.clear();
            }
          }

          // Tambahkan akun tambahan dari backend jika belum ada di default 17 akun
          for (var entry in serverItemsMap.entries) {
            if (!populatedCodes.contains(entry.key)) {
              final serverItem = entry.value;
              final ctrl = TextEditingController();
              ctrl.addListener(() {
                if (mounted) setState(() {});
              });
              final amt = (serverItem['amount'] ?? serverItem['balance'] ?? serverItem['initial_balance'] as num?)?.toDouble() ?? 0.0;
              ctrl.text = _formatCurrencyValue(amt);

              String norm = (serverItem['normal_balance']?.toString() ?? serverItem['normal']?.toString() ?? 'DEBIT').toUpperCase();
              if (entry.key.startsWith('2') || entry.key.startsWith('3')) {
                norm = 'CREDIT';
              }

              final accName = (serverItem['account_name'] ?? serverItem['name'])?.toString() ?? 'Akun ${entry.key}';

              _items.add(
                InitialBalanceItem(
                  accountCode: entry.key,
                  accountName: accName,
                  normalBalance: norm,
                  category: serverItem['category']?.toString() ?? 'Lain-lain',
                  controller: ctrl,
                ),
              );
            }
          }
        }
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat saldo awal (Status ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveInitialBalances() async {
    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jurnal saldo awal belum seimbang! Total Debet (${_formatRupiah(_totalDebit)}) harus sama dengan Total Kredit (${_formatRupiah(_totalCredit)}).',
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_cutoffDate);
    final payloadItems = _items.map((item) {
      return {
        'account_code': item.accountCode,
        'account_name': item.accountName,
        'normal_balance': item.normalBalance,
        'amount': item.amount,
      };
    }).toList();

    final payload = {
      'cutoff_date': dateStr,
      'description': 'Saldo Awal Cut-Off Pembukuan - $dateStr',
      'items': payloadItems,
    };

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/initial-balances');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && (body['success'] == true || body['status'] == 'success')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Saldo Awal Cut-Off Pembukuan berhasil disimpan & dijurnal otomatis!'),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchInitialBalances();
      } else {
        final msg = body['message']?.toString() ?? 'Gagal menyimpan saldo awal ke server.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan koneksi: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectCutoffDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _cutoffDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _cutoffDate) {
      setState(() => _cutoffDate = picked);
      _fetchInitialBalances();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBalanced = _isBalanced;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: Builder(
          builder: (btnContext) => NavigationUtils.buildSafeLeadingIcon(
            btnContext: btnContext,
            onOpenDrawer: widget.onOpenDrawer,
          ),
        ),
        title: const Text(
          'Saldo Awal Pembukuan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Muat Ulang',
            onPressed: _fetchInitialBalances,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _fetchInitialBalances,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _buildContent(isBalanced),
    );
  }

  Widget _buildContent(bool isBalanced) {
    final String dateFormatted = DateFormat('dd MMMM yyyy', 'id_ID').format(_cutoffDate);

    return Column(
      children: [
        // 1. Header Pengaturan & DatePicker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 650;
              final headerInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: AppColors.adminNavy, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Pengaturan Saldo Awal Cut-Off Pembukuan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.adminNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tetapkan saldo awal kas, bank, piutang, aset inventaris, simpanan, dana, dan modal per tanggal cut-off agar buku besar & neraca seimbang.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (_isAlreadySaved && _savedVoucherNumber != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        '✓ Tersimpan di Jurnal Voucher: $_savedVoucherNumber',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                    ),
                  ],
                ],
              );

              final dateSelector = InkWell(
                onTap: _selectCutoffDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tanggal Cut-Off:',
                            style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            dateFormatted,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    ],
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    const SizedBox(height: 12),
                    dateSelector,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerInfo),
                  const SizedBox(width: 16),
                  dateSelector,
                ],
              );
            },
          ),
        ),

        // 2. Tabel Input Saldo Awal Akun (Dapat di-scroll secara penuh, state controller tidak ter-reset)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 720),
                    child: SizedBox(
                      width: 720,
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            color: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: const Row(
                              children: [
                                SizedBox(width: 40, child: Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                SizedBox(width: 80, child: Text('Kode (COA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Expanded(flex: 3, child: Text('Nama Perkiraan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                SizedBox(width: 110, child: Text('Sifat Posisi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('Nominal Saldo Awal (Rp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),

                          // Table Rows (Column-based rendering to permanently retain all controllers during scroll)
                          Column(
                            children: List.generate(_items.length, (index) {
                              final item = _items[index];
                              final bool isDebit = item.normalBalance.toUpperCase() == 'DEBIT';

                              return Container(
                                key: ValueKey('account_row_${item.accountCode}'),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: index == _items.length - 1 ? Colors.transparent : const Color(0xFFF1F5F9),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // 1. Nomor Urut
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 12),
                                      ),
                                    ),

                                    // 2. Kode Akun
                                    SizedBox(
                                      width: 80,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.accountCode,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.adminNavy),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),

                                    // 3. Nama Perkiraan & Kategori
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.accountName,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                                            ),
                                            Text(
                                              item.category,
                                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 4. Sifat (Debet / Kredit)
                                    SizedBox(
                                      width: 110,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDebit ? Colors.blue.shade50 : Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isDebit ? Colors.blue.shade300 : Colors.amber.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isDebit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                              size: 14,
                                              color: isDebit ? Colors.blue.shade800 : Colors.amber.shade900,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isDebit ? 'DEBET' : 'KREDIT',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDebit ? Colors.blue.shade800 : Colors.amber.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 5. Input Nominal Saldo Awal
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: SizedBox(
                                          width: 180,
                                          height: 38,
                                          child: TextFormField(
                                            key: ValueKey('input_field_${item.accountCode}'),
                                            controller: item.controller,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.right,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              CurrencyInputFormatter(),
                                            ],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            decoration: InputDecoration(
                                              prefixText: 'Rp ',
                                              prefixStyle: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black54,
                                              ),
                                              hintText: '0',
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              isDense: true,
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 3. Footer Indikator Keseimbangan & Tombol Aksi
        _buildFooterBalanceBar(isBalanced),
      ],
    );
  }

  Widget _buildFooterBalanceBar(bool isBalanced) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 750;

          final balanceCards = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total Debet Card
              _statBox(
                label: 'TOTAL DEBET',
                value: _formatRupiah(_totalDebit),
                color: const Color(0xFF1D4ED8),
                bg: const Color(0xFFEFF6FF),
              ),
              const SizedBox(width: 12),

              // Total Kredit Card
              _statBox(
                label: 'TOTAL KREDIT',
                value: _formatRupiah(_totalCredit),
                color: const Color(0xFFB45309),
                bg: const Color(0xFFFEF3C7),
              ),
              const SizedBox(width: 12),

              // Status Seimbang / Selisih Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isBalanced ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isBalanced ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBalanced ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 18,
                      color: isBalanced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBalanced ? 'SEIMBANG' : 'BELUM SEIMBANG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isBalanced ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                        Text(
                          isBalanced ? 'Selisih Rp 0' : 'Selisih ${_formatRupiah(_difference)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isBalanced ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final saveButton = ElevatedButton.icon(
            onPressed: (_isSaving || !isBalanced) ? null : _saveInitialBalances,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Saldo Awal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF94A3B8),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: isBalanced ? 2 : 0,
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: balanceCards,
                ),
                const SizedBox(height: 12),
                saveButton,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              balanceCards,
              saveButton,
            ],
          );
        },
      ),
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
