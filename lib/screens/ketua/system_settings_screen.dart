import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../data/models/system_setting_model.dart';
import '../../utils/navigation_utils.dart';
import 'widgets/setting_components.dart';

///  HALAMAN PENGATURAN SISTEM & KONFIGURASI OPERASIONAL (KETUA VIEW)
class SystemSettingsScreen extends StatefulWidget {
  final Function(SystemSettingModel settings)? onSaveSettingsCallback;

  const SystemSettingsScreen({
    super.key,
    this.onSaveSettingsCallback,
  });

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SystemSettingModel _settings;
  bool _isDirty = false;
  bool _isSaving = false;

  // Controllers Tab 1: Limit & Kebijakan
  late TextEditingController _limitKmController;
  late TextEditingController _limitKkController;
  late bool _enableAutoApprovalKM;
  late bool _requireAttachmentKK;

  // Controllers Tab 2: Keuangan & Parameter
  late TextEditingController _simpananPokokController;
  late TextEditingController _simpananWajibController;
  late TextEditingController _bungaPinjamanController;
  late TextEditingController _dendaLateController;

  // Controllers Tab 4: Profil & Keamanan
  late TextEditingController _koperasiNameController;
  late TextEditingController _legalNoController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late bool _enable2FA;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _settings = SystemSettingModel.getDefaultSettings();

    // Init values
    _limitKmController = TextEditingController(text: _settings.autoApprovalLimitKM.toStringAsFixed(0));
    _limitKkController = TextEditingController(text: _settings.manualApprovalLimitKK.toStringAsFixed(0));
    _enableAutoApprovalKM = _settings.enableAutoApprovalSmallKM;
    _requireAttachmentKK = _settings.requireAttachmentForLargeKK;

    _simpananPokokController = TextEditingController(text: _settings.simpananPokokDefault.toStringAsFixed(0));
    _simpananWajibController = TextEditingController(text: _settings.simpananWajibDefault.toStringAsFixed(0));
    _bungaPinjamanController = TextEditingController(text: _settings.sukuBungaPinjamanMonthly.toString());
    _dendaLateController = TextEditingController(text: _settings.dendaKeterlambatanMonthly.toString());

