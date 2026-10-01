import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_input_formatter.dart';

/// Screen "Kelola Kas Keluar (KK)" Khusus Admin Koperasi CUM Pelita
class AdminKasKeluarScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const AdminKasKeluarScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<AdminKasKeluarScreen> createState() => _AdminKasKeluarScreenState();
}

class _AdminKasKeluarScreenState extends State<AdminKasKeluarScreen> {
  final num _totalPemasukan = 1850000000;
  num _totalPengeluaran = 425000000;
  int _kkCounter = 1045;

  num get _kasKoperasi => _totalPemasukan - _totalPengeluaran;

  // Data Rekap Operasional Asli Nota Kas Keluar (KK) Koperasi CUM Pelita
  final List<TransactionModel> _kkTransactions = [
    const TransactionModel(
      id: '1',
      kmCode: 'KK 1042',
      memberName: 'Maria Sitindaon',
      memberNo: '2564',
      title: 'Pencairan Pinjaman Konsumtif Anggota',
      category: 'Pencairan Pinjaman Anggota',
      date: '27 Juli 2026, 15:30',
      amount: 15000000,
      isIncome: false,
      status: 'Lunas',
    ),
    const TransactionModel(
      id: '2',
      kmCode: 'KK 1043',
      memberName: 'Reslina Nainggolan',
      memberNo: '2562',
      title: 'Penarikan Simpanan Sukarela (SS)',
      category: 'Penarikan Simpanan Sukarela (SS)',
      date: '26 Juli 2026, 11:00',
      amount: 2500000,
      isIncome: false,
      status: 'Lunas',
    ),
    const TransactionModel(
      id: '3',
      kmCode: 'KK 1044',
      memberName: 'Vendor PLN & Telkom Duri',
      memberNo: 'VENDOR-01',
      title: 'Beban Operasional Listrik, Internet & ATK Kantor',
      category: 'Beban Operasional (Listrik, ATK, Gaji)',
      date: '25 Juli 2026, 14:15',
      amount: 1850000,
      isIncome: false,
      status: 'Lunas',
    ),
  ];

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  void _showInputNotaKkDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    String selectedRecipient = 'Maria Sitindaon (No. 2564)';
    String selectedCategory = 'Pencairan Pinjaman Anggota';

