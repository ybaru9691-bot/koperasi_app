# 🏦 Sistem Aplikasi Koperasi CUM Pelita

Aplikasi **Koperasi CUM Pelita** adalah platform enterprise modern berbasis **Flutter (Multi-Platform: Web & Mobile)** yang dirancang untuk mendigitalkan seluruh operasional koperasi simpan pinjam secara menyeluruh, akuntabel, dan *real-time*. Sistem ini terhubung langsung ke **RESTful API Backend Laravel** dengan arsitektur multi-peran (*Multi-Role Access Control*): **Anggota**, **Admin (Kasir/Operasional)**, dan **Ketua (Manajer Eksekutif)**.

---

## 📑 Daftar Isi
1. [Arsitektur & Tech Stack](#-arsitektur--tech-stack)
2. [Peran Pengguna & Modul Utama](#-peran-pengguna--modul-utama)
3. [Struktur Folder Frontend (lib/)](#-struktur-folder-frontend-lib)
4. [Alur Bisnis Utama (Core Business Workflows)](#-alur-bisnis-utama-core-business-workflows)
5. [Spesifikasi Fitur Finansial Khusus](#-spesifikasi-fitur-finansial-khusus)
6. [Integrasi API Backend](#-integrasi-api-backend)
7. [Panduan Instalasi & Menjalankan Aplikasi](#-panduan-instalasi--menjalankan-aplikasi)

---

## 🛠️ Arsitektur & Tech Stack

| Layer | Teknologi & Pustaka | Deskripsi |
| :--- | :--- | :--- |
| **Frontend Framework** | **Flutter SDK (Dart 3.x)** | Clean UI, Responsive Web & Mobile Android/iOS |
| **State & Controller** | StatefulWidgets, Custom Controllers | Pemisahan State UI, Form Controllers, dan Service Layer |
| **Visualisasi Finansial** | `fl_chart: ^0.70.2` | Grafik Tren Arus Kas, Bar Chart & Line Chart Dinamis |
| **Networking & HTTP** | `http: ^1.2.0` | HTTP Client dengan timeout handling, bearer token injection & multi-part upload |
| **Storage & Keamanan** | `flutter_secure_storage: ^9.0.0`, `shared_preferences: ^2.2.2` | Token JWT/Sanctum terenkripsi & cache preferensi lokal |
| **Konektivitas** | `connectivity_plus: ^7.3.1` | Network Awareness Wrapper untuk mendeteksi offline/online |
| **Export & Format Data** | `intl: ^0.19.0`, Native Web Blob & PDF Service | Format Rupiah IDR, Ekspor Excel (.xlsx), dan PDF Landscape (A3/Folio) |

---

## 👥 Peran Pengguna & Modul Utama

```
                      ┌─────────────────────────────────────────┐
                      │        Koperasi CUM Pelita System       │
                      └────────────────────┬────────────────────┘
                                           │
         ┌─────────────────────────────────┼─────────────────────────────────┐
         ▼                                 ▼                                 ▼
┌──────────────────┐             ┌──────────────────┐             ┌──────────────────┐
│  PORTAL ANGGOTA  │             │   PORTAL ADMIN   │             │  PORTAL MANAJER  │
│     (MEMBER)     │             │     (KASIR)      │             │     (KETUA)      │
└────────┬─────────┘             └────────┬─────────┘             └────────┬─────────┘
         │                                │                                │
         ├─ Portofolio Simpanan           ├─ Kas Masuk (KM) / Keluar (KK)  ├─ Approval Pinjaman & Pencairan
         ├─ Buku Biru & Buku Putih        ├─ Kelola Master Anggota         ├─ Distribusi SHU & Deviden
         ├─ Pengajuan Pinjaman Mandiri    ├─ Riwayat Transaksi Pinjaman    ├─ Jurnal Tabelaris (29 Kolom)
         ├─ Riwayat Angsuran              ├─ Verifikasi Pinjaman Tahap 1   ├─ Neraca Lajur (10 Kolom)
         └─ Konfirmasi Setoran Manual     ├─ Audit Log & Backup Database   ├─ Catat Saldo & Beban Operasional
                                          └─ SOP & Panduan Operasional     └─ Laporan Eksekutif Keuangan
```

### 1. 📱 Portal Anggota (`/member`)
* **Ringkasan Finansial**: Dashboard saldo total, mutasi rekening simpanan, dan status pinjaman aktif.
* **Buku Biru (Saham Keanggotaan)**: Pencatatan Simpanan Pokok (SP), Simpanan Wajib (SW), dan Simpanan Sukarela (SS).
* **Buku Putih (Tabungan Harian)**: Rekening fleksibel harian dengan simulasi bagi hasil/jasa, penarikan, dan proteksi saldo mengendap.
* **Pengajuan Pinjaman Online**: Form pengajuan pinjaman modal/multiguna (nominal, tenor 3–24 bulan, estimasi angsuran, agunan & alasan pinjaman).
* **Kartu Pinjaman & Angsuran**: Rincian tagihan per bulan, sisa pokok pinjaman, jasa pinjaman, serta riwayat pembayaran angsuran.
* **Setoran Manual**: Upload bukti transfer bank untuk diverifikasi admin kasir.

### 2. 💼 Portal Admin / Kasir (`/admin`)
* **Dashboard Kasir**: Statistik real-time total kas harian, transaksi tertunda, dan ringkasan anggota aktif.
* **Input Transaksi Kas Masuk (KM) & Kas Keluar (KK)**:
  * Pembuatan Nomor Bukti otomatis (`KM-YYYYMMDD-XXXX` / `KK-YYYYMMDD-XXXX`).
  * Dropdown dinamis COA (Chart of Accounts) dan anggota aktif.
  * Preview & Cetak Struk/Kwitansi Transaksi.
* **Kelola Anggota**: Registrasi anggota baru (penomoran NBA otomatis), update biodata, nonaktif/keluar, dan monitoring rekening.
* **Riwayat Transaksi Pinjaman**: Rekapitulasi transaksi pencairan pinjaman (KK) dan setoran angsuran (KM).
* **Verifikasi Pinjaman (Tahap 1)**: Verifikasi kelengkapan berkas pengajuan pinjaman anggota sebelum diteruskan ke Manajer.
* **Migrasi & Backup Data**: Unggah berkas Excel migrasi saldo awal dan manajemen backup/restore database.
* **Panduan SOP Interaktif**: Panduan langkah operasional kasir, penarikan, dan pencatatan kas.

### 3. 👔 Portal Ketua / Manajer Eksekutif (`/ketua`)
* **Executive Financial Dashboard**: Visualisasi KPI koperasi, rasio likuiditas, rasio kolektibilitas pinjaman, dan tren kas bulanan.
* **Persetujuan & Pencairan Pinjaman (Manager Approval)**: Otorisasi final pinjaman yang lolos verifikasi admin dan eksekusi pencairan (*Disbursement*).
* **Manajemen Distribusi SHU & Deviden (12 Bulan)**:
  * Pelacakan performa SHU bulanan (Juni hingga Mei).
  * Simulasi pembagian porsi 25% SHU Anggota berdasarkan proporsi unit saham (Simpanan Pokok + Wajib + Sukarela).
  * Eksekusi distribusi dividen otomatis ke rekening simpanan anggota dan penerbitan *Member Dividend Statement*.
* **Jurnal Tabelaris Presisi (29 Kolom)**: Buku harian berstandar koperasi dengan *Balance Checker* (Debet vs Kredit) dan akumulasi berjalan (*Jumlah Hal Ini, Saldo Hal Lalu, Jumlah s/d Hal Ini*).
* **Neraca Lajur (Worksheet 10 Kolom)**: Laporan keuangan komprehensif (Neraca Saldo, Penyesuaian, Neraca Disesuaikan, Laba/Rugi, dan Neraca Akhir).
* **Catat Beban Operasional & Tambah Saldo**: Penyesuaian kas dan beban harian koperasi.
* **Manajemen Periode Buku**: Pembukaan, penutupan, dan penguncian buku kas bulanan/tahunan.

---

## 📂 Struktur Folder Frontend (lib/)

Struktur direktori pada `lib/` disusun secara modular dan clean architecture:

```text
d:\koperasi_app\lib\
│
├── main.dart                                # Entry point aplikasi & inisialisasi route utama
│
├── constants/                               # Pengaturan konstanta global aplikasi
│   ├── app_assets.dart                      # Path icon, ilustrasi & logo koperasi
│   ├── app_colors.dart                      # Palet warna primer, sekunder, background & alert
│   └── app_constants.dart                   # Konstanta konfigurasi umum
│
├── core/                                    # Pondasi arsitektur & tema aplikasi
│   ├── constants/
│   │   └── api_endpoints.dart               # Daftar routing URL REST API Backend Laravel
│   └── theme/
│       ├── app_colors.dart                  # Sistem warna tema koperasi
│       ├── app_decorations.dart             # BoxDecorations, border radius & shadow reusable
│       └── app_text_styles.dart             # Tipografi teks standar (Heading, Body, Caption)
│
├── controllers/                             # Pengendali logika bisnis dan form state
│   ├── auth_controller.dart                 # State login, logout, dan pemulihan sesi
│   ├── manual_deposit_controller.dart       # State pengajuan setoran manual anggota
│   └── savings_controller.dart              # State portofolio rekening simpanan
│
├── data/                                    # Data source, data model & dummy data
│   ├── dummy/
│   │   ├── admin_dummy_data.dart            # Mock data dashboard admin
│   │   └── ketua_dummy_data.dart            # Mock data eksekutif manajer
│   └── models/
│       ├── activity_log_model.dart          # Model log riwayat aktivitas sistem
│       ├── announcement_model.dart          # Model pengumuman informasi koperasi
│       ├── approval_data_model.dart         # Model data persetujuan pinjaman/transaksi
│       ├── backup_file_model.dart           # Model metadata file cadangan database
│       ├── executive_report_model.dart      # Model data laporan keuangan eksekutif
│       ├── member_detail_model.dart         # Model lengkap profil & rekening anggota
│       ├── member_model.dart                # Model entitas anggota
│       ├── pending_approval_model.dart      # Model antrean persetujuan transaksi
│       ├── period_model.dart                # Model periode akuntansi buku
│       ├── system_setting_model.dart        # Model parameter konfigurasi sistem
│       ├── transaction_model.dart           # Model entitas transaksi kasir
│       └── user_model.dart                  # Model autentikasi pengguna
│
├── models/                                  # Model pendukung untuk modul mobile
│   ├── admin_stat_model.dart
│   ├── manual_deposit_model.dart
│   ├── member_data_model.dart
│   ├── promo_model.dart
│   ├── savings_model.dart
│   ├── transaction_data_model.dart
│   ├── transaction_model.dart
│   └── user_model.dart
│
├── screens/                                 # Seluruh antarmuka tampilan (Views)
│   ├── dashboard_router.dart                # Router pengarah peran (Member/Admin/Ketua)
│   │
│   ├── auth/                                # Layar autentikasi
│   │   ├── splash_screen.dart               # Splash screen & token session check
│   │   └── welcome_screen.dart              # Layar login multi-role
│   │
│   ├── member/                              # Modul Layar Portal Anggota
│   │   ├── home_screen.dart                 # Beranda nasabah (Buku Biru & Buku Putih)
│   │   ├── loan_screen.dart                 # Halaman pengajuan & status pinjaman
│   │   ├── my_loan_screen.dart              # Detail pinjaman aktif & riwayat angsuran
│   │   ├── savings_screen.dart              # Rincian mutasi tabungan & simpanan
│   │   ├── manual_deposit_submission_screen.dart # Form upload bukti setoran
│   │   ├── profile_screen.dart              # Profil akun & informasi NBA
│   │   └── edit_profile_screen.dart         # Ubah data kontak & password
│   │
│   ├── admin/                               # Modul Layar Portal Admin / Kasir
│   │   ├── admin_main_screen.dart           # Shell layout navigasi drawer admin
│   │   ├── admin_dashboard_screen.dart      # Dashboard ringkasan operasional kasir
│   │   ├── input_transaksi_screen.dart      # Form pencatatan Kas Masuk & Kas Keluar
│   │   ├── kelola_anggota_screen.dart       # Daftar master anggota & filter status
│   │   ├── tambah_anggota_screen.dart       # Form registrasi anggota baru (NBA Auto)
│   │   ├── edit_anggota_screen.dart         # Form edit data anggota
│   │   ├── member_detail_screen.dart        # Detail rekening & mutasi individual
│   │   ├── cash_loan_recap_screen.dart      # Riwayat transaksi pinjaman & pencairan
│   │   ├── loan_approval_screen.dart        # Layar verifikasi pinjaman tahap 1
│   │   ├── loan_card_screen.dart            # Kartu pinjaman anggota
│   │   ├── loan_installment_card_screen.dart# Kartu simulasi angsuran pinjaman
│   │   ├── admin_keuangan_screen.dart       # Buku besar kas & mutasi keuangan
│   │   ├── admin_worksheet_screen.dart      # Neraca lajur 10 kolom admin
│   │   ├── migration_screen.dart            # Migrasi data via file Excel
│   │   ├── backup_restore_screen.dart       # Manajemen backup & restore sistem
│   │   ├── audit_log_screen.dart            # Layar audit trail aktivitas operator
│   │   ├── admin_profile_screen.dart        # Profil admin & Panduan SOP Sistem
│   │   └── widgets/                         # Widget internal layar admin
│   │       ├── admin_header.dart
│   │       ├── admin_stat_cards.dart
│   │       ├── admin_table.dart
│   │       ├── audit_log_components.dart
│   │       ├── backup_components.dart
│   │       └── excel_upload_components.dart
│   │
│   ├── ketua/                               # Modul Layar Portal Ketua / Manajer
│   │   ├── dashboard_ketua_screen.dart      # Dashboard analitik & KPI eksekutif
│   │   ├── transaction_approval_screen.dart # Otorisasi final pencairan pinjaman
│   │   ├── shu_distribution_screen.dart     # Manajemen distribusi SHU 12 bulan
│   │   ├── shu_parameter_screen.dart        # Konfigurasi persentase alokasi SHU
│   │   ├── executive_report_screen.dart     # Laporan komparasi finansial & laba rugi
│   │   ├── member_list_screen.dart          # Monitoring seluruh portofolio anggota
│   │   ├── period_management_screen.dart    # Buka/Tutup periode akuntansi
│   │   ├── announcement_screen.dart         # Manajemen pengumuman koperasi
│   │   ├── system_settings_screen.dart      # Konfigurasi parameter bunga & denda
│   │   └── widgets/                         # Widget modal & komponen layar ketua
│   │       ├── adjust_balance_dialog.dart   # Modal catat beban & pemasukan saldo
│   │       ├── dividend_distribution_dialog.dart # Modal eksekusi bagi hasil SHU
│   │       ├── member_dividend_statement_dialog.dart # Modal statement dividen anggota
│   │       ├── ketua_header.dart
│   │       ├── ketua_stat_cards.dart
│   │       ├── ketua_approval_table.dart
│   │       ├── member_components.dart
│   │       ├── period_components.dart
│   │       └── setting_components.dart
│   │
│   ├── reports/                             # Modul Laporan Akuntansi Presisi
│   │   └── tabelaris_report_screen.dart     # Layar Jurnal Tabelaris 29 Kolom
│   │
│   ├── finance/
│   │   └── admin_tabelaris_screen.dart      # Wrapper kompatibilitas Tabelaris
│   │
│   └── loan/
│       └── loan_application_sheet.dart      # Modal bottom sheet pengajuan pinjaman
│
├── services/                                # Service Layer & Komunikasi API HTTP
│   ├── auth_service.dart                    # Autentikasi, token bearer & role checking
│   ├── api_service.dart                     # Endpoint data anggota, simpanan & transaksi
│   ├── activity_log_service.dart            # Pengambilan audit trail logs
│   ├── backup_service.dart                  # Download & upload backup zip/sql
│   ├── connectivity_service.dart            # Monitor status jaringan online/offline
│   ├── member_cache_service.dart            # Cache lokal data rekening anggota
│   └── member_statement_pdf_service.dart    # Generator PDF rekening & dividen
│
├── utils/                                   # Helper fungsi dan formatter
│   ├── currency_input_formatter.dart        # Format input ribuan otomatis (100.000)
│   ├── financial_calculator_helper.dart     # Kalkulator anuitas, flat, & declining loan
│   ├── navigation_utils.dart                # Utilitas routing navigasi layar
│   └── whatsapp_helper.dart                 # Integrasi kirim notifikasi ke WhatsApp
│
└── widgets/                                 # Komponen UI global reusable
    ├── admin_dashboard_chart_widget.dart    # Widget grafik arus kas fl_chart
    ├── admin_dashboard_widgets.dart         # Card widget indikator dashboard
    ├── admin_drawer.dart                    # Navigasi sidebar drawer multi-menu
    ├── admin_financial_chart_widget.dart    # Grafik performa neraca & laba rugi
    ├── common_state_widgets.dart            # Widget empty state, loading & error state
    ├── curved_text.dart                     # Teks kurva untuk stempel kwitansi
    ├── member_card.dart                     # Kartu digital anggota koperasi
    ├── network_awareness_wrapper.dart       # Banner indikator status koneksi internet
    ├── receipt_preview_dialog.dart          # Dialog preview nota kasir
    ├── receipt_voucher_dialog.dart          # Dialog cetak voucher transaksi
    └── reports/
        └── tabelaris_table_view.dart        # Komponen tabel 29 kolom tabelaris
```

---

## 🔄 Alur Bisnis Utama (Core Business Workflows)

### 1. Alur Pengajuan, Verifikasi, hingga Pencairan Pinjaman

```
[ Anggota ]
    │
    ▼ Mengajukan Pinjaman (Plafon, Tenor 3-24 Bln, Agunan)
[ Status: pending_admin / WAITING_ADMIN_VERIFICATION ]
    │
    ▼ Admin Memeriksa Kelayakan & Berkas
[ Status: WAITING_MANAGER_APPROVAL ]
    │
    ▼ Manajer (Ketua) Menyetujui Pengajuan
[ Status: APPROVED_BY_MANAGER ]
    │
    ▼ Kasir Mencairkan Kas (Disbursement KK)
[ Status: DISBURSED / ACTIVE ]
    │
    ▼ Anggota Membayar Angsuran Bulanan (KM)
[ Status: PAID_OFF (Lunas) ]
```

### 2. Alur Pembukuan Jurnal Tabelaris 29 Kolom
Setiap transaksi kasir otomatis terpetakan ke dalam **29 Kolom Tabelaris Standar Koperasi**:
1. **Identitas / Meta (4 Kolom)**: `Tgl`, `No Bukti`, `NBA`, `Nama Anggota`.
2. **Pengeluaran (9 Kolom)**: `Piutang`, `Tarik SW`, `Tarik SS`, `Tarik SP`, `Tarik SH`, `Tarik SD`, `Inventaris`, `Bk Keluar`, `Biaya`.
3. **Kas (2 Kolom)**: `Kas Debet (KM)` dan `Kas Kredit (KK)`.
4. **Pemasukan (14 Kolom)**: `Dana`, `Up. Pangkal`, `Simpan SP`, `Simpan SW`, `Simpan SS`, `Simpan SH`, `Simpan SD`, `Ang Pokok`, `Jasa Pinj`, `Denda`, `Provisi`, `Asuransi`, `Lain2`, `BRI Masuk`.

* **Sistem Pengecekan Keseimbangan (Balance Checker)**:
  $$\text{Total Sisi Debet} = \text{Kas Debet} + \sum \text{Kolom Pengeluaran}$$
  $$\text{Total Sisi Kredit} = \text{Kas Kredit} + \sum \text{Kolom Pemasukan}$$
  * Jika $\text{Total Debet} == \text{Total Kredit}$ $\rightarrow$ **Badge Hijau: Jurnal Seimbang (Balance)**.
  * Jika terdapat selisih $\rightarrow$ **Badge Merah: Peringatan Jurnal Tidak Seimbang**.

### 3. Alur Distribusi SHU & Deviden Tahunan (Siklus Juni – Mei)
1. Manajer menginput Laba Bersih Koperasi pada bulan bersangkutan.
2. Sistem mengalokasikan **25% porsi SHU Anggota** dari total laba.
3. Menghitung rasio saham tiap anggota:
   $$\text{Deviden Anggota} = \left( \frac{\text{Total Saham Anggota (SP + SW + SS)}}{\text{Total Saham Koperasi}} \right) \times \text{Porsi SHU 25\%}$$
4. Eksekusi distribusi langsung mengkreditkan dividen ke rekening simpanan anggota dan mencatat histori transaksi.

---

## 📊 Spesifikasi Fitur Finansial Khusus

* **Proteksi Saldo Mengendap**: Penarikan Buku Putih (Tabungan Harian) mewajibkan saldo tersisa minimal **Rp 20.000**.
* **Filter Dropdown Transaksi Kasir**: Kasir hanya dapat memilih anggota dengan status `ACTIVE` untuk input transaksi harian.
* **Auto-format & Sanitasi Input Uang**: Menggunakan `CurrencyInputFormatter` untuk mengubah nominal raw `5000000` menjadi format tampilan `5.000.000`.
* **Export PDF Landscape (Ukuran A3 / Folio)**: Menggunakan parameter `orientation=landscape&paper_size=a3` agar 29 kolom tabelaris dan 10 kolom neraca lajur tercetak rapi tanpa terpotong.

---

## 🌐 Integrasi API Backend

Konfigurasi base URL endpoint diatur pada [`lib/core/constants/api_endpoints.dart`](file:///d:/koperasi_app/lib/core/constants/api_endpoints.dart):

| Kategori | Method | Endpoint | Deskripsi |
| :--- | :---: | :--- | :--- |
| **Auth** | `POST` | `/api/login` | Login user & return Sanctum token |
| | `POST` | `/api/logout` | Revoke token sesi |
| | `GET` | `/api/user/profile` | Ambil profil pengguna login |
| **Dashboard** | `GET` | `/api/dashboard` | Statistik ringkas & status pinjaman aktif |
| **Anggota** | `GET` | `/api/members` | Ambil daftar master anggota |
| | `POST` | `/api/members` | Pendaftaran anggota baru |
| | `GET` | `/api/members/{id}` | Detail anggota & portofolio rekening |
| **Kasir** | `POST` | `/api/transactions` | Simpan transaksi Kas Masuk (KM) / Kas Keluar (KK) |
| | `GET` | `/api/loans/transactions-history` | Riwayat pencairan dan pembayaran angsuran |
| **Pinjaman** | `POST` | `/api/loans/apply` | Pengajuan pinjaman baru oleh anggota |
| | `GET` | `/api/loans/approvals` | Antrean persetujuan pinjaman |
| | `POST` | `/api/loans/{id}/approve` | Persetujuan manajer |
| | `POST` | `/api/loans/{id}/disburse` | Pencairan kas pinjaman oleh kasir |
| **SHU & Deviden** | `GET` | `/api/shu/monthly-status?year={y}` | Status pembagian SHU 12 bulan |
| | `POST` | `/api/shu/distribute` | Eksekusi pembagian dividen anggota |
| **Laporan** | `GET` | `/api/v1/tabelaris` | Data 29 kolom jurnal tabelaris |
| | `GET` | `/api/v1/tabelaris/export-excel` | Unduh file Excel tabelaris |
| | `GET` | `/api/v1/tabelaris/export-pdf` | Unduh dokumen PDF Landscape A3 |
| | `GET` | `/api/reports/trial-balance` | Data neraca lajur 10 kolom |
| **Sistem** | `GET` | `/api/audit-logs` | Mengambil catatan log aktivitas operator |
| | `GET` | `/api/system/backups` | Daftar file backup database |

---

## 🚀 Panduan Instalasi & Menjalankan Aplikasi

### 1. Prasyarat Sistem
* **Flutter SDK**: Versi `>= 3.12.0`
* **Dart SDK**: Versi `>= 3.0.0`
* **Google Chrome / Edge** (untuk menjalankan Web Dashboard)
* **Android Studio / VS Code** lengkap dengan ekstensi Flutter & Dart

### 2. Langkah Instalasi

1. **Clone repositori & buka direktori project**:
   ```bash
   cd d:/koperasi_app
   ```

2. **Unduh seluruh package dependensi**:
   ```bash
   flutter pub get
   ```

3. **Sesuaikan IP Server Backend**:
   Buka file [`lib/core/constants/api_endpoints.dart`](file:///d:/koperasi_app/lib/core/constants/api_endpoints.dart) atau [`lib/services/auth_service.dart`](file:///d:/koperasi_app/lib/services/auth_service.dart) dan sesuaikan `staticBaseUrl`:
   * **Web / Desktop Local**: `http://localhost:8000/api`
   * **Android Emulator**: `http://10.0.2.2:8000/api`
   * **Production Server**: `https://koperasi.domain-anda.com/api`

4. **Jalankan Aplikasi**:
   * **Menjalankan pada Web Browser (Dashboard Admin / Manajer)**:
     ```bash
     flutter run -d chrome
     ```
   * **Menjalankan pada Android Emulator / Device**:
     ```bash
     flutter run -d android
     ```

5. **Build Rilis Produksi**:
   * **Build Web**:
     ```bash
     flutter build web --release
     ```
   * **Build APK Android**:
     ```bash
     flutter build apk --release
     ```

---

## 📄 Lisensi & Hak Cipta
Hak Cipta © 2026 **Koperasi CUM Pelita**. Seluruh hak cipta dilindungi undang-undang. Dikembangkan untuk transparansi dan kemajuan ekonomi anggota koperasi.
