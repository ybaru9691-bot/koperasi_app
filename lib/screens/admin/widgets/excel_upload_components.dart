import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// 📄 1. CARD INSTRUKSI & DOWNLOAD TEMPLATE EXCEL
class DownloadTemplateCard extends StatelessWidget {
  final VoidCallback onDownloadTemplate;
  final bool isDownloading;

  const DownloadTemplateCard({
    super.key,
    required this.onDownloadTemplate,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.table_chart_rounded, color: Color(0xFF0284C7), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unduh Template Excel Resmi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0369A1),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gunakan format kolom resmi (NIK, Nama Lengkap, NIA, Simpanan Pokok, Simpanan Wajib, Simpanan Sukarela, Plafon Pinjaman, & Sisa Pokok) agar data ter-parse otomatis tanpa error.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: isDownloading ? null : onDownloadTemplate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    isDownloading ? 'Mengunduh Template...' : 'Download Template Excel (.xlsx)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

///  2. DRAG & DROP / FILE PICKER AREA (CUSTOM DOTTED BORDER BOX)
class ExcelUploadPickerWidget extends StatelessWidget {
  final PlatformFile? selectedFile;
  final VoidCallback onPickFile;
  final VoidCallback onRemoveFile;

  const ExcelUploadPickerWidget({
    super.key,
    required this.selectedFile,
    required this.onPickFile,
    required this.onRemoveFile,
  });

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: selectedFile != null ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedFile != null ? AppColors.primary : AppColors.cardBorder,
          width: selectedFile != null ? 2 : 1.5,
        ),
      ),
      child: selectedFile == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Klik atau seret file Excel ke sini',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminNavy,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Format didukung: .xlsx, .csv (Maksimal 10MB)',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onPickFile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Pilih File dari Komputer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_rounded, color: AppColors.success, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedFile!.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.adminNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ukuran: ${_formatBytes(selectedFile!.size)} • Siap Di-import',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onRemoveFile,
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                  label: const Text('Ganti File', style: TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }
}
