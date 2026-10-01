import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatter untuk input nominal angka dengan pemisah ribuan otomatis (misal: 100000 -> 100.000)
class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Ambil hanya digit angka
    final String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final double? numVal = double.tryParse(digitsOnly);
    if (numVal == null) {
      return oldValue;
    }

    final String formatted = _formatter.format(numVal).trim();

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
