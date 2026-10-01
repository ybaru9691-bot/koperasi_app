import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service terpusat untuk memantau status koneksi internet secara real-time
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// ValueNotifier status offline (true = Offline / Putus, false = Online)
  final ValueNotifier<bool> isOfflineNotifier = ValueNotifier<bool>(false);

  /// Stream Controller untuk memberi sinyal otomatis saat internet terhubung kembali (Reconnected)
  final StreamController<bool> _reconnectionController =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _wasOffline = false;

  /// Stream yang memberikan event saat internet pulih kembali
  Stream<bool> get onReconnected => _reconnectionController.stream;

  /// Inisialisasi pemantauan koneksi real-time
  void initialize() {
    _subscription?.cancel();
    _checkInitialConnectivity();
    _subscription =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  /// Pengecekan awal saat aplikasi dibuka
  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking initial connectivity: $e');
      }
    }
  }

  /// Penanganan perubahan status koneksi
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    // Memeriksa apakah koneksi terputus (Tidak ada WiFi, Mobile, maupun Ethernet)
    final bool isOffline = results.isEmpty ||
        results.contains(ConnectivityResult.none) ||
        !results.any((r) => r != ConnectivityResult.none);

    if (isOffline) {
      _wasOffline = true;
      isOfflineNotifier.value = true;
    } else {
      isOfflineNotifier.value = false;
      // Jika sebelumnya offline lalu terhubung kembali, pemicu event Reconnected
      if (_wasOffline) {
        _wasOffline = false;
        _reconnectionController.add(true);
      }
    }
  }

  /// Release resource saat service tidak digunakan
  void dispose() {
    _subscription?.cancel();
    isOfflineNotifier.dispose();
    _reconnectionController.close();
  }
}
