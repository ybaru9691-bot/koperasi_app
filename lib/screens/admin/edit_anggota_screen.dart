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

  // Data Pribadi
  late final TextEditingController _placeOfBirthController;
  late final TextEditingController _dateOfBirthController;
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

  @override
  void initState() {
    super.initState();

    final String initialPhone = widget.member.phone.isNotEmpty
        ? widget.member.phone
        : (widget.member.email.contains('@') ? '' : widget.member.email);

    final String initialEmail = widget.member.email.contains('@') ? widget.member.email : '';

    final String initialBukuPutih = widget.member.bukuPutihNo ??
        ((widget.member.bukuPutihNumber.isNotEmpty &&
                widget.member.bukuPutihNumber != '-' &&
                widget.member.bukuPutihNumber != 'null' &&
                !widget.member.bukuPutihNumber.startsWith('{'))
            ? widget.member.bukuPutihNumber
            : '');

    _nikController = TextEditingController(text: widget.member.nik != '-' ? widget.member.nik : '');
    _nameController = TextEditingController(text: widget.member.name);
    _bukuPutihController = TextEditingController(text: initialBukuPutih);
    _phoneController = TextEditingController(text: initialPhone != '-' ? initialPhone : '');
    _emailController = TextEditingController(text: initialEmail);
    _addressController = TextEditingController(text: widget.member.address != '-' ? widget.member.address : '');
    _churchController = TextEditingController(text: widget.member.churchSector != '-' ? widget.member.churchSector : '');

    // Data Pribadi
    _placeOfBirthController = TextEditingController(text: widget.member.placeOfBirth != '-' ? widget.member.placeOfBirth : '');
    _dateOfBirthController = TextEditingController(text: widget.member.dateOfBirth != '-' ? widget.member.dateOfBirth : '');
    _selectedGender = (widget.member.gender == 'Laki-laki' || widget.member.gender == 'Perempuan') ? widget.member.gender : 'Laki-laki';
    _occupationController = TextEditingController(text: widget.member.occupation != '-' ? widget.member.occupation : '');
    _educationController = TextEditingController(text: widget.member.education != '-' ? widget.member.education : '');
    _familyStatusController = TextEditingController(text: widget.member.familyStatus != '-' ? widget.member.familyStatus : '');

    // Data Ahli Waris
    _heirNameController = TextEditingController(text: widget.member.heirName != '-' ? widget.member.heirName : '');
    _heirRelationshipController = TextEditingController(text: widget.member.heirRelationship != '-' ? widget.member.heirRelationship : '');
    _heirPlaceOfBirthController = TextEditingController(text: widget.member.heirPlaceOfBirth != '-' ? widget.member.heirPlaceOfBirth : '');
    _heirDateOfBirthController = TextEditingController(text: widget.member.heirDateOfBirth != '-' ? widget.member.heirDateOfBirth : '');
    _heirAddressController = TextEditingController(text: widget.member.heirAddress != '-' ? widget.member.heirAddress : '');
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
        'tempat_lahir': _placeOfBirthController.text.trim(),
        'tanggal_lahir': _dateOfBirthController.text.trim(),
        'jenis_kelamin': _selectedGender,
        'pekerjaan': _occupationController.text.trim(),
        'pendidikan': _educationController.text.trim(),
        'status_keluarga': _familyStatusController.text.trim(),
        'nama_ahli_waris': _heirNameController.text.trim(),
        'hubungan_ahli_waris': _heirRelationshipController.text.trim(),
        'tempat_lahir_ahli_waris': _heirPlaceOfBirthController.text.trim(),
        'tanggal_lahir_ahli_waris': _heirDateOfBirthController.text.trim(),
        'alamat_ahli_waris': _heirAddressController.text.trim(),
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

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
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
                                value: _selectedGender,
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
                                    setState(() => _selectedGender = val);
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
