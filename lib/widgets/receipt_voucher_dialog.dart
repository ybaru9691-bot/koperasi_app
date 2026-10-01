import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import '../core/theme/app_colors.dart';
import '../models/transaction_data_model.dart';
import '../services/auth_service.dart';

/// Modal Pratinjau (Preview) Digital Slip Kuitansi / Bukti Kas Resmi
/// Koperasi CUM Pelita HKBP Dame Duri (Reusable Component)
class ReceiptVoucherDialog extends StatelessWidget {
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

  const ReceiptVoucherDialog({
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

  /// Format Angka ke Rupiah Indonesia
  static String formatRupiah(num val) {
    try {
      return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
    } catch (_) {
      return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }
  }

  /// Helper Pembersihan & Deduplikasi Nomor Bukti (KM / KK)
  static String deduplicateProofNumber(String? raw, {bool isIncome = true}) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') {
      return isIncome ? 'KM Auto' : 'KK Auto';
    }
    var s = raw.trim();

    // Bersihkan repetisi prefix ganda (misal: "KK KK 0012" -> "KK 0012")
    s = s.replaceAll(RegExp(r'^(KK[\s\-_]*)+', caseSensitive: false), 'KK ');
    s = s.replaceAll(RegExp(r'^(KM[\s\-_]*)+', caseSensitive: false), 'KM ');

    if (s.toUpperCase().startsWith('KK') || s.toUpperCase().startsWith('KM')) {
      s = s.replaceAllMapped(RegExp(r'^(KK|KM)[\s\-_]*', caseSensitive: false), (m) => '${m[1]?.toUpperCase()} ');
    } else if (!s.toUpperCase().startsWith('TRX')) {
      final defaultPrefix = isIncome ? 'KM ' : 'KK ';
      s = '$defaultPrefix$s';
    }

    return s.trim();
  }

  /// Helper Format Tanggal & Jam Lokal (WIB)
  static String formatToWibDateTime(dynamic rawDate) {
    if (rawDate == null || rawDate.toString().trim().isEmpty || rawDate.toString().trim() == '-') {
      return '${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(DateTime.now().toLocal())} WIB';
    }
    final dateStr = rawDate.toString().trim();
    if (dateStr.endsWith('WIB')) {
      return dateStr;
    }
    try {
      DateTime dt;
      if (dateStr.contains('T') || dateStr.contains('-') || dateStr.contains(':')) {
        dt = DateTime.parse(dateStr).toLocal();
      } else {
        return '$dateStr WIB';
      }
      return '${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt)} WIB';
    } catch (_) {
      try {
        final dt = DateTime.parse(dateStr);
        return '${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt.toLocal())} WIB';
      } catch (_) {
        return '$dateStr WIB';
      }
    }
  }

  /// Helper Konversi Angka ke Terbilang Bahasa Indonesia
  static String terbilang(num n) {
    final int number = n.round();
    if (number == 0) return 'Nol Rupiah';

    final units = ['', 'Satu', 'Dua', 'Tiga', 'Empat', 'Lima', 'Enam', 'Tujuh', 'Delapan', 'Sembilan', 'Sepuluh', 'Sebelas'];

    String convert(int number) {
      if (number < 0) {
        return 'Minus ${convert(-number)}';
      } else if (number < 12) {
        return units[number];
      } else if (number < 20) {
        return '${convert(number - 10)} Belas';
      } else if (number < 100) {
        return '${convert(number ~/ 10)} Puluh ${convert(number % 10)}'.trim();
      } else if (number < 200) {
        return 'Seratus ${convert(number - 100)}'.trim();
      } else if (number < 1000) {
        return '${convert(number ~/ 100)} Ratus ${convert(number % 100)}'.trim();
      } else if (number < 2000) {
        return 'Seribu ${convert(number - 1000)}'.trim();
      } else if (number < 1000000) {
        return '${convert(number ~/ 1000)} Ribu ${convert(number % 1000)}'.trim();
      } else if (number < 1000000000) {
        return '${convert(number ~/ 1000000)} Juta ${convert(number % 1000000)}'.trim();
      } else if (number < 1000000000000) {
        return '${convert(number ~/ 1000000000)} Milyar ${convert(number % 1000000000)}'.trim();
      } else {
        return '$number';
      }
    }

    return '${convert(number)} Rupiah';
  }

