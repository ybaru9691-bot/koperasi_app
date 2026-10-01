/// 👥 Model Data Detail & Portofolio Anggota Koperasi (Ketua View)
class MemberDetailModel {
  final String id;
  final String memberNo; // NIA
  final String nik;
  final String name;
  final String phone;
  final String address;
  final String churchUnit;
  final String joinDate;
  final String status; // 'aktif', 'non-aktif'
  final String bukuPutihNo;
  final MemberFinancialSummaryModel financialSummary;

  MemberDetailModel({
    required this.id,
    required this.memberNo,
    required this.nik,
    required this.name,
    required this.phone,
    required this.address,
    required this.churchUnit,
    required this.joinDate,
    required this.status,
    this.bukuPutihNo = '-',
    required this.financialSummary,
  });

  factory MemberDetailModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawBp = json['buku_putih_no'] ??
                          json['no_rekening_buku_putih'] ??
                          json['buku_putih_account_no'] ??
                          json['buku_putih_number'] ??
                          json['no_buku_putih'] ??
                          json['buku_putih_rek'] ??
                          json['rekening_buku_putih'];
    String bp = '-';
    if (rawBp != null && rawBp is! Map && rawBp is! List) {
      final s = rawBp.toString().trim();
      if (s.isNotEmpty && s != '-' && s != 'null' && !s.startsWith('{')) {
        bp = s;
      }
    }

    return MemberDetailModel(
      id: json['id']?.toString() ?? '',
      memberNo: (json['member_no'] ?? json['no_anggota'] ?? json['nia'] ?? json['member_number'] ?? json['no_buku'] ?? json['id'])?.toString() ?? '',
      nik: json['nik']?.toString() ?? '',
      name: json['name']?.toString() ?? json['nama']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['no_hp']?.toString() ?? '',
      address: json['address']?.toString() ?? json['alamat']?.toString() ?? '',
      churchUnit: json['church_unit']?.toString() ?? json['unit_gereja']?.toString() ?? '',
      joinDate: json['join_date']?.toString() ?? json['tgl_bergabung']?.toString() ?? '',
      status: (json['status'] ?? 'aktif').toString().toLowerCase(),
      bukuPutihNo: bp,
      financialSummary: MemberFinancialSummaryModel.fromJson(
        json['financial_summary'] != null
            ? Map<String, dynamic>.from(json['financial_summary'])
            : json
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_no': memberNo,
      'nik': nik,
      'name': name,
      'phone': phone,
      'address': address,
      'church_unit': churchUnit,
      'join_date': joinDate,
      'status': status,
      'financial_summary': financialSummary.toJson(),
    };
  }

  static List<MemberDetailModel> getDummyMembers() {
    return [
      MemberDetailModel(
        id: '1',
        memberNo: '2562',
        nik: '1403011508820001',
        name: 'St. M. Simanjuntak',
        phone: '0812-7654-3210',
        address: 'Jl. Jend. Sudirman No. 42, Duri Kota',
        churchUnit: 'HKBP Bethania Duri',
        joinDate: '12 Januari 2020',
        status: 'aktif',
        financialSummary: MemberFinancialSummaryModel(
          simpananPokok: 500000,
          simpananWajib: 3600000,
          simpananSukarela: 15400000,
          simpananHarian: 5000000,
          hasActiveLoan: true,
          loanAmount: 25000000,
          remainingLoan: 18500000,
          paymentTrackRecord: 'Lancar',
          totalPortfolio: 0,
        ),
      ),
      MemberDetailModel(
        id: '2',
        memberNo: '2563',
        nik: '1403012204900004',
        name: 'Farida Suzana',
        phone: '0852-9876-1234',
        address: 'Jl. Hangtuah No. 88, Mandau',
        churchUnit: 'GKPI Duri Restu',
        joinDate: '05 Maret 2021',
        status: 'aktif',
        financialSummary: MemberFinancialSummaryModel(
          simpananPokok: 500000,
          simpananWajib: 2400000,
          simpananSukarela: 8200000,
          simpananHarian: 1500000,
          hasActiveLoan: true,
          loanAmount: 10000000,
          remainingLoan: 4200000,
          paymentTrackRecord: 'Lancar',
          totalPortfolio: 0,
        ),
      ),
      MemberDetailModel(
        id: '3',
        memberNo: '2564',
        nik: '1403010511850002',
        name: 'J. Nainggolan',
        phone: '0813-2345-6789',
        address: 'Jl. Mawar No. 12, Duri',
        churchUnit: 'HKBP Simpang Padang',
        joinDate: '15 Agustus 2019',
        status: 'non-aktif',
        financialSummary: MemberFinancialSummaryModel(
          simpananPokok: 500000,
          simpananWajib: 1200000,
          simpananSukarela: 500000,
          simpananHarian: 0,
          hasActiveLoan: false,
          loanAmount: 0,
          remainingLoan: 0,
          paymentTrackRecord: '-',
          totalPortfolio: 0,
        ),
      ),
      MemberDetailModel(
        id: '4',
        memberNo: '2565',
        nik: '1403013008950009',
        name: 'R. Tampubolon',
        phone: '0821-4567-8901',
        address: 'Jl. Obor 1 No. 5, Duri',
        churchUnit: 'HKBP Ebenezer',
        joinDate: '20 Februari 2022',
        status: 'aktif',
        financialSummary: MemberFinancialSummaryModel(
          simpananPokok: 500000,
          simpananWajib: 1800000,
          simpananSukarela: 2000000,
          simpananHarian: 1000000,
          hasActiveLoan: true,
          loanAmount: 5000000,
          remainingLoan: 1500000,
          paymentTrackRecord: 'Lancar',
          totalPortfolio: 0,
        ),
      ),
      MemberDetailModel(
        id: '5',
        memberNo: '2540',
        nik: '1403016012750003',
        name: 'J. Rajagukguk',
        phone: '0813-1122-3344',
        address: 'Jl. Sebanga No. 4, Mandau',
        churchUnit: 'HKBP Sebanga Duri',
        joinDate: '01 Juni 2017',
        status: 'non-aktif',
        financialSummary: MemberFinancialSummaryModel(
          simpananPokok: 500000,
          simpananWajib: 1200000,
          simpananSukarela: 0,
          simpananHarian: 0,
          hasActiveLoan: false,
          loanAmount: 0,
          remainingLoan: 0,
          paymentTrackRecord: 'Non-Aktif / Pensiun',
          totalPortfolio: 0,
        ),
      ),
    ];
  }
}

