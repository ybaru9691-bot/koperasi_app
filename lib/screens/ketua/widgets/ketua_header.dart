import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

// WIDGET HEADER / APPBAR KHUSUS KETUA KOPERASI WITH NOTIFICATIONS & REFRESH
class KetuaHeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final bool isDesktop;
  final bool isSidebarOpen;
  final bool isRefreshing;
  final int unreadNotificationsCount;
  final VoidCallback onToggleSidebar;
  final VoidCallback onRefresh;
  final VoidCallback onOpenNotifications;

  const KetuaHeaderWidget({
    super.key,
    required this.isDesktop,
    required this.isSidebarOpen,
    required this.isRefreshing,
    required this.unreadNotificationsCount,
    required this.onToggleSidebar,
    required this.onRefresh,
    required this.onOpenNotifications,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.adminNavy,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          isDesktop
              ? (isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded)
              : Icons.menu_rounded,
          color: Colors.white,
        ),
        tooltip: 'Toggle Sidebar',
        onPressed: onToggleSidebar,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              isDesktop ? 'Dashboard Manajer' : 'Dashboard Manajer',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 17 : 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        //  NOTIFIKASI BUTTON WITH UNREAD BADGE
        IconButton(
          tooltip: 'Notifikasi Terbaru',
          onPressed: onOpenNotifications,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
              if (unreadNotificationsCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                    child: Text(
                      '$unreadNotificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),

        //  REFRESH BUTTON WITH LOADING INDICATOR
        IconButton(
          tooltip: 'Refresh Data',
          onPressed: isRefreshing ? null : onRefresh,
          icon: isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
        ),

        const SizedBox(width: 4),
      ],
    );
  }
}
