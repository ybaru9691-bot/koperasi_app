/// Model Data Pengguna / Anggota Koperasi
class UserModel {
  final String name;
  final String memberId;
  final String nik;
  final String phoneNumber;
  final String address;
  final String status;
  final double estimatedShu;

  const UserModel({
    required this.name,
    required this.memberId,
    required this.nik,
    required this.phoneNumber,
    required this.address,
    required this.status,
    required this.estimatedShu,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] as String? ?? 'Budi Santoso',
      memberId: json['member_id'] as String? ?? 'ANGGOTA #882049',
      nik: json['nik'] as String? ?? '1471081507920003',
      phoneNumber: json['phone_number'] as String? ?? '0812-7654-7189',
      address: json['address'] as String? ?? 'Jl. Sudirman No. 45, Duri',
      status: json['status'] as String? ?? 'Aktif',
      estimatedShu: (json['estimated_shu'] as num? ?? 1450000.00).toDouble(),
    );
  }
}
