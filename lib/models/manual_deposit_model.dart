// =========================================================
// DATA MODEL: MANUAL DEPOSIT SUBMISSION
// =========================================================

/// Enum Status Pengajuan Setoran Manual
enum DepositStatus { pending, approved, rejected }

/// Model Data Pengajuan Setoran Manual Koperasi
class ManualDepositModel {
  final String id;
  final String depositType; // e.g. 'Simpanan Wajib', 'Simpanan Sukarela'
  final double amount;
  final String paymentMethod; // e.g. 'Transfer BCA', 'Transfer BRI', 'Tunai'
  final String bankName;
  final String accountNumber;
  final String? proofImagePath;
  final DepositStatus status;
  final String createdAt;
  final String? adminNote;

  const ManualDepositModel({
    required this.id,
    required this.depositType,
    required this.amount,
    required this.paymentMethod,
    required this.bankName,
    required this.accountNumber,
    this.proofImagePath,
    required this.status,
    required this.createdAt,
    this.adminNote,
  });

  /// Status Teks Bahasa Indonesia
  String get statusLabel {
    switch (status) {
      case DepositStatus.pending:
        return 'Menunggu Verifikasi';
      case DepositStatus.approved:
        return 'Disetujui';
      case DepositStatus.rejected:
        return 'Ditolak';
    }
  }

  /// CopyWith Helper
  ManualDepositModel copyWith({
    String? id,
    String? depositType,
    double? amount,
    String? paymentMethod,
    String? bankName,
    String? accountNumber,
    String? proofImagePath,
    DepositStatus? status,
    String? createdAt,
    String? adminNote,
  }) {
    return ManualDepositModel(
      id: id ?? this.id,
      depositType: depositType ?? this.depositType,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      proofImagePath: proofImagePath ?? this.proofImagePath,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      adminNote: adminNote ?? this.adminNote,
    );
  }
}
