import 'package:flutter/material.dart';

/// Model Data Transaksi Kas Masuk (KM) & Mutasi Koperasi CUM Pelita
class TransactionModel {
  final String id;                  // ID internal
  final String kmCode;              // Kode Nota Kas Masuk (contoh: "KM 4914", "KM 5221")
  final String memberName;          // Nama Anggota
  final String memberNo;            // No. Anggota Register (contoh: "2562")
  final String title;               // Judul / Keterangan Transaksi
  final String category;            // Tipe: 'Jasa Pinjam', 'Simpanan Wajib (SW)', 'Simpanan Sukarela (SS)', 'Simpanan Pokok (SP)', 'Uang Pangkal (UP)'
  final String date;                // Tanggal Nota
  final double amount;              // Nominal Transaksi (Rp)
  final bool isIncome;              // true = Kas Masuk, false = Pencairan/Pengeluaran
  final String status;              // 'Lunas', 'Pending', 'Disetujui'
  final IconData icon;

  const TransactionModel({
    required this.id,
    required this.kmCode,
    required this.memberName,
    required this.memberNo,
    required this.title,
    required this.category,
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.status,
    this.icon = Icons.receipt_long_rounded,
  });
}
