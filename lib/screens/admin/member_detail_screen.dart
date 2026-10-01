import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../data/models/member_model.dart';
import '../../services/auth_service.dart';
import '../../services/member_statement_pdf_service.dart';
import 'input_transaksi_screen.dart';

// SCREEN DETAIL PORTOFOLIO ANGGOTA (REALTIME GET /api/members/{id}/details)
class MemberDetailScreen extends StatefulWidget {
  final MemberModel member;

  const MemberDetailScreen({
    super.key,
    required this.member,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  bool _isLoading = true;
  MemberModel? _fetched;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic>? _rawData;
  String _selectedBookTab = 'biru';
  bool? _whiteBookStatusOverride;
  bool _isTogglingStatus = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  //  Formatter Rupiah
  static String _rp(num val) {
    try {
      return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
    } catch (_) {
      return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}";
    }
  }

  //  Fetch dari API
  Future<void> _fetchDetails({bool preserveOverride = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      if (!preserveOverride) _whiteBookStatusOverride = null;
    });

    try {
      final token = await AuthService().getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      // Coba endpoint /details dulu, fallback ke /members/{id}
      var resp = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/members/${widget.member.id}/details'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 404) {
        resp = await http.get(
          Uri.parse('${AuthService.staticBaseUrl}/members/${widget.member.id}'),
          headers: headers,
        ).timeout(const Duration(seconds: 30));
      }

      debugPrint('[DETAIL_LOG] ${resp.statusCode} – ${resp.body.substring(0, resp.body.length.clamp(0, 300))}');

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final Map<String, dynamic> data = body['data'] ?? body['member'] ?? body;

        // Fetch statement lengkap Buku Putih langsung dari BukuPutihLedgerService endpoint
        try {
          var bpResp = await http.get(
            Uri.parse('${AuthService.staticBaseUrl}/members/${widget.member.id}/buku-putih-ledger'),
            headers: headers,
          ).timeout(const Duration(seconds: 15));

          if (bpResp.statusCode == 404) {
            bpResp = await http.get(
              Uri.parse('${AuthService.staticBaseUrl}/manager/members/${widget.member.id}/buku-putih-ledger'),
              headers: headers,
            ).timeout(const Duration(seconds: 15));
          }

          if (bpResp.statusCode == 200) {
            final bpBody = jsonDecode(bpResp.body);
            if (bpBody['data'] is Map) {
              data['buku_putih_ledger'] = Map<String, dynamic>.from(bpBody['data']);
            }
          }
        } catch (e) {
          debugPrint('[DETAIL_LOG] Error fetching buku-putih-ledger: $e');
        }

        final parsed = MemberModel.fromJson(data);
        final List rawTrx = data['transactions'] ?? [];

        if (mounted) {
          setState(() {
            _rawData = data;
            _fetched = parsed;
            _transactions = rawTrx.map((e) => Map<String, dynamic>.from(e)).toList();
            _isLoading = false;
          });
        }
      } else {
        debugPrint('[DETAIL_LOG] Server returned status: ${resp.statusCode}');
        if (mounted) {
          setState(() {
            _fetched = widget.member;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[DETAIL_LOG] Exception: $e');
      if (mounted) {
        setState(() {
          _fetched = widget.member;
          _isLoading = false;
        });
      }
    }
  }

  //  BUILD─
  @override
  Widget build(BuildContext context) {
    final m = _fetched ?? widget.member;
    final bool isActive = (m.status.toLowerCase() == 'aktif' || m.status.toLowerCase() == 'active');
    final phone = m.phone.isNotEmpty && m.phone != '-' ? m.phone : '-';
    final email = m.email.isNotEmpty && m.email != '-' ? m.email : '-';

    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Detail Anggota #${m.memberNumber}',
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchDetails,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 14),
              Text('Memuat rincian anggota...', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!isActive) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status Keanggotaan: NONAKTIF / KELUAR',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Anggota ini telah berstatus NONAKTIF / KELUAR. Rekening simpanan dan saham telah ditutup.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFB91C1C),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildProfileCard(m, phone, email),
                const SizedBox(height: 20),
                _buildSavingsCard(m),
                const SizedBox(height: 20),
                _buildHeirCard(m),
                const SizedBox(height: 24),
                const Row(children: [
                  Icon(Icons.history_rounded, size: 18, color: AppColors.adminNavy),
                  SizedBox(width: 6),
                  Text('Riwayat Transaksi Anggota',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                ]),
                const SizedBox(height: 12),
                _buildTrxList(),
              ]),
            ),
      floatingActionButton: isActive
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InputTransaksiScreen(),
                  ),
                ).then((_) {
                  _fetchDetails();
                });
              },
              backgroundColor: AppColors.adminNavy,
              icon: const Icon(Icons.add_card_rounded, color: Colors.white),
              label: const Text('Input Transaksi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  //  SECTION 1: Profil ─
  Widget _buildProfileCard(MemberModel m, String phone, String email) {
    return _card(
      child: Column(children: [
        Row(children: [
          Hero(
            tag: 'member_avatar_${m.id}',
            child: CircleAvatar(
              radius: 32,
              backgroundColor: m.avatarBgColor,
              child: Text(m.initials, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: m.avatarTextColor)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Row(
              children: [
                Text('No. Anggota: ${m.memberNumber}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                if (m.bukuPutihNumber.isNotEmpty && m.bukuPutihNumber != '-' && m.bukuPutihNumber != 'null') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCE93D8)),
                    ),
                    child: Text(
                      'Buku Putih: ${m.bukuPutihNumber.startsWith('2021-') ? m.bukuPutihNumber : "2021-${m.bukuPutihNumber}"}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                    ),
                  ),
                ],
              ],
            ),
            Text('NIK: ${m.nik}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
        ]),
        const Divider(height: 24, color: AppColors.cardBorder),

        // Grid responsif – info pribadi
        LayoutBuilder(
          builder: (context, constraints) {
            return _buildResponsiveGrid(
              constraints: constraints,
              items: [
                _infoTile('No. HP', phone, Icons.phone_android_outlined),
                _infoTile('Email', email, Icons.email_outlined),
                _infoTile('Tempat Lahir', m.placeOfBirth, Icons.location_city_outlined),
                _infoTile('Tgl Lahir', m.dateOfBirth, Icons.cake_outlined),
                _infoTile('Jenis Kelamin', m.gender, Icons.wc_outlined),
                _infoTile('Pekerjaan', m.occupation, Icons.work_outline),
                _infoTile('Pendidikan', m.education, Icons.school_outlined),
                _infoTile('Status Keluarga', m.familyStatus, Icons.family_restroom_outlined),
                _infoTile('Gereja / Sektor', m.churchSector, Icons.church_outlined),
              ],
              addressItem: _infoTileFull('Alamat Tinggal', m.address, Icons.home_outlined),
            );
          },
        ),

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: (m.status == 'aktif' || m.status == 'active') ? AppColors.successBg : AppColors.cardBorder,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (m.status == 'aktif' || m.status == 'active') ? 'Anggota Aktif' : m.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: (m.status == 'aktif' || m.status == 'active') ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  int _calculateExitFee(num totalSavings) {
    if (totalSavings < 1000000) {
      return 100000;
    } else if (totalSavings <= 10000000) {
      return 150000;
    } else if (totalSavings <= 50000000) {
      return 200000;
    } else {
      return 300000;
    }
  }

  // DIALOG TUTUP REKENING BUKU PUTIH SAJA (SIMPANAN HARIAN)
  void _showCloseWhiteBookDialog(MemberModel m) {
    final Map<String, dynamic>? sObj = _rawData?['simpanan'];
    final int dailySavings = int.tryParse(
      (sObj?['daily_savings'] ?? sObj?['simpanan_harian'] ?? sObj?['buku_putih'] ??
       _rawData?['daily_savings'] ?? _rawData?['simpanan_harian'] ?? 0)?.toString() ?? '0'
    ) ?? 0;

    final int fee = _calculateExitFee(dailySavings);
    final int netRefund = (dailySavings - fee) > 0 ? (dailySavings - fee) : 0;
    final TextEditingController voucherController = TextEditingController();
    String? voucherErrorText;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFF59E0B), size: 24),
                  SizedBox(width: 10),
                  Text('Tutup Rekening Buku Putih', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anggota: ${m.name} (#${m.memberNumber})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          _resignRow('Saldo Simpanan Harian (Buku Putih)', _rp(dailySavings), isBold: true),
                          const Divider(height: 12),
                          _resignRow('Biaya Potongan Administrasi (Tier)', '- ${_rp(fee)}', color: AppColors.danger),
                          const Divider(height: 16, thickness: 1.5),
                          _resignRow(
                            'Dana Bersih yang Diterima',
                            _rp(netRefund),
                            isBold: true,
                            color: const Color(0xFF10B981),
                            fontSize: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Input Nomor Bukti Kas Keluar (KK)
                    const Text('Nomor Bukti Kas Keluar (KK)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: voucherController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) {
                        if (voucherErrorText != null) {
                          setDialogState(() => voucherErrorText = null);
                        }
                      },
                      decoration: InputDecoration(
                        prefixText: 'KK ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
                        hintText: '0120',
                        errorText: voucherErrorText,
                        errorMaxLines: 3,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pencairan ini hanya menutup rekening Simpanan Harian (Buku Putih). Keanggotaan koperasi dan hak Buku Biru anggota tetap AKTIF.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (isSubmitting || dailySavings <= 0)
                      ? null
                      : () async {
                          final cleanNo = voucherController.text.trim();
                          if (cleanNo.isEmpty) {
                            setDialogState(() => voucherErrorText = 'Nomor bukti nota KK wajib diisi');
                            return;
                          }

                          setDialogState(() {
                            voucherErrorText = null;
                            isSubmitting = true;
                          });

                          try {
                            final token = await AuthService().getToken();
                            final uri = Uri.parse('${AuthService.staticBaseUrl}/members/${m.id}/close-white-book');
                            final response = await http.post(
                              uri,
                              headers: {
                                'Content-Type': 'application/json',
                                'Accept': 'application/json',
                                if (token != null) 'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode({
                                'voucher_no': 'KK $cleanNo',
                              }),
                            ).timeout(const Duration(seconds: 30));

                            Map<String, dynamic> resData = {};
                            try {
                              resData = jsonDecode(response.body);
                            } catch (_) {}

                            if (response.statusCode == 200 || response.statusCode == 201) {
                              if (ctx.mounted) Navigator.pop(dialogCtx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Rekening Buku Putih ${m.name} berhasil ditutup. Dana dicairkan: ${_rp(netRefund)}'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                _fetchDetails();
                              }
                            } else if (response.statusCode == 422) {
                              String err = resData['message'] ?? 'Validasi gagal';
                              if (resData['errors'] != null && resData['errors'] is Map) {
                                final errs = resData['errors'] as Map<String, dynamic>;
                                final vErr = errs['voucher_no'] ?? errs['voucher_number'] ?? errs['transaction_number'];
                                if (vErr != null) {
                                  err = vErr is List && vErr.isNotEmpty ? vErr.first.toString() : vErr.toString();
                                }
                              }
                              setDialogState(() {
                                voucherErrorText = err;
                                isSubmitting = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
                                );
                              }
                            } else {
                              String rawMsg = (resData['message'] ?? 'Gagal memproses penutupan buku putih').toString();
                              if (rawMsg.contains('SQLSTATE') || rawMsg.contains('1062') || rawMsg.contains('Duplicate entry')) {
                                rawMsg = 'Maaf, Transaksi KK ini sudah ada coba lagi dengan no berbeda';
                                setDialogState(() => voucherErrorText = rawMsg);
                              }
                              setDialogState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(rawMsg), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Proses Pencairan & Tutup Buku Putih'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // DIALOG RESIGN TOTAL / TUTUP BUKU BIRU (KELUAR KOPERASI)
  void _showResignTotalDialog(MemberModel m) {
    final Map<String, dynamic>? sObj = _rawData?['simpanan'];
    final int principalSavings = int.tryParse(
      (sObj?['principal_savings'] ?? sObj?['simpanan_pokok'] ?? _rawData?['principal_savings'] ?? m.principalSavings)?.toString() ?? '0'
    ) ?? 0;
    final int mandatorySavings = int.tryParse(
      (sObj?['mandatory_savings'] ?? sObj?['simpanan_wajib'] ?? _rawData?['mandatory_savings'] ?? m.mandatorySavings)?.toString() ?? '0'
    ) ?? 0;
    final int voluntarySavings = int.tryParse(
      (sObj?['voluntary_savings'] ?? sObj?['simpanan_sukarela'] ?? _rawData?['voluntary_savings'] ?? m.voluntarySavings)?.toString() ?? '0'
    ) ?? 0;
    final int dailySavings = int.tryParse(
      (sObj?['daily_savings'] ?? sObj?['simpanan_harian'] ?? sObj?['buku_putih'] ?? _rawData?['daily_savings'] ?? _rawData?['simpanan_harian'] ?? 0)?.toString() ?? '0'
    ) ?? 0;

    final int totalSaham = principalSavings + mandatorySavings + voluntarySavings;
    final int totalSimpanan = totalSaham + dailySavings;
    final int penaltyAmount = _calculateExitFee(totalSaham > 0 ? totalSaham : totalSimpanan);

    final Map<String, dynamic>? pinjamanData = _rawData?['pinjaman'] ?? _rawData?['loans'];
    final int sisaPinjaman = int.tryParse(
      (pinjamanData?['remaining_balance'] ?? pinjamanData?['sisa_pokok'] ?? _rawData?['loan_remaining'] ?? 0)?.toString() ?? '0'
    ) ?? 0;
    final bool hasActiveLoan = sisaPinjaman > 0;

    final bool isSwArrears6Months = _rawData?['is_sw_arrears_6_months'] == true;
    final String? swWarning = _rawData?['sw_arrears_warning']?.toString();

    final int netRefund = (totalSimpanan - penaltyAmount) > 0 ? (totalSimpanan - penaltyAmount) : 0;
    final TextEditingController voucherController = TextEditingController();
    String? voucherErrorText;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.no_accounts_rounded, color: AppColors.danger, size: 24),
                  SizedBox(width: 10),
                  Text('Pengunduran Diri / Resign Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anggota: ${m.name} (#${m.memberNumber})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // Rincian Modal Saham & Simpanan
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          _resignRow('Simpanan Pokok (SP)', _rp(principalSavings)),
                          const Divider(height: 10),
                          _resignRow('Simpanan Wajib (SW)', _rp(mandatorySavings)),
                          const Divider(height: 10),
                          _resignRow('Simpanan Sukarela (SS)', _rp(voluntarySavings)),
                          const Divider(height: 10),
                          _resignRow('Total Modal Saham', _rp(totalSaham), isBold: true, color: AppColors.primary),
                          if (dailySavings > 0) ...[
                            const Divider(height: 10),
                            _resignRow('Sisa Simpanan Harian (Buku Putih)', _rp(dailySavings)),
                          ],
                          const Divider(height: 12),
                          _resignRow('Total Simpanan Bruto', _rp(totalSimpanan), isBold: true),
                          const Divider(height: 10),
                          _resignRow('Biaya Potongan Keluar (Tier)', '- ${_rp(penaltyAmount)}', color: AppColors.danger),
                          const Divider(height: 16, thickness: 1.5),
                          _resignRow(
                            'Dana Bersih yang Diterima',
                            _rp(netRefund),
                            isBold: true,
                            color: const Color(0xFF10B981),
                            fontSize: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Peringatan Pinjaman Aktif
                    if (hasActiveLoan) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Anggota masih memiliki sisa pinjaman aktif sebesar ${_rp(sisaPinjaman)}. Pelunasan pinjaman wajib diselesaikan sebelum pengunduran diri total.',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Peringatan Tunggakan SW
                    if (isSwArrears6Months || swWarning != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                swWarning ?? 'Tunggakan SW ≥ 6 bulan: Hak SHU/Deviden tahun berjalan gugur.',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Input Nomor Bukti Kas Keluar (KK)
                    const Text('Nomor Bukti Kas Keluar (KK)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: voucherController,
                      enabled: !hasActiveLoan,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) {
                        if (voucherErrorText != null) {
                          setDialogState(() => voucherErrorText = null);
                        }
                      },
                      decoration: InputDecoration(
                        prefixText: 'KK ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
                        hintText: '0120',
                        errorText: voucherErrorText,
                        errorMaxLines: 3,
                        filled: true,
                        fillColor: hasActiveLoan ? Colors.grey.shade100 : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tindakan ini akan menonaktifkan seluruh keanggotaan dan mencairkan seluruh modal simpanan setelah dipotong biaya keluar.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (isSubmitting || hasActiveLoan)
                      ? null
                      : () async {
                          final cleanNo = voucherController.text.trim();
                          if (cleanNo.isEmpty) {
                            setDialogState(() => voucherErrorText = 'Nomor bukti nota KK wajib diisi');
                            return;
                          }

                          setDialogState(() {
                            voucherErrorText = null;
                            isSubmitting = true;
                          });

                          try {
                            final token = await AuthService().getToken();
                            final uri = Uri.parse('${AuthService.staticBaseUrl}/members/${m.id}/resign-total');
                            final response = await http.post(
                              uri,
                              headers: {
                                'Content-Type': 'application/json',
                                'Accept': 'application/json',
                                if (token != null) 'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode({
                                'voucher_no': 'KK $cleanNo',
                              }),
                            ).timeout(const Duration(seconds: 30));

                            Map<String, dynamic> resData = {};
                            try {
                              resData = jsonDecode(response.body);
                            } catch (_) {}

                            if (response.statusCode == 200 || response.statusCode == 201) {
                              if (ctx.mounted) Navigator.pop(dialogCtx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Anggota ${m.name} telah berhasil resign total. Dana dicairkan: ${_rp(netRefund)}'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                _fetchDetails();
                              }
                            } else if (response.statusCode == 422) {
                              String err = resData['message'] ?? 'Validasi gagal';
                              if (resData['errors'] != null && resData['errors'] is Map) {
                                final errs = resData['errors'] as Map<String, dynamic>;
                                final vErr = errs['voucher_no'] ?? errs['voucher_number'] ?? errs['transaction_number'];
                                if (vErr != null) {
                                  err = vErr is List && vErr.isNotEmpty ? vErr.first.toString() : vErr.toString();
                                }
                              }
                              setDialogState(() {
                                voucherErrorText = err;
                                isSubmitting = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
                                );
                              }
                            } else {
                              String rawMsg = (resData['message'] ?? 'Gagal memproses resign').toString();
                              if (rawMsg.contains('SQLSTATE') || rawMsg.contains('1062') || rawMsg.contains('Duplicate entry')) {
                                rawMsg = 'Maaf, Transaksi KK ini sudah ada coba lagi dengan no berbeda';
                                setDialogState(() => voucherErrorText = rawMsg);
                              }
                              setDialogState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(rawMsg), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Setujui Resign & Cairkan Seluruh Hak'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _resignRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 12}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  //  SECTION 2: Simpanan ─
  Widget _buildSavingsCard(MemberModel m) {
    final Map<String, dynamic>? sObj = _rawData?['simpanan'];

    final int principalSavings = int.tryParse(
      (sObj?['principal_savings'] ?? sObj?['simpanan_pokok'] ??
       _rawData?['principal_savings'] ?? _rawData?['simpanan_pokok'] ??
       m.principalSavings)?.toString() ?? '0'
    ) ?? 0;

    final int mandatorySavings = int.tryParse(
      (sObj?['mandatory_savings'] ?? sObj?['simpanan_wajib'] ??
       _rawData?['mandatory_savings'] ?? _rawData?['simpanan_wajib'] ??
       m.mandatorySavings)?.toString() ?? '0'
    ) ?? 0;

    final int voluntarySavings = int.tryParse(
      (sObj?['voluntary_savings'] ?? sObj?['simpanan_sukarela'] ??
       _rawData?['voluntary_savings'] ?? _rawData?['simpanan_sukarela'] ??
       m.voluntarySavings)?.toString() ?? '0'
    ) ?? 0;

    final int dailySavings = int.tryParse(
      (sObj?['daily_savings'] ?? sObj?['buku_putih'] ??
       _rawData?['daily_savings'] ?? _rawData?['buku_putih'] ?? '0')?.toString() ?? '0'
    ) ?? 0;

    final int griefFund = int.tryParse(
      (sObj?['grief_fund'] ?? sObj?['dana_duka'] ??
       _rawData?['grief_fund'] ?? _rawData?['dana_duka'] ??
       m.griefFund)?.toString() ?? '0'
    ) ?? 0;

    final total = principalSavings + mandatorySavings + voluntarySavings + dailySavings;
    final blueTotal = principalSavings + mandatorySavings + voluntarySavings;
    final whiteTotal = dailySavings;

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Portofolio Simpanan Anggota',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
          ]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total Portofolio Keseluruhan',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              Text(_rp(total),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ]),
        const Divider(height: 20, color: AppColors.cardBorder),

        // Tab Switched Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Switcher Segmented Button
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _tabButton(
                    title: 'Buku Biru (Saham)',
                    isActive: _selectedBookTab == 'biru',
                    onTap: () => setState(() => _selectedBookTab = 'biru'),
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  _tabButton(
                    title: 'Buku Putih (Harian)',
                    isActive: _selectedBookTab == 'putih',
                    onTap: () => setState(() => _selectedBookTab = 'putih'),
                    activeColor: const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
            // Total Saldo Buku Aktif
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _selectedBookTab == 'biru' ? 'Total Saldo Buku Biru' : 'Total Saldo Buku Putih',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                Text(
                  _rp(_selectedBookTab == 'biru' ? blueTotal : whiteTotal),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _selectedBookTab == 'biru' ? AppColors.primary : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            int cols = 1;

            final List<Widget> cards = [];
            if (_selectedBookTab == 'biru') {
              cards.addAll([
                _savingsTile('Simpanan Pokok (SP)', principalSavings, AppColors.primary, 'Buku Biru'),
                _savingsTile('Simpanan Wajib (SW)', mandatorySavings, const Color(0xFF0284C7), 'Buku Biru'),
                _savingsTile('Simpanan Sukarela (SS)', voluntarySavings, const Color(0xFFD97706), 'Buku Biru'),
              ]);
              if (griefFund > 0) {
                cards.add(_savingsTile('Dana Duka / Sosial', griefFund, const Color(0xFF7C3AED), 'Lainnya'));
              }
            } else {
              cards.add(_savingsTile('Simpanan Harian (SH)', dailySavings, const Color(0xFF10B981), 'Buku Putih'));
            }

            final int cardCount = cards.length;
            if (width > 900) {
              cols = cardCount.clamp(1, 4);
            } else if (width > 600) {
              cols = cardCount.clamp(1, 2);
            }
            final double spacing = 8.0;
            final int spacingCount = cols - 1;
            final double totalSpacing = spacing * spacingCount;
            final double cardWidth = (width - totalSpacing) / cols;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: cards.map((c) => SizedBox(width: cardWidth > 0 ? cardWidth : 120, child: c)).toList(),
                ),
                if (_selectedBookTab == 'putih') ...[
                  const SizedBox(height: 18),
                  _buildWhiteBook12CycleTable(m, dailySavings),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 12),
                if (_selectedBookTab == 'putih')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Tutup rekening hanya mencairkan Simpanan Harian. Keanggotaan dan Buku Biru tetap aktif.',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _handlePrintWhiteBook(m),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: const Text('Cetak Buku Putih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          ElevatedButton.icon(
                            onPressed: ((m.status != 'aktif' && m.status != 'active') || dailySavings <= 0)
                                ? null
                                : () => _showCloseWhiteBookDialog(m),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                            label: const Text('Tutup Rekening Buku Putih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Pengunduran diri akan mencairkan seluruh modal saham dan menonaktifkan keanggotaan.',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: (m.status != 'aktif' && m.status != 'active')
                            ? null
                            : () => _showResignTotalDialog(m),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.no_accounts_rounded, size: 16),
                        label: const Text('Pengunduran Diri / Resign Keanggotaan Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ]),
    );
  }

  Future<void> _handlePrintWhiteBook(MemberModel m) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Menyiapkan & mengunduh Lembar Buku Putih...'),
            ],
          ),
          backgroundColor: Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      await MemberStatementPdfService().exportWhiteBookPdf(
        int.tryParse(m.id) ?? 0,
        memberName: m.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh dokumen: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── TOGGLE STATUS KEAKTIFAN BUKU PUTIH (API PATCH + REAKTIF) ─────
  Future<void> _toggleWhiteBookActiveStatus(MemberModel m, bool currentStatus) async {
    final bool nextStatus = !currentStatus;
    final String nextStatusLabel = nextStatus ? 'Aktif' : 'Tidak Aktif';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              nextStatus ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
              color: nextStatus ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              size: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Konfirmasi Status Keaktifan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ubah status keaktifan anggota ini? Anggota tidak aktif tidak akan menerima bunga 0,6%.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: nextStatus ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: nextStatus ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    nextStatus ? Icons.trending_up_rounded : Icons.money_off_rounded,
                    size: 16,
                    color: nextStatus ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nextStatus
                          ? 'Status baru: AKTIF (Menerima bunga 0,6% per bulan).'
                          : 'Status baru: TIDAK AKTIF (Bunga otomatis Rp 0 pada tabel mutasi).',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: nextStatus ? const Color(0xFF166534) : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nextStatus ? const Color(0xFF16A34A) : AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Ubah Status ke $nextStatusLabel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isTogglingStatus = true;
    });

    try {
      final token = await AuthService().getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final payload = jsonEncode({
        'is_active': nextStatus,
        'status': nextStatus ? 'aktif' : 'tidak_aktif',
        'white_book_active': nextStatus,
        'is_white_book_active': nextStatus,
        'status_buku_putih': nextStatus ? 'aktif' : 'tidak_aktif',
      });

      // Request API PATCH ke backend toggle-status Buku Putih
      var resp = await http.patch(
        Uri.parse('${AuthService.staticBaseUrl}/buku-putih/members/${m.id}/toggle-status'),
        headers: headers,
        body: payload,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 404 || resp.statusCode == 405) {
        resp = await http.patch(
          Uri.parse('${AuthService.staticBaseUrl}/members/${m.id}/toggle-status'),
          headers: headers,
          body: payload,
        ).timeout(const Duration(seconds: 15));
      }

      if (resp.statusCode == 404 || resp.statusCode == 405) {
        resp = await http.patch(
          Uri.parse('${AuthService.staticBaseUrl}/members/${m.id}/status'),
          headers: headers,
          body: payload,
        ).timeout(const Duration(seconds: 15));
      }

      if (resp.statusCode == 404 || resp.statusCode == 405) {
        resp = await http.patch(
          Uri.parse('${AuthService.staticBaseUrl}/members/${m.id}'),
          headers: headers,
          body: payload,
        ).timeout(const Duration(seconds: 15));
      }

      if (resp.statusCode == 405) {
        resp = await http.post(
          Uri.parse('${AuthService.staticBaseUrl}/buku-putih/members/${m.id}/toggle-status'),
          headers: headers,
          body: payload,
        ).timeout(const Duration(seconds: 15));
      }

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        try {
          final resBody = jsonDecode(resp.body);
          final updatedData = resBody['data'] ?? resBody['member'] ?? resBody['statement'] ?? resBody;
          if (updatedData is Map<String, dynamic>) {
            _rawData = {...?_rawData, ...updatedData};
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _whiteBookStatusOverride = nextStatus;
          _isTogglingStatus = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  nextStatus ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Status keaktifan anggota berhasil diubah menjadi $nextStatusLabel'),
                ),
              ],
            ),
            backgroundColor: nextStatus ? AppColors.success : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Muat ulang data terbaru dengan preserveOverride agar sinkron penuh dengan server
        _fetchDetails(preserveOverride: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _whiteBookStatusOverride = nextStatus;
          _isTogglingStatus = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status keaktifan lokal diubah ke $nextStatusLabel'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _calculateWhiteBookMultiRow(MemberModel m, int dailySavings) {
    // 1. Cek apakah backend API (BukuPutihLedgerService) mengirim array siklus/statement Buku Putih siap pakai
    final Map<String, dynamic>? serverStatement =
        (_rawData?['buku_putih_ledger'] is Map ? _rawData!['buku_putih_ledger'] as Map<String, dynamic> : null) ??
        (_rawData?['white_book_statement'] is Map ? _rawData!['white_book_statement'] as Map<String, dynamic> : null) ??
        (_rawData?['buku_putih_statement'] is Map ? _rawData!['buku_putih_statement'] as Map<String, dynamic> : null) ??
        (_rawData?['white_book'] is Map ? _rawData!['white_book'] as Map<String, dynamic> : null) ??
        (_rawData?['buku_putih'] is Map ? _rawData!['buku_putih'] as Map<String, dynamic> : null);

    final List serverCycles = (serverStatement?['cycles'] as List?) ?? (_rawData?['cycles'] as List?) ?? [];
    final List serverFlatRows = (serverStatement?['rows'] as List?) ?? (serverStatement?['items'] as List?) ?? [];

    if (serverCycles.isNotEmpty) {
      final List<Map<String, dynamic>> allRows = [];
      num totalSetor = (serverStatement?['total_deposit'] ?? serverStatement?['total_setor'] ?? serverStatement?['total_setoran'] ?? serverStatement?['total_simpanan'] as num?)?.toDouble() ?? 0;
      num totalTarik = (serverStatement?['total_withdrawal'] ?? serverStatement?['total_tarik'] ?? serverStatement?['total_penarikan'] as num?)?.toDouble() ?? 0;
      num totalJasa = (serverStatement?['total_interest'] ?? serverStatement?['total_jasa'] ?? serverStatement?['total_bunga'] ?? _rawData?['total_jasa_buku_putih'] ?? _rawData?['total_jasa'] as num?)?.toDouble() ?? 0;
      num lastSaldo = (serverStatement?['closing_balance'] ?? serverStatement?['last_saldo'] ?? serverStatement?['final_balance'] ?? serverStatement?['saldo_akhir'] as num?)?.toDouble() ?? 0;
      bool isActive = _whiteBookStatusOverride ??
          (serverStatement?['is_active'] == true ||
           serverStatement?['status'] == 'AKTIF' ||
           serverStatement?['status'] == 'aktif' ||
           _rawData?['is_white_book_active'] == true ||
           _rawData?['white_book_active'] == true);
      int activeMonths = (serverStatement?['active_months_count'] ?? serverStatement?['active_months'] as int?) ?? 0;
      int passiveMonths = (serverStatement?['passive_months_count'] ?? serverStatement?['passive_months'] as int?) ?? (12 - activeMonths);

      for (var c in serverCycles) {
        if (c is! Map) continue;
        final cycleMap = Map<String, dynamic>.from(c);
        final String monthLabel = (cycleMap['month_name'] ?? cycleMap['month_label'] ?? cycleMap['bulan'] ?? '').toString();
        final int mNum = (cycleMap['month'] as num?)?.toInt() ?? 0;
        final int yNum = (cycleMap['year'] as num?)?.toInt() ?? 0;
        final List cycleRows = (cycleMap['rows'] as List?) ?? (cycleMap['transactions'] as List?) ?? [];

        if (cycleRows.isNotEmpty) {
          final int cycleRowCount = cycleRows.length;
          for (int rIdx = 0; rIdx < cycleRowCount; rIdx++) {
            final r = cycleRows[rIdx] is Map ? Map<String, dynamic>.from(cycleRows[rIdx]) : <String, dynamic>{};
            final String rawType = (r['type'] ?? '').toString().toUpperCase();
            final String rawVoucher = (r['voucher_no'] ?? r['evidence_no'] ?? r['receipt_number'] ?? '').toString().trim();
            final bool isMem = r['is_memorial'] == true ||
                rawType == 'BM' ||
                rawVoucher.startsWith('BM-INT') ||
                rawVoucher.startsWith('BM-') ||
                (r['interest'] as num? ?? 0) > 0;

            final String rawDate = (r['date'] ?? r['tanggal'] ?? '').toString();
            String tgl = rawDate;
            if (rawDate.contains('-')) {
              final parts = rawDate.split('-');
              if (parts.length >= 3) {
                tgl = '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}';
              }
            }
            if (tgl.isEmpty || tgl == '-') {
              tgl = '20/${mNum.toString().padLeft(2, '0')}';
            }

            final String targetYm = '$yNum${mNum.toString().padLeft(2, '0')}';
            final String vNo = rawVoucher.isNotEmpty
                ? rawVoucher
                : (isMem ? 'BM-INT-$targetYm' : (rawType == 'KK' ? 'KK' : 'KM'));

            final num deposit = (r['deposit'] ?? r['setoran'] ?? 0) as num;
            final num withdrawal = (r['withdrawal'] ?? r['penarikan'] ?? 0) as num;
            final num interest = (r['interest'] ?? r['jasa'] ?? r['bunga'] ?? 0) as num;
            final num balance = (r['balance'] ?? r['running_balance'] ?? r['saldo'] ?? cycleMap['closing_balance'] ?? 0) as num;
            final bool isWithdrawal = rawType == 'KK' || withdrawal > 0 || (r['is_withdrawal'] == true);

            allRows.add({
              'month_label': monthLabel,
              'is_first_in_month': rIdx == 0,
              'is_last_in_month': rIdx == cycleRowCount - 1,
              'row_index_in_month': rIdx,
              'row_count_in_month': cycleRowCount,
              'tgl': tgl,
              'tanda_bukti': vNo,
              'setoran': deposit,
              'penarikan': withdrawal,
              'jasa': isActive ? interest : 0,
              'saldo': balance,
              'is_interest': isMem,
              'is_withdrawal': isWithdrawal,
            });
          }
        } else {
          final num interest = (cycleMap['interest'] ?? cycleMap['jasa'] ?? cycleMap['bunga'] ?? 0) as num;
          final num balance = (cycleMap['closing_balance'] ?? cycleMap['saldo'] ?? cycleMap['saldo_akhir'] ?? 0) as num;
          final String targetYm = '$yNum${mNum.toString().padLeft(2, '0')}';

          allRows.add({
            'month_label': monthLabel,
            'is_first_in_month': true,
            'is_last_in_month': true,
            'row_index_in_month': 0,
            'row_count_in_month': 1,
            'tgl': '20/${mNum.toString().padLeft(2, '0')}',
            'tanda_bukti': 'BM-INT-$targetYm',
            'setoran': (cycleMap['total_deposit'] ?? cycleMap['setoran'] ?? 0) as num,
            'penarikan': (cycleMap['total_withdrawal'] ?? cycleMap['penarikan'] ?? 0) as num,
            'jasa': isActive ? interest : 0,
            'saldo': balance,
            'is_interest': true,
            'is_withdrawal': false,
          });
        }
      }

      if (allRows.isNotEmpty) {
        if (lastSaldo == 0 && allRows.isNotEmpty) {
          lastSaldo = (allRows.last['saldo'] as num?)?.toDouble() ?? 0;
        }

        return {
          'rows': allRows,
          'is_active': isActive,
          'status_label': isActive ? 'STATUS: AKTIF' : 'STATUS: TIDAK AKTIF',
          'membership_status': isActive ? 'AKTIF' : 'TIDAK AKTIF',
          'active_months_count': activeMonths > 0 ? activeMonths : allRows.where((r) => ((r['setoran'] as num?) ?? 0) > 0 || ((r['penarikan'] as num?) ?? 0) > 0).length,
          'passive_months_count': passiveMonths,
          'consecutive_passive_months': 0,
          'total_setor': totalSetor,
          'total_tarik': totalTarik,
          'total_jasa': isActive ? totalJasa : 0,
          'total_jasa_official': isActive ? totalJasa : 0,
          'last_saldo': lastSaldo,
        };
      }
    } else if (serverFlatRows.isNotEmpty) {
      final List<Map<String, dynamic>> allRows = [];
      num totalSetor = (serverStatement?['total_setor'] ?? serverStatement?['total_deposit'] ?? serverStatement?['total_simpanan'] as num?)?.toDouble() ?? 0;
      num totalTarik = (serverStatement?['total_tarik'] ?? serverStatement?['total_withdrawal'] as num?)?.toDouble() ?? 0;
      num totalJasa = (serverStatement?['total_jasa'] ?? serverStatement?['total_interest'] ?? serverStatement?['total_bunga'] ?? _rawData?['total_jasa_buku_putih'] ?? _rawData?['total_jasa'] as num?)?.toDouble() ?? 0;
      num lastSaldo = (serverStatement?['last_saldo'] ?? serverStatement?['closing_balance'] ?? serverStatement?['final_balance'] ?? serverStatement?['saldo_akhir'] as num?)?.toDouble() ?? 0;
      bool isActive = _whiteBookStatusOverride ??
          (serverStatement?['is_active'] == true ||
           serverStatement?['status'] == 'AKTIF' ||
           serverStatement?['status'] == 'aktif' ||
           _rawData?['is_white_book_active'] == true ||
           _rawData?['white_book_active'] == true);
      int activeMonths = (serverStatement?['active_months_count'] ?? serverStatement?['active_months'] as int?) ?? 0;

      for (var r in serverFlatRows) {
        if (r is Map) {
          allRows.add(Map<String, dynamic>.from(r));
        }
      }

      if (allRows.isNotEmpty) {
        for (int i = 0; i < allRows.length; i++) {
          final row = allRows[i];
          final String monthLabel = (row['month_label'] ?? row['bulan'] ?? '').toString();
          final bool isFirst = i == 0 || (allRows[i - 1]['month_label'] ?? allRows[i - 1]['bulan']).toString() != monthLabel;
          row['is_first_in_month'] = isFirst;
        }

        if (totalSetor == 0 && totalTarik == 0 && totalJasa == 0) {
          for (var r in allRows) {
            totalSetor += (r['setoran'] as num?)?.toDouble() ?? 0;
            totalTarik += (r['penarikan'] as num?)?.toDouble() ?? 0;
            totalJasa += (r['jasa'] as num?)?.toDouble() ?? 0;
          }
          lastSaldo = (allRows.last['saldo'] as num?)?.toDouble() ?? lastSaldo;
        }

        if (!isActive) {
          totalJasa = 0;
          for (var r in allRows) {
            if (r['is_interest'] == true || (r['jasa'] as num? ?? 0) > 0) {
              r['jasa'] = 0;
            }
          }
        }

        return {
          'rows': allRows,
          'is_active': isActive,
          'status_label': isActive ? 'STATUS: AKTIF' : 'STATUS: TIDAK AKTIF',
          'membership_status': isActive ? 'AKTIF' : 'TIDAK AKTIF',
          'active_months_count': activeMonths > 0 ? activeMonths : allRows.where((r) => ((r['setoran'] as num?) ?? 0) > 0 || ((r['penarikan'] as num?) ?? 0) > 0).length,
          'passive_months_count': 12 - activeMonths,
          'consecutive_passive_months': 0,
          'total_setor': totalSetor,
          'total_tarik': totalTarik,
          'total_jasa': isActive ? totalJasa : 0,
          'total_jasa_official': isActive ? totalJasa : 0,
          'last_saldo': lastSaldo,
        };
      }
    }

    final now = DateTime.now();
    final int currentYear = now.year;
    final int startYear = now.month >= 6 ? currentYear : (currentYear - 1);
    final int endYear = startYear + 1;

    final List<Map<String, dynamic>> cycleMonths = [];
    final List<String> monthNames = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final List<String> shortCodes = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];

    for (int month = 6; month <= 12; month++) {
      cycleMonths.add({
        'month': month,
        'year': startYear,
        'label': '${monthNames[month]} $startYear',
        'code': '${shortCodes[month]}-${startYear.toString().substring(2)}',
      });
    }
    for (int month = 1; month <= 5; month++) {
      cycleMonths.add({
        'month': month,
        'year': endYear,
        'label': '${monthNames[month]} $endYear',
        'code': '${shortCodes[month]}-${endYear.toString().substring(2)}',
      });
    }

    // Filter transaksi Buku Putih
    final whiteTrxs = _transactions.where((t) {
      final String bookType = (t['book_type'] ?? '').toString().toUpperCase();
      final String category = (t['category'] ?? t['title'] ?? '').toString().toLowerCase();
      final String desc = (t['description'] ?? '').toString().toLowerCase();

      return bookType == 'BUKU_PUTIH' ||
             category.contains('harian') ||
             category.contains('putih') ||
             category.contains('sh') ||
             category.contains('bunga') ||
             desc.contains('buku putih') ||
             desc.contains('simpanan harian');
    }).toList();

    // Saldo awal tahun buku (Juni): 0 murni (jangan gunakan daily_savings saat ini karena akan mendobelkan transaksi)
    num runningBalance = (serverStatement?['initial_balance'] ?? serverStatement?['saldo_awal'] as num?)?.toDouble() ?? 0.0;

    // Cek apakah anggota memiliki transaksi kas riil (KM/KK) di periode berjalan ini
    final bool hasCashInPeriod = whiteTrxs.any((t) {
      final String type = (t['type'] ?? '').toString().toLowerCase();
      final String cat = (t['category'] ?? t['title'] ?? '').toString().toLowerCase();
      final String desc = (t['description'] ?? '').toString().toLowerCase();
      final String rawProof = (t['receipt_number'] ?? t['voucher_no'] ?? t['transaction_number'] ?? '').toString().trim();
      final bool isMemorial = cat.contains('bunga') || desc.contains('bunga') || rawProof.contains('BM-INT') || rawProof.contains('BM-');
      final bool isRealCash = (type == 'deposit' || type == 'in' || type == 'kas_masuk' || type == 'km' ||
                               type == 'withdrawal' || type == 'out' || type == 'kas_keluar' || type == 'kk') && !isMemorial;
      return isRealCash;
    });

    final List<Map<String, dynamic>> allRows = [];
    int consecutivePassiveMonths = 0;
    int activeCashMonthsCount = 0;
    num grandTotalSetor = 0;
    num grandTotalTarik = 0;
    num grandTotalJasa = 0;

    for (int i = 0; i < cycleMonths.length; i++) {
      final cm = cycleMonths[i];
      final int m = cm['month'] as int;
      final int y = cm['year'] as int;
      final String monthLabel = cm['label'] as String;

      final cycleStart = DateTime(m == 1 ? y - 1 : y, m == 1 ? 12 : m - 1, 21);
      final cycleEnd = DateTime(y, m, 20, 23, 59, 59);

      final monthTrxs = whiteTrxs.where((t) {
        final rawDate = (t['transaction_date'] ?? t['date'] ?? t['tanggal'] ?? t['created_at'] ?? '').toString();
        final dt = DateTime.tryParse(rawDate);
        if (dt == null) return false;
        return dt.isAfter(cycleStart.subtract(const Duration(seconds: 1))) &&
               dt.isBefore(cycleEnd.add(const Duration(seconds: 1)));
      }).toList();

      final List<Map<String, dynamic>> cashTrxs = [];
      num existingDbInterest = 0;
      String? existingBmProof;

      for (var t in monthTrxs) {
        final num amt = (t['amount'] is num) ? t['amount'] as num : (num.tryParse(t['amount']?.toString() ?? '0') ?? 0);
        final String rawProof = (t['receipt_number'] ?? t['voucher_no'] ?? t['transaction_number'] ?? '').toString().trim();
        final String cat = (t['category'] ?? t['title'] ?? '').toString().toLowerCase();
        final String desc = (t['description'] ?? '').toString().toLowerCase();

        final bool isInterest = cat.contains('bunga') || desc.contains('bunga') || rawProof.contains('BM-INT');

        if (isInterest) {
          existingDbInterest += amt;
          if (rawProof.isNotEmpty) existingBmProof = rawProof;
        } else {
          cashTrxs.add(t);
        }
      }

      // Evaluasi Keaktifan Siklus
      final bool isCycleActive = hasCashInPeriod;
      if (cashTrxs.isNotEmpty) {
        activeCashMonthsCount++;
        consecutivePassiveMonths = 0;
      } else {
        consecutivePassiveMonths++;
      }

      final List<Map<String, dynamic>> monthRowItems = [];

      // 1. Baris Transaksi Kas (KM / KK)
      for (var t in cashTrxs) {
        final num amt = (t['amount'] is num) ? t['amount'] as num : (num.tryParse(t['amount']?.toString() ?? '0') ?? 0);
        final String rawProof = (t['receipt_number'] ?? t['voucher_no'] ?? t['transaction_number'] ?? '').toString().trim();
        final String cat = (t['category'] ?? t['title'] ?? '').toString().toLowerCase();
        final String type = (t['type'] ?? '').toString().toLowerCase();
        final bool isWithdrawal = type == 'withdrawal' || type == 'out' || type == 'kas_keluar' || type == 'kk' || cat.contains('penarikan');

        num setoran = 0;
        num penarikan = 0;

        if (isWithdrawal) {
          penarikan = amt;
          runningBalance = (runningBalance - amt).clamp(0, double.infinity);
          grandTotalTarik += penarikan;
        } else {
          setoran = amt;
          runningBalance = runningBalance + amt;
          grandTotalSetor += setoran;
        }

        String tgl = '20/${m.toString().padLeft(2, '0')}';
        final rawDate = (t['transaction_date'] ?? t['date'] ?? t['tanggal'] ?? t['created_at'] ?? '').toString();
        final dt = DateTime.tryParse(rawDate);
        if (dt != null) {
          tgl = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
        }

        final String voucherNo = rawProof.isNotEmpty
            ? (isWithdrawal ? (rawProof.startsWith('KK') ? rawProof : 'KK-$rawProof') : (rawProof.startsWith('KM') ? rawProof : 'KM-$rawProof'))
            : (isWithdrawal ? 'KK' : 'KM');

        monthRowItems.add({
          'month_label': monthLabel,
          'tgl': tgl,
          'tanda_bukti': voucherNo,
          'setoran': setoran,
          'penarikan': penarikan,
          'jasa': 0,
          'saldo': runningBalance,
          'is_interest': false,
          'is_withdrawal': isWithdrawal,
          'is_cycle_active': isCycleActive,
          'consecutive_passive_months': consecutivePassiveMonths,
        });
      }

      // 2. Baris Bunga Bulanan (BM 0.6%)
      num interestAmount = 0;
      if (isCycleActive) {
        interestAmount = existingDbInterest;
        if (interestAmount == 0 && runningBalance > 0) {
          // Bunga 0.6% diberikan setiap bulan berdasarkan saldo aktif yang ada
          interestAmount = (runningBalance * 0.006).round();
        }
      }

      if (interestAmount > 0) {
        runningBalance = runningBalance + interestAmount;
        grandTotalJasa += interestAmount;
      }

      final String targetYm = '$y${m.toString().padLeft(2, '0')}';
      final String bmVoucher = existingBmProof ?? 'BM-INT-$targetYm';
      final String bmTgl = '20/${m.toString().padLeft(2, '0')}';

      monthRowItems.add({
        'month_label': monthLabel,
        'tgl': bmTgl,
        'tanda_bukti': bmVoucher,
        'setoran': 0,
        'penarikan': 0,
        'jasa': interestAmount,
        'saldo': runningBalance,
        'is_interest': true,
        'is_withdrawal': false,
        'is_cycle_active': isCycleActive,
        'consecutive_passive_months': consecutivePassiveMonths,
      });

      final int rowCountInMonth = monthRowItems.length;
      for (int r = 0; r < rowCountInMonth; r++) {
        final item = monthRowItems[r];
        allRows.add({
          ...item,
          'is_first_in_month': r == 0,
          'is_last_in_month': r == rowCountInMonth - 1,
          'row_index_in_month': r,
          'row_count_in_month': rowCountInMonth,
        });
      }
    }

    final bool isCurrentActive = _whiteBookStatusOverride ??
        (_rawData?['is_white_book_active'] == true ||
         _rawData?['white_book_active'] == true ||
         hasCashInPeriod ||
         activeCashMonthsCount > 0);
    final int passiveMonthsCount = 12 - activeCashMonthsCount;

    final num officialTotalJasa = (serverStatement?['total_jasa'] ??
                                   serverStatement?['total_interest'] ??
                                   serverStatement?['total_bunga'] ??
                                   _rawData?['total_jasa_buku_putih'] ??
                                   _rawData?['buku_putih_total_jasa'] ??
                                   _rawData?['total_jasa'] as num?)?.toDouble() ?? grandTotalJasa;

    if (!isCurrentActive) {
      grandTotalJasa = 0;
      for (var r in allRows) {
        if (r['is_interest'] == true || (r['jasa'] as num? ?? 0) > 0) {
          r['jasa'] = 0;
        }
      }
    }

    return {
      'rows': allRows,
      'is_active': isCurrentActive,
      'status_label': isCurrentActive ? 'STATUS: AKTIF' : 'STATUS: TIDAK AKTIF',
      'membership_status': isCurrentActive ? 'AKTIF' : 'TIDAK AKTIF',
      'active_months_count': activeCashMonthsCount,
      'passive_months_count': passiveMonthsCount,
      'consecutive_passive_months': consecutivePassiveMonths,
      'total_setor': grandTotalSetor,
      'total_tarik': grandTotalTarik,
      'total_jasa': isCurrentActive ? grandTotalJasa : 0,
      'total_jasa_official': isCurrentActive ? officialTotalJasa : 0,
      'last_saldo': runningBalance,
    };
  }

  Widget _buildWhiteBook12CycleTable(MemberModel m, int dailySavings) {
    final result = _calculateWhiteBookMultiRow(m, dailySavings);
    final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(result['rows'] ?? []);
    final bool isWhiteBookActive = result['is_active'] == true;
    final int activeCashMonths = result['active_months_count'] as int? ?? 0;
    final num totalSetor = result['total_setor'] as num? ?? 0;
    final num totalTarik = result['total_tarik'] as num? ?? 0;
    final num totalJasa = (result['total_jasa_official'] ?? result['total_jasa']) as num? ?? 0;
    final num lastSaldo = result['last_saldo'] as num? ?? (rows.isNotEmpty ? (rows.last['saldo'] as num? ?? dailySavings) : dailySavings);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_rows_rounded, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'Tabel Mutasi Buku Putih (12 Siklus Multi-Row)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.adminNavy,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Tombol / Switch Status Keaktifan Interaktif
                    InkWell(
                      onTap: _isTogglingStatus ? null : () => _toggleWhiteBookActiveStatus(m, isWhiteBookActive),
                      borderRadius: BorderRadius.circular(6),
                      child: Tooltip(
                        message: 'Klik untuk mengubah status keaktifan anggota',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isWhiteBookActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isWhiteBookActive ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isWhiteBookActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isTogglingStatus)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.adminNavy),
                                )
                              else
                                Icon(
                                  isWhiteBookActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  size: 13,
                                  color: isWhiteBookActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              const SizedBox(width: 5),
                              Text(
                                isWhiteBookActive
                                    ? 'STATUS: AKTIF ⇅'
                                    : 'STATUS: TIDAK AKTIF ⇅',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isWhiteBookActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.touch_app_rounded,
                                size: 12,
                                color: isWhiteBookActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Badge Total Jasa Simpanan
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, size: 13, color: Color(0xFFD97706)),
                          const SizedBox(width: 5),
                          Text(
                            'Total Jasa: ${_rp(isWhiteBookActive ? totalJasa : 0)}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 780),
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 40,
                columnSpacing: 16,
                horizontalMargin: 14,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('Bulan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Tgl', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Tanda Bukti', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Simpanan (Setoran)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Penarikan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Jasa 0.6%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
                  DataColumn(numeric: true, label: Text('Saldo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.adminNavy))),
                ],
                rows: [
                  ...rows.map((row) {
                    final bool isInterest = row['is_interest'] == true;
                    final bool isFirstInMonth = row['is_first_in_month'] == true;
                    final bool isWithdrawal = row['is_withdrawal'] == true;
                    final String monthLabel = row['month_label'].toString();
                    final String tgl = row['tgl'].toString();
                    final String voucherNo = row['tanda_bukti'].toString();
                    final num setor = row['setoran'] as num;
                    final num tarik = row['penarikan'] as num;
                    final num jasa = isWhiteBookActive ? (row['jasa'] as num) : 0;
                    final num saldo = row['saldo'] as num;

                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (isInterest) {
                          return const Color(0xFFFEF9C3); // Highlight Baris Bunga (BM)
                        }
                        return isFirstInMonth ? Colors.white : const Color(0xFFFAFAFA);
                      }),
                      cells: [
                        // 1. Kolom Bulan (Grouping rowSpan visual)
                        DataCell(
                          isFirstInMonth
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: isInterest ? const Color(0xFFF59E0B) : const Color(0xFF0284C7),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      monthLabel,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                                    ),
                                  ],
                                )
                              : const Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Text('↳', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                ),
                        ),
                        // 2. Kolom Tgl
                        DataCell(
                          Text(
                            tgl,
                            style: TextStyle(
                              fontSize: 11,
                              color: isInterest ? const Color(0xFFB45309) : AppColors.textMuted,
                              fontWeight: isInterest ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        // 3. Kolom Tanda Bukti (KM / KK / BM)
                        DataCell(
                          isInterest
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                                  ),
                                  child: Text(
                                    voucherNo,
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isWithdrawal ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    voucherNo,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isWithdrawal ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                        ),
                        // 4. Kolom Simpanan (Setoran)
                        DataCell(
                          Text(
                            setor > 0 ? _rp(setor) : '-',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: setor > 0 ? FontWeight.bold : FontWeight.normal,
                              color: setor > 0 ? const Color(0xFF166534) : AppColors.textMuted,
                            ),
                          ),
                        ),
                        // 5. Kolom Penarikan
                        DataCell(
                          Text(
                            tarik > 0 ? _rp(tarik) : '-',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: tarik > 0 ? FontWeight.bold : FontWeight.normal,
                              color: tarik > 0 ? AppColors.danger : AppColors.textMuted,
                            ),
                          ),
                        ),
                        // 6. Kolom Jasa 0.6%
                        DataCell(
                          Text(
                            (isWhiteBookActive && jasa > 0)
                                ? '+ ${_rp(jasa)}'
                                : (isInterest
                                    ? 'Rp 0'
                                    : '-'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: (isWhiteBookActive && jasa > 0) ? FontWeight.bold : FontWeight.normal,
                              color: (isWhiteBookActive && jasa > 0)
                                  ? const Color(0xFF047857)
                                  : (!isWhiteBookActive && isInterest ? const Color(0xFF991B1B) : AppColors.textMuted),
                            ),
                          ),
                        ),
                        // 7. Kolom Saldo
                        DataCell(
                          Text(
                            _rp(saldo),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isInterest ? const Color(0xFF0F766E) : AppColors.adminNavy,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  DataRow(
                    color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    cells: [
                      const DataCell(Text('TOTAL 12 SIKLUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.adminNavy))),
                      const DataCell(Text('-', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
                      const DataCell(Text('-', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
                      DataCell(Text(_rp(totalSetor), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)))),
                      DataCell(Text(_rp(totalTarik), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: totalTarik > 0 ? AppColors.danger : AppColors.textMuted))),
                      DataCell(Text(_rp(isWhiteBookActive ? totalJasa : 0), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (isWhiteBookActive && totalJasa > 0) ? const Color(0xFF047857) : const Color(0xFF991B1B)))),
                      DataCell(Text(_rp(lastSaldo), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Catatan Keterangan Keaktifan Simpanan Buku Putih
          if (!isWhiteBookActive)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catatan: Bunga 0,6% tidak diberikan (Rp 0) karena status keaktifan anggota Tidak Aktif.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontStyle: FontStyle.italic, height: 1.3),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catatan: Simpanan berstatus AKTIF ($activeCashMonths/12 bulan transaksi kas). Bunga simpanan 0,6% per bulan diberikan secara penuh.',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534), fontStyle: FontStyle.italic, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? activeColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.adminNavy : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savingsTile(String label, int amount, Color color, String bookType) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                bookType,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(_rp(amount), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  //  SECTION 3: Ahli Waris ─
  Widget _buildHeirCard(MemberModel m) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.family_restroom_rounded, color: AppColors.adminNavy, size: 20),
          SizedBox(width: 8),
          Text('Data Ahli Waris Terdaftar',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
        ]),
        const Divider(height: 20, color: AppColors.cardBorder),
        LayoutBuilder(
          builder: (context, constraints) {
            return _buildResponsiveGrid(
              constraints: constraints,
              items: [
                _infoTile('Nama Ahli Waris', m.heirName, Icons.person_outline),
                _infoTile('Hubungan Keluarga', m.heirRelationship, Icons.escalator_warning_outlined),
                _infoTile('Tempat Lahir', m.heirPlaceOfBirth, Icons.location_city_outlined),
                _infoTile('Tgl Lahir', m.heirDateOfBirth, Icons.cake_outlined),
              ],
              addressItem: _infoTileFull('Alamat Ahli Waris', m.heirAddress, Icons.home_outlined),
            );
          },
        ),
      ]),
    );
  }

  //  SECTION 4: Transaksi 
  Widget _buildTrxList() {
    final filtered = _transactions.where((t) {
      final String bookType = (t['book_type'] ?? '').toString().toUpperCase();
      final String category = (t['category'] ?? t['title'] ?? '').toString().toLowerCase();

      final isBlueBook = bookType == 'BUKU_BIRU' ||
                          category.contains('pokok') ||
                          category.contains('wajib') ||
                          category.contains('sukarela') ||
                          category.contains('sp') ||
                          category.contains('sw') ||
                          category.contains('ss');

      final isWhiteBook = bookType == 'BUKU_PUTIH' ||
                          category.contains('harian') ||
                          category.contains('putih') ||
                          category.contains('sh');

      if (_selectedBookTab == 'biru') {
        return isBlueBook && !category.contains('harian') && !category.contains('putih') && !category.contains('sh');
      } else {
        return isWhiteBook && !isBlueBook;
      }
    }).toList();

    if (filtered.isEmpty) {
      return _card(
        child: const Column(children: [
          Icon(Icons.receipt_long_rounded, size: 36, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text('Belum Ada Riwayat Transaksi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
        ]),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final t = filtered[i];

        final rawReceipt = t['receipt_number']?.toString().trim() ?? '';
        final typePrefix = (t['type'] == 'deposit' || t['type'] == 'in' || t['type'] == 'kas_masuk') ? 'KM' : 'KK';
        final displayNoBukti = '$typePrefix-$rawReceipt';
        final isWithdrawal = typePrefix == 'KK';

        final category = (t['category'] ?? t['title'] ?? (isWithdrawal ? 'Penarikan' : 'Setoran')).toString();
        final rawDate  = (t['transaction_date'] ?? t['date'] ?? t['tanggal'] ?? t['created_at'] ?? '').toString();
        String date = rawDate;
        try {
          final parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
          date = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(parsedDate);
        } catch (_) {}

        final num amt  = (t['amount'] is num) ? t['amount'] as num : int.tryParse(t['amount']?.toString() ?? '0') ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isWithdrawal ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
              child: Icon(
                isWithdrawal ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: isWithdrawal ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                size: 20,
              ),
            ),
            title: Text(category,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
            subtitle: Text('$displayNoBukti • $date',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            trailing: Text(
              isWithdrawal ? '- ${_rp(amt)}' : '+ ${_rp(amt)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isWithdrawal ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              ),
            ),
          ),
        );
      },
    );
  }

  //  UTILITIES─
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: AppColors.primary),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ])),
    ]);
  }

  Widget _infoTileFull(String label, String value, IconData icon) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: AppColors.primary),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ])),
    ]);
  }



  Widget _buildResponsiveGrid({
    required BoxConstraints constraints,
    required List<Widget> items,
    required Widget addressItem,
  }) {
    final double width = constraints.maxWidth;
    int cols = 2;
    if (width > 1024) {
      cols = 5;
    } else if (width >= 600) {
      cols = 3;
    }

    final double spacing = 16.0;
    final int spacingCount = cols - 1;
    final double totalSpacing = spacing * spacingCount;
    final double itemWidth = (width - totalSpacing) / cols;

    List<Widget> gridItems = [];
    for (var item in items) {
      gridItems.add(
        SizedBox(
          width: itemWidth > 0 ? itemWidth : 120,
          child: item,
        ),
      );
    }

    // Special handling for address: span 2 cols on tablet/desktop, or full width on mobile
    final double addressWidth = (cols >= 3)
        ? (itemWidth * 2 + spacing)
        : width;

    gridItems.add(
      SizedBox(
        width: addressWidth > 0 ? addressWidth : double.infinity,
        child: addressItem,
      ),
    );

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: gridItems,
    );
  }
}
