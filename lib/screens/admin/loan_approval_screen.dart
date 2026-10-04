import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

/// Data Model untuk Pengajuan Pinjaman Multi-Level (User -> Admin -> Ketua)
class LoanApprovalModel {
  final String id;
  final String memberName;
  final String memberNo;
  final num amount;
  final int tenorMonths;
  final String purpose;
  final String collateral; // Master Jaminan / Agunan
  final String date;
  String status; // 'verifikasi_admin', 'menunggu_ketua', 'disetujui', 'ditolak'
  double interestRatePercent; // Default 2.5% / bulan
  int dueDateDay; // Default tanggal 20 setiap bulan
  num adminFee; // Default Rp 50.000
  String? adminNotes;
  String? kkVoucherCode; // Auto-generate 4 digit: KK 1042

  LoanApprovalModel({
    required this.id,
    required this.memberName,
    required this.memberNo,
    required this.amount,
    required this.tenorMonths,
    required this.purpose,
    required this.collateral,
    required this.date,
    required this.status,
    this.interestRatePercent = 2.50,
    this.dueDateDay = 20,
    this.adminFee = 50000,
    this.adminNotes,
    this.kkVoucherCode,
  });

  factory LoanApprovalModel.fromJson(Map<String, dynamic> json) {
    return LoanApprovalModel(
      id: json['id']?.toString() ?? '',
      memberName: json['member_name'] ?? json['nama_anggota'] ?? json['member']?['name'] ?? '',
      memberNo: json['member_no'] ?? json['no_buku'] ?? json['member']?['member_number'] ?? '',
      amount: json['amount'] ?? json['plafon'] ?? 0,
      tenorMonths: json['tenor_months'] ?? json['tenor'] ?? 0,
      purpose: json['purpose'] ?? json['keperluan'] ?? '',
      collateral: json['collateral'] ?? json['jaminan'] ?? '',
      date: json['date'] ?? json['tgl_pengajuan'] ?? json['created_at'] ?? '',
      status: json['status'] ?? 'verifikasi_admin',
      interestRatePercent: double.tryParse(json['interest_rate_percent']?.toString() ?? '2.50') ?? 2.50,
      dueDateDay: int.tryParse(json['due_date_day']?.toString() ?? '20') ?? 20,
      adminFee: double.tryParse(json['admin_fee']?.toString() ?? '50000') ?? 50000,
      adminNotes: json['admin_notes'],
      kkVoucherCode: json['kk_voucher_code'],
    );
  }
}

