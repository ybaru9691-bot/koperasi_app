/// ⚙️ Model Data Konfigurasi & Pengaturan Sistem Koperasi (Ketua View)
class SystemSettingModel {
  // Tab 1: Kebijakan Transaksi & Limit
  final double autoApprovalLimitKM;
  final double manualApprovalLimitKK;
  final bool enableAutoApprovalSmallKM;
  final bool requireAttachmentForLargeKK;

  // Tab 2: Keuangan & Parameter
  final double simpananPokokDefault;
  final double simpananWajibDefault;
  final double sukuBungaPinjamanMonthly;
  final double dendaKeterlambatanMonthly;

  // Tab 3: Manajemen User Operator
  final List<UserOperatorModel> operatorUsers;

  // Tab 4: Profil Koperasi & Keamanan
  final String koperasiName;
  final String legalNo;
  final String address;
  final String phone;
  final bool enable2FAAuth;

  SystemSettingModel({
    required this.autoApprovalLimitKM,
    required this.manualApprovalLimitKK,
    required this.enableAutoApprovalSmallKM,
    required this.requireAttachmentForLargeKK,
    required this.simpananPokokDefault,
    required this.simpananWajibDefault,
    required this.sukuBungaPinjamanMonthly,
    required this.dendaKeterlambatanMonthly,
    required this.operatorUsers,
    required this.koperasiName,
    required this.legalNo,
    required this.address,
    required this.phone,
    required this.enable2FAAuth,
  });

  factory SystemSettingModel.fromJson(Map<String, dynamic> json) {
    final usersList = (json['operator_users'] as List<dynamic>?)
            ?.map((u) => UserOperatorModel.fromJson(Map<String, dynamic>.from(u)))
            .toList() ??
        [];

    return SystemSettingModel(
      autoApprovalLimitKM: (json['auto_approval_limit_km'] as num?)?.toDouble() ?? 1000000.0,
      manualApprovalLimitKK: (json['manual_approval_limit_kk'] as num?)?.toDouble() ?? 5000000.0,
      enableAutoApprovalSmallKM: json['enable_auto_approval_small_km'] as bool? ?? true,
      requireAttachmentForLargeKK: json['require_attachment_large_kk'] as bool? ?? true,
      simpananPokokDefault: (json['simpanan_pokok_default'] as num?)?.toDouble() ?? 500000.0,
      simpananWajibDefault: (json['simpanan_wajib_default'] as num?)?.toDouble() ?? 50000.0,
      sukuBungaPinjamanMonthly: (json['suku_bunga_pinjaman_monthly'] as num?)?.toDouble() ?? 1.5,
      dendaKeterlambatanMonthly: (json['denda_keterlambatan_monthly'] as num?)?.toDouble() ?? 0.5,
      operatorUsers: usersList,
      koperasiName: json['koperasi_name'] ?? 'Koperasi CUM Pelita Duri',
      legalNo: json['legal_no'] ?? 'AHU-0012345.AH.01.26',
      address: json['address'] ?? 'Jl. Jend. Sudirman No. 42, Duri Kota, Mandau, Bengkalis',
      phone: json['phone'] ?? '0765-8901234',
      enable2FAAuth: json['enable_2fa_auth'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auto_approval_limit_km': autoApprovalLimitKM,
      'manual_approval_limit_kk': manualApprovalLimitKK,
      'enable_auto_approval_small_km': enableAutoApprovalSmallKM,
      'require_attachment_large_kk': requireAttachmentForLargeKK,
      'simpanan_pokok_default': simpananPokokDefault,
      'simpanan_wajib_default': simpananWajibDefault,
      'suku_bunga_pinjaman_monthly': sukuBungaPinjamanMonthly,
      'denda_keterlambatan_monthly': dendaKeterlambatanMonthly,
      'operator_users': operatorUsers.map((u) => u.toJson()).toList(),
      'koperasi_name': koperasiName,
      'legal_no': legalNo,
      'address': address,
      'phone': phone,
      'enable_2fa_auth': enable2FAAuth,
    };
  }

  static SystemSettingModel getDefaultSettings() {
    return SystemSettingModel(
      autoApprovalLimitKM: 1000000,
      manualApprovalLimitKK: 5000000,
      enableAutoApprovalSmallKM: true,
      requireAttachmentForLargeKK: true,
      simpananPokokDefault: 500000,
      simpananWajibDefault: 50000,
      sukuBungaPinjamanMonthly: 1.5,
      dendaKeterlambatanMonthly: 0.5,
      operatorUsers: [
        UserOperatorModel(id: '1', name: 'Rina Simanjuntak', role: 'Teller 1', email: 'teller1@cumpelita.com', isActive: true),
        UserOperatorModel(id: '2', name: 'Agus Nainggolan', role: 'Teller 2', email: 'teller2@cumpelita.com', isActive: true),
        UserOperatorModel(id: '3', name: 'Desi Marlina', role: 'Admin Kasir', email: 'admin@cumpelita.com', isActive: true),
      ],
      koperasiName: 'Koperasi Credit Union Pelita (CUM Pelita)',
      legalNo: 'AHU-0012345.AH.01.26',
      address: 'Jl. Jend. Sudirman No. 42, Duri Kota, Mandau',
      phone: '0765-8901234',
      enable2FAAuth: false,
    );
  }
}

class UserOperatorModel {
  final String id;
  final String name;
  final String role;
  final String email;
  bool isActive;

  UserOperatorModel({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.isActive,
  });

  factory UserOperatorModel.fromJson(Map<String, dynamic> json) {
    return UserOperatorModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'email': email,
      'is_active': isActive,
    };
  }
}
