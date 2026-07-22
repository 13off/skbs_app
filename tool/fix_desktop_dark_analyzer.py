from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch(path_value: str, replacements: list[tuple[str, str]]) -> None:
    path = ROOT / path_value
    text = path.read_text(encoding='utf-8')
    for old, new in replacements:
        if old not in text:
            raise RuntimeError(f'{path}: missing {old!r}')
        text = text.replace(old, new, 1)
    path.write_text(text, encoding='utf-8')


patch(
    'lib/screens/desktop_home_widgets.dart',
    [
        ('Color get _surface => AppAdaptivePalette.surface;\n', ''),
        ("const Text(\n                'Выплаты',", "Text(\n                'Выплаты',"),
        ("const Text(\n                'Не удалось загрузить главную',", "Text(\n                'Не удалось загрузить главную',"),
        ("const Text(\n                'Проверь интернет и повтори загрузку.',", "Text(\n                'Проверь интернет и повтори загрузку.',"),
    ],
)

patch(
    'lib/screens/desktop_employees_view.dart',
    [
        ('  _Badge({\n', '  const _Badge({\n'),
        ('  _MessageCard({\n', '  const _MessageCard({\n'),
    ],
)

patch(
    'lib/screens/desktop_tasks_screen.dart',
    [('  _MessageCard({\n', '  const _MessageCard({\n')],
)
