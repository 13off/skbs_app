from pathlib import Path

path = Path('lib/features/employee/data/employee_shift_runtime.dart')
text = path.read_text(encoding='utf-8')
expected = text.count('const WebSettings(')
if expected != 3:
    raise SystemExit(f'Expected 3 const WebSettings occurrences, got {expected}')
path.write_text(text.replace('const WebSettings(', 'WebSettings('), encoding='utf-8')
Path('tool/fix_websettings_const.py').unlink()
