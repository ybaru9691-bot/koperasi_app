import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/navigation_utils.dart';
import 'widgets/excel_upload_components.dart';

///  LAYAR IMPORT DATA AWAL / BULK EXCEL UPLOAD MIGRATION (ADMIN)
class MigrationScreen extends StatefulWidget {
  final Function(PlatformFile file)? onUploadFileCallback;

  const MigrationScreen({
    super.key,
    this.onUploadFileCallback,
  });

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  bool _isDownloadingTemplate = false;

  ///  PILIH FILE EXCEL VIA FILE_PICKER
  Future<void> _handlePickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih file: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleRemoveFile() {
    setState(() {
      _selectedFile = null;
    });
  }

  /// 📥 UNDUH TEMPLATE EXCEL RESMI DARI BACKEND
  Future<void> _handleDownloadTemplate() async {
    if (_isDownloadingTemplate) return;

    setState(() => _isDownloadingTemplate = true);

    try {
      final token = await AuthService().getToken();
      final url = '${AuthService.staticBaseUrl}/members/migration/template';
      final uri = Uri.parse(url);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        const filename = 'Template_Migrasi_Anggota_CUM_Pelita.xlsx';

        if (kIsWeb) {
          final blob = html.Blob(
            [response.bodyBytes],
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
          final blobUrl = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = blobUrl
            ..download = filename;
          html.document.body?.children.add(anchor);
          anchor.click();
          anchor.remove();
          html.Url.revokeObjectUrl(blobUrl);
        } else {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Template Excel resmi berhasil diunduh!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Status respon server: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Gagal mengunduh template: $e')),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingTemplate = false);
      }
    }
  }

  /// 🚀 EKSEKUSI PROCESS IMPORT BULK EXCEL VIA REAL API
  Future<void> _handleProcessImport() async {
    if (_selectedFile == null || _isUploading) return;

    setState(() => _isUploading = true);

    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/members/import-initial');
      final request = http.MultipartRequest('POST', uri);

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      if (_selectedFile!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _selectedFile!.bytes!,
            filename: _selectedFile!.name,
          ),
        );
      } else if (_selectedFile!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedFile!.path!,
            filename: _selectedFile!.name,
          ),
        );
      } else {
        throw Exception('File data is empty. Please try selecting the file again.');
      }

      final responseStream = await request.send().timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw TimeoutException('Proses import data massal membutuhkan waktu lebih lama. Mohon tunggu...'),
      );
      final response = await http.Response.fromStream(responseStream);

      debugPrint('[IMPORT_EXCEL_LOG] Response: ${response.statusCode} - ${response.body}');

      if (!mounted) return;

      setState(() => _isUploading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        final totalImported = resData['data']?['total_imported'] ?? resData['data']?['imported_count'] ?? 0;
        final totalAmount = resData['data']?['total_amount'] ?? 0;

        final formattedAmount = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(totalAmount);

        showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                  SizedBox(width: 10),
                  Text('Import Data Berhasil!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File "${_selectedFile!.name}" telah selesai diproses.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• $totalImported Data Master Anggota Baru Ter-create.', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.success)),
                        const SizedBox(height: 3),
                        Text('• $formattedAmount Total Saldo Awal Terkonsolidasi.', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.success)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    NavigationUtils.safePop(dialogContext);
                    setState(() => _selectedFile = null);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Selesai'),
                ),
              ],
            );
          },
        );
      } else {
        String errorDetail = 'Gagal mengimpor data (Status ${response.statusCode})';
        try {
          final resData = jsonDecode(response.body);
          if (resData['message'] != null) {
            errorDetail = resData['message'];
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorDetail),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan koneksi API: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
            title: Row(
              children: const [
                Icon(Icons.file_upload_outlined, color: AppColors.adminAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Import Data Awal Anggota & Saldo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24.0 : 12.0,
              vertical: 16.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER TITLE & SUBTITLE
                    const Text(
                      'Migrasi Saldo Awal & Data Anggota (Bulk Excel)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.adminNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Unggah file Excel migrasi saldo awal simpanan dan pinjaman anggota agar ter-konsolidasi otomatis tanpa mulai dari nol.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),

                    const SizedBox(height: 20),

                    // 1. CARD INSTRUKSI & DOWNLOAD TEMPLATE
                    DownloadTemplateCard(
                      onDownloadTemplate: _handleDownloadTemplate,
                      isDownloading: _isDownloadingTemplate,
                    ),

                    const SizedBox(height: 20),

                    // 2. DRAG & DROP / FILE PICKER AREA
                    ExcelUploadPickerWidget(
                      selectedFile: _selectedFile,
                      onPickFile: _handlePickFile,
                      onRemoveFile: _handleRemoveFile,
                    ),

                    const SizedBox(height: 20),

                    // 3. PROGRESS INDICATOR & START IMPORT BUTTON
                    if (_isUploading) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Sedang memproses & memvalidasi data Excel...',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            LinearProgressIndicator(color: AppColors.primary, backgroundColor: AppColors.cardBorder),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _selectedFile != null && !_isUploading ? _handleProcessImport : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(
                          _selectedFile != null ? 'Mulai Import & Validasi Data' : 'Pilih File Excel Terlebih Dahulu',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
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
