import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

/// Controller terpisah untuk mengelola state Login & Autentikasi dengan keamanan memori (Dispose-Safe)
class AuthController extends ChangeNotifier {
  bool _isLoading = false;
  bool _isDisposed = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  /// Memproses Login NIK & PIN secara aman dengan logging lengkap
  Future<bool> processLogin({
    required String nik,
    required String pin,
  }) async {
    debugPrint('[AUTH_CONTROLLER] Memulai alur login NIK: $nik dengan PIN 6-digit');

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final Map<String, dynamic> result = await AuthService().login(
      nik: nik,
      pin: pin,
    );

    if (_isDisposed) {
      debugPrint('[AUTH_CONTROLLER] Controller telah di-dispose. Membatalkan update state.');
      return result['success'] == true;
    }

    _isLoading = false;

    if (result['success'] == true) {
      debugPrint('[AUTH_CONTROLLER] Login NIK & PIN sukses!');
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Login Gagal.';
      debugPrint('[AUTH_CONTROLLER] Login gagal: $_errorMessage');
      notifyListeners();
      return false;
    }
  }
}
