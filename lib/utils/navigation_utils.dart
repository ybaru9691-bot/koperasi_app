import 'package:flutter/material.dart';

/// Helper Utilitas Navigasi Aman untuk Mencegah Issue 'Navbar Freeze / Overlay Barrier Stuck'
class NavigationUtils {
  /// Menutup secara aman semua Overlay aktif (Drawer, Dialog, BottomSheet)
  static void safeCloseOverlays(BuildContext context) {
    try {
      // 1. Cek jika Drawer Scaffold sedang terbuka
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null && scaffold.isDrawerOpen) {
        Navigator.of(context).pop();
      }
    } catch (_) {}

    try {
      // 2. Cek dan pop modal barrier jika Navigator bisa di-pop
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (_) {}
  }

  /// Menutup Pop-up/Dialog/BottomSheet saat tombol Batal/Simpan/Tutup diklik
  static void safePop(BuildContext context) {
    try {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint("Info SafePop: $e");
    }
  }

  /// Pindah ke halaman baru setelah memastikan seluruh modal/drawer tertutup
  static Future<T?> safeNavigateTo<T>(
    BuildContext context,
    Widget targetScreen,
  ) async {
    safeCloseOverlays(context);
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  /// Widget Builder AppBar Leading Icon yang Aman untuk Admin & Anggota
  static Widget buildSafeLeadingIcon({
    required BuildContext btnContext,
    VoidCallback? onOpenDrawer,
  }) {
    final bool canPop = Navigator.canPop(btnContext);

    if (canPop) {
      return IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        tooltip: 'Kembali',
        onPressed: () => safePop(btnContext),
      );
    }

    return IconButton(
      icon: const Icon(Icons.menu_rounded, color: Colors.white),
      tooltip: 'Menu Utama',
      onPressed: () {
        if (onOpenDrawer != null) {
          onOpenDrawer();
        } else {
          try {
            Scaffold.of(btnContext).openDrawer();
          } catch (_) {}
        }
      },
    );
  }
}
