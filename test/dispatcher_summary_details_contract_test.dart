import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('сводка диспетчера показывает кнопку и конкретные отклонения', () {
    final bell = File('lib/widgets/notification_bell.dart').readAsStringSync();
    final repository = File(
      'lib/features/dispatcher/data/dispatcher_summary_details_repository.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/dispatcher/presentation/dispatcher_summary_details_screen.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260718154500_dispatcher_summary_details.sql',
    ).readAsStringSync();

    expect(bell, contains('DispatcherSummaryDetailsScreen'));
    expect(bell, contains("notification.entityType == 'dispatcher_summary'"));
    expect(bell, contains('Разобрать отклонения'));
    expect(repository, contains('get_dispatcher_summary_details'));
    expect(screen, contains('Входит в итоговое число отклонений'));
    expect(screen, contains('Сейчас открыто'));
    expect(screen, contains('Показать \${group.count}'));
    expect(migration, contains('get_dispatcher_summary_details'));
    expect(migration, contains('Выплаты без чеков'));
    expect(migration, contains('Незакрытые задачи'));
    expect(migration, contains('Расшифровка отклонений'));
  });
}
