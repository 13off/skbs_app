import 'package:flutter/material.dart';

import '../../../features/payments/presentation/screens/payments_screen.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import 'accounting_dashboard_screen.dart';
import 'accounting_reports_screen.dart';

class AccountingMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const AccountingMainScreen({super.key, required this.profile});

  @override
  State<AccountingMainScreen> createState() => _AccountingMainScreenState();
}

class _AccountingMainScreenState extends State<AccountingMainScreen> {
  int currentIndex = 0;
  late final PageController controller;

  @override
  void initState() {
    super.initState();
    controller = PageController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> select(int index) async {
    if (index == currentIndex) return;
    await controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  List<Widget> get pages => <Widget>[
        AccountingDashboardScreen(
          profile: widget.profile,
          onOpenPayments: () => select(1),
          onOpenReports: () => select(2),
        ),
        const PaymentsScreen(),
        const AccountingReportsScreen(),
        ProfileScreen(profile: widget.profile),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: controller,
        allowImplicitScrolling: true,
        onPageChanged: (index) => setState(() => currentIndex = index),
        children: pages,
      ),
      bottomNavigationBar: ProfessionalBottomNavigation(
        items: const <ProfessionalBottomNavigationItem>[
          ProfessionalBottomNavigationItem(
            label: 'Сегодня',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Выплаты',
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Отчёты',
            icon: Icons.summarize_outlined,
            selectedIcon: Icons.summarize_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Профиль',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
          ),
        ],
        selectedIndex: currentIndex,
        onSelected: select,
      ),
    );
  }
}
