/// 👤 Model Data Anggota Admin
class MemberDataModel {
  final String id;
  final String memberNumber;
  final String nik;
  final String name;
  final String phone;
  final String address;
  final String joinedDate;
  final double totalSavings;
  final double totalLoans;
  final String status; // 'aktif', 'non-aktif'
  final bool hasBukuBiru;
  final String bukuPutihNumber;

  MemberDataModel({
    required this.id,
    required this.memberNumber,
    required this.nik,
    required this.name,
    required this.phone,
    required this.address,
    required this.joinedDate,
    required this.totalSavings,
    required this.totalLoans,
    required this.status,
    this.hasBukuBiru = true,
    this.bukuPutihNumber = '-',
  });

  String? get bukuPutihNo => (bukuPutihNumber != '-' && bukuPutihNumber.isNotEmpty && bukuPutihNumber != 'null' && !bukuPutihNumber.startsWith('{')) ? bukuPutihNumber : null;

  factory MemberDataModel.fromJson(Map<String, dynamic> json) {
    final bool hasBiru = json['has_buku_biru'] == null
        ? (json['buku_biru'] != false)
        : (json['has_buku_biru'] == true || json['has_buku_biru'] == 1 || json['has_buku_biru'] == '1');

    final dynamic rawBp = json['buku_putih_no'] ??
                          json['no_rekening_buku_putih'] ??
                          json['buku_putih_account_no'] ??
                          json['buku_putih_number'] ??
                          json['no_buku_putih'] ??
                          json['buku_putih_rek'] ??
                          json['rekening_buku_putih'];
    String bp = '-';
    if (rawBp != null && rawBp is! Map && rawBp is! List) {
      final s = rawBp.toString().trim();
      if (s.isNotEmpty && s != '-' && s != 'null' && !s.startsWith('{')) {
        bp = s;
      }
    }

    return MemberDataModel(
      id: json['id']?.toString() ?? '',
      memberNumber: (json['member_number'] ?? json['no_buku'] ?? json['id'])?.toString() ?? '',
      nik: json['nik'] ?? json['no_anggota'] ?? '',
      name: json['name'] ?? json['nama'] ?? '',
      phone: json['phone'] ?? json['no_hp'] ?? '',
      address: json['address'] ?? json['alamat'] ?? '',
      joinedDate: json['joinedDate'] ?? json['created_at'] ?? '',
      totalSavings: (json['totalSavings'] is num)
          ? (json['totalSavings'] as num).toDouble()
          : (num.tryParse(json['totalSavings']?.toString().replaceAll(',', '').trim() ?? '')?.toDouble() ?? 0.0),
      totalLoans: (json['totalLoans'] is num)
          ? (json['totalLoans'] as num).toDouble()
          : (num.tryParse(json['totalLoans']?.toString().replaceAll(',', '').trim() ?? '')?.toDouble() ?? 0.0),
      status: json['status'] ?? 'aktif',
      hasBukuBiru: hasBiru,
      bukuPutihNumber: bp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_number': memberNumber,
      'nik': nik,
      'name': name,
      'buku_putih_no': bukuPutihNumber,
      'phone': phone,
      'address': address,
      'joinedDate': joinedDate,
      'totalSavings': totalSavings,
      'totalLoans': totalLoans,
      'status': status,
    };
  }
}
