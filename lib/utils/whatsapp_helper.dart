import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';

/// Model Item Kontak Resmi Koperasi
class WhatsAppContact {
  final String label;
  final String subtitle;
  final String phone;
  final String displayPhone;
  final IconData icon;
  final Color themeColor;
  final String Function(String name, String number) templateBuilder;

  const WhatsAppContact({
    required this.label,
    required this.subtitle,
    required this.phone,
    required this.displayPhone,
    required this.icon,
    required this.themeColor,
    required this.templateBuilder,
  });
}

/// Helper Resmi Pengelolaan Kontak WhatsApp Koperasi CUM Pelita
class WhatsAppHelper {
  static final List<WhatsAppContact> contacts = [
    WhatsAppContact(
      label: 'Admin 1',
      subtitle: 'Layanan Anggota & Pendaftaran',
      phone: '6283178240112',
      displayPhone: '0831-7824-0112',
      icon: Icons.person_outline_rounded,
      themeColor: const Color(0xFF137A43),
      templateBuilder: (name, number) =>
          "Syalom, Selamat pagi/siang Bapak/Ibu Admin CUM PELITA HKBP DAME DURI. Saya $name ($number), ingin bertanya mengenai layanan anggota/pendaftaran...",
    ),
    WhatsAppContact(
      label: 'Admin 2',
      subtitle: 'Administrasi & Simpanan',
      phone: '6282381861201',
      displayPhone: '0823-8186-1201',
      icon: Icons.person_outline_rounded,
      themeColor: const Color(0xFF0284C7),
      templateBuilder: (name, number) =>
          "Syalom, Selamat pagi/siang Bapak/Ibu Admin CUM PELITA HKBP DAME DURI. Saya $name ($number), ingin bertanya mengenai administrasi simpanan...",
    ),
    WhatsAppContact(
      label: 'Manajer Koperasi',
      subtitle: 'Layanan Khusus & Manajerial',
      phone: '6281266807056',
      displayPhone: '0812-6680-7056',
      icon: Icons.person_outline_rounded,
      themeColor: const Color(0xFF6A1B9A),
      templateBuilder: (name, number) =>
          "Syalom, Selamat pagi/siang Bapak/Ibu Manajer CUM PELITA HKBP DAME DURI. Saya $name ($number), ingin menyampaikan perihal...",
    ),
  ];

  // Aksi Klik Item: Membuka URL WhatsApp menggunakan LaunchMode.externalApplication
  static Future<void> launchWhatsAppTo({
    required BuildContext context,
    required String targetPhone,
    required String targetText,
  }) async {
    final String encodedText = Uri.encodeComponent(targetText);
    final Uri url = Uri.parse("https://api.whatsapp.com/send?phone=$targetPhone&text=$encodedText");
    final Uri waSchemeUri = Uri.parse("whatsapp://send?phone=$targetPhone&text=$encodedText");

    try {
      final bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(waSchemeUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka WhatsApp. Silakan hubungi nomor $targetPhone'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Fungsi kompatibilitas untuk panggilan langsung
  static Future<void> launchWhatsApp(
    BuildContext context, {
    required String message,
    String? phone,
  }) async {
    await launchWhatsAppTo(
      context: context,
      targetPhone: phone ?? contacts.first.phone,
      targetText: message,
    );
  }

  // Menampilkan Modal BottomSheet Pilihan Kontak WhatsApp Petugas & Manajer
  static Future<void> showContactBottomSheet(
    BuildContext context, {
    String? memberName,
    String? memberNumber,
    String? customHeaderTitle,
    String? customHeaderSubtitle,
  }) async {
    // Ambil data anggota tersimpan secara otomatis jika tidak disediakan
    String resolvedName = memberName ?? '';
    String resolvedNumber = memberNumber ?? '';

    if (resolvedName.isEmpty || resolvedNumber.isEmpty) {
      try {
        final savedUser = await AuthService().getSavedUser();
        if (savedUser != null) {
          if (resolvedName.isEmpty) {
            resolvedName = (savedUser['name'] ?? savedUser['nama'] ?? '').toString();
          }
          if (resolvedNumber.isEmpty) {
            resolvedNumber = (savedUser['member_number'] ??
                    savedUser['member_no'] ??
                    savedUser['no_anggota'] ??
                    savedUser['no_register'] ??
                    '')
                .toString();
          }
        }
      } catch (_) {}
    }

    final String finalName = resolvedName.isNotEmpty ? resolvedName : 'Calon Anggota / Anggota';
    final String finalNumber = resolvedNumber.isNotEmpty ? resolvedNumber : '-';

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).padding.bottom + 20,
            top: 12,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header Modal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Color(0xFF2E7D32),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customHeaderTitle ?? 'Hubungi Pengelola & Petugas',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.adminNavy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          customHeaderSubtitle ??
                              'Pilih kontak yang sesuai dengan kebutuhan layanan Anda:',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Daftar Item Kontak
              ...contacts.map((contact) {
                final String targetText = contact.templateBuilder(finalName, finalNumber);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(modalContext);
                        launchWhatsAppTo(
                          context: context,
                          targetPhone: contact.phone,
                          targetText: targetText,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            // Avatar Icon (Netral & Seragam)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              child: Icon(
                                contact.icon,
                                color: Colors.grey.shade700,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Detail Informasi Kontak
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        contact.label,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.adminNavy,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.green.shade200),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 10,
                                              color: Color(0xFF25D366),
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              'WhatsApp',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1B5E20),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    contact.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    contact.displayPhone,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // WhatsApp Send Action Icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
