import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_constants.dart';
import '../../controllers/manual_deposit_controller.dart';
import '../../dummy/mock_data.dart';
import '../../models/manual_deposit_model.dart';
import '../../utils/currency_input_formatter.dart';
import '../../widgets/common_state_widgets.dart';



// SCREEN: HALAMAN PENGAJUAN SETORAN MANUAL (NO LOGIC IN UI)
// ManualDepositSubmissionScreen menampilkan daftar riwayat pengajuan setoran manual
//dan memfasilitasi pembuatan pengajuan setoran baru tanpa payment gateway.
class ManualDepositSubmissionScreen extends StatefulWidget {
  const ManualDepositSubmissionScreen({super.key});

  @override
  State<ManualDepositSubmissionScreen> createState() =>
      _ManualDepositSubmissionScreenState();
}

class _ManualDepositSubmissionScreenState
    extends State<ManualDepositSubmissionScreen> {
  final ManualDepositController _controller = ManualDepositController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _controller.fetchDeposits();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  // Menampilkan modal form pembuatan setoran manual baru
  void _showNewDepositFormModal(BuildContext context) {
    String selectedDepositType = MockData.savingsTypes.first;
    Map<String, String> selectedBankAccount = MockData.bankAccounts.first;
    final TextEditingController amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLarge),
        ),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(modalContext).viewInsets.bottom +
                    AppSizes.paddingLarge,
                top: AppSizes.paddingLarge,
                left: AppSizes.paddingLarge,
                right: AppSizes.paddingLarge,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Form Pengajuan Setoran Manual',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Transaksi disetorkan secara manual ke rekening Koperasi dan diverifikasi admin.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 18),

                  // Dropdown Jenis Simpanan
                  DropdownButtonFormField<String>(
                    initialValue: selectedDepositType,
                    decoration: InputDecoration(
                      labelText: 'Jenis Simpanan',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    items: MockData.savingsTypes
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedDepositType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Dropdown Rekening Tujuan Koperasi
                  DropdownButtonFormField<Map<String, String>>(
                    initialValue: selectedBankAccount,
                    decoration: InputDecoration(
                      labelText: 'Tujuan Transfer / Penyetoran',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    items: MockData.bankAccounts
                        .map(
                          (acc) => DropdownMenuItem(
                            value: acc,
                            child: Text(
                              '${acc['bank']} - ${acc['accountNumber']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedBankAccount = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // TextField Nominal
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Nominal Setoran (Rp)',
                      hintText: '0',
                      prefixText: 'Rp ',
                      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Info Box Verifikasi Manual
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingMedium),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Setelah mengirim pengajuan, harap simpan bukti transfer untuk dicocokkan oleh Admin Koperasi.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tombol Kirim Pengajuan
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final rawValue = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                        final double amount = double.tryParse(rawValue) ?? 0;

                        if (amount > 0) {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(modalContext);
                          final success = await _controller.submitDeposit(
                            depositType: selectedDepositType,
                            amount: amount,
                            paymentMethod:
                                selectedBankAccount['bank'] ?? 'Transfer',
                            bankName: selectedBankAccount['bank'] ?? 'BCA',
                            accountNumber:
                                selectedBankAccount['accountNumber'] ?? '-',
                          );

                          if (success) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Pengajuan setoran manual berhasil dikirim dan dalam status Menunggu Verifikasi!',
                                ),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Masukkan nominal setoran yang valid!',
                              ),
                              backgroundColor: AppColors.statusRejected,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Kirim Pengajuan Setoran',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Pengajuan Setoran Manual',
          style: AppTextStyles.appBarTitle,
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<ViewState>(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            tooltip: 'Simulasi UI State',
            onSelected: (state) => _controller.simulateState(state),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ViewState.success,
                child: Text('State: Success (Normal)'),
              ),
              const PopupMenuItem(
                value: ViewState.loading,
                child: Text('State: Loading'),
              ),
              const PopupMenuItem(
                value: ViewState.empty,
                child: Text('State: Empty (Kosong)'),
              ),
              const PopupMenuItem(
                value: ViewState.error,
                child: Text('State: Error (Gagal)'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBodyState(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewDepositFormModal(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Buat Setoran Baru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Menangani 3 Condition State Visual UI (Loading, Empty, Error, Success)
  Widget _buildBodyState() {
    switch (_controller.state) {
      case ViewState.loading:
        return const LoadingViewWidget(
          message: 'Memproses data setoran manual...',
        );

      case ViewState.empty:
        return EmptyStateWidget(
          title: 'Belum Ada Pengajuan Setoran',
          description:
              'Anda belum memiliki riwayat pengajuan setoran manual. Buat pengajuan setoran baru sekarang.',
          icon: Icons.assignment_outlined,
          actionLabel: 'Buat Setoran Baru',
          onActionPressed: () => _showNewDepositFormModal(context),
        );

      case ViewState.error:
        return ErrorStateWidget(
          errorMessage: _controller.errorMessage,
          onRetry: () => _controller.fetchDeposits(),
        );

      case ViewState.initial:
      case ViewState.success:
        return _buildDepositList();
    }
  }

  /// Membangun Daftar Riwayat Card Setoran Manual
  Widget _buildDepositList() {
    final deposits = _controller.deposits;

    return RefreshIndicator(
      onRefresh: () => _controller.fetchDeposits(),
      color: AppColors.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.paddingMedium,
          AppSizes.paddingMedium,
          AppSizes.paddingMedium,
          80.0,
        ),
        itemCount: deposits.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final deposit = deposits[index];
          return _DepositItemCard(deposit: deposit);
        },
      ),
    );
  }
}

// REUSABLE SUB-WIDGET: CARD ITEM SETORAN MANUAL
class _DepositItemCard extends StatelessWidget {
  final ManualDepositModel deposit;

  const _DepositItemCard({required this.deposit});

  Color _getStatusColor(DepositStatus status) {
    switch (status) {
      case DepositStatus.pending:
        return AppColors.statusPending;
      case DepositStatus.approved:
        return AppColors.statusApproved;
      case DepositStatus.rejected:
        return AppColors.statusRejected;
    }
  }

  IconData _getStatusIcon(DepositStatus status) {
    switch (status) {
      case DepositStatus.pending:
        return Icons.pending_actions_rounded;
      case DepositStatus.approved:
        return Icons.check_circle_outline_rounded;
      case DepositStatus.rejected:
        return Icons.cancel_outlined;
    }
  }

  String _formatCurrency(double? amount) {
    final double safeAmount = amount ?? 0.0;
    final String priceString = safeAmount.toStringAsFixed(0);
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceString.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(deposit.status);
    final statusIcon = _getStatusIcon(deposit.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: ID Transaksi & Badge Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                deposit.id,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      deposit.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Row 2: Jenis Simpanan & Nominal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deposit.depositType, style: AppTextStyles.subtitle),
                  const SizedBox(height: 2),
                  Text(
                    '${deposit.paymentMethod} (${deposit.accountNumber})',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
              Text(
                '+ Rp ${_formatCurrency(deposit.amount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          // Row 3: Admin Note jika ada
          if (deposit.adminNote != null && deposit.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.paddingSmall),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              ),
              child: Text(
                'Catatan Admin: ${deposit.adminNote}',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Row 4: Waktu Pengajuan
          Align(
            alignment: Alignment.centerRight,
            child: Text(deposit.createdAt, style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }
}
