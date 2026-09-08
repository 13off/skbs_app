import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'estimator_closing_operations_index_screen.dart';
import 'estimator_closing_screens.dart';
import 'estimator_manual_volumes_screen.dart';
import 'estimator_volumes_screen.dart';
import 'estimator_work_screen.dart';

class EstimatorMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EstimatorMainScreen({super.key, required this.profile});

  @override
  State<EstimatorMainScreen> createState() => _EstimatorMainScreenState();
}

class _EstimatorMainScreenState extends State<EstimatorMainScreen> {
  late final PersistentTabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = PersistentTabController(pageCount: 6);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Widget page(int index) {
    return switch (index) {
      0 => const EstimatorWorkScreen(),
      1 => const EstimatorVolumesScreen(),
      2 => const EstimatorManualVolumesScreen(),
      3 => const EstimatorClosingsScreen(),
      4 => EstimatorClosingOperationsIndexScreen(profile: widget.profile),
      5 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: tabs,
      navigationStorageKey: 'estimator',
      returnToFirstTabOnBack: true,
      items: const <ProfessionalBottomNavigationItem>[
        ProfessionalBottomNavigationItem(
          label: 'Работы',
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Объёмы',
          icon: Icons.stacked_bar_chart_outlined,
          selectedIcon: Icons.stacked_bar_chart_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Ручные',
          icon: Icons.edit_note_outlined,
          selectedIcon: Icons.edit_note_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Закрытие',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Пакет',
          icon: Icons.folder_copy_outlined,
          selectedIcon: Icons.folder_copy_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Профиль',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ],
      tabBuilder: (_, index) => page(index),
    );
  }
}
