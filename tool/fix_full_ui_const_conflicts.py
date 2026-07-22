from pathlib import Path

path = Path(__file__).resolve().parents[1] / (
    'lib/features/payments/presentation/widgets/payment_report_sheet.dart'
)
text = path.read_text(encoding='utf-8')
old = (
    "const Text(\n"
    "                  'Сначала выбери объект или «Все объекты», затем период и сотрудника.',"
)
new = (
    "Text(\n"
    "                  'Сначала выбери объект или «Все объекты», затем период и сотрудника.',"
)
if old not in text:
    raise RuntimeError('Payment report const marker is missing')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
