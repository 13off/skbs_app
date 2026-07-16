from pathlib import Path

path = Path('lib/screens/task_details_screen.dart')
text = path.read_text(encoding='utf-8')

old_enabled = 'enabled: !isSaving,'
if text.count(old_enabled) != 2:
    raise SystemExit(f'Expected 2 remaining editable fields, found {text.count(old_enabled)}')
text = text.replace(old_enabled, 'enabled: !isSaving && canEdit,')

old_date = """    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
"""
new_date = """    final cleanToday = TaskEditPolicy.operationalToday;
"""
if old_date not in text:
    raise SystemExit('Expected local date validation fragment not found')
text = text.replace(old_date, new_date, 1)

path.write_text(text, encoding='utf-8')
print('Follow-up task edit patch applied')
