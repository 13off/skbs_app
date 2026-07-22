from pathlib import Path


def replace_present(path: str, replacements: list[tuple[str, str]]) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    original = text
    for old, new in replacements:
        if old in text:
            text = text.replace(old, new)
    if text == original:
        raise RuntimeError(f'No changes made in {path}')
    file_path.write_text(text, encoding='utf-8')


replace_present(
    'lib/features/company/presentation/mobile_company_management_screen.dart',
    [
        (
            "import '../../../app/app_theme.dart';\n",
            "import '../../../app/app_adaptive_palette.dart';\n",
        ),
        ('AppColors.textPrimary', 'AppAdaptivePalette.textPrimary'),
        ('AppColors.textMuted', 'AppAdaptivePalette.textMuted'),
        (
            'Colors.white.withValues(alpha: 0.86)',
            'AppAdaptivePalette.surfaceElevated',
        ),
        (
            'Colors.white.withValues(alpha: 0.84)',
            'AppAdaptivePalette.surfaceElevated',
        ),
        (
            'Border.all(color: Colors.white)',
            'Border.all(color: AppAdaptivePalette.border)',
        ),
        (
            'const BorderSide(color: Colors.white)',
            'BorderSide(color: AppAdaptivePalette.border)',
        ),
        ('const Color(0xFFF0F1F3)', 'AppAdaptivePalette.surfaceSoft'),
        ('Color(0xFFF0F1F3)', 'AppAdaptivePalette.surfaceSoft'),
        ('const Color(0xFFF1F2F3)', 'AppAdaptivePalette.surfaceSoft'),
        ('Color(0xFFF1F2F3)', 'AppAdaptivePalette.surfaceSoft'),
        ('const Color(0xFFF3F4F5)', 'AppAdaptivePalette.surfaceSoft'),
        ('Color(0xFFF3F4F5)', 'AppAdaptivePalette.surfaceSoft'),
        (
            "return const Center(\n                child: PremiumDots(color: AppAdaptivePalette.textPrimary),\n              );",
            "return Center(\n                child: PremiumDots(\n                  color: AppAdaptivePalette.textPrimary,\n                ),\n              );",
        ),
        (
            'backgroundColor: const Color(0xFF874540),\n              foregroundColor: Colors.white,',
            'backgroundColor: AppAdaptivePalette.danger,\n              foregroundColor: AppAdaptivePalette.onAccent,',
        ),
        ('color: Color(0xFF874540)', 'color: AppAdaptivePalette.danger'),
        (
            'foregroundColor: const Color(0xFF874540)',
            'foregroundColor: AppAdaptivePalette.danger',
        ),
        (
            'side: const BorderSide(color: Color(0xFFB88A85)),',
            'side: BorderSide(\n                    color: AppAdaptivePalette.danger.withValues(alpha: 0.55),\n                  ),',
        ),
        ('const BoxDecoration(', 'BoxDecoration('),
        ('const TextStyle(', 'TextStyle('),
        (
            'color: AppAdaptivePalette.surfaceSoft,\n                    borderRadius: BorderRadius.circular(16),',
            'color: AppAdaptivePalette.surfaceSoft,\n                    borderRadius: BorderRadius.circular(16),\n                    border: Border.all(color: AppAdaptivePalette.border),',
        ),
        (
            'color: AppAdaptivePalette.surfaceSoft,\n        borderRadius: BorderRadius.circular(16),',
            'color: AppAdaptivePalette.surfaceSoft,\n        borderRadius: BorderRadius.circular(16),\n        border: Border.all(color: AppAdaptivePalette.border),',
        ),
    ],
)

replace_present(
    'lib/features/company/presentation/desktop_company_user_dialogs.dart',
    [
        (
            'const CircleAvatar(\n                        backgroundColor: Colors.white,\n                        child: Icon(Icons.person_outline),\n                      ),',
            'CircleAvatar(\n                        backgroundColor: specialistSoft,\n                        foregroundColor: specialistText,\n                        child: const Icon(Icons.person_outline),\n                      ),',
        ),
    ],
)
