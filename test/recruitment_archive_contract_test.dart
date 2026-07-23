import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/recruitment/models/recruitment_models.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('recruitment application reads archived state from the database', () {
    final active = RecruitmentApplication.fromMap(<String, dynamic>{
      'id': 'active-id',
      'company_id': 'company-id',
      'full_name': 'Активный кандидат',
      'created_at': '2026-07-17T12:00:00Z',
    });
    final archived = RecruitmentApplication.fromMap(<String, dynamic>{
      'id': 'archived-id',
      'company_id': 'company-id',
      'full_name': 'Архивный кандидат',
      'archived_at': '2026-07-17T13:00:00Z',
      'created_at': '2026-07-17T12:00:00Z',
    });

    expect(active.isArchived, isFalse);
    expect(archived.isArchived, isTrue);
    expect(archived.archivedAt, isNotNull);
  });

  test('working list and dashboard exclude archived applications', () {
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );

    expect(repository, contains('bool archived = false'));
    expect(repository, contains('item.isArchived == archived'));
    expect(repository, contains('archiveApplication'));
    expect(repository, contains('restoreApplication'));
    expect(repository, contains('deleteApplication'));
    expect(repository, contains("'archived_at': null"));
  });

  test('applications screen opens archive and can archive a candidate', () {
    final applications = source(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    );
    final archive = source(
      'lib/features/recruitment/presentation/recruitment_archive_screen.dart',
    );

    expect(applications, contains("tooltip: 'Архив кандидатов'"));
    expect(applications, contains("Text('В архив')"));
    expect(applications, contains('archiveApplication(application)'));
    expect(archive, contains("title: 'Архив кандидатов'"));
    expect(archive, contains("label: const Text('Восстановить')"));
    expect(archive, contains("title: const Text('Удалить кандидата навсегда?')"));
    expect(archive, contains("child: const Text('Удалить навсегда')"));
  });

  test('permanent deletion is allowed only for archived applications', () {
    final migration = source(
      'supabase/migrations/20260717162200_require_archive_before_recruitment_delete.sql',
    );

    expect(migration, contains('archived_at is not null'));
    expect(
      migration,
      contains(
        "current_user_has_permission('recruitment.applications.delete')",
      ),
    );
  });
}
