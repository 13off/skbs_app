import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../estimator/presentation/estimator_closing_operations_index_screen.dart';
import '../../estimator/presentation/estimator_closing_screens.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'accounting_documents_screen.dart';
import 'accounting_control_screen.dart';
import 'adaptive_accounting_dashboard_screen.dart';

class AccountingMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const AccountingMainScreen({super.key, required this.profile});

  @override
  State<AccountingMainScreen> createState() => _AccountingMainScreenState();
}

class _AccountingMainScreenState extends State<AccountingMainScreen> {
  static const int pageCount = 8;
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
        onOpenPeople: () => select(1),
        onOpenExpenses: () => select(2),
        onOpenDocuments: () => select(3),
        onOpenControl: () => select(4),
      ),
      1 => AdaptiveEmployeesScreen(
        profile: widget.profile,
        selectedObjectName: null,
      ),
      2 => const ExpensesScreen(),
      3 => const AccountingDocumentsScreen(),
      4 => const AccountingControlScreen(),
      5 => EstimatorClosingInboxScreen(profile: widget.profile),
      6 => EstimatorClosingOperationsIndexScreen(profile: widget.profile),
      7 => ProfileScreen(profile: widget.profile),
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
          label: 'Люди',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Расходы',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
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
          label: 'Закрытия',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Выработка',
          icon: Icons.payments_outlined,
          selectedIcon: Icons.payments_rounded,
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
