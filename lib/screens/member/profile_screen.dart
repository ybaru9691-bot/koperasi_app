import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/whatsapp_helper.dart';
import '../auth/welcome_screen.dart';
import 'edit_profile_screen.dart';
import 'home_screen.dart';

// SECTION 1: DUMMY MODELS REMOVED (INTEGRATED WITH LARAVEL API)
// SECTION 2: PROFILE SCREEN WIDGET
/// ProfileScreen menampilkan detail keanggotaan, informasi pribadi,
/// pengaturan akun, dan opsi keluar dari aplikasi.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Map<String, dynamic>? _memberData;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final user = await authService.getSavedUser();
      final token = await authService.getToken();

      if (user == null || token == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Sesi tidak ditemukan. Silakan login kembali.';
          });
        }
        return;
      }

      final memberId = user['member_id'] ?? user['id'];
      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/members/$memberId/details');

      debugPrint('[PROFILE_LOG] Fetching profile details from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      debugPrint('[PROFILE_LOG] Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final bool isSuccess = responseData['success'] == true ||
            responseData['status'] == 'success' ||
            responseData['status'] == true;

        if (isSuccess && responseData['data'] != null) {
          if (mounted) {
            setState(() {
              _memberData = responseData['data'];
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = responseData['message'] ?? 'Gagal memuat profil.';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Gagal memuat profil (Status ${response.statusCode}).';
          });
        }
      }
    } catch (e) {
      debugPrint('[PROFILE_ERROR] Exception: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Gagal terhubung ke server API: $e';
        });
      }
    }
  }

  /// Menampilkan dialog konfirmasi Logout dengan efek Loading & Reset Navigasi
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                'Keluar dari Akun?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari akun Koperasi Pelita Mobile?',
            style: TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // 1. Tutup Dialog Konfirmasi
                Navigator.pop(dialogContext);

                // 2. Tampilkan Overlay Loading Dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingContext) {
                    return Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 24.0,
                          horizontal: 20.0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Mengeluarkan akun...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

                // 3. Penghapusan Sesi & Token dari SharedPreferences & SecureStorage
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                } catch (e) {
                  debugPrint("Error clearing SharedPreferences: $e");
                }
                await AuthService().logout();

                if (!context.mounted) return;

                // 4. Tutup dialog loading
                Navigator.of(context, rootNavigator: true).pop();

                if (!context.mounted) return;

                // 5. Reset Navigasi ke WelcomeScreen dan hapus histori backstack
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Ya, Keluar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Membuka WhatsApp CS / Pusat Bantuan Koperasi
  void _openWhatsAppHelp(BuildContext context) {
    final String memberName = _memberData?['name'] ?? 'Anggota';
    final String memberNo = _memberData?['member_number'] ?? _memberData?['no_register'] ?? '-';
    WhatsAppHelper.showContactBottomSheet(
      context,
      memberName: memberName,
      memberNumber: memberNo,
    );
  }

  /// Membuka WhatsApp untuk permohonan Ubah Kata Sandi / PIN
  void _openWhatsAppChangePassword(BuildContext context) {
    final String memberName = _memberData?['name'] ?? 'Anggota';
    final String memberNo = _memberData?['member_number'] ?? _memberData?['no_register'] ?? '-';
    
    WhatsAppHelper.showContactBottomSheet(
      context,
      memberName: memberName,
      memberNumber: memberNo,
      customHeaderTitle: 'Permohonan Ubah PIN / Bantuan',
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _hasError
              ? _buildErrorState()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    children: [
                      _buildHeaderProfile(context),
                      const SizedBox(height: 20),
                      _buildMembershipInfoCard(),
                      const SizedBox(height: 24),
                      _buildSettingsMenu(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFEE2E2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Gagal Memuat Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage ?? 'Terjadi kesalahan saat terhubung ke server.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _fetchProfileData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // SECTION 3: MODULAR BUILD METHODS


  /// AppBar khusus Halaman Profil
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        tooltip: 'Kembali',
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            const TabSwitchNotification(0).dispatch(context);
          }
        },
      ),
      title: const Text(
        'Profil Anggota',
        style: TextStyle(
          color: AppColors.textInverse,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          tooltip: 'Rincian Profil',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Header Profil: Foto Avatar, Nama, ID Anggota, dan Badge Status
  Widget _buildHeaderProfile(BuildContext context) {
    final String name = _memberData?['name'] ?? '';
    final String memberId = _memberData?['member_number'] ?? _memberData?['no_register'] ?? '';
    final String status = _memberData?['status'] ?? 'aktif';

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            );
          },
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFF137A43), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF137A43).withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const ClipOval(
              child: CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(
                  Icons.person_rounded,
                  size: 60,
                  color: Color(0xFF137A43),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Nama Anggota
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),

        // ID Anggota & Badge Status
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ID: $memberId',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Card Informasi Keanggotaan (NIK, HP, Tgl Bergabung, SHU)
  Widget _buildMembershipInfoCard() {
    final String nik = _memberData?['nik'] ?? '-';
    final String phone = _memberData?['phone'] ?? _memberData?['no_hp'] ?? '-';
    final String address = _memberData?['address'] ?? '-';
    final String dob = _memberData?['date_of_birth'] != null
        ? _memberData!['date_of_birth'].toString().split('T')[0]
        : '-';
    final dynamic rawJoinDate = _memberData?['joined_at'] ?? _memberData?['created_at'];
    final String joinDate = rawJoinDate != null
        ? rawJoinDate.toString().split('T')[0]
        : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.badge_outlined, color: Color(0xFF137A43), size: 20),
                SizedBox(width: 8),
                Text(
                  'Informasi Keanggotaan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2533),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            _InfoRowTile(
              label: 'Nomor NIK',
              value: nik,
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 14),
            _InfoRowTile(
              label: 'Nomor HP / WhatsApp',
              value: phone,
              icon: Icons.phone_android_outlined,
            ),
            const SizedBox(height: 14),
            _InfoRowTile(
              label: 'Alamat Tinggal',
              value: address,
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 14),
            _InfoRowTile(
              label: 'Tanggal Lahir',
              value: dob,
              icon: Icons.cake_outlined,
            ),
            const SizedBox(height: 14),
            _InfoRowTile(
              label: 'Tanggal Bergabung',
              value: joinDate,
              icon: Icons.calendar_today_outlined,
            ),
            
            // Estimasi SHU Tahun 2026 disembunyikan/komentar sesuai instruksi:
            // const SizedBox(height: 14),
            // _InfoRowTile(
            //   label: 'Estimasi SHU Tahun 2026',
            //   value: 'Rp ${_formatCurrency(1450000.00)}',
            //   icon: Icons.savings_outlined,
            //   valueColor: const Color(0xFF137A43),
            //   isBoldValue: true,
            // ),
          ],
        ),
      ),
    );
  }

  /// Menampilkan Bottom Sheet Syarat & Ketentuan Pinjaman
  void _showTermsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF6F8FA),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle indicator
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  width: double.infinity,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Syarat & Ketentuan Pinjaman',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2533),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ketentuan Umum Pengajuan Pinjaman Koperasi CUM Pelita',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Kartu Ketentuan Survei & Persetujuan Keluarga
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8F5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF137A43).withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF137A43).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_outlined,
                            color: Color(0xFF137A43),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ketentuan Verifikasi & Persetujuan',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF0F5132),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Bersedia disurvei di tempat domisili/tinggal oleh petugas koperasi, serta pengajuan pinjaman wajib diketahui dan disetujui oleh suami/istri (bagi yang berkeluarga) atau pihak keluarga/wali.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tombol Tutup
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137A43),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Tutup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Menu Pengaturan & Opsi Akun
  Widget _buildSettingsMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _MenuOptionTile(
              icon: Icons.lock_outline_rounded,
              title: 'Ubah Kata Sandi / PIN',
              subtitle: 'Keamanan akun dan verifikasi transaksi',
              onTap: () => _openWhatsAppChangePassword(context),
            ),
            const Divider(height: 1, indent: 56),
            _MenuOptionTile(
              icon: Icons.headset_mic_outlined,
              title: 'Pusat Bantuan / CS',
              subtitle: 'Hubungi petugas koperasi via WhatsApp',
              onTap: () => _openWhatsAppHelp(context),
            ),
            const Divider(height: 1, indent: 56),
            _MenuOptionTile(
              icon: Icons.description_outlined,
              title: 'Syarat & Ketentuan',
              subtitle: 'Ketentuan keanggotaan dan hak simpan pinjam',
              onTap: () => _showTermsBottomSheet(context),
            ),
            const Divider(height: 1, indent: 56),
            // Tombol Keluar (Merah)
            _MenuOptionTile(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Keluar dari aplikasi Koperasi Pelita',
              iconColor: Colors.redAccent,
              titleColor: Colors.redAccent,
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

// SECTION 4: REUSABLE SUB-WIDGETS

/// Widget Baris Informasi Keanggotaan
class _InfoRowTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRowTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF137A43).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF137A43)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget Item Opsi Menu Pengaturan
class _MenuOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _MenuOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? const Color(0xFF137A43);
    final effectiveTitleColor = titleColor ?? const Color(0xFF1E293B);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18.0,
        vertical: 4.0,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: effectiveIconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: effectiveIconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: effectiveTitleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey.shade400,
        size: 20,
      ),
    );
  }
}
