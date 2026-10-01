/// Model Data Transaksi Admin
class TransactionDataModel {
  final String id;
  final String date;
  final String kmCode;
  final String memberName;
  final String memberNo;
  final String category;
  final bool isIncome;
  final double amount;
  final String paymentMethod;
  final String operator;
  final List<Map<String, dynamic>> subItems;

  TransactionDataModel({
    required this.id,
    required this.date,
    required this.kmCode,
    required this.memberName,
    required this.memberNo,
    required this.category,
    required this.isIncome,
    required this.amount,
    required this.paymentMethod,
    required this.operator,
    this.subItems = const [],
  });

  String get refNo => kmCode;
  String get memberRegNo => memberNo;
  String get type => isIncome ? 'KM' : 'KK';
  String get status => 'Berhasil';
  String get operatorName => operator;

  factory TransactionDataModel.fromJson(Map<String, dynamic> json) {
    return TransactionDataModel(
      id: json['id']?.toString() ?? '',
      date: json['date'] ?? json['created_at'] ?? '',
      kmCode: json['kmCode'] ?? json['no_transaksi'] ?? '',
      memberName: json['memberName'] ?? json['nama_anggota'] ?? '',
      memberNo: json['memberNo'] ?? json['no_anggota'] ?? '',
      category: json['category'] ?? json['kategori'] ?? '',
      isIncome: json['isIncome'] ?? json['is_income'] ?? true,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] ?? json['metode_pembayaran'] ?? 'Tunai',
      operator: json['operator'] ?? json['petugas'] ?? 'Admin',
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
      'operator': operator,
    };
  }
}
