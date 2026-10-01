//Model Data Persetujuan / Approval Transaksi Ketua Koperasi CUM Pelita
class PendingApprovalModel {
  final String id;
  final String refCode; // 'KM 5231' / 'KK 1045'
  final String date;
  final String memberName;
  final String memberNo;
  final String adminOperator;
  final String category;
  final String type; // 'KM' (Kas Masuk), 'KK' (Kas Keluar), 'Pinjaman'
  final double amount;
  String status; // 'pending', 'disetujui', 'ditolak'
  final String notes;
  final String? rejectionReason;
  final String? attachmentUrl;

  PendingApprovalModel({
    required this.id,
    required this.refCode,
    required this.date,
    required this.memberName,
    required this.memberNo,
    required this.adminOperator,
    required this.category,
    required this.type,
    required this.amount,
    required this.status,
    required this.notes,
    this.rejectionReason,
    this.attachmentUrl,
  });

  factory PendingApprovalModel.fromJson(Map<String, dynamic> json) {
    return PendingApprovalModel(
      id: json['id']?.toString() ?? '',
      refCode: json['ref_code'] ?? json['no_ref'] ?? '',
      date: json['date'] ?? json['created_at'] ?? '',
      memberName: json['member_name'] ?? json['pemohon'] ?? '',
      memberNo: json['member_no'] ?? json['no_anggota'] ?? '',
      adminOperator: json['admin_operator'] ?? json['petugas'] ?? 'Admin Pelita',
      category: json['category'] ?? json['kategori'] ?? '',
      type: json['type'] ?? json['jenis'] ?? 'KM',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      notes: json['notes'] ?? json['keterangan'] ?? '',
      rejectionReason: json['rejection_reason'] ?? json['alasan_penolakan'],
      attachmentUrl: json['attachment_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ref_code': refCode,
      'date': date,
      'member_name': memberName,
      'member_no': memberNo,
      'admin_operator': adminOperator,
      'category': category,
      'type': type,
      'amount': amount,
      'status': status,
      'notes': notes,
      'rejection_reason': rejectionReason,
      'attachment_url': attachmentUrl,
    };
  }

  static List<PendingApprovalModel> getDummyApprovals() {
    return [
      PendingApprovalModel(
        id: '1',
        refCode: 'PJ-2026-084',
        date: '30 Juli 2026, 10:15',
        memberName: 'St. M. Simanjuntak',
        memberNo: '2562',
        adminOperator: 'Teller 1 (Rina S.)',
        category: 'Pinjaman Piutang S-3 (Kredit Usaha Sembako)',
        type: 'Pinjaman',
        amount: 25000000,
        status: 'pending',
        notes: 'Pengajuan modal kerja perluasan toko sembako Duri dengan agunan BPKB.',
        attachmentUrl: 'assets/images/bukti_transaksi_sample.png',
      ),
      PendingApprovalModel(
        id: '2',
        refCode: 'KK-2026-042',
        date: '29 Juli 2026, 14:30',
        memberName: 'Kas Operasional Admin',
        memberNo: 'OFFICE',
        adminOperator: 'Admin Pelita (Teller 2)',
        category: 'Kas Keluar > 10 Jt (Upgrade Perangkat Komputer Server)',
        type: 'KK',
        amount: 15500000,
        status: 'pending',
        notes: 'Pengadaan PC Server dan UPS Backup Teller Kasir Koperasi.',
        attachmentUrl: 'assets/images/bukti_transaksi_sample.png',
      ),
      PendingApprovalModel(
        id: '3',
        refCode: 'PJ-2026-085',
        date: '28 Juli 2026, 11:20',
        memberName: 'Farida Suzana',
        memberNo: '2563',
        adminOperator: 'Bendahara Koperasi',
        category: 'Pinjaman Piutang S-2 (Biaya Pendidikan Anak)',
        type: 'Pinjaman',
        amount: 10000000,
        status: 'pending',
        notes: 'Pembayaran UKT semester ganjil perguruan tinggi.',
      ),
      PendingApprovalModel(
        id: '4',
        refCode: 'KM-2026-523',
        date: '27 Juli 2026, 09:10',
        memberName: 'Reslina Nainggolan',
        memberNo: '2562',
        adminOperator: 'Teller 1 (Rina S.)',
        category: 'Pelunasan Khusus Piutang Pinjaman',
        type: 'KM',
        amount: 12500000,
        status: 'disetujui',
        notes: 'Pelunasan dipercepat piutang pinjaman periode 2025.',
      ),
      PendingApprovalModel(
        id: '5',
        refCode: 'KK-2026-039',
        date: '25 Juli 2026, 16:45',
        memberName: 'Budi Santoso',
        memberNo: '2571',
        adminOperator: 'Admin Pelita (Teller 2)',
        category: 'Pencairan Simpanan Sukarela Darurat',
        type: 'KK',
        amount: 4500000,
        status: 'ditolak',
        notes: 'Penarikan dana simpanan sukarela via counter teller.',
        rejectionReason: 'Persyaratan kelengkapan formulir penarikan belum ditandatangani basah oleh anggota.',
      ),
    ];
  }
}
