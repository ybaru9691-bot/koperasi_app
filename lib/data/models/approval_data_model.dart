/// 📝 Model Data Pengajuan ACC / Persetujuan Ketua & Admin
class ApprovalDataModel {
  final String id;
  final String applicant;
  final String memberNo;
  final String category;
  final String type; // 'pinjaman', 'kas_keluar'
  final String date;
  final double amount;
  String status; // 'menunggu', 'disetujui', 'ditolak'
  final String notes;

  ApprovalDataModel({
    required this.id,
    required this.applicant,
    required this.memberNo,
    required this.category,
    required this.type,
    required this.date,
    required this.amount,
    required this.status,
    required this.notes,
  });

  factory ApprovalDataModel.fromJson(Map<String, dynamic> json) {
    final member = json['member'] ?? {};
    final applicantName = member['name'] ?? member['full_name'] ?? json['applicant'] ?? json['nama_anggota'] ?? json['pemohon'] ?? json['nama'] ?? '';
    final mNo = member['nik'] ?? member['no_anggota'] ?? json['memberNo'] ?? json['no_anggota'] ?? '';
    final desc = json['description'] ?? json['notes'] ?? json['keterangan'] ?? '';

    // Map Laravel transaction types to readable categories
    final category = json['category'] ?? json['description'] ?? json['kategori'] ?? '';
    final rawType = (json['type'] ?? json['jenis'] ?? 'pinjaman').toString().toLowerCase();
    final type = (rawType == 'withdrawal' || rawType == 'kas_keluar' || rawType == 'out') ? 'kas_keluar' : 'pinjaman';

    return ApprovalDataModel(
      id: (json['id'] ?? json['no_ref'] ?? json['id_pengajuan'] ?? '').toString(),
      applicant: applicantName,
      memberNo: mNo,
      category: category.isNotEmpty ? category : 'Mutasi Kas Koperasi',
      type: type,
      date: json['date'] ?? json['transaction_date'] ?? json['tanggal'] ?? json['created_at'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? (json['nominal'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'menunggu',
      notes: desc,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'applicant': applicant,
      'memberNo': memberNo,
      'category': category,
      'type': type,
      'date': date,
      'amount': amount,
      'status': status,
      'notes': notes,
    };
  }

  /// Utility Helper Konversi Safe Mapping untuk List Response API / Mock Data
  static List<ApprovalDataModel> fromJsonList(dynamic jsonList) {
    if (jsonList is! List) return [];
    return jsonList
        .map((item) {
          if (item is ApprovalDataModel) return item;
          if (item is Map<String, dynamic>) {
            return ApprovalDataModel.fromJson(item);
          }
          if (item is Map) {
            return ApprovalDataModel.fromJson(Map<String, dynamic>.from(item));
          }
          return null;
        })
        .whereType<ApprovalDataModel>()
        .toList();
  }
}
