import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../data/models/announcement_model.dart';
import '../../services/auth_service.dart';
import '../../utils/navigation_utils.dart';

// LAYAR KELOLA & DAFTAR PENGUMUMAN KOPERASI (RESPONSIF – API DINAMIS)
class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  List<AnnouncementModel> _announcements = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  // Loading state per-item (untuk tombol Edit/Hapus)
  final Set<String> _loadingItems = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  // API HELPERS 

  Future<String?> _getToken() async {
    return await AuthService().getToken();
  }

  String get _baseUrl => AuthService.staticBaseUrl;

  //FETCH

  Future<void> _fetchAnnouncements() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        _setError('Sesi tidak ditemukan. Silakan login kembali.');
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/announcements'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> raw = body['data'] ?? [];
          setState(() {
            _announcements = raw.map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>)).toList();
            _isLoading = false;
          });
        } else {
          _setError(body['message'] ?? 'Gagal memuat pengumuman.');
        }
      } else {
        _setError('Gagal memuat data (Status ${response.statusCode})');
      }
    } catch (e) {
      _setError('Error: $e');
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = msg;
      _isLoading = false;
    });
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // CREATE 

  Future<void> _createAnnouncement(String title, String content, String category) async {
    setState(() => _isSaving = true);
    try {
      final token = await _getToken();
      if (token == null) { _showSnack('Sesi tidak ditemukan.'); return; }

      final response = await http.post(
        Uri.parse('$_baseUrl/announcements'),
        headers: _headers(token),
        body: jsonEncode({'title': title, 'content': content, 'category': category}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final body = jsonDecode(response.body);

      if (response.statusCode == 201 && body['success'] == true) {
        _showSnack('Pengumuman berhasil diterbitkan!', success: true);
        await _fetchAnnouncements();
      } else {
        _showSnack(body['message'] ?? 'Gagal menerbitkan pengumuman.');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // UPDATE 

  Future<void> _updateAnnouncement(String id, String title, String content, String category) async {
    setState(() { _loadingItems.add(id); _isSaving = true; });
    try {
      final token = await _getToken();
      if (token == null) { _showSnack('Sesi tidak ditemukan.'); return; }

      final response = await http.put(
        Uri.parse('$_baseUrl/announcements/$id'),
        headers: _headers(token),
        body: jsonEncode({'title': title, 'content': content, 'category': category}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        _showSnack('Pengumuman berhasil diperbarui!', success: true);
        await _fetchAnnouncements();
      } else {
        _showSnack(body['message'] ?? 'Gagal memperbarui pengumuman.');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() { _loadingItems.remove(id); _isSaving = false; });
    }
  }

  //  DELETE

  Future<void> _deleteAnnouncement(String id, String title) async {
    setState(() => _loadingItems.add(id));
    try {
      final token = await _getToken();
      if (token == null) { _showSnack('Sesi tidak ditemukan.'); return; }

      final response = await http.delete(
        Uri.parse('$_baseUrl/announcements/$id'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        _showSnack('Pengumuman "$title" telah dihapus.', isError: true);
        await _fetchAnnouncements();
      } else {
        _showSnack(body['message'] ?? 'Gagal menghapus pengumuman.');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingItems.remove(id));
    }
  }

  //DIALOGS 
  void _showFormDialog({AnnouncementModel? item}) {
    final bool isEdit = item != null;
    final titleController = TextEditingController(text: item?.title ?? '');
    final contentController = TextEditingController(text: item?.content ?? '');
    String category = _toApiCategory(item?.category ?? 'INFORMASI');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_note_rounded : Icons.campaign_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Pengumuman' : 'Buat Pengumuman Baru',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Judul Pengumuman *',
                          hintText: 'Masukkan judul...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Kategori *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'PENTING',    child: Text('🔴  PENTING')),
                          DropdownMenuItem(value: 'INFORMASI',  child: Text('🔵  INFORMASI')),
                          DropdownMenuItem(value: 'PROMO',      child: Text('🟢  PROMO')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Isi Pengumuman *',
                          hintText: 'Masukkan detail informasi...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : () => NavigationUtils.safePop(dialogContext),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final t = titleController.text.trim();
                          final c = contentController.text.trim();
                          if (t.isEmpty || c.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Judul dan isi pengumuman wajib diisi!')),
                            );
                            return;
                          }
                          NavigationUtils.safePop(dialogContext);
                          if (isEdit) {
                            await _updateAnnouncement(item.id, t, c, category);
                          } else {
                            await _createAnnouncement(t, c, category);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(isEdit ? 'Simpan Perubahan' : 'Terbitkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(AnnouncementModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 24),
              SizedBox(width: 10),
              Text('Hapus Pengumuman', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apakah Anda yakin ingin menghapus pengumuman berikut?'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '"${item.title}"',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationUtils.safePop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                NavigationUtils.safePop(dialogContext);
                _deleteAnnouncement(item.id, item.title);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Hapus'),
            ),
          ],
        );
      },
    );
  }

  //  HELPERS 

  void _showSnack(String msg, {bool success = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : (success ? AppColors.success : null),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _toApiCategory(String raw) {
    final upper = raw.toUpperCase();
    if (upper == 'PENTING' || upper == 'IMPORTANT') return 'PENTING';
    if (upper == 'PROMO') return 'PROMO';
    return 'INFORMASI';
  }

  //  BUILD
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
                  // ── HEADER
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.campaign_outlined, color: AppColors.primary, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Pengumuman & Informasi Koperasi',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.adminNavy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Kelola berita, pengumuman penting, dan edaran resmi Koperasi',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Refresh button
                          IconButton(
                            onPressed: _isLoading ? null : _fetchAnnouncements,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                : const Icon(Icons.refresh_rounded, color: AppColors.primary),
                            tooltip: 'Muat Ulang',
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _showFormDialog(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Buat Pengumuman Baru', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── BODY 
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (_hasError)
                    _buildErrorState()
                  else if (_announcements.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _announcements.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return _buildAnnouncementCard(_announcements[index], isDesktop);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // SUB-WIDGETS 

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          const Text('Gagal Memuat Pengumuman',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
          const SizedBox(height: 6),
          Text(_errorMessage ?? '', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchAnnouncements,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined, color: AppColors.textMuted.withValues(alpha: 0.5), size: 56),
          const SizedBox(height: 14),
          const Text('Belum Ada Pengumuman',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
          const SizedBox(height: 6),
          const Text(
            'Klik tombol "Buat Pengumuman Baru" untuk mempublikasikan pengumuman koperasi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(AnnouncementModel item, bool isDesktop) {
    final String cat = item.category.toUpperCase();
    final bool isPenting = cat == 'PENTING';
    final bool isPromo = cat == 'PROMO';

    final Color tagColor = isPenting
        ? AppColors.danger
        : isPromo
            ? const Color(0xFF16A34A)
            : AppColors.info;
    final Color tagBg = isPenting
        ? AppColors.dangerBg
        : isPromo
            ? const Color(0xFFDCFCE7)
            : AppColors.infoBg;

    final bool itemLoading = _loadingItems.contains(item.id);

    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPenting ? AppColors.danger.withValues(alpha: 0.3) : AppColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag + Tanggal + Author
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: tagColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.date,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              Text(
                'Oleh: ${item.author}',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Judul
          Text(
            item.title,
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14.5,
              fontWeight: FontWeight.bold,
              color: AppColors.adminNavy,
            ),
          ),

          const SizedBox(height: 6),

          // Isi
          Text(
            item.content,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 8),

          // Aksi Edit / Hapus
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (itemLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              else ...[
                TextButton.icon(
                  onPressed: () => _showFormDialog(item: item),
                  icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                  label: const Text('Edit',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showDeleteDialog(item),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                  label: const Text('Hapus',
                      style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
