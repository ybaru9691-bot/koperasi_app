import 'package:flutter/material.dart';

class TabelarisRow {
  final String id, tgl, noBukti, nba, nama, type, description;
  final double kasDebet, kasKredit;
  final double piutang, penarikanSw, penarikanSs, penarikanSp, penarikanSh, penarikanSd;
  final double inventaris, bankKeluar, biaya;
  final double danaDana, uangPangkal, simpananSp, simpananSw, simpananSs, simpananSh, simpananSd;
  final double angsuranPokok, jasaPinjaman, dendaPenalti, provisiPinjaman, asuransi, lainLain, bankMasuk;

  TabelarisRow({
    required this.id,
    required this.tgl,
    required this.noBukti,
    required this.nba,
    required this.nama,
    required this.type,
    required this.description,
    required this.kasDebet,
    required this.kasKredit,
    required this.piutang,
    required this.penarikanSw,
    required this.penarikanSs,
    required this.penarikanSp,
    required this.penarikanSh,
    required this.penarikanSd,
    required this.inventaris,
    required this.bankKeluar,
    required this.biaya,
    required this.danaDana,
    required this.uangPangkal,
    required this.simpananSp,
    required this.simpananSw,
    required this.simpananSs,
    required this.simpananSh,
    required this.simpananSd,
    required this.angsuranPokok,
    required this.jasaPinjaman,
    required this.dendaPenalti,
    required this.provisiPinjaman,
    required this.asuransi,
    required this.lainLain,
    required this.bankMasuk,
  });

  factory TabelarisRow.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0.0;
    return TabelarisRow(
      id: (j['id'] ?? '').toString(),
      tgl: (j['tgl'] ?? j['transaction_date'] ?? '-').toString(),
      noBukti: (j['no_bukti'] ?? j['receipt_number'] ?? '-').toString(),
      nba: (j['nba'] ?? j['member_number'] ?? '-').toString(),
      nama: (j['nama'] ?? j['name'] ?? '-').toString(),
      type: (j['type'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      kasDebet: n('kas_debet'),
      kasKredit: n('kas_kredit'),
      piutang: n('piutang'),
      penarikanSw: n('penarikan_sw'),
      penarikanSs: n('penarikan_ss'),
      penarikanSp: n('penarikan_sp'),
      penarikanSh: n('penarikan_sh'),
      penarikanSd: n('penarikan_sd'),
      inventaris: n('inventaris'),
      bankKeluar: n('bank_keluar'),
      biaya: n('biaya'),
      danaDana: n('dana_dana'),
      uangPangkal: n('uang_pangkal'),
      simpananSp: n('simpanan_sp'),
      simpananSw: n('simpanan_sw'),
      simpananSs: n('simpanan_ss'),
      simpananSh: n('simpanan_sh'),
      simpananSd: n('simpanan_sd'),
      angsuranPokok: n('angsuran_pokok'),
      jasaPinjaman: n('jasa_pinjaman'),
      dendaPenalti: n('denda_penalti'),
      provisiPinjaman: n('provisi_pinjaman'),
      asuransi: n('asuransi'),
      lainLain: n('lain_lain'),
      bankMasuk: n('bank_masuk'),
    );
  }
}

class TabelarisAccumulator {
  double piutang = 0;
  double penarikanSw = 0;
  double penarikanSs = 0;
  double penarikanSp = 0;
  double penarikanSh = 0;
  double penarikanSd = 0;
  double inventaris = 0;
  double bankKeluar = 0;
  double biaya = 0;
  double kasDebet = 0;
  double kasKredit = 0;
  double danaDana = 0;
  double uangPangkal = 0;
  double simpananSp = 0;
  double simpananSw = 0;
  double simpananSs = 0;
  double simpananSh = 0;
  double simpananSd = 0;
  double angsuranPokok = 0;
  double jasaPinjaman = 0;
  double dendaPenalti = 0;
  double provisiPinjaman = 0;
  double asuransi = 0;
  double lainLain = 0;
  double bankMasuk = 0;

  TabelarisAccumulator();

