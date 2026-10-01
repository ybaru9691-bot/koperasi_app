import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/admin_drawer.dart';
import 'admin_dashboard_screen.dart';
import 'admin_kas_keluar_screen.dart';
import 'admin_keuangan_screen.dart';
import 'admin_profil_screen.dart';
import 'admin_rekapitulasi_screen.dart';
import 'input_transaksi_screen.dart';
import 'kelola_anggota_screen.dart';
import 'loan_approval_screen.dart';
import 'loan_installment_card_screen.dart';
import 'admin_worksheet_screen.dart';
import 'admin_transaksi_screen.dart';
import 'initial_balance_screen.dart';
import '../finance/admin_tabelaris_screen.dart';

/// Main Shell Navigation untuk Admin Koperasi dengan Side Navigation Drawer
class AdminMainScreen extends StatefulWidget {
  final int initialIndex;

  const AdminMainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;
  bool _isSidebarOpen = true;

  // Set index yang sudah diaktifkan (Lazy Load untuk mencegah penembakan API massal saat startup)
  late final Set<int> _activatedIndices;
  final Map<int, Widget> _screenCache = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _activatedIndices = {_currentIndex};
  }

  void _onSelectMenu(int index) {
    setState(() {
      _currentIndex = index;
      _activatedIndices.add(index);
    });
  }

  void _toggleDrawer() {
    if (MediaQuery.of(context).size.width >= 900) {
      setState(() {
        _isSidebarOpen = !_isSidebarOpen;
      });
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

// Build screen berdasarkan index,dengan mekanisme lazy load
  Widget _buildScreen(int index) {
    // Jika tab belum pernah diklik/dibuka, return widget kosong (tidak menembak API / initState)
    if (!_activatedIndices.contains(index)) {
      return const SizedBox.shrink();
    }
    return _screenCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return AdminDashboardScreen(onOpenDrawer: _toggleDrawer);
        case 1:
          return KelolaAnggotaScreen(onOpenDrawer: _toggleDrawer);
        case 2:
          return InputTransaksiScreen(onOpenDrawer: _toggleDrawer);
        case 3:
          return AdminProfilScreen(onOpenDrawer: _toggleDrawer);
        case 4:
          return AdminRekapitulasiScreen(onOpenDrawer: _toggleDrawer);
        case 5:
          return LoanApprovalScreen(onOpenDrawer: _toggleDrawer);
        case 6:
          return AdminKasKeluarScreen(onOpenDrawer: _toggleDrawer);
        case 7:
          return AdminKeuanganScreen(onOpenDrawer: _toggleDrawer);
        case 8:
          return LoanInstallmentCardScreen(onOpenDrawer: _toggleDrawer);
        case 9:
          return AdminWorksheetScreen(onOpenDrawer: _toggleDrawer);
        case 10:
          return AdminTransaksiScreen(onOpenDrawer: _toggleDrawer);
        case 11:
          return AdminTabelarisScreen(onOpenDrawer: _toggleDrawer);
        case 12:
          return InitialBalanceScreen(onOpenDrawer: _toggleDrawer);
        default:
          return const SizedBox.shrink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 13 screens dengan mekanisme Lazy Load
    final List<Widget> adminScreens = List.generate(13, (i) => _buildScreen(i));

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          // Layout Desktop: Collapsible Sidebar + Main Content (AnimatedContainer & Row)
          return Scaffold(
            backgroundColor: AppColors.adminCanvas,
            body: Row(
              children: [
                // 1. Animated Collapsible Sidebar (Width 270px when open, 0px when closed)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.fastOutSlowIn,
                  width: _isSidebarOpen ? 270.0 : 0.0,
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 270.0,
                      maxWidth: 270.0,
                      alignment: Alignment.topLeft,
                      child: AdminDrawerWidget(
                        currentIndex: _currentIndex,
                        onSelectMenu: _onSelectMenu,
                      ),
                    ),
                  ),
                ),
                if (_isSidebarOpen)
                  const VerticalDivider(width: 1, color: AppColors.cardBorder),

                // 2. Main Content area automatically expands to fill full width
                Expanded(
                  child: ClipRect(
                    child: IndexedStack(
                      index: _currentIndex < adminScreens.length ? _currentIndex : 0,
                      children: adminScreens,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Layout Mobile/Tablet: Drawer Navigation via Scaffold + ClipRect Body
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.adminCanvas,
          drawer: AdminDrawerWidget(
            currentIndex: _currentIndex,
            onSelectMenu: _onSelectMenu,
          ),
          body: ClipRect(
            child: IndexedStack(
              index: _currentIndex < adminScreens.length ? _currentIndex : 0,
              children: adminScreens,
            ),
          ),
        );
      },
    );
  }
}
