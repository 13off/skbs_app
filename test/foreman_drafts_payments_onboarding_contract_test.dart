import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foreman task drafts use the existing hidden task mechanism', () {
    final repository = File('lib/data/task_repository.dart').readAsStringSync();
    final createView = File(
      'lib/screens/task_create/task_create_view.dart',
    ).readAsStringSync();
    final mobile = File(
      'lib/screens/mobile_tasks_screen.dart',
    ).readAsStringSync();

    expect(repository, contains('fetchOwnDraftTasks'));
    expect(repository, contains('saveTaskDraftWithDetails'));
    expect(repository, contains(".eq('is_draft', true)"));
    expect(createView, contains('Сохранить черновик'));
    expect(mobile, contains('Черновики ('));
  });

  test('payments support employment status and arbitrary interval', () {
    final screen = File(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/payment_repository.dart',
    ).readAsStringSync();

    expect(screen, contains('Выбрать промежуток'));
    expect(screen, contains('Уволенные'));
    expect(screen, contains('fetchPeriodTimesheet'));
    expect(screen, contains('fetchPaymentTotalsForEmployees'));
    expect(screen, contains('byPaymentDate: mode == _PaymentAccountingMode.paymentDate'));
    expect(repository, contains("'p_start_date': dateKey(startDate)"));
    expect(repository, contains("'p_end_date': dateKey(endDate)"));
  });

  test('onboarding implementation is preserved but temporarily disconnected', () {
    final guide = File(
      'lib/features/onboarding/presentation/first_run_guide.dart',
    ).readAsStringSync();
    final gate = File(
      'lib/features/whats_new/presentation/whats_new_gate.dart',
    ).readAsStringSync();

    expect(guide, contains('OverlayEntry('));
    expect(guide, contains('_SpotlightPainter'));
    expect(guide, contains('AnimationController('));
    expect(guide, contains('Icons.keyboard_arrow_down_rounded'));
    expect(guide, contains('WidgetsBinding.instance.rootElement'));
    expect(guide, contains("GlobalKey(debugLabel: 'first-run-guide-overlay')"));
    expect(
      guide,
      matches(
        RegExp(
          r'coordinateBox\s*\.\s*globalToLocal\s*\(\s*globalTopLeft\s*,?\s*\)',
        ),
      ),
    );
    expect(
      guide,
      matches(
        RegExp(
          r'coordinateBox\s*\.\s*globalToLocal\s*\(\s*globalBottomRight\s*,?\s*\)',
        ),
      ),
    );
    expect(
      guide,
      matches(
        RegExp(
          r"ValueKey<String>\s*\(\s*'professional-bottom-navigation-panel'\s*,?\s*\)",
        ),
      ),
    );
    expect(guide, contains('widget is NavigationBar'));
    expect(guide, contains('tabIndex: tabIndex'));
    expect(guide, contains('tabCount: tabCount'));
    expect(guide, contains('profile.id'));
    expect(guide, contains('profile.role'));
    expect(guide, contains('profile.isRolePreview'));
    expect(guide, isNot(contains('rootContext')));
    expect(guide, isNot(contains('current is Text')));
    expect(guide, isNot(contains('showDialog<void>')));
    expect(gate, isNot(contains('FirstRunGuide.showIfNeeded')));
    expect(gate, isNot(contains("first_run_guide.dart")));
  });
}
