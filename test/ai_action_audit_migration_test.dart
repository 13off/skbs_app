import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit table stores immutable proposal and finite statuses', () {
    final sql = File(
      'supabase/migrations/20260720205000_ai_action_confirmation_audit.sql',
    ).readAsStringSync();

    expect(sql, contains('create table if not exists public.ai_action_audit'));
    expect(sql, contains('proposal jsonb not null'));
    expect(
      sql,
      contains(
        "check (status in ('proposed', 'confirmed', 'cancelled', 'completed', 'failed'))",
      ),
    );
    expect(sql, contains('unique (company_id, user_id, action_id)'));
    expect(sql, contains('ai_action_audit_company_created_idx'));
    expect(sql, contains('ai_action_audit_user_created_idx'));
    expect(sql, contains('ai_action_audit_company_status_idx'));
  });

  test('RLS exposes own audit and admin read without direct mutation', () {
    final sql = File(
      'supabase/migrations/20260720205000_ai_action_confirmation_audit.sql',
    ).readAsStringSync();

    expect(sql, contains('alter table public.ai_action_audit enable row level security'));
    expect(sql, contains('create policy ai_action_audit_select'));
    expect(sql, contains('user_id = (select auth.uid())'));
    expect(sql, contains('public.is_company_admin(company_id)'));
    expect(sql, contains('create policy ai_action_audit_insert'));
    expect(sql, contains('public.current_user_company_id()'));
    expect(sql, contains('public.is_company_member(company_id)'));
    expect(sql, contains('revoke insert, update, delete'));
    expect(
      sql,
      contains(
        'grant insert (company_id, action_id, action_type, object_name, proposal)',
      ),
    );
    expect(sql, isNot(contains('create policy ai_action_audit_update')));
    expect(sql, isNot(contains('grant delete')));
  });

  test('only protected RPC performs validated state transitions', () {
    final sql = File(
      'supabase/migrations/20260720205000_ai_action_confirmation_audit.sql',
    ).readAsStringSync();

    expect(sql, contains('create or replace function public.transition_ai_action_audit'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public, pg_temp'));
    expect(sql, contains("v_row.status = 'proposed'"));
    expect(sql, contains("v_row.status = 'confirmed'"));
    expect(sql, contains("p_status in ('confirmed', 'cancelled', 'failed')"));
    expect(sql, contains("p_status in ('completed', 'cancelled', 'failed')"));
    expect(sql, contains('and user_id = auth.uid()'));
    expect(sql, contains('for update'));
    expect(sql, contains('revoke all on function'));
    expect(sql, contains('grant execute on function'));
  });
}
