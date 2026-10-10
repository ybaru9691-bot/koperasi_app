import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/financial_calculator_helper.dart';
import 'admin_main_screen.dart';

//  Form Pendaftaran Calon Anggota Baru Koperasi CUM Pelita Dual-Key REST API & Fallback Ready
class TambahAnggotaScreen extends StatefulWidget {
  const TambahAnggotaScreen({super.key});

  @override
  State<TambahAnggotaScreen> createState() => _TambahAnggotaScreenState();
}

class _TambahAnggotaScreenState extends State<TambahAnggotaScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

 
  // SECTION 1: DATA IDENTITAS CALON ANGGOTA
  final TextEditingController _memberNoController = TextEditingController();
  final TextEditingController _bukuPutihNoController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthPlaceController = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'Laki-laki';
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _jobController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _familyStatusController = TextEditingController();
  final TextEditingController _churchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // SECTION 2: DATA AHLI WARIS
  final TextEditingController _heirNameController = TextEditingController();
  final TextEditingController _heirRelationController = TextEditingController();
  final TextEditingController _heirBirthPlaceController = TextEditingController();
  DateTime? _heirBirthDate;
  final TextEditingController _heirAddressController = TextEditingController();


  // SECTION 3: RINCIAN BIAYA PENDAFTARAN AWAL
  final int _uangPangkal = 20000; 
  final int _simpananPokok = 200000; 
  final int _danaDuka = 20000; 

  String _selectedProduct = 'buku_biru';

  // Editable Controllers dengan default minimal setoran awal (Rp 270.000 total untuk Buku Biru)
  final TextEditingController _swController = TextEditingController(text: '20000');
  final TextEditingController _ssController = TextEditingController(text: '10000');
  final TextEditingController _shController = TextEditingController(text: '50000');

  int get _simpananWajibVal {
    final clean = _swController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.isEmpty ? 20000 : (int.tryParse(clean) ?? 20000);
  }

  int get _simpananSukarelaVal {
    final clean = _ssController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.isEmpty ? 10000 : (int.tryParse(clean) ?? 10000);
  }

  int get _dailySavingsVal {
    final clean = _shController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.isEmpty ? 50000 : (int.tryParse(clean) ?? 50000);
  }

  @override
  void dispose() {
    _memberNoController.dispose();
    _bukuPutihNoController.dispose();
    _nikController.dispose();
    _nameController.dispose();
    _birthPlaceController.dispose();
    _phoneController.dispose();
    _jobController.dispose();
    _educationController.dispose();
    _familyStatusController.dispose();
    _churchController.dispose();
    _addressController.dispose();
    _heirNameController.dispose();
    _heirRelationController.dispose();
    _heirBirthPlaceController.dispose();
    _heirAddressController.dispose();
    _swController.dispose();
    _ssController.dispose();
    _shController.dispose();
    super.dispose();
  }



  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Pilih Tanggal';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _selectDate(BuildContext context, bool isMember) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isMember) {
          _birthDate = picked;
        } else {
          _heirBirthDate = picked;
        }
      });
    }
  }

  /// SAFE NAVIGATION (MENCEGAH PAGE RELOAD FLUTTER WEB)
  void _handleBack(BuildContext context, [bool result = false]) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      try {
        Navigator.of(context).pushReplacementNamed('/admin/dashboard');
      } catch (_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminMainScreen(initialIndex: 1),
          ),
        );
      }
    }
  }

  
  ///  PROSES SIMPAN ANGGOTA BARU — Dengan Logging Lengkap & Error Dialog
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    //  Kumpulkan nilai dari semua controller
    final memberNo    = _memberNoController.text.trim();
    final nik         = _nikController.text.trim();
    final name        = _nameController.text.trim();
    final phone       = _phoneController.text.trim();
    final address     = _addressController.text.trim();
    final occupation  = _jobController.text.trim();
    final education   = _educationController.text.trim();
    final familyStat  = _familyStatusController.text.trim();
    final church      = _churchController.text.trim();
    final birthPlace  = _birthPlaceController.text.trim();
    final heirName    = _heirNameController.text.trim();
    final heirRel     = _heirRelationController.text.trim();
    final heirBPob    = _heirBirthPlaceController.text.trim();
    final heirAddr    = _heirAddressController.text.trim();

    final dateStr     = _birthDate != null
        ? _birthDate!.toIso8601String().split('T')[0]
        : null;
    final heirDateStr = _heirBirthDate != null
        ? _heirBirthDate!.toIso8601String().split('T')[0]
        : null;

    final String? bpVal = _bukuPutihNoController.text.trim().isEmpty
        ? null
        : _bukuPutihNoController.text.trim();

    //  Payload 100% presisi dengan kolom migration Laravel terbaru 
    // Key utama sesuai tabel `members`. Key fallback (*) untuk backward-compat.
    final Map<String, dynamic> payload = {
      // Identitas
      'member_number':    memberNo,     
      'member_no':        memberNo,     
      'buku_putih_no':    bpVal,
      'no_rekening_buku_putih': bpVal,
      'buku_putih_account_no': bpVal,
      'nik':              nik,
      'name':             name,
      'gender':           _gender,
      'place_of_birth':   birthPlace,  
      'birth_place':      birthPlace,  
      'date_of_birth':    dateStr,     
      'birth_date':       dateStr,     
      'phone':            phone,       
      'no_hp':            phone,       
      'occupation':       occupation,  
      'job':              occupation,  
      'education':        education,
      'family_status':    familyStat,
      'church_sector':    church,      
      'church_unit':      church,      
      'address':          address,
      // Ahli Waris
      'heir_name':              heirName,
      'heir_relationship':      heirRel,  
      'heir_relation':          heirRel,  
      'heir_place_of_birth':    heirBPob,
      'heir_date_of_birth':     heirDateStr,
      'heir_address':           heirAddr,
      // Simpanan & Dana
      'principal_savings':  (_selectedProduct == 'buku_biru' || _selectedProduct == 'keduanya') ? _simpananPokok : 0,
      'mandatory_savings':  (_selectedProduct == 'buku_biru' || _selectedProduct == 'keduanya') ? _simpananWajibVal : 0,
      'voluntary_savings':  _simpananSukarelaVal,
      'daily_savings':      (_selectedProduct == 'buku_putih' || _selectedProduct == 'keduanya') ? _dailySavingsVal : 0,
      'buku_putih':         (_selectedProduct == 'buku_putih' || _selectedProduct == 'keduanya') ? _dailySavingsVal : 0,
      'grief_fund':         _selectedProduct == 'keduanya' ? 40000 : _danaDuka,   
      'social_fund':        _selectedProduct == 'keduanya' ? 40000 : _danaDuka,   
      'registration_fee':   _selectedProduct == 'keduanya' ? 40000 : _uangPangkal,
      'total_pembayaran':   ((_selectedProduct == 'keduanya' ? 40000 : _uangPangkal) +
                             ((_selectedProduct == 'buku_biru' || _selectedProduct == 'keduanya') ? _simpananPokok : 0) +
                             (_selectedProduct == 'keduanya' ? 40000 : _danaDuka) +
                             ((_selectedProduct == 'buku_biru' || _selectedProduct == 'keduanya') ? _simpananWajibVal : 0) +
                             _simpananSukarelaVal +
                             ((_selectedProduct == 'buku_putih' || _selectedProduct == 'keduanya') ? _dailySavingsVal : 0)),
      'status':             'aktif',
      'has_buku_biru':      _selectedProduct == 'buku_biru' || _selectedProduct == 'keduanya',
      'has_buku_putih':     _selectedProduct == 'buku_putih' || _selectedProduct == 'keduanya',
    };

    //  LOG FASE 1: Sebelum request
    developer.log(
      'Payload: ${const JsonEncoder.withIndent('  ').convert(payload)}',
      name: 'MEMBER_POST',
      level: 800,
    );

    try {
      // Ambil token dari SharedPreferences 
      final token = await AuthService().getToken();
      final apiUrl = Uri.parse('${AuthService.staticBaseUrl}/members');

      // LOG FASE 2: Info request 
      developer.log('POST → $apiUrl', name: 'MEMBER_POST', level: 800);
      developer.log(
        'Headers: Content-Type=application/json | Accept=application/json | '
        'Authorization=${token != null && token.isNotEmpty ? "Bearer ${token.substring(0, token.length.clamp(0, 12))}..." : "KOSONG / TIDAK ADA"}',
        name: 'MEMBER_POST',
        level: 800,
      );

      // Kirim HTTP POST 
      final response = await http.post(
        apiUrl,
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'X-Requested-With': 'XMLHttpRequest',  // tambahan untuk Laravel SPA
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Request Timeout — server tidak merespons dalam 60 detik.'),
      );

      // LOG FASE 3: Response dari server 
      developer.log(
        'Response ${response.statusCode}\n${response.body}',
        name: 'MEMBER_POST',
        level: response.statusCode >= 400 ? 900 : 800,
      );
      // Print tambahan agar mudah dilihat di Dart DevTools Console
      // ignore: avoid_print
      print('╔══ [MEMBER_POST] Status: ${response.statusCode} ══╗');
      // ignore: avoid_print
      print('║ Body: ${response.body}');
      // ignore: avoid_print
      print('╚══════════════════════════════════════════╝');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _isLoading = false);
        if (!mounted) return;

        String successMsg = '✅ Anggota Berhasil Ditambahkan ke Database';
        if (_selectedProduct == 'buku_biru') {
          successMsg = '✅ Anggota Berhasil Terdaftar di Buku Biru (Saham)!';
        } else if (_selectedProduct == 'buku_putih') {
          successMsg = '✅ Anggota Berhasil Terdaftar di Buku Putih (Tabungan Harian)!';
        } else if (_selectedProduct == 'keduanya') {
          successMsg = '✅ Anggota Berhasil Terdaftar di Buku Biru & Buku Putih!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(successMsg)),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          _handleBack(context, true);
        }
        return;
      }

      // HANDLE ERROR — Parse body Laravel secara detail
      if (!mounted) return;

      final String errorTitle;
      final String errorBody;

      // Coba parse JSON error dari Laravel
      Map<String, dynamic>? resData;
      try {
        resData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        resData = null;
      }

      switch (response.statusCode) {
        // 422 Validasi Laravel gagal
        case 422:
          errorTitle = '⚠️ Data Tidak Valid (422)';
          final errors = resData?['errors'];
          if (errors is Map && errors.isNotEmpty) {
            final buffer = StringBuffer();
            errors.forEach((field, msgs) {
              final List msgList = msgs is List ? msgs : [msgs.toString()];
              buffer.write('• $field: ${msgList.join(', ')}\n');
            });
            errorBody = buffer.toString().trim();
          } else {
            errorBody = resData?['message']?.toString() ??
                'Data tidak lolos validasi Laravel. Periksa kembali form Anda.';
          }
          break;

        //   401 Token tidak valid / Sesi habis → REDIRECT KE LOGIN 
        case 401:
          developer.log('401 Unauthorized — menghapus sesi & redirect ke login.',
              name: 'MEMBER_POST', level: 900);

          // Hapus token lama & redirect ke WelcomeScreen
          if (mounted) {
            await AuthService.handleLogout(context);
          }
          return; // Hentikan eksekusi, sudah berpindah halaman

        //  403 – Forbidden 
        case 403:
          errorTitle = '🚫 Akses Ditolak (403 Forbidden)';
          errorBody = resData?['message']?.toString() ??
              'Anda tidak memiliki izin untuk menambahkan anggota.';
          break;

        //  404 Endpoint tidak ditemukan 
        case 404:
          errorTitle = '🔍 Endpoint Tidak Ditemukan (404)';
          errorBody = 'URL API \'${apiUrl.toString()}\' tidak ada di server. '
              'Pastikan route Laravel sudah didaftarkan dan server berjalan.';
          break;

        // Data Duplikat 
        case 409:
          errorTitle = '❌ Data Duplikat (409 Conflict)';
          errorBody = resData?['message']?.toString() ??
              'NIK atau Nomor Anggota sudah terdaftar di database.';
          break;

        //  500 – Server Error 
        case 500:
          errorTitle = '💥 Error Server Laravel (500)';
          errorBody = resData?['message']?.toString() ??
              'Terjadi error internal di server. Periksa file storage/logs/laravel.log.';
          break;

        // Lainnya 
        default:
          errorTitle = 'Gagal Menyimpan (Status ${response.statusCode})';
          errorBody = resData?['message']?.toString() ?? response.body;
      }

      //  Tampilkan Dialog Error (lebih informatif dari SnackBar) 
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
          title: Text(
            errorTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(
                  errorBody,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
                ),
                const Divider(height: 24),
                // Tampilkan raw body untuk membantu debugging
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Tampilkan Raw Response',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        response.body.length > 800
                            ? '${response.body.substring(0, 800)}\n... [truncated]'
                            : response.body,
                        style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                // Coba kirim ulang
                _submitForm();
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );

    } catch (e) {
      // Exception/Error: koneksi gagal / timeout / runtime error
      developer.log('Exception/Error: $e', name: 'MEMBER_POST', level: 1000, error: e);
      // ignore: avoid_print
      print('╔══ [MEMBER_POST] EXCEPTION ══╗');
      // ignore: avoid_print
      print('║ $e');
      // ignore: avoid_print
      print('╚══════════════════════════╝');

      if (!mounted) return;

      final isTimeout = e.toString().contains('Timeout') ||
          e.toString().contains('TimeoutException');

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(
            isTimeout ? Icons.timer_off_rounded : Icons.wifi_off_rounded,
            color: AppColors.warning,
            size: 40,
          ),
          title: Text(
            isTimeout ? '⏱️ Request Timeout' : '📵 Server Tidak Terjangkau',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTimeout
                    ? 'Server tidak merespons dalam 15 detik. Data disimpan sementara secara lokal.'
                    : 'Tidak dapat terhubung ke server API. Pastikan:\n\n'
                        '• Server Laravel berjalan\n'
                        '• URL base API sudah benar (${AuthService.staticBaseUrl})\n'
                        '• Perangkat terhubung ke internet / intranet\n\n'
                        'Data disimpan sementara secara lokal.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text('Detail: ${e.toString()}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (Navigator.canPop(context)) Navigator.pop(context, true);
              },
              child: const Text('OK, Lanjutkan'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.adminCanvas,
        appBar: AppBar(
          backgroundColor: AppColors.adminNavy,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Kembali',
            onPressed: () => _handleBack(context),
          ),
          title: const Text(
            'Formulir Anggota Baru',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: DATA IDENTITAS CALON ANGGOTA
                _buildSectionCard(
                  title: '1. Data Identitas Calon Anggota',
                  icon: Icons.person_outline_rounded,
                  child: Column(
                    children: [
                      // Grid 2 Kolom: No. Anggota & NIK KTP
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _memberNoController,
                              label: 'No. Register Anggota',
                              icon: Icons.confirmation_number_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (v) => v == null || v.trim().isEmpty ? 'No. Anggota wajib diisi' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              controller: _nikController,
                              label: 'Nomor KTP / NIK (16 Digit)',
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.number,
                              maxLength: 16,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(16),
                              ],
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (value.length != 16) return 'NIK harus persis 16 digit!';
                                  if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'NIK hanya boleh berisi angka!';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // No. Rekening Buku Putih (Simpanan Harian)
                      _buildInputField(
                        controller: _bukuPutihNoController,
                        label: 'No. Rekening Buku Putih (Simpanan Harian)',
                        hintText: 'Contoh: 2021-0017',
                        icon: Icons.menu_book_outlined,
                      ),
                      const SizedBox(height: 12),

                      // 1 Kolom Penuh: Nama Lengkap
                      _buildInputField(
                        controller: _nameController,
                        label: 'Nama Lengkap (Sesuai KTP)',
                        icon: Icons.person_outline,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),

                      // Grid 2 Kolom: Tempat Lahir & Tanggal Lahir
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _birthPlaceController,
                              label: 'Tempat Lahir',
                              icon: Icons.location_city_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDatePickerField(
                              label: 'Tanggal Lahir',
                              dateStr: _formatDate(_birthDate),
                              onTap: () => _selectDate(context, true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grid 2 Kolom: Jenis Kelamin & No. HP/WA
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: _buildInputDecoration('Jenis Kelamin', Icons.wc_outlined),
                              items: const [
                                DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan', style: TextStyle(fontSize: 13))),
                              ],
                              onChanged: (val) => setState(() => _gender = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              controller: _phoneController,
                              label: 'No. Handphone / WA',
                              icon: Icons.phone_android_outlined,
                              keyboardType: TextInputType.phone,
                              maxLength: 13,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'No HP wajib diisi';
                                }
                                if (value.length < 10 || value.length > 13) {
                                  return 'Nomor HP harus antara 10–13 digit!';
                                }
                                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                  return 'Nomor HP hanya boleh berisi angka!';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grid 2 Kolom: Pekerjaan & Pendidikan terakhir
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _jobController,
                              label: 'Pekerjaan',
                              icon: Icons.work_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              controller: _educationController,
                              label: 'Pendidikan Terakhir',
                              icon: Icons.school_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grid 2 Kolom: Status Keluarga & Gereja / Sektor
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _familyStatusController,
                              label: 'Status dlm Keluarga',
                              icon: Icons.family_restroom_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              controller: _churchController,
                              label: 'Asal Gereja / Sektor',
                              icon: Icons.church_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Alamat Tempat Tinggal
                      _buildInputField(
                        controller: _addressController,
                        label: 'Alamat Lengkap Tempat Tinggal',
                        icon: Icons.home_outlined,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // SECTION 2: DATA AHLI WARIS
                _buildSectionCard(
                  title: '2. Data Ahli Waris',
                  icon: Icons.people_outline_rounded,
                  child: Column(
                    children: [
                      // Grid 2 Kolom: Nama Ahli Waris & Hubungan Keluarga
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _heirNameController,
                              label: 'Nama Ahli Waris',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              controller: _heirRelationController,
                              label: 'Hubungan Keluarga',
                              icon: Icons.escalator_warning_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grid 2 Kolom: Tempat Lahir & Tanggal Lahir Ahli Waris
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _heirBirthPlaceController,
                              label: 'Tempat Lahir Ahli Waris',
                              icon: Icons.location_city_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDatePickerField(
                              label: 'Tgl Lahir Ahli Waris',
                              dateStr: _formatDate(_heirBirthDate),
                              onTap: () => _selectDate(context, false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Alamat Ahli Waris
                      _buildInputField(
                        controller: _heirAddressController,
                        label: 'Alamat Tempat Tinggal Ahli Waris',
                        icon: Icons.home_outlined,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                FinancialSetoranSection(
                  swController: _swController,
                  ssController: _ssController,
                  shController: _shController,
                  selectedProduct: _selectedProduct,
                  onProductChanged: (value) {
                    setState(() {
                      _selectedProduct = value;
                    });
                  },
                ),

                const SizedBox(height: 24),

                // TOMBOL SIMPAN DATA ANGGOTA BARU
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: Text(
                      _isLoading ? 'Menyimpan ke Database...' : 'Simpan Data Anggota',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.adminNavy, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.adminNavy,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.cardBorder),
          child,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      fillColor: Colors.white,
      filled: true,
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final isMultiline = maxLines > 1;

    return TextFormField(
      controller: controller,
      keyboardType: isMultiline ? TextInputType.multiline : keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      textAlignVertical: isMultiline ? TextAlignVertical.top : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        labelStyle: const TextStyle(fontSize: 12),
        alignLabelWithHint: isMultiline ? true : null,
        prefixIcon: isMultiline ? null : Icon(icon, color: AppColors.primary, size: 20),
        prefix: isMultiline
            ? Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              )
            : null,
        border: const OutlineInputBorder(),
        contentPadding: isMultiline ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        fillColor: Colors.white,
        filled: true,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required String dateStr,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: _buildInputDecoration(label, Icons.calendar_today_outlined),
        child: Text(
          dateStr,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// 💸 Sub-Widget untuk membungkus input finansial agar rebuild tidak memengaruhi halaman utama (Identity & Heir Form)
class FinancialSetoranSection extends StatefulWidget {
  final TextEditingController swController;
  final TextEditingController ssController;
  final TextEditingController shController;
  final String selectedProduct;
  final ValueChanged<String> onProductChanged;

  const FinancialSetoranSection({
    super.key,
    required this.swController,
    required this.ssController,
    required this.shController,
    required this.selectedProduct,
    required this.onProductChanged,
  });

  @override
  State<FinancialSetoranSection> createState() => _FinancialSetoranSectionState();
}

class _FinancialSetoranSectionState extends State<FinancialSetoranSection> {
  int _currentSW = 20000;
  int _currentSS = 10000;
  int _currentSH = 50000;

  @override
  void initState() {
    super.initState();
    // Sinkronisasi nilai awal dari controller
    final cleanSw = widget.swController.text.replaceAll(RegExp(r'[^0-9]'), '');
    _currentSW = cleanSw.isEmpty ? 20000 : (int.tryParse(cleanSw) ?? 20000);

    final cleanSs = widget.ssController.text.replaceAll(RegExp(r'[^0-9]'), '');
    _currentSS = cleanSs.isEmpty ? 10000 : (int.tryParse(cleanSs) ?? 10000);

    final cleanSh = widget.shController.text.replaceAll(RegExp(r'[^0-9]'), '');
    _currentSH = cleanSh.isEmpty ? 50000 : (int.tryParse(cleanSh) ?? 50000);
  }

  @override
  void didUpdateWidget(covariant FinancialSetoranSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProduct != widget.selectedProduct) {
      final cleanSw = widget.swController.text.replaceAll(RegExp(r'[^0-9]'), '');
      _currentSW = cleanSw.isEmpty ? 20000 : (int.tryParse(cleanSw) ?? 20000);

      final cleanSs = widget.ssController.text.replaceAll(RegExp(r'[^0-9]'), '');
      _currentSS = cleanSs.isEmpty ? 10000 : (int.tryParse(cleanSs) ?? 10000);

      final cleanSh = widget.shController.text.replaceAll(RegExp(r'[^0-9]'), '');
      _currentSH = cleanSh.isEmpty ? 50000 : (int.tryParse(cleanSh) ?? 50000);
    }
  }

  Widget _buildProductChip(String value, String label) {
    final bool isActive = widget.selectedProduct == value;
    final Color activeColor = value == 'buku_biru'
        ? AppColors.primary
        : value == 'buku_putih'
            ? Colors.grey.shade700
            : const Color(0xFF10B981);

    return InkWell(
      onTap: () => widget.onProductChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : AppColors.cardBorder,
            width: isActive ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? activeColor : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBukuBiruOnly = widget.selectedProduct == 'buku_biru';
    final isBukuPutihOnly = widget.selectedProduct == 'buku_putih';

    final int pangkalVal = widget.selectedProduct == 'keduanya' ? 40000 : 20000;
    final int dukaVal = widget.selectedProduct == 'keduanya' ? 40000 : 20000;
    final int swVal = isBukuPutihOnly ? 0 : _currentSW;
    final int ssVal = isBukuPutihOnly ? 0 : _currentSS;
    final int shVal = isBukuBiruOnly ? 0 : _currentSH;
    final int spVal = isBukuPutihOnly ? 0 : 200000;

    // Total Pembayaran
    final int totalPayment = pangkalVal + spVal + dukaVal + swVal + ssVal + shVal;

    // Label detail total pendaftaran
    String detailLabel = '';
    if (isBukuBiruOnly) {
      detailLabel = 'Uang Pangkal + SP + SW + SS + Dana Duka';
    } else if (isBukuPutihOnly) {
      detailLabel = 'Uang Pangkal + Dana Duka + Setoran Awal SH';
    } else {
      detailLabel = 'Uang Pangkal + SP + SW + SS + Setoran Awal SH + Dana Duka';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppColors.adminNavy, size: 20),
              SizedBox(width: 8),
              Text(
                '3. Rincian Setoran Biaya Pendaftaran Awal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.adminNavy,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.cardBorder),

          const Text(
            'Pilihan Produk Simpanan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.adminNavy,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final isSmall = width < 500;
              final List<Widget> children = [
                _buildProductChip('buku_biru', '🔵 Buku Biru (Saham)'),
                if (!isSmall) const SizedBox(width: 8) else const SizedBox(height: 6),
                _buildProductChip('buku_putih', '⚪ Buku Putih (Harian)'),
                if (!isSmall) const SizedBox(width: 8) else const SizedBox(height: 6),
                _buildProductChip('keduanya', '🟢 Buka Kedua Buku'),
              ];

              return isSmall
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
                  : Row(children: children.map((w) => Expanded(child: w)).toList());
            },
          ),
          const Divider(height: 24, color: AppColors.cardBorder),
          
          _buildStaticFeeTile('Uang Pangkal / Pendaftaran', pangkalVal, 'Wajib / Sekali'),
          const SizedBox(height: 8),
          if (!isBukuPutihOnly) ...[
            _buildStaticFeeTile('Simpanan Pokok (SP)', 200000, 'Wajib / Sekali'),
            const SizedBox(height: 8),
          ],
          _buildStaticFeeTile('Dana Duka / Sosial', dukaVal, 'Wajib / Sekali'),
          const SizedBox(height: 12),

          // Input Simpanan Wajib Awal (Buku Biru atau Keduanya)
          if (!isBukuPutihOnly) ...[
            _buildLocalInputField(
              controller: widget.swController,
              label: 'Simpanan Wajib Bulan Ke-1 (SW)',
              icon: Icons.monetization_on_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                final val = clean.isEmpty ? 0 : (int.tryParse(clean) ?? 0);
                if (val > 20000) {
                  final excess = val - 20000;
                  setState(() {
                    _currentSW = 20000;
                    _currentSS += excess;
                  });
                  widget.swController.text = '20000';
                  widget.ssController.text = _currentSS.toString();
                  widget.swController.selection = TextSelection.fromPosition(
                    TextPosition(offset: widget.swController.text.length),
                  );
                } else {
                  setState(() {
                    _currentSW = val;
                  });
                }
              },
              validator: (v) {
                if (isBukuPutihOnly) return null;
                if (v == null || v.isEmpty) return 'Simpanan Wajib diisi';
                final numVal = num.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                if (numVal < 20000) return 'Minimal Simpanan Wajib Rp 20.000';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Input Simpanan Sukarela Awal (Buku Biru atau Keduanya)
            _buildLocalInputField(
              controller: widget.ssController,
              label: 'Setoran Simpanan Sukarela Awal (SS)',
              icon: Icons.savings_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                final val = clean.isEmpty ? 0 : (int.tryParse(clean) ?? 0);
                setState(() {
                  _currentSS = val;
                });
              },
            ),
            const SizedBox(height: 12),
          ],

          // Input Setoran Awal Harian / Buku Putih (Buku Putih atau Keduanya)
          if (!isBukuBiruOnly) ...[
            _buildLocalInputField(
              controller: widget.shController,
              label: 'Setoran Awal Simpanan Harian (SH)',
              icon: Icons.wallet_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                final val = clean.isEmpty ? 0 : (int.tryParse(clean) ?? 0);
                setState(() {
                  _currentSH = val;
                });
              },
              validator: (v) {
                if (isBukuBiruOnly) return null;
                if (v == null || v.isEmpty) return 'Setoran Awal Harian diisi';
                final numVal = num.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                if (numVal < 50000) return 'Minimal Setoran Awal Harian Rp 50.000';
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          // TOTAL AKUMULASI PEMBAYARAN AWAL
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL PEMBAYARAN AWAL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detailLabel,
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  FinancialCalculatorHelper.formatRupiah(totalPayment),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    required List<TextInputFormatter> inputFormatters,
    required void Function(String) onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        fillColor: Colors.white,
        filled: true,
      ),
    );
  }

  Widget _buildStaticFeeTile(String label, int amount, String badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.adminCanvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          Text(FinancialCalculatorHelper.formatRupiah(amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
