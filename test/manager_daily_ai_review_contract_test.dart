import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('центр отчётов открывает ИИ-разбор рабочего дня', () {
    final screen = File(
      'lib/features/reports/presentation/manager_reports_screen.dart',
    ).readAsStringSync();
    final review = File(
      'lib/features/reports/presentation/manager_daily_ai_review.dart',
    ).readAsStringSync();

    expect(screen, contains("import 'manager_daily_ai_review.dart';"));
    expect(screen, contains("title: 'ИИ-разбор рабочего дня'"));
    expect(
      screen,
      contains('void openDailyReview(ManagerReportsCenter center)'),
    );
    expect(screen, contains('ManagerDailyAiReviewScreen('));
    expect(screen, isNot(contains('ManagerDailyAiReviewCard(')));
    expect(review, contains("'ИИ-разбор рабочего дня'"));
    expect(review, contains("'Что выполнено'"));
    expect(review, contains("'Какие проблемы возникли'"));
    expect(review, contains("'Расходы и выплаты'"));
    expect(review, contains("'Отсутствовали сотрудники'"));
    expect(review, contains("'Документы на завтра'"));
    expect(review, contains("'Три приоритетные задачи на завтра'"));
  });

  test('разбор не меняет рабочие данные автоматически', () {
    final review = File(
      'lib/features/reports/presentation/manager_daily_ai_review.dart',
    ).readAsStringSync();

    expect(review, contains('Он ничего не изменяет автоматически.'));
    expect(review, contains('return result.take(3).toList();'));
    expect(review, isNot(contains(".insert('")));
    expect(review, isNot(contains(".update('")));
    expect(review, isNot(contains(".delete('")));
  });
}
