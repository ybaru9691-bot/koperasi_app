/// 👤 Model Data Pengguna / Anggota / Admin
class UserModel {
  final int? id;
  final String name;
  final String email;
  final String role; // 'admin', 'ketua', 'manajer', 'anggota'
  final String? noAnggota;
  final String? noHp;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.role,
    this.noAnggota,
    this.noHp,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      name: json['name'] ?? json['nama'] ?? '',
      email: json['email'] ?? '',
      role: (json['role'] ?? 'anggota').toString().toLowerCase(),
      noAnggota: json['no_anggota'] ?? json['nik'],
      noHp: json['no_hp'] ?? json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'no_anggota': noAnggota,
      'no_hp': noHp,
    };
  }
}