    _koperasiNameController = TextEditingController(text: _settings.koperasiName);
    _legalNoController = TextEditingController(text: _settings.legalNo);
    _addressController = TextEditingController(text: _settings.address);
    _phoneController = TextEditingController(text: _settings.phone);
    _enable2FA = _settings.enable2FAAuth;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _limitKmController.dispose();
    _limitKkController.dispose();
    _simpananPokokController.dispose();
    _simpananWajibController.dispose();
    _bungaPinjamanController.dispose();
    _dendaLateController.dispose();
    _koperasiNameController.dispose();
    _legalNoController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _markAsDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  ///  KONFIRMASI & SIMPAN PENGATURAN
  void _confirmAndSaveSettings() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.settings_suggest_rounded, color: AppColors.primary, size: 26),
              SizedBox(width: 10),
              Text('Konfirmasi Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin memperbarui konfigurasi sistem operasional koperasi ini?',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationUtils.safePop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                NavigationUtils.safePop(dialogContext);

                setState(() => _isSaving = true);

                await Future.delayed(const Duration(milliseconds: 600));

                if (!mounted) return;

                final updatedSettings = SystemSettingModel(
                  autoApprovalLimitKM: double.tryParse(_limitKmController.text) ?? 1000000,
                  manualApprovalLimitKK: double.tryParse(_limitKkController.text) ?? 5000000,
                  enableAutoApprovalSmallKM: _enableAutoApprovalKM,
                  requireAttachmentForLargeKK: _requireAttachmentKK,
                  simpananPokokDefault: double.tryParse(_simpananPokokController.text) ?? 500000,
                  simpananWajibDefault: double.tryParse(_simpananWajibController.text) ?? 50000,
                  sukuBungaPinjamanMonthly: double.tryParse(_bungaPinjamanController.text) ?? 1.5,
                  dendaKeterlambatanMonthly: double.tryParse(_dendaLateController.text) ?? 0.5,
                  operatorUsers: _settings.operatorUsers,
                  koperasiName: _koperasiNameController.text.trim(),
                  legalNo: _legalNoController.text.trim(),
                  address: _addressController.text.trim(),
                  phone: _phoneController.text.trim(),
                  enable2FAAuth: _enable2FA,
                );

                if (widget.onSaveSettingsCallback != null) {
                  widget.onSaveSettingsCallback!(updatedSettings);
                }

                setState(() {
                  _settings = updatedSettings;
                  _isSaving = false;
                  _isDirty = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Konfigurasi sistem berhasil diperbarui.'),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ya, Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24.0 : 12.0,
            vertical: 16.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER SECTION
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.settings_rounded, color: AppColors.primary, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Pengaturan Sistem & Konfigurasi Operasional',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.adminNavy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Kelola batas persetujuan transaksi, parameter bunga/simpanan, hak akses user, dan keamanan.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),

                      // SAVE BUTTON
                      ElevatedButton.icon(
                        onPressed: _isDirty && !_isSaving ? _confirmAndSaveSettings : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDirty ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          _isDirty ? 'Simpan Perubahan' : 'Tidak Ada Perubahan',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // TAB BAR SECTION
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textMuted,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(icon: Icon(Icons.rule_rounded, size: 18), text: 'Kebijakan & Limit'),
                        Tab(icon: Icon(Icons.calculate_rounded, size: 18), text: 'Keuangan & Parameter'),
                        Tab(icon: Icon(Icons.admin_panel_settings_rounded, size: 18), text: 'User Operator'),
                        Tab(icon: Icon(Icons.security_rounded, size: 18), text: 'Profil & Keamanan'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // TAB CONTENT VIEWS (SizedBox Fixed Height for Clean View)
                  SizedBox(
                    height: 520,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: KEBIJAKAN TRANSAKSI & LIMIT
                        SingleChildScrollView(
                          child: SettingSectionCard(
                            title: 'Batas Persetujuan Transaksi (Limit ACC)',
                            description: 'Tentukan threshold nominal transaksi yang dapat di-auto approve oleh sistem atau butuh ACC manual Ketua.',
                            icon: Icons.rule_rounded,
                            children: [
                              SettingInputField(
                                label: 'Batas Auto-Approval Kas Masuk (KM)',
                                hint: '1000000',
                                prefixText: 'Rp',
                                controller: _limitKmController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _markAsDirty(),
                              ),
                              SettingInputField(
                                label: 'Batas Minimum Approval Manual Kas Keluar (KK)',
                                hint: '5000000',
                                prefixText: 'Rp',
                                controller: _limitKkController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _markAsDirty(),
                              ),
                              SettingToggleTile(
                                title: 'Aktifkan Auto-Approval KM < Rp 1.000.000',
                                subtitle: 'Kas Masuk di bawah limit ini akan otomatis ter-approve tanpa perlu verifikasi manual Ketua.',
                                value: _enableAutoApprovalKM,
                                onChanged: (val) {
                                  setState(() => _enableAutoApprovalKM = val);
                                  _markAsDirty();
                                },
                              ),
                              SettingToggleTile(
                                title: 'Wajibkan Lampiran Struk Bukti Pengeluaran > Rp 2.000.000',
                                subtitle: 'Teller/Admin wajib mengunggah foto struk/kwitansi sebelum pengajuan kas keluar dapat dikirim.',
                                value: _requireAttachmentKK,
                                onChanged: (val) {
                                  setState(() => _requireAttachmentKK = val);
                                  _markAsDirty();
                                },
                              ),
                            ],
                          ),
                        ),

                        // TAB 2: KEUANGAN & PARAMETER
                        SingleChildScrollView(
                          child: SettingSectionCard(
                            title: 'Parameter Standar Keuangan & Produk Koperasi',
                            description: 'Konfigurasi nilai standar Simpanan Pokok, Simpanan Wajib, Bunga Pinjaman, dan Denda.',
                            icon: Icons.calculate_rounded,
                            children: [
                              SettingInputField(
                                label: 'Nominal Simpanan Pokok Standard (Sekali Bayar)',
                                hint: '500000',
                                prefixText: 'Rp',
                                controller: _simpananPokokController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _markAsDirty(),
                              ),
                              SettingInputField(
                                label: 'Nominal Simpanan Wajib Standard (Bulanan)',
                                hint: '50000',
                                prefixText: 'Rp',
                                controller: _simpananWajibController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _markAsDirty(),
                              ),
                              SettingInputField(
                                label: 'Suku Bunga Pinjaman Piutang Standard (Per Bulan)',
                                hint: '1.5',
                                suffixText: '% / Bulan',
                                controller: _bungaPinjamanController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _markAsDirty(),
                              ),
                              SettingInputField(
                                label: 'Denda Keterlambatan Angsuran (Per Bulan)',
                                hint: '0.5',
                                suffixText: '% / Bulan',
                                controller: _dendaLateController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _markAsDirty(),
                              ),
                            ],
                          ),
                        ),

                        // TAB 3: MANAJEMEN USER OPERATOR
                        SingleChildScrollView(
                          child: SettingSectionCard(
                            title: 'Daftar Akun Operator Admin & Teller',
                            description: 'Kelola status aktif/non-aktif dan reset password petugas teller/admin.',
                            icon: Icons.admin_panel_settings_rounded,
                            children: [
                              for (int i = 0; i < _settings.operatorUsers.length; i++) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primaryBackground,
                                        child: Text(
                                          _settings.operatorUsers[i].name[0],
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_settings.operatorUsers[i].name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                                            Text('${_settings.operatorUsers[i].role} • ${_settings.operatorUsers[i].email}', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _settings.operatorUsers[i].isActive,
                                        activeTrackColor: AppColors.primary,
                                        onChanged: (val) {
                                          setState(() {
                                            _settings.operatorUsers[i].isActive = val;
                                          });
                                          _markAsDirty();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // TAB 4: PROFIL KOPERASI & KEAMANAN
                        SingleChildScrollView(
                          child: SettingSectionCard(
                            title: 'Profil Koperasi & Keamanan Akun Ketua',
                            description: 'Informasi legalitas lembaga koperasi dan autentikasi keamanan ganda.',
                            icon: Icons.security_rounded,
                            children: [
                              SettingInputField(
                                label: 'Nama Resmi Lembaga Koperasi',
                                hint: 'Koperasi CUM Pelita',
                                controller: _koperasiNameController,
                                onChanged: (val) => _markAsDirty(),
                              ),
                              SettingInputField(
                                label: 'Nomor Badan Hukum / Legalitas AHU',
                                hint: 'AHU-0012345.AH.01.26',
                                controller: _legalNoController,
                                onChanged: (val) => _markAsDirty(),
                              ),
                              SettingInputField(
                                label: 'Alamat Kantor Pusat',
                                hint: 'Jl. Jend. Sudirman No. 42...',
                                controller: _addressController,
                                onChanged: (val) => _markAsDirty(),
                              ),
                              SettingToggleTile(
                                title: 'Aktifkan Autentikasi 2-Faktor (2FA Security)',
                                subtitle: 'Setiap aksi persetujuan ACC bernilai > Rp 10.000.000 mewajibkan verifikasi PIN 6 digit.',
                                value: _enable2FA,
                                onChanged: (val) {
                                  setState(() => _enable2FA = val);
                                  _markAsDirty();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