  /// Helper Mapping Nama Transaksi / Pos ke Kode Akun (No. Perk)
  static String lookupAccountCode(String label, {bool isIncome = true}) {
    final l = label.toLowerCase();
    if (l.contains('pokok') && (l.contains('simpan') || l.contains('sp'))) return '3101';
    if (l.contains('wajib') && (l.contains('simpan') || l.contains('sw'))) return '3102';
    if (l.contains('sukarela') && (l.contains('simpan') || l.contains('ss'))) return '3103';
    if (l.contains('harian') || l.contains('putih') || l.contains('sh')) return '3104';
    if (l.contains('diakonia') || l.contains('duka') || l.contains('sosial')) return '3105';
    if (l.contains('angsuran') || (l.contains('pinjam') && !l.contains('jasa'))) return '1201';
    if (l.contains('jasa') && l.contains('pinjam')) return '4101';
    if (l.contains('pangkal')) return '4102';
    if (l.contains('denda')) return '4103';
    if (l.contains('provisi')) return '4104';
    if (l.contains('administrasi') || l.contains('admin') || l.contains('finalty')) return '4105';
    if (l.contains('jasa simpanan') || l.contains('bunga')) return '5101';
    if (l.contains('atk') || l.contains('tulis')) return '5201';
    if (l.contains('gaji') || l.contains('honor')) return '5202';
    if (l.contains('telekomunikasi') || l.contains('pulsa') || l.contains('internet')) return '5203';
    if (l.contains('transport') || l.contains('bensin') || l.contains('perjalanan')) return '5204';
    if (l.contains('bpjs tk') || l.contains('ketenagakerjaan')) return '5205';
    if (l.contains('konsumsi') || l.contains('makan')) return '5206';
    if (l.contains('bpjs kes') || l.contains('kesehatan')) return '5207';
    if (l.contains('bank') || l.contains('bri')) return '1102';
    if (l.contains('pendapatan')) return '4201';
    if (l.contains('biaya') || l.contains('beban')) return '5301';
    return isIncome ? '3101' : '1201';
  }