  factory TabelarisAccumulator.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0.0;
    final acc = TabelarisAccumulator();
    acc.piutang = n('piutang');
    acc.penarikanSw = n('penarikan_sw') != 0 ? n('penarikan_sw') : n('tarik_sw');
    acc.penarikanSs = n('penarikan_ss') != 0 ? n('penarikan_ss') : n('tarik_ss');
    acc.penarikanSp = n('penarikan_sp') != 0 ? n('penarikan_sp') : n('tarik_sp');
    acc.penarikanSh = n('penarikan_sh') != 0 ? n('penarikan_sh') : n('tarik_sh');
    acc.penarikanSd = n('penarikan_sd') != 0 ? n('penarikan_sd') : n('tarik_sd');
    acc.inventaris = n('inventaris');
    acc.bankKeluar = n('bank_keluar') != 0 ? n('bank_keluar') : n('bk_keluar');
    acc.biaya = n('biaya');
    acc.kasDebet = n('kas_debet') != 0 ? n('kas_debet') : n('debet');
    acc.kasKredit = n('kas_kredit') != 0 ? n('kas_kredit') : n('kredit');
    acc.danaDana = n('dana_dana') != 0 ? n('dana_dana') : n('dana');
    acc.uangPangkal = n('uang_pangkal') != 0 ? n('uang_pangkal') : n('up_pangkal');
    acc.simpananSp = n('simpanan_sp') != 0 ? n('simpanan_sp') : n('simpan_sp');
    acc.simpananSw = n('simpanan_sw') != 0 ? n('simpanan_sw') : n('simpan_sw');
    acc.simpananSs = n('simpanan_ss') != 0 ? n('simpanan_ss') : n('simpan_ss');
    acc.simpananSh = n('simpanan_sh') != 0 ? n('simpanan_sh') : n('simpan_sh');
    acc.simpananSd = n('simpanan_sd') != 0 ? n('simpanan_sd') : n('simpan_sd');
    acc.angsuranPokok = n('angsuran_pokok') != 0 ? n('angsuran_pokok') : n('ang_pokok');
    acc.jasaPinjaman = n('jasa_pinjaman') != 0 ? n('jasa_pinjaman') : n('jasa_pinj');
    acc.dendaPenalti = n('denda_penalti') != 0 ? n('denda_penalti') : n('denda');
    acc.provisiPinjaman = n('provisi_pinjaman') != 0 ? n('provisi_pinjaman') : n('provisi');
    acc.asuransi = n('asuransi');
    acc.lainLain = n('lain_lain') != 0 ? n('lain_lain') : n('lain2');
    acc.bankMasuk = n('bank_masuk') != 0 ? n('bank_masuk') : n('bri_masuk');
    return acc;
  }

  bool get hasNonZeroValues =>
      piutang != 0 ||
      penarikanSw != 0 ||
      penarikanSs != 0 ||
      penarikanSp != 0 ||
      penarikanSh != 0 ||
      penarikanSd != 0 ||
      inventaris != 0 ||
      bankKeluar != 0 ||
      biaya != 0 ||
      kasDebet != 0 ||
      kasKredit != 0 ||
      danaDana != 0 ||
      uangPangkal != 0 ||
      simpananSp != 0 ||
      simpananSw != 0 ||
      simpananSs != 0 ||
      simpananSh != 0 ||
      simpananSd != 0 ||
      angsuranPokok != 0 ||
      jasaPinjaman != 0 ||
      dendaPenalti != 0 ||
      provisiPinjaman != 0 ||
      asuransi != 0 ||
      lainLain != 0 ||
      bankMasuk != 0;

  void addRow(TabelarisRow r) {
    piutang += r.piutang;
    penarikanSw += r.penarikanSw;
    penarikanSs += r.penarikanSs;
    penarikanSp += r.penarikanSp;
    penarikanSh += r.penarikanSh;
    penarikanSd += r.penarikanSd;
    inventaris += r.inventaris;
    bankKeluar += r.bankKeluar;
    biaya += r.biaya;
    kasDebet += r.kasDebet;
    kasKredit += r.kasKredit;
    danaDana += r.danaDana;
    uangPangkal += r.uangPangkal;
    simpananSp += r.simpananSp;
    simpananSw += r.simpananSw;
    simpananSs += r.simpananSs;
    simpananSh += r.simpananSh;
    simpananSd += r.simpananSd;
    angsuranPokok += r.angsuranPokok;
    jasaPinjaman += r.jasaPinjaman;
    dendaPenalti += r.dendaPenalti;
    provisiPinjaman += r.provisiPinjaman;
    asuransi += r.asuransi;
    lainLain += r.lainLain;
    bankMasuk += r.bankMasuk;
  }

