import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../data/models/member_model.dart';

export '../data/models/member_model.dart';

/// Custom Reusable Widget Card Anggota Koperasi
class MemberCard extends StatelessWidget {
  final MemberModel member;
  final VoidCallback? onEditPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onTap;

  const MemberCard({
    super.key,
    required this.member,
    this.onEditPressed,
    this.onDeletePressed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                // Avatar Lingkaran dengan Hero Tag unik per anggota (mencegah duplicate hero tag)
                Hero(
                  tag: 'member_avatar_${member.id}',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: member.avatarBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        member.initials,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: member.avatarTextColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Informasi Detail Anggota
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBackground,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'NIA: ${member.memberNo.padLeft(4, '0')}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    if (member.bukuPutihNumber.isNotEmpty && member.bukuPutihNumber != '-' && member.bukuPutihNumber != 'null')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3E5F5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFCE93D8)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.menu_book_rounded, size: 11, color: Color(0xFF6A1B9A)),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Buku Putih: ${member.bukuPutihNumber.startsWith('2021-') ? member.bukuPutihNumber : "2021-${member.bukuPutihNumber}"}',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF6A1B9A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // NIK & Gereja / Jemaat
                      Text(
                        'NIK: ${member.nik}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Gereja / Jemaat Info
                      Row(
                        children: [
                          const Icon(
                            Icons.church_rounded,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              member.church,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tombol Edit (Pena)
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.accentBlue,
                    size: 20,
                  ),
                  tooltip: 'Edit Data Anggota',
                  onPressed: onEditPressed,
                ),
                if (onDeletePressed != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    tooltip: 'Hapus Data Anggota',
                    onPressed: onDeletePressed,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
