import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../kelola_anggota_screen.dart';

// WIDGET HEADER / APPBAR KHUSUS ADMIN KOPERASI (CLEAN ARCHITECTURE THEMED)
class AdminHeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final String adminName;
  final VoidCallback? onOpenDrawer;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const AdminHeaderWidget({
    super.key,
    required this.adminName,
    this.onOpenDrawer,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.adminNavy,
      elevation: 2,
      leading: Builder(
        builder: (btnContext) {
          if (Navigator.canPop(btnContext)) {
            return IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              tooltip: 'Kembali',
              onPressed: () {
                if (Navigator.canPop(btnContext)) {
                  Navigator.pop(btnContext);
                }
              },
            );
          }
          return IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            tooltip: 'Menu Admin',
            onPressed: () {
              if (onOpenDrawer != null) {
                onOpenDrawer!();
              } else {
                try {
                  Scaffold.of(btnContext).openDrawer();
                } catch (_) {}
              }
            },
          );
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Dashboard Admin CUM Pelita",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textInverse,
            ),
          ),
          Text(
            "Halo, ${adminName.trim().isNotEmpty ? adminName.trim() : 'Admin Koperasi'}",
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.people_alt_rounded, color: AppColors.adminAccent),
          tooltip: "Kelola Anggota",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const KelolaAnggotaScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textInverse),
          onPressed: onRefresh,
          tooltip: "Refresh Data Admin",
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppColors.dangerAccent),
          onPressed: onLogout,
          tooltip: "Logout",
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
