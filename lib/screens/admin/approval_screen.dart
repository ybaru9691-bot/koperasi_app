import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

/// Model Item Pengajuan Persetujuan Admin
class ApprovalModel {
  final String id;
  final String memberName;
  final String memberNo;
  final String type;
  final num amount;
  final String date;
  String status; // 'pending', 'disetujui', 'ditolak'

  ApprovalModel({
    required this.id,
    required this.memberName,
    required this.memberNo,
    required this.type,
    required this.amount,
    required this.date,
    this.status = 'pending',
  });

  factory ApprovalModel.fromJson(Map<String, dynamic> json) {
    return ApprovalModel(
      id: json['id']?.toString() ?? '',
      memberName: json['member_name'] ?? json['nama_anggota'] ?? json['member']?['name'] ?? '',
      memberNo: json['member_no'] ?? json['no_buku'] ?? json['member']?['member_number'] ?? '',
      type: json['type'] ?? 'Pengajuan Pinjaman Baru',
      amount: json['total_loan_amount'] ?? json['amount'] ?? json['plafon'] ?? 0,
      date: json['created_at'] ?? json['date'] ?? json['tgl_pengajuan'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }
}

/// Screen "Persetujuan / Approval" Khusus Admin Koperasi
class ApprovalScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const ApprovalScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ApprovalModel> _allApprovals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchApprovalsFromApi();
  }

  Future<void> _fetchApprovalsFromApi() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await AuthService().getToken();
      final response = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/admin/loans/pending'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List data = body['data'] ?? body;
        if (mounted) {
          setState(() {
            _allApprovals = data.map((item) => ApprovalModel.fromJson(item)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching approvals: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  Future<void> _updateStatus(ApprovalModel item, String newStatus) async {
    try {
      final token = await AuthService().getToken();
      final isApprove = newStatus == 'disetujui';
      final endpoint = isApprove
          ? '${AuthService.staticBaseUrl}/admin/loans/${item.id}/approve-admin'
          : '${AuthService.staticBaseUrl}/admin/loans/${item.id}/reject-admin';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: isApprove
            ? jsonEncode({
                'interest_rate_percent': 2.5,
                'admin_fee': 50000,
                'due_date_day': 20,
                'admin_notes': 'Disetujui dari Persetujuan Admin',
              })
            : jsonEncode({
                'admin_notes': 'Ditolak dari Persetujuan Admin',
              }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          item.status = newStatus;
        });

        if (mounted) {
          final String message = newStatus == 'disetujui'
              ? 'Pengajuan ${item.memberName} (${item.type}) BERHASIL DISETUJUI!'
              : 'Pengajuan ${item.memberName} (${item.type}) TELAH DITOLAK.';

          final Color bg = newStatus == 'disetujui' ? AppColors.success : AppColors.danger;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: bg,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _fetchApprovalsFromApi();
      } else if (response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _allApprovals.removeWhere((a) => a.id == item.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data pengajuan pinjaman sudah tidak tersedia di server. Daftar telah diperbarui.'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _fetchApprovalsFromApi();
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Gagal memperbarui status pengajuan.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<ApprovalModel> _filterByStatus(String status) {
    return _allApprovals.where((a) => a.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          tooltip: 'Menu Admin',
          onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text(
          'Persetujuan Pengajuan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.adminAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Disetujui'),
            Tab(text: 'Ditolak'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _fetchApprovalsFromApi,
              color: AppColors.primary,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildApprovalList(_filterByStatus('pending')),
                  _buildApprovalList(_filterByStatus('disetujui')),
                  _buildApprovalList(_filterByStatus('ditolak')),
                ],
              ),
            ),
    );
  }

  Widget _buildApprovalList(List<ApprovalModel> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Tidak ada pengajuan dalam kategori ini',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        item.memberName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'No. ${item.memberNo}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(item.status),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                item.type,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.adminNavy,
                ),
              ),
              const SizedBox(height: 4),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nominal: ${_formatRupiah(item.amount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    item.date,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),

              if (item.status == 'pending') ...[
                const Divider(height: 20, color: AppColors.cardBorder),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateStatus(item, 'ditolak'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(item, 'disetujui'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Setujui'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'disetujui':
        bg = AppColors.successBg;
        fg = AppColors.success;
        label = 'Disetujui';
        break;
      case 'ditolak':
        bg = AppColors.dangerBg;
        fg = AppColors.danger;
        label = 'Ditolak';
        break;
      default:
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
