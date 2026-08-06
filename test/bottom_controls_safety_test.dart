import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/app/app_ui_tokens.dart';

void main() {
  testWidgets('iPhone safe area is part of the shared navigation geometry', (
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

    expect(navigationHeight, 128);
    expect(actionBottom, 138);
    expect(listBottom, 214);
  });

  test('navigation and timesheet consume one geometry source', () {
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();
    final timesheet = File(
      'lib/screens/timesheet/timesheet_view.dart',
    ).readAsStringSync();

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
  });

  test(
    'other page-level bottom actions already own a safe layout boundary',
    () {
      final archiveV2 = File(
        'lib/features/archive/presentation/archive_management_screen_v2.dart',
      ).readAsStringSync();
      final archiveV3 = File(
        'lib/features/archive/presentation/archive_management_screen_v3.dart',
      ).readAsStringSync();
      final milestones = File(
        'lib/features/milestones/presentation/milestones_screen.dart',
      ).readAsStringSync();
      final persistentShell = File(
        'lib/features/shell/presentation/persistent_tab_shell.dart',
      ).readAsStringSync();

      expect(archiveV2, contains('bottomNavigationBar:'));
      expect(archiveV2, contains('SafeArea('));
      expect(archiveV3, contains('bottomNavigationBar:'));
      expect(archiveV3, contains('SafeArea('));

      // The milestones FAB belongs to its own pushed Scaffold, not to the
      // root tab shell, and its list reserves space for the control. The
      // horizontal inset is adaptive: 18 on phones and 144 in a wide PWA.
      expect(milestones, contains('leading: const BackButton()'));
      expect(milestones, contains('floatingActionButton:'));
      expect(milestones, contains('final horizontalPadding ='));
      expect(milestones, contains('AppUi.pageDesktopHorizontalPadding'));
      expect(milestones, contains(': 18.0'));
      expect(milestones, contains('horizontalPadding,'));
      expect(milestones, contains('120,'));

      // The root specialist shell gives navigation its own Scaffold slot, so
      // page content physically ends before the translucent glass panel.
      expect(
        persistentShell,
        contains('bottomNavigationBar: ProfessionalBottomNavigation('),
      );
      expect(persistentShell, isNot(contains('extendBody: true')));
      expect(
        persistentShell,
        isNot(contains('persistent-tab-content-clearance')),
      );
      expect(
        persistentShell,
        contains('backgroundColor: Theme.of(context).scaffoldBackgroundColor'),
      );
    },
  );
}
