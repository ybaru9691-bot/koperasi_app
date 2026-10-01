import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../data/models/pending_approval_model.dart';
import '../../../utils/navigation_utils.dart';

// WIDGET KARTU TRANSAKSI APPROVAL (INFORMASI LENGKAP & QUICK ACTIONS)
class ApprovalCardWidget extends StatelessWidget {
  final PendingApprovalModel item;
  final VoidCallback onTapDetail;
  final VoidCallback onQuickApprove;
  final VoidCallback onQuickReject;

  const ApprovalCardWidget({
    super.key,
    required this.item,
    required this.onTapDetail,
    required this.onQuickApprove,
    required this.onQuickReject,
  });

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    Color typeBg;
    Color typeFg;
    IconData typeIcon;

    if (item.type == 'KM') {
      typeBg = AppColors.successBg;
      typeFg = AppColors.success;
      typeIcon = Icons.arrow_downward_rounded;
    } else if (item.type == 'KK') {
      typeBg = AppColors.dangerBg;
      typeFg = AppColors.danger;
      typeIcon = Icons.arrow_upward_rounded;
    } else {
      typeBg = AppColors.infoBg;
      typeFg = AppColors.info;
      typeIcon = Icons.credit_card_rounded;
    }

    final bool isPending = item.status == 'pending';

    return InkWell(
      onTap: onTapDetail,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPending ? AppColors.cardBorder : AppColors.border,
          ),
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
            // HEADER BARIS 1: BADGE TYPE, NO REF, & TANGGAL
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(typeIcon, color: typeFg, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        item.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: typeFg,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.refCode,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminNavy,
                  ),
                ),
                const Spacer(),
                Text(
                  item.date,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // BARIS 2: NAMA PEMOHON & NOMINAL RUPS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.memberName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.adminNavy,
                        ),
                      ),
                      Text(
                        'No. Reg: ${item.memberNo} • Operator: ${item.adminOperator}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatRupiah(item.amount),
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: typeFg,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // BARIS 3: KATEGORI / CATATAN
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${item.category} • ${item.notes}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // REJECTION REASON IF REJECTED
            if (item.status == 'ditolak' && item.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Alasan Penolakan: ${item.rejectionReason}',
                        style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // BARIS 4: QUICK ACTION BUTTONS OR STATUS BADGE
            if (isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onQuickReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onQuickApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      item.type == 'Pinjaman' ? 'Setujui Pinjaman' : 'Setujui Transaksi',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.status == 'disetujui' ? AppColors.successBg : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: item.status == 'disetujui' ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 🔍 DIALOG DETAIL TRANSAKSI LENGKAP BUKTI/STRUK
class ApprovalDetailDialog extends StatelessWidget {
  final PendingApprovalModel item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ApprovalDetailDialog({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = item.status == 'pending';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Rincian Detail ${item.refCode}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => NavigationUtils.safePop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              _detailRow('Nomor Registrasi', item.refCode),
              _detailRow('Anggota', '${item.memberName} (No. ${item.memberNo})'),
              _detailRow('Jenis Transaksi', item.type),
              _detailRow('Nominal Transaksi', _formatRupiah(item.amount), isBold: true, color: AppColors.primary),
              _detailRow('Operator Admin', item.adminOperator),
              _detailRow('Kategori Pos', item.category),
              _detailRow('Waktu / Tanggal', item.date),
              _detailRow('Catatan Tambahan', item.notes),
              if (item.rejectionReason != null)
                _detailRow('Alasan Penolakan', item.rejectionReason!, color: AppColors.danger),

              const SizedBox(height: 16),

              if (isPending) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        NavigationUtils.safePop(context);
                        onReject();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        NavigationUtils.safePop(context);
                        onApprove();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        item.type == 'Pinjaman' ? 'Setujui Pinjaman' : 'Setujui Transaksi',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
}

/// 🛑 DIALOG ALASAN PENOLAKAN (VALIDATED TEXTFORMFIELD)
class RejectReasonDialog extends StatefulWidget {
  final PendingApprovalModel item;
  final Function(String reason) onSubmitReject;

  const RejectReasonDialog({
    super.key,
    required this.item,
    required this.onSubmitReject,
  });

  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.cancel_rounded, color: AppColors.danger, size: 26),
          SizedBox(width: 10),
          Text('Konfirmasi Penolakan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menolak pengajuan ${widget.item.refCode} dari ${widget.item.memberName}?',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Alasan penolakan wajib diisi!';
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Alasan Penolakan (Wajib)',
                hintText: 'Masukkan alasan spesifik penolakan...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => NavigationUtils.safePop(context),
          child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final reason = _reasonController.text.trim();
              NavigationUtils.safePop(context);
              widget.onSubmitReject(reason);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Ya, Tolak Transaksi'),
        ),
      ],
    );
  }
}
