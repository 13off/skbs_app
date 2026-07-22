from pathlib import Path


def replace_all(path: str, replacements: list[tuple[str, str]]) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    original = text
    for old, new in replacements:
        if old not in text:
            raise RuntimeError(f'Expected fragment not found in {path}: {old!r}')
        text = text.replace(old, new)
    if text == original:
        raise RuntimeError(f'No changes made in {path}')
    file_path.write_text(text, encoding='utf-8')


replace_all(
    'lib/features/company/presentation/mobile_company_management_screen.dart',
    [
        (
            "import '../../../app/app_theme.dart';\n",
            "import '../../../app/app_adaptive_palette.dart';\n",
        ),
        (
            'color: Colors.white.withValues(alpha: 0.86),',
            'color: AppAdaptivePalette.surfaceElevated,',
        ),
        (
            'border: Border.all(color: Colors.white),',
            'border: Border.all(color: AppAdaptivePalette.border),',
        ),
        (
            'decoration: const BoxDecoration(\n                  color: Color(0xFFF0F1F3),',
            'decoration: BoxDecoration(\n                  color: AppAdaptivePalette.surfaceSoft,',
        ),
        ('color: AppColors.textPrimary,', 'color: AppAdaptivePalette.textPrimary,'),
        ('color: AppColors.textMuted,', 'color: AppAdaptivePalette.textMuted,'),
        (
            'color: Colors.white.withValues(alpha: 0.84),',
            'color: AppAdaptivePalette.surfaceElevated,',
        ),
        (
            'side: const BorderSide(color: Colors.white),',
            'side: BorderSide(color: AppAdaptivePalette.border),',
        ),
        (
            'backgroundColor: const Color(0xFFF0F1F3),',
            'backgroundColor: AppAdaptivePalette.surfaceSoft,',
        ),
        (
            "return const Center(\n                child: PremiumDots(color: AppColors.textPrimary),\n              );",
            "return Center(\n                child: PremiumDots(\n                  color: AppAdaptivePalette.textPrimary,\n                ),\n              );",
        ),
        (
            'color: const Color(0xFFF1F2F3),\n                    borderRadius: BorderRadius.circular(16),',
            'color: AppAdaptivePalette.surfaceSoft,\n                    borderRadius: BorderRadius.circular(16),\n                    border: Border.all(color: AppAdaptivePalette.border),',
        ),
        (
            'style: const TextStyle(\n                      color: AppColors.textMuted,',
            'style: TextStyle(\n                      color: AppAdaptivePalette.textMuted,',
        ),
        (
            'backgroundColor: const Color(0xFF874540),\n              foregroundColor: Colors.white,',
            'backgroundColor: AppAdaptivePalette.danger,\n              foregroundColor: AppAdaptivePalette.onAccent,',
        ),
        (
            'style: const TextStyle(\n                  color: Color(0xFF874540),',
            'style: TextStyle(\n                  color: AppAdaptivePalette.danger,',
        ),
        (
            'foregroundColor: const Color(0xFF874540),\n                  side: const BorderSide(color: Color(0xFFB88A85)),',
            'foregroundColor: AppAdaptivePalette.danger,\n                  side: BorderSide(\n                    color: AppAdaptivePalette.danger.withValues(alpha: 0.55),\n                  ),',
        ),
        (
            'color: const Color(0xFFF3F4F5),\n        borderRadius: BorderRadius.circular(16),',
            'color: AppAdaptivePalette.surfaceSoft,\n        borderRadius: BorderRadius.circular(16),\n        border: Border.all(color: AppAdaptivePalette.border),',
        ),
        (
            'Text(label, style: const TextStyle(color: AppColors.textMuted)),',
            'Text(\n            label,\n            style: TextStyle(color: AppAdaptivePalette.textMuted),\n          ),',
        ),
    ],
)

replace_all(
    'lib/features/company/presentation/desktop_company_user_dialogs.dart',
    [
        (
            'const CircleAvatar(\n                        backgroundColor: Colors.white,\n                        child: Icon(Icons.person_outline),\n                      ),',
            'CircleAvatar(\n                        backgroundColor: specialistSoft,\n                        foregroundColor: specialistText,\n                        child: const Icon(Icons.person_outline),\n                      ),',
        ),
    ],
)
