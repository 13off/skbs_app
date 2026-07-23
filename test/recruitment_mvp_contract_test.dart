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

  test('HR uses the Telegram bot workflow without losing simple stages', () {
    expect(
      recruitmentStatuses,
      containsAll(<String>[
        'draft',
        'new',
        'waiting_documents',
        'review',
        'approved',
        'ticket_request',
        'in_transit',
        'arrived',
        'hired',
        'reserve',
        'rejected',
      ]),
    );
    expect(recruitmentStageKey('waiting_documents'), 'documents');
    expect(recruitmentStageKey('review'), 'problems');
    expect(recruitmentStageKey('approved'), 'ready');
    expect(recruitmentStageKey('ticket_request'), 'tickets');
    expect(recruitmentStageKey('hired'), 'completed');
    expect(recruitmentStageTitle('documents'), 'Ждём документы');
    expect(recruitmentStageTitle('problems'), 'Косяки');
  });

  test('HR reads the same applications that the Telegram bot creates', () {
    final screen = source(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    );
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );

    expect(screen, contains("title: 'Кандидаты'"));
    expect(screen, contains("labelText: 'ФИО'"));
    expect(screen, contains("labelText: 'Вакансия'"));
    expect(screen, contains("labelText: 'Объект'"));
    expect(repository, contains(".from('recruitment_applications')"));
    expect(repository, contains("external_user_id"));
    expect(repository, contains("position_title"));
    expect(repository, contains("experience_text"));
    expect(repository, contains("source = 'manual'"));
  });
}
