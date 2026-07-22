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
    (
        'Text(errorText!, style: const TextStyle(color: Colors.red)),',
        'Text(\n              errorText!,\n              style: TextStyle(color: AppAdaptivePalette.danger),\n            ),',
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
        'color: AppAdaptivePalette.surfaceSoft,\n              borderRadius: BorderRadius.circular(22),\n            ),\n            child: Column(',
        'color: AppAdaptivePalette.surfaceSoft,\n              borderRadius: BorderRadius.circular(22),\n              border: Border.all(color: AppAdaptivePalette.border),\n            ),\n            child: Column(',
    ),
    (
        "appBar: AppBar(\n        leading: const BackButton(),title: const Text('Добавить выплату')),",
        "appBar: AppBar(\n        leading: const BackButton(),\n        title: const Text('Добавить выплату'),\n      ),",
    ),
]

for old, new in replacements:
    if old in text:
        text = text.replace(old, new)

if text == original:
    raise RuntimeError('No changes made')

path.write_text(text, encoding='utf-8')
