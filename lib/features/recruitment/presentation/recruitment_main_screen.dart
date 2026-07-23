import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'recruitment_applications_screen.dart';
import 'recruitment_dashboard_screen.dart';
import 'recruitment_mobilization_screen.dart';
import 'recruitment_onboarding_screen.dart';

class RecruitmentMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const RecruitmentMainScreen({super.key, required this.profile});

  @override
  State<RecruitmentMainScreen> createState() => _RecruitmentMainScreenState();
}

class _RecruitmentMainScreenState extends State<RecruitmentMainScreen> {
  static const int pageCount = 5;
  late final PersistentTabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = PersistentTabController(pageCount: pageCount);
    AppDataSync.start(
      companyId: widget.profile.activeCompanyId,
      invalidateCaches: (_) {},
    );
  }

  @override
  void dispose() {
    AppDataSync.stop(companyId: widget.profile.activeCompanyId);
    tabs.dispose();
    super.dispose();
  }

  Future<void> select(int index) => tabs.select(index);

  Widget rootPage(int index) {
    return switch (index) {
      0 => RecruitmentDashboardScreen(
        profile: widget.profile,
        onOpenApplications: () => select(1),
      ),
      1 => RecruitmentApplicationsScreen(profile: widget.profile),
      2 => RecruitmentOnboardingScreen(profile: widget.profile),
      3 => RecruitmentMobilizationScreen(profile: widget.profile),
      4 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: tabs,
      navigationStorageKey: 'hr',
      items: const <ProfessionalBottomNavigationItem>[
        ProfessionalBottomNavigationItem(
          label: 'Сегодня',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Заявки',
          icon: Icons.view_kanban_outlined,
          selectedIcon: Icons.view_kanban_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Оформление',
          icon: Icons.assignment_ind_outlined,
          selectedIcon: Icons.assignment_ind_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Выход',
          icon: Icons.flight_takeoff_outlined,
          selectedIcon: Icons.flight_takeoff_rounded,
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
