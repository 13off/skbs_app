from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path_value: str, replacements: list[tuple[str, str]]) -> None:
    path = ROOT / path_value
    text = path.read_text(encoding='utf-8')
    original = text
    for old, new in replacements:
        text = text.replace(old, new)
    if text == original:
        raise RuntimeError(f'No replacements applied to {path_value}')
    path.write_text(text, encoding='utf-8')


replace(
    'lib/features/archive/presentation/archive_management_screen_v3.dart',
    [
        ('title: const Text(', 'title: Text('),
        ('return const PremiumWorkCard(', 'return PremiumWorkCard('),
    ],
)

replace(
    'lib/features/company/presentation/company_plans_screen.dart',
    [
        ('const Text(', 'Text('),
        (
            'valueColor: const AlwaysStoppedAnimation<Color>(_billingAccent)',
            'valueColor: AlwaysStoppedAnimation<Color>(_billingAccent)',
        ),
    ],
)

replace(
    'lib/screens/pwa_install_screen.dart',
    [('child: const Icon(', 'child: Icon(')],
)

replace(
    'lib/widgets/notification_bell.dart',
    [('const Center(\n                  child: Icon(', 'Center(\n                  child: Icon(')],
)
