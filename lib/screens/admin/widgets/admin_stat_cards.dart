import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_stat_model.dart';

// WIDGET STAT CARDS KHUSUS ADMIN (RESPONSIF GRID-COLS-1 SM:2 LG:3 XL:4)
class AdminStatCardsWidget extends StatelessWidget {
  final bool isDesktop;
  final List<AdminStatModel>? statCards;

  const AdminStatCardsWidget({
    super.key,
    required this.isDesktop,
    this.statCards,
  });

  @override
  Widget build(BuildContext context) {
    final list = statCards ?? const [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount;
        double childAspectRatio;

        // Responsif multi-breakpoint layout (grid-cols-1 sm:2 lg:3 xl:4)
        if (width >= 1100) {
          crossAxisCount = 4;
          childAspectRatio = 2.1;
        } else if (width >= 780) {
          crossAxisCount = 3;
          childAspectRatio = 2.1;
        } else if (width >= 500) {
          crossAxisCount = 2;
          childAspectRatio = 2.1;
        } else {
          crossAxisCount = 1;
          childAspectRatio = 3.2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = list[index];
            return _AdminStatCardItemWidget(
              title: item.title,
              value: item.value,
              icon: item.icon,
              iconBg: item.iconBg,
              iconColor: item.iconColor,
              subtitle: item.subtitle,
            );
          },
        );
      },
    );
  }
}

class _AdminStatCardItemWidget extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String? subtitle;

  const _AdminStatCardItemWidget({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ],
      ),
    );
  }
}
