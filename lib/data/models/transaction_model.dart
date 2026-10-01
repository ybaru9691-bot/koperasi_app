/// 💸 Model Data Transaksi Kas (KM / KK)
class TransactionModel {
  final String id;
  final String date;
  final String kmCode;
  final String memberName;
  final String memberNo;
  final String category;
  final bool isIncome;
  final double amount;
  final String paymentMethod;
  final String operatorName;

  TransactionModel({
    required this.id,
    required this.date,
    required this.kmCode,
    required this.memberName,
    required this.memberNo,
    required this.category,
    required this.isIncome,
    required this.amount,
    required this.paymentMethod,
    required this.operatorName,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      date: json['date'] ?? json['created_at'] ?? '',
      kmCode: json['kmCode'] ?? json['no_transaksi'] ?? '',
      memberName: json['memberName'] ?? json['nama_anggota'] ?? '',
      memberNo: json['memberNo'] ?? json['no_anggota'] ?? '',
      category: json['category'] ?? json['kategori'] ?? '',
      isIncome: json['isIncome'] ?? json['is_income'] ?? true,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] ?? json['metode_pembayaran'] ?? 'Tunai',
      operatorName: json['operator'] ?? json['petugas'] ?? 'Admin',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'kmCode': kmCode,
      'memberName': memberName,
      'memberNo': memberNo,
      'category': category,
      'isIncome': isIncome,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'operator': operatorName,
    };
  }
}
