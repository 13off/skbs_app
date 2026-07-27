import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('README описывает рабочий проект и обязательные проверки', () {
    final readme = File('README.md').readAsStringSync();

    expect(readme, contains('# AppСтрой'));
    expect(readme, contains('Supabase'));
    expect(readme, contains('flutter test'));
    expect(readme, contains('docs/personal-data.md'));
    expect(readme, isNot(contains('A new Flutter project')));
  });

  test('ключевые эксплуатационные документы присутствуют', () {
    const paths = <String>[
      'docs/architecture.md',
      'docs/roles-and-permissions.md',
      'docs/deployment.md',
      'docs/edge-functions.md',
      'docs/personal-data.md',
      'docs/release-checklist.md',
    ];

    for (final path in paths) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      expect(file.readAsStringSync().trim().length, greaterThan(300), reason: path);
    }
  });

  test('Intel macOS workflow использует закреплённый Flutter и строгие проверки', () {
    final workflow = File(
      '.github/workflows/build-macos-11-intel.yml',
    ).readAsStringSync();

    expect(workflow, contains('flutter-version-file: .fvmrc'));
    expect(workflow, contains('architecture: x64'));
    expect(workflow, contains('flutter pub get --enforce-lockfile'));
    expect(workflow, contains('flutter analyze --no-fatal-infos --no-fatal-warnings'));
    expect(workflow, contains('flutter test --reporter compact'));
    expect(workflow, isNot(contains('continue-on-error: true')));
    expect(workflow, isNot(contains("flutter-version: '3.44.2'")));
  });

  test('миграция удаляет только доказанный дубль индекса', () {
    final migration = File(
      'supabase/migrations/20260721112337_remove_duplicate_objects_name_index.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('drop index if exists public.objects_company_name_unique'),
    );
    expect(migration, contains('objects_company_normalized_name_key'));
    expect(migration.toLowerCase(), isNot(contains('drop table')));
    expect(migration.toLowerCase(), isNot(contains('delete from')));
  });
}
