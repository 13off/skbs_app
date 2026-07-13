from pathlib import Path

path = Path(__file__).resolve().parents[1] / 'tool/apply_archive_payment_page_fix.py'
text = path.read_text(encoding='utf-8')

replacements = {
    "key: ValueKey('payment-employee-${selectedObjectName ?? 'none'}'),":
        'key: ValueKey("payment-employee-${selectedObjectName ?? \'none\'}"),',
    "        anyOf(contains('AppPageHeader('), contains('return AppPage(')),\n        reason:":
        "        anyOf(contains('AppPageHeader('), contains('return AppPage(')),\n        reason:",
}

# Вторая замена отдельно закрывает anyOf перед именованным аргументом expect.
old_contract = "        anyOf(contains('AppPageHeader('), contains('return AppPage(')),\n        reason: '$path должен использовать единую объёмную шапку',"
new_contract = "        anyOf(contains('AppPageHeader('), contains('return AppPage('))),\n        reason: '$path должен использовать единую объёмную шапку',"

quote_old = "key: ValueKey('payment-employee-${selectedObjectName ?? 'none'}'),"
quote_new = 'key: ValueKey("payment-employee-${selectedObjectName ?? \'none\'}"),'

if quote_old not in text:
    raise RuntimeError('Не найдена строка для исправления кавычек')
text = text.replace(quote_old, quote_new, 1)

if old_contract not in text:
    raise RuntimeError('Не найден контрактный тест для закрытия anyOf')
text = text.replace(old_contract, new_contract, 1)

path.write_text(text, encoding='utf-8')
