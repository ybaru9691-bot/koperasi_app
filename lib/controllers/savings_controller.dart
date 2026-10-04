import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/savings_model.dart';
import '../services/auth_service.dart';

/// Controller terpisah untuk mengelola state & logika bisnis halaman Simpanan
class SavingsController extends ChangeNotifier {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String _selectedFilter = 'Semua';

  // Melacak status dispose agar aman dari memory leak
  bool _isDisposed = false;

  List<SavingsMutationModel> _mutationsList = [];
  List<SavingsDetailModel> _savingsTypesList = [];
  double _totalBalance = 0.0;
  String _memberNumber = '';
  String? _bukuPutihNo;
  bool _hasBukuBiru = true;
  bool _hasBukuPutih = true;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  String get selectedFilter => _selectedFilter;

  List<SavingsMutationModel> get mutationsList => _mutationsList;
  List<SavingsDetailModel> get savingsTypesList => _savingsTypesList;
  double get totalBalance => _totalBalance;
  String get memberNumber => _memberNumber;
  String? get bukuPutihNo => _bukuPutihNo;
  bool get hasBukuBiru => _hasBukuBiru;
  bool get hasBukuPutih => _hasBukuPutih;

  double _principalSavings = 0.0;
  double _mandatorySavings = 0.0;
  double _voluntarySavings = 0.0;

  double get principalSavings => _principalSavings;
  double get mandatorySavings => _mandatorySavings;
  double get voluntarySavings => _voluntarySavings;
  double get totalSaham => _principalSavings + _mandatorySavings + _voluntarySavings;

  String _selectedBook = 'Buku Biru';
  String get selectedBook => _selectedBook;

  void selectBook(String book) {
    _selectedBook = book;
    notifyListeners();
  }

  double _dailySavings = 0.0;
  double get dailySavings => _dailySavings;

  double get displayTotalBalance {
    if (_selectedBook == 'Buku Biru') {
      return totalSaham;
    } else {
      if (!_hasBukuPutih || _dailySavings == 0) return 0.0;
      return _dailySavings;
    }
  }

  List<SavingsDetailModel> get displaySavingsTypesList {
    if (_selectedBook == 'Buku Biru') {
      return _savingsTypesList;
    } else {
      final double sh = displayTotalBalance;
      final String bpAccNo = (_bukuPutihNo != null && _bukuPutihNo!.isNotEmpty && _bukuPutihNo != '-')
          ? _bukuPutihNo!
          : (_memberNumber.isNotEmpty && _memberNumber != '-' ? _bukuPutihNo ?? '-' : '-');
      return [
        SavingsDetailModel(
          id: 'sh',
          title: 'Tabungan Harian',
          accountNumber: bpAccNo,
          balance: sh,
          icon: Icons.auto_graph_rounded,
          color: const Color(0xFF1E88E5),
          description:
              'Tabungan harian sukarela anggota yang fleksibel dan aman.',
        )
      ];
    }
  }

  List<SavingsMutationModel> get displayMutationsList {
    return _mutationsList.where((m) {
      final titleLower = m.title?.toLowerCase() ?? '';
      final catLower = m.savingsType?.toLowerCase() ?? '';
      final isWhiteBook = titleLower.contains('harian') || titleLower.contains('putih') ||
                          catLower.contains('harian') || catLower.contains('putih');
      if (_selectedBook == 'Buku Biru') {
        return !isWhiteBook;
      } else {
        return isWhiteBook;
      }
    }).toList();
  }

