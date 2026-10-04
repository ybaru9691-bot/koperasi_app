import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../data/models/pending_approval_model.dart';
import '../../services/auth_service.dart';
import '../../utils/navigation_utils.dart';
import 'widgets/approval_components.dart';

// HALAMAN UTAMA PERSETUJUAN / APPROVAL TRANSAKSI KETUA KOPERASI (RESPONSIF)
class TransactionApprovalScreen extends StatefulWidget {   
  final Function(String id)? onApproveCallback;
  final Function(String id, String reason)? onRejectCallback;

  const TransactionApprovalScreen({
    super.key,
    this.onApproveCallback,
    this.onRejectCallback,
  });

  @override
  State<TransactionApprovalScreen> createState() => _TransactionApprovalScreenState();
}

class _TransactionApprovalScreenState extends State<TransactionApprovalScreen> {
  List<PendingApprovalModel> _allApprovals = [];
  String _selectedStatusFilter = 'pending'; // 'pending', 'disetujui', 'ditolak'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApprovals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PendingApprovalModel _mapLoanToApproval(Map<String, dynamic> j, String targetStatus) {
    return PendingApprovalModel(
      id: j['id']?.toString() ?? '',
      refCode: j['loan_code'] ?? j['no_ref'] ?? '',
      date: j['application_date'] ?? j['created_at'] ?? '',
      memberName: j['member_name'] ?? j['member']?['name'] ?? '',
      memberNo: j['member_no'] ?? j['member']?['member_number'] ?? '',
      adminOperator: 'Admin Pelita',
      category: 'Pinjaman: ${j['purpose'] ?? "Dana Anggota"}',
      type: 'Pinjaman',
      amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0.0,
      status: targetStatus,
      notes: 'Agunan: ${j['collateral'] ?? "-"}',
    );
  }

  PendingApprovalModel _mapTxToApproval(Map<String, dynamic> j, String targetStatus) {
    final String typeStr = j['type']?.toString().toLowerCase() ?? '';
    final String typeVal = typeStr == 'withdrawal' ? 'KK' : 'KM';
    return PendingApprovalModel(
      id: j['id']?.toString() ?? '',
      refCode: j['receipt_number'] ?? j['transaction_number'] ?? '',
      date: j['transaction_date'] ?? j['created_at'] ?? '',
      memberName: j['member_name'] ?? j['member']?['name'] ?? 'Umum',
      memberNo: j['member_no'] ?? j['member']?['member_number'] ?? '-',
      adminOperator: j['operator']?['name'] ?? 'Admin Pelita',
      category: j['description'] ?? 'Transaksi Kas',
      type: typeVal,
      amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0.0,
      status: targetStatus,
      notes: j['description'] ?? '',
    );
  }

  Future<void> _fetchApprovals() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthService().getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // 1. Fetch pending
      final pendingLoansRes = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/admin/loans?status=pending_manager'),
        headers: headers,
      );
      final pendingTxRes = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/transactions/pending'),
        headers: headers,
      );

      // 2. Fetch approved
      final approvedLoansRes = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/admin/loans?status=approved'),
        headers: headers,
      );
      final allTxRes = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/transactions'),
        headers: headers,
      );

      // 3. Fetch rejected
      final rejectedLoansRes = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/admin/loans?status=rejected'),
        headers: headers,
      );

      List<PendingApprovalModel> temp = [];

      // Parse pending loans
      if (pendingLoansRes.statusCode == 200) {
        final body = jsonDecode(pendingLoansRes.body);
        final raw = body['data'];
        List list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw['data'] is List) {
          list = raw['data'];
        }
        for (var item in list) {
          temp.add(_mapLoanToApproval(item, 'pending'));
        }
      }

      // Parse pending transactions
      if (pendingTxRes.statusCode == 200) {
        final body = jsonDecode(pendingTxRes.body);
        final raw = body['data'];
        List list = [];
        if (raw is List) {
          list = raw;
        }
        for (var item in list) {
          temp.add(_mapTxToApproval(item, 'pending'));
        }
      }

      // Parse approved loans
      if (approvedLoansRes.statusCode == 200) {
        final body = jsonDecode(approvedLoansRes.body);
        final raw = body['data'];
        List list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw['data'] is List) {
          list = raw['data'];
        }
        for (var item in list) {
          temp.add(_mapLoanToApproval(item, 'disetujui'));
        }
      }

      // Parse all transactions to split into approved and rejected
      if (allTxRes.statusCode == 200) {
        final body = jsonDecode(allTxRes.body);
        final raw = body['data'];
        List list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw['data'] is List) {
          list = raw['data'];
        }
        for (var item in list) {
          final stat = item['status']?.toString().toLowerCase() ?? '';
          if (stat == 'approved' || stat == 'disetujui') {
            temp.add(_mapTxToApproval(item, 'disetujui'));
          } else if (stat == 'rejected' || stat == 'ditolak') {
            temp.add(_mapTxToApproval(item, 'ditolak'));
          }
        }
      }

      // Parse rejected loans
      if (rejectedLoansRes.statusCode == 200) {
        final body = jsonDecode(rejectedLoansRes.body);
        final raw = body['data'];
        List list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw['data'] is List) {
          list = raw['data'];
        }
        for (var item in list) {
          temp.add(_mapLoanToApproval(item, 'ditolak'));
        }
      }

      if (mounted) {
        setState(() {
          _allApprovals = temp;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[MANAGER_APPROVAL] Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Filtered list berdasarkan tab status & search query
  List<PendingApprovalModel> get _filteredList {
    return _allApprovals.where((item) {
      final matchesStatus = item.status == _selectedStatusFilter;
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          item.refCode.toLowerCase().contains(q) ||
          item.memberName.toLowerCase().contains(q) ||
          item.adminOperator.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  // AKSI APPROVE (SETUJUI)
  void _handleApprove(PendingApprovalModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
              SizedBox(width: 10),
              Text('Konfirmasi Persetujuan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menyetujui pengajuan ${item.refCode} dari ${item.memberName}?',
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationUtils.safePop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                NavigationUtils.safePop(dialogContext);

                // Show a loading SnackBar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Memproses persetujuan...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                try {
                  final token = await AuthService().getToken();
                  final String url = item.type == 'Pinjaman'
                      ? '${AuthService.staticBaseUrl}/admin/loans/${item.id}/approve-manager'
                      : '${AuthService.staticBaseUrl}/manager/approvals/${item.id}/approve';

                  final res = await http.post(
                    Uri.parse(url),
                    headers: {
                      'Accept': 'application/json',
                      if (token != null) 'Authorization': 'Bearer $token',
                    },
                  ).timeout(const Duration(seconds: 60));

                  if (res.statusCode == 200 || res.statusCode == 201) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Pengajuan ${item.refCode} berhasil DISETUJUI!'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _fetchApprovals();
                  } else if (res.statusCode == 404) {
                    if (!mounted) return;
                    setState(() {
                      _allApprovals.removeWhere((a) => a.id == item.id);
                    });
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data pengajuan sudah tidak tersedia di server. Daftar telah diperbarui.'),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _fetchApprovals();
                  } else {
                    final body = jsonDecode(res.body);
                    final msg = body['message'] ?? 'Gagal memproses persetujuan.';
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ya, Setujui'),
            ),
          ],
        );
      },
    );
  }

  ///  AKSI REJECT (TOLAK)
  void _handleReject(PendingApprovalModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return RejectReasonDialog(
          item: item,
          onSubmitReject: (reason) async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Memproses penolakan...'),
                  ],
                ),
                duration: Duration(seconds: 2),
              ),
            );

            try {
              final token = await AuthService().getToken();
              final String url = item.type == 'Pinjaman'
                  ? '${AuthService.staticBaseUrl}/admin/loans/${item.id}/reject'
                  : '${AuthService.staticBaseUrl}/manager/approvals/${item.id}/reject';

              final res = await http.post(
                Uri.parse(url),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  if (token != null) 'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'rejection_reason': reason,
                  'notes': reason,
                }),
              ).timeout(const Duration(seconds: 60));

              if (res.statusCode == 200 || res.statusCode == 201) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pengajuan ${item.refCode} berhasil DITOLAK!'),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _fetchApprovals();
              } else if (res.statusCode == 404) {
                if (!mounted) return;
                setState(() {
                  _allApprovals.removeWhere((a) => a.id == item.id);
                });
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data pengajuan sudah tidak tersedia di server. Daftar telah diperbarui.'),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _fetchApprovals();
              } else {
                final body = jsonDecode(res.body);
                final msg = body['message'] ?? 'Gagal menolak pengajuan.';
                if (!mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      },
    );
  }

  ///  TAMPILKAN DIALOG DETAIL
  void _showDetailDialog(PendingApprovalModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ApprovalDetailDialog(
          item: item,
          onApprove: () => _handleApprove(item),
          onReject: () => _handleReject(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _allApprovals.where((a) => a.status == 'pending').length;
    final approvedCount = _allApprovals.where((a) => a.status == 'disetujui').length;
    final rejectedCount = _allApprovals.where((a) => a.status == 'ditolak').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return RefreshIndicator(
          onRefresh: _fetchApprovals,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24.0 : 12.0,
              vertical: 16.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER & SEARCH BAR
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.rule_rounded, color: AppColors.primary, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Persetujuan & ACC Transaksi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.adminNavy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tinjau dan verifikasi transaksi KM/KK yang di-input oleh Admin & Teller Koperasi',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),

                        // Search Input Box
                        SizedBox(
                          width: isDesktop ? 320 : double.infinity,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            decoration: InputDecoration(
                              hintText: 'Cari No Ref, Nama, Operator...',
                              hintStyle: const TextStyle(fontSize: 12.5),
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.cardBorder),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 2. QUICK ACTION STATUS TABS
                    Row(
                      children: [
                        _statusTabButton('Menunggu Persetujuan', 'pending', pendingCount, AppColors.warning),
                        const SizedBox(width: 8),
                        _statusTabButton('Disetujui', 'disetujui', approvedCount, AppColors.success),
                        const SizedBox(width: 8),
                        _statusTabButton('Ditolak', 'ditolak', rejectedCount, AppColors.danger),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3. APPROVAL CARDS LIST
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_filteredList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedStatusFilter == 'pending'
                                  ? Icons.task_alt_rounded
                                  : Icons.find_in_page_rounded,
                              color: AppColors.textMuted,
                              size: 44,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tidak Ada Transaksi ${_selectedStatusFilter == "pending" ? "Menunggu ACC" : _selectedStatusFilter}',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Semua transaksi dalam kategori ini telah diproses atau tidak ditemukan.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredList.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _filteredList[index];
                          return ApprovalCardWidget(
                            item: item,
                            onTapDetail: () => _showDetailDialog(item),
                            onQuickApprove: () => _handleApprove(item),
                            onQuickReject: () => _handleReject(item),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _statusTabButton(String label, String value, int count, Color activeColor) {
    final bool isSelected = _selectedStatusFilter == value;

    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.adminNavy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.adminNavy : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : AppColors.adminCanvas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
