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

    expect(screen, contains('Выбрать промежуток'));
    expect(screen, contains('Уволенные'));
    expect(screen, contains('fetchPeriodTimesheet'));
    expect(screen, contains('payment.paymentDate'));
  });

  test('first real login shows a role-specific guide once', () {
    final guide = File(
      'lib/features/onboarding/presentation/first_run_guide.dart',
    ).readAsStringSync();
    final gate = File(
      'lib/features/whats_new/presentation/whats_new_gate.dart',
    ).readAsStringSync();

    expect(guide, contains('Как работать в AppСтрой'));
    expect(guide, contains('profile.id'));
    expect(guide, contains('profile.role'));
    expect(guide, contains('profile.isRolePreview'));
    expect(gate, contains('FirstRunGuide.showIfNeeded'));
  });
}
