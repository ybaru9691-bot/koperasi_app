import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../data/dummy/ketua_dummy_data.dart';

//  WIDGET TABEL PERSETUJUAN / ACC KETUA (RESPONSIF HORIZONTAL SCROLL)
class KetuaApprovalTableWidget extends StatelessWidget {
  final bool isDesktop;
  final dynamic requests; // Mendukung List<ApprovalDataModel> atau List<Map<String, dynamic>> dari API
  final String approvalFilter;
  final ValueChanged<String> onFilterChanged;
  final Function(ApprovalDataModel) onApprove;
  final Function(ApprovalDataModel) onReject;
  final Set<String> loadingIds;

  const KetuaApprovalTableWidget({
    super.key,
    required this.isDesktop,
    this.requests,
    required this.approvalFilter,
    required this.onFilterChanged,
    required this.onApprove,
    required this.onReject,
    this.loadingIds = const {},
  });

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    final List<ApprovalDataModel> listData = requests is List
        ? ApprovalDataModel.fromJsonList(requests)
        : KetuaDummyData.getApprovalRequests();

    final filtered = listData.where((r) {
      if (approvalFilter == 'semua') return true;
      return r.type == approvalFilter;
    }).toList();

    final int pendingCount = listData.where((r) => r.status == 'menunggu').length;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_turned_in_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pengajuan Membutuhkan ACC / Persetujuan KM/KK',
                      style: TextStyle(
                        fontSize: isDesktop ? 15 : 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.adminNavy,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: pendingCount > 0 ? AppColors.warningBg : AppColors.successBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pendingCount Menunggu',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: pendingCount > 0 ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),

              // Filter Chips
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _filterChipButton('Semua', 'semua'),
                  const SizedBox(width: 6),
                  _filterChipButton('Pinjaman', 'pinjaman'),
                  const SizedBox(width: 6),
                  _filterChipButton('Kas Keluar', 'kas_keluar'),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          //  SOLUSI TABEL HORIZONTAL SCROLL + CONSTRAINEDBOX MIN-WIDTH SUPAYA TIDAK OVERFLOW
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: isDesktop ? 800.0 : 650.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder)),
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(100),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2.5),
                      3: FixedColumnWidth(125),
                      4: FixedColumnWidth(100),
                      5: FixedColumnWidth(170),
                    },
                    children: [
                      // Table Header
                      TableRow(
                        decoration: const BoxDecoration(color: AppColors.adminNavy),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            child: Text('No. Ref', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            child: Text('Anggota', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            child: Text('Kategori Pengajuan', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            child: Text('Nominal (Rp)', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            child: Text('Status ACC', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            child: Text('Aksi Persetujuan', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),

                      // Table Body Rows
                      for (int i = 0; i < filtered.length; i++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                              child: Text(filtered[i].id, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(filtered[i].applicant, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text('No. Buku: ${filtered[i].memberNo}', style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                              child: Text(filtered[i].category, style: const TextStyle(fontSize: 10.5, color: AppColors.textPrimary)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                              child: Text(
                                _formatRupiah(filtered[i].amount),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                              child: Center(child: _statusBadge(filtered[i].status)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                              child: loadingIds.contains(filtered[i].id)
                                  ? const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : filtered[i].status == 'menunggu'
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () => onApprove(filtered[i]),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.success,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: const Text('Setujui', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 6),
                                            OutlinedButton(
                                              onPressed: () => onReject(filtered[i]),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.danger,
                                                side: const BorderSide(color: AppColors.danger),
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: const Text('Tolak', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        )
                                      : const Center(
                                          child: Text('Selesai', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                                        ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChipButton(String label, String value) {
    final bool isSelected = approvalFilter == value;
    return InkWell(
      onTap: () => onFilterChanged(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    if (status == 'disetujui') {
      bg = AppColors.successBg;
      fg = AppColors.success;
      label = 'DISETUJUI';
    } else if (status == 'ditolak') {
      bg = AppColors.dangerBg;
      fg = AppColors.danger;
      label = 'DITOLAK';
    } else {
      bg = AppColors.warningBg;
      fg = AppColors.warning;
      label = 'MENUNGGU';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
