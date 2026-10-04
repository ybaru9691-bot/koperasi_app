import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/edit_transaction_dialog.dart';

class TransactionItem {
  final int id;
  final String date;
  final String transactionNumber;
  final String receiptNumber;
  final String description;
  final double amount;
  final String type;
  final String memberName;
  final String memberNumber; // NBA
  final int? memberId;

  TransactionItem({
    required this.id,
    required this.date,
    required this.transactionNumber,
    required this.receiptNumber,
    required this.description,
    required this.amount,
    required this.type,
    required this.memberName,
    required this.memberNumber,
    this.memberId,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['transaction_date'] ?? json['date'] ?? json['created_at'] ?? '').toString().trim();
    String formattedDate = '-';
    if (rawDate.isNotEmpty) {
      final cleanDate = rawDate.split('T')[0].split(' ')[0];
      formattedDate = cleanDate;
    }
    return TransactionItem(
      id:                json['id'] ?? 0,
      date:              formattedDate,
      transactionNumber: (json['transaction_number'] ?? '-').toString(),
      receiptNumber:     (json['receipt_number'] ?? json['formatted_receipt_no'] ?? '-').toString(),
      description:       (json['description'] ?? '-').toString(),
      amount:            json['amount'] != null ? double.tryParse(json['amount'].toString()) ?? 0.0 : 0.0,
      type:              (json['type'] ?? '').toString(),
      memberName:        json['member']?['name']?.toString() ?? '-',
      memberNumber:      json['member']?['member_number']?.toString() ?? '-',
      memberId:          json['member_id'] as int?,
    );
  }
}

class AdminTransaksiScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const AdminTransaksiScreen({super.key, this.onOpenDrawer});

  @override
  State<AdminTransaksiScreen> createState() => _AdminTransaksiScreenState();
}

