import 'package:flutter/material.dart';

import '../../../data/app_cache_coordinator.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'adaptive_procurement_requests_screen.dart';
import 'procurement_dashboard_screen.dart';
import 'procurement_deliveries_screen.dart';
import 'procurement_suppliers_screen.dart';

class ProcurementMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const ProcurementMainScreen({super.key, required this.profile});

  @override
  State<ProcurementMainScreen> createState() => _ProcurementMainScreenState();
}

class _ProcurementMainScreenState extends State<ProcurementMainScreen>
    with WidgetsBindingObserver {
  static const int pageCount = 5;
  late final PersistentTabController tabs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tabs = PersistentTabController(pageCount: pageCount);
    _startSync();
  }

  @override
  void didUpdateWidget(covariant ProcurementMainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      AppDataSync.stop(companyId: oldWidget.profile.activeCompanyId);
      _startSync();
    }
  }

  void _startSync() {
    AppDataSync.start(
      companyId: widget.profile.activeCompanyId,
      invalidateCaches: AppCacheCoordinator.invalidate,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AppDataSync.refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppDataSync.stop(companyId: widget.profile.activeCompanyId);
    tabs.dispose();
    super.dispose();
  }

  Future<void> openRequests() => tabs.select(1);
  Future<void> openDeliveries() => tabs.select(3);

  Widget rootPage(int index) {
    return switch (index) {
      0 => ProcurementDashboardScreen(
        profile: widget.profile,
        onOpenRequests: openRequests,
        onOpenDeliveries: openDeliveries,
      ),
      1 => AdaptiveProcurementRequestsScreen(profile: widget.profile),
      2 => ProcurementSuppliersScreen(profile: widget.profile),
      3 => ProcurementDeliveriesScreen(profile: widget.profile),
      4 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: tabs,
      navigationStorageKey: 'procurement',
      returnToFirstTabOnBack: true,
      items: const <ProfessionalBottomNavigationItem>[
        ProfessionalBottomNavigationItem(
          label: 'Сегодня',
          icon: Icons.space_dashboard_outlined,
          selectedIcon: Icons.space_dashboard_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Заявки',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Поставщики',
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Доставки',
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Профиль',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ],
      tabBuilder: (_, index) => rootPage(index),
    );
  }
}