class MemberFinancialSummaryModel {
  final double simpananPokok;
  final double simpananWajib;
  final double simpananSukarela;
  final double simpananHarian;
  final bool hasActiveLoan;
  final double loanAmount;
  final double remainingLoan;
  final String paymentTrackRecord; // 'Lancar', 'Menunggak', 'Sangat Baik'
  final double totalPortfolio;

  MemberFinancialSummaryModel({
    required this.simpananPokok,
    required this.simpananWajib,
    required this.simpananSukarela,
    required this.simpananHarian,
    required this.hasActiveLoan,
    required this.loanAmount,
    required this.remainingLoan,
    required this.paymentTrackRecord,
    required this.totalPortfolio,
  });

  double get totalSimpanan => simpananPokok + simpananWajib + simpananSukarela + simpananHarian;

  factory MemberFinancialSummaryModel.empty() {
    return MemberFinancialSummaryModel(
      simpananPokok: 0,
      simpananWajib: 0,
      simpananSukarela: 0,
      simpananHarian: 0,
      hasActiveLoan: false,
      loanAmount: 0,
      remainingLoan: 0,
      paymentTrackRecord: '-',
      totalPortfolio: 0,
    );
  }

  factory MemberFinancialSummaryModel.fromJson(Map<String, dynamic> json) {
    // Parsing aman: Cek apakah data berada di root, di dalam 'data', atau di 'savings_portfolio'
    final rootData = json['data'] as Map<String, dynamic>? ?? json;
    final portfolio = rootData['savings_portfolio'] as Map<String, dynamic>? ?? rootData;

    double parseVal(dynamic value) {
      if (value == null) return 0.0;
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return MemberFinancialSummaryModel(
      simpananPokok: parseVal(portfolio['simpanan_pokok'] ?? rootData['simpanan_pokok']),
      simpananWajib: parseVal(portfolio['simpanan_wajib'] ?? rootData['simpanan_wajib']),
      simpananSukarela: parseVal(portfolio['simpanan_sukarela'] ?? rootData['simpanan_sukarela']),
      simpananHarian: parseVal(
        portfolio['simpanan_harian'] ?? 
        portfolio['tabungan_harian'] ?? 
        rootData['simpanan_harian'] ?? 
        rootData['daily_savings']
      ),
      hasActiveLoan: rootData['has_active_loan'] as bool? ?? false,
      loanAmount: parseVal(rootData['loan_amount']),
      remainingLoan: parseVal(rootData['remaining_loan']),
      paymentTrackRecord: rootData['payment_track_record']?.toString() ?? 'Lancar',
      totalPortfolio: parseVal(rootData['total_portfolio'] ?? rootData['total_savings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'simpanan_pokok': simpananPokok,
      'simpanan_wajib': simpananWajib,
      'simpanan_sukarela': simpananSukarela,
      'simpanan_harian': simpananHarian,
      'has_active_loan': hasActiveLoan,
      'loan_amount': loanAmount,
      'remaining_loan': remainingLoan,
      'payment_track_record': paymentTrackRecord,
      'total_portfolio': totalPortfolio,
    };
  }
}
