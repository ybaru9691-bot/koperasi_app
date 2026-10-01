import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../utils/whatsapp_helper.dart';
import '../../widgets/curved_text.dart';
import '../dashboard_router.dart';


// SECTION 1: KONFIGURASI & KONSTANTA
// ✅ DIPERBAIKI: Path aset dibersihkan dari duplikasi & ekstensi ganda (.png.jpg)
const String _kLogoPath = 'assets/images/logo_koperasi.png';
const String _kAppTitle = 'CREDO UNION MODIFIKASI';
const String _kAppDescription =
    'APLIKASI RESMI UNTUK CREDO UNION MODIFIKASI';
const String _kPrimaryButtonText = 'Masuk dengan Nomor KTP (NIK)';
/// Teks bantuan registrasi anggota baru
const String _kUnregisteredPrefixText = 'Belum terdaftar? ';
const String _kContactAdminText = 'Registrasi Anggota';

// ✅ DIPERBAIKI: Menggantikan teks OJK dengan legalitas Kemenkop UKM
const String _kOjkText = 'Aman dan Terpercaya';
const String _kVersionSecurityText = 'Versi 1.0.0 • Keamanan Terenkripsi';


// SECTION 2: WELCOME SCREEN WIDGET (LOGIN 2 LANGKAH)
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final TapGestureRecognizer _contactAdminTapRecognizer;

  @override
  void initState() {
    super.initState();
    _contactAdminTapRecognizer = TapGestureRecognizer()
      ..onTap = _onContactAdminTap;
  }

  /// Callback ketika calon anggota mengeklik "Registrasi Anggota" (Membuka WA Petugas)
  Future<void> _onContactAdminTap() async {
    await WhatsAppHelper.showContactBottomSheet(
      context,
      memberName: 'Calon Anggota',
      memberNumber: '-',
      customHeaderTitle: 'Registrasi & Layanan Anggota',
    );
  }

  /// Membuka Modal Bottom Sheet Login 2 Langkah (Langkah 1: NIK, Langkah 2: PIN 6 Digit)
  void _showTwoStepLoginBottomSheet(BuildContext context) {
    int currentStep = 1; // 1 = NIK, 2 = PIN
    String enteredNik = '';
    bool isPinObscured = true;
    bool isSubmitting = false;
    int pinShakeTrigger = 0;
    String? pinErrorMessage;

    final TextEditingController nikController = TextEditingController();
    final TextEditingController pinController = TextEditingController();
    final FocusNode nikFocusNode = FocusNode();
    final FocusNode pinFocusNode = FocusNode();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        // Auto focus input pertama
        Future.delayed(const Duration(milliseconds: 150), () {
          if (bottomSheetContext.mounted) {
            nikFocusNode.requestFocus();
          }
        });

        return StatefulBuilder(
          builder: (context, setModalState) {
            void handleContinueToPin() {
              final String rawNik = nikController.text.trim();
              if (rawNik.length == 16) {
                enteredNik = rawNik;
                setModalState(() {
                  currentStep = 2;
                });
                Future.delayed(
                  const Duration(milliseconds: 100),
                  () {
                    pinFocusNode.requestFocus();
                  },
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Nomor KTP (NIK) harus 16 digit angka!',
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            Future<void> handleLoginSubmit() async {
              if (isSubmitting) return;

              if (pinController.text.length < 6) {
                setModalState(() {
                  pinErrorMessage = 'PIN / Password minimal 6 karakter!';
                  pinShakeTrigger++;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'PIN / Password minimal 6 karakter!',
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              FocusScope.of(context).unfocus();

              setModalState(() {
                isSubmitting = true;
                pinErrorMessage = null;
              });

              final result = await AuthService().login(
                nik: nikController.text.isNotEmpty
                    ? nikController.text
                    : enteredNik,
                pin: pinController.text,
              );

              if (bottomSheetContext.mounted) {
                setModalState(() {
                  isSubmitting = false;
                });
              }

              if (result['success'] == true) {
                if (bottomSheetContext.mounted) {
                  Navigator.pop(bottomSheetContext);
                }
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DashboardRouter(),
                    ),
                  );
                }
              } else {
                // 1. AUTO-CLEAR & RE-FOCUS
                pinController.clear();
                
                final String errorMsg = result['message'] ?? 'PIN keamanan salah. Silakan coba lagi.';

                setModalState(() {
                  pinErrorMessage = errorMsg;
                  pinShakeTrigger++;
                });

                Future.delayed(const Duration(milliseconds: 100), () {
                  if (bottomSheetContext.mounted) {
                    pinFocusNode.requestFocus();
                  }
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar Modal
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Indikator Progress Langkah (Step 1 vs Step 2)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF137A43,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'LANGKAH $currentStep DARI 2',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF137A43),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (currentStep == 2)
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              currentStep = 1;
                            });
                            Future.delayed(
                              const Duration(milliseconds: 100),
                              () {
                                nikFocusNode.requestFocus();
                              },
                            );
                          },
                          child: const Text(
                            'Ubah NIK',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF137A43),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  
                  // LANGKAH 1: INPUT NOMOR NIK / KK                
                  if (currentStep == 1) ...[
                    const Text(
                      'Masukkan Nomor KTP (NIK)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A2540),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gunakan 16 digit Nomor KTP (NIK) Anda yang sudah terdaftar.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF5A6A85)),
                    ),
                    const SizedBox(height: 20),

                    // Form Input NIK
                    TextField(
                      controller: nikController,
                      focusNode: nikFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => handleContinueToPin(),
                      onChanged: (value) {
                        if (value.trim().length == 16) {
                          FocusScope.of(context).unfocus();
                          handleContinueToPin();
                        }
                      },
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: InputDecoration(
                        hintText: '3271xxxxxxxxxxxx',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.normal,
                        ),
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: Color(0xFF137A43),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF137A43),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Tombol Lanjut ke PIN
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: handleContinueToPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF137A43),
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Lanjut ke PIN Keamanan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],

                  
                  // LANGKAH 2: INPUT PIN 6 DIGIT               
                  if (currentStep == 2) ...[
                    const Text(
                      'Masukkan 6 Digit PIN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A2540),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Verifikasi masuk untuk KTP: $enteredNik',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5A6A85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Form Input PIN 6 Digit dengan Shake Animation saat salah
                    TweenAnimationBuilder<double>(
                      key: ValueKey(pinShakeTrigger),
                      tween: Tween(begin: 0.0, end: pinShakeTrigger > 0 ? 1.0 : 0.0),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, animValue, child) {
                        final offset = math.sin(animValue * math.pi * 6) * 10 * (1 - animValue);
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: TextField(
                        controller: pinController,
                        focusNode: pinFocusNode,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (pinController.text.length == 6) {
                            handleLoginSubmit();
                          }
                        },
                        onChanged: (value) {
                          if (pinErrorMessage != null) {
                            setModalState(() {
                              pinErrorMessage = null;
                            });
                          }
                          if (value.trim().length == 6) {
                            handleLoginSubmit();
                          }
                        },
                        obscureText: isPinObscured,
                        obscuringCharacter: '•',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8.0,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          hintText: '••••••',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            letterSpacing: 6.0,
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF137A43),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPinObscured
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              setModalState(() {
                                isPinObscured = !isPinObscured;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: pinErrorMessage != null ? Colors.redAccent : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: pinErrorMessage != null ? Colors.redAccent : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: pinErrorMessage != null ? Colors.redAccent : const Color(0xFF137A43),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (pinErrorMessage != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                pinErrorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Teks Bantuan Lupa PIN
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          WhatsAppHelper.showContactBottomSheet(
                            context,
                            memberName: enteredNik.isNotEmpty ? 'Anggota (NIK: $enteredNik)' : 'Anggota',
                            memberNumber: '-',
                            customHeaderTitle: 'Bantuan Reset PIN Akun',
                          );
                        },
                        child: const Text(
                          'Lupa PIN?',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF137A43),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tombol Masuk Aplikasi
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : handleLoginSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF137A43),
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Masuk Aplikasi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _contactAdminTapRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Expanded(child: _buildHeader()),
                      _buildBottomCard(context),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 280,
            height: 160,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  child: _buildLogoContainer(),
                ),
                Positioned(
                  top: 55,
                  child: CurvedText(
                    text: _kAppTitle,
                    radius: 80,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD32F2F),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoContainer() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052CC).withValues(alpha: 0.08),
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
            _kLogoPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.account_balance_rounded,
                size: 54,
                color: Color(0xFF0052CC),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28.0, 36.0, 28.0, 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            _kAppDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFF5A6A85),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),

          // Tombol Masuk Utama (Membuka Modal Login 2 Langkah)
          OutlinedButton(
            onPressed: () => _showTwoStepLoginBottomSheet(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              side: BorderSide(
                color: const Color(0xFF0052CC).withValues(alpha: 0.3),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A2540),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.badge_outlined, color: Color(0xFF0052CC), size: 20),
                SizedBox(width: 10),
                Text(
                  _kPrimaryButtonText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A2540),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Informasi Hubungi Petugas Koperasi
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: _kUnregisteredPrefixText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.normal,
                  ),
                  children: [
                    TextSpan(
                      text: _kContactAdminText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0052CC),
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: _contactAdminTapRecognizer,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Footer
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: const Color(0xFF718096).withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _kOjkText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF718096).withValues(alpha: 0.9),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _kVersionSecurityText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFFA0AEC0).withValues(alpha: 0.9),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
