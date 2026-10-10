import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/member_card.dart';

/// ✏️ LAYAR EDIT DATA ANGGOTA & RESET PIN KEAMANAN
class EditAnggotaScreen extends StatefulWidget {
  final MemberModel member;

  const EditAnggotaScreen({
    super.key,
    required this.member,
  });

  @override
  State<EditAnggotaScreen> createState() => _EditAnggotaScreenState();
}

class _EditAnggotaScreenState extends State<EditAnggotaScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _securityFormKey = GlobalKey<FormState>();

  // Profile Controllers (Inisialisasi aman di initState)
  late final TextEditingController _nikController;
  late final TextEditingController _nameController;
  late final TextEditingController _bukuPutihController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _churchController;
  TextEditingController get _churchSectorController => _churchController;

  // Data Pribadi
  late final TextEditingController _placeOfBirthController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _genderController;
  String? _selectedGender;
  late final TextEditingController _occupationController;
  late final TextEditingController _educationController;
  late final TextEditingController _familyStatusController;

  // Data Ahli Waris
  late final TextEditingController _heirNameController;
  late final TextEditingController _heirRelationshipController;
  late final TextEditingController _heirPlaceOfBirthController;
  late final TextEditingController _heirDateOfBirthController;
  late final TextEditingController _heirAddressController;

  // Security Controllers (Reset PIN 6 Digit)
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  bool _isUpdatingProfile = false;
  bool _isResettingPin = false;
  bool _isLoadingDetail = false;

  /// 🔄 Isi atau update nilai seluruh TextEditingController & dropdown dari objek MemberModel
  void _populateControllers(MemberModel member) {
    // 1. Data Profil Dasar
    if (member.nik.isNotEmpty && member.nik != '-') {
      _nikController.text = member.nik;
    }
    if (member.name.isNotEmpty && member.name != 'Tanpa Nama') {
      _nameController.text = member.name;
    }
    final String initialPhone = member.phone.isNotEmpty && member.phone != '-'
        ? member.phone
        : (member.email.contains('@') ? '' : member.email);
    if (initialPhone.isNotEmpty && initialPhone != '-') {
      _phoneController.text = initialPhone;
    }
    if (member.email.contains('@')) {
      _emailController.text = member.email;
    }
    final String bp = member.bukuPutihNo ?? (member.bukuPutihNumber != '-' ? member.bukuPutihNumber : '');
    if (bp.isNotEmpty && bp != '-' && bp != 'null') {
      _bukuPutihController.text = bp;
    }

    // 2. Data Pribadi Tambahan (Sesuai Spesifikasi Prompt)
    _placeOfBirthController.text = member.placeOfBirth ?? member.tempatLahir ?? '';
    if (_placeOfBirthController.text == '-' || _placeOfBirthController.text == 'null') {
      _placeOfBirthController.text = '';
    }

    final String? dobRaw = member.dateOfBirth ?? member.tanggalLahir;
    final String dob = (dobRaw != null && dobRaw != '-' && dobRaw != 'null')
        ? (MemberModel.parseDateOnly(dobRaw) ?? dobRaw)
        : '';
    _dateOfBirthController.text = dob;

    _occupationController.text = member.occupation ?? member.pekerjaan ?? '';
    if (_occupationController.text == '-' || _occupationController.text == 'null') {
      _occupationController.text = '';
    }

    _educationController.text = member.education ?? member.pendidikan ?? '';
    if (_educationController.text == '-' || _educationController.text == 'null') {
      _educationController.text = '';
    }

    _familyStatusController.text = member.familyStatus ?? member.statusKeluarga ?? '';
    if (_familyStatusController.text == '-' || _familyStatusController.text == 'null') {
      _familyStatusController.text = '';
    }

    _churchSectorController.text = member.churchSector ?? member.sektorGereja ?? '';
    if (_churchSectorController.text == '-' || _churchSectorController.text == 'null') {
      _churchSectorController.text = '';
    }

    _addressController.text = member.address ?? member.alamat ?? '';
    if (_addressController.text == '-' || _addressController.text == 'null') {
      _addressController.text = '';
    }

    final String g = member.gender ?? member.jenisKelamin ?? '';
    _genderController.text = g;
    if (g == 'Laki-laki' || g == 'Perempuan') {
      _selectedGender = g;
    } else if (g.toLowerCase() == 'male' || g.toLowerCase() == 'l') {
      _selectedGender = 'Laki-laki';
    } else if (g.toLowerCase() == 'female' || g.toLowerCase() == 'p') {
      _selectedGender = 'Perempuan';
    }

    // 3. Data Ahli Waris (Sesuai Spesifikasi Prompt)
    _heirNameController.text = member.heirName ?? member.namaAhliWaris ?? '';
    if (_heirNameController.text == '-' || _heirNameController.text == 'null') {
      _heirNameController.text = '';
    }

    _heirRelationshipController.text = member.heirRelationship ?? member.hubunganAhliWaris ?? '';
    if (_heirRelationshipController.text == '-' || _heirRelationshipController.text == 'null') {
      _heirRelationshipController.text = '';
    }

    _heirPlaceOfBirthController.text = member.heirPlaceOfBirth ?? member.tempatLahirAhliWaris ?? '';
    if (_heirPlaceOfBirthController.text == '-' || _heirPlaceOfBirthController.text == 'null') {
      _heirPlaceOfBirthController.text = '';
    }

    final String? hDobRaw = member.heirDateOfBirth ?? member.tanggalLahirAhliWaris;
    final String hDob = (hDobRaw != null && hDobRaw != '-' && hDobRaw != 'null')
        ? (MemberModel.parseDateOnly(hDobRaw) ?? hDobRaw)
        : '';
    _heirDateOfBirthController.text = hDob;

    _heirAddressController.text = member.heirAddress ?? member.alamatAhliWaris ?? '';
    if (_heirAddressController.text == '-' || _heirAddressController.text == 'null') {
      _heirAddressController.text = '';
    }
  }

  /// 🌐 0. FETCH DETAIL DATA ANGGOTA (GET /api/members/{id}/details atau GET /api/members/{id})
  Future<void> loadMemberDetail() async {
    if (!mounted) return;
    setState(() => _isLoadingDetail = true);

    try {
      final token = await AuthService().getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      // Coba endpoint /details terlebih dahulu, fallback ke /members/:id
      final detailsUri = Uri.parse('${AuthService.staticBaseUrl}/members/${widget.member.id}/details');
      var response = await http.get(detailsUri, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 404) {
        final fallbackUri = Uri.parse('${AuthService.staticBaseUrl}/members/${widget.member.id}');
        response = await http.get(fallbackUri, headers: headers).timeout(const Duration(seconds: 30));
      }

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        Map<String, dynamic>? data;
        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map<String, dynamic>) {
            data = decoded['data'] as Map<String, dynamic>;
          } else if (decoded['member'] is Map<String, dynamic>) {
            data = decoded['member'] as Map<String, dynamic>;
          } else {
            data = decoded;
          }
        }

        if (data != null && mounted) {
          final fetchedMember = MemberModel.fromJson(data);
          setState(() {
            _populateControllers(fetchedMember);
            _isLoadingDetail = false;
          });
          debugPrint('[LOAD_MEMBER_DETAIL] Berhasil memuat & mengisi detail member: ${fetchedMember.name}');
          return;
        }
      }
    } catch (e) {
      debugPrint('[LOAD_MEMBER_DETAIL] Gagal memuat detail member: $e');
    }

    if (mounted) {
      setState(() => _isLoadingDetail = false);
    }
  }

  @override
  void initState() {
    super.initState();

    _nikController = TextEditingController();
    _nameController = TextEditingController();
    _bukuPutihController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _churchController = TextEditingController();

    _placeOfBirthController = TextEditingController();
    _dateOfBirthController = TextEditingController();
    _genderController = TextEditingController();
    _occupationController = TextEditingController();
    _educationController = TextEditingController();
    _familyStatusController = TextEditingController();

    _heirNameController = TextEditingController();
    _heirRelationshipController = TextEditingController();
    _heirPlaceOfBirthController = TextEditingController();
    _heirDateOfBirthController = TextEditingController();
    _heirAddressController = TextEditingController();

    _selectedGender = (widget.member.gender == 'Laki-laki' || widget.member.gender == 'Perempuan')
        ? widget.member.gender
        : 'Laki-laki';

    // 1. Inisialisasi awal menggunakan data widget.member yang diteruskan
    _populateControllers(widget.member);

    // 2. Muat data detail lengkap secara async dari API /api/members/:id
    loadMemberDetail();
  }

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    _bukuPutihController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _churchController.dispose();
    _placeOfBirthController.dispose();
    _dateOfBirthController.dispose();
    _genderController.dispose();
    _occupationController.dispose();
    _educationController.dispose();
    _familyStatusController.dispose();
    _heirNameController.dispose();
    _heirRelationshipController.dispose();
    _heirPlaceOfBirthController.dispose();
    _heirDateOfBirthController.dispose();
    _heirAddressController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 20)); // default 20 years ago
    if (controller.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(controller.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1930),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  /// 🌐 1. UPDATE PROFILE DATA (PUT /api/members/{id})
  Future<void> _handleUpdateProfile() async {
    if (!_profileFormKey.currentState!.validate() || _isUpdatingProfile) return;

    setState(() => _isUpdatingProfile = true);

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/members/${widget.member.id}');

      final String? bpVal = _bukuPutihController.text.trim().isEmpty
          ? null
          : _bukuPutihController.text.trim();

      final String placeOfBirthVal = _placeOfBirthController.text.trim();

      // Format tanggal lahir memastikan YYYY-MM-DD
      final String rawDob = _dateOfBirthController.text.trim();
      final String? dateOfBirthVal = rawDob.isNotEmpty
          ? (MemberModel.parseDateOnly(rawDob) ?? rawDob)
          : null;

      final String heirPlaceOfBirthVal = _heirPlaceOfBirthController.text.trim();

      // Format tanggal lahir ahli waris memastikan YYYY-MM-DD
      final String rawHeirDob = _heirDateOfBirthController.text.trim();
      final String? heirDateOfBirthVal = rawHeirDob.isNotEmpty
          ? (MemberModel.parseDateOnly(rawHeirDob) ?? rawHeirDob)
          : null;

      final body = {
        'nik': _nikController.text.trim(),
        'no_ktp': _nikController.text.trim(),
        'ktp': _nikController.text.trim(),
        'name': _nameController.text.trim(),
        'buku_putih_no': bpVal,
        'no_rekening_buku_putih': bpVal,
        'buku_putih_account_no': bpVal,
        'buku_putih_number': bpVal,
        'no_buku_putih': bpVal,
        'phone': _phoneController.text.trim(),
        'no_hp': _phoneController.text.trim(),
        'no_handphone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'alamat': _addressController.text.trim(),
        'church_unit': _churchController.text.trim(),
        'church_sector': _churchController.text.trim(),
        'sektor_gereja': _churchController.text.trim(),

        // 🌟 Tempat Lahir (place_of_birth & alias tempat_lahir)
        'place_of_birth': placeOfBirthVal,
        'tempat_lahir': placeOfBirthVal,
        'birth_place': placeOfBirthVal,

        // 🌟 Tanggal Lahir (date_of_birth format YYYY-MM-DD & alias tanggal_lahir)
        'date_of_birth': dateOfBirthVal,
        'tanggal_lahir': dateOfBirthVal,
        'birth_date': dateOfBirthVal,

        'jenis_kelamin': _selectedGender,
        'gender': _selectedGender,
        'pekerjaan': _occupationController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'pendidikan': _educationController.text.trim(),
        'education': _educationController.text.trim(),
        'status_keluarga': _familyStatusController.text.trim(),
        'family_status': _familyStatusController.text.trim(),

        'nama_ahli_waris': _heirNameController.text.trim(),
        'heir_name': _heirNameController.text.trim(),
        'hubungan_ahli_waris': _heirRelationshipController.text.trim(),
        'heir_relationship': _heirRelationshipController.text.trim(),
        'tempat_lahir_ahli_waris': heirPlaceOfBirthVal,
        'heir_place_of_birth': heirPlaceOfBirthVal,
        'tanggal_lahir_ahli_waris': heirDateOfBirthVal,
        'heir_date_of_birth': heirDateOfBirthVal,
        'alamat_ahli_waris': _heirAddressController.text.trim(),
        'heir_address': _heirAddressController.text.trim(),
      };

      debugPrint('[UPDATE_PROFILE_LOG] Sending PUT to: $uri with body: ${jsonEncode(body)}');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60));

      debugPrint('[UPDATE_PROFILE_LOG] Response: ${response.statusCode} - ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 1. Ambil data member terbaru dari response API
        Map<String, dynamic> updatedData = {};
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            if (decoded['data'] is Map<String, dynamic>) {
              updatedData = decoded['data'] as Map<String, dynamic>;
            } else if (decoded['member'] is Map<String, dynamic>) {
              updatedData = decoded['member'] as Map<String, dynamic>;
            } else {
              updatedData = decoded;
            }
          }
        } catch (_) {}

        final dynamic heirObj = updatedData['ahli_waris'] ?? updatedData['heir'];
        final Map<String, dynamic> heirMap = (heirObj is Map<String, dynamic>) ? heirObj : {};

        // 2. Perbarui nilai TextEditingController di form menggunakan data terbaru tersebut di dalam setState:
        setState(() {
          _placeOfBirthController.text = (updatedData['place_of_birth'] ?? updatedData['tempat_lahir'])?.toString() ?? _placeOfBirthController.text;

          final String? rawDob = (updatedData['date_of_birth'] ?? updatedData['tanggal_lahir'])?.toString();
          _dateOfBirthController.text = (rawDob != null && rawDob.isNotEmpty)
              ? (MemberModel.parseDateOnly(rawDob) ?? rawDob)
              : _dateOfBirthController.text;

          _genderController.text = (updatedData['gender'] ?? updatedData['jenis_kelamin'])?.toString() ?? _genderController.text;
          final String currentG = _genderController.text;
          if (currentG == 'Laki-laki' || currentG == 'Perempuan') {
            _selectedGender = currentG;
          } else if (currentG.toLowerCase() == 'male' || currentG.toLowerCase() == 'l') {
            _selectedGender = 'Laki-laki';
          } else if (currentG.toLowerCase() == 'female' || currentG.toLowerCase() == 'p') {
            _selectedGender = 'Perempuan';
          }

          _occupationController.text = (updatedData['occupation'] ?? updatedData['pekerjaan'])?.toString() ?? _occupationController.text;
          _educationController.text = (updatedData['education'] ?? updatedData['pendidikan'])?.toString() ?? _educationController.text;
          _familyStatusController.text = (updatedData['family_status'] ?? updatedData['status_keluarga'])?.toString() ?? _familyStatusController.text;
          _churchSectorController.text = (updatedData['church_sector'] ?? updatedData['sektor_gereja'] ?? updatedData['church_unit'])?.toString() ?? _churchSectorController.text;
          _addressController.text = (updatedData['address'] ?? updatedData['alamat'])?.toString() ?? _addressController.text;

          // Data Ahli Waris
          _heirNameController.text = (updatedData['heir_name'] ?? updatedData['nama_ahli_waris'] ?? heirMap['nama'] ?? heirMap['name'])?.toString() ?? _heirNameController.text;
          _heirRelationshipController.text = (updatedData['heir_relationship'] ?? updatedData['hubungan_ahli_waris'] ?? heirMap['hubungan'] ?? heirMap['relationship'])?.toString() ?? _heirRelationshipController.text;
          _heirPlaceOfBirthController.text = (updatedData['heir_place_of_birth'] ?? updatedData['tempat_lahir_ahli_waris'] ?? heirMap['tempat_lahir'])?.toString() ?? _heirPlaceOfBirthController.text;

          final String? rawHeirDob = (updatedData['heir_date_of_birth'] ?? updatedData['tanggal_lahir_ahli_waris'] ?? heirMap['tanggal_lahir'])?.toString();
          _heirDateOfBirthController.text = (rawHeirDob != null && rawHeirDob.isNotEmpty)
              ? (MemberModel.parseDateOnly(rawHeirDob) ?? rawHeirDob)
              : _heirDateOfBirthController.text;

          _heirAddressController.text = (updatedData['heir_address'] ?? updatedData['alamat_ahli_waris'] ?? heirMap['alamat'])?.toString() ?? _heirAddressController.text;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Profil & No. HP Anggota Berhasil Diperbarui'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui profil (Status ${response.statusCode})'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan koneksi API: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingProfile = false);
      }
    }
  }

  /// 🔑 2. RESET PIN 6 DIGIT (PUT /api/members/{id}/reset-pin)
  Future<void> _handleResetPin() async {
    if (!_securityFormKey.currentState!.validate() || _isResettingPin) return;

    setState(() => _isResettingPin = true);

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/members/${widget.member.id}/reset-pin');

      final body = {
        'new_pin': _newPinController.text.trim(),
        'pin_confirmation': _confirmPinController.text.trim(),
      };

      debugPrint('[RESET_PIN_LOG] Sending PUT to: $uri with body: ${jsonEncode(body)}');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60));

      debugPrint('[RESET_PIN_LOG] Response Status: ${response.statusCode} - ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _newPinController.clear();
        _confirmPinController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('PIN Berhasil Di-reset!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        String errorDetail = 'Gagal reset PIN (Status ${response.statusCode})';
        try {
          final resData = jsonDecode(response.body);
          if (resData['errors'] != null && resData['errors'] is Map) {
            final Map errors = resData['errors'];
            final buffer = StringBuffer();
            errors.forEach((field, msgs) {
              final List msgList = msgs is List ? msgs : [msgs.toString()];
              buffer.write('• ${msgList.join(', ')}\n');
            });
            errorDetail = buffer.toString().trim();
          } else if (resData['message'] != null) {
            errorDetail = resData['message'];
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(errorDetail)),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan koneksi API: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResettingPin = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Data #${widget.member.memberNo} - ${widget.member.name}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: _isLoadingDetail
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  color: AppColors.accentBlue,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: FORM EDIT PROFIL ANGGOTA
                Form(
                  key: _profileFormKey,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.manage_accounts_rounded, color: AppColors.adminNavy, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Informasi Profil Anggota',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.adminNavy,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // NIK KTP & NAMA LENGKAP
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nikController,
                                readOnly: false,
                                enabled: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(20),
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z]')),
                                ],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Nomor NIK wajib diisi';
                                  }
                                  if (v.trim().length > 20) {
                                    return 'Nomor NIK maksimal 20 karakter';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Nomor KTP / NIK',
                                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _nameController,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Lengkap',
                                  prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // NO HANDPHONE & EMAIL TERPISAH
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'No. Handphone / WA',
                                  prefixIcon: Icon(Icons.phone_android_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Alamat Email',
                                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // NO REKENING BUKU PUTIH & ASAL GEREJA
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _bukuPutihController,
                                decoration: const InputDecoration(
                                  labelText: 'No. Rekening Buku Putih (Simpanan Harian)',
                                  hintText: 'Contoh: 2021-0017',
                                  prefixIcon: Icon(Icons.menu_book_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _churchController,
                                decoration: const InputDecoration(
                                  labelText: 'Asal Gereja / Sektor',
                                  prefixIcon: Icon(Icons.church_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Alamat Tempat Tinggal',
                            prefixIcon: Icon(Icons.home_outlined, color: AppColors.primary),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 32),
                        const Row(
                          children: [
                            Icon(Icons.badge_rounded, color: AppColors.adminNavy, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Data Pribadi Tambahan',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.adminNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Tempat Lahir & Tanggal Lahir
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _placeOfBirthController,
                                decoration: const InputDecoration(
                                  labelText: 'Tempat Lahir',
                                  prefixIcon: Icon(Icons.location_city_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _dateOfBirthController,
                                readOnly: true,
                                onTap: () => _selectDate(context, _dateOfBirthController),
                                decoration: const InputDecoration(
                                  labelText: 'Tanggal Lahir',
                                  prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Jenis Kelamin & Pekerjaan
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(_selectedGender),
                                initialValue: _selectedGender,
                                decoration: const InputDecoration(
                                  labelText: 'Jenis Kelamin',
                                  prefixIcon: Icon(Icons.people_outline, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                                  DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedGender = val;
                                      _genderController.text = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _occupationController,
                                decoration: const InputDecoration(
                                  labelText: 'Pekerjaan',
                                  prefixIcon: Icon(Icons.work_outline, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Pendidikan Terakhir & Status Keluarga
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _educationController,
                                decoration: const InputDecoration(
                                  labelText: 'Pendidikan Terakhir',
                                  prefixIcon: Icon(Icons.school_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _familyStatusController,
                                decoration: const InputDecoration(
                                  labelText: 'Status dalam Keluarga',
                                  prefixIcon: Icon(Icons.family_restroom_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 32),
                        const Row(
                          children: [
                            Icon(Icons.supervised_user_circle_rounded, color: AppColors.adminNavy, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Data Ahli Waris',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.adminNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Nama Ahli Waris & Hubungan Keluarga
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _heirNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Ahli Waris',
                                  prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _heirRelationshipController,
                                decoration: const InputDecoration(
                                  labelText: 'Hubungan Keluarga',
                                  prefixIcon: Icon(Icons.handshake_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Tempat Lahir & Tanggal Lahir Ahli Waris
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _heirPlaceOfBirthController,
                                decoration: const InputDecoration(
                                  labelText: 'Tempat Lahir Ahli Waris',
                                  prefixIcon: Icon(Icons.location_city_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _heirDateOfBirthController,
                                readOnly: true,
                                onTap: () => _selectDate(context, _heirDateOfBirthController),
                                decoration: const InputDecoration(
                                  labelText: 'Tanggal Lahir Ahli Waris',
                                  prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Alamat Lengkap Ahli Waris
                        TextFormField(
                          controller: _heirAddressController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Alamat Lengkap Ahli Waris',
                            prefixIcon: Icon(Icons.home_outlined, color: AppColors.primary),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isUpdatingProfile ? null : _handleUpdateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.adminNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isUpdatingProfile
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Simpan Perubahan Profil', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // SECTION 2: CARD KHUSUS KEAMANAN / RESET PIN
                Form(
                  key: _securityFormKey,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.shield_rounded, color: AppColors.danger, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Keamanan / Reset PIN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Atur ulang PIN otorisasi 6 digit untuk akses transaksi anggota ini jika lupa.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                        ),
                        const Divider(height: 20),

                        // FIELD 1: PIN BARU (6 DIGIT)
                        TextFormField(
                          controller: _newPinController,
                          obscureText: _obscureNewPin,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'PIN Baru (6 Digit) wajib diisi!';
                            }
                            if (val.trim().length != 6) {
                              return 'PIN harus tepat 6 digit angka!';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'PIN Baru (6 Digit)',
                            hintText: 'Masukkan 6 digit angka...',
                            counterText: '',
                            prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.danger),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                setState(() => _obscureNewPin = !_obscureNewPin);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // FIELD 2: KONFIRMASI PIN BARU
                        TextFormField(
                          controller: _confirmPinController,
                          obscureText: _obscureConfirmPin,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Konfirmasi PIN wajib diisi!';
                            }
                            if (val.trim() != _newPinController.text.trim()) {
                              return 'Konfirmasi PIN tidak cocok!';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Konfirmasi PIN Baru',
                            hintText: 'Ulangi 6 digit PIN...',
                            counterText: '',
                            prefixIcon: const Icon(Icons.pin_end_outlined, color: AppColors.danger),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                setState(() => _obscureConfirmPin = !_obscureConfirmPin);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // TOMBOL RESET PIN
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _isResettingPin ? null : _handleResetPin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isResettingPin
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.key_rounded, size: 18),
                            label: Text(
                              _isResettingPin ? 'Memproses Reset PIN...' : 'Reset PIN',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
