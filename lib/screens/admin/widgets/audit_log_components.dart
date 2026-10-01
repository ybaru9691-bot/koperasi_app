import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../data/models/activity_log_model.dart';
import '../../../utils/navigation_utils.dart';

/// 🏷️ 1. CHIP BADGE AKSI WARNA RESPONSIF
class AuditLogActionChip extends StatelessWidget {
  final String action;

  const AuditLogActionChip({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (action.toUpperCase()) {
      case 'CREATE':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        icon = Icons.add_circle_outline_rounded;
        break;
      case 'UPDATE':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        icon = Icons.edit_note_rounded;
        break;
      case 'DELETE':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        icon = Icons.delete_outline_rounded;
        break;
      case 'LOGIN':
      case 'LOGOUT':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.key_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            action.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }
}

/// 🔍 2. FILTER BAR (SEARCH + MODULE DROPDOWN + ACTION DROPDOWN)
class AuditLogFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedModule;
  final String selectedAction;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onModuleChanged;
  final ValueChanged<String?> onActionChanged;

  const AuditLogFilterBar({
    super.key,
    required this.searchController,
    required this.selectedModule,
    required this.selectedAction,
    required this.onSearchChanged,
    required this.onModuleChanged,
    required this.onActionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // SEARCH INPUT
          SizedBox(
            width: 280,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari nama, ID, atau deskripsi...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ),
          ),

          // FILTER MODUL
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              initialValue: selectedModule,
              isDense: true,
              decoration: InputDecoration(
                labelText: 'Modul',
                labelStyle: const TextStyle(fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'semua', child: Text('Semua Modul', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'Anggota', child: Text('Anggota', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'Simpanan', child: Text('Simpanan', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'Pinjaman', child: Text('Pinjaman', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'System', child: Text('System', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'Auth', child: Text('Auth', style: TextStyle(fontSize: 12))),
              ],
              onChanged: onModuleChanged,
            ),
          ),

          // FILTER AKSI
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              initialValue: selectedAction,
              isDense: true,
              decoration: InputDecoration(
                labelText: 'Aksi',
                labelStyle: const TextStyle(fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'semua', child: Text('Semua Aksi', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'CREATE', child: Text('CREATE', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'UPDATE', child: Text('UPDATE', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'DELETE', child: Text('DELETE', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'LOGIN', child: Text('LOGIN', style: TextStyle(fontSize: 12))),
              ],
              onChanged: onActionChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. DIALOG DETAIL AUDIT LOG (PERBEDAAN DATA LAMA VS DATA BARU)
class AuditLogDetailDialog extends StatelessWidget {
  final ActivityLogModel log;

  const AuditLogDetailDialog({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final oldData = log.oldValues;
    final newData = log.newValues;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.security_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Detail Audit Log #${log.id}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // METADATA USER & WAKTU
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    _metaRow('Waktu / Tanggal', log.createdAt, Icons.schedule_rounded),
                    const SizedBox(height: 6),
                    _metaRow('Pengguna', '${log.userName} (${log.userRole.toUpperCase()})', Icons.person_rounded),
                    const SizedBox(height: 6),
                    _metaRow('Modul & Aksi', '${log.module} • ${log.action}', Icons.category_rounded),
                    const SizedBox(height: 6),
                    _metaRow('IP Address', '${log.ipAddress} (${log.userAgent})', Icons.computer_rounded),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              const Text('Deskripsi Aktivitas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
              const SizedBox(height: 4),
              Text(log.description, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),

              const SizedBox(height: 16),

              // VISUAL DIFF DATA LAMA VS BARU
              if (oldData != null || newData != null) ...[
                const Text('Rincian Perubahan Data (Properties Diff):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (oldData != null)
                      Expanded(
                        child: _jsonBox('Data Sebelum (Old)', oldData, AppColors.dangerBg, AppColors.danger),
                      ),
                    if (oldData != null && newData != null) const SizedBox(width: 8),
                    if (newData != null)
                      Expanded(
                        child: _jsonBox('Data Sesudah (New)', newData, AppColors.successBg, AppColors.success),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => NavigationUtils.safePop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.adminNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _metaRow(String label, String val, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Expanded(
          child: Text(val, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _jsonBox(String title, Map<String, dynamic> data, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: border)),
          const SizedBox(height: 6),
          for (var entry in data.entries) ...[
            Text(
              '${entry.key}: ${entry.value}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}
