import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// 👤 Data Model Anggota Koperasi CUM Pelita — Selaras dengan migration Laravel terbaru
/// Kolom DB: member_number, nik, name, place_of_birth, date_of_birth, gender,
///           phone, occupation, education, family_status, church_sector, address,
///           heir_name, heir_relationship, heir_place_of_birth, heir_date_of_birth, heir_address,
///           principal_savings, mandatory_savings, voluntary_savings, grief_fund, status
class MemberModel {
  // ── Identitas ──────────────────────────────────────────────
  final String id;
  final String memberNumber;  // member_number
  final String nik;
  final String name;
  final String? placeOfBirth;  // place_of_birth
  final String? dateOfBirth;   // date_of_birth  (YYYY-MM-DD)
  final String gender;
  final String phone;
  final String occupation;    // occupation
  final String education;
  final String familyStatus;  // family_status
  final String churchSector;  // church_sector
  final String address;
  final String email;         // opsional – bisa kosong
  final String status;
  final bool hasBukuBiru;
  final bool hasBukuPutih;
  final String bukuPutihNumber;

  // ── Ahli Waris ─────────────────────────────────────────────
  final String heirName;          // heir_name
  final String heirRelationship;  // heir_relationship
  final String heirPlaceOfBirth;  // heir_place_of_birth
  final String heirDateOfBirth;   // heir_date_of_birth
  final String heirAddress;       // heir_address

  // ── Simpanan (Dinamis dari API) ─────────────────────────────
  final int principalSavings;   // principal_savings  (SP)
  final int mandatorySavings;   // mandatory_savings  (SW)
  final int voluntarySavings;   // voluntary_savings  (SS)
  final int griefFund;          // grief_fund         (Dana Duka)
  final int totalSaldo;         // = SP + SW + SS

  // ── Alias lama supaya layar lain tidak error ────────────────
  String get memberNo        => memberNumber;
  String get church          => churchSector;
  String? get tempatLahir    => placeOfBirth;
  String? get tanggalLahir   => dateOfBirth;
  String get namaAhliWaris   => heirName;
  String get hubunganAhliWaris => heirRelationship;
  String get alamatAhliWaris => heirAddress;
  String get heirNameAlias   => heirName;
  String? get bukuPutihNo    => (bukuPutihNumber != '-' && bukuPutihNumber.isNotEmpty && bukuPutihNumber != 'null' && !bukuPutihNumber.startsWith('{')) ? bukuPutihNumber : null;
  int    get simpananPokok   => principalSavings;
  int    get simpananWajib   => mandatorySavings;
  int    get simpananSukarela => voluntarySavings;

  // ── Avatar ─────────────────────────────────────────────────
  final Color avatarBgColor;
  final Color avatarTextColor;

  const MemberModel({
    required this.id,
    required this.memberNumber,
    required this.nik,
    required this.name,
    this.placeOfBirth,
    this.dateOfBirth,
    this.gender          = '-',
    required this.phone,
    this.occupation      = '-',
    this.education       = '-',
    this.familyStatus    = '-',
    required this.churchSector,
    this.address         = '-',
    this.email           = '-',
    this.status          = 'aktif',
    this.hasBukuBiru     = true,
    this.hasBukuPutih    = true,
    this.bukuPutihNumber = '-',
    this.heirName        = '-',
    this.heirRelationship = '-',
    this.heirPlaceOfBirth = '-',
    this.heirDateOfBirth  = '-',
    this.heirAddress      = '-',
    this.principalSavings = 0,
    this.mandatorySavings = 0,
    this.voluntarySavings = 0,
    this.griefFund        = 0,
    this.totalSaldo       = 0,
    this.avatarBgColor   = const Color(0xFFE0F2FE),
    this.avatarTextColor = AppColors.adminNavy,
  });

  // ────────────────────────────────────────────────────────────
  // HELPERS PARSING BULLETPROOF (aman dari null / wrong-type)
  // ────────────────────────────────────────────────────────────

