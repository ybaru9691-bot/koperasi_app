import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

// SECTION 1: DETAILED READ-ONLY MEMBER PROFILE SCREEN
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Map<String, dynamic>? _memberData;
  String? _memberId;

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

      _memberId = (user['member_id'] ?? user['id'])?.toString();
      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/members/$_memberId/details');

      debugPrint('[DETAIL_PROFILE_LOG] Fetching details from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

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
              _errorMessage = responseData['message'] ?? 'Gagal memuat detail profil.';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Gagal memuat detail profil (Status ${response.statusCode}).';
          });
        }
      }
    } catch (e) {
      debugPrint('[DETAIL_PROFILE_ERROR] Exception: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Gagal terhubung ke server API: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF137A43),
        elevation: 0,
        title: const Text(
          'Rincian Profil Anggota',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF137A43)),
            )
          : _hasError
              ? _buildErrorState()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  child: Column(
                    children: [
                      _buildAvatarSection(context),
                      const SizedBox(height: 32),
                      _buildFormFieldsSection(),
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
                  backgroundColor: const Color(0xFF137A43),
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

  Widget _buildAvatarSection(BuildContext context) {
    return Center(
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFF137A43), width: 3.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF137A43).withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const ClipOval(
          child: CircleAvatar(
            backgroundColor: Color(0xFFE8F5E9),
            child: Icon(
              Icons.person_rounded,
              size: 75,
              color: Color(0xFF137A43),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFieldsSection() {
    final String name = _memberData?['name'] ?? '-';
    final String phone = _memberData?['phone'] ?? _memberData?['no_hp'] ?? '-';
    final String address = _memberData?['address'] ?? '-';
    final String status = _memberData?['status'] ?? 'aktif';
    final String memberNo = _memberData?['member_number'] ?? _memberData?['no_register'] ?? _memberId ?? '-';

    return Container(
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
          // 1. Nama Lengkap (Read-only)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF137A43).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF137A43),
                size: 22,
              ),
            ),
            title: const Text(
              'Nama Lengkap',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hubungi admin koperasi jika ingin mengubah Nama lengkap',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 64),

          // 2. Nomor WhatsApp / HP (Read-only)
          _buildReadOnlyTile(
            icon: Icons.phone_android_outlined,
            label: 'Nomor WhatsApp / HP',
            value: phone,
          ),
          const Divider(height: 1, indent: 64),

          // 3. Alamat Tempat Tinggal (Read-only)
          _buildReadOnlyTile(
            icon: Icons.location_on_outlined,
            label: 'Alamat Tempat Tinggal',
            value: address,
          ),
          const Divider(height: 1, indent: 64),

          // 4. Tanggal Bergabung (Read-only)
          _buildReadOnlyTile(
            icon: Icons.calendar_month_outlined,
            label: 'Tanggal Bergabung',
            value: _memberData?['joined_at'] ?? _memberData?['created_at'] ?? '-',
          ),
          const Divider(height: 1, indent: 64),

          // 5. Status Keanggotaan (Read-only)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF10B981),
                size: 22,
              ),
            ),
            title: const Text(
              'Status Keanggotaan',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Anggota ${status.toUpperCase()} (ID: #$memberNo)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF137A43).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF137A43),
          size: 22,
        ),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }
}