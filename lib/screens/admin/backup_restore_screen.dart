import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../data/models/backup_file_model.dart';
import '../../services/backup_service.dart';
import 'widgets/backup_components.dart';

/// 💾 LAYAR BACKUP & RESTORE DATABASE KOPERASI CUM PELITA
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isLoadingList = true;
  bool _isGenerating = false;
  bool _isRestoring = false;
  List<BackupFileModel> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoadingList = true);

    final results = await BackupService.fetchBackupList();

    if (!mounted) return;

    setState(() {
      _backups = results;
      _isLoadingList = false;
    });
  }

  /// ➕ BUAT BACKUP BARU
  Future<void> _handleGenerateBackup() async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    final res = await BackupService.generateBackup();

    if (!mounted) return;

    setState(() => _isGenerating = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(res['message'] ?? 'File backup database berhasil dibuat.'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _loadBackups();
  }

  /// 🔄 RESTORE DATABASE DARI FILE TERPILIH
  void _handleConfirmRestore(BackupFileModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return RestoreConfirmationDialog(
          backupFile: item,
          onSubmitRestore: (password) async {
            setState(() => _isRestoring = true);

            final res = await BackupService.restoreBackup(
              filename: item.filename,
              confirmPassword: password,
            );

            if (!mounted) return;

            setState(() => _isRestoring = false);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.restore_page_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(res['message'] ?? 'Database berhasil dipulihkan.'),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          },
        );
      },
    );
  }

  /// 📥 DOWNLOAD FILE BACKUP
  void _handleDownload(BackupFileModel item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.downloading_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Mengunduh ${item.filename}...'),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: AppColors.adminCanvas,
          appBar: AppBar(
            backgroundColor: AppColors.adminNavy,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Row(
              children: const [
                Icon(Icons.storage_rounded, color: AppColors.adminAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Backup & Restore Database',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24.0 : 12.0,
                  vertical: 16.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER TITLE
                        const Text(
                          'Manajemen Salinan Cadangan & Pemulihan Database',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.adminNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Buat backup berkala atau pulihkan database Koperasi CUM Pelita secara aman.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),

                        const SizedBox(height: 20),

                        // 1. QUICK ACTIONS CARD
                        QuickBackupCard(
                          isGenerating: _isGenerating,
                          onGenerateBackup: _handleGenerateBackup,
                          onUploadRestore: () {
                            if (_backups.isNotEmpty) {
                              _handleConfirmRestore(_backups.first);
                            }
                          },
                        ),

                        const SizedBox(height: 24),

                        // 2. RIWAYAT FILE BACKUP TABLE
                        Row(
                          children: const [
                            Icon(Icons.folder_zip_rounded, color: AppColors.adminNavy, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Daftar File Backup di Server Storage',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.adminNavy,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (_isLoadingList)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                          )
                        else if (_backups.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.folder_off_rounded, size: 44, color: AppColors.textMuted),
                                SizedBox(height: 8),
                                Text('Belum Ada File Backup Tersedia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: isDesktop ? 950 : 700),
                                  child: Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(3),
                                      1: FixedColumnWidth(150),
                                      2: FixedColumnWidth(110),
                                      3: FixedColumnWidth(210),
                                    },
                                    children: [
                                      // Table Header
                                      TableRow(
                                        decoration: const BoxDecoration(color: AppColors.adminNavy),
                                        children: const [
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            child: Text('Nama File Backup', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            child: Text('Waktu Dibuat', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            child: Text('Ukuran File', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            child: Text('Aksi Pengelolaan', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),

                                      // Table Body Rows
                                      for (int i = 0; i < _backups.length; i++)
                                        TableRow(
                                          decoration: BoxDecoration(
                                            color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.primary),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _backups[i].filename,
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                              child: Text(_backups[i].createdAt, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                              child: Text(_backups[i].sizeFormatted, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: () => _handleDownload(_backups[i]),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: AppColors.primary,
                                                      side: const BorderSide(color: AppColors.primary),
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                    icon: const Icon(Icons.download_rounded, size: 14),
                                                    label: const Text('Download', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _handleConfirmRestore(_backups[i]),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.danger,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                    icon: const Icon(Icons.restore_rounded, size: 14),
                                                    label: const Text('Restore', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // OVERLAY LOADING RESTORE
              if (_isRestoring)
                Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: const Center(
                    child: Card(
                      color: Colors.white,
                      margin: EdgeInsets.all(24),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.danger),
                            SizedBox(height: 16),
                            Text('Memulihkan Database...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                            SizedBox(height: 4),
                            Text('Mohon tidak menutup aplikasi saat pemulihan berjalan.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