  void _executePrint(BuildContext context, String id, String voucherCode, double totalAmount) {
    Navigator.of(context, rootNavigator: true).pop();
    try {
      if (kIsWeb) {
        if (id.isNotEmpty && id != '0' && !id.startsWith('dummy')) {
          final url = '${AuthService.staticBaseUrl}/transactions/$id/receipt/pdf';
          html.window.open(url, '_blank');
        } else {
          html.window.print();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.print_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Mencetak Kuitansi Nota $voucherCode (${formatRupiah(totalAmount)})...'),
              ),
            ],
          ),
          backgroundColor: AppColors.adminNavy,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('[RECEIPT_PRINT] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    String id = '';
    String rawDate = date ?? '';
    String rawVoucher = voucherNo ?? '';
    String dispMemberName = memberName ?? '';
    String dispMemberNo = memberNo ?? '';
    String dispCategory = '';
    bool dispIsIncome = isIncome ?? true;
    double totalAmount = amount ?? 0.0;
    String dispPaymentMethod = paymentMethod ?? '💵 Tunai / Cash';
    String dispOperator = operatorName ?? 'Admin Pelita (Teller)';
    List<Map<String, dynamic>> dispItems = items != null ? List.from(items!) : [];

    // Parsing jika objek transaction dipassing
    if (transaction is TransactionDataModel) {
      final TransactionDataModel t = transaction;
      id = t.id;
      rawDate = t.date;
      rawVoucher = t.kmCode;
      dispMemberName = t.memberName;
      dispMemberNo = t.memberNo;
      dispCategory = t.category;
      dispIsIncome = t.isIncome;
      totalAmount = t.amount;
      dispPaymentMethod = t.paymentMethod;
      dispOperator = t.operator;
      if (t.subItems.isNotEmpty) {
        dispItems = List<Map<String, dynamic>>.from(t.subItems);
      }
    } else if (transaction is Map) {
      final Map t = transaction;
      id = (t['id'] ?? '').toString();
      rawDate = (t['transaction_date'] ?? t['date'] ?? t['tanggal'] ?? t['created_at'] ?? date ?? '').toString();
      rawVoucher = (t['formatted_receipt_no'] ?? t['receipt_number'] ?? t['transaction_number'] ?? t['kmCode'] ?? t['nota'] ?? voucherNo ?? '').toString();
      dispMemberName = (t['member_name'] ?? t['memberName'] ?? t['member']?['full_name'] ?? t['member']?['name'] ?? memberName ?? 'Anggota Umum').toString();
      dispMemberNo = (t['member_no'] ?? t['memberNo'] ?? t['member']?['member_number'] ?? memberNo ?? '-').toString();
      dispCategory = (t['description'] ?? t['category'] ?? t['kategori'] ?? 'Transaksi Kasir').toString();
      dispIsIncome = t['isIncome'] ?? t['is_income'] ?? isIncome ?? (t['type'] == 'deposit' || t['type'] == 'KM' || t['type'] == 'kas_masuk');
      totalAmount = (t['amount'] as num?)?.toDouble() ?? amount ?? 0.0;
      final pRaw = (t['payment_method'] ?? t['paymentMethod'] ?? paymentMethod ?? 'cash').toString().toLowerCase();
      dispPaymentMethod = (pRaw.contains('bank') || pRaw.contains('transfer')) ? '🏦 Transfer / Bank' : '💵 Tunai / Cash';
      dispOperator = (t['operator'] ?? t['teller'] ?? t['operator_name'] ?? operatorName ?? 'Admin Pelita (Teller)').toString();
      if (t['sub_items'] is List && (t['sub_items'] as List).isNotEmpty) {
        dispItems = List<Map<String, dynamic>>.from(t['sub_items']);
      }
    }

    // Jika items masih kosong, buat dari category & totalAmount
    if (dispItems.isEmpty) {
      if (dispCategory.isEmpty) {
        dispCategory = dispIsIncome ? 'Setoran Simpanan Kas Masuk' : 'Penarikan Simpanan Kas Keluar';
      }
      dispItems.add({
        'label': dispCategory,
        'code': lookupAccountCode(dispCategory, isIncome: dispIsIncome),
        'amount': totalAmount,
      });
    }

    final String finalVoucherCode = deduplicateProofNumber(rawVoucher, isIncome: dispIsIncome);
    final String dateDisplay = formatToWibDateTime(rawDate);
    final String terbilangText = terbilangCustom ?? terbilang(totalAmount);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. MODAL TOP HEADER BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.adminNavy,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.print_rounded, color: AppColors.adminAccent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Preview Nota Physical ${dispIsIncome ? "Kas Masuk (KM)" : "Kas Keluar (KK)"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ],
              ),
            ),

