from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch(path_value: str, replacements: list[tuple[str, str]]) -> None:
    path = ROOT / path_value
    text = path.read_text(encoding='utf-8')
    original = text
    for old, new in replacements:
        if old not in text:
            raise RuntimeError(f'{path_value}: missing expected fragment {old!r}')
        text = text.replace(old, new, 1)
    if text == original:
        raise RuntimeError(f'{path_value}: no changes applied')
    path.write_text(text, encoding='utf-8')


patch(
    'lib/screens/desktop_timesheet_screen.dart',
    [
        (
            'color: selected ? _text : _soft,',
            'color: selected ? AppAdaptivePalette.accentStrong : _soft,',
        ),
        (
            'border: Border.all(color: selected ? _text : _line),',
            'border: Border.all(\n'
            '            color: selected ? AppAdaptivePalette.accent : _line,\n'
            '          ),',
        ),
    ],
)

patch(
    'lib/features/foreman/presentation/foreman_home_summary_widgets.dart',
    [
        (
            "import 'package:flutter/material.dart';\n\n",
            "import 'package:flutter/material.dart';\n\n"
            "import '../../../app/app_adaptive_palette.dart';\n",
        ),
        (
            'color: Colors.white,',
            'color: AppAdaptivePalette.surfaceElevated,',
        ),
    ],
)

patch(
    'lib/widgets/notification_bell.dart',
    [
        (
            'Color get _accent => AppAdaptivePalette.textFaint;',
            'Color get _accent => AppAdaptivePalette.accent;',
        ),
        (
            "gradient: LinearGradient(\n"
            "                begin: Alignment.topLeft,\n"
            "                end: Alignment.bottomRight,\n"
            "                colors: [\n"
            "                  Colors.white.withValues(alpha: 0.96),\n"
            "                  Colors.white.withValues(alpha: 0.76),\n"
            "                ],\n"
            "              ),",
            'color: hasUnread\n'
            '                  ? AppAdaptivePalette.accentSoft\n'
            '                  : _card,',
        ),
        (
            'border: Border.all(color: hasUnread ? _accent : Colors.white),',
            'border: Border.all(color: hasUnread ? _accent : _line),',
        ),
        (
            'color: _text,\n                    size: 25,',
            'color: hasUnread ? _accent : _muted,\n                    size: 25,',
        ),
    ],
)

patch(
    'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    [
        (
            'selectedColor: _text,',
            'selectedColor: AppAdaptivePalette.accentStrong,',
        ),
    ],
)
