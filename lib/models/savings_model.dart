import 'package:flutter/material.dart';

/// Jenis Mutasi Simpanan
enum MutationType { setor, tarik, bunga }

/// Model Data Jenis Simpanan Koperasi
class SavingsDetailModel {
  final String id;
  final String title;
  final String accountNumber;
  final double balance;
  final IconData icon;
  final Color color;
  final String description;

  const SavingsDetailModel({
    required this.id,
    required this.title,
    required this.accountNumber,
    required this.balance,
    required this.icon,
    required this.color,
    required this.description,
  });

  factory SavingsDetailModel.fromJson(Map<String, dynamic> json) {
    return SavingsDetailModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      balance: (json['balance'] as num? ?? 0.0).toDouble(),
      icon: Icons.account_balance_wallet_outlined,
      color: const Color(0xFF137A43),
      description: json['description'] as String? ?? '',
    );
  }
}

/// Model Data Mutasi / Riwayat Transaksi Simpanan
class SavingsMutationModel {
  final String id;
  final String? title;
  final String? savingsType;
  final String? category;
  final String date;
  final double amount;
  final bool isCredit;
  final MutationType type;
  final String status;
  final String proofNumber;

  const SavingsMutationModel({
    required this.id,
    this.title,
    this.savingsType,
    this.category,
    required this.date,
    required this.amount,
    required this.isCredit,
    required this.type,
    required this.status,
    required this.proofNumber,
  });

  factory SavingsMutationModel.fromJson(Map<String, dynamic> json) {
    MutationType typeEnum;
    final cat = (json['category'] ?? json['jenis_simpanan'] ?? '').toString();
    final typeStr = (json['type'] as String? ?? 'setor').toLowerCase();

    if (cat == 'bunga_simpanan' || cat.toLowerCase().contains('bunga') || typeStr == 'bunga') {
      typeEnum = MutationType.bunga;
    } else if (typeStr == 'tarik' || typeStr == 'withdrawal') {
      typeEnum = MutationType.tarik;
    } else {
      typeEnum = MutationType.setor;
    }

    return SavingsMutationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      savingsType: json['savings_type'] as String? ?? 'Simpanan Sukarela',
      category: cat,
      date: json['date'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      isCredit: json['is_credit'] as bool? ?? (typeEnum != MutationType.tarik),
      type: typeEnum,
      status: json['status'] as String? ?? 'Berhasil',
      proofNumber: json['proof_number'] as String? ?? json['transaction_number'] as String? ?? '',
    );
  }
}
