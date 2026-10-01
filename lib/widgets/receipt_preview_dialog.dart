import 'package:flutter/material.dart';
import 'receipt_voucher_dialog.dart';

export 'receipt_voucher_dialog.dart';

/// Backward-compatibility wrapper pointing to ReceiptVoucherDialog
class ReceiptPreviewDialog extends StatelessWidget {
  final dynamic transaction;
  final String? voucherNo;
  final String? date;
  final String? memberName;
  final String? memberNo;
  final String? paymentMethod;
  final String? operatorName;
  final bool? isIncome;
  final double? amount;
  final String? terbilangCustom;
  final List<Map<String, dynamic>>? items;

  const ReceiptPreviewDialog({
    super.key,
    this.transaction,
    this.voucherNo,
    this.date,
    this.memberName,
    this.memberNo,
    this.paymentMethod,
    this.operatorName,
    this.isIncome,
    this.amount,
    this.terbilangCustom,
    this.items,
  });

  static String formatRupiah(num val) => ReceiptVoucherDialog.formatRupiah(val);
  static String deduplicateProofNumber(String? raw, {bool isIncome = true}) => ReceiptVoucherDialog.deduplicateProofNumber(raw, isIncome: isIncome);
  static String formatToWibDateTime(dynamic rawDate) => ReceiptVoucherDialog.formatToWibDateTime(rawDate);
  static String terbilang(num n) => ReceiptVoucherDialog.terbilang(n);

  @override
  Widget build(BuildContext context) {
    return ReceiptVoucherDialog(
      transaction: transaction,
      voucherNo: voucherNo,
      date: date,
      memberName: memberName,
      memberNo: memberNo,
      paymentMethod: paymentMethod,
      operatorName: operatorName,
      isIncome: isIncome,
      amount: amount,
      terbilangCustom: terbilangCustom,
      items: items,
    );
  }
}