  /// Konversi apa pun → int tanpa melempar exception, aman terhadap string desimal/angka
  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final cleanStr = v.toString().trim().replaceAll(',', '');
    return num.tryParse(cleanStr)?.toInt() ?? int.tryParse(cleanStr) ?? fallback;
  }

  /// Konversi apa pun → String tanpa melempar exception
  static String _parseStr(dynamic v, [String fallback = '-']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isNotEmpty ? s : fallback;
  }

  /// Konversi apa pun → String? tanpa melempar exception (mengembalikan null jika kosong / '-')
  static String? _parseNullableStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == '-' || s == 'null') return null;
    return s;
  }

  /// Helper parser khusus tanggal (YYYY-MM-DD), membersihkan timestamp ISO-8601 & SQL
  static String? parseDateOnly(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty || str == '-' || str == 'null') return null;

    // Jika backend mengirim format ISO-8601 (T) atau SQL timestamp (spasi), ambil tanggalnya
    String datePart = str;
    if (datePart.contains('T')) {
      datePart = datePart.split('T')[0].trim();
    } else if (datePart.contains(' ')) {
      datePart = datePart.split(' ')[0].trim();
    }

    try {
      final dt = DateTime.tryParse(datePart);
      if (dt != null) {
        return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      }
    } catch (_) {}

    return datePart.isNotEmpty ? datePart : null;
  }

  // ────────────────────────────────────────────────────────────
  // FACTORY fromJson — Support nested 'simpanan' & 'ahli_waris'
  //                    serta key flat dari response Laravel
  // ────────────────────────────────────────────────────────────
  factory MemberModel.fromJson(Map<String, dynamic> json) {
    // Nested objek simpanan (opsional)
    final Map<String, dynamic>? sObj =
        json['simpanan'] is Map<String, dynamic> ? json['simpanan'] as Map<String, dynamic> : null;

    // Nested objek ahli_waris (opsional)
    final Map<String, dynamic>? wObj =
        json['ahli_waris'] is Map<String, dynamic> ? json['ahli_waris'] as Map<String, dynamic> : null;

    // ── Simpanan — prioritas: nested → flat → 0 ──────────────
    final int sp = _parseInt(
      sObj?['principal_savings'] ?? sObj?['simpanan_pokok'] ??
      json['principal_savings'] ?? json['simpanan_pokok'],
    );
    final int sw = _parseInt(
      sObj?['mandatory_savings'] ?? sObj?['simpanan_wajib'] ??
      json['mandatory_savings'] ?? json['simpanan_wajib'],
    );
    final int ss = _parseInt(
      sObj?['voluntary_savings'] ?? sObj?['simpanan_sukarela'] ??
      json['voluntary_savings'] ?? json['simpanan_sukarela'],
    );
    final int gf = _parseInt(
      sObj?['grief_fund'] ?? sObj?['dana_duka'] ??
      json['grief_fund'] ?? json['dana_duka'] ?? json['social_fund'],
    );
    final int total = _parseInt(
      sObj?['total_saldo'] ?? json['total_savings'] ?? json['total_saldo'],
      sp + sw + ss,
    );

    // ── Ahli Waris — prioritas: nested → flat ────────────────
    final String heirName = _parseStr(
      wObj?['nama'] ?? wObj?['heir_name'] ??
      json['heir_name'] ?? json['nama_ahli_waris'],
    );
    final String heirRel = _parseStr(
      wObj?['hubungan'] ?? wObj?['heir_relationship'] ??
      json['heir_relationship'] ?? json['heir_relation'] ?? json['hubungan_ahli_waris'],
    );
    final String heirPob = _parseStr(
      wObj?['tempat_lahir'] ?? wObj?['heir_place_of_birth'] ??
      json['heir_place_of_birth'],
    );
    final String heirDob = parseDateOnly(
      wObj?['tanggal_lahir'] ?? wObj?['heir_date_of_birth'] ??
      json['heir_date_of_birth'] ?? json['heir_birth_date'] ?? json['tanggal_lahir_ahli_waris'],
    ) ?? '-';
    final String heirAddr = _parseStr(
      wObj?['alamat'] ?? wObj?['heir_address'] ??
      json['heir_address'] ?? json['alamat_ahli_waris'],
    );

    // ── Identitas ─────────────────────────────────────────────
    final String rawPhone = _parseStr(
      json['phone'] ?? json['no_hp'] ?? json['no_handphone'],
      '',
    );
    final String rawEmail = _parseStr(json['email'], '-');

    final String memberNumber = _parseStr(
      json['member_number'] ?? json['member_no'] ?? json['no_anggota'],
      json['id']?.toString() ?? '-',
    );

    final bool hasBiru = json['has_buku_biru'] == null
        ? (sp > 0 || sw > 0 || json['buku_biru'] != false)
        : (json['has_buku_biru'] == true || json['has_buku_biru'] == 1 || json['has_buku_biru'] == '1');
    final bool hasPutih = json['has_buku_putih'] == null
        ? true
        : (json['has_buku_putih'] == true || json['has_buku_putih'] == 1 || json['has_buku_putih'] == '1');

    final dynamic rawBpVal = json['buku_putih_no'] ??
                             json['no_rekening_buku_putih'] ??
                             json['buku_putih_account_no'] ??
                             json['buku_putih_number'] ??
                             json['no_buku_putih'] ??
                             json['buku_putih_rek'] ??
                             json['rekening_buku_putih'];
    String rawBukuPutih = '-';
    if (rawBpVal != null && rawBpVal is! Map && rawBpVal is! List) {
      final s = rawBpVal.toString().trim();
      if (s.isNotEmpty && s != '-' && s != 'null' && !s.startsWith('{')) {
        rawBukuPutih = s;
      }
    }

    return MemberModel(
      id:             json['id']?.toString() ?? '',
      memberNumber:   memberNumber,
      nik:            _parseStr(json['nik'] ?? json['no_ktp']),
      name:           _parseStr(json['name'] ?? json['nama'], 'Tanpa Nama'),
      placeOfBirth:   _parseNullableStr(json['place_of_birth'] ?? json['tempat_lahir'] ?? json['birth_place'] ?? json['tempatLahir']),
      dateOfBirth:    parseDateOnly(json['date_of_birth'] ?? json['tanggal_lahir'] ?? json['birth_date'] ?? json['tanggalLahir']),
      gender:         _parseStr(json['gender']),
      phone:          rawPhone.isNotEmpty && rawPhone != '-' ? rawPhone : '',
      occupation:     _parseStr(json['occupation'] ?? json['job'] ?? json['pekerjaan']),
      education:      _parseStr(json['education'] ?? json['pendidikan']),
      familyStatus:   _parseStr(json['family_status'] ?? json['status_keluarga']),
      churchSector:   _parseStr(
        json['church_sector'] ?? json['church_unit'] ?? json['church'] ?? json['address'],
        'HKBP Dame Duri',
      ),
      address:        _parseStr(json['address'] ?? json['alamat']),
      email:          rawEmail.contains('@') ? rawEmail : '-',
      status:         _parseStr(json['status'], 'aktif'),
      hasBukuBiru:     hasBiru,
      hasBukuPutih:    hasPutih,
      bukuPutihNumber: rawBukuPutih != '-' && rawBukuPutih.isNotEmpty ? rawBukuPutih : '-',
      heirName:       heirName,
      heirRelationship: heirRel,
      heirPlaceOfBirth: heirPob,
      heirDateOfBirth:  heirDob,
      heirAddress:    heirAddr,
      principalSavings: sp,
      mandatorySavings: sw,
      voluntarySavings: ss,
      griefFund:        gf,
      totalSaldo:       total > 0 ? total : (sp + sw + ss),
      avatarBgColor:   const Color(0xFFE0F2FE),
      avatarTextColor: const Color(0xFF0369A1),
    );
  }

  // ────────────────────────────────────────────────────────────
  // toJson — key selaras dengan kolom DB Laravel terbaru
  // ────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':               id,
    'member_number':    memberNumber,
    'nik':              nik,
    'name':             name,
    'place_of_birth':   placeOfBirth,
    'tempat_lahir':     tempatLahir,
    'date_of_birth':    dateOfBirth,
    'tanggal_lahir':    tanggalLahir,
    'gender':           gender,
    'phone':            phone,
    'occupation':       occupation,
    'education':        education,
    'family_status':    familyStatus,
    'church_sector':    churchSector,
    'address':          address,
    'email':            email,
    'status':           status,
    'has_buku_biru':    hasBukuBiru,
    'has_buku_putih':   hasBukuPutih,
    'buku_putih_no':    bukuPutihNumber,
    'no_rekening_buku_putih': bukuPutihNumber,
    'buku_putih_account_no': bukuPutihNumber,
    'heir_name':        heirName,
    'heir_relationship': heirRelationship,
    'heir_place_of_birth': heirPlaceOfBirth,
    'heir_date_of_birth':  heirDateOfBirth,
    'heir_address':     heirAddress,
    'principal_savings': principalSavings,
    'mandatory_savings': mandatorySavings,
    'voluntary_savings': voluntarySavings,
    'grief_fund':       griefFund,
  };

  // ────────────────────────────────────────────────────────────
  // Computed properties
  // ────────────────────────────────────────────────────────────

  /// Inisial dua huruf  ("Reslina Nainggolan" → "RN")
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'AK';
  }
}
