import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matter card contains native case workspace sections', () {
    final source = File(
      'lib/features/legal/presentation/legal_matter_details_part.dart',
    ).readAsStringSync();

    for (final text in <String>[
      'Суть дела',
      'Основание',
      'Участники и ответственность',
      'Контроль дела',
      'Связанные документы',
      'История дела',
    ]) {
      expect(source, contains(text));
    }
    expect(source, contains('LegalMatterWorkspaceRepository.fetch'));
    expect(source, contains('LegalRepository.fetchDocuments'));
    expect(source, contains('addNote'));
  });

  test('matter history is tenant scoped, append only and linked to allowed matter', () {
    final sql = File(
      'supabase/migrations/20260815131342_legal_matter_workspace_card.sql',
    ).readAsStringSync();

    expect(sql, contains('add column if not exists basis text'));
    expect(sql, contains('create table if not exists public.legal_matter_events'));
    expect(sql, contains('legal_matter_allowed_for_user(matter_id)'));
    expect(sql, contains("current_user_has_permission('legal.matters.edit')"));
    expect(sql, contains('grant select, insert on table public.legal_matter_events'));
    expect(sql, isNot(contains('grant update on table public.legal_matter_events')));
    expect(sql, isNot(contains('grant delete on table public.legal_matter_events')));
    expect(sql, contains('CREATE TRIGGER legal_matters_history_trigger'));
    expect(
      sql,
      contains(
        'revoke all on function public.log_legal_matter_change() from public, anon, authenticated',
      ),
    );
  });
}
