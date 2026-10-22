import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../services/app_update_service.dart';

/// 📱 Dialog Pembaruan Aplikasi (Force Update & Optional Update)
///
/// Fitur Utama:
/// - Menggunakan [PopScope] (canPop: false) jika update bersifat WAJIB (Force Update).
/// - Tombol "Perbarui Sekarang" memanggil `launchUrl` dengan `LaunchMode.externalApplication`.
/// - Menampilkan rincian catatan rilis (release notes) dari server.
/// - Menampilkan perbandingan versi saat ini vs versi terbaru.
class ForceUpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onDismissOptional;

  const ForceUpdateDialog({
    super.key,
    required this.updateInfo,
    this.onDismissOptional,
  });

  /// Helper untuk membuka dialog secara terpusat
  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    VoidCallback? onDismissOptional,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (ctx) => ForceUpdateDialog(
        updateInfo: updateInfo,
        onDismissOptional: onDismissOptional,
      ),
    );
  }

  /// Membuka tautan unduhan pembaruan di browser/Play Store eksternal
  Future<void> _launchUpdateUrl(BuildContext context) async {
    final rawUrl = updateInfo.downloadUrl.trim();
    if (rawUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tautan unduhan tidak tersedia. Silakan hubungi admin koperasi.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    try {
      final Uri uri = Uri.parse(rawUrl);
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka tautan pembaruan: $rawUrl'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ForceUpdateDialog] Error meluncurkan download_url: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat membuka tautan: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope: Jika mandatory, user DILARANG pop / back keluar dialog
    return PopScope(
      canPop: !updateInfo.isMandatory,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // User menekan tombol back saat force update aktif
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembaruan wajib dilakukan untuk terus menggunakan aplikasi.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Icon Header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: updateInfo.isMandatory
                        ? const Color(0xFFFEF2F2) // Merah muda lembut
                        : const Color(0xFFECFDF5), // Hijau muda lembut
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: updateInfo.isMandatory
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF86EFAC),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    updateInfo.isMandatory
                        ? Icons.system_security_update_rounded
                        : Icons.rocket_launch_rounded,
                    size: 36,
                    color: updateInfo.isMandatory
                        ? AppColors.danger
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Judul Dialog
              Text(
                updateInfo.isMandatory
                    ? 'Pembaruan Wajib Tersedia'
                    : 'Pembaruan Aplikasi Tersedia',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.adminNavy,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // 3. Badge Versi (Lokal vs Terbaru)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.adminCanvas,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'v${updateInfo.currentVersion}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        'v${updateInfo.latestVersion}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Deskripsi Penjelasan
              Text(
                updateInfo.isMandatory
                    ? 'Versi aplikasi Anda saat ini sudah tidak didukung demi keamanan dan kelancaran transaksi data koperasi. Harap perbarui ke versi terbaru untuk melanjutkan.'
                    : 'Fitur baru dan peningkatan performa tersedia. Perbarui sekarang untuk mendapatkan pengalaman terbaik.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // 5. Kotak Rincian Catatan Rilis (Release Notes)
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 15,
                          color: AppColors.adminNavy,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Catatan Pembaruan:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.adminNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          updateInfo.releaseNotes.trim().isNotEmpty
                              ? updateInfo.releaseNotes.trim()
                              : '• Pembaruan performa dan stabilitas sistem.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 6. Tombol Aksi "Perbarui Sekarang"
              ElevatedButton.icon(
                onPressed: () => _launchUpdateUrl(context),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text(
                  'Perbarui Sekarang',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // 7. Tombol "Nanti Saja" (Hanya ditampilkan jika BUKAN Mandatory/Force Update)
              if (!updateInfo.isMandatory) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onDismissOptional != null) {
                      onDismissOptional!();
                    }
                  },
                  child: const Text(
                    'Nanti Saja',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