            // 2. KERTAS BUKTI FISIK NOTA (PRINTER PAPER VIEW)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DESAIN HEADER NOTA (LOGO, JUDUL, NOMOR NOTA & TANGGAL)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 2),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo_koperasi.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.account_balance_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CREDO UNION MODIFIKASI (CUM) PELITA',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.adminNavy,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'HKBP DAME DURI • RIAU',
                                  style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: dispIsIncome ? AppColors.successBg : AppColors.dangerBg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: (dispIsIncome ? AppColors.success : AppColors.danger).withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    dispIsIncome ? 'BUKTI PENERIMAAN KAS (KM)' : 'BUKTI PENGELUARAN KAS (KK)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: dispIsIncome ? AppColors.success : AppColors.danger,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${dispIsIncome ? "NO. KM" : "NO. KK"}: $finalVoucherCode',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.adminNavy,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Tgl: $dateDisplay',
                                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1, thickness: 1.5, color: AppColors.adminNavy),
                      const SizedBox(height: 14),

                      // SECTION INFORMASI ANGGOTA & DENGAN HURUF
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                                      children: [
                                        TextSpan(
                                          text: dispIsIncome ? 'Diterima Dari: ' : 'Dibayar Ke: ',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                        ),
                                        TextSpan(text: dispMemberName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                                      children: [
                                        const TextSpan(text: 'NIK / NA: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                        TextSpan(text: dispMemberNo.startsWith('No.') ? dispMemberNo : 'No. $dispMemberNo', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                                      children: [
                                        const TextSpan(text: 'Tunai Rp: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                        TextSpan(
                                          text: 'Rp ${formatRupiah(totalAmount)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: dispIsIncome ? AppColors.success : AppColors.danger,
                                          ),
                                        ),
                                        TextSpan(text: '  ($dispPaymentMethod)', style: const TextStyle(fontSize: 10.5, color: AppColors.info, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                                  children: [
                                    const TextSpan(text: 'Jumlah Dengan Huruf: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                    TextSpan(
                                      text: '"$terbilangText"',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: AppColors.adminNavy),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // TABEL RINCIAN ITEM (DENGAN NO. PERK)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder)),
                          child: Table(
                            columnWidths: const {
                              0: FixedColumnWidth(36),
                              1: FlexColumnWidth(),
                              2: FixedColumnWidth(90),
                              3: FixedColumnWidth(130),
                            },
                            children: [
                              // Table Header
                              TableRow(
                                decoration: const BoxDecoration(color: AppColors.adminNavy),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                    child: Text('No', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                                    child: Text('Uraian Transaksi', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                    child: Text('No. Perk.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                                    child: Text('Jumlah (Rp)', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ],
                              ),
                              // Table Rows (Rincian Item Uraian)
                              for (int i = 0; i < dispItems.length; i++)
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                      child: Text('${i + 1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                                      child: Text(
                                        (dispItems[i]['label'] ?? dispItems[i]['category'] ?? dispItems[i]['keterangan'] ?? 'Uraian Transaksi').toString(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                      child: Text(
                                        (dispItems[i]['code'] ?? dispItems[i]['account_code'] ?? dispItems[i]['no_perk'] ?? lookupAccountCode((dispItems[i]['label'] ?? dispItems[i]['category'] ?? dispItems[i]['keterangan'] ?? '').toString(), isIncome: dispIsIncome)).toString(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.info),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                                      child: Text(
                                        formatRupiah((dispItems[i]['amount'] as num?) ?? 0),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              // Total Row
                              TableRow(
                                decoration: BoxDecoration(
                                  color: dispIsIncome ? AppColors.successBg : AppColors.dangerBg,
                                ),
                                children: [
                                  const SizedBox.shrink(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    child: Text(
                                      'TOTAL ${dispIsIncome ? "PENERIMAAN" : "PENGELUARAN"}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: dispIsIncome ? AppColors.success : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                  const SizedBox.shrink(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    child: Text(
                                      'Rp ${formatRupiah(totalAmount)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: dispIsIncome ? AppColors.success : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // FOOTER TANDA TANGAN (4 KOLOM PRESISI NOTA FISIK)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Kolom 1: Dijurnal
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Dijurnal di tab / Tgl', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                const Text('Oleh', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                const SizedBox(height: 38),
                                Container(width: 100, height: 1, color: AppColors.cardBorder),
                                const SizedBox(height: 3),
                                const Text('( Pembukuan )', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Kolom 2: Disetujui Manager
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Disetujui', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                const Text('Manager', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                const SizedBox(height: 38),
                                Container(width: 100, height: 1, color: AppColors.cardBorder),
                                const SizedBox(height: 3),
                                const Text('( Manager )', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Kolom 3: Kasir
                          Expanded(
                            child: Column(
                              children: [
                                Text(dispIsIncome ? 'Menerima' : 'Dikeluarkan', style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                const Text('Kasir', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                const SizedBox(height: 38),
                                Container(width: 100, height: 1, color: AppColors.cardBorder),
                                const SizedBox(height: 3),
                                Text('( $dispOperator )', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          // Kolom 4: Penyetor / Penerima
                          Expanded(
                            child: Column(
                              children: [
                                Text(dispIsIncome ? 'Menyetor' : 'Diterima', style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                const Text('Anggota', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                const SizedBox(height: 38),
                                Container(width: 100, height: 1, color: AppColors.cardBorder),
                                const SizedBox(height: 3),
                                Text('($dispMemberName)', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.cardBorder),
                      const SizedBox(height: 6),

                      // LEMBAR KETERANGAN FISIK
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            dispIsIncome
                                ? '* Lembar 1: Penyetor / Anggota (Putih)   |   * Lembar 2: Kasir / Pembukuan (Kuning)'
                                : '* Lembar 1: Kasir / Pembukuan (Putih)   |   * Lembar 2: Penerima / Anggota (Kuning)',
                            style: const TextStyle(fontSize: 8.5, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                          ),
                          const Text(
                            'Koperasi CUM Pelita System',
                            style: TextStyle(fontSize: 8.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.cardBorder),

            // 3. ACTION BUTTONS: TUTUP & KONFIRMASI / PRINT
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Tutup'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _executePrint(context, id, finalVoucherCode, totalAmount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text(
                      'Konfirmasi & Print',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
