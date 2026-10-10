import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../data/models/member_detail_model.dart';
import '../../services/auth_service.dart';
import 'widgets/member_components.dart';

/// 👥 LAYAR KELOLA & MONITORING DATA ANGGOTA (KETUA VIEW)
class MemberListScreen extends StatefulWidget {
  final Function(String query)? onSearchCallback;
  final Function(String status)? onFilterChangedCallback;
  final Function(String memberId)? onSelectMemberCallback;

  const MemberListScreen({
    super.key,
    this.onSearchCallback,
    this.onFilterChangedCallback,
    this.onSelectMemberCallback,
  });

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  List<MemberDetailModel> _members = [];
  bool _isLoading = true;
  String _selectedStatusFilter = 'semua'; // 'semua', 'aktif', 'non-aktif'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // Server-Side Pagination Variables
  int _currentPage = 1;
  int _lastPage = 1;
  int _perPage = 25;
  int _totalRows = 0;

  // Summary Stats
  int _totalMembers = 0;
  int _newMembers = 0;
  int _inactiveMembers = 0;

  // Lifecycle & Concurrency Guards
  bool _hasFetched = false;
  bool _isFetchingStats = false;
  bool _isFetchingMembers = false;

  String _formatRibuan(int val) {
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  void initState() {
    super.initState();
    if (!_hasFetched) {
      _hasFetched = true;
      _fetchMemberStats();
      _fetchMembersData();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMemberStats() async {
    if (_isFetchingStats) return;
    _isFetchingStats = true;

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/manager/members/stats');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final data = responseData['data'] ?? {};
        if (mounted) {
          setState(() {
            _totalMembers = data['total_active'] != null
                ? int.tryParse(data['total_active'].toString()) ?? 0
                : 0;
            _newMembers = data['new_this_month'] != null
                ? int.tryParse(data['new_this_month'].toString()) ?? 0
                : 0;
            _inactiveMembers = data['total_inactive'] != null
                ? int.tryParse(data['total_inactive'].toString()) ?? 0
                : 0;
          });
        }
      }
    } catch (e) {
      debugPrint('[MEMBER_STATS_ERROR] Error fetching member stats: $e');
    } finally {
      _isFetchingStats = false;
    }
  }

  Future<void> _fetchMembersData() async {
    if (_isFetchingMembers) return;
    _isFetchingMembers = true;

    if (!mounted) {
      _isFetchingMembers = false;
      return;
    }
    setState(() => _isLoading = true);

    try {
      final token = await AuthService().getToken();
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'per_page': _perPage.toString(),
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
        if (_selectedStatusFilter != 'semua') 'status': _selectedStatusFilter,
      };

      final uri = Uri.parse('${AuthService.staticBaseUrl}/manager/members')
          .replace(queryParameters: queryParams);

      debugPrint('[MANAGER_MEMBERS] Target URL: $uri');

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> rawList = [];
        int current = _currentPage;
        int last = _lastPage;
        int total = _totalRows;

        if (decoded is Map<String, dynamic>) {
          final dataField = decoded['data'];
          if (dataField is List) {
            rawList = dataField;
            current = int.tryParse(decoded['current_page']?.toString() ?? '') ?? _currentPage;
            last = int.tryParse(decoded['last_page']?.toString() ?? '') ?? _lastPage;
            total = int.tryParse(decoded['total']?.toString() ?? '') ?? rawList.length;
          } else if (dataField is Map<String, dynamic>) {
            rawList = (dataField['data'] as List?) ?? [];
            current = int.tryParse(dataField['current_page']?.toString() ?? '') ?? _currentPage;
            last = int.tryParse(dataField['last_page']?.toString() ?? '') ?? _lastPage;
            total = int.tryParse(dataField['total']?.toString() ?? '') ?? rawList.length;
          } else if (decoded['meta'] is Map<String, dynamic>) {
            final meta = decoded['meta'] as Map<String, dynamic>;
            current = int.tryParse(meta['current_page']?.toString() ?? '') ?? _currentPage;
            last = int.tryParse(meta['last_page']?.toString() ?? '') ?? _lastPage;
            total = int.tryParse(meta['total']?.toString() ?? '') ?? rawList.length;
          }
        } else if (decoded is List) {
          rawList = decoded;
          current = 1;
          last = 1;
          total = rawList.length;
        }

        if (last < 1) last = 1;

        if (mounted) {
          setState(() {
            _members = rawList
                .map((e) => MemberDetailModel.fromJson(e as Map<String, dynamic>))
                .toList();
            _currentPage = current;
            _lastPage = last;
            _totalRows = total;
          });
        }
      }
    } catch (e) {
      debugPrint('[MANAGER_MEMBERS_ERROR] Error fetching member data: $e');
    } finally {
      _isFetchingMembers = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _searchQuery = val.trim();
          _currentPage = 1;
        });
        if (widget.onSearchCallback != null) {
          widget.onSearchCallback!(_searchQuery);
        }
        _fetchMembersData();
      }
    });
  }

  void _onStatusFilterChanged(String status) {
    setState(() {
      _selectedStatusFilter = status;
      _currentPage = 1;
    });
    if (widget.onFilterChangedCallback != null) {
      widget.onFilterChangedCallback!(status);
    }
    _fetchMembersData();
  }

  void _goToPage(int page) {
    if (page < 1 || page > _lastPage || page == _currentPage) return;
    setState(() => _currentPage = page);
    _fetchMembersData();
  }

  void _showMemberDetailDialog(MemberDetailModel item) {
    if (widget.onSelectMemberCallback != null) {
      widget.onSelectMemberCallback!(item.id);
    }

    showDialog(
      context: context,
      builder: (context) => MemberDetailDialog(member: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24.0 : 12.0,
            vertical: 16.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HEADER & SEARCH BAR
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Data Anggota & Portofolio Keuangan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.adminNavy,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Monitoring riwayat simpanan, pinjaman, dan status keanggotaan Koperasi CUM Pelita',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),

                      // Search Input Box
                      SizedBox(
                        width: isDesktop ? 320 : double.infinity,
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Cari Nama atau No. Anggota...',
                            hintStyle: const TextStyle(fontSize: 12.5),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _debounceTimer?.cancel();
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _currentPage = 1;
                                      });
                                      if (widget.onSearchCallback != null) {
                                        widget.onSearchCallback!('');
                                      }
                                      _fetchMembersData();
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.cardBorder),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 2. STAT CARDS SUMMARY (3 CARDS)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isDesktop ? 3 : 1,
                    childAspectRatio: isDesktop ? 3.6 : 3.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 10,
                    children: [
                      MemberStatCardWidget(
                        title: 'Total Anggota Aktif',
                        value: '${_formatRibuan(_totalMembers)} Anggota',
                        icon: Icons.groups_rounded,
                        color: const Color(0xFF0284C7),
                        bg: const Color(0xFFE0F2FE),
                      ),
                      MemberStatCardWidget(
                        title: 'Anggota Baru (Bulan Ini)',
                        value: '+${_formatRibuan(_newMembers)} Anggota',
                        icon: Icons.person_add_alt_1_rounded,
                        color: AppColors.success,
                        bg: AppColors.successBg,
                      ),
                      MemberStatCardWidget(
                        title: 'Anggota Non-Aktif / Pensiun',
                        value: '${_formatRibuan(_inactiveMembers)} Anggota',
                        icon: Icons.person_off_rounded,
                        color: AppColors.danger,
                        bg: AppColors.dangerBg,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. STATUS FILTER CHIPS
                  Row(
                    children: [
                      _statusFilterChip('Semua Status', 'semua'),
                      const SizedBox(width: 8),
                      _statusFilterChip('Anggota Aktif', 'aktif'),
                      const SizedBox(width: 8),
                      _statusFilterChip('Non-Aktif / Pensiun', 'non-aktif'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4. MEMBERS CARDS LIST
                  if (_isLoading && _members.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),

                  if (_isLoading && _members.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (_members.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.person_search_rounded
                                : Icons.people_outline,
                            color: AppColors.textMuted,
                            size: 54,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Data Anggota Tidak Ditemukan'
                                : 'Belum Ada Data Anggota',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.adminNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Coba ubah kata kunci pencarian atau filter status yang Anda pilih.'
                                : 'Data anggota yang terdaftar di sistem akan muncul di sini secara otomatis.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _members.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _members[index];
                        return MemberCardWidget(
                          member: item,
                          onTapDetail: () => _showMemberDetailDialog(item),
                        );
                      },
                    ),

                    // 5. PAGINATION BAR KONTROL
                    _buildPaginationBar(isDesktop),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationBar(bool isDesktop) {
    final int startItem = _totalRows == 0 ? 0 : (_currentPage - 1) * _perPage + 1;
    final int endItem = (_currentPage * _perPage) > _totalRows ? _totalRows : (_currentPage * _perPage);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Baris & Dropdown Per Halaman
                Row(
                  children: [
                    Text(
                      'Menampilkan $startItem-$endItem dari ${_formatRibuan(_totalRows)} anggota',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text('Per halaman:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _perPage,
                      isDense: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              if (val != null && val != _perPage) {
                                setState(() {
                                  _perPage = val;
                                  _currentPage = 1;
                                });
                                _fetchMembersData();
                              }
                            },
                    ),
                  ],
                ),

                // Tombol Navigasi Halaman
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page_rounded),
                      tooltip: 'Halaman Pertama',
                      onPressed: (_currentPage > 1 && !_isLoading)
                          ? () => _goToPage(1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Halaman Sebelumnya',
                      onPressed: (_currentPage > 1 && !_isLoading)
                          ? () => _goToPage(_currentPage - 1)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.adminNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Halaman $_currentPage dari $_lastPage',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.adminNavy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: 'Halaman Berikutnya',
                      onPressed: (_currentPage < _lastPage && !_isLoading)
                          ? () => _goToPage(_currentPage + 1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page_rounded),
                      tooltip: 'Halaman Terakhir',
                      onPressed: (_currentPage < _lastPage && !_isLoading)
                          ? () => _goToPage(_lastPage)
                          : null,
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menampilkan $startItem-$endItem dari ${_formatRibuan(_totalRows)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    DropdownButton<int>(
                      value: _perPage,
                      isDense: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              if (val != null && val != _perPage) {
                                setState(() {
                                  _perPage = val;
                                  _currentPage = 1;
                                });
                                _fetchMembersData();
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page_rounded),
                      onPressed: (_currentPage > 1 && !_isLoading) ? () => _goToPage(1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: (_currentPage > 1 && !_isLoading) ? () => _goToPage(_currentPage - 1) : null,
                    ),
                    Text(
                      '$_currentPage / $_lastPage',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: (_currentPage < _lastPage && !_isLoading) ? () => _goToPage(_currentPage + 1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page_rounded),
                      onPressed: (_currentPage < _lastPage && !_isLoading) ? () => _goToPage(_lastPage) : null,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _statusFilterChip(String label, String value) {
    final bool isSelected = _selectedStatusFilter == value;

    return InkWell(
      onTap: () => _onStatusFilterChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.adminNavy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.adminNavy : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
