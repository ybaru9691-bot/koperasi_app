import 'package:flutter/material.dart';
import '../dummy/mock_data.dart';
import '../models/manual_deposit_model.dart';

// CONTROLLER & STATE HANDLING: SEPARATION OF LOGIC FROM UI
/// State UI Enum untuk Handing 3 State Utama (+ State Sukses & Initial)
enum ViewState { initial, loading, empty, error, success }

/// Controller Pengajuan Setoran Manual Koperasi
class ManualDepositController extends ChangeNotifier {
  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  List<ManualDepositModel> _deposits = [];

  // Getter
  ViewState get state => _state;
  String get errorMessage => _errorMessage;
  List<ManualDepositModel> get deposits => List.unmodifiable(_deposits);

  /// Load data setoran manual
  Future<void> fetchDeposits() async {
    _setState(ViewState.loading);

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      _deposits = MockData.getMockDeposits();
      if (_deposits.isEmpty) {
        _setState(ViewState.empty);
      } else {
        _setState(ViewState.success);
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat data pengajuan setoran: ${e.toString()}';
      _setState(ViewState.error);
    }
  }

  /// Simulasi Memicu UI State (Loading, Empty, Error, Success) untuk Pengujian UI
  void simulateState(ViewState newState) {
    if (newState == ViewState.empty) {
      _deposits = [];
      _setState(ViewState.empty);
    } else if (newState == ViewState.error) {
      _errorMessage = 'Terjadi kesalahan koneksi ke server Koperasi.';
      _setState(ViewState.error);
    } else if (newState == ViewState.loading) {
      _setState(ViewState.loading);
    } else {
      _deposits = MockData.getMockDeposits();
      _setState(ViewState.success);
    }
  }

  /// Submit Setoran Manual Baru
  Future<bool> submitDeposit({
    required String depositType,
    required double amount,
    required String paymentMethod,
    required String bankName,
    required String accountNumber,
  }) async {
    _setState(ViewState.loading);
    await Future.delayed(const Duration(milliseconds: 800));

    final String currentHour = TimeOfDay.now().hour.toString().padLeft(2, '0');
    final String currentMinute = TimeOfDay.now().minute.toString().padLeft(
      2,
      '0',
    );

    final newDeposit = ManualDepositModel(
      id: 'DEP-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      depositType: depositType,
      amount: amount,
      paymentMethod: paymentMethod,
      bankName: bankName,
      accountNumber: accountNumber,
      status: DepositStatus.pending,
      createdAt: 'Hari ini, $currentHour:$currentMinute',
      adminNote: 'Menunggu verifikasi admin.',
    );

    _deposits.insert(0, newDeposit);
    _setState(ViewState.success);
    return true;
  }

  void _setState(ViewState newState) {
    _state = newState;
    notifyListeners();
  }
}
