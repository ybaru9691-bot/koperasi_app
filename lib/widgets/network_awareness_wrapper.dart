import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Widget Wrapper yang memantau koneksi internet real-time
/// dan menampilkan Banner Offline / Reconnected secara otomatis.
class NetworkAwarenessWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReconnected;

  const NetworkAwarenessWrapper({
    super.key,
    required this.child,
    this.onReconnected,
  });

  @override
  State<NetworkAwarenessWrapper> createState() =>
      _NetworkAwarenessWrapperState();
}

class _NetworkAwarenessWrapperState extends State<NetworkAwarenessWrapper>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _reconnectSubscription;

  bool _showReconnectedBanner = false;
  Timer? _reconnectedBannerTimer;

  @override
  void initState() {
    super.initState();
    _connectivityService.initialize();

    // Listen event Reconnected
    _reconnectSubscription = _connectivityService.onReconnected.listen((_) {
      if (mounted) {
        setState(() {
          _showReconnectedBanner = true;
        });

        // Trigger callback refetch jika ada
        widget.onReconnected?.call();

        // Sembunyikan banner reconnected setelah 3 detik
        _reconnectedBannerTimer?.cancel();
        _reconnectedBannerTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showReconnectedBanner = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _reconnectSubscription?.cancel();
    _reconnectedBannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _connectivityService.isOfflineNotifier,
      builder: (context, isOffline, _) {
        return Stack(
          children: [
            // Konten Utama Aplikasi
            widget.child,

            // Banner Offline (Orange / Red)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: isOffline ? 0 : -90,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Material(
                  elevation: 6,
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
                    margin: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFDC2626)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Koneksi Internet Terputus',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Menunggu jaringan terhubung kembali...',
                                style: TextStyle(
                                  color: Color(0xFFFEF3C7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Banner Reconnected (Hijau Koperasi)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: (!isOffline && _showReconnectedBanner) ? 0 : -90,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Material(
                  elevation: 6,
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
                    margin: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF137A43), Color(0xFF0F5A32)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.wifi_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Koneksi Terhubung Kembali',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Memuat ulang data terbaru secara otomatis...',
                                style: TextStyle(
                                  color: Color(0xFFD1FAE5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFFFFD700),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
