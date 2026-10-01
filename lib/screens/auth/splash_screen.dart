import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/curved_text.dart';
import '../dashboard_router.dart';
import 'welcome_screen.dart';

// SPLASH SCREEN WIDGET (SEQUENTIAL ANIMATION)
/// SplashScreen menampilkan animasi bertahap (Sequential Animation):
/// 1. Logo Bethania/HKBP dengan Fade-In (1s) dan tahan 1.5s
/// 2. Transisi Cross-Fade ke Logo CUM Pelita + Teks Melengkung
/// 3. Navigasi otomatis ke WelcomeScreen setelah sekuens selesai (~3.8s)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Animasi Logo 1 (Bethania)
  late Animation<double> _logo1FadeIn;
  late Animation<double> _logo1FadeOut;

  // Animasi Logo 2 (CUM Pelita + Curved Text)
  late Animation<double> _logo2FadeIn;
  late Animation<double> _logo2Scale;

  @override
  void initState() {
    super.initState();
    _initSequentialAnimations();
  }

  /// Inisialisasi sekuens animasi bertahap
  void _initSequentialAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.splashAnimationDuration,
    );

    // Phase 1: Logo 1 Fade-In (0.0 - 1.0s)
    _logo1FadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.26, curve: Curves.easeIn),
      ),
    );

    // Phase 2: Logo 1 Cross-Fade Exit (2.0 - 2.7s)
    _logo1FadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.71, curve: Curves.easeInOut),
      ),
    );

    // Phase 3: Logo 2 Fade-In (2.0 - 2.8s)
    _logo2FadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.73, curve: Curves.easeIn),
      ),
    );

    // Phase 3: Logo 2 Scale-In (2.0 - 2.8s)
    _logo2Scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.73, curve: Curves.easeOutCubic),
      ),
    );

    // Listener saat sekuens selesai -> Navigasi otomatis
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextScreen();
      }
    });

    _controller.forward();
  }

  /// Pengecekan status Sesi & Navigasi otomatis setelah sekuens animasi selesai
  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    final bool isSessionValid = await AuthService().isSessionValid();

    if (!mounted) return;

    if (isSessionValid) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardRouter()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Container Utama Sekuens Animasi (Center)
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Logo 1: Bethania / HKBP
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final double opacity =
                          _logo1FadeIn.value * _logo1FadeOut.value;
                      return Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: _buildBethaniaLogoSection(),
                      );
                    },
                  ),

                  // 2. Logo 2: CUM Pelita + Teks Melengkung
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logo2FadeIn.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: _logo2Scale.value,
                          child: _buildCumPelitaLogoSection(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Indikator Loading di Bagian Bawah
            Positioned(
              left: 0,
              right: 0,
              bottom: 42,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final Color activeColor = _logo2FadeIn.value > 0.5
                          ? AppColors.primary
                          : AppColors.navy;
                      return SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan Logo 1 (Bethania / HKBP)
  Widget _buildBethaniaLogoSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.1),
                blurRadius: 28,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset(
                AppAssets.logoBethania,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.church_rounded,
                    size: 56,
                    color: AppColors.navy,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'HKBP',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  /// Tampilan Logo 2 (CUM Pelita + Teks Melengkung)
  Widget _buildCumPelitaLogoSection() {
    return SizedBox(
      width: 280,
      height: 170,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.asset(
                    AppAssets.logoKoperasi,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.account_balance_rounded,
                        size: 54,
                        color: AppColors.primary,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 55,
            child: CurvedText(
              text: AppConstants.appTitle,
              radius: 80,
              textStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD32F2F),
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
