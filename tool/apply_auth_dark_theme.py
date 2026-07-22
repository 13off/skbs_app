from pathlib import Path


def patch(path: str, replacements: list[tuple[str, str]]) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    original = text
    for old, new in replacements:
        if old in text:
            text = text.replace(old, new)
    if text == original:
        raise RuntimeError(f'No changes made in {path}')
    file_path.write_text(text, encoding='utf-8')


patch(
    'lib/features/auth/presentation/premium_auth_gate_v2.dart',
    [
        (
            "import '../../../app/app_theme.dart';\n",
            "import '../../../app/app_adaptive_palette.dart';\n"
            "import '../../../app/app_theme.dart';\n",
        ),
        ('AppColors.accentSoft', 'AppAdaptivePalette.accentSoft'),
        ('AppColors.textPrimary', 'AppAdaptivePalette.textPrimary'),
        ('AppColors.textMuted', 'AppAdaptivePalette.textMuted'),
        (
            'Colors.white.withValues(alpha: 0.82)',
            'AppAdaptivePalette.surfaceElevated',
        ),
        (
            'Colors.white.withValues(alpha: 0.94)',
            'AppAdaptivePalette.border',
        ),
        ('const BoxDecoration(', 'BoxDecoration('),
    ],
)

patch(
    'lib/features/auth/presentation/premium_login_screen_v2.dart',
    [
        (
            "import '../../../app/app_theme.dart';\n",
            "import '../../../app/app_adaptive_palette.dart';\n"
            "import '../../../app/app_theme.dart';\n",
        ),
        ('AppColors.textPrimary', 'AppAdaptivePalette.textPrimary'),
        ('AppColors.textMuted', 'AppAdaptivePalette.textMuted'),
        (
            'fillColor: Colors.white.withValues(alpha: 0.88),',
            'fillColor: AppAdaptivePalette.inputSurface,',
        ),
        (
            'color: Colors.white.withValues(alpha: 0.80),',
            'color: AppAdaptivePalette.surfaceElevated,',
        ),
        (
            'color: Colors.white.withValues(alpha: 0.92),',
            'color: AppAdaptivePalette.border,',
        ),
        (
            'color: Colors.white.withValues(alpha: 0.72),',
            'color: AppAdaptivePalette.surface.withValues(\n                                  alpha: AppAdaptivePalette.isDark ? 0.12 : 0.72,\n                                ),',
        ),
        (
            'keyboardAppearance: Brightness.light,',
            'keyboardAppearance: AppAdaptivePalette.isDark\n                                      ? Brightness.dark\n                                      : Brightness.light,',
        ),
        (
            'color: const Color(0xFFFFF2F1),',
            'color: AppAdaptivePalette.danger.withValues(alpha: 0.12),',
        ),
        (
            'color: const Color(0xFFF0D2CF),',
            'color: AppAdaptivePalette.danger.withValues(alpha: 0.32),',
        ),
        ('color: Color(0xFFA64F49)', 'color: AppAdaptivePalette.danger'),
        (
            'color: const Color(\n                                                             0xFF874540,\n                                                           ),',
            'color: AppAdaptivePalette.danger,',
        ),
        ('color: Color(0xFF3A8B61)', 'color: AppAdaptivePalette.success'),
        ('const inputTextStyle = TextStyle(', 'final inputTextStyle = TextStyle('),
        ('const TextStyle(', 'TextStyle('),
        ('const BoxDecoration(', 'BoxDecoration('),
        ('const Icon(', 'Icon('),
    ],
)

patch(
    'lib/features/auth/presentation/company_signup_screen.dart',
    [
        (
            "import '../../../app/app_theme.dart';\n",
            "import '../../../app/app_adaptive_palette.dart';\n",
        ),
        ('AppColors.textPrimary', 'AppAdaptivePalette.textPrimary'),
        ('AppColors.textMuted', 'AppAdaptivePalette.textMuted'),
        (
            'fillColor: Colors.white.withValues(alpha: 0.90),',
            'fillColor: AppAdaptivePalette.inputSurface,',
        ),
        (
            'color: Colors.white.withValues(alpha: 0.84),',
            'color: AppAdaptivePalette.surfaceElevated,',
        ),
        (
            'border: Border.all(color: Colors.white),',
            'border: Border.all(color: AppAdaptivePalette.border),',
        ),
        (
            'color: const Color(0xFFFFF2F1),',
            'color: AppAdaptivePalette.danger.withValues(alpha: 0.12),',
        ),
        (
            'color: const Color(0xFFF0D2CF),',
            'color: AppAdaptivePalette.danger.withValues(alpha: 0.32),',
        ),
        ('color: Color(0xFFA64F49)', 'color: AppAdaptivePalette.danger'),
        ('color: Color(0xFF874540)', 'color: AppAdaptivePalette.danger'),
        (
            'color: const Color(0xFFF1F2F3),',
            'color: AppAdaptivePalette.surfaceSoft,',
        ),
        ('const TextStyle(', 'TextStyle('),
        ('const Icon(', 'Icon('),
    ],
)
