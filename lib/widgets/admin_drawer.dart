import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/admin/tambah_anggota_screen.dart';
import '../services/auth_service.dart';
import '../utils/navigation_utils.dart';

/// Widget Side Navigation Drawer terstruktur khusus Admin Koperasi CUM Pelita
class AdminDrawerWidget extends StatelessWidget {
  final int currentIndex;
  final Function(int index) onSelectMenu;

  const AdminDrawerWidget({
    super.key,
    required this.currentIndex,
    required this.onSelectMenu,
  });

  @override
  Widget build(BuildContext context) {
    // Cek grup mana yang memiliki menu aktif untuk auto-expand ExpansionTile
    final bool isKeanggotaanActive = currentIndex == 1;
    final bool isKeuanganActive = currentIndex == 2 || currentIndex == 7 || currentIndex == 9 || currentIndex == 10 || currentIndex == 11 || currentIndex == 12;
    final bool isOperasionalActive = currentIndex == 4 || currentIndex == 5 || currentIndex == 8;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          // Header Drawer dengan Branding Koperasi CUM Pelita
          _buildDrawerHeader(context),

          // Menu Berstruktur (Expanded Scrollable List)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              children: [
                // 1. BERANDA ADMIN (Single Menu)
                _buildDrawerTile(
                  context: context,
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  title: 'Beranda Admin',
                ),

                const SizedBox(height: 4),

                // 2. KEANGGOTAAN (ExpansionTile / Dropdown Group)
                _buildExpansionGroupTile(
                  context: context,
                  icon: Icons.people_alt_rounded,
                  title: 'KEANGGOTAAN',
                  isGroupActive: isKeanggotaanActive,
                  children: [
                    _buildSubDrawerTile(
                      context: context,
                      index: 1,
                      icon: Icons.badge_outlined,
                      title: 'Data Anggota',
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 28, right: 12),
                      leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 18),
                      title: const Text(
                        'Pendaftaran Anggota Baru',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Tutup drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TambahAnggotaScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // 3. KEUANGAN & KAS (ExpansionTile / Dropdown Group)
                _buildExpansionGroupTile(
                  context: context,
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'KEUANGAN & KAS',
                  isGroupActive: isKeuanganActive,
                  children: [
                    _buildSubDrawerTile(
                      context: context,
                      index: 2,
                      icon: Icons.point_of_sale_rounded,
                      title: 'Input Transaksi Harian (KM & KK)',
                    ),
                    _buildSubDrawerTile(
                      context: context,
                      index: 7,
                      icon: Icons.menu_book_rounded,
                      title: 'Buku Besar',
                    ),
                    _buildSubDrawerTile(
                      context: context,
                      index: 12,
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Saldo Awal Pembukuan',
                    ),
                    _buildSubDrawerTile(
                      context: context,
                      index: 9,
                      icon: Icons.view_column_rounded,
                      title: 'Neraca Lajur',
                    ),
                    _buildSubDrawerTile(
                      context: context,
                      index: 10,
                      icon: Icons.history_rounded,
                      title: 'Manajemen Transaksi',
                    ),
                    _buildSubDrawerTile(
                      context: context,
                      index: 11,
                      icon: Icons.table_view_outlined,
                      title: 'Jurnal Tabelaris',
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // 4. OPERASIONAL PINJAMAN (ExpansionTile / Dropdown Group)
                _buildExpansionGroupTile(
                  context: context,
                  icon: Icons.request_quote_rounded,
                  title: 'OPERASIONAL PINJAMAN',
                  isGroupActive: isOperasionalActive,
                  children: [
                    _buildSubDrawerTile(
                      context: context,
                      index: 5,
                      icon: Icons.rate_review_rounded,
                      title: 'Persetujuan Pinjaman',
                    ),
                    _buildSubDrawerTile(
                      context: context,
                      index: 8,
                      icon: Icons.credit_card_rounded,
                      title: 'Kartu Pinjaman & Angsuran',
                    ),
                    _buildSubDrawerTile(
                      context: context,
                      index: 4,
                      icon: Icons.history_edu_rounded,
                      title: 'Riwayat Transaksi Pinjaman',
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                const Divider(height: 16, color: AppColors.cardBorder),
                const SizedBox(height: 4),

                // 5. PROFIL ADMIN (Single Menu)
                _buildDrawerTile(
                  context: context,
                  index: 3,
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Profil Admin',
                ),

                const SizedBox(height: 4),

                // 6. LOGOUT (Single Menu / Red Accent)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.logout_rounded, color: AppColors.dangerAccent, size: 20),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dangerAccent,
                      ),
                    ),
                    onTap: () => _showLogoutConfirmDialog(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.adminNavy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.adminAccent, width: 2),
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
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KOPERASI CUM PELITA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'HKBP Dame Duri',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Admin Koperasi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'admin@koperasipelita.id',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper untuk merender item menu tunggal (Beranda, Profil)
  Widget _buildDrawerTile({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String title,
  }) {
    final bool isSelected = currentIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.adminNavy.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? AppColors.adminNavy : AppColors.textSecondary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppColors.adminNavy : AppColors.textPrimary,
          ),
        ),
        onTap: () => _safeCloseDrawerAndSelect(context, index),
      ),
    );
  }

  /// Helper untuk merender sub-menu di dalam ExpansionTile
  Widget _buildSubDrawerTile({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String title,
  }) {
    final bool isSelected = currentIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.adminNavy.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 28, right: 12),
        leading: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppColors.adminNavy : AppColors.textPrimary,
          ),
        ),
        onTap: () => _safeCloseDrawerAndSelect(context, index),
      ),
    );
  }

  void _safeCloseDrawerAndSelect(BuildContext context, int index) {
    NavigationUtils.safeCloseOverlays(context);
    onSelectMenu(index);
  }

  /// Helper untuk merender ExpansionTile (Dropdown/Accordion Group)
  Widget _buildExpansionGroupTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isGroupActive,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isGroupActive,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: EdgeInsets.zero,
        leading: Icon(
          icon,
          size: 20,
          color: isGroupActive ? AppColors.adminNavy : AppColors.textSecondary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isGroupActive ? AppColors.adminNavy : AppColors.textSecondary,
          ),
        ),
        children: children,
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.dangerAccent),
              SizedBox(width: 10),
              Text(
                'Logout Admin?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar (logout) dari akun Admin Koperasi?',
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationUtils.safePop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                NavigationUtils.safePop(dialogContext);
                await AuthService.handleLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Logout'),
            ),
          ],
        );
      },
    );
  }
}
