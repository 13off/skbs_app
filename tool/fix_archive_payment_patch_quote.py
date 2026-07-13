from pathlib import Path

path = Path(__file__).resolve().parents[1] / 'tool/apply_archive_payment_page_fix.py'
text = path.read_text(encoding='utf-8')
old = "key: ValueKey('payment-employee-${selectedObjectName ?? 'none'}'),"
new = 'key: ValueKey("payment-employee-${selectedObjectName ?? \'none\'}"),'
if old not in text:
    raise RuntimeError('Не найдена строка для исправления кавычек')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
