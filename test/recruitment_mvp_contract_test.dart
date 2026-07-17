import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/auth/models/app_user_profile.dart';
import 'package:skbs_app/features/recruitment/models/recruitment_models.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('HR role has a dedicated title and platform', () {
    const profile = AppUserProfile(
      id: 'hr-id',
      email: 'hr@example.com',
      fullName: 'HR',
      role: 'hr',
      objectName: '',
      activeCompanyId: 'company-id',
      isActive: true,
    );

    expect(profile.isHr, isTrue);
    expect(profile.roleTitle, 'HR-менеджер');
    expect(
      source('lib/screens/main_screen.dart'),
      contains('RecruitmentMainScreen(profile: profile)'),
    );
  });

  test('recruitment pipeline keeps the agreed MVP stages', () {
    expect(
      recruitmentStatuses,
      <String>[
        'new',
        'documents',
        'problems',
        'ready',
        'tickets',
        'completed',
        'rejected',
      ],
    );
    expect(recruitmentStatusTitle('new'), 'Новые');
    expect(recruitmentStatusTitle('documents'), 'Ждём документы');
    expect(recruitmentStatusTitle('problems'), 'Косяки');
    expect(recruitmentStatusTitle('ready'), 'Готовы к вылету');
    expect(recruitmentStatusTitle('tickets'), 'Нужны билеты');
  });

  test('HR screen supports manual intake before Telegram integration', () {
    final screen = source(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    );
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );

    expect(screen, contains("title: 'Заявки'"));
    expect(screen, contains("labelText: 'ФИО'"));
    expect(screen, contains("labelText: 'Вакансия'"));
    expect(screen, contains("labelText: 'Объект'"));
    expect(repository, contains(".from('recruitment_applications')"));
    expect(repository, contains("source = 'manual'"));
  });
}
