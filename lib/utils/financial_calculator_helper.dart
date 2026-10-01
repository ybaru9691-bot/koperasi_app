// Helper class untuk memisahkan logika bisnis kalkulasi keuangan dari UI Widget
class FinancialCalculatorHelper {
  // Komponen Biaya Tetap (Sekali Bayar)
  static const int uangPangkal = 20000;
  static const int simpananPokok = 200000;
  static const int danaDuka = 20000;
  
  // Total Biaya Wajib Tetap (Rp 240.000)
  static const int fixedWajibCost = uangPangkal + simpananPokok + danaDuka;

  // Batas Minimal Simpanan Wajib Bulanan
  static const int minSimpananWajib = 20000;

  // Kalkulasi total setoran awal secara dinamis
  static int calculateTotal(int sw, int ss) {
    return fixedWajibCost + sw + ss;
  }

  // Formatter mata uang rupiah standar
  static String formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }
}
