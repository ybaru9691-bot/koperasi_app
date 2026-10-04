import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';

class LedgerItem {
  final String date;
  final String voucherNumber;
  final String description;
  final double debit;
  final double credit;
  final double runningBalance;

  LedgerItem({
    required this.date,
    required this.voucherNumber,
    required this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });

  factory LedgerItem.fromJson(Map<String, dynamic> json) {
    return LedgerItem(
      date: (json['transaction_date'] ?? json['date'] ?? '-').toString(),
      voucherNumber: (json['voucher_number'] ?? json['receipt_number'] ?? json['reference_no'] ?? '-').toString(),
      description: (json['description'] ?? json['notes'] ?? '-').toString(),
      debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      runningBalance: (json['running_balance'] ?? json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AdminKeuanganScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const AdminKeuanganScreen({super.key, this.onOpenDrawer});

  @override
  State<AdminKeuanganScreen> createState() => _AdminKeuanganScreenState();
}

class _AdminKeuanganScreenState extends State<AdminKeuanganScreen> {
  bool _isLoading = false;
  bool _isExportingPdf = false;
  bool _isExportingExcel = false;
  bool _hasSearched = false;
  String? _errorMessage;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  
  String _accountCode = '1000';
  String _accountName = 'Kas';
  double _beginningBalance = 0.0;
  List<LedgerItem> _ledgerItems = [];
  List<Map<String, dynamic>> _coas = [];

  // Server-Side Pagination States
  int _currentPage = 1;
  int _lastPage = 1;
  int _perPage = 25;
  int _totalEntries = 0;

  @override
  void initState() {
    super.initState();
    _fetchCOA();
  }

  Future<void> _fetchCOA() async {
    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/chart-of-accounts');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> coaList = [];
        if (decoded is List) {
          coaList = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] is List) {
            coaList = decoded['data'] as List;
          } else if (decoded['accounts'] is List) {
            coaList = decoded['accounts'] as List;
          } else if (decoded['reports'] is List) {
            coaList = decoded['reports'] as List;
          }
        }
        if (mounted) {
          setState(() {
            _coas = coaList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            if (_coas.isNotEmpty && !_coas.any((c) => c['account_code'] == _accountCode)) {
              _accountCode = _coas.first['account_code']?.toString() ?? '1000';
              _accountName = _coas.first['account_name']?.toString() ?? 'Kas';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Exception COA API: $e');
    }
  }

  Future<void> _fetchLedger({int? page}) async {
    if (page != null) {
      _currentPage = page;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final token = await AuthService().getToken();
      final start = _startDate.toIso8601String().split('T')[0];
      final end = _endDate.toIso8601String().split('T')[0];
      
      final uri = Uri.parse(
        '${AuthService.staticBaseUrl}/ledger?account_code=$_accountCode&start_date=$start&end_date=$end&page=$_currentPage&per_page=$_perPage',
      );
      
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        Map<String, dynamic> payload = {};
        List<dynamic> itemsList = [];

        if (decoded is Map) {
          if (decoded['data'] is Map) {
            payload = Map<String, dynamic>.from(decoded['data'] as Map);
          } else {
            payload = Map<String, dynamic>.from(decoded);
          }

          itemsList = (payload['entries'] as List?) ??
                      (payload['data'] as List?) ??
                      (payload['journals'] as List?) ??
                      (payload['transactions'] as List?) ??
                      (payload['reports'] as List?) ??
                      (decoded['entries'] as List?) ??
                      (decoded['data'] as List?) ??
                      (decoded['journals'] as List?) ??
                      [];

          _currentPage = (payload['current_page'] as num?)?.toInt() ?? _currentPage;
          _lastPage = (payload['last_page'] as num?)?.toInt() ?? 1;
          _totalEntries = (payload['total'] as num?)?.toInt() ?? itemsList.length;
          _perPage = (payload['per_page'] as num?)?.toInt() ?? _perPage;
        } else if (decoded is List) {
          itemsList = decoded;
          _totalEntries = itemsList.length;
          _lastPage = 1;
        }

        if (mounted) {
          setState(() {
            _accountName = payload['account_name']?.toString() ?? _accountName;
            _beginningBalance = (payload['opening_balance'] ??
                    payload['beginning_balance'] ??
                    payload['initial_balance'] ??
                    payload['saldo_awal'] as num?)
                ?.toDouble() ??
                0.0;
            
            _ledgerItems = itemsList
                .whereType<Map>()
                .map((e) => LedgerItem.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            
            // Tambahkan baris Saldo Awal hanya di halaman 1
            if (_currentPage == 1) {
              _ledgerItems.insert(0, LedgerItem(
                date: '-',
                voucherNumber: '-',
                description: 'Saldo Awal',
                debit: 0.0,
                credit: 0.0,
                runningBalance: _beginningBalance,
              ));
            }

            _isLoading = false;
          });
        }
      } else {
        debugPrint('Error Ledger API (${response.statusCode}): ${response.body}');
        if (mounted) {
          setState(() {
            _errorMessage = 'Gagal memuat data (Code: ${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Exception Ledger API: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan jaringan: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String _formatRupiah(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  Future<void> _exportReport(String type) async {
    final isPdf = type.toLowerCase() == 'pdf';
    if (isPdf && _isExportingPdf) return;
    if (!isPdf && _isExportingExcel) return;

    setState(() {
      if (isPdf) {
        _isExportingPdf = true;
      } else {
        _isExportingExcel = true;
      }
    });

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Menyiapkan file ${type.toUpperCase()} Buku Besar...'),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final token = await AuthService().getToken();
      final start = _startDate.toIso8601String().split('T')[0];
      final end = _endDate.toIso8601String().split('T')[0];

      final endpoint = isPdf ? 'export-pdf' : 'export-excel';
      final url = '${AuthService.staticBaseUrl}/ledger/$endpoint?account_code=$_accountCode&start_date=$start&end_date=$end';

      debugPrint('Target Export URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': isPdf
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final mimeType = isPdf
            ? 'application/pdf'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        final extension = isPdf ? 'pdf' : 'xlsx';
        final filename = 'Buku_Besar_${_accountCode}_${start}_sd_$end.$extension';

        final blob = html.Blob([response.bodyBytes], mimeType);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = blobUrl
          ..download = filename;
        html.document.body?.children.add(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(blobUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil mengunduh $filename'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[EXPORT_ERROR] Gagal export Buku Besar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export laporan: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isPdf) {
            _isExportingPdf = false;
          } else {
            _isExportingExcel = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: AppBar(
        title: const Text('Buku Besar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: widget.onOpenDrawer,
        ),
        actions: [
          _isExportingPdf
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                  tooltip: 'Export PDF',
                  onPressed: () => _exportReport('pdf'),
                ),
          _isExportingExcel
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.table_view, color: Colors.white),
                  tooltip: 'Export Excel',
                  onPressed: () => _exportReport('excel'),
                ),
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: 'Filter Tanggal',
            onPressed: _selectDateRange,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Memuat data Buku Besar...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _fetchLedger(page: 1),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Filter Card: Akun COA + Tanggal + Tombol Tampilkan
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _coas.any((c) => c['account_code'] == _accountCode) ? _accountCode : null,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Akun COA',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _coas.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['account_code']?.toString(),
                          child: Text('${c['account_code']} - ${c['account_name']}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _accountCode = val;
                            final selected = _coas.firstWhere((c) => c['account_code'] == val, orElse: () => {});
                            _accountName = selected['account_name']?.toString() ?? _accountName;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      '${_startDate.toLocal().toString().split(' ')[0]} s/d ${_endDate.toLocal().toString().split(' ')[0]}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _fetchLedger(page: 1),
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Tampilkan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.adminNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (!_hasSearched)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Pilih Akun COA dan Rentang Tanggal, lalu klik "Tampilkan"',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Header Info Saldo Awal & Akun
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Akun: $_accountCode - $_accountName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Periode: ${_startDate.toLocal().toString().split(' ')[0]} s/d ${_endDate.toLocal().toString().split(' ')[0]}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Saldo Awal', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text(_formatRupiah(_beginningBalance), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _ledgerItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Tidak ada mutasi buku besar pada periode ini', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.1)),
                        columns: const [
                          DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('No. Bukti', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Keterangan', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Debit', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Kredit', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Saldo Berjalan', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _ledgerItems.map((item) {
                          final isSaldoAwal = item.description == 'Saldo Awal';
                          return DataRow(
                            color: isSaldoAwal
                                ? WidgetStateProperty.all(const Color(0xFFF1F5F9))
                                : null,
                            cells: [
                              DataCell(Text(item.date)),
                              DataCell(Text(item.voucherNumber)),
                              DataCell(Text(item.description, style: TextStyle(fontWeight: isSaldoAwal ? FontWeight.bold : FontWeight.normal))),
                              DataCell(Text(isSaldoAwal ? '-' : _formatRupiah(item.debit), style: const TextStyle(color: AppColors.success))),
                              DataCell(Text(isSaldoAwal ? '-' : _formatRupiah(item.credit), style: const TextStyle(color: AppColors.danger))),
                              DataCell(Text(_formatRupiah(item.runningBalance), style: const TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          _buildPaginationFooter(),
        ],
      ],
    );
  }

  Widget _buildPaginationFooter() {
    if (_ledgerItems.isEmpty && _totalEntries == 0) return const SizedBox.shrink();

    final int startItem = _totalEntries == 0 ? 0 : (_currentPage - 1) * _perPage + 1;
    final int endItem = (_currentPage * _perPage > _totalEntries) ? _totalEntries : _currentPage * _perPage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 650;
          if (isNarrow) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Data $startItem-$endItem dari $_totalEntries',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    _perPageDropdown(),
                  ],
                ),
                const SizedBox(height: 8),
                _paginationControls(),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Menampilkan $startItem - $endItem dari $_totalEntries mutasi',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 16),
                  const Text('Baris per hal:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  _perPageDropdown(),
                ],
              ),
              _paginationControls(),
            ],
          );
        },
      ),
    );
  }

  Widget _perPageDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _perPage,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
          items: const [
            DropdownMenuItem(value: 15, child: Text('15 baris')),
            DropdownMenuItem(value: 25, child: Text('25 baris')),
            DropdownMenuItem(value: 50, child: Text('50 baris')),
            DropdownMenuItem(value: 100, child: Text('100 baris')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _perPage = val);
              _fetchLedger(page: 1);
            }
          },
        ),
      ),
    );
  }

  Widget _paginationControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageBtn(
          icon: Icons.first_page_rounded,
          tooltip: 'Halaman Pertama',
          enabled: _currentPage > 1,
          onPressed: () => _fetchLedger(page: 1),
        ),
        const SizedBox(width: 4),
        _pageBtn(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Sebelumnya',
          enabled: _currentPage > 1,
          onPressed: () => _fetchLedger(page: _currentPage - 1),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            'Halaman $_currentPage dari $_lastPage',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
        ),
        const SizedBox(width: 8),
        _pageBtn(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Selanjutnya',
          enabled: _currentPage < _lastPage,
          onPressed: () => _fetchLedger(page: _currentPage + 1),
        ),
        const SizedBox(width: 4),
        _pageBtn(
          icon: Icons.last_page_rounded,
          tooltip: 'Halaman Terakhir',
          enabled: _currentPage < _lastPage,
          onPressed: () => _fetchLedger(page: _lastPage),
        ),
      ],
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
