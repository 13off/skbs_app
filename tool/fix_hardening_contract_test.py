from pathlib import Path

path = Path('test/role_notifications_task_photos_contract_test.dart')
text = path.read_text(encoding='utf-8')
old = """        'tasks_validate_photo_requirements',
        'appstroy.suppress_draft_task_id',
        \"alter column source_role drop default\",
      ],
    );
    expectContains('lib/data/task_repository.dart', const [
"""
new = """        'tasks_validate_photo_requirements',
      ],
    );
    expectContains(
      'supabase/migrations/20260718121000_harden_role_notifications_task_drafts.sql',
      const [
        'appstroy.suppress_draft_task_id',
        'alter column source_role drop default',
        'create or replace function public.app_notify_change()',
      ],
    );
    expectContains('lib/data/task_repository.dart', const [
"""
if old not in text:
    raise SystemExit('generated hardening contract block not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
