import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import 'admin_main_screen.dart';

/// Screen Profil Khusus Admin Koperasi
class AdminProfilScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const AdminProfilScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<AdminProfilScreen> createState() => _AdminProfilScreenState();
}

class _AdminProfilScreenState extends State<AdminProfilScreen> {
  String _adminName = 'Admin Koperasi';
  String _adminEmail = 'admin@koperasipelita.id';
  String _adminPhone = '-';
  String? _avatarUrl;
  bool _isLoadingProfile = false;

  /// Helper untuk menstandarkan URL avatar baik berupa path relatif maupun absolut
  static String? _resolveAvatarUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty || rawUrl == 'null') return null;
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final String baseHost = AuthService.staticBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (trimmed.startsWith('/storage/')) {
      return '$baseHost$trimmed';
    }
    if (trimmed.startsWith('storage/')) {
      return '$baseHost/$trimmed';
    }
    if (trimmed.startsWith('/')) {
      return '$baseHost/storage$trimmed';
    }
    return '$baseHost/storage/$trimmed';
  }

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
    setState(() => _isLoadingProfile = true);

    // 1. Baca dari penyimpanan lokal terlebih dahulu
    final savedUser = await AuthService().getSavedUser();
    if (savedUser != null && mounted) {
      final rawAvatar = savedUser['avatar_url'] ??
          savedUser['avatar'] ??
          savedUser['profile_photo_url'] ??
          savedUser['foto'];
      setState(() {
        _adminName = savedUser['name']?.toString() ?? _adminName;
        _adminEmail = savedUser['email']?.toString() ?? _adminEmail;
        _adminPhone = savedUser['phone']?.toString() ?? _adminPhone;
        _avatarUrl = _resolveAvatarUrl(rawAvatar?.toString());
      });
    }

    // 2. Refresh dari backend API jika tersedia
    try {
      final token = await AuthService().getToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${AuthService.staticBaseUrl}/admin/profile');
        final response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);
          Map<String, dynamic>? userData;
          if (decoded is Map) {
            if (decoded['data'] is Map) {
              userData = Map<String, dynamic>.from(decoded['data'] as Map);
            } else if (decoded['user'] is Map) {
              userData = Map<String, dynamic>.from(decoded['user'] as Map);
            }
          }

          if (userData != null) {
            final merged = {
              ...?savedUser,
              ...userData,
            };
            await AuthService().saveUser(merged);

            final rawAvatar = userData['avatar_url'] ??
                userData['avatar'] ??
                userData['profile_photo_url'] ??
                userData['foto'];

            if (mounted) {
              setState(() {
                _adminName = userData!['name']?.toString() ?? _adminName;
                _adminEmail = userData['email']?.toString() ?? _adminEmail;
                _adminPhone = userData['phone']?.toString() ?? _adminPhone;
                _avatarUrl = _resolveAvatarUrl(rawAvatar?.toString()) ?? _avatarUrl;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ADMIN_PROFILE_LOG] Gagal refresh profil dari server: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
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
        leading: Builder(
          builder: (btnContext) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              tooltip: 'Menu Admin',
              onPressed: widget.onOpenDrawer ??
                  () {
                    try {
                      Scaffold.of(btnContext).openDrawer();
                    } catch (_) {}
                  },
            );
          },
        ),
        title: const Text(
          'Profil Admin Koperasi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAdminProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
          child: Column(
            children: [
              if (_isLoadingProfile)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: LinearProgressIndicator(
                    color: AppColors.adminAccent,
                    backgroundColor: Colors.transparent,
                  ),
                ),

              // Header Kartu Profil Admin
              _buildAdminProfileHeader(),

              const SizedBox(height: 24),

              // Daftar Menu Pengaturan Admin
              _buildAdminSettingsMenuList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminProfileHeader() {
    final String? resolvedUrl = _resolveAvatarUrl(_avatarUrl);
    final bool hasAvatar = resolvedUrl != null && resolvedUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar Admin
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.adminNavy,
              border: Border.all(color: AppColors.adminAccent, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.adminNavy.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: hasAvatar
                  ? Image.network(
                      resolvedUrl,
                      key: ValueKey(resolvedUrl),
                      fit: BoxFit.cover,
                      width: 88,
                      height: 88,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Nama Admin
          Text(
            _adminName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Email Admin
          Text(
            _adminEmail,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),

          if (_adminPhone.isNotEmpty && _adminPhone != '-') ...[
            const SizedBox(height: 4),
            Text(
              _adminPhone,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Daftar menu pengaturan admin
  Widget _buildAdminSettingsMenuList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _buildMenuItemTile(
            icon: Icons.person_outline_rounded,
            title: 'Pengaturan Akun Admin',
            subtitle: 'Ubah informasi profil & nama pengelola',
            onTap: () => _showEditProfileDialog(context),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          _buildMenuItemTile(
            icon: Icons.menu_book_rounded,
            title: 'Panduan Langkah Penggunaan Sistem',
            subtitle: 'SOP resmi operasional anggota, kas harian, dan kartu pinjaman',
            iconColor: AppColors.primary,
            onTap: () => _showPanduanSopDialog(context),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          _buildMenuItemTile(
            icon: Icons.delete_forever_rounded,
            title: 'Reset Test Data (Developer)',
            subtitle: 'Hapus semua data transaksi & jurnal',
            iconColor: AppColors.danger,
            titleColor: AppColors.danger,
            onTap: () => _showResetDataDialog(context),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),

          // Tombol Logout Merah
          _buildMenuItemTile(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            subtitle: 'Keluar dari sesi admin',
            iconColor: AppColors.dangerAccent,
            titleColor: AppColors.dangerAccent,
            onTap: () => _showLogoutConfirmDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = AppColors.adminNavy,
    Color titleColor = AppColors.textPrimary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
    );
  }

  // ─── FORM MODAL PENGATURAN AKUN ADMIN ─────────────────────────────────────
  void _showEditProfileDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _adminName);
    final emailController = TextEditingController(text: _adminEmail);
    final phoneController = TextEditingController(
      text: _adminPhone != '-' ? _adminPhone : '',
    );

    XFile? selectedImage;
    Uint8List? selectedImageBytes;
    bool isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stContext, setStateDialog) {
            final String? resolvedUrl = _resolveAvatarUrl(_avatarUrl);
            final bool hasAvatarUrl = resolvedUrl != null && resolvedUrl.isNotEmpty;

            Future<void> pickProfileImage() async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 800,
                  maxHeight: 800,
                );
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setStateDialog(() {
                    selectedImage = picked;
                    selectedImageBytes = bytes;
                  });
                }
              } catch (e) {
                setStateDialog(() {
                  errorMessage = 'Gagal memilih gambar: $e';
                });
              }
            }

            Future<void> submitProfileChanges() async {
              if (!formKey.currentState!.validate()) return;

              setStateDialog(() {
                isSaving = true;
                errorMessage = null;
              });

              try {
                final token = await AuthService().getToken();
                final uri = Uri.parse('${AuthService.staticBaseUrl}/admin/profile');

                final request = http.MultipartRequest('POST', uri);
                if (token != null && token.isNotEmpty) {
                  request.headers['Authorization'] = 'Bearer $token';
                }
                request.headers['Accept'] = 'application/json';

                request.fields['name'] = nameController.text.trim();
                request.fields['email'] = emailController.text.trim();
                request.fields['phone'] = phoneController.text.trim();
                request.fields['_method'] = 'PUT'; // REST method spoofing support

                if (selectedImageBytes != null) {
                  final ext = selectedImage != null && selectedImage!.name.contains('.')
                      ? selectedImage!.name.split('.').last.toLowerCase()
                      : 'jpg';
                  final filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

                  request.files.add(
                    http.MultipartFile.fromBytes(
                      'avatar',
                      selectedImageBytes!,
                      filename: filename,
                    ),
                  );
                }

                final streamedResponse =
                    await request.send().timeout(const Duration(seconds: 30));
                final response = await http.Response.fromStream(streamedResponse);

                debugPrint('[PROFILE_UPDATE] Status: ${response.statusCode}, Body: ${response.body}');

                if (response.statusCode == 200 || response.statusCode == 201) {
                  final dynamic decoded = jsonDecode(response.body);
                  Map<String, dynamic> updatedUser = {};
                  if (decoded is Map) {
                    if (decoded['data'] is Map) {
                      updatedUser = Map<String, dynamic>.from(decoded['data'] as Map);
                    } else if (decoded['user'] is Map) {
                      updatedUser = Map<String, dynamic>.from(decoded['user'] as Map);
                    } else {
                      updatedUser = Map<String, dynamic>.from(decoded);
                    }
                  }

                  final rawAvatar = updatedUser['avatar_url'] ??
                      updatedUser['avatar'] ??
                      updatedUser['profile_photo_url'] ??
                      updatedUser['foto'];

                  final currentSaved = await AuthService().getSavedUser() ?? {};
                  final mergedUser = {
                    ...currentSaved,
                    ...updatedUser,
                    'name': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'phone': phoneController.text.trim(),
                    if (rawAvatar != null) ...{
                      'avatar': rawAvatar,
                      'avatar_url': rawAvatar,
                    },
                  };

                  await AuthService().saveUser(mergedUser);

                  final newResolvedAvatar = _resolveAvatarUrl(rawAvatar?.toString());

                  if (mounted) {
                    setState(() {
                      _adminName = mergedUser['name']?.toString() ?? _adminName;
                      _adminEmail = mergedUser['email']?.toString() ?? _adminEmail;
                      _adminPhone = mergedUser['phone']?.toString() ?? _adminPhone;
                      if (newResolvedAvatar != null) {
                        _avatarUrl = newResolvedAvatar;
                      }
                    });
                  }

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profil admin berhasil diperbarui'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  String msg = 'Gagal menyimpan profil (Status ${response.statusCode})';
                  try {
                    final body = jsonDecode(response.body);
                    if (body['message'] != null) msg = body['message'].toString();
                  } catch (_) {}
                  setStateDialog(() {
                    isSaving = false;
                    errorMessage = msg;
                  });
                }
              } catch (e) {
                setStateDialog(() {
                  isSaving = false;
                  errorMessage = 'Terjadi kesalahan jaringan: $e';
                });
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: 480,
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Dialog
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.manage_accounts_rounded,
                                  color: AppColors.adminNavy,
                                  size: 24,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Pengaturan Akun Admin',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.adminNavy,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // Avatar Picker Section
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.adminNavy,
                                  border: Border.all(
                                    color: AppColors.adminAccent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: selectedImageBytes != null
                                      ? Image.memory(
                                          selectedImageBytes!,
                                          fit: BoxFit.cover,
                                          width: 96,
                                          height: 96,
                                        )
                                      : (hasAvatarUrl
                                          ? Image.network(
                                              resolvedUrl,
                                              fit: BoxFit.cover,
                                              width: 96,
                                              height: 96,
                                              errorBuilder: (context, error, stackTrace) => const Center(
                                                child: Icon(
                                                  Icons.person_rounded,
                                                  size: 48,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons.person_rounded,
                                                size: 48,
                                                color: Colors.white,
                                              ),
                                            )),
                                ),
                              ),
                              Material(
                                color: AppColors.adminAccent,
                                shape: const CircleBorder(),
                                elevation: 2,
                                child: InkWell(
                                  onTap: isSaving ? null : pickProfileImage,
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Klik kamera untuk mengganti foto profil',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),

                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Input: Nama Lengkap
                        const Text(
                          'Nama Lengkap *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            hintText: 'Masukkan nama lengkap admin',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nama lengkap wajib diisi';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Input: Email
                        const Text(
                          'Alamat Email *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: emailController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'admin@koperasipelita.id',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Alamat email wajib diisi';
                            }
                            final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegExp.hasMatch(val.trim())) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Input: Nomor WhatsApp / HP
                        const Text(
                          'Nomor WhatsApp / HP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: phoneController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Contoh: 081234567890',
                            prefixIcon: Icon(Icons.phone_android_outlined, size: 20),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action Buttons: Batal & Simpan
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Batal'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: isSaving ? null : submitProfileChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.adminNavy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded, size: 18),
                              label: Text(
                                isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Dialog Konfirmasi Logout admin
  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.dangerAccent),
              SizedBox(width: 10),
              Text(
                'Keluar Sesi Admin?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari akun Admin Koperasi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await AuthService.handleLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Keluar'),
            ),
          ],
        );
      },
    );
  }

  // Dialog Konfirmasi Reset Data Admin yg Dipengaturan admin
  void _showResetDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ Clean Data Total Sistem',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Tindakan ini akan MENGHAPUS PERMANEN seluruh data transaksi, jurnal, anggota, dan riwayat peminjam. Akun login Admin & Manager akan TETAP AMAN. Apakah Anda yakin ingin membersihkan semua data?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                _executeResetData(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('🗑️ Ya, Bersihkan Semua Data'),
            ),
          ],
        );
      },
    );
  }

  // Eksekusi Reset data admin dengan memanggil API backend
  Future<void> _executeResetData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/admin/reset-test-data');
      final response = await http.post(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop(); // Tutup Loading Dialog
        }
      }

      if (response.statusCode == 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seluruh data berhasil dibersihkan!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminMainScreen(initialIndex: 0),
            ),
            (route) => false,
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal reset: ${response.statusCode} - ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error jaringan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── DIALOG MODAL INTERAKTIF PANDUAN & SOP PENGGUNAAN SISTEM ──────────────
  void _showPanduanSopDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 750, maxHeight: 650),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER DIALOG ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panduan Operasional Sistem Koperasi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.adminNavy,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'SOP Resmi Penggunaan & Alur Kerja Koperasi CUM Pelita',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 14),

                // ── CONTENT ACCORDIONS (EXPANSION TILES) ──
                Expanded(
                  child: ListView(
                    children: [
                      // TILE 1: MANAJEMEN ANGGOTA & MIGRASI DATA
                      _buildSopAccordion(
                        icon: Icons.people_alt_rounded,
                        accentColor: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                        title: '1. Manajemen Anggota & Migrasi Data',
                        subtitle: 'Migrasi Excel, Pendaftaran Baru & Validasi NIK',
                        initiallyExpanded: true,
                        content: [
                          _buildSopPoint(
                            title: 'Migrasi Excel',
                            desc: 'Unggah berkas Data ango1.xlsx via menu "Data Anggota". Sistem otomatis membedakan Anggota Saham (Buku Biru) dan Nasabah Simpanan Harian murni (Buku Putih dengan NIK sementara).',
                          ),
                          const SizedBox(height: 10),
                          _buildSopPoint(
                            title: 'Pendaftaran Baru',
                            desc: 'Gunakan tombol "Pendaftaran Anggota Baru" untuk mencatat warga jemaat/nasabah baru secara manual lengkap dengan foto KTP dan data gereja.',
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // TILE 2: TRANSAKSI KAS HARIAN (KM & KK)
                      _buildSopAccordion(
                        icon: Icons.point_of_sale_rounded,
                        accentColor: const Color(0xFF059669),
                        bgColor: const Color(0xFFECFDF5),
                        title: '2. Transaksi Kas Harian (KM & KK)',
                        subtitle: 'Penerimaan Kas Masuk, Pengeluaran & Jurnal Otomatis',
                        content: [
                          _buildSopPoint(
                            title: 'Kas Masuk (KM)',
                            desc: 'Catat penerimaan uang tunai untuk setoran Simpanan Wajib, Sukarela, maupun Tabungan Harian.',
                          ),
                          const SizedBox(height: 10),
                          _buildSopPoint(
                            title: 'Kas Keluar (KK)',
                            desc: 'Catat pengeluaran tunai untuk penarikan tabungan atau biaya operasional kantor.',
                          ),
                          const SizedBox(height: 10),
                          _buildSopPoint(
                            title: 'Otomasi Akuntansi',
                            desc: 'Setiap nota KM/KK otomatis menjurnal akun kas (1000/1010) dan terhubung langsung ke Buku Besar serta Neraca Lajur.',
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // TILE 3: OPERASIONAL PINJAMAN & KARTU KUNING
                      _buildSopAccordion(
                        icon: Icons.credit_card_rounded,
                        accentColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        title: '3. Operasional Pinjaman & Kartu Kuning (Manual Rule)',
                        subtitle: 'Persetujuan, Bunga Menurun, Input Angsuran & Cetak PDF',
                        content: [
                          _buildSopPoint(
                            title: 'Pengajuan & Pencairan',
                            desc: 'Proses permohonan di menu "Persetujuan Pinjaman". Baris pertama pencairan akan langsung tercetak di kartu pinjaman.',
                          ),
                          const SizedBox(height: 10),
                          _buildSopPoint(
                            title: 'Fleksibilitas Angsuran Kasir',
                            desc: '• Klik "+ Input Angsuran" di menu Kartu Pinjaman & Angsuran.\n• Jika anggota HANYA bayar jasa/bunga, isi Angsuran Pokok dengan 0. Saldo pokok utang tidak akan berkurang.\n• Jika anggota membawa nominal pokok bebas/parsial, ketik nominal riil yang diterima. Saldo pokok otomatis berkurang dinamis.',
                          ),
                          const SizedBox(height: 10),
                          _buildSopPoint(
                            title: 'Cetak Kartu Kuning',
                            desc: 'Klik tombol "Cetak Kartu Pinjaman (PDF)" untuk mencetak lembar fisik 9 kolom (28 baris bergaris) siap arsip.',
                          ),
                          const SizedBox(height: 10),
                          _buildSopPoint(
                            title: 'Riwayat Pinjaman',
                            desc: 'Pantau khusus mutasi pencairan dan angsuran di menu "Riwayat Transaksi Pinjaman".',
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // TILE 4: LAPORAN KEUANGAN & TUTUP BUKU
                      _buildSopAccordion(
                        icon: Icons.analytics_rounded,
                        accentColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF5F3FF),
                        title: '4. Laporan Keuangan & Tutup Buku',
                        subtitle: 'Buku Besar, Neraca Lajur, Jurnal Tabelaris & SHU',
                        content: [
                          _buildSopPoint(
                            title: 'Buku Besar & Neraca Lajur',
                            desc: 'Pantau mutasi debit/kredit dan keseimbangan neraca secara real-time.',
                          ),
                          const SizedBox(height: 10),
                          _buildSopPoint(
                            title: 'Jurnal Tabelaris',
                            desc: 'Rekap harian seluruh transaksi kas masuk dan keluar.',
                          ),
                          const SizedBox(height: 10),
                          _buildSopPoint(
                            title: 'Pembagian SHU & Bunga',
                            desc: 'Jalankan kalkulasi dividen saham atau bunga buku putih berkala melalui Dashboard Manajer.',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 12),

                // ── FOOTER DIALOG ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Koperasi Simpan Pinjam CUM Pelita HKBP Ressort Dame',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.adminNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Tutup Panduan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSopAccordion({
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    bool initiallyExpanded = false,
    required List<Widget> content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.adminNavy,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 14, top: 4),
          children: content,
        ),
      ),
    );
  }

  Widget _buildSopPoint({
    required String title,
    required String desc,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• $title',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.adminNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