    final List<Map<String, String>> recipientOptions = const [
      {'name': 'Maria Sitindaon', 'no': '2564', 'label': 'Maria Sitindaon (No. 2564)'},
      {'name': 'Reslina Nainggolan', 'no': '2562', 'label': 'Reslina Nainggolan (No. 2562)'},
      {'name': 'Farida Suzana', 'no': '2563', 'label': 'Farida Suzana (No. 2563)'},
      {'name': 'Budi Santoso', 'no': '2571', 'label': 'Budi Santoso (No. 2571)'},
      {'name': 'Vendor Operasional / PLN Duri', 'no': 'VENDOR', 'label': 'Bebas / Vendor Operasional Koperasi'},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.output_rounded, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Input Nota KK $_kkCounter',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auto-generated KK Voucher Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'No. Nota Terbit: KK $_kkCounter',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Dropdown Penerima / Anggota
                  DropdownButtonFormField<String>(
                    initialValue: selectedRecipient,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Anggota / Penerima Kas',
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.danger),
                      border: OutlineInputBorder(),
                    ),
                    items: recipientOptions
                        .map((r) => DropdownMenuItem(
                              value: r['label'],
                              child: Text(r['label']!, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) selectedRecipient = val;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Dropdown Kategori Transaksi KK
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Kas Keluar',
                      prefixIcon: Icon(Icons.category_outlined, color: AppColors.danger),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Pencairan Pinjaman Anggota',
                        child: Text('Pencairan Pinjaman Anggota'),
                      ),
                      DropdownMenuItem(
                        value: 'Penarikan Simpanan Sukarela (SS)',
                        child: Text('Penarikan Simpanan Sukarela (SS)'),
                      ),
                      DropdownMenuItem(
                        value: 'Pengembalian Simpanan Pokok/Wajib',
                        child: Text('Pengembalian Simpanan Pokok/Wajib'),
                      ),
                      DropdownMenuItem(
                        value: 'Beban Operasional (Listrik, ATK, Gaji)',
                        child: Text('Beban Operasional (Listrik, ATK, Gaji)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) selectedCategory = val;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Input Nominal (Rp)
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Nominal beban wajib diisi dan harus lebih dari 0.';
                      final raw = val.replaceAll(RegExp(r'[^0-9]'), '');
                      final n = double.tryParse(raw) ?? 0.0;
                      if (n <= 0) return 'Nominal beban wajib diisi dan harus lebih dari 0.';
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Nominal Kas Keluar (Rp)',
                      prefixText: 'Rp ',
                      prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      hintText: '0',
                      prefixIcon: Icon(Icons.payments_outlined, color: AppColors.danger),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Input Keterangan
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan / Catatan Pencairan',
                      prefixIcon: Icon(Icons.notes_outlined, color: AppColors.danger),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final rawValue = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                  final num inputAmount = double.tryParse(rawValue) ?? 0;
                  if (inputAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nominal beban wajib diisi dan harus lebih dari 0.')),
                    );
                    return;
                  }
                  final selectedMap = recipientOptions.firstWhere((r) => r['label'] == selectedRecipient);
                  final String generatedKkCode = 'KK $_kkCounter';
                  final String notes = notesController.text.trim().isNotEmpty
                      ? notesController.text.trim()
                      : 'Pencairan $selectedCategory';

                  final newTransaction = TransactionModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    kmCode: generatedKkCode,
                    memberName: selectedMap['name']!,
                    memberNo: selectedMap['no']!,
                    title: notes,
                    category: selectedCategory,
                    date: '28 Juli 2026, ${TimeOfDay.now().format(context)}',
                    amount: inputAmount.toDouble(),
                    isIncome: false,
                    status: 'Lunas',
                  );

                  setState(() {
                    _kkCounter++;
                    _totalPengeluaran += inputAmount;
                    _kkTransactions.insert(0, newTransaction);
                  });

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Nota $generatedKkCode (${_formatRupiah(inputAmount)}) BERHASIL DITERBITKAN!',
                      ),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Simpan Nota KK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.danger,
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
          'Kelola Keuangan & Kas Keluar (KK)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            tooltip: 'Cetak Rekap Kas Keluar (KK)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mencetak Rekapitulasi Buku Kas Keluar (KK)...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Saldo Kas Utama CUM Pelita
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.danger, Color(0xFF7F1D1D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo Kas Utama (Kas Masuk - Kas Keluar)',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatRupiah(_kasKoperasi),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card Ringkasan Pemasukan & Pengeluaran (Visual Rose/Red Theme)
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total Pemasukan Kas',
                    value: _formatRupiah(_totalPemasukan),
                    icon: Icons.south_west_rounded,
                    iconColor: AppColors.success,
                    bgColor: AppColors.successBg,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total Pencairan (KK)',
                    value: _formatRupiah(_totalPengeluaran),
                    icon: Icons.north_east_rounded,
                    iconColor: AppColors.danger,
                    bgColor: AppColors.dangerBg,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Label Title Riwayat Nota Kas Keluar (KK)
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buku Nota Kas Keluar (KK) Terbaru',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminNavy,
                  ),
                ),
                Text(
                  'Lihat Rekap',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // List Log Keuangan Nota KK
            _buildFinancialLogList(),
          ],
        ),
      ),

      // Floating Action Button (+ Input Nota KK -> Triggers Modal Form)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInputNotaKkDialog,
        backgroundColor: AppColors.danger,
        elevation: 4,
        icon: const Icon(Icons.output_rounded, color: Colors.white),
        label: const Text(
          'Input Nota KK',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialLogList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _kkTransactions.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: AppColors.cardBorder),
        itemBuilder: (context, index) {
          final item = _kkTransactions[index];

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.dangerBg,
              child: const Icon(
                Icons.output_rounded,
                color: AppColors.danger,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.kmCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.memberName,
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  '${item.date} • Penerima/Reg: ${item.memberNo}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '- ${_formatRupiah(item.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
