/// 💾 MODEL DATA FILE BACKUP DATABASE KOPERASI
class BackupFileModel {
  final String filename;
  final String sizeFormatted;
  final int sizeBytes;
  final String createdAt;
  final String? downloadUrl;

  BackupFileModel({
    required this.filename,
    required this.sizeFormatted,
    required this.sizeBytes,
    required this.createdAt,
    this.downloadUrl,
  });

  factory BackupFileModel.fromJson(Map<String, dynamic> json) {
    return BackupFileModel(
      filename: json['filename'] ?? json['name'] ?? '',
      sizeFormatted: json['size_formatted'] ?? json['size'] ?? '0 MB',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      createdAt: json['created_at'] ?? '',
      downloadUrl: json['download_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'size_formatted': sizeFormatted,
      'size_bytes': sizeBytes,
      'created_at': createdAt,
      'download_url': downloadUrl,
    };
  }

  /// Dummy Repository File Backup untuk Mock Offline Mode
  static List<BackupFileModel> getDummyBackups() {
    return [
      BackupFileModel(
        filename: 'backup_cumpelita_2026_07_31_080000.sql.zip',
        sizeFormatted: '14.2 MB',
        sizeBytes: 14889728,
        createdAt: '31/07/2026 08:00',
        downloadUrl: '/api/v1/admin/backup/download/backup_cumpelita_2026_07_31_080000.sql.zip',
      ),
      BackupFileModel(
        filename: 'backup_cumpelita_2026_07_24_080000.sql.zip',
        sizeFormatted: '13.8 MB',
        sizeBytes: 14470348,
        createdAt: '24/07/2026 08:00',
        downloadUrl: '/api/v1/admin/backup/download/backup_cumpelita_2026_07_24_080000.sql.zip',
      ),
      BackupFileModel(
        filename: 'backup_cumpelita_2026_07_17_080000.sql.zip',
        sizeFormatted: '13.5 MB',
        sizeBytes: 14155776,
        createdAt: '17/07/2026 08:00',
        downloadUrl: '/api/v1/admin/backup/download/backup_cumpelita_2026_07_17_080000.sql.zip',
      ),
    ];
  }
}
