import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../screens/admin/admin_transaksi_screen.dart';
import '../services/auth_service.dart';
import '../utils/currency_input_formatter.dart';

class EditTransactionDialog extends StatefulWidget {
  final TransactionItem transaction;

  const EditTransactionDialog({
    super.key,
    required this.transaction,
  });

  @override
  State<EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<EditTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  String? _selectedPos;
  late DateTime _selectedDate;
  bool _isLoading = false;
  late bool _isKasMasuk;
  late List<String> _posOptions;

  // Daftar POS Pemasukan (KM)
  static const List<String> _kmPosList = [
    'Simpanan Pokok (SP)',
    'Simpanan Wajib (SW)',
    'Simpanan Sukarela (SS)',
    'Simpanan Harian (SH)',
    'Simpanan Diakonia',
    'Angsuran Pokok',
    'Jasa Pinjaman',
    'Provisi',
    'Up. Pangkal',
    'Dana Duka / Sosial',
    'Asuransi Investasi',
    'Finalty Tabungan',
    'Pendapatan Lain-lain',
    'Koreksi / Penyesuaian Kas Masuk',
    'Lain-lain',
  ];

  // Daftar POS Pengeluaran (KK)
  static const List<String> _kkPosList = [
    'Pencairan Pinjaman (Piutang)',
    'Tarik Simpanan Wajib (SW)',
    'Tarik Simpanan Sukarela (SS)',
    'Tarik Simpanan Pokok (SP)',
    'Tarik Tabungan Harian (SH)',
    'Beban / Biaya Operasional',
    'Dana Duka / Sosial',
    'Inventaris',
    'Bank Keluar',
    'Koreksi / Penyesuaian Kas Keluar',
    'Lain-lain',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.transaction;

    // 1. Deteksi tipe transaksi saat modal dibuka
    final typeStr = item.type.toLowerCase();
    _isKasMasuk = item.type == 'KM' ||
        item.type == 'kas_masuk' ||
        typeStr == 'deposit' ||
        typeStr.contains('km') ||
        typeStr.contains('in') ||
        typeStr.contains('masuk');

    // 2. Tentukan daftar POS berdasarkan tipe transaksi
    _posOptions = List<String>.from(_isKasMasuk ? _kmPosList : _kkPosList);

    // Cocokkan nilai awal deskripsi transaksi
    final currentDesc = item.description.trim();
    if (currentDesc.isNotEmpty) {
      if (_posOptions.contains(currentDesc)) {
        _selectedPos = currentDesc;
      } else {
        // Cari kemungkinan kecocokan parsial atau tambahkan ke list opsi
        final matched = _posOptions.firstWhere(
          (pos) => pos.toLowerCase() == currentDesc.toLowerCase() ||
              pos.toLowerCase().contains(currentDesc.toLowerCase()) ||
              currentDesc.toLowerCase().contains(pos.toLowerCase()),
          orElse: () => '',
        );
        if (matched.isNotEmpty) {
          _selectedPos = matched;
        } else {
          _posOptions.add(currentDesc);
          _selectedPos = currentDesc;
        }
      }
    } else {
      _selectedPos = _posOptions.first;
    }

    // Inisialisasi controller nominal bersih dari item.amount
    _amountCtrl = TextEditingController(text: item.amount.toStringAsFixed(0));

    // Parse tanggal transaksi awal menggunakan toLocal()
    _selectedDate = DateTime.now();
    try {
      final rawDate = item.date.trim();
      if (rawDate.isNotEmpty) {
        if (rawDate.contains('T')) {
          _selectedDate = DateTime.parse(rawDate).toLocal();
        } else {
          final dateOnly = rawDate.split(' ')[0];
          final parts = dateOnly.split('-');
          if (parts.length == 3) {
            _selectedDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } else {
            _selectedDate = DateTime.parse('${dateOnly}T00:00:00').toLocal();
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Widget _infoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 1),
        Text(
          value.isNotEmpty ? value : '-',
          style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final rawAmountStr = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final newAmount = double.tryParse(rawAmountStr) ?? widget.transaction.amount;
    final newDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final newDesc = _selectedPos?.trim() ?? widget.transaction.description;

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/transactions/${widget.transaction.id}');
      
      final response = await http.put(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': newAmount,
          'description': newDesc,
          'pos_name': newDesc,
          'transaction_date': newDateStr,
        }),
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          (decoded['success'] == true || decoded['status'] == 'success')) {
        // Tampilkan notifikasi sukses
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Transaksi berhasil diperbarui dan tersinkronisasi.'),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
          ),
        );

        // Tutup dialog dan kirim data pembaruan
        Navigator.of(context).pop({
          'success': true,
          'newDate': _selectedDate,
        });
      } else {
        setState(() => _isLoading = false);
        final errorMsg = decoded['message']?.toString() ?? 'Gagal memperbarui transaksi di server.';
        _showErrorSnackBar(errorMsg);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('Terjadi kesalahan sistem: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.transaction;
    final headerColor = _isKasMasuk ? const Color(0xFF1D4ED8) : const Color(0xFFC2410C);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: headerColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit / Koreksi Transaksi',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    item.receiptNumber,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isKasMasuk ? '● KAS MASUK (KM)' : '● KAS KELUAR (KK)',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Info Anggota (Read-only)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 6,
                    children: [
                      _infoField('Anggota', item.memberName),
                      _infoField('NBA', item.memberNumber),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tanggal Transaksi
                const Text(
                  'Tanggal Transaksi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _isLoading
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        Icon(Icons.edit, size: 14, color: Colors.grey[500]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Dropdown Dinamis POS Transaksi (KM vs KK)
                Text(
                  _isKasMasuk ? 'Pos Kas Masuk (KM)' : 'Pos Kas Keluar (KK)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPos,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    prefixIcon: const Icon(Icons.category_outlined, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _posOptions.map((pos) {
                    return DropdownMenuItem<String>(
                      value: pos,
                      child: Text(
                        pos,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _isLoading
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedPos = val);
                          }
                        },
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Pos transaksi wajib dipilih' : null,
                ),
                const SizedBox(height: 14),

                // Nominal Transaksi
                const Text(
                  'Nominal (Rp)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _amountCtrl,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) {
                    final raw = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                    final n = double.tryParse(raw);
                    if (n == null || n <= 0) return 'Masukkan nominal yang valid (> 0)';
                    return null;
                  },
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saldo anggota, Buku Besar, dan Jurnal Tabelaris akan tersinkronisasi otomatis.',
                          style: TextStyle(fontSize: 11, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleSave,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded, size: 16),
          label: Text(_isLoading ? 'Menyimpan...' : 'Simpan Perubahan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: headerColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
