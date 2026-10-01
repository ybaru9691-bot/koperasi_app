import 'package:flutter/material.dart';
import '../../../data/dummy/ketua_dummy_data.dart';

// WIDGET STAT CARDS EKSEKUTIF KETUA (RESPONSIF GRID-COLS-1 SM:2 LG:3 XL:4)
class KetuaStatCardsWidget extends StatelessWidget {
  final bool isDesktop;
  final List<StatCardModel>? cards;

  const KetuaStatCardsWidget({
    super.key,
    required this.isDesktop,
    this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final list = cards ?? KetuaDummyData.statCards;

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
            return _ExecutiveStatCardItem(card: list[index]);
          },
        );
      },
    );
  }
}

class _ExecutiveStatCardItem extends StatelessWidget {
  final StatCardModel card;

  const _ExecutiveStatCardItem({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: card.bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: card.color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: card.color.withValues(alpha: 0.08),
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
                  card.title,
                  style: TextStyle(
                    fontSize: 11,
                    color: card.color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  card.value,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: card.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  card.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: card.color.withValues(alpha: 0.75),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: card.color.withValues(alpha: 0.15),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(card.icon, color: card.color, size: 20),
          ),
        ],
      ),
    );
  }
}