class _AdminTransaksiScreenState extends State<AdminTransaksiScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _selectedType = 'Semua';
  String _selectedBookType = 'Semua'; // 'Semua', 'BUKU_BIRU', 'BUKU_PUTIH'
  final TextEditingController _searchController = TextEditingController();

  // Server-Side Pagination States
  int _currentPage = 1;
  int _lastPage = 1;
  int _perPage = 25;
  int _totalTransactions = 0;

  List<TransactionItem> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions({int? page}) async {
    if (page != null) {
      _currentPage = page;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService().getToken();
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final searchQuery = _searchController.text.trim();
      final searchParam = searchQuery.isNotEmpty ? '&search=${Uri.encodeComponent(searchQuery)}' : '';
      final bookTypeParam = _selectedBookType != 'Semua' ? '&book_type=$_selectedBookType' : '';
      
      final uri = Uri.parse(
        '${AuthService.staticBaseUrl}/transactions?page=$_currentPage&per_page=$_perPage&start_date=$startStr&end_date=$endStr&type=$_selectedType$searchParam$bookTypeParam',
      );
      
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> itemsList = [];

        if (decoded is Map) {
          final dataField = decoded['data'];
          if (dataField is Map && dataField['data'] is List) {
            itemsList = dataField['data'] as List; // Laravel paginated response
            _currentPage = (dataField['current_page'] as num?)?.toInt() ?? _currentPage;
            _lastPage = (dataField['last_page'] as num?)?.toInt() ?? 1;
            _totalTransactions = (dataField['total'] as num?)?.toInt() ?? itemsList.length;
            _perPage = (dataField['per_page'] as num?)?.toInt() ?? _perPage;
          } else if (dataField is List) {
            itemsList = dataField;
            _totalTransactions = itemsList.length;
            _lastPage = 1;
          } else if (decoded['transactions'] is List) {
            itemsList = decoded['transactions'] as List;
            _totalTransactions = itemsList.length;
            _lastPage = 1;
          }
        } else if (decoded is List) {
          itemsList = decoded;
          _totalTransactions = itemsList.length;
          _lastPage = 1;
        }

        if (mounted) {
          setState(() {
            _transactions = itemsList
                .whereType<Map>()
                .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Gagal memuat data (Code: ${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan jaringan: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTransaction(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini?\n\nTindakan ini akan mengembalikan saldo Kas dan saldo Simpanan Anggota ke keadaan semula secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/transactions/$id');
      final response = await http.delete(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil dihapus'), backgroundColor: Colors.green),
        );
        _fetchTransactions();
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal menghapus: ${response.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── EDIT TRANSAKSI 
  Future<void> _showEditDialog(TransactionItem item) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => EditTransactionDialog(transaction: item),
    );

    if (result != null && mounted) {
      if (result is Map && result['success'] == true) {
        final DateTime? newDate = result['newDate'] as DateTime?;
        if (newDate != null) {
          final startOnly = DateTime(_startDate.year, _startDate.month, _startDate.day);
          final endOnly = DateTime(_endDate.year, _endDate.month, _endDate.day);
          final targetOnly = DateTime(newDate.year, newDate.month, newDate.day);

          if (targetOnly.isBefore(startOnly)) {
            _startDate = targetOnly;
          }
          if (targetOnly.isAfter(endOnly)) {
            _endDate = targetOnly;
          }
        }
        _fetchTransactions();
      } else if (result == true) {
        _fetchTransactions();
      }
    }
  }




  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchTransactions(page: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: Builder(
          builder: (btnContext) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: widget.onOpenDrawer ?? () {
              try { Scaffold.of(btnContext).openDrawer(); } catch (_) {}
            },
          ),
        ),
        title: const Text('Manajemen Transaksi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: 'Filter Tanggal',
            onPressed: _selectDateRange,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              return isNarrow
                  ? Column(
                      children: [
                        Row(
                          children: [
                            // 1. Dropdown Tipe Transaksi
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _selectedType,
                                decoration: const InputDecoration(
                                  labelText: 'Tipe Transaksi',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Semua', child: Text('Semua Tipe')),
                                  DropdownMenuItem(value: 'deposit', child: Text('Kas Masuk (Deposit)')),
                                  DropdownMenuItem(value: 'withdrawal', child: Text('Kas Keluar (Withdrawal)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedType = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 2. Dropdown Jenis Buku
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _selectedBookType,
                                decoration: const InputDecoration(
                                  labelText: 'Jenis Buku',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Semua', child: Text('Semua Buku')),
                                  DropdownMenuItem(value: 'BUKU_BIRU', child: Text('Buku Biru')),
                                  DropdownMenuItem(value: 'BUKU_PUTIH', child: Text('Buku Putih')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedBookType = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // 3. Input Box Pencarian Transaksi
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Pencarian Transaksi',
                            hintText: 'Cari Nama Anggota, No. Bukti, atau Keterangan...',
                            hintStyle: const TextStyle(fontSize: 11.5),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                      _fetchTransactions(page: 1);
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (_) => _fetchTransactions(page: 1),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _fetchTransactions(page: 1),
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('Terapkan Filter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.adminNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // 1. Dropdown Tipe Transaksi
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Tipe Transaksi',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Semua', child: Text('Semua Tipe')),
                              DropdownMenuItem(value: 'deposit', child: Text('Kas Masuk (Deposit)')),
                              DropdownMenuItem(value: 'withdrawal', child: Text('Kas Keluar (Withdrawal)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedType = val;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 2. Dropdown Jenis Buku
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedBookType,
                            decoration: const InputDecoration(
                              labelText: 'Jenis Buku',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Semua', child: Text('Semua Buku')),
                              DropdownMenuItem(value: 'BUKU_BIRU', child: Text('Buku Biru')),
                              DropdownMenuItem(value: 'BUKU_PUTIH', child: Text('Buku Putih')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedBookType = val;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 3. Input Box Pencarian Transaksi
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Pencarian Transaksi',
                              hintText: 'Cari Nama Anggota, No. Bukti, atau Keterangan...',
                              hintStyle: const TextStyle(fontSize: 12),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                        _fetchTransactions(page: 1);
                                      },
                                    )
                                  : null,
                            ),
                            onSubmitted: (_) => _fetchTransactions(page: 1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 4. Tombol Terapkan Filter
                        ElevatedButton.icon(
                          onPressed: () => _fetchTransactions(page: 1),
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('Terapkan Filter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.adminNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFF8FAFC),
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter Aktif:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    'Periode: ${DateFormat('yyyy-MM-dd').format(_startDate)} s/d ${DateFormat('yyyy-MM-dd').format(_endDate)} | Tipe: $_selectedType | Buku: ${_selectedBookType == 'BUKU_BIRU' ? 'Buku Biru' : _selectedBookType == 'BUKU_PUTIH' ? 'Buku Putih' : 'Semua'}${_searchController.text.trim().isNotEmpty ? ' | Cari: "${_searchController.text.trim()}"' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Text(
                'Total: $_totalTransactions Transaksi',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('Tidak ada transaksi pada filter ini', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.1)),
                      columns: const [
                        DataColumn(label: Text('No. Bukti', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Nama Anggota / Uraian', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Jenis Pos', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Nominal', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _transactions.map((item) {
                        final isDeposit = item.type == 'deposit';
                        return DataRow(
                          cells: [
                            DataCell(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item.receiptNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (item.date.isNotEmpty)
                                  Text(
                                    item.date.split('T')[0].split(' ')[0],
                                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                                  ),
                              ],
                            )),
                            DataCell(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item.memberName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(item.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDeposit ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(isDeposit ? 'Kas Masuk' : 'Kas Keluar', style: TextStyle(color: isDeposit ? Colors.green : Colors.red, fontSize: 12)),
                            )),
                            DataCell(Text(_formatRupiah(item.amount), style: TextStyle(color: isDeposit ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Tombol Edit (biru)
                                  Tooltip(
                                    message: 'Edit / Koreksi Transaksi',
                                    child: InkWell(
                                      onTap: () => _showEditDialog(item),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[700]!.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.blue[700]!.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_outlined, size: 14, color: Colors.blue[700]),
                                            const SizedBox(width: 4),
                                            Text('Edit', style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Tombol Hapus (merah)
                                  Tooltip(
                                    message: 'Hapus Transaksi',
                                    child: InkWell(
                                      onTap: () => _deleteTransaction(item.id),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.delete_outline, size: 14, color: Colors.red[700]),
                                            const SizedBox(width: 4),
                                            Text('Hapus', style: TextStyle(fontSize: 12, color: Colors.red[700], fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
        _buildPaginationFooter(),
      ],
    );
  }

  Widget _buildPaginationFooter() {
    if (_transactions.isEmpty && _totalTransactions == 0) return const SizedBox.shrink();

    final int startItem = _totalTransactions == 0 ? 0 : (_currentPage - 1) * _perPage + 1;
    final int endItem = (_currentPage * _perPage > _totalTransactions) ? _totalTransactions : _currentPage * _perPage;

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
                      'Data $startItem-$endItem dari $_totalTransactions',
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
                    'Menampilkan $startItem - $endItem dari $_totalTransactions transaksi',
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
              _fetchTransactions(page: 1);
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
          onPressed: () => _fetchTransactions(page: 1),
        ),
        const SizedBox(width: 4),
        _pageBtn(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Sebelumnya',
          enabled: _currentPage > 1,
          onPressed: () => _fetchTransactions(page: _currentPage - 1),
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
          onPressed: () => _fetchTransactions(page: _currentPage + 1),
        ),
        const SizedBox(width: 4),
        _pageBtn(
          icon: Icons.last_page_rounded,
          tooltip: 'Halaman Terakhir',
          enabled: _currentPage < _lastPage,
          onPressed: () => _fetchTransactions(page: _lastPage),
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

