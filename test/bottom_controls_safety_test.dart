import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/app/app_ui_tokens.dart';

void main() {
  testWidgets('native iPhone safe area stays inside navigation geometry', (
    tester,
  ) async {
    late double navigationHeight;
    late double actionBottom;
    late double listBottom;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              navigationHeight = AppUi.navigationTotalHeight(context);
              actionBottom = AppUi.floatingActionBottom(context);
              listBottom = AppUi.floatingActionListBottomPadding(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // Native deliberately keeps the PWA bottom spacing out of this geometry.
    expect(
      navigationHeight,
      AppUi.mobileNavigationPanelHeight +
          AppUi.mobileNavigationTopSpacing +
          34,
    );
    expect(actionBottom, AppUi.floatingActionGap);
    expect(listBottom, 64 + 22);
  });

  test('PWA floating actions do not double count bottom navigation', () {
    final tokens = File('lib/app/app_ui_tokens.dart').readAsStringSync();
    final floatingStart = tokens.indexOf('static double floatingActionBottom');
    final listStart = tokens.indexOf(
      'static double floatingActionListBottomPadding',
    );

    expect(floatingStart, greaterThanOrEqualTo(0));
    expect(listStart, greaterThan(floatingStart));

    final floatingBlock = tokens.substring(floatingStart, listStart);
    final listBlock = tokens.substring(listStart);

    expect(floatingBlock, isNot(contains('kIsWeb')));
    expect(floatingBlock, isNot(contains('navigationTotalHeight(context) + gap')));
    expect(floatingBlock, contains('return gap;'));

    expect(listBlock, isNot(contains('if (!kIsWeb)')));
    expect(
      listBlock,
      isNot(contains('navigationTotalHeight(context) + actionHeight + gap')),
    );
    expect(listBlock, contains('return actionHeight + gap;'));
  });

  test('navigation and timesheet consume one geometry source', () {
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();
    final timesheet = File(
      'lib/screens/timesheet/timesheet_view.dart',
    ).readAsStringSync();
    final tasks = File('lib/screens/mobile_tasks_screen.dart').readAsStringSync();

    expect(
      navigation,
      contains('height: AppUi.navigationTotalHeight(context)'),
    );
    expect(navigation, contains('AppUi.navigationPanelHeight(context)'));
    expect(navigation, isNot(contains('isDesktop ? 78.0 : 76.0')));
    expect(timesheet, contains('AppUi.floatingActionBottom(context)'));
    expect(
      timesheet,
      contains('AppUi.floatingActionListBottomPadding(context)'),
    );
    expect(tasks, contains('AppUi.floatingActionBottom(context)'));
    expect(tasks, contains("ValueKey('tasks-floating-add')"));
  });

  test(
    'other page-level bottom actions already own a safe layout boundary',
    () {
      final archiveV3 = File(
        'lib/features/archive/presentation/archive_management_screen_v3.dart',
      ).readAsStringSync();
      final milestones = File(
        'lib/features/milestones/presentation/milestones_screen.dart',
      ).readAsStringSync();
      final persistentShell = File(
        'lib/features/shell/presentation/persistent_tab_shell.dart',
      ).readAsStringSync();

      expect(archiveV3, contains('bottomNavigationBar:'));
      expect(archiveV3, contains('SafeArea('));

      // The milestones FAB belongs to its own pushed Scaffold, not to the
      // root tab shell, and its list reserves space for the control. The
      // horizontal inset remains adaptive through the shared desktop token.
      expect(milestones, contains('leading: const BackButton()'));
      expect(milestones, contains('floatingActionButton:'));
      expect(milestones, contains('final horizontalPadding ='));
      expect(milestones, contains('AppUi.pageDesktopHorizontalPadding'));
      expect(milestones, contains(': 18.0'));
      expect(milestones, contains('horizontalPadding,'));
      expect(milestones, contains('120,'));

      // The root specialist shell gives compact bottom navigation its own
      // Scaffold slot and swaps it for a permanent side rail on wide desktop.
      expect(persistentShell, contains('bottomNavigationBar: useDesktopShell'));
      expect(persistentShell, contains('ProfessionalBottomNavigation('));
      expect(persistentShell, contains('_DesktopTabRail('));
      expect(persistentShell, isNot(contains('extendBody: true')));
      expect(
        persistentShell,
        isNot(contains('persistent-tab-content-clearance')),
      );
      expect(persistentShell, contains('backgroundColor: Colors.transparent'));
    },
  );
}
