import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../data/models/backup_file_model.dart';
import '../../../utils/navigation_utils.dart';

///  1. QUICK ACTIONS CARD BACKUP & RESTORE
class QuickBackupCard extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback onGenerateBackup;
  final VoidCallback onUploadRestore;

  const QuickBackupCard({
    super.key,
    required this.isGenerating,
    required this.onGenerateBackup,
    required this.onUploadRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text(
                'Tindakan Cepat Backup & Restore',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.adminNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Buat salinan cadangan (.sql/.zip) database secara berkala untuk perlindungan kehilangan data akibat kegagalan sistem.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: isGenerating ? null : onGenerateBackup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_to_photos_rounded, size: 18),
                label: Text(
                  isGenerating ? 'Membuat Backup...' : 'Buat Backup Baru',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onUploadRestore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text(
                  'Upload & Restore File Backup',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ⚠️ 2. RESTORE CONFIRMATION DIALOG (SAFEDOUBLE CONFIRMATION)
class RestoreConfirmationDialog extends StatefulWidget {
  final BackupFileModel backupFile;
  final Function(String confirmPassword) onSubmitRestore;

  const RestoreConfirmationDialog({
    super.key,
    required this.backupFile,
    required this.onSubmitRestore,
  });

  @override
  State<RestoreConfirmationDialog> createState() => _RestoreConfirmationDialogState();
}

class _RestoreConfirmationDialogState extends State<RestoreConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _keywordController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _keywordController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 26),
          SizedBox(width: 10),
          Text('PERINGATAN: Pemulihan Database', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anda akan mengembalikan database ke file "${widget.backupFile.filename}" (${widget.backupFile.createdAt}).',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️ BAHAYA: Seluruh data saat ini akan ditimpa!', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.danger)),
                    SizedBox(height: 4),
                    Text('Aplikasi akan dimasukkan ke Maintenance Mode sementara saat proses pemulihan berjalan.', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _keywordController,
                validator: (val) {
                  if (val == null || val.trim().toUpperCase() != 'RESTORE') {
                    return 'Ketik kata "RESTORE" dengan benar!';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Ketik "RESTORE" untuk konfirmasi',
                  hintText: 'RESTORE',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Password Otorisasi wajib diisi!';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Password Otorisasi Ketua / Admin',
                  hintText: 'Masukkan password Anda...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => NavigationUtils.safePop(context),
          child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final pwd = _passwordController.text.trim();
              NavigationUtils.safePop(context);
              widget.onSubmitRestore(pwd);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Eksekusi Restore Database'),
        ),
      ],
    );
  }
}
