import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/member_card.dart';
import 'edit_anggota_screen.dart';
import 'member_detail_screen.dart';
import 'tambah_anggota_screen.dart';

/// 👥 Screen "Kelola Anggota" Real-Time API Integration (GET /api/members)
class KelolaAnggotaScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const KelolaAnggotaScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<KelolaAnggotaScreen> createState() => _KelolaAnggotaScreenState();
}

class _KelolaAnggotaScreenState extends State<KelolaAnggotaScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;

  String _searchQuery = '';
  String _sortOrder = 'number_asc'; // 'number_asc', 'name_asc'

  // Realtime API & Pagination State
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _displayedItemCount = 20;
  String? _errorMessage;

  // Realtime List Data Anggota dari Laravel API Backend
  List<MemberModel> _membersList = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollListener);
    fetchMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  /// 🌐 1. FETCH DATA ANGGOTA REALTIME (GET /api/members)
  Future<void> fetchMembers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/members');

      debugPrint('[MEMBER_FETCH_LOG] GET Request ke: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      debugPrint('[MEMBER_FETCH_LOG] Status Code: ${response.statusCode}');

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
            .map((item) => _mapJsonToMember(Map<String, dynamic>.from(item)))
            .toList();

        if (mounted) {
          setState(() {
            _membersList = parsedList;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Gagal mengambil data dari server (Status ${response.statusCode}).';
          });
        }
      }
    } catch (e) {
      debugPrint('[MEMBER_FETCH_LOG] Exception: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Kosongkan list jika koneksi server lokal offline
          _membersList = [];
        });
      }
    }
  }

  /// 🔄 MAP JSON RESPONSE DARI LARAVEL BACKEND KE MEMBERMODEL
  MemberModel _mapJsonToMember(Map<String, dynamic> json) {
    return MemberModel.fromJson(json);
  }

  /// 🗑️ 2. HAPUS DATA ANGGOTA (DELETE /api/members/{id})
  Future<void> _handleDeleteMember(MemberModel member) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
              SizedBox(width: 8),
              Text('Konfirmasi Hapus Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger)),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus data "${member.name}" (No. ${member.memberNo})?',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Hapus Data'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/members/${member.id}');

      debugPrint('[DELETE_MEMBER_LOG] Sending DELETE to: $uri');

      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Data ${member.name} Berhasil Dihapus'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        fetchMembers();
      } else {
        String msg = 'Gagal menghapus data (Status ${response.statusCode})';
        try {
          final resJson = jsonDecode(response.body);
          if (resJson['message'] != null) {
            msg = resJson['message'];
          }
        } catch (_) {}
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan koneksi API: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 📜 LAZY LOADING LISTENER
  void _onScrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    final filtered = _filteredMembers;
    if (_isLoadingMore || _displayedItemCount >= filtered.length) return;

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _displayedItemCount += 20;
          _isLoadingMore = false;
        });
      }
    });
  }

  /// 🔍 SEARCH WITH 400MS DEBOUNCE
  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _searchQuery = query.trim();
          _displayedItemCount = 20;
        });
      }
    });
  }

  /// 📊 LIST ANGGOTA TERFILTER & TERURUT
  List<MemberModel> get _filteredMembers {
    List<MemberModel> list = _membersList.where((m) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;

      final nameMatch = m.name.toLowerCase().contains(q);
      final nikMatch = m.nik.toLowerCase().contains(q);
      final noMatch = m.memberNo.toLowerCase().contains(q) || m.memberNo.padLeft(4, '0').contains(q);
      final churchMatch = m.church.toLowerCase().contains(q);
      final bp = m.bukuPutihNumber.toLowerCase().trim();
      final bukuPutihMatch = bp.isNotEmpty && bp != '-' && bp != 'null' &&
          (bp.contains(q) || (bp.startsWith('2021-') && bp.replaceFirst('2021-', '').contains(q)));

      return nameMatch || nikMatch || noMatch || churchMatch || bukuPutihMatch;
    }).toList();

    if (_sortOrder == 'number_asc') {
      list.sort((a, b) => a.memberNo.compareTo(b.memberNo));
    } else if (_sortOrder == 'name_asc') {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    return list;
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Urutkan Anggota',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.tag_rounded, color: AppColors.primary),
                title: const Text('Nomor Anggota (Urut dari No. 0001 ke atas)'),
                trailing: _sortOrder == 'number_asc'
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortOrder = 'number_asc');
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha, color: AppColors.primary),
                title: const Text('Nama (A - Z)'),
                trailing: _sortOrder == 'name_asc'
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortOrder = 'name_asc');
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMembers;
    final int itemsToRender = _displayedItemCount < filtered.length
        ? _displayedItemCount
        : filtered.length;

    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: _buildHeaderAppBar(),
      body: RefreshIndicator(
        onRefresh: fetchMembers,
        color: AppColors.primary,
        child: Column(
          children: [
            // Section Search & Filter
            _buildSearchAndFilterSection(),

            // Counter Bar Section
            _buildCounterBarSection(filtered.length),

            // Main Content Body (Loading / Empty State / List View)
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 14),
                          Text(
                            'Mengambil data anggota dari server API...',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: itemsToRender + (_displayedItemCount < filtered.length ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == itemsToRender) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final member = filtered[index];
                            return MemberCard(
                              member: member,
                              onEditPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditAnggotaScreen(member: member),
                                  ),
                                );
                                fetchMembers();
                              },
                              onDeletePressed: () => _handleDeleteMember(member),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MemberDetailScreen(member: member),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),

      // 🔄 3. AUTO-REFRESH SETELAH TAMBAH ANGGOTA
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Buka Form Tambah Anggota dan tunggu hingga kembali (pop screen)
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TambahAnggotaScreen()),
          );
          // Panggil ulang fetchMembers() secara otomatis jika sukses
          if (result == true || result == null) {
            fetchMembers();
          }
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text(
          '+ Tambah Anggota',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// 1. AppBar Header Tanpa Mock Cache Badge
  PreferredSizeWidget _buildHeaderAppBar() {
    return AppBar(
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
        'Kelola Anggota',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh Data',
          onPressed: fetchMembers,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 2. Search & Filter Bar Section
  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          // Search Field Text Box
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari Nama, NIK, No. Anggota, Rek. Buku Putih, atau Gereja...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Button Filter & Sort
          InkWell(
            onTap: _showSortBottomSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Counter Bar Section
  Widget _buildCounterBarSection(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFFF1F5F9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Menampilkan $count Anggota Koperasi',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            _sortOrder == 'name_asc' ? 'Urutan: Nama (A-Z)' : 'Urutan: NIK',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Empty State Widget (Tampilan saat database kosong)
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Anggota "$_searchQuery" Tidak Ditemukan'
                  : 'Belum Ada Data Anggota',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.adminNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Coba periksa kembali ejaan nama atau nomor NIK/NIA yang dimasukkan.'
                  : _errorMessage ?? 'Belum ada anggota terdaftar di database server. Tekan tombol + Tambah Anggota untuk mendaftarkan anggota baru.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: fetchMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh Data'),
            ),
          ],
        ),
      ),
    );
  }
}
