import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'admin/admin_main_screen.dart';
import 'ketua/dashboard_ketua_screen.dart';
import 'member/home_screen.dart';


// SECTION 1: DASHBOARD ROUTER (PENENTU ROLE UTAMA)
class DashboardRouter extends StatefulWidget {
  const DashboardRouter({super.key});

  @override
  State<DashboardRouter> createState() => _DashboardRouterState();
}
class _DashboardRouterState extends State<DashboardRouter> {
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }


  //Membaca role pengguna secara asynchronous dari SharedPreferences & Storage
  Future<void> _checkUserRole() async {
    String role = 'anggota';

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? roleFromPrefs = prefs.getString('user_role');

      if (roleFromPrefs != null && roleFromPrefs.isNotEmpty) {
        role = roleFromPrefs;
      } else {
        role = await AuthService().getUserRole();
      }
    } catch (e) {
      debugPrint("Error membaca role SharedPreferences: $e");
    }

    final String cleanRole = role.trim().toLowerCase();

    // Print Log Debug Wajib Sesuai Spesifikasi
    // ignore: avoid_print
    print("DEBUG ROLE TERBACA: $cleanRole");
    debugPrint("DEBUG ROLE TERBACA: $cleanRole");

    if (!mounted) return;
    setState(() {
      _userRole = cleanRole;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    
    // Pengecekan String Role ('admin', 'manajer' / 'ketua', vs 'anggota')
    if (_userRole == 'admin') {
      return const AdminMainScreen();
    } else if (_userRole == 'manajer' || _userRole == 'manager' || _userRole == 'ketua') {
      return const DashboardKetuaScreen();
    } else {
      return const AnggotaDashboardScreen();
    }
  }
}


// SECTION 2: ANGGOTA DASHBOARD SCREEN (KHUSUS ROLE ANGGOTA)
class AnggotaDashboardScreen extends StatelessWidget {
  const AnggotaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Menampilkan Tampilan Utama Aplikasi Anggota (HomeScreen dengan Shell Navigation)
    return const HomeScreen();
  }
}