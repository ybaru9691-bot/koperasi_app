/// 📜 MODEL ACTIVITY LOG (AUDIT TRAIL / AUDIT & CONTROL)
class ActivityLogModel {
  final String id;
  final String userId;
  final String userName;
  final String userRole; // 'ketua', 'manajer', 'admin', 'teller'
  final String action; // 'CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT'
  final String module; // 'Anggota', 'Simpanan', 'Pinjaman', 'System', 'Auth'
  final String description;
  final Map<String, dynamic>? properties; // {'old': {...}, 'new': {...}}
  final String ipAddress;
  final String userAgent;
  final String createdAt;

  ActivityLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.module,
    required this.description,
    this.properties,
    required this.ipAddress,
    required this.userAgent,
    required this.createdAt,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    return ActivityLogModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name'] ?? json['user']?['name'] ?? 'System',
      userRole: json['user_role'] ?? json['user']?['role'] ?? 'admin',
      action: (json['action'] ?? 'LOG').toString().toUpperCase(),
      module: json['module'] ?? 'System',
      description: json['description'] ?? '',
      properties: json['properties'] is Map<String, dynamic>
          ? json['properties'] as Map<String, dynamic>
          : null,
      ipAddress: json['ip_address'] ?? '127.0.0.1',
      userAgent: json['user_agent'] ?? 'Browser',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'action': action,
      'module': module,
      'description': description,
      'properties': properties,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt,
    };
  }

  /// Map Data Lama (Old Values)
  Map<String, dynamic>? get oldValues {
    if (properties != null && properties!['old'] is Map<String, dynamic>) {
      return properties!['old'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Map Data Baru (New Values)
  Map<String, dynamic>? get newValues {
    if (properties != null && properties!['new'] is Map<String, dynamic>) {
      return properties!['new'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Dummy Data Repository untuk Pengujian Audit Logs UI
  static List<ActivityLogModel> getDummyLogs() {
    return [
      ActivityLogModel(
        id: 'LOG-1008',
        userId: 'U-001',
        userName: 'St. M. Simanjuntak',
        userRole: 'ketua',
        action: 'UPDATE',
        module: 'System',
        description: 'Memperbarui batas limit auto-approval Kas Masuk dari Rp 500.000 menjadi Rp 1.000.000',
        properties: {
          'old': {'auto_approval_km_limit': 500000, 'updated_by': 'St. M. Simanjuntak'},
          'new': {'auto_approval_km_limit': 1000000, 'updated_by': 'St. M. Simanjuntak'},
        },
        ipAddress: '192.168.1.45',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        createdAt: '31/07/2026 09:15',
      ),
      ActivityLogModel(
        id: 'LOG-1007',
        userId: 'U-003',
        userName: 'Teller Rina S.',
        userRole: 'admin',
        action: 'CREATE',
        module: 'Simpanan',
        description: 'Mencatat setoran Kas Masuk (KM-2026-104) Simpanan Wajib Rp 50.000 atas nama Ibu Maria',
        properties: {
          'new': {
            'ref_no': 'KM-2026-104',
            'member_name': 'Ibu Maria',
            'category': 'Simpanan Wajib',
            'amount': 50000,
          },
        },
        ipAddress: '192.168.1.12',
        userAgent: 'Chrome 126.0 (Windows)',
        createdAt: '31/07/2026 08:42',
      ),
      ActivityLogModel(
        id: 'LOG-1006',
        userId: 'U-001',
        userName: 'St. M. Simanjuntak',
        userRole: 'ketua',
        action: 'UPDATE',
        module: 'Pinjaman',
        description: 'Menyetujui (ACC) Pengajuan Kredit Usaha #PJ-2026-084 sebesar Rp 25.000.000',
        properties: {
          'old': {'status': 'PENDING_APPROVAL'},
          'new': {'status': 'APPROVED', 'approved_at': '31/07/2026 08:30'},
        },
        ipAddress: '192.168.1.45',
        userAgent: 'Safari/537.36 (macOS)',
        createdAt: '31/07/2026 08:30',
      ),
      ActivityLogModel(
        id: 'LOG-1005',
        userId: 'U-002',
        userName: 'Admin Operasional',
        userRole: 'admin',
        action: 'CREATE',
        module: 'Anggota',
        description: 'Pendaftaran Anggota Baru #2575 atas name Pak Budi Tampubolon',
        properties: {
          'new': {
            'member_no': '2575',
            'name': 'Budi Tampubolon',
            'nik': '1403011204850003',
            'church': 'HKBP Dame Duri',
          },
        },
        ipAddress: '192.168.1.10',
        userAgent: 'Chrome 126.0 (Windows)',
        createdAt: '31/07/2026 08:10',
      ),
      ActivityLogModel(
        id: 'LOG-1004',
        userId: 'U-001',
        userName: 'St. M. Simanjuntak',
        userRole: 'ketua',
        action: 'LOGIN',
        module: 'Auth',
        description: 'Pengguna berhasil melakukan otentikasi login masuk sistem',
        ipAddress: '192.168.1.45',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0)',
        createdAt: '31/07/2026 08:00',
      ),
      ActivityLogModel(
        id: 'LOG-1003',
        userId: 'U-003',
        userName: 'Teller Rina S.',
        userRole: 'admin',
        action: 'DELETE',
        module: 'Simpanan',
        description: 'Pembatalan/Hapus Draf Kas Masuk (KM-2026-099) karena keteledoran nominal',
        properties: {
          'old': {
            'ref_no': 'KM-2026-099',
            'amount': 500000,
            'reason': 'Keteledoran input nominal teller',
          },
        },
        ipAddress: '192.168.1.12',
        userAgent: 'Chrome 126.0 (Windows)',
        createdAt: '30/07/2026 16:50',
      ),
    ];
  }
}
