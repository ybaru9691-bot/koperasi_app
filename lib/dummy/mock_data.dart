import '../models/manual_deposit_model.dart';


// MOCK DATA SEPARATION: DUMMY DATA FOR OFFLINE & API READY


abstract class MockData {
  /// Daftar Pilihan Jenis Simpanan
  static const List<String> savingsTypes = [
    'Simpanan Wajib',
    'Simpanan Sukarela',
  ];

  /// Daftar Rekening Koperasi Resmi untuk Penyetoran Manual
  static const List<Map<String, String>> bankAccounts = [
    {
      'bank': 'Bank BCA',
      'accountNumber': '8820-0012-3456',
      'accountName': 'Koperasi Pelita Utama',
    },
    {
      'bank': 'Bank BRI',
      'accountNumber': '0123-0100-8820-501',
      'accountName': 'Koperasi Pelita Utama',
    },
    {
      'bank': 'Setor Tunai',
      'accountNumber': 'Kantor Kas Koperasi Pelita',
      'accountName': 'Petugas Kasir Koperasi',
    },
  ];

  /// Mock List Riwayat Pengajuan Setoran Manual
  static List<ManualDepositModel> getMockDeposits() {
    return [
      const ManualDepositModel(
        id: 'DEP-2026-003',
        depositType: 'Simpanan Sukarela',
        amount: 500000.0,
        paymentMethod: 'Transfer Bank BCA',
        bankName: 'BCA',
        accountNumber: '8820-0012-3456',
        status: DepositStatus.pending,
        createdAt: '24 Juli 2026, 09:30',
        adminNote: 'Sedang diverifikasi oleh Kasir.',
      ),
      const ManualDepositModel(
        id: 'DEP-2026-002',
        depositType: 'Simpanan Wajib',
        amount: 250000.0,
        paymentMethod: 'Transfer Bank BRI',
        bankName: 'BRI',
        accountNumber: '0123-0100-8820-501',
        status: DepositStatus.approved,
        createdAt: '20 Juli 2026, 14:15',
        adminNote: 'Bukti transfer terverifikasi sah.',
      ),
      const ManualDepositModel(
        id: 'DEP-2026-001',
        depositType: 'Simpanan Sukarela',
        amount: 1000000.0,
        paymentMethod: 'Setor Tunai Kasir',
        bankName: 'Kantor Kas',
        accountNumber: 'Kasir Utama',
        status: DepositStatus.rejected,
        createdAt: '10 Juli 2026, 11:00',
        adminNote: 'Nominal transfer tidak sesuai dengan bukti kuitansi.',
      ),
    ];
  }
}
