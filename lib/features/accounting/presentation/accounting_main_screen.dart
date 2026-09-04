import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'adaptive_accounting_dashboard_screen.dart';
import 'adaptive_accounting_operations_screen.dart';
import 'accounting_documents_screen.dart';
import 'accounting_control_screen.dart';

class AccountingMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const AccountingMainScreen({super.key, required this.profile});

  @override
  State<AccountingMainScreen> createState() => _AccountingMainScreenState();
}

class _AccountingMainScreenState extends State<AccountingMainScreen> {
  static const int pageCount = 5;
  late final PersistentTabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = PersistentTabController(pageCount: pageCount);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> select(int index) => tabs.select(index);

  Widget rootPage(int index) {
    return switch (index) {
      0 => AdaptiveAccountingDashboardScreen(
        profile: widget.profile,
        onOpenPayments: () => select(1),
        onOpenReports: () => select(3),
      ),
      1 => const AdaptiveAccountingOperationsScreen(),
      2 => const AccountingDocumentsScreen(),
      3 => const AccountingControlScreen(),
      4 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: tabs,
      navigationStorageKey: 'accountant',
      items: const <ProfessionalBottomNavigationItem>[
        ProfessionalBottomNavigationItem(
          label: 'Сегодня',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Операции',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Документы',
          icon: Icons.description_outlined,
          selectedIcon: Icons.description_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Контроль',
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Профиль',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ],
      tabBuilder: (context, index) => rootPage(index),
    );
  }
}