/// Screen "Persetujuan Pinjaman Multi-Level & Penerbitan Kartu Pinjaman" Khusus Admin / Pengurus
class LoanApprovalScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const LoanApprovalScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<LoanApprovalModel> _loans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchPendingLoans();
  }

  Future<void> _fetchPendingLoans() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await AuthService().getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // 1. Fetch pending loans
      final pendingResponse = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/admin/loans/pending'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));

      // 2. Fetch approved/completed loans
      final completedResponse = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/admin/loans?status=approved'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));

      List<LoanApprovalModel> tempLoans = [];

      if (pendingResponse.statusCode == 200) {
        final body = jsonDecode(pendingResponse.body);
        List pendingList = [];
        if (body is Map) {
          final raw = body['data'] ?? body['loans'];
          if (raw is List) {
            pendingList = raw;
          } else if (raw is Map && raw['data'] is List) {
            pendingList = raw['data'];
          }
        } else if (body is List) {
          pendingList = body;
        }
        tempLoans.addAll(pendingList.whereType<Map>().map((item) => LoanApprovalModel.fromJson(Map<String, dynamic>.from(item))));
      }

      if (completedResponse.statusCode == 200) {
        final body = jsonDecode(completedResponse.body);
        var rawData = body['data'];
        List completedList = [];
        if (rawData != null) {
          if (rawData is List) {
            completedList = rawData;
          } else if (rawData is Map && rawData['data'] is List) {
            completedList = rawData['data'];
          }
        }
        tempLoans.addAll(completedList.map((item) {
          final model = LoanApprovalModel.fromJson(item);
          if (model.status == 'approved') {
            model.status = 'disetujui';
          }
          return model;
        }));
      }

      if (mounted) {
        setState(() {
          _loans = tempLoans;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching pending loans: $e");
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

  // --- MODAL DIALOG PERSETUJUAN PENGAJUAN PINJAMAN (ADMIN APPROVAL) ---
  void _showApprovalDecisionModal(LoanApprovalModel loan) {
    final formKey = GlobalKey<FormState>();
    final rateController = TextEditingController(text: loan.interestRatePercent.toString());
    final notesController = TextEditingController(text: loan.adminNotes ?? '');
    int selectedDueDateDay = loan.dueDateDay;
    String decisionStatus = 'SETUJUI';
    bool isSubmitting = false;

    num parseNum(String text) {
      final clean = text.replaceAll(RegExp(r'[^0-9.]'), '');
      return clean.isEmpty ? 0 : num.parse(clean);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        String modalDecisionStatus = decisionStatus;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Modal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBackground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Persetujuan Pinjaman Admin',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                                  ),
                                  Text(
                                    '${loan.memberName} • No. Buku ${loan.memberNo}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Cek Portofolio Simpanan',
                                icon: const Icon(Icons.analytics_rounded, color: AppColors.primary),
                                onPressed: () => _showMemberConsiderationDialog(loan),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                                onPressed: () => Navigator.pop(modalContext),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Divider(height: 20, color: AppColors.cardBorder),

                      // 1. RINGKASAN DATA ANGGOTA (READ-ONLY CARD)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.adminCanvas,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RINGKASAN PENGAJUAN ANGGOTA',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.adminNavy, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 8),
                            _buildModalSummaryRow('Plafon Diajukan', _formatRupiah(loan.amount), isHighlight: true),
                            _buildModalSummaryRow('Tenor / Jangka', '${loan.tenorMonths} Bulan'),
                            _buildModalSummaryRow('Jaminan / Agunan', loan.collateral),
                            _buildModalSummaryRow('Tujuan Pinjaman', loan.purpose),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Pilihan Radio Decision Status (SETUJUI vs TOLAK)
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text('SETUJUI & VERIFIKASI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              selected: modalDecisionStatus == 'SETUJUI',
                              selectedColor: AppColors.primaryBackground,
                              labelStyle: TextStyle(
                                color: modalDecisionStatus == 'SETUJUI' ? AppColors.primary : AppColors.textSecondary,
                              ),
                              side: BorderSide(
                                color: modalDecisionStatus == 'SETUJUI' ? AppColors.primary : AppColors.cardBorder,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => modalDecisionStatus = 'SETUJUI');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text('TOLAK PENGAJUAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              selected: modalDecisionStatus == 'TOLAK',
                              selectedColor: AppColors.dangerBg,
                              labelStyle: TextStyle(
                                color: modalDecisionStatus == 'TOLAK' ? AppColors.danger : AppColors.textSecondary,
                              ),
                              side: BorderSide(
                                color: modalDecisionStatus == 'TOLAK' ? AppColors.danger : AppColors.cardBorder,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => modalDecisionStatus = 'TOLAK');
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // 2. FORM KEPUTUSAN ADMIN (Hanya jika SETUJUI)
                      if (modalDecisionStatus == 'SETUJUI') ...[
                        // Suku Bunga (%/bln) & Biaya Admin
                        TextFormField(
                          controller: rateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            final numVal = parseNum(val ?? '');
                            if (numVal <= 0) return 'Bunga wajib diisi';
                            return null;
                          },
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Jasa / Bunga (% / bln)',
                            isDense: true,
                            suffixText: '%',
                            prefixIcon: Icon(Icons.percent_rounded, color: AppColors.primary, size: 18),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Dropdown Tanggal Jatuh Tempo (1 - 31)
                        DropdownButtonFormField<int>(
                          initialValue: selectedDueDateDay,
                          decoration: const InputDecoration(
                            labelText: 'Tanggal Jatuh Tempo Setiap Bulan',
                            isDense: true,
                            prefixIcon: Icon(Icons.event_repeat_rounded, color: AppColors.primary, size: 18),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          items: List.generate(31, (i) => i + 1)
                              .map((day) => DropdownMenuItem(value: day, child: Text('Tanggal $day setiap bulan')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedDueDateDay = val;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 12),
                      ],

                      // Catatan Admin (Opsional / Wajib jika Tolak)
                      TextFormField(
                        controller: notesController,
                        validator: (val) {
                          if (modalDecisionStatus == 'TOLAK' && (val == null || val.trim().isEmpty)) {
                            return 'Alasan penolakan wajib diisi';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: modalDecisionStatus == 'TOLAK' ? 'Alasan Penolakan (Wajib)' : 'Catatan Admin (Opsional)',
                          hintText: modalDecisionStatus == 'TOLAK'
                              ? 'Masukkan alasan resmi penolakan pengajuan'
                              : 'Catatan tambahan pengurus / syarat khusus',
                          isDense: true,
                          prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 3. TOMBOL AKSI AKHIR
                      Row(
                        children: [
                          if (modalDecisionStatus == 'TOLAK')
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () async {
                                          if (formKey.currentState!.validate()) {
                                            setModalState(() => isSubmitting = true);
                                            try {
                                              final token = await AuthService().getToken();
                                              final response = await http.post(
                                                Uri.parse('${AuthService.staticBaseUrl}/admin/loans/${loan.id}/reject'),
                                                headers: {
                                                  'Content-Type': 'application/json',
                                                  'Accept': 'application/json',
                                                  if (token != null) 'Authorization': 'Bearer $token',
                                                },
                                                body: jsonEncode({
                                                  'reason': notesController.text.trim(),
                                                  'notes': notesController.text.trim(),
                                                }),
                                              ).timeout(const Duration(seconds: 60));

                                              if (response.statusCode == 200 || response.statusCode == 201) {
                                                await _fetchPendingLoans();
                                                if (context.mounted) {
                                                  Navigator.pop(modalContext);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Pengajuan Pinjaman ${loan.memberName} TELAH DITOLAK.'),
                                                      backgroundColor: AppColors.danger,
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }
                                              } else if (response.statusCode == 404) {
                                                if (mounted) {
                                                  setState(() {
                                                    _loans.removeWhere((l) => l.id == loan.id);
                                                  });
                                                }
                                                if (context.mounted) {
                                                  Navigator.pop(modalContext);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Data pengajuan pinjaman sudah tidak tersedia di server. Daftar telah diperbarui.'),
                                                      backgroundColor: AppColors.danger,
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }
                                                await _fetchPendingLoans();
                                              } else {
                                                final body = jsonDecode(response.body);
                                                final msg = body['message'] ?? 'Gagal menolak pengajuan.';
                                                if (context.mounted) {
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
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                                                    backgroundColor: Colors.red,
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            } finally {
                                              setModalState(() => isSubmitting = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.danger,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.cancel_rounded, size: 18),
                                  label: const Text('Tolak Pengajuan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () async {
                                          if (formKey.currentState!.validate()) {
                                            setModalState(() => isSubmitting = true);
                                            try {
                                              final token = await AuthService().getToken();
                                              final String currentStatus = loan.status.toLowerCase();
                                              final bool isAdminApproval = currentStatus == 'pending_admin' || currentStatus == 'verifikasi_admin';
                                              final String endpointSuffix = isAdminApproval ? 'approve-admin' : 'approve-manager';

                                              final response = await http.post(
                                                Uri.parse('${AuthService.staticBaseUrl}/admin/loans/${loan.id}/$endpointSuffix'),
                                                headers: {
                                                  'Content-Type': 'application/json',
                                                  'Accept': 'application/json',
                                                  if (token != null) 'Authorization': 'Bearer $token',
                                                },
                                                body: jsonEncode({
                                                  'interest_rate_percent': parseNum(rateController.text).toDouble(),
                                                  'admin_fee': 0.0,
                                                  'due_date_day': selectedDueDateDay,
                                                  'admin_notes': notesController.text.trim(),
                                                }),
                                              ).timeout(const Duration(seconds: 60));

                                              if (response.statusCode == 200 || response.statusCode == 201) {
                                                await _fetchPendingLoans();
                                                if (isAdminApproval) {
                                                  _tabController.animateTo(1);
                                                }
                                                if (context.mounted) {
                                                  Navigator.pop(modalContext);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'PENGAJUAN AN. ${loan.memberName} BERHASIL DIVERIFIKASI ADMIN! Menunggu Persetujuan Manajer.',
                                                      ),
                                                      backgroundColor: AppColors.success,
                                                      behavior: SnackBarBehavior.floating,
                                                      duration: const Duration(seconds: 4),
                                                    ),
                                                  );
                                                }
                                              } else if (response.statusCode == 404) {
                                                if (mounted) {
                                                  setState(() {
                                                    _loans.removeWhere((l) => l.id == loan.id);
                                                  });
                                                }
                                                if (context.mounted) {
                                                  Navigator.pop(modalContext);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Data pengajuan pinjaman sudah tidak tersedia di server. Daftar telah diperbarui.'),
                                                      backgroundColor: AppColors.danger,
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }
                                                await _fetchPendingLoans();
                                              } else {
                                                final body = jsonDecode(response.body);
                                                final msg = body['message'] ?? 'Gagal memproses verifikasi pengajuan.';
                                                if (context.mounted) {
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
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                                                    backgroundColor: Colors.red,
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            } finally {
                                              setModalState(() => isSubmitting = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.verified_rounded, size: 18),
                                  label: const Text(
                                    'Verifikasi & Teruskan ke Manajer',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalSummaryRow(String label, String val, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(
            val,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberConsiderationDialog(LoanApprovalModel loan) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppColors.adminNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pertimbangan Kredit: ${loan.memberName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No. Buku: ${loan.memberNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const SizedBox(height: 10),
                _buildInfoTile('Rencana Pinjaman', _formatRupiah(loan.amount)),
                _buildInfoTile('Tenor', '${loan.tenorMonths} Bulan'),
                _buildInfoTile('Jaminan / Agunan', loan.collateral),
                _buildInfoTile('Tujuan', loan.purpose),
                const Divider(height: 20, color: AppColors.cardBorder),
                const Text('Portofolio Simpanan Anggota:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                _buildInfoTile('Simpanan Pokok (SP)', 'Rp 200.000'),
                _buildInfoTile('Simpanan Wajib (SW)', 'Rp 240.000'),
                _buildInfoTile('Simpanan Sukarela (SS)', 'Rp 150.000'),
                _buildInfoTile('Total Saldo Simpanan', 'Rp 590.000', isHighlighted: true),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan Kredit: Anggota aktif, pembayaran simpanan wajib lancar tanpa tunggakan.',
                          style: TextStyle(fontSize: 11, color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showApprovalDecisionModal(loan);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proses Persetujuan'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String val, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  List<LoanApprovalModel> _getFilteredLoans(String stage) {
    if (stage == 'verifikasi_admin') {
      return _loans.where((l) => l.status == 'verifikasi_admin' || l.status == 'pending_admin').toList();
    } else if (stage == 'menunggu_ketua') {
      return _loans.where((l) => l.status == 'menunggu_ketua' || l.status == 'pending_manager').toList();
    } else {
      return _loans.where((l) => l.status == 'disetujui' || l.status == 'approved' || l.status == 'ditolak' || l.status == 'rejected').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: Builder(
          builder: (btnContext) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              tooltip: 'Menu Admin',
              onPressed: widget.onOpenDrawer ?? () {
                try {
                  Scaffold.of(btnContext).openDrawer();
                } catch (_) {}
              },
            );
          },
        ),
        title: const Text(
          'Persetujuan Pinjaman (Multi-Level)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.adminAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: '1. Verifikasi Admin'),
            Tab(text: '2. ACC Manajer'),
            Tab(text: '3. Selesai / Siap Cair'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLoanStageList(_getFilteredLoans('verifikasi_admin'), 'verifikasi_admin'),
                _buildLoanStageList(_getFilteredLoans('menunggu_ketua'), 'menunggu_ketua'),
                _buildLoanStageList(_getFilteredLoans('selesai'), 'selesai'),
              ],
            ),
    );
  }

  Widget _buildLoanStageList(List<LoanApprovalModel> items, String stage) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule_folder_rounded, size: 64, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Tidak ada pengajuan pinjaman pada tahapan ini',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final loan = items[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
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
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (stage == 'verifikasi_admin') {
                  _showApprovalDecisionModal(loan);
                } else {
                  _showMemberConsiderationDialog(loan);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              loan.memberName,
                              style: const TextStyle(
                                fontSize: 16,
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
                                'No. ${loan.memberNo}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildStatusBadge(loan.status),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Keperluan & Jaminan
                    Text(
                      loan.purpose,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.adminNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.security_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Jaminan: ${loan.collateral}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Plafon: ${_formatRupiah(loan.amount)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Tenor: ${loan.tenorMonths} Bulan',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Visual Progress Tracker Multi-Level Approval
                    _buildTrackerBar(loan.status),

                    if (loan.kkVoucherCode != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Draft Nota Kas Keluar: ${loan.kkVoucherCode}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],

                    // Action Buttons berdasarkan Stage
                    if (stage == 'verifikasi_admin') ...[
                      const Divider(height: 20, color: AppColors.cardBorder),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showApprovalDecisionModal(loan),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.verified_user_rounded, size: 16),
                              label: const Text(
                                'Verifikasi & Teruskan ke Manajer',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (stage == 'menunggu_ketua') ...[
                      const Divider(height: 20, color: AppColors.cardBorder),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFB45309)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Menunggu Persetujuan Manajer (Read-Only)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrackerBar(String status) {
    bool isStep1Done = status != 'verifikasi_admin' && status != 'pending_admin';
    bool isStep2Done = status == 'disetujui' || status == 'approved';
    bool isRejected = status == 'ditolak' || status == 'rejected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.adminCanvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTrackerStep('1. Verifikasi Admin', isStep1Done, isRejected && status != 'menunggu_ketua' && status != 'disetujui' && status != 'approved'),
          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
          _buildTrackerStep('2. ACC Manajer', isStep2Done, isRejected && status == 'ditolak'),
          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
          _buildTrackerStep('3. Siap Cair (KK)', isStep2Done, false),
        ],
      ),
    );
  }

  Widget _buildTrackerStep(String label, bool isDone, bool isFailed) {
    Color bg = isDone
        ? AppColors.success
        : isFailed
            ? AppColors.danger
            : AppColors.textMuted;

    return Row(
      children: [
        Icon(
          isDone
              ? Icons.check_circle_rounded
              : isFailed
                  ? Icons.cancel_rounded
                  : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: bg,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: bg,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'disetujui':
      case 'approved':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = 'Telah Disetujui Manajer (Siap Dicairkan)';
        break;
      case 'menunggu_ketua':
      case 'pending_manager':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'Menunggu Persetujuan Manajer';
        break;
      case 'ditolak':
      case 'rejected':
        bg = AppColors.dangerBg;
        fg = AppColors.danger;
        label = 'Ditolak';
        break;
      default:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        label = 'Menunggu Verifikasi Admin';
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

