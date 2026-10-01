import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../constants/app_colors.dart';
import '../../../data/models/member_detail_model.dart';
import '../../../services/auth_service.dart';
import '../../../utils/navigation_utils.dart';

// WIDGET STAT CARD ANGGOTA
class MemberStatCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  const MemberStatCardWidget({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// WIDGET KARTU ANGGOTA & PORTOFOLIO KEUANGAN
class MemberCardWidget extends StatelessWidget {
  final MemberDetailModel member;
  final VoidCallback onTapDetail;

  const MemberCardWidget({
    super.key,
    required this.member,
    required this.onTapDetail,
  });

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  @override
  Widget build(BuildContext context) {
    final bool isAktif = member.status == 'aktif';

    return InkWell(
      onTap: onTapDetail,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar Initials Circle
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isAktif ? const Color(0xFFE0F2FE) : const Color(0xFFFFE4E6),
                  child: Text(
                    _getInitials(member.name),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isAktif ? const Color(0xFF0369A1) : AppColors.danger,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Name & Reg Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              member.name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.adminNavy,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAktif ? AppColors.successBg : AppColors.dangerBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              member.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isAktif ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NIA: ${member.memberNo} • ${member.churchUnit}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 10),

            // Financial Quick Summary Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Portfolio Simpanan', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      _formatRupiah(member.financialSummary.totalSimpanan),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Status Pinjaman', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          member.financialSummary.hasActiveLoan
                              ? Icons.pending_actions_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: member.financialSummary.hasActiveLoan ? AppColors.warning : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          member.financialSummary.hasActiveLoan
                              ? 'Pinjaman Aktif (${_formatRupiah(member.financialSummary.remainingLoan)})'
                              : 'Tidak Ada Pinjaman',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: member.financialSummary.hasActiveLoan ? AppColors.warning : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onTapDetail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.badge_outlined, size: 16),
                label: const Text('Detail Profil', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 📋 MODAL TABBED DIALOG / BOTTOMSHEET DETAIL PROFIL ANGGOTA
class MemberDetailDialog extends StatefulWidget {
  final MemberDetailModel member;

  const MemberDetailDialog({super.key, required this.member});

  @override
  State<MemberDetailDialog> createState() => _MemberDetailDialogState();
}

class _MemberDetailDialogState extends State<MemberDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MemberDetailModel _memberData;
  Map<String, dynamic>? _loansData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _memberData = widget.member;
    _tabController = TabController(length: 3, vsync: this);
    loadMemberData();
  }

  Future<void> loadMemberData() async {
    try {
      debugPrint(">>> 1. START FETCH MEMBER DETAIL ID: ${widget.member.id}");
      final token = await AuthService().getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final memberUri = Uri.parse('${AuthService.staticBaseUrl}/manager/members/${widget.member.id}');
      final loanUri = Uri.parse('${AuthService.staticBaseUrl}/manager/members/${widget.member.id}/loans');
      
      final responses = await Future.wait([
        http.get(memberUri, headers: headers).timeout(const Duration(seconds: 10)),
        http.get(loanUri, headers: headers).timeout(const Duration(seconds: 10)),
      ]);

      if (responses[0].statusCode == 200) {
        final body = jsonDecode(responses[0].body);
        final data = body['data'] ?? body;
        debugPrint(">>> 2. RESPONSE BACKEND HASIL FETCH: $data");
        
        Map<String, dynamic>? loansData;
        if (responses[1].statusCode == 200) {
          final loanBody = jsonDecode(responses[1].body);
          loansData = loanBody['data'] ?? loanBody;
        }

        if (mounted) {
          final parsedData = MemberDetailModel.fromJson(data);
          debugPrint(">>> 3. HASIL PARSING MODEL: Pokok=${parsedData.financialSummary.simpananPokok}, Harian=${parsedData.financialSummary.simpananHarian}");
          setState(() {
            _memberData = parsedData;
            _loansData = loansData;
            _isLoading = false;
          });
          debugPrint(">>> 4. SETSTATE BERHASIL DIPANGGIL!");
        }
      } else {
        debugPrint(">>> ERROR RESPONSE STATUS: ${responses[0].statusCode} - ${responses[0].body}");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e, stacktrace) {
      debugPrint(">>> ERROR SAAT FETCH/PARSING MODAL: $e");
      debugPrint(">>> STACKTRACE: $stacktrace");
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

  @override
  Widget build(BuildContext context) {
    final member = _memberData;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Dialog
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 26),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                          ),
                          Text('NIA: ${member.memberNo} • NIK: ${member.nik}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => NavigationUtils.safePop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Tab Bar Navigation
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Informasi Personal'),
                  Tab(text: 'Portofolio Simpanan'),
                  Tab(text: 'Riwayat Pinjaman'),
                ],
              ),

              const SizedBox(height: 14),

              // Tab View Content
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: INFORMASI PERSONAL
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _infoRow('Nama Lengkap', member.name),
                          _infoRow('Nomor Induk Anggota (NIA)', member.memberNo),
                          _infoRow('NIK KTP', member.nik),
                          _infoRow('Nomor Telepon / WA', member.phone),
                          _infoRow('Unit Gereja', member.churchUnit),
                          _infoRow('Tanggal Bergabung', member.joinDate),
                          _infoRow('Alamat Domisili', member.address),
                          _infoRow('Status Keanggotaan', member.status.toUpperCase(), color: member.status == 'aktif' ? AppColors.success : AppColors.danger),
                        ],
                      ),
                    ),

                    // TAB 2: PORTOFOLIO SIMPANAN
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _infoRow('Simpanan Pokok', _formatRupiah(member.financialSummary.simpananPokok)),
                          _infoRow('Simpanan Wajib', _formatRupiah(member.financialSummary.simpananWajib)),
                          _infoRow('Simpanan Sukarela', _formatRupiah(member.financialSummary.simpananSukarela)),
                          _infoRow('Simpanan Harian (Buku Putih)', _formatRupiah(member.financialSummary.simpananHarian)),
                          const Divider(),
                          _infoRow('TOTAL PORTOFOLIO SIMPANAN', _formatRupiah(member.financialSummary.totalSimpanan), isBold: true, color: AppColors.primary),
                        ],
                      ),
                    ),

                    // TAB 3: RIWAYAT PINJAMAN
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loansData != null && _loansData!['active_loan'] != null) ...[
                            const Text('Ringkasan Pinjaman Aktif', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            const SizedBox(height: 8),
                            _infoRow('Status Pinjaman Aktif', _loansData!['active_loan']['status']?.toString() ?? 'Aktif', color: AppColors.warning),
                            _infoRow('Plafon Pinjaman Utama', _formatRupiah(double.tryParse(_loansData!['active_loan']['plafon']?.toString() ?? '0') ?? 0)),
                            _infoRow('Sisa Pokok Pinjaman', _formatRupiah(double.tryParse(_loansData!['active_loan']['sisa_pokok']?.toString() ?? '0') ?? 0), isBold: true, color: AppColors.danger),
                            _infoRow('Sisa Bunga / Jasa', _formatRupiah(double.tryParse(_loansData!['active_loan']['sisa_bunga']?.toString() ?? '0') ?? 0)),
                            _infoRow('Tenor & Sisa Angsuran', '${_loansData!['active_loan']['sisa_bulan'] ?? 0} dari ${_loansData!['active_loan']['total_bulan'] ?? 0} Bulan'),
                            _infoRow('Angsuran per Bulan', _formatRupiah(double.tryParse(_loansData!['active_loan']['angsuran_bulanan']?.toString() ?? '0') ?? 0)),
                            _buildKolektibilitasRow(_loansData!['active_loan']['kolektibilitas']?.toString() ?? 'Lancar'),
                          ] else ...[
                            _infoRow('Status Pinjaman Aktif', 'Tidak Ada Pinjaman', color: AppColors.success),
                          ],

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          const Text('Riwayat Pinjaman Sebelumnya', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          const SizedBox(height: 8),
                          
                          if (_loansData != null && _loansData!['loan_history'] != null && (_loansData!['loan_history'] as List).isNotEmpty) ...[
                            _buildLoanHistoryTable(_loansData!['loan_history'] as List),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.history_rounded, size: 32, color: AppColors.textMuted),
                                  SizedBox(height: 8),
                                  Text('Belum pernah mengajukan pinjaman sebelumnya.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => NavigationUtils.safePop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.adminNavy,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppColors.adminNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKolektibilitasRow(String status) {
    Color color = AppColors.success;
    if (status.toLowerCase().contains('ragu') || status.toLowerCase().contains('kuning')) color = AppColors.warning;
    if (status.toLowerCase().contains('macet') || status.toLowerCase().contains('merah')) color = AppColors.danger;
    
    return _infoRow('Track Record / Kolektibilitas', status, isBold: true, color: color);
  }

  Widget _buildLoanHistoryTable(List history) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2.5),
          3: FlexColumnWidth(2),
        },
        border: TableBorder.symmetric(inside: BorderSide(color: AppColors.cardBorder.withOpacity(0.5))),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.surface),
            children: [
              _tableCell('Kode', isHeader: true),
              _tableCell('Cair', isHeader: true),
              _tableCell('Plafon', isHeader: true),
              _tableCell('Status', isHeader: true),
            ],
          ),
          ...history.map((h) => TableRow(
            children: [
              _tableCell(h['kode_pinjaman']?.toString() ?? '-'),
              _tableCell(h['tanggal_cair']?.toString() ?? '-'),
              _tableCell(_formatRupiah(double.tryParse(h['plafon']?.toString() ?? '0') ?? 0)),
              _tableCell(h['status']?.toString() ?? '-', color: h['status'] == 'LUNAS' ? AppColors.success : AppColors.textMuted),
            ],
          )).toList(),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: color ?? (isHeader ? AppColors.textPrimary : AppColors.textSecondary),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
