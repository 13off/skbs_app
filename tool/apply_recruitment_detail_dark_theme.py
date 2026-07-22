from pathlib import Path

path = Path(
    'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart'
)
text = path.read_text(encoding='utf-8')
original = text

replacements = [
    (
        "Color get _detailSuccess => AppAdaptivePalette.success;\n",
        "Color get _detailSuccess => AppAdaptivePalette.success;\n"
        "Color get _detailSurface => AppAdaptivePalette.surfaceElevated;\n"
        "Color get _detailBorder => AppAdaptivePalette.border;\n"
        "Color get _detailInput => AppAdaptivePalette.inputSurface;\n"
        "Color get _detailWarning => AppAdaptivePalette.warning;\n",
    ),
    ('color: Colors.white.withValues(alpha: 0.78),', 'color: _detailSurface,'),
    ('border: Border.all(color: Colors.white),', 'border: Border.all(color: _detailBorder),'),
    (
        'const Color(0xFFFFF4E2)',
        '_detailWarning.withValues(alpha: 0.14)',
    ),
    (
        'const Color(0xFFE8F4ED)',
        '_detailSuccess.withValues(alpha: 0.14)',
    ),
    ('const Color(0xFF9A6816)', '_detailWarning'),
    (
        'color: inbound ? Colors.white : const Color(0xFFDCEEFF),',
        'color: inbound\n              ? _detailSurface\n              : AppAdaptivePalette.selectedSurface,',
    ),
    ('color: Colors.white.withValues(alpha: 0.72),', 'color: _detailSoft,'),
    (
        'color: const Color(0xFFE9EDF1),',
        'color: AppAdaptivePalette.surfaceSoft,',
    ),
    (
        'color: Colors.white,\n              border: Border(top: BorderSide(color: Color(0xFFE1E4E8))),',
        'color: _detailSurface,\n              border: Border(top: BorderSide(color: _detailBorder)),',
    ),
    ('fillColor: const Color(0xFFF3F5F7),', 'fillColor: _detailInput,'),
    ('color: Colors.white.withValues(alpha: 0.70),', 'color: _detailSurface,'),
]

for old, new in replacements:
    if old in text:
        text = text.replace(old, new)

if text == original:
    raise RuntimeError('No changes made')
path.write_text(text, encoding='utf-8')
