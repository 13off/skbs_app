from pathlib import Path


def update(path: str, replacements: list[tuple[str, str]]) -> None:
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


update(
    'lib/features/archive/presentation/archive_management_screen.dart',
    [
        (
            "import '../../../app/app_theme.dart';\n",
            "import '../../../app/app_adaptive_palette.dart';\n"
            "import '../../../app/app_theme.dart';\n",
        ),
        ('AppColors.surfaceSoft', 'AppAdaptivePalette.surfaceSoft'),
        ('AppColors.border', 'AppAdaptivePalette.border'),
        ('AppColors.textMuted', 'AppAdaptivePalette.textMuted'),
        ('AppColors.textPrimary', 'AppAdaptivePalette.textPrimary'),
        ('AppColors.accent', 'AppAdaptivePalette.accent'),
        ('color: Colors.white,', 'color: AppAdaptivePalette.surface,'),
        (
            'selected ? Colors.white : AppAdaptivePalette.textMuted',
            'selected ? AppAdaptivePalette.onAccent : AppAdaptivePalette.textMuted',
        ),
        (
            'selected ? Colors.white : AppAdaptivePalette.textPrimary',
            'selected ? AppAdaptivePalette.onAccent : AppAdaptivePalette.textPrimary',
        ),
        ('const TextStyle(', 'TextStyle('),
        ('const BoxDecoration(', 'BoxDecoration('),
        ('const Icon(', 'Icon('),
        ('const BorderSide(', 'BorderSide('),
    ],
)

update(
    'lib/features/payments/presentation/screens/payments_screen.dart',
    [
        (
            "import '../../../../app/app_theme.dart';\n",
            "import '../../../../app/app_adaptive_palette.dart';\n"
            "import '../../../../app/app_theme.dart';\n",
        ),
        ('AppColors.textMuted', 'AppAdaptivePalette.textMuted'),
        ('AppColors.textPrimary', 'AppAdaptivePalette.textPrimary'),
        ('AppColors.accentSoft', 'AppAdaptivePalette.accentSoft'),
        (
            'fillColor: Colors.white.withValues(alpha: 0.86),',
            'fillColor: AppAdaptivePalette.inputSurface,',
        ),
        (
            'borderSide: const BorderSide(color: Colors.white),',
            'borderSide: BorderSide(color: AppAdaptivePalette.border),',
        ),
        ('color: const Color(0xFF8A4B46)', 'color: AppAdaptivePalette.danger'),
        ('color: const Color(0xFF3F6B56)', 'color: AppAdaptivePalette.success'),
        ('balanceColor = const Color(0xFF8A4B46);', 'balanceColor = AppAdaptivePalette.danger;'),
        ('balanceColor = const Color(0xFF3F6B56);', 'balanceColor = AppAdaptivePalette.success;'),
        (
            'style: const TextStyle(color: Colors.red),',
            'style: TextStyle(color: AppAdaptivePalette.danger),',
        ),
        ('color: Colors.white,', 'color: AppAdaptivePalette.surfaceElevated,'),
        (
            'Border.all(color: const Color(0xFFE1E2DF))',
            'Border.all(color: AppAdaptivePalette.border)',
        ),
        ('const TextStyle(', 'TextStyle('),
        ('const BoxDecoration(', 'BoxDecoration('),
        ('const Icon(', 'Icon('),
        ('const BorderSide(', 'BorderSide('),
    ],
)
