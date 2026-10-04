import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../data/models/period_model.dart';
import '../../services/auth_service.dart';
import 'widgets/period_components.dart';

//HALAMAN UTAMA MANAJEMEN PERIODE & TUTUP BUKU KETUA KOPERASI (DINAMIS API)
class PeriodManagementScreen extends StatefulWidget {
  final Function(String periodId, String confirmPassword)? onClosePeriodCallback;

  const PeriodManagementScreen({
    super.key,
    this.onClosePeriodCallback,
  });

  @override
  State<PeriodManagementScreen> createState() => _PeriodManagementScreenState();
}

class _PeriodManagementScreenState extends State<PeriodManagementScreen> {
  PeriodModel? _activePeriod;
  List<PeriodModel> _periodHistory = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isProcessingClose = false;

  @override
  void initState() {
    super.initState();
    _fetchPeriodData();
  }

  Future<void> _fetchPeriodData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Sesi tidak ditemukan. Silakan login kembali.';
            _isLoading = false;
          });
        }
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/periods/active');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final dynamic rawData = responseData['data'] ?? responseData['periods'] ?? responseData;

        PeriodModel? active;
        List<PeriodModel> history = [];

        // 1. Ambil active_period dari responseData / rawData
        final dynamic activeRaw = responseData['active_period'] ?? (rawData is Map ? rawData['active_period'] : null);
        if (activeRaw is Map) {
          active = PeriodModel.fromJson(Map<String, dynamic>.from(activeRaw));
        }

        // 2. Ambil locked_periods / history_locked_periods
        final dynamic lockedRaw = responseData['locked_periods'] ??
            (rawData is Map ? (rawData['locked_periods'] ?? rawData['history_locked_periods'] ?? rawData['history_periods'] ?? rawData['history']) : null);

        if (lockedRaw is List) {
          history = lockedRaw
              .map((item) => PeriodModel.fromJson(Map<String, dynamic>.from(item)))
              .where((p) => p.isLocked || p.status == 'closed' || p.status == 'dikunci' || p.status == 'locked')
              .toList();
        }

        // 3. Fallback jika active masih null
        if (active == null) {
          if (rawData is Map<String, dynamic> && (rawData['period_name'] != null || rawData['name'] != null)) {
            final p = PeriodModel.fromJson(rawData);
            if (!p.isLocked && (p.status == 'open' || p.status == 'terbuka' || p.status == 'active')) {
              active = p;
            }
          } else if (rawData is List) {
            for (var item in rawData) {
              final p = PeriodModel.fromJson(Map<String, dynamic>.from(item));
              if (!p.isLocked && (p.status == 'open' || p.status == 'terbuka' || p.status == 'active')) {
                active ??= p;
              } else {
                history.add(p);
              }
            }
          }
        }

        active ??= PeriodModel.getActivePeriod();

        setState(() {
          _activePeriod = active;
          _periodHistory = history;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Gagal memuat data periode (Status ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handleClosePeriod() {
    if (_activePeriod == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ClosePeriodConfirmDialog(
          period: _activePeriod!,
          onSubmitClose: () {
            _closePeriod();
          },
        );
      },
    );
  }

  void _showOpenNewPeriodDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return OpenNewPeriodDialog(
          onSubmitOpen: ({
            required String periodName,
            required DateTime startDate,
            required DateTime endDate,
          }) {
            _openNewPeriodApi(
              periodName: periodName,
              startDate: startDate,
              endDate: endDate,
            );
          },
        );
      },
    );
  }

  String _getIndoMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[(month - 1) % 12];
  }

  Future<void> _openNewPeriodApi({
    required String periodName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi tidak ditemukan. Silakan login kembali.')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/periods/open-period');

      final String isoStartDate = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final String isoEndDate = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      final String formattedStart = "${startDate.day.toString().padLeft(2, '0')} ${_getIndoMonthName(startDate.month)} ${startDate.year}";
      final String formattedEnd = "${endDate.day.toString().padLeft(2, '0')} ${_getIndoMonthName(endDate.month)} ${endDate.year}";

      final Map<String, dynamic> payload = {
        'name': periodName,
        'period_name': periodName,
        'start_date': isoStartDate,
        'end_date': isoEndDate,
        'start_date_formatted': formattedStart,
        'end_date_formatted': formattedEnd,
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message'] ?? 'Periode baru "$periodName" berhasil dibuka.',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _fetchPeriodData();
      } else {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Gagal membuka periode baru.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        final String formattedStart = "${startDate.day.toString().padLeft(2, '0')} ${_getIndoMonthName(startDate.month)} ${startDate.year}";
        final String formattedEnd = "${endDate.day.toString().padLeft(2, '0')} ${_getIndoMonthName(endDate.month)} ${endDate.year}";

        setState(() {
          _activePeriod = PeriodModel(
            id: 'PER-${startDate.year}-${endDate.year}',
            periodName: periodName,
            startDate: formattedStart,
            endDate: formattedEnd,
            status: 'terbuka',
            totalTransactions: 0,
            remainingDays: endDate.difference(DateTime.now()).inDays,
            isLocked: false,
          );
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Periode baru "$periodName" berhasil diatur.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _closePeriod() async {
    if (!mounted) return;
    setState(() {
      _isProcessingClose = true;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi tidak ditemukan. Silakan login kembali.')),
          );
          setState(() => _isProcessingClose = false);
        }
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/periods/close-period');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'period_id': _activePeriod?.id,
        }),
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    responseData['message'] ?? 'Periode berhasil ditutup dan periode baru telah dibuka.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );

        if (widget.onClosePeriodCallback != null && _activePeriod != null) {
          widget.onClosePeriodCallback!(_activePeriod!.id, '');
        }

        // Refresh data periode
        await _fetchPeriodData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Gagal menutup periode.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal terhubung ke server: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingClose = false;
        });
      }
    }
  }

  Future<void> _unlockPeriod(dynamic id) async {
    final String periodId = (id ?? '').toString().trim();
    debugPrint("Calling unlock for Period ID: $periodId");

    if (periodId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID Periode tidak valid (kosong).'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi tidak ditemukan. Silakan login kembali.')),
          );
        }
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/periods/$periodId/unlock');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      final Map<String, dynamic> resData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resData['message'] ?? 'Kunci periode berhasil dibuka.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _fetchPeriodData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resData['message'] ?? 'Gagal membuka kunci periode (Status ${response.statusCode}).'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePeriod(dynamic id) async {
    final String periodId = (id ?? '').toString().trim();
    debugPrint("Calling delete for Period ID: $periodId");

    if (periodId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID Periode tidak valid (kosong).'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi tidak ditemukan. Silakan login kembali.')),
          );
        }
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/periods/$periodId');

      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      Map<String, dynamic> resData = {};
      try {
        if (response.body.isNotEmpty) {
          resData = jsonDecode(response.body);
        }
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resData['message'] ?? 'Periode berhasil dihapus.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _fetchPeriodData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resData['message'] ?? 'Gagal menghapus periode (Status ${response.statusCode}).'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmUnlockDialog(PeriodModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Buka Kunci Periode?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Tindakan ini akan mengizinkan kembali perubahan transaksi pada periode ${item.periodName}.',
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _unlockPeriod(item.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Buka Kunci'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDialog(PeriodModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text('Hapus Periode?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data periode ${item.periodName}? Tindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deletePeriod(item.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus Periode'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: AppColors.adminCanvas,
          appBar: AppBar(
            backgroundColor: AppColors.adminNavy,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text(
              'Manajemen Periode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(80.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : _hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            Text(_errorMessage ?? 'Gagal memuat data periode', textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchPeriodData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24.0 : 12.0,
                        vertical: 16.0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 850),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. CARD STATUS PERIODE AKTIF
                              if (_activePeriod != null && !_activePeriod!.isLocked)
                                ActivePeriodCard(period: _activePeriod!),

                              const SizedBox(height: 20),

                              // 2. WARNING CARD (PERINGATAN KEAMANAN RED BOX)
                              const SecurityWarningCard(),

                              const SizedBox(height: 24),

                              // 3. ACTION BUTTONS (ATUR TANGGAL PERIODE BARU & TUTUP BUKU)
                              Builder(
                                builder: (context) {
                                  final bool isLocked = _activePeriod?.isLocked ?? false;
                                  final bool isProcessingClose = _isProcessingClose;

                                  return Center(
                                    child: Column(
                                      children: [
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            // Tombol 1: Buka Periode Baru / Atur Tanggal
                                            SizedBox(
                                              width: isDesktop ? 340 : double.infinity,
                                              height: 48,
                                              child: OutlinedButton.icon(
                                                onPressed: _showOpenNewPeriodDialog,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppColors.adminNavy,
                                                  side: const BorderSide(color: AppColors.adminNavy, width: 1.5),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                                icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                                                label: const Text(
                                                  '+ Buka Periode Baru / Atur Tanggal',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Tombol 2: Tutup Buku & Kunci Periode
                                            SizedBox(
                                              width: isDesktop ? 340 : double.infinity,
                                              height: 48,
                                              child: ElevatedButton.icon(
                                                onPressed: (isLocked || isProcessingClose)
                                                    ? null
                                                    : _handleClosePeriod,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.danger,
                                                  foregroundColor: Colors.white,
                                                  elevation: 2,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                                icon: isProcessingClose
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                      )
                                                    : const Icon(Icons.lock_outline_rounded, size: 20),
                                                label: Text(
                                                  isLocked
                                                      ? 'Periode Telah Dikunci'
                                                      : 'Tutup Buku & Kunci Periode',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Otoritas Manajer / Ketua Koperasi Diperlukan',
                                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 32),
                              const Divider(height: 1, color: AppColors.cardBorder),
                              const SizedBox(height: 20),

                              // 4. RIWAYAT PERIODE AKUNTANSI SEBELUMNYA (ARSIP)
                              const Row(
                                children: [
                                  Icon(Icons.history_rounded, color: AppColors.adminNavy, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Riwayat Periode Akuntansi (Arsip Dikunci)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.adminNavy,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              if (_periodHistory.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Belum ada arsip periode yang dikunci',
                                      style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _periodHistory.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = _periodHistory[index];
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.cardBorder),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.periodName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.adminNavy,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${item.startDate} - ${item.endDate} • ${item.totalTransactions} Transaksi',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.cardBorder,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.lock_rounded, size: 12, color: AppColors.textSecondary),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'DIKUNCI',
                                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              // 1. Tombol Buka Kunci (Icon Gembok Terbuka) -> POST /api/manager/periods/{id}/unlock
                                              IconButton(
                                                tooltip: 'Buka Kunci Periode',
                                                icon: const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 20),
                                                onPressed: () => _confirmUnlockDialog(item),
                                              ),
                                              // 2. Tombol Hapus (Icon Sampah Merah) -> DELETE /api/manager/periods/{id}
                                              IconButton(
                                                tooltip: 'Hapus Periode',
                                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                                onPressed: () => _confirmDeleteDialog(item),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
        );
      },
    );
  }
}