  void add(TabelarisAccumulator o) {
    piutang += o.piutang;
    penarikanSw += o.penarikanSw;
    penarikanSs += o.penarikanSs;
    penarikanSp += o.penarikanSp;
    penarikanSh += o.penarikanSh;
    penarikanSd += o.penarikanSd;
    inventaris += o.inventaris;
    bankKeluar += o.bankKeluar;
    biaya += o.biaya;
    kasDebet += o.kasDebet;
    kasKredit += o.kasKredit;
    danaDana += o.danaDana;
    uangPangkal += o.uangPangkal;
    simpananSp += o.simpananSp;
    simpananSw += o.simpananSw;
    simpananSs += o.simpananSs;
    simpananSh += o.simpananSh;
    simpananSd += o.simpananSd;
    angsuranPokok += o.angsuranPokok;
    jasaPinjaman += o.jasaPinjaman;
    dendaPenalti += o.dendaPenalti;
    provisiPinjaman += o.provisiPinjaman;
    asuransi += o.asuransi;
    lainLain += o.lainLain;
    bankMasuk += o.bankMasuk;
  }
}

class TabelarisTableView extends StatelessWidget {
  final List<TabelarisRow> allRows;
  final List<TabelarisRow> pageRows;
  final int startIndex;
  final ScrollController? horizontalScrollController;
  final TabelarisAccumulator? apiSaldoHalLalu;
  final TabelarisAccumulator? apiJumlahSdHalIni;

  const TabelarisTableView({
    super.key,
    required this.allRows,
    required this.pageRows,
    required this.startIndex,
    this.horizontalScrollController,
    this.apiSaldoHalLalu,
    this.apiJumlahSdHalIni,
  });

  static const double _wTgl = 80;
  static const double _wBukti = 110;
  static const double _wNba = 72;
  static const double _wNama = 190;
  static const double _wNum = 105;

