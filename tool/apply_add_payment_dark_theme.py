from pathlib import Path

path = Path('lib/screens/add_payment_screen.dart')
text = path.read_text(encoding='utf-8')
original = text

replacements = [
    (
        "import '../data/employee_repository.dart';\n",
        "import '../app/app_adaptive_palette.dart';\n"
        "import '../data/employee_repository.dart';\n",
    ),
    (
        'style: const TextStyle(color: Colors.red),',
        'style: TextStyle(color: AppAdaptivePalette.danger),',
    ),
    ('color: Colors.grey.shade100,', 'color: AppAdaptivePalette.surfaceSoft,'),
    (
        'border: Border.all(color: Colors.grey.shade200),',
        'border: Border.all(color: AppAdaptivePalette.border),',
    ),
    (
        'color: Colors.grey.shade700,',
        'color: AppAdaptivePalette.textMuted,',
    ),
    ('color: Colors.white,', 'color: AppAdaptivePalette.surfaceElevated,'),
    (
        'border: Border.all(color: Colors.grey.shade300),',
        'border: Border.all(color: AppAdaptivePalette.border),',
    ),
    (
        'color: Colors.grey.shade100,\n              borderRadius: BorderRadius.circular(22),',
        'color: AppAdaptivePalette.surfaceSoft,\n              borderRadius: BorderRadius.circular(22),\n              border: Border.all(color: AppAdaptivePalette.border),',
    ),
    (
        "Text(errorText!, style: const TextStyle(color: Colors.red)),",
        "Container(\n              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),\n              decoration: BoxDecoration(\n                color: AppAdaptivePalette.danger.withValues(alpha: 0.12),\n                borderRadius: BorderRadius.circular(15),\n                border: Border.all(\n                  color: AppAdaptivePalette.danger.withValues(alpha: 0.32),\n                ),\n              ),\n              child: Text(\n                errorText!,\n                style: TextStyle(\n                  color: AppAdaptivePalette.danger,\n                  fontWeight: FontWeight.w700,\n                ),\n              ),\n            ),",
    ),
    (
        "appBar: AppBar(\n        leading: const BackButton(),title: const Text('Добавить выплату')),",
        "appBar: AppBar(\n        leading: const BackButton(),\n        title: const Text('Добавить выплату'),\n      ),",
    ),
]

for old, new in replacements:
    if old not in text:
        raise RuntimeError(f'Expected fragment not found: {old!r}')
    text = text.replace(old, new)

if text == original:
    raise RuntimeError('No changes made')

path.write_text(text, encoding='utf-8')
