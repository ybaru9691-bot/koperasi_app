import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/transaction_data_model.dart';
import '../../../widgets/receipt_voucher_dialog.dart';

class AdminTableWidget extends StatelessWidget {
  final bool isDesktop;
  final List<TransactionDataModel>? transactions;
  final VoidCallback onInputTransaction;
  final VoidCallback? onImportExcel;

  const AdminTableWidget({
    super.key,
    required this.isDesktop,
    this.transactions,
    required this.onInputTransaction,
    this.onImportExcel,
  });

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  void _showBreakdownModal(BuildContext context, TransactionDataModel trx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Text('Rincian Gabungan Pos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppColors.cardBorder),
              const SizedBox(height: 10),
              Text('No Ref: ${trx.refNo} - ${trx.memberName}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ...trx.subItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('- ${item['category']}'),
                      Text(_formatRupiah(item['amount']), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              const Divider(color: AppColors.cardBorder),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Keseluruhan', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _formatRupiah(trx.amount),
                    style: TextStyle(fontWeight: FontWeight.bold, color: trx.isIncome ? Colors.green[700] : Colors.red[700], fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final listData = transactions ?? const [];

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                  const Icon(Icons.history, color: AppColors.textPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Transaksi Kas Harian Terakhir',
                    style: AppTextStyles.heading3.copyWith(
                      fontSize: isDesktop ? 16 : 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onImportExcel != null) ...[
                    OutlinedButton.icon(
                      onPressed: onImportExcel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.file_upload_outlined, size: 17),
                      label: const Text('Import Excel', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: onInputTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Input Transaksi', style: AppTextStyles.bodyTextBold),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.cardBorder),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: listData.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.cardBorder),
            itemBuilder: (context, index) {
              final trx = listData[index];
              final bool isKM = trx.isIncome;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon Panah
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isKM ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                      ),
                      child: Icon(
                        isKM ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isKM ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Detail Kiri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.adminNavy,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ReceiptVoucherDialog.deduplicateProofNumber(trx.refNo, isIncome: trx.isIncome),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${trx.memberName} (${trx.memberRegNo})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              InkWell(
                                onTap: trx.subItems.length > 1 ? () => _showBreakdownModal(context, trx) : null,
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isKM ? Colors.green.withOpacity(0.1) : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        trx.category,
                                        style: TextStyle(
                                          color: isKM ? Colors.green[700] : Colors.red[700],
                                          fontSize: 11,
                                          fontWeight: trx.subItems.length > 1 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      if (trx.subItems.length > 1) ...[
                                        const SizedBox(width: 4),
                                        Icon(Icons.info_outline_rounded, size: 14, color: isKM ? Colors.green[700] : Colors.red[700]),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final bool isTransfer = trx.paymentMethod.toLowerCase().contains('bank') || trx.paymentMethod.toLowerCase().contains('transfer');
                                  final Color badgeColor = isTransfer ? Colors.blue : Colors.green;
                                  final IconData badgeIcon = isTransfer ? Icons.account_balance : Icons.payments;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(badgeIcon, size: 12, color: badgeColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          trx.paymentMethod,
                                          style: TextStyle(color: badgeColor, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${ReceiptVoucherDialog.formatToWibDateTime(trx.date)} • ${trx.operatorName}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Detail Kanan
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isKM ? '+' : '-'} ${_formatRupiah(trx.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isKM ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Diterbitkan',
                          style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => ReceiptVoucherDialog(transaction: trx),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, color: Colors.black87),
                      tooltip: 'Print Kuitansi',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