  static String formatNum(double val, {bool showDashIfZero = true}) {
    if (val == 0 || val.abs() < 0.0001) return showDashIfZero ? '-' : '0';
    return val
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    // 1. Akumulasi Halaman Ini (JUMLAH HAL INI)
    final halIni = TabelarisAccumulator();
    for (final r in pageRows) {
      halIni.addRow(r);
    }

    // 2. Akumulasi Halaman Lalu (SALDO HAL LALU)
    // Menggabungkan saldo_hal_lalu dari API (bila ada) ditambah akumulasi baris sebelum startIndex
    final halLalu = TabelarisAccumulator();
    if (apiSaldoHalLalu != null) {
      halLalu.add(apiSaldoHalLalu!);
    }
    if (startIndex > 0) {
      final prevRows = allRows.sublist(0, startIndex.clamp(0, allRows.length));
      for (final r in prevRows) {
        halLalu.addRow(r);
      }
    }

    // 3. Akumulasi s/d Halaman Ini (JUMLAH S/D HAL INI)
    final sdHalIni = TabelarisAccumulator();
    if (apiJumlahSdHalIni != null && startIndex == 0 && allRows.length == pageRows.length) {
      sdHalIni.add(apiJumlahSdHalIni!);
    } else {
      sdHalIni.add(halLalu);
      sdHalIni.add(halIni);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          controller: horizontalScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: horizontalScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 3100),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGroupHeader(),
                    _buildSubHeader(),
                    ...pageRows.asMap().entries.map(
                          (e) => _buildDataRow(startIndex + e.key, e.value),
                        ),
                    _buildAccumulationRow(
                      title: 'JUMLAH HAL INI',
                      acc: halIni,
                      bgColor: const Color(0xFF1E293B),
                      textColor: const Color(0xFF67E8F9),
                    ),
                    _buildAccumulationRow(
                      title: 'SALDO HAL LALU',
                      acc: halLalu,
                      bgColor: const Color(0xFF0F172A),
                      textColor: const Color(0xFFFDE047),
                    ),
                    _buildAccumulationRow(
                      title: 'JUMLAH S/D HAL INI',
                      acc: sdHalIni,
                      bgColor: const Color(0xFF0B132B),
                      textColor: const Color(0xFF4ADE80),
                      isFinal: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ─── 1. GROUP HEADER (Pengeluaran -> Kas -> Pemasukan) ─────────────────────
  Widget _buildGroupHeader() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          _hC('', width: _wTgl + _wBukti + _wNba + _wNama),
          _hC('PENGELUARAN', width: _wNum * 9, bl: true, color: const Color(0xFFE2E8F0)),
          _hC('KAS', width: _wNum * 2, bl: true, color: const Color(0xFF38BDF8)),
          _hC('PEMASUKAN', width: _wNum * 14, bl: true, color: const Color(0xFF4ADE80)),
        ],
      ),
    );
  }

  /// ─── 2. SUB HEADER (29 Kolom Sesuai Urutan Baru) ───────────────────────────
  Widget _buildSubHeader() {
    return Container(
      color: const Color(0xFF334155),
      child: Row(
        children: [
          // Identitas / Meta (4 Kolom)
          _hC('Tgl', width: _wTgl, fs: 10),
          _hC('No Bukti', width: _wBukti, bl: true, fs: 10),
          _hC('NBA', width: _wNba, bl: true, fs: 10),
          _hC('Nama Anggota', width: _wNama, bl: true, fs: 10),

          // PENGELUARAN (9 Kolom)
          _hC('Piutang', width: _wNum, bl: true, fs: 10),
          _hC('Tarik SW', width: _wNum, bl: true, fs: 10),
          _hC('Tarik SS', width: _wNum, bl: true, fs: 10),
          _hC('Tarik SP', width: _wNum, bl: true, fs: 10),
          _hC('Tarik SH', width: _wNum, bl: true, fs: 10),
          _hC('Tarik SD', width: _wNum, bl: true, fs: 10),
          _hC('Inventaris', width: _wNum, bl: true, fs: 10),
          _hC('Bk Keluar', width: _wNum, bl: true, fs: 10),
          _hC('Biaya', width: _wNum, bl: true, fs: 10),

          // KAS (2 Kolom - Debet & Kredit Tepat Setelah Pengeluaran)
          _hC('Kas Debet (KM)', width: _wNum, bl: true, fs: 10, color: const Color(0xFF93C5FD)),
          _hC('Kas Kredit (KK)', width: _wNum, bl: true, fs: 10, color: const Color(0xFFFCA5A5)),

          // PEMASUKAN (14 Kolom)
          _hC('Dana', width: _wNum, bl: true, fs: 10),
          _hC('Up. Pangkal', width: _wNum, bl: true, fs: 10),
          _hC('Simpan SP', width: _wNum, bl: true, fs: 10),
          _hC('Simpan SW', width: _wNum, bl: true, fs: 10),
          _hC('Simpan SS', width: _wNum, bl: true, fs: 10),
          _hC('Simpan SH', width: _wNum, bl: true, fs: 10),
          _hC('Simpan SD', width: _wNum, bl: true, fs: 10),
          _hC('Ang Pokok', width: _wNum, bl: true, fs: 10),
          _hC('Jasa Pinj', width: _wNum, bl: true, fs: 10),
          _hC('Denda', width: _wNum, bl: true, fs: 10),
          _hC('Provisi', width: _wNum, bl: true, fs: 10),
          _hC('Asuransi', width: _wNum, bl: true, fs: 10),
          _hC('Lain2', width: _wNum, bl: true, fs: 10),
          _hC('BRI Masuk', width: _wNum, bl: true, fs: 10),
        ],
      ),
    );
  }

  /// ─── 3. DATA ROW (29 Kolom) ────────────────────────────────────────────────
  Widget _buildDataRow(int idx, TabelarisRow r) {
    final bool isKm = r.type.toLowerCase().contains('km') ||
        r.type.toLowerCase().contains('deposit') ||
        r.type.toLowerCase().contains('in');
    final Color rowBg = idx % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC);
    final Color typeColor = isKm ? Colors.blue[700]! : Colors.red[700]!;

    return Container(
      color: rowBg,
      child: Row(
        children: [
          // Meta
          _dC(r.tgl, w: _wTgl, al: Alignment.center, fs: 11),
          _dC(r.noBukti, w: _wBukti, bl: true, cl: typeColor, bold: true, fs: 11),
          _dC(r.nba, w: _wNba, bl: true, al: Alignment.center, fs: 11),
          _dC(r.nama, w: _wNama, bl: true, al: Alignment.centerLeft, fs: 11),

          // PENGELUARAN (9 Kolom)
          _nC(r.piutang, w: _wNum, bl: true),
          _nC(r.penarikanSw, w: _wNum, bl: true),
          _nC(r.penarikanSs, w: _wNum, bl: true),
          _nC(r.penarikanSp, w: _wNum, bl: true),
          _nC(r.penarikanSh, w: _wNum, bl: true),
          _nC(r.penarikanSd, w: _wNum, bl: true),
          _nC(r.inventaris, w: _wNum, bl: true),
          _nC(r.bankKeluar, w: _wNum, bl: true),
          _nC(r.biaya, w: _wNum, bl: true),

          // KAS (2 Kolom)
          _nC(r.kasDebet, w: _wNum, bl: true, cl: Colors.blue[700], bold: r.kasDebet > 0),
          _nC(r.kasKredit, w: _wNum, bl: true, cl: Colors.red[700], bold: r.kasKredit > 0),

          // PEMASUKAN (14 Kolom)
          _nC(r.danaDana, w: _wNum, bl: true),
          _nC(r.uangPangkal, w: _wNum, bl: true),
          _nC(r.simpananSp, w: _wNum, bl: true),
          _nC(r.simpananSw, w: _wNum, bl: true),
          _nC(r.simpananSs, w: _wNum, bl: true),
          _nC(r.simpananSh, w: _wNum, bl: true),
          _nC(r.simpananSd, w: _wNum, bl: true),
          _nC(r.angsuranPokok, w: _wNum, bl: true),
          _nC(r.jasaPinjaman, w: _wNum, bl: true),
          _nC(r.dendaPenalti, w: _wNum, bl: true),
          _nC(r.provisiPinjaman, w: _wNum, bl: true),
          _nC(r.asuransi, w: _wNum, bl: true),
          _nC(r.lainLain, w: _wNum, bl: true),
          _nC(r.bankMasuk, w: _wNum, bl: true),
        ],
      ),
    );
  }

  /// ─── 4. ACCUMULATION ROWS (Footer) ─────────────────────────────────────────
  Widget _buildAccumulationRow({
    required String title,
    required TabelarisAccumulator acc,
    required Color bgColor,
    required Color textColor,
    bool isFinal = false,
  }) {
    return Container(
      color: bgColor,
      child: Row(
        children: [
          // Meta Header Label
          _dC(
            title,
            w: _wTgl + _wBukti + _wNba + _wNama,
            al: Alignment.center,
            bold: true,
            cl: textColor,
            fs: 11.5,
          ),

          // PENGELUARAN (9 Kolom)
          _nC(acc.piutang, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.penarikanSw, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.penarikanSs, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.penarikanSp, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.penarikanSh, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.penarikanSd, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.inventaris, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.bankKeluar, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.biaya, w: _wNum, bl: true, cl: textColor, bold: true),

          // KAS (2 Kolom)
          _nC(acc.kasDebet, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.kasKredit, w: _wNum, bl: true, cl: textColor, bold: true),

          // PEMASUKAN (14 Kolom)
          _nC(acc.danaDana, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.uangPangkal, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.simpananSp, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.simpananSw, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.simpananSs, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.simpananSh, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.simpananSd, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.angsuranPokok, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.jasaPinjaman, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.dendaPenalti, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.provisiPinjaman, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.asuransi, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.lainLain, w: _wNum, bl: true, cl: textColor, bold: true),
          _nC(acc.bankMasuk, w: _wNum, bl: true, cl: textColor, bold: true),
        ],
      ),
    );
  }

  Widget _hC(
    String t, {
    required double width,
    bool bl = false,
    double fs = 11,
    Color? color,
  }) =>
      Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          border: bl
              ? const Border(left: BorderSide(color: Colors.white24, width: 1))
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fs,
          ),
        ),
      );

  Widget _dC(
    String t, {
    required double w,
    Alignment al = Alignment.centerRight,
    bool bl = false,
    bool bold = false,
    Color? cl,
    double fs = 12,
  }) =>
      Container(
        width: w,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withValues(alpha: 0.15),
              width: 0.5,
            ),
            left: bl
                ? BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 0.5,
                  )
                : BorderSide.none,
          ),
        ),
        alignment: al,
        child: Text(
          t,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: fs,
            color: cl ?? Colors.black87,
          ),
        ),
      );

  Widget _nC(
    double val, {
    required double w,
    bool bl = false,
    Color? cl,
    bool bold = false,
  }) =>
      _dC(formatNum(val), w: w, bl: bl, cl: cl, bold: bold);
}
