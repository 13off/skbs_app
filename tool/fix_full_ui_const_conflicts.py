from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path_value: str, old: str, new: str) -> None:
    path = ROOT / path_value
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'Marker is missing: {path_value}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


replace(
    'lib/features/recruitment/presentation/recruitment_archive_screen.dart',
    "const Text(\n                    'Не удалось загрузить архив',",
    "Text(\n                    'Не удалось загрузить архив',",
)

replace(
    'lib/features/recruitment/presentation/recruitment_dashboard_screen.dart',
    'Color color = _text,',
    'Color color = AppAdaptivePalette.telegramBlue,',
)
replace(
    'lib/features/recruitment/presentation/recruitment_dashboard_screen.dart',
    "const Text(\n                    'Не удалось загрузить HR-сводку',",
    "Text(\n                    'Не удалось загрузить HR-сводку',",
)

replace(
    'lib/screens/desktop_timesheet_screen.dart',
    'this.accent = _text,',
    'this.accent = AppAdaptivePalette.telegramBlue,',
)

replace(
    'lib/screens/object_management_screen.dart',
    "const Text(\n            'Объекты',",
    "Text(\n            'Объекты',",
)
replace(
    'lib/screens/object_management_screen.dart',
    "child: const Text(\n                  'Объекты пока не найдены',",
    "child: Text(\n                  'Объекты пока не найдены',",
)