  List<SavingsMutationModel> get filteredMutations {
    final current = _selectedFilter.toLowerCase().trim();

    return displayMutationsList.where((m) {
      // 1. Identifikasi apakah transaksi merupakan bunga
      final title = (m.title ?? '').toLowerCase();
      final cat = (m.category ?? '').toLowerCase();
      final isBunga = m.type == MutationType.bunga || 
                      cat == 'bunga_simpanan' || 
                      title.contains('bunga') || 
                      cat.contains('bunga');

      // 2. Tab Semua
      if (current == 'semua' || current == 'all' || current == '') {
        return true;
      }

      // 3. Tab Bunga
      if (current == 'bunga') {
        return isBunga;
      }

      // 4. Tab Setor (Seluruh mutasi uang masuk yang BUKAN bunga)
      if (current == 'setor') {
        return !isBunga && (m.isCredit == true || m.type == MutationType.setor);
      }

      // 5. Tab Tarik (Mutasi uang keluar)
      if (current == 'tarik') {
        return !isBunga && (m.isCredit == false || m.type == MutationType.tarik);
      }

      return true;
    }).toList();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

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

  /// Helper untuk memastikan parsing double aman dari int/string/null
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Mengambil data simpanan dari Laravel API secara dinamis
  Future<void> fetchSavingsData() async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final authService = AuthService();
      final user = await authService.getSavedUser();
      final token = await authService.getToken();

      if (user == null || token == null) {
        _hasError = true;
        _errorMessage = 'Sesi tidak ditemukan. Silakan login kembali.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final memberId = user['member_id'] ?? user['id'];
      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/members/$memberId/details');

      debugPrint('[SAVINGS_LOG] Fetching savings details from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      debugPrint('[SAVINGS_LOG] Response status: ${response.statusCode}');
      debugPrint('[SAVINGS_LOG] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Pengecekan Fleksibel Status 'success' (Bisa berupa bool true atau string 'success')
        final bool isSuccess = responseData['success'] == true ||
            responseData['status'] == 'success' ||
            responseData['status'] == true;

        if (isSuccess && responseData['data'] != null) {
          final data = responseData['data'];

          // 0. Map Status Kepemilikan Buku
          _hasBukuBiru = data['has_buku_biru'] == null ? true : (data['has_buku_biru'] == true || data['has_buku_biru'] == 1 || data['has_buku_biru'] == '1');
          _hasBukuPutih = data['has_buku_putih'] == null ? true : (data['has_buku_putih'] == true || data['has_buku_putih'] == 1 || data['has_buku_putih'] == '1');

          // 1. Map Nomor Anggota & Buku Putih (Cek berbagai variasi nama kolom dari Laravel)
          final String memberNo = data['member_number']?.toString() ??
              data['no_anggota']?.toString() ??
              data['no_register']?.toString() ??
              data['member_no']?.toString() ??
              '-';
          _memberNumber = memberNo;

          final dynamic rawBp = data['buku_putih_no'] ??
              data['no_rekening_buku_putih'] ??
              data['buku_putih_account_no'] ??
              data['buku_putih_number'] ??
              data['no_buku_putih'] ??
              data['buku_putih_rek'] ??
              data['rekening_buku_putih'];
          String? parsedBp;
          if (rawBp != null && rawBp is! Map && rawBp is! List) {
            final s = rawBp.toString().trim();
            if (s.isNotEmpty && s != '-' && s != 'null' && !s.startsWith('{')) {
              parsedBp = s.startsWith('2021-') ? s : '2021-$s';
            }
          }
          _bukuPutihNo = parsedBp;

          // 2. Map Saldo Simpanan 
          final simpanan = data['simpanan'] ?? data;

          final double sp = _parseDouble(
            simpanan['principal_savings'] ??
                simpanan['simpanan_pokok'] ??
                simpanan['pokok'],
          );
          final double sw = _parseDouble(
            simpanan['mandatory_savings'] ??
                simpanan['simpanan_wajib'] ??
                simpanan['wajib'],
          );
          final double ss = _parseDouble(
            simpanan['voluntary_savings'] ??
                simpanan['simpanan_sukarela'] ??
                simpanan['sukarela'],
          );

          _principalSavings = sp;
          _mandatorySavings = sw;
          _voluntarySavings = ss;

          final double sh = _parseDouble(
            simpanan['daily_savings'] ??
                simpanan['buku_putih'] ??
                simpanan['simpanan_harian'] ??
                simpanan['tabungan_harian'] ??
                simpanan['sh'],
          );
          _dailySavings = sh;

          _totalBalance = sp + sw + ss;

          _savingsTypesList = [
            SavingsDetailModel(
              id: 'sp',
              title: 'Simpanan Pokok',
              accountNumber: 'SP-$memberNo',
              balance: sp,
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF137A43),
              description:
                  'Simpanan awal anggota yang tidak dapat ditarik selama menjadi anggota.',
            ),
            SavingsDetailModel(
              id: 'sw',
              title: 'Simpanan Wajib',
              accountNumber: 'SW-$memberNo',
              balance: sw,
              icon: Icons.savings_outlined,
              color: const Color(0xFF1C7C54),
              description:
                  'Simpanan bulanan rutin anggota sesuai ketentuan koperasi.',
            ),
            SavingsDetailModel(
              id: 'ss',
              title: 'Simpanan Sukarela',
              accountNumber: 'SS-$memberNo',
              balance: ss,
              icon: Icons.payments_outlined,
              color: const Color(0xFF2E8B57),
              description:
                  'Simpanan fleksibel yang dapat disetor & ditarik sewaktu-waktu.',
            ),
          ];

          // 3. Map Transaksi / Mutasi Simpanan
          final List<dynamic> txRaw = data['transactions'] ??
              data['mutations'] ??
              data['mutasi'] ??
              [];

          final List<SavingsMutationModel> parsedMutations = [];

          for (var item in txRaw) {
            final double amount = _parseDouble(item['amount'] ?? item['jumlah'] ?? item['nominal']);
            final String category = (item['category'] ?? item['jenis_simpanan'] ?? '').toString();
            final String title = (item['title'] ?? item['description'] ?? item['keterangan'] ?? 'Transaksi Koperasi').toString();
            final String typeStr = (item['type'] ?? '').toString().toLowerCase();

            final String lowerCategory = category.toLowerCase();
            final String lowerTitle = title.toLowerCase();

            final bool isBunga = category == 'bunga_simpanan' ||
                lowerCategory.contains('bunga') ||
                lowerCategory.contains('jasa') ||
                lowerCategory.contains('deviden') ||
                lowerTitle.contains('bunga') ||
                lowerTitle.contains('jasa') ||
                lowerTitle.contains('deviden');

            bool isExpense = false;
            if (isBunga) {
              isExpense = false;
            } else if (typeStr.contains('withdrawal') || typeStr.contains('keluar') || typeStr.contains('out') || typeStr.contains('tarik') || typeStr.contains('pinjam') ||
                lowerCategory.contains('withdrawal') || lowerCategory.contains('keluar') || lowerCategory.contains('out') || lowerCategory.contains('tarik') || lowerCategory.contains('pinjam') ||
                lowerTitle.contains('withdrawal') || lowerTitle.contains('keluar') || lowerTitle.contains('out') || lowerTitle.contains('tarik') || lowerTitle.contains('pinjam')) {
              isExpense = true;
            } else if (typeStr.contains('deposit') || typeStr.contains('masuk') || typeStr.contains('in') || typeStr.contains('setor') || typeStr.contains('simpan') ||
                       lowerCategory.contains('deposit') || lowerCategory.contains('masuk') || lowerCategory.contains('in') || lowerCategory.contains('setor') || lowerCategory.contains('simpan') ||
                       lowerTitle.contains('deposit') || lowerTitle.contains('masuk') || lowerTitle.contains('in') || lowerTitle.contains('setor') || lowerTitle.contains('simpan')) {
              isExpense = false;
            } else {
              isExpense = item['is_expense'] ?? false;
            }

            MutationType typeEnum = MutationType.setor;
            if (isBunga) {
              typeEnum = MutationType.bunga;
            } else if (isExpense) {
              typeEnum = MutationType.tarik;
            }

            final String rawReceipt = item['receipt_number']?.toString().trim() ?? '';
            final String proofCode = isExpense ? 'KK-$rawReceipt' : 'KM-$rawReceipt';

            final String rawDate = (item['date'] ?? item['created_at'] ?? '').toString();
            String formattedDate = rawDate;
            try {
              final parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
              formattedDate = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(parsedDate);
            } catch (_) {}

            parsedMutations.add(
              SavingsMutationModel(
                id: item['id']?.toString() ?? '',
                title: title,
                savingsType: (item['book_type'] == 'BUKU_PUTIH' || lowerCategory.contains('harian') || lowerCategory.contains('putih') || lowerTitle.contains('harian') || lowerTitle.contains('putih'))
                    ? 'Tabungan Harian'
                    : (item['savings_type'] ??
                        (lowerCategory.contains('pokok')
                            ? 'Simpanan Pokok'
                            : lowerCategory.contains('wajib')
                                ? 'Simpanan Wajib'
                                : 'Simpanan Sukarela')),
                category: category,
                date: formattedDate,
                amount: amount,
                isCredit: !isExpense,
                type: typeEnum,
                status: item['status']?.toString() ?? 'Berhasil',
                proofNumber: proofCode,
              ),
            );
          }

          _mutationsList = parsedMutations;
          _isLoading = false;
          _hasError = false;
        } else {
          _hasError = true;
          _errorMessage = responseData['message'] ?? 'Gagal memuat data simpanan.';
          _isLoading = false;
        }
      } else {
        _hasError = true;
        _errorMessage = 'Gagal memuat data (Status ${response.statusCode})';
        _isLoading = false;
      }
    } catch (e) {
      debugPrint('[SAVINGS_ERROR] Error fetching savings data: $e');
      _hasError = true;
      _errorMessage = 'Gagal terhubung ke server API: $e';
      _isLoading = false;
    } finally {
      notifyListeners();
    }
  }

  /// Mempertahankan kompatibilitas dengan pemanggilan fetchSimpananData di UI
  Future<void> fetchSimpananData() => fetchSavingsData();
}