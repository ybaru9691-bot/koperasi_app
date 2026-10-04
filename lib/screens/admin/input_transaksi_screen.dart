import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../models/member_data_model.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/receipt_voucher_dialog.dart';

/// Screen "Input Transaksi Harian" Kasir / Admin Koperasi CUM Pelita
/// Menggunakan 15 Item KM & 18 Item KK Presisi Sesuai Kertas Bukti Penerimaan/Pengeluaran Kas
class InputTransaksiScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const InputTransaksiScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<InputTransaksiScreen> createState() => _InputTransaksiScreenState();
}

class _InputTransaksiScreenState extends State<InputTransaksiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0; // 0: Uang Masuk (KM), 1: Uang Keluar (KK)

  final _formKey = GlobalKey<FormState>();

  // 1. Flexible Inputs: Editable No. Bukti & Date Picker
  late TextEditingController _proofCodeController;
  late TextEditingController _customUraianLabelController;
  DateTime _selectedDate = DateTime.now();

  String _selectedMemberName = '';
  String _selectedMemberNo = '';
  String _selectedMemberNik = '';
  String? _selectedMemberId;
  bool _selectedMemberHasBukuBiru = true;

  String _paymentMethod = 'Tunai (Kas Utama - Akun 1000)';
  String _selectedBuku = 'Buku Biru';

  final List<String> _paymentMethodOptions = const [
    'Tunai (Kas Utama - Akun 1000)',
    'Transfer BRI',
  ];

  //  15 ITEM URAIAN KAS MASUK (KM) SESUAI BUKTI FISIK KERTAS
  final List<Map<String, String>> _kmItems = const [
    {'key': 'bank', 'label': 'Bank'},
    {'key': 'sp', 'label': 'Simpanan Pokok'},
    {'key': 'sw', 'label': 'Simpanan Wajib'},
    {'key': 'ss', 'label': 'Simpanan Sukarela'},
    {'key': 'angsuranPokok', 'label': 'Angsuran Piutang'},
    {'key': 'jasaPinjam', 'label': 'Jasa Piutang'},
    {'key': 'uangPangkal', 'label': 'Uang Pangkal'},
    {'key': 'denda', 'label': 'Denda'},
    {'key': 'provisi', 'label': 'Provisi'},
    {'key': 'simpananHarian', 'label': 'Simpanan Harian'},
    {'key': 'simpananDiakonia', 'label': 'Simpanan Diakonia'},
    {'key': 'dana', 'label': 'Dana'},
    {'key': 'asuransiInvestasi', 'label': 'Asuransi Investasi'},
    {'key': 'finaltyTabungan', 'label': 'Finalty Tabungan'},
    {'key': 'pendapatanLain', 'label': 'Pendapatan Lain-lain'},
  ];

  //  18 ITEM URAIAN KAS KELUAR (KK) SESUAI BUKTI FISIK KERTAS
  final List<Map<String, String>> _kkItems = const [
    {'key': 'bank', 'label': 'Bank'},
    {'key': 'pinjamanAnggota', 'label': 'Pinjaman Anggota'},
    {'key': 'penarikanSp', 'label': 'Simpanan Pokok Penarikan'},
    {'key': 'penarikanSw', 'label': 'Simpanan Wajib Penarikan'},
    {'key': 'penarikanSs', 'label': 'Simpanan Sukarela Penarikan'},
    {'key': 'penarikanSh', 'label': 'Simpanan Harian Penarikan'},
    {'key': 'penarikanDiakonia', 'label': 'Simpanan Diakonia Penarikan'},
    {'key': 'jasaSimpanan', 'label': 'Jasa Simpanan'},
    {'key': 'atk', 'label': 'Alat Tulis Kantor'},
    {'key': 'gajiStaff', 'label': 'Gaji Staff/Karyawan'},
    {'key': 'telekomunikasi', 'label': 'Telekomunikasi'},
    {'key': 'transport', 'label': 'Biaya Transport Petugas'},
    {'key': 'bpjsTk', 'label': 'BPJS Tenaga Kerja'},
    {'key': 'dana', 'label': 'Dana'},
    {'key': 'konsumsi', 'label': 'B. Konsumsi'},
    {'key': 'bpjsKesehatan', 'label': 'BPJS Kesehatan'},
    {'key': 'customUraian', 'label': 'Uraian Beban (Custom)'},
    {'key': 'lainLain', 'label': 'Lain-lain'},
  ];

  late Map<String, TextEditingController> _kmControllers;
  late Map<String, TextEditingController> _kkControllers;
  
  // Real-time Submitted Session Transactions List (Front-End Result Feed)
  final List<TransactionModel> _recentlySubmittedTransactions = [];


  List<MemberDataModel> _membersList = [];
  bool _isMembersLoading = false;
  String? _membersError;


  double _fetchedAvailableBalance = 0.0;
  bool _isFetchingBalance = false;

  double get _availableBalance => _fetchedAvailableBalance;

  Future<void> _fetchMemberBalances(String memberId) async {
    if (!mounted) return;
    setState(() {
      _isFetchingBalance = true;
      _fetchedAvailableBalance = 0.0;
    });
    
    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/members/$memberId/balances');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        final double saldoTersedia = double.tryParse(data['saldo_tersedia_ditarik']?.toString() ?? '0') ?? 0.0;
        
        if (mounted) {
          setState(() {
            _fetchedAvailableBalance = saldoTersedia;
          });
        }
      }
    } catch (e) {
      debugPrint('[TRANSAKSI_LOG] Failed to fetch balances: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingBalance = false;
        });
      }
    }
  }

  Future<void> _fetchMembers([String query = '']) async {
    if (!mounted) return;
    setState(() {
      _isMembersLoading = true;
      _membersError = null;
    });

    try {
      final token = await AuthService().getToken();
      final String searchParam = query.isNotEmpty ? '?search=${Uri.encodeComponent(query)}' : '';
      final uri = Uri.parse('${AuthService.staticBaseUrl}/members$searchParam');

      debugPrint('[TRANSAKSI_MEMBER_LOG] GET Request ke: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      debugPrint('[TRANSAKSI_MEMBER_LOG] Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List rawList = [];

        if (body is Map) {
          final dataField = body['data'];
          if (dataField is Map && dataField['data'] is List) {
            rawList = dataField['data'] as List;
          } else if (dataField is List) {
            rawList = dataField;
          } else if (body['members'] is List) {
            rawList = body['members'];
          }
        } else if (body is List) {
          rawList = body;
        }

        final parsedList = rawList
            .whereType<Map>()
            .map((item) => MemberDataModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        final activeMembers = parsedList.where((m) {
          final st = m.status.trim().toUpperCase();
          return st != 'RESIGNED' && st != 'KELUAR';
        }).toList();

        if (mounted) {
          setState(() {
            _membersList = activeMembers;
            _isMembersLoading = false;
            if ((_selectedMemberId == null || _selectedMemberId!.isEmpty) && activeMembers.isNotEmpty) {
              final firstMember = activeMembers.first;
              _selectedMemberId = firstMember.id;
              _selectedMemberName = firstMember.name;
              _selectedMemberNo = firstMember.memberNumber.padLeft(4, '0');
              _selectedMemberNik = firstMember.nik;
              _selectedMemberHasBukuBiru = firstMember.hasBukuBiru;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isMembersLoading = false;
            _membersError = 'Gagal mengambil data anggota (Status ${response.statusCode}).';
          });
        }
      }
    } catch (e) {
      debugPrint('[TRANSAKSI_MEMBER_LOG] Exception: $e');
      if (mounted) {
        setState(() {
          _isMembersLoading = false;
          _membersError = 'Terjadi kesalahan: $e';
        });
      }
    }
  }

  bool _isTransactionsLoading = false;
  bool _isSubmitting = false;

  TransactionModel _mapJsonToTransaction(Map<String, dynamic> json) {
    final isIncomeValue = json['is_income'] ?? json['isIncome'] ?? true;
    final typeValue = json['type']?.toString().toLowerCase() ?? '';
    final bool isIncome = (typeValue == 'deposit' || isIncomeValue == true || isIncomeValue == 1);

    return TransactionModel(
      id: json['id']?.toString() ?? '',
      kmCode: json['no_transaksi'] ?? json['voucher_code'] ?? json['kmCode'] ?? '',
      memberName: json['member']?['name'] ?? json['memberName'] ?? json['nama_anggota'] ?? '-',
      memberNo: json['member']?['member_number'] ?? json['memberNo'] ?? json['no_anggota'] ?? '-',
      title: json['title'] ?? json['description'] ?? 'Transaksi',
      category: json['category'] ?? json['kategori'] ?? '',
      date: json['date'] ?? json['created_at']?.toString().split('T')[0] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      isIncome: isIncome,
      status: json['status'] ?? 'Lunas',
    );
  }

  Future<void> _fetchTransactions() async {
    if (!mounted) return;
    setState(() {
      _isTransactionsLoading = true;
    });

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/transactions');

      debugPrint('[TRANSAKSI_LOG] GET Request ke: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      debugPrint('[TRANSAKSI_LOG] Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List rawList = [];

        // Tangani struktur respons paginasi Laravel { "data": { "data": [...] } }, map biasa, maupun List
        if (body is Map) {
          final dataField = body['data'];
          if (dataField is Map && dataField['data'] is List) {
            rawList = dataField['data'] as List;
          } else if (dataField is List) {
            rawList = dataField;
          } else if (body['transactions'] is List) {
            rawList = body['transactions'] as List;
          }
        } else if (body is List) {
          rawList = body;
        }

        final parsedList = rawList
            .whereType<Map>()
            .map((item) => _mapJsonToTransaction(Map<String, dynamic>.from(item)))
            .toList();

        if (mounted) {
          setState(() {
            _recentlySubmittedTransactions.clear();
            _recentlySubmittedTransactions.addAll(parsedList);
          });
        }
      }
    } catch (e) {
      debugPrint('[TRANSAKSI_LOG] Exception: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTransactionsLoading = false;
        });
      }
    }
  }

  void _initControllers() {
    _proofCodeController = TextEditingController(text: '');
    _customUraianLabelController = TextEditingController(text: 'Biaya Perbaikan Gedung');

    _kmControllers = {
      for (var item in _kmItems) item['key']!: TextEditingController()
    };
    _kkControllers = {
      for (var item in _kkItems) item['key']!: TextEditingController()
    };
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
    _fetchMembers();
    _fetchTransactions();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _activeTabIndex = _tabController.index;
          _proofCodeController.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _proofCodeController.dispose();
    _customUraianLabelController.dispose();
    for (var c in _kmControllers.values) {
      c.dispose();
    }
    for (var c in _kkControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  num _parseNum(String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.isEmpty ? 0 : num.parse(clean);
  }

  num get _totalAmount {
    final activeMap = _activeTabIndex == 0 ? _kmControllers : _kkControllers;
    num total = 0;
    for (var c in activeMap.values) {
      total += _parseNum(c.text);
    }
    return total;
  }

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showMemberSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        String query = '';
        Timer? modalDebounceTimer;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeMembers = _membersList.where((m) {
              final st = m.status.trim().toUpperCase();
              return st != 'RESIGNED' && st != 'KELUAR';
            }).toList();

            final filtered = activeMembers.where((m) {
              final q = query.toLowerCase().trim();
              if (q.isEmpty) return true;
              final nameMatch = m.name.toLowerCase().contains(q);
              final memberNoMatch = m.memberNumber.toLowerCase().contains(q) || m.memberNumber.padLeft(4, '0').contains(q);
              final idMatch = m.id.toLowerCase().contains(q);
              final nikMatch = m.nik.toLowerCase().contains(q);
              final bp = m.bukuPutihNumber.toLowerCase().trim();
              final bukuPutihMatch = bp.isNotEmpty && bp != '-' && bp != 'null' &&
                  (bp.contains(q) || (bp.startsWith('2021-') && bp.replaceFirst('2021-', '').contains(q)));
              return nameMatch || memberNoMatch || idMatch || nikMatch || bukuPutihMatch;
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih Data Anggota Koperasi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        onPressed: () {
                          modalDebounceTimer?.cancel();
                          Navigator.pop(modalContext);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    onChanged: (val) {
                      modalDebounceTimer?.cancel();
                      modalDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                        setModalState(() {
                          query = val;
                        });
                        _fetchMembers(val).then((_) {
                          setModalState(() {});
                        });
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Cari Nama, NIA, No. Rek Buku Putih, atau NIK...',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: _isMembersLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          )
                        : _membersError != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
                                      const SizedBox(height: 8),
                                      Text(
                                        _membersError!,
                                        style: const TextStyle(color: AppColors.danger, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () {
                                          _fetchMembers(query).then((_) {
                                            setModalState(() {});
                                          });
                                        },
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('Coba Lagi'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : filtered.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Text(
                                        'Tidak ada data anggota ditemukan.',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: filtered.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final m = filtered[index];
                                      final bool hasBp = m.bukuPutihNumber.isNotEmpty &&
                                          m.bukuPutihNumber != '-' &&
                                          m.bukuPutihNumber != 'null' &&
                                          !m.bukuPutihNumber.startsWith('{');
                                      final String bpText = hasBp
                                          ? (m.bukuPutihNumber.startsWith('2021-')
                                              ? m.bukuPutihNumber
                                              : '2021-${m.bukuPutihNumber}')
                                          : '';
                                      final String displayNia = m.memberNumber.padLeft(4, '0');
                                      return ListTile(
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                m.name.isNotEmpty ? m.name : '-',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.blue.shade200),
                                              ),
                                              child: Text(
                                                'NIA: $displayNia',
                                                style: TextStyle(color: Colors.blue.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            if (hasBp) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF3E5F5),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFCE93D8)),
                                                ),
                                                child: Text(
                                                  'Buku Putih: $bpText',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 2.0),
                                          child: Text(
                                            'NIK: ${m.nik.isNotEmpty ? m.nik : "-"}${hasBp ? " • Rek. Buku Putih: $bpText" : ""}',
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _selectedMemberId = m.id;
                                            _selectedMemberName = m.name;
                                            _selectedMemberNo = displayNia;
                                            _selectedMemberNik = m.nik;
                                            _selectedMemberHasBukuBiru = m.hasBukuBiru;
                                          });
                                          Navigator.pop(modalContext);
                                          _fetchMemberBalances(m.id);
                                        },
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _clearAllInputFields() {
    setState(() {
      for (var c in _kmControllers.values) {
        c.clear();
      }
      for (var c in _kkControllers.values) {
        c.clear();
      }
      _selectedBuku = 'Buku Biru';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seluruh nominal input uraian berhasil dibersihkan!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitTransaction() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMemberId == null || _selectedMemberId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih data anggota terlebih dahulu!'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validasi status anggota harus aktif
    final selectedMember = _membersList.firstWhere(
      (m) => m.id == _selectedMemberId,
      orElse: () => MemberDataModel(
        id: _selectedMemberId!,
        memberNumber: _selectedMemberNo,
        nik: _selectedMemberNik,
        name: _selectedMemberName,
        phone: '',
        address: '',
        joinedDate: '',
        totalSavings: 0,
        totalLoans: 0,
        status: 'non-aktif',
      ),
    );

    final String memberStatus = selectedMember.status.trim().toUpperCase();
    if (memberStatus == 'RESIGNED' || memberStatus == 'KELUAR') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi gagal: Anggota sudah berstatus Keluar / Resign.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan minimal satu nominal transaksi!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isIncome = _activeTabIndex == 0;

    if (!isIncome) {
      if (_selectedBuku == 'Buku Putih') {
        final double maxDraw = _availableBalance > 100000 ? _availableBalance - 100000 : 0.0;
        if (_totalAmount > maxDraw && _availableBalance > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saldo Tabungan Buku Putih wajib tersisa minimal Rp 100.000'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      } else if (_selectedBuku == 'Buku Biru') {
        final double maxDraw = _availableBalance > 10000 ? _availableBalance - 10000 : 0.0;
        if (_totalAmount > maxDraw && _availableBalance > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saldo Simpanan Sukarela Buku Biru wajib tersisa minimal Rp 10.000'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    setState(() {
      _isSubmitting = true;
      _isTransactionsLoading = true;
    });

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/daily-transactions');
      final inputVal = _proofCodeController.text.trim();
      final String proofNumber = inputVal.isEmpty ? "" : "${isIncome ? 'KM' : 'KK'} $inputVal";
      final savedTotal = _totalAmount;

      final activeMap = isIncome ? _kmControllers : _kkControllers;
      final activeItemsList = isIncome ? _kmItems : _kkItems;

      final isBukuPutih = _selectedBuku == 'Buku Putih';
      List<Map<String, dynamic>> itemsToPost = [];

      for (var item in activeItemsList) {
        final key = item['key']!;
        final label = item['label']!;
        final controller = activeMap[key];

        // Filter Buku Putih vs Buku Biru
        final isSpKey = key == 'sp' || key == 'penarikanSp';
        final isSwKey = key == 'sw' || key == 'penarikanSw';
        final isSsKey = key == 'ss' || key == 'penarikanSs';
        final isShKey = key == 'simpananHarian' || key == 'penarikanSh';

        if (isBukuPutih) {
          if (isSpKey || isSwKey || isSsKey) continue;
        } else {
          if (isShKey) continue;
        }

        if (controller != null) {
          double val = _parseNum(controller.text).toDouble();
          if (val > 0) {
            String desc = label;
            if (key == 'customUraian' && _customUraianLabelController.text.isNotEmpty) {
              desc = _customUraianLabelController.text.trim();
            }
            itemsToPost.add({
              'key': key,
              'label': label,
              'amount': val,
              'description': desc,
            });
          }
        }
      }

      if (itemsToPost.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silakan masukkan minimal satu nominal transaksi!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final payloadItems = itemsToPost.map((item) => {
        "account_code": _getAccountCode(item['key'] as String),
        "amount": item['amount'],
        "description": item['description'] ?? item['label'],
        "label": item['label'],
      }).toList();

      final payload = {
        "voucher_number": proofNumber.isNotEmpty ? proofNumber : (isIncome ? 'KM-AUTO' : 'KK-AUTO'),
        "transaction_date": _selectedDate.toIso8601String().split('T')[0],
        "member_id": int.tryParse(_selectedMemberId ?? "0") ?? 0,
        "payment_method": _paymentMethod.toLowerCase().contains('transfer') ? 'bank' : 'cash',
        "type": isIncome ? "deposit" : "withdrawal",
        "book_type": _selectedBuku == "Buku Biru" ? "BUKU_BIRU" : "BUKU_PUTIH",
        "items": payloadItems
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      debugPrint('[TRANSAKSI_POST_LOG] Bulk POST Code: ${response.statusCode}');
      debugPrint('[TRANSAKSI_POST_LOG] Bulk POST Body: ${response.body}');

      bool allSuccessful = response.statusCode == 200 || response.statusCode == 201;
      String? lastErrorMessage;

      if (!allSuccessful) {
        try {
          final errorBody = jsonDecode(response.body);
          lastErrorMessage = errorBody['message'] ?? 'Error server';
        } catch (_) {
          lastErrorMessage = 'Status Code: ${response.statusCode}';
        }
      }

      if (allSuccessful) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transaksi Berhasil Disimpan & Dijurnal Otomatis! (${_formatRupiah(savedTotal)})'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        if (!mounted) return;
        setState(() {
          _proofCodeController.clear();
          for (var c in activeMap.values) {
            c.clear();
          }
          _customUraianLabelController.clear();
          _selectedBuku = 'Buku Biru';
        });

        // Fetch ulang transaksi agar list ter-update riil dari server
        await _fetchTransactions();
      } else {
        if (mounted) {
          if (response.statusCode == 400 && !isIncome) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.warning_rounded, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('⚠️ Penarikan Ditolak', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: Text(lastErrorMessage ?? 'Saldo tidak mencukupi.', style: const TextStyle(fontSize: 14)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal menyimpan transaksi: ${lastErrorMessage ?? 'Error server'}'),
                backgroundColor: AppColors.danger,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan koneksi: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isTransactionsLoading = false;
        });
      }
    }
  }

  // MODAL PREVIEW KUITANSI / NOTA FISIK PRESISI KOPERASI CUM PELITA
  void _showReceiptPreviewModal(BuildContext context) {
    final isIncome = _activeTabIndex == 0;
    final activeItems = isIncome ? _kmItems : _kkItems;
    final activeControllers = isIncome ? _kmControllers : _kkControllers;

    // Pemetaan Kode Akun Standard (No. Perk.)
    final Map<String, String> accountCodes = {
      'bank': '1102',
      'sp': '3101',
      'sw': '3102',
      'ss': '3103',
      'angsuranPokok': '1201',
      'jasaPinjam': '4101',
      'uangPangkal': '4102',
      'denda': '4103',
      'provisi': '4104',
      'simpananHarian': '3104',
      'simpananDiakonia': '3105',
      'dana': '2102',
      'asuransiInvestasi': '1301',
      'finaltyTabungan': '4105',
      'pendapatanLain': '4201',
      'pinjamanAnggota': '1201',
      'penarikanSp': '3101',
      'penarikanSw': '3102',
      'penarikanSs': '3103',
      'penarikanSh': '3104',
      'penarikanDiakonia': '3105',
      'jasaSimpanan': '5101',
      'atk': '5201',
      'gajiStaff': '5202',
      'telekomunikasi': '5203',
      'transport': '5204',
      'bpjsTk': '5205',
      'konsumsi': '5206',
      'bpjsKesehatan': '5207',
      'customUraian': '5301',
      'lainLain': '5901',
    };

    final List<Map<String, dynamic>> itemsToPrint = [];
    double totalAmountToPrint = 0.0;

    for (var item in activeItems) {
      final key = item['key']!;
      final rawStr = activeControllers[key]?.text.replaceAll('.', '').replaceAll(',', '') ?? '';
      final val = double.tryParse(rawStr) ?? 0.0;
      if (val > 0) {
        String label = item['label']!;
        if (key == 'customUraian' && _customUraianLabelController.text.isNotEmpty) {
          label = _customUraianLabelController.text.trim();
        }
        final code = accountCodes[key] ?? '1000';
        itemsToPrint.add({'label': label, 'code': code, 'amount': val});
        totalAmountToPrint += val;
      }
    }

    // Jika form saat ini kosong, tapi ada transaksi baru yang baru saja di-submit di sesi ini
    if (itemsToPrint.isEmpty && _recentlySubmittedTransactions.isNotEmpty) {
      final latestTx = _recentlySubmittedTransactions.first;
      itemsToPrint.add({'label': latestTx.title, 'code': isIncome ? '3101' : '1201', 'amount': latestTx.amount});
      totalAmountToPrint = latestTx.amount;
    }

    if (totalAmountToPrint <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi nominal uraian transaksi terlebih dahulu sebelum membuka Preview Nota.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final String dateDisplay = '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';
    final String inputVal = _proofCodeController.text.trim();
    final String voucherCode = inputVal.isEmpty 
        ? (isIncome ? "KM Auto" : "KK Auto") 
        : "${isIncome ? 'KM' : 'KK'} $inputVal";

    showDialog(
      context: context,
      builder: (dialogContext) => ReceiptVoucherDialog(
        voucherNo: voucherCode,
        date: dateDisplay,
        memberName: _selectedMemberName,
        memberNo: _selectedMemberNo,
        paymentMethod: _paymentMethod,
        operatorName: 'Admin Pelita (Teller)',
        isIncome: isIncome,
        amount: totalAmountToPrint,
        items: itemsToPrint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _activeTabIndex == 0;
    final themeColor = isIncome ? AppColors.primary : AppColors.danger;
    final activeItems = isIncome ? _kmItems : _kkItems;
    final activeControllers = isIncome ? _kmControllers : _kkControllers;

    final String dateDisplay = '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';

    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: Builder(
          builder: (btnContext) {
            if (Navigator.canPop(btnContext)) {
              return IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Kembali',
                onPressed: () {
                  if (Navigator.canPop(btnContext)) {
                    Navigator.pop(btnContext);
                  }
                },
              );
            }
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              tooltip: 'Menu Admin',
              onPressed: () {
                if (widget.onOpenDrawer != null) {
                  widget.onOpenDrawer!();
                } else {
                  try {
                    Scaffold.of(btnContext).openDrawer();
                  } catch (_) {}
                }
              },
            );
          },
        ),
        title: const Text(
          'Input Transaksi Harian',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isIncome ? AppColors.success : AppColors.danger,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Uang Masuk (KM)'),
            Tab(text: 'Uang Keluar (KK)'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Row 1: FLEXIBLE HEADER (No. Bukti Editable & Date Picker)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _proofCodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nomor bukti/kwitansi tidak boleh kosong!';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'No. Bukti (KM / KK)',
                            labelStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            prefixIcon: Icon(Icons.edit_note_rounded, size: 18, color: themeColor),
                            prefixText: isIncome ? 'KM ' : 'KK ',
                            prefixStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tanggal Transaksi', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month_rounded, size: 16, color: themeColor),
                                    const SizedBox(width: 6),
                                    Text(dateDisplay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Row 2: SEARCHABLE MEMBER SELECTOR & DETAILS
                  InkWell(
                    onTap: _showMemberSearchModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.adminCanvas,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: themeColor.withValues(alpha: 0.1),
                            child: Icon(Icons.person_search_rounded, color: themeColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Nama / NIK Anggota Koperasi', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedMemberId == null || _selectedMemberId!.isEmpty
                                      ? 'Pilih Anggota Koperasi'
                                      : '$_selectedMemberName (No. $_selectedMemberNo)',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  _selectedMemberId == null || _selectedMemberId!.isEmpty
                                      ? 'Klik di sini untuk mencari anggota'
                                      : 'NIK: $_selectedMemberNik',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Row 3: METODE PEMBAYARAN
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _paymentMethodOptions.contains(_paymentMethod) ? _paymentMethod : _paymentMethodOptions.first,
                          decoration: const InputDecoration(
                            labelText: 'Metode Pembayaran',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: _paymentMethodOptions
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      m,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _paymentMethod = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedBuku,
                          decoration: const InputDecoration(
                            labelText: 'Pilihan Buku / Akun',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Buku Biru',
                              child: Text(
                                'Buku Biru (Keanggotaan/Saham)',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Buku Putih',
                              child: Text(
                                'Buku Putih (Tabungan Harian)',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedBuku = val;
                              });
                              if (val == 'Buku Putih' && _selectedMemberId != null) {
                                _fetchMemberBalances(_selectedMemberId!);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. SECTION: KARTU GRID DINAMIS NOMINAL URAIAN (KM: 15 ITEMS, KK: 18 ITEMS)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: themeColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isIncome
                                ? 'Rincian Uraian Kas Masuk KM (15 Item Sesuai Kertas)'
                                : 'Rincian Uraian Kas Keluar KK (18 Item Sesuai Kertas)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _clearAllInputFields,
                        icon: const Icon(Icons.cleaning_services_rounded, size: 14),
                        label: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                  const Divider(height: 16, color: AppColors.cardBorder),

                  // GRID BUILDER UNTUK SELURUH ITEM NOMINAL
                  Builder(
                    builder: (context) {
                      final isBukuPutih = _selectedBuku == 'Buku Putih';
                      final visibleItems = activeItems.where((item) {
                        final key = item['key']!;
                        final isSpKey = key == 'sp' || key == 'penarikanSp';
                        final isSwKey = key == 'sw' || key == 'penarikanSw';
                        final isSsKey = key == 'ss' || key == 'penarikanSs';
                        final isShKey = key == 'simpananHarian' || key == 'penarikanSh';

                        if (!isIncome) {
                          // Kunci/Disable penarikan SP dan SW untuk Kas Keluar harian
                          if (key == 'penarikanSp' || key == 'penarikanSw') {
                            activeControllers[key]?.clear();
                            return false;
                          }
                          // Kunci/Disable Pencairan Pinjaman jika anggota tidak punya Buku Biru
                          if (key == 'pinjamanAnggota' && !_selectedMemberHasBukuBiru) {
                            activeControllers[key]?.clear();
                            return false;
                          }
                        }

                        if (isBukuPutih) {
                          // Buku Putih: Sembunyikan SP, SW, SS
                          if (isSpKey || isSwKey || isSsKey) {
                            activeControllers[key]?.clear();
                            return false;
                          }
                        } else {
                          // Buku Biru: Sembunyikan SH
                          if (isShKey) {
                            activeControllers[key]?.clear();
                            return false;
                          }
                        }
                        return true;
                      }).toList();

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisExtent: 58,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: visibleItems.length,
                        itemBuilder: (context, index) {
                          final item = visibleItems[index];
                          final key = item['key']!;
                          final label = item['label']!;
                          final controller = activeControllers[key]!;

                          if (key == 'customUraian') {
                            return _buildCustomUraianInputField(controller, keyStr: key, isIncome: isIncome);
                          }

                          return _buildNominalInputField(controller, label, keyStr: key, isIncome: isIncome);
                        },
                      );
                    }
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 3. BANNER TOTAL SETORAN / PENCAIRAN REAL-TIME
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isIncome ? AppColors.adminNavy : AppColors.danger,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isIncome ? AppColors.adminNavy : AppColors.danger).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIncome ? 'TOTAL SETORAN (KM)' : 'TOTAL PENGELUARAN (KK)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatRupiah(_totalAmount),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 28),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (!isIncome && _selectedMemberId != null && _selectedBuku == 'Buku Putih')
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    if (_isFetchingBalance)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning))
                    else
                      const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isFetchingBalance 
                          ? 'Mengecek Saldo Tersedia...' 
                          : 'Saldo Tersedia untuk Ditarik: ${_formatRupiah(_availableBalance)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),

            // 4. ACTION BUTTONS: SIMPAN TRANSAKSI & CETAK BUKTI TRANSAKSI
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: themeColor.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Simpan Transaksi',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReceiptPreviewModal(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeColor,
                      side: BorderSide(color: themeColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 20),
                    label: const Text(
                      'Cetak',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            // 5. DAFTAR TRANSAKSI BARU DITERBITKAN SESI INI (FRONT-END RESULT FEED)
            if (_recentlySubmittedTransactions.isNotEmpty || _isTransactionsLoading) ...[
              const SizedBox(height: 24),
              _buildRecentlySubmittedSection(),
            ],
          ],
        ),
      ),
    ),
  );
}


  Widget _buildNominalInputField(TextEditingController controller, String label, {String? keyStr, bool isIncome = true}) {
    final bool isFilled = _parseNum(controller.text) > 0;
    
    String? errorText;
    if (!isIncome && _selectedBuku == 'Buku Putih' && keyStr == 'penarikanSh' && isFilled) {
      if (_parseNum(controller.text) > _fetchedAvailableBalance) {
        errorText = 'Nominal penarikan melebihi saldo tersedia (Maksimal Rp ${_formatRupiah(_fetchedAvailableBalance)})';
      }
    }

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (val) {
        final numVal = _parseNum(val);
        if (numVal > 0) {
          final formatted = numVal.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
          if (controller.text != formatted) {
            controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }
        } else {
          controller.clear();
        }
        setState(() {});
      },
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 11,
          color: isFilled ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isFilled ? FontWeight.bold : FontWeight.normal,
        ),
        prefixText: 'Rp ',
        prefixStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.danger),
      ),
    );
  }

  Widget _buildCustomUraianInputField(TextEditingController controller, {String? keyStr, bool isIncome = true}) {
    return Column(
      children: [
        Expanded(
          child: _buildNominalInputField(controller, _customUraianLabelController.text, keyStr: keyStr, isIncome: isIncome),
        ),
      ],
    );
  }

  String _getAccountCode(String key) {
    switch (key) {
      case 'sp':
      case 'penarikanSp':
      case 'sw':
      case 'penarikanSw':
      case 'ss':
      case 'penarikanSs':
        return '2020'; // Sw,Ss,Sp - Buku Biru
      case 'angsuranPokok':
      case 'pinjamanAnggota':
        return '1024'; // Piutang
      case 'jasaPinjam':
        return '4180'; // Jasa Pinjaman
      case 'denda':
        return '4182'; // Denda Keterlambatan Angsuran
      case 'provisi':
        return '4170'; // Provisi Pinjaman
      case 'uangPangkal':
        return '4191'; // Uang Pangkal
      case 'finaltyTabungan':
        return '4183'; // Finalty Tabungan
      case 'pendapatanLain':
        return '4192'; // Pendapatan Lain-lain
      case 'bank':
        return '1010'; // BRI
      case 'simpananHarian':
      case 'penarikanSh':
        return '2021'; // Simpanan Harian - Buku Putih
      case 'simpananDiakonia':
      case 'penarikanDiakonia':
        return '2022'; // Simpanan Diakonia
      case 'jasaSimpanan':
        return '7145'; // Jasa Simpanan
      case 'atk':
        return '7100'; // ATK
      case 'telekomunikasi':
        return '7101'; // Komunikasi
      case 'konsumsi':
        return '7170'; // Konsumsi Kantor
      case 'gajiStaff':
        return '7110'; // Gaji Karyawan
      case 'transport':
        return '7115'; // Transport Petugas
      case 'bpjsTk':
        return '7168'; // BPJS Tenaga Kerja
      case 'bpjsKesehatan':
        return '7167'; // BPJS Kesehatan
      case 'dana':
        return '2034'; // Dana Sosial (Bisa juga Dana Duka 2038)
      case 'customUraian':
      case 'lainLain':
      default:
        return '4192'; // Default Pendapatan Lain-lain jika tidak spesifik
    }
  }

  Widget _buildRecentlySubmittedSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, color: AppColors.adminNavy, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Daftar Transaksi Diterbitkan Sesi Ini',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_recentlySubmittedTransactions.length} Transaksi Baru',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.cardBorder),
          _isTransactionsLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentlySubmittedTransactions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.cardBorder),
                  itemBuilder: (context, index) {
              final tx = _recentlySubmittedTransactions[index];
              final isKm = tx.isIncome;
              final badgeColor = isKm ? AppColors.success : AppColors.danger;
              final badgeBg = isKm ? AppColors.successBg : AppColors.dangerBg;

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: badgeBg,
                  child: Icon(
                    isKm ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: badgeColor,
                    size: 16,
                  ),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isKm ? AppColors.adminNavy : const Color(0xFF7F1D1D),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tx.kmCode,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tx.memberName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${tx.title} • ${tx.date}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                trailing: Text(
                  '${isKm ? '+ ' : '- '}${_formatRupiah(tx.amount)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }
}
