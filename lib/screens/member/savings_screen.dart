import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../../constants/app_constants.dart';
import '../../controllers/savings_controller.dart';
import '../../models/savings_model.dart';
import '../../services/connectivity_service.dart';
import '../../utils/whatsapp_helper.dart';
import '../../widgets/common_state_widgets.dart';

// SAVINGS SCREEN WIDGET (UI LAYER)
/// SavingsScreen menampilkan ringkasan saldo simpanan,
/// rincian jenis simpanan, dan riwayat mutasi dengan pengisolasian logika di SavingsController.
class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  late final SavingsController _controller;
  StreamSubscription<bool>? _reconnectSubscription;
  bool _isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = SavingsController();
    _controller.fetchSimpananData();

    // Auto-refetch data secara otomatis ketika internet terhubung kembali
    _reconnectSubscription =
        ConnectivityService().onReconnected.listen((_) {
      if (mounted) {
        _controller.fetchSimpananData();
      }
    });
  }

  @override
  void dispose() {
    _reconnectSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(),
          body: RefreshIndicator(
            onRefresh: _controller.fetchSimpananData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSummaryCard(),
                  const SizedBox(height: 16),
                  _buildBookToggleButton(),
                  const SizedBox(height: 16),
                  if (_controller.isLoading)
                    _buildSkeletonLoading()
                  else if (_controller.hasError)
                    _buildErrorState()
                  else if (_controller.selectedBook == 'Buku Biru' && !_controller.hasBukuBiru)
                    _buildInactiveBookState(
                      title: 'Buku Biru (Saham Keanggotaan) Belum Aktif',
                      subtitle: 'Anda belum terdaftar di Buku Biru. Hubungi Admin untuk pembukaan Saham Keanggotaan.',
                      buttonLabel: null,
                      onButtonPressed: null,
                    )
                  else if (_controller.selectedBook == 'Buku Putih' && (!_controller.hasBukuPutih || _controller.dailySavings == 0))
                    _buildInactiveBookState(
                      title: 'Buku Putih (Tabungan Harian) Belum Aktif',
                      subtitle: 'Anda belum mendaftar rekening Buku Putih. Buka rekening Tabungan Harian untuk menikmati bunga 0.6% setiap bulan.',
                      buttonLabel: 'Ajukan Pembukaan Buku Putih',
                      onButtonPressed: () => WhatsAppHelper.showContactBottomSheet(
                        context,
                        customHeaderTitle: 'Pengajuan Buku Putih',
                      ),
                    )
                  else ...[
                    _buildSavingsCardsSection(),
                    const SizedBox(height: 28),
                    _buildMutationsSection(),
                  ],
                ],     
              ),
            ),
          ),
        );
      },
    );
  }


  // MODULAR UI BUILDERS
  /// AppBar khusus Halaman Simpanan
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        tooltip: 'Kembali',
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            const TabSwitchNotification(0).dispatch(context);
          }
        },
      ),
      title: const Text(
        'Simpanan Koperasi',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Header Card Summary Total Saldo
  Widget _buildHeaderSummaryCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (!_controller.hasBukuBiru || _controller.selectedBook == 'Buku Putih')
                          ? 'TOTAL SALDO TABUNGAN HARIAN'
                          : 'TOTAL SAHAM',
                      style: const TextStyle(
                        color: Color(0xE6FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _toggleBalanceVisibility,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      _isBalanceVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              _isBalanceVisible
                  ? 'Rp ${_formatCurrency((!_controller.hasBukuBiru || _controller.selectedBook == 'Buku Putih') ? _controller.dailySavings : _controller.totalSaham)}'
                  : 'Rp ••••••••••',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _controller.selectedBook == 'Buku Putih'
                        ? 'Nomor Anggota (${_controller.memberNumber}) • No. Buku Putih: ${_controller.bukuPutihNo ?? '-'}'
                        : 'Nomor Anggota (${_controller.memberNumber})',
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: AppColors.gold,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Status: Terverifikasi',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Bagian Daftar Jenis Simpanan
  Widget _buildSavingsCardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Daftar Jenis Simpanan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _controller.displaySavingsTypesList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _controller.displaySavingsTypesList[index];
              return _SavingsTypeCard(
                item: item,
                isBalanceVisible: _isBalanceVisible,
                formatCurrency: _formatCurrency,
              );
            },
          ),
        ),
      ],
    );
  }


  /// Bagian Riwayat Mutasi Simpanan
  Widget _buildMutationsSection() {
    final listData = _controller.filteredMutations;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat Mutasi',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: _controller.fetchSimpananData,
                child: const Text(
                  'Segarkan',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: ['Semua', 'Setor', 'Tarik', 'Bunga'].map((filter) {
                final isSelected = _controller.selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _controller.setFilter(filter);
                      }
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: listData.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: listData.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 64),
                    itemBuilder: (context, index) {
                      final mutation = listData[index];
                      return _MutationTile(
                        mutation: mutation,
                        formatCurrency: _formatCurrency,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }


  // SKELETON LOADING, EMPTY & ERROR STATES


  Widget _buildSkeletonLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonBox(width: 160, height: 18),
          const SizedBox(height: 14),
          ...List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildSkeletonBox(
                width: double.infinity,
                height: 90,
                radius: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSkeletonBox(width: 140, height: 18),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      _buildSkeletonBox(width: 40, height: 40, radius: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSkeletonBox(width: 140, height: 14),
                            const SizedBox(height: 6),
                            _buildSkeletonBox(width: 90, height: 10),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildSkeletonBox(width: 70, height: 14),
                          const SizedBox(height: 6),
                          _buildSkeletonBox(width: 50, height: 12),
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

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double radius = 8,
  }) {
    return ShimmerLoadingWidget(
      width: width,
      height: height,
      borderRadius: radius,
    );
  }

  Widget _buildEmptyState() {
    if (_controller.selectedFilter == 'Bunga') {
      return EmptyStateWidget(
        title: 'Belum ada riwayat penerimaan bunga simpanan',
        description:
            'Bunga tabungan harian/buku putih (jika ada) biasanya dibagikan setiap tanggal 20.',
        icon: Icons.card_giftcard_rounded,
        actionLabel: 'Muat Ulang Data',
        onActionPressed: _controller.fetchSimpananData,
      );
    }
    return EmptyStateWidget(
      title: 'Belum Ada Riwayat Simpanan',
      description:
          'Transaksi atau mutasi simpanan Anda akan muncul di sini setelah ada setoran/penarikan.',
      icon: Icons.inbox_outlined,
      actionLabel: 'Muat Ulang Data',
      onActionPressed: _controller.fetchSimpananData,
    );
  }

  Widget _buildInactiveBookState({
    required String title,
    required String subtitle,
    required String? buttonLabel,
    required VoidCallback? onButtonPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_clock_outlined,
                size: 32,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            if (buttonLabel != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFEE2E2)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.statusRejected,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal Memuat Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _controller.errorMessage ??
                  'Terjadi kesalahan saat terhubung ke server.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _controller.fetchSimpananData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
  String _formatCurrency(double? amount) {
    final double safeAmount = amount ?? 0.0;
    final String priceString = safeAmount.toStringAsFixed(0);
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceString.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  Widget _buildBookToggleButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildBookTabItem(
                label: 'Buku Biru (Saham)',
                isSelected: _controller.selectedBook == 'Buku Biru',
                activeColor: AppColors.primary,
                onTap: () => _controller.selectBook('Buku Biru'),
              ),
            ),
            Expanded(
              child: _buildBookTabItem(
                label: 'Buku Putih (Harian)',
                isSelected: _controller.selectedBook == 'Buku Putih',
                activeColor: const Color(0xFF1E88E5),
                onTap: () => _controller.selectBook('Buku Putih'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookTabItem({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// REUSABLE SUB-WIDGETS

class _SavingsTypeCard extends StatelessWidget {
  final SavingsDetailModel item;
  final bool isBalanceVisible;
  final String Function(double) formatCurrency;

  const _SavingsTypeCard({
    required this.item,
    required this.isBalanceVisible,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.accountNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Saldo',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBalanceVisible
                        ? 'Rp ${formatCurrency(item.balance)}'
                        : 'Rp •••••••',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MutationTile extends StatelessWidget {
  final SavingsMutationModel mutation;
  final String Function(double) formatCurrency;

  const _MutationTile({required this.mutation, required this.formatCurrency});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    Color iconBgColor;

    switch (mutation.type) {
      case MutationType.setor:
        icon = Icons.south_west_rounded;
        iconColor = AppColors.statusApproved;
        iconBgColor = AppColors.statusApproved.withValues(alpha: 0.1);
        break;
      case MutationType.tarik:
        icon = Icons.north_east_rounded;
        iconColor = AppColors.statusRejected;
        iconBgColor = AppColors.statusRejected.withValues(alpha: 0.1);
        break;
      case MutationType.bunga:
        icon = Icons.card_giftcard_rounded;
        iconColor = const Color(0xFF8E24AA);
        iconBgColor = const Color(0xFF8E24AA).withValues(alpha: 0.1);
        break;
    }

    Color statusBgColor;
    Color statusTextColor;
    if (mutation.status == 'Berhasil') {
      statusBgColor = AppColors.statusApproved.withValues(alpha: 0.1);
      statusTextColor = AppColors.statusApproved;
    } else if (mutation.status == 'Pending') {
      statusBgColor = AppColors.statusPending.withValues(alpha: 0.12);
      statusTextColor = const Color(0xFFD97706);
    } else {
      statusBgColor = AppColors.statusRejected.withValues(alpha: 0.1);
      statusTextColor = AppColors.statusRejected;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 6.0,
      ),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        mutation.title ?? 'Transaksi Simpanan',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${mutation.proofNumber} • ${mutation.date}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${(mutation.type == MutationType.bunga || mutation.isCredit) ? "+" : "-"} Rp ${formatCurrency(mutation.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: (mutation.type == MutationType.bunga || mutation.isCredit)
                  ? const Color(0xFF10B981) // Green
                  : AppColors.statusRejected,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              mutation.status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
