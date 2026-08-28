import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../navigation/app_page_route.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import '../data/recruitment_flight_repository.dart';
import '../data/recruitment_repository.dart';
import 'recruitment_applications_screen.dart';
import 'recruitment_dashboard_screen.dart';
import 'recruitment_flight_calendar_screen.dart';
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
  late final StreamSubscription<RecruitmentApplicationStageMove>
  stageMoveSubscription;
  bool flightPromptBusy = false;

  @override
  void initState() {
    super.initState();
    tabs = PersistentTabController(pageCount: pageCount);
    AppDataSync.start(
      companyId: widget.profile.activeCompanyId,
      invalidateCaches: (_) {},
    );
    stageMoveSubscription = RecruitmentRepository.stageMoves.listen(
      handleStageMove,
    );
  }

  @override
  void dispose() {
    stageMoveSubscription.cancel();
    AppDataSync.stop(companyId: widget.profile.activeCompanyId);
    tabs.dispose();
    super.dispose();
  }

  Future<void> select(int index) => tabs.select(index);

  void handleStageMove(RecruitmentApplicationStageMove move) {
    if (!mounted || flightPromptBusy) return;
    unawaited(openFlightAfterTicketPurchase(move));
  }

  Future<void> openFlightAfterTicketPurchase(
    RecruitmentApplicationStageMove move,
  ) async {
    flightPromptBusy = true;
    try {
      final configuration = await RecruitmentRepository.fetchConfiguration(
        companyId: widget.profile.activeCompanyId,
      );
      final stage = configuration.stageById(move.stageId);
      if (stage == null ||
          !RecruitmentFlightRepository.isTicketPurchasedStage(stage)) {
        return;
      }

      final candidates = await RecruitmentFlightRepository.fetchCandidates(
        companyId: widget.profile.activeCompanyId,
        configuration: configuration,
      );
      final matching = candidates
          .where((candidate) => candidate.applicationId == move.applicationId)
          .toList(growable: false);
      if (matching.isEmpty || !mounted) return;
      final selected = matching.first;

      await Navigator.of(context).push<bool>(
        AppPageRoute<bool>(
          builder: (_) => RecruitmentFlightEditorScreen(
            profile: widget.profile,
            candidates: [selected],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Карточка перенесена в «Куплен билет», но окно вылета не открылось: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      flightPromptBusy = false;
    }
  }

  Widget rootPage(int index) {
    return switch (index) {
      0 => RecruitmentDashboardScreen(
        profile: widget.profile,
        onOpenApplications: () => select(1),
      ),
      1 => RecruitmentApplicationsScreen(profile: widget.profile),
      2 => RecruitmentOnboardingScreen(profile: widget.profile),
      3 => RecruitmentFlightCalendarScreen(profile: widget.profile),
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
          label: 'Кандидаты',
          icon: Icons.view_kanban_outlined,
          selectedIcon: Icons.view_kanban_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Оформление',
          icon: Icons.assignment_ind_outlined,
          selectedIcon: Icons.assignment_ind_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Вылеты',
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
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
