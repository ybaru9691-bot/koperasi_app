import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'receipt_voucher_dialog.dart';

/// Widget Card Statistik Admin Dashboard
class AdminStatCardItemWidget extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const AdminStatCardItemWidget({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ],
      ),
    );
  }
}

/// Widget Badge Status Persetujuan Transaksi Admin
class AdminStatusBadgeWidget extends StatelessWidget {
  final String status;

  const AdminStatusBadgeWidget({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'approved':
      case 'lunas':
        bg = AppColors.successBg;
        fg = AppColors.success;
        label = "Lunas / Disetujui";
        break;
      default:
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        label = "Pending";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

/// Widget Kartu Tabel Transaksi Kas Harian Terakhir
class AdminTransactionListCardWidget extends StatelessWidget {
  final List<dynamic> recentTransactions;
  final String Function(num?) formatRupiah;
  final VoidCallback? onInputTransaction;
  final Function(dynamic)? onViewDetail;

  const AdminTransactionListCardWidget({
    super.key,
    required this.recentTransactions,
    required this.formatRupiah,
    this.onInputTransaction,
    this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          // 1. HEADER SEKSI DENGAN 1 TOMBOL AKSI CEPAT (+ INPUT TRANSAKSI)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: AppColors.adminNavy,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Transaksi Kas Harian Terakhir",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.adminNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onInputTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    "Input Transaksi",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.cardBorder),

          // 2. TAMPILAN TABEL / LIST VIEW DENGAN EMPTY STATE HANDLER
          recentTransactions.isEmpty
              ? _buildEmptyState(context)
              : _buildTransactionList(context),
        ],
      ),
    );
  }

  /// Empty State Widget jika belum ada data transaksi
  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(36.0),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primaryBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada transaksi kas harian hari ini',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gunakan tombol "+ Input Transaksi" di kanan atas untuk menginput transaksi setoran KM atau penarikan KK',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// List Transaksi Kas Harian dengan 6 Kolom Lengkap
  Widget _buildTransactionList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentTransactions.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.cardBorder),
      itemBuilder: (context, index) {
        final trx = recentTransactions[index];
        final bool isKm = trx['isIncome'] ?? (trx['is_income'] ?? true);
        final String rawDate = trx['date'] ?? trx['created_at'] ?? trx['tanggal'] ?? '';
        final String tanggal = ReceiptVoucherDialog.formatToWibDateTime(rawDate);
        final String rawNota = trx['formatted_receipt_no'] ?? trx['receipt_number'] ?? trx['transaction_number'] ?? trx['kmCode'] ?? trx['nota'] ?? '-';
        final String nota = ReceiptVoucherDialog.deduplicateProofNumber(rawNota, isIncome: isKm);
        final String name = trx['member_name'] ?? trx['memberName'] ?? 'Maria Sitindaon';
        final String memberNo = trx['member_no'] ?? trx['memberNo'] ?? 'No. 2564';
        final String jenis = trx['type'] ?? trx['category'] ?? (isKm ? 'Setoran Simpanan (KM)' : 'Penarikan Simpanan (KK)');
        final num amount = trx['amount'] ?? 0;
        final String paymentMethod = trx['paymentMethod'] ?? trx['payment_method'] ?? 'Tunai / Cash';
        final String operatorName = trx['operator'] ?? trx['teller'] ?? 'Admin Pelita (Teller 1)';

        final badgeColor = isKm ? AppColors.success : AppColors.danger;
        final badgeBg = isKm ? AppColors.successBg : AppColors.dangerBg;
        final prefixText = isKm ? '+ ' : '- ';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: badgeBg,
            child: Icon(
              isKm ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: badgeColor,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              // Badge Voucher Code (Nota KM / KK)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isKm ? AppColors.adminNavy : const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  nota,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nama Anggota & No. Register
              Expanded(
                child: Text(
                  '$name ($memberNo)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Badge Jenis Transaksi
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        jenis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    // Badge Metode Pembayaran
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            paymentMethod.toLowerCase().contains('tunai')
                                ? Icons.payments_outlined
                                : Icons.account_balance_outlined,
                            size: 10,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paymentMethod,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Tanggal & Operator / Teller
                Text(
                  '$tanggal • $operatorName',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nominal Format Rupiah
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefixText${formatRupiah(amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: badgeColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Diterbitkan',
                    style: TextStyle(fontSize: 9, color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(width: 4),

              // Action Button: Detail / Cetak Struk
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.print_rounded, color: AppColors.adminNavy, size: 18),
                tooltip: 'Cetak Bukti Transaksi',
                onPressed: () {
                  if (onViewDetail != null) {
                    onViewDetail!(trx);
                  } else {
                    showDialog(
                      context: context,
                      builder: (ctx) => ReceiptVoucherDialog(transaction: trx),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
