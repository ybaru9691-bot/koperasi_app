import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../data/models/activity_log_model.dart';
import '../../services/activity_log_service.dart';
import 'widgets/audit_log_components.dart';

/// 📜 LAYAR AUDIT TRAIL / LOG AKTIVITAS PENGGUNA (ADMIN & KETUA)
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedModule = 'semua';
  String _selectedAction = 'semua';
  bool _isLoading = true;
  List<ActivityLogModel> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);

    final results = await ActivityLogService.fetchAuditLogs(
      searchQuery: _searchController.text.trim(),
      moduleFilter: _selectedModule,
      actionFilter: _selectedAction,
    );

    if (!mounted) return;

    setState(() {
      _logs = results;
      _isLoading = false;
    });
  }

  void _showDetailDialog(ActivityLogModel log) {
    showDialog(
      context: context,
      builder: (dialogContext) => AuditLogDetailDialog(log: log),
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
                Icon(Icons.history_toggle_off_rounded, color: AppColors.adminAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Audit Trail & Log Aktivitas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24.0 : 12.0,
              vertical: 16.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER TITLE
                    const Text(
                      'Audit & Control Log Aktivitas Pengguna',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.adminNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Catatan otomatis transaksi, perubahan data anggota, otentikasi login, dan konfigurasi sistem.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),

                    const SizedBox(height: 16),

                    // 1. FILTER BAR
                    AuditLogFilterBar(
                      searchController: _searchController,
                      selectedModule: _selectedModule,
                      selectedAction: _selectedAction,
                      onSearchChanged: (val) => _loadAuditLogs(),
                      onModuleChanged: (val) {
                        setState(() => _selectedModule = val ?? 'semua');
                        _loadAuditLogs();
                      },
                      onActionChanged: (val) {
                        setState(() => _selectedAction = val ?? 'semua');
                        _loadAuditLogs();
                      },
                    ),

                    const SizedBox(height: 16),

                    // 2. DATA TABLE / LIST CARD LOGS
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_logs.isEmpty)
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
                            Icon(Icons.manage_search_rounded, size: 48, color: AppColors.textMuted),
                            SizedBox(height: 10),
                            Text('Tidak Ada Log Aktivitas Ditemukan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                            SizedBox(height: 2),
                            Text('Coba ubah kata kunci pencarian atau filter modul.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
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
                              constraints: BoxConstraints(minWidth: isDesktop ? 1000 : 750),
                              child: Table(
                                columnWidths: const {
                                  0: FixedColumnWidth(130),
                                  1: FixedColumnWidth(160),
                                  2: FixedColumnWidth(110),
                                  3: FixedColumnWidth(110),
                                  4: FlexColumnWidth(3),
                                  5: FixedColumnWidth(80),
                                },
                                children: [
                                  // Table Header
                                  TableRow(
                                    decoration: const BoxDecoration(color: AppColors.adminNavy),
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        child: Text('Waktu', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        child: Text('Pengguna', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        child: Text('Modul', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        child: Text('Aksi', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        child: Text('Deskripsi Aktivitas', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        child: Text('Opsi', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),

                                  // Table Body Rows
                                  for (int i = 0; i < _logs.length; i++)
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          child: Text(_logs[i].createdAt, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(_logs[i].userName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                                              Text(_logs[i].userRole.toUpperCase(), style: const TextStyle(fontSize: 9.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          child: Text(_logs[i].module, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          child: AuditLogActionChip(action: _logs[i].action),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                          child: Text(
                                            _logs[i].description,
                                            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                          child: Center(
                                            child: IconButton(
                                              icon: const Icon(Icons.visibility_rounded, size: 18, color: AppColors.primary),
                                              tooltip: 'Lihat Detail Perubahan',
                                              onPressed: () => _showDetailDialog(_logs[i]),
                                            ),
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
        );
      },
    );
  }
}
