from pathlib import Path
import os
import re

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'lib'


def rel_import(path: Path) -> str:
    return os.path.relpath(
        LIB / 'app/app_adaptive_palette.dart',
        path.parent,
    ).replace('\\', '/')


def ensure_palette_import(path: Path, text: str) -> str:
    if 'app_adaptive_palette.dart' in text:
        return text
    marker = "import 'package:flutter/material.dart';"
    if marker not in text:
        return text
    return text.replace(
        marker,
        marker + f"\n\nimport '{rel_import(path)}';",
        1,
    )


COLOR_MAP = {
    '0xFF1F2328': 'AppAdaptivePalette.textPrimary',
    '0xFF6B7075': 'AppAdaptivePalette.textMuted',
    '0xFFE6E8EB': 'AppAdaptivePalette.border',
    '0xFFE4E2DC': 'AppAdaptivePalette.border',
    '0xFFF2F3F5': 'AppAdaptivePalette.surfaceSoft',
    '0xFFF1F2F4': 'AppAdaptivePalette.surfaceSoft',
    '0xFFF1F0EC': 'AppAdaptivePalette.surfaceSoft',
    '0xFFF7F8FA': 'AppAdaptivePalette.background',
    '0xFFFFFFFF': 'AppAdaptivePalette.surfaceElevated',
    '0xFF8F9499': 'AppAdaptivePalette.textFaint',
    '0xFF646A70': 'AppAdaptivePalette.textMuted',
    '0xFF66766A': 'AppAdaptivePalette.success',
    '0xFF2E7D52': 'AppAdaptivePalette.success',
    '0xFF22C55E': 'AppAdaptivePalette.success',
    '0xFF8A6259': 'AppAdaptivePalette.warning',
    '0xFF9A6816': 'AppAdaptivePalette.warning',
    '0xFF9A6A16': 'AppAdaptivePalette.warning',
    '0xFF9D3E38': 'AppAdaptivePalette.danger',
    '0xFF9A403A': 'AppAdaptivePalette.danger',
}

PALETTE_FILES = [
    'screens/desktop_timesheet_screen.dart',
    'screens/object_management_screen.dart',
    'screens/desktop_object_management_dialog.dart',
    'widgets/notification_bell.dart',
    'widgets/task_tile.dart',
    'features/recruitment/presentation/recruitment_archive_screen.dart',
    'features/recruitment/presentation/recruitment_application_detail_screen.dart',
    'features/recruitment/presentation/recruitment_dashboard_screen.dart',
    'features/recruitment/presentation/recruitment_applications_screen.dart',
    'features/company/presentation/company_plans_screen.dart',
    'features/payments/presentation/widgets/payment_report_sheet.dart',
    'features/archive/presentation/archive_management_screen_v3.dart',
]


def patch_palette_file(relative: str) -> None:
    path = LIB / relative
    text = ensure_palette_import(path, path.read_text(encoding='utf-8'))
    for color, expression in COLOR_MAP.items():
        text = re.sub(
            rf'const Color ([_A-Za-z0-9]+) = Color\({color}\);',
            rf'Color get \1 => {expression};',
            text,
        )
    for name in [
        'TextStyle',
        'Icon',
        'BoxDecoration',
        'Border',
        'BorderSide',
        'CircleAvatar',
        'AppBar',
        'DropdownMenuItem',
        'SizedBox',
        'Padding',
        'Expanded',
        'Row',
        'Column',
        'Material',
        'ListTile',
        'Chip',
        'FilterChip',
    ]:
        text = text.replace(f'const {name}(', f'{name}(')
    path.write_text(text, encoding='utf-8')


def patch_app_page() -> None:
    path = LIB / 'widgets/app_page.dart'
    text = ensure_palette_import(path, path.read_text(encoding='utf-8'))
    text = text.replace(
        '  final Widget? headerTrailing;\n',
        '  final Widget? headerTrailing;\n'
        '  final bool showBackButton;\n'
        '  final VoidCallback? onBack;\n',
        1,
    )
    text = text.replace(
        '    this.headerTrailing,\n  });',
        '    this.headerTrailing,\n'
        '    this.showBackButton = false,\n'
        '    this.onBack,\n'
        '  });',
        1,
    )
    text = text.replace(
        '                      trailing: effectiveTrailing,\n',
        '                      trailing: effectiveTrailing,\n'
        '                      showBackButton: showBackButton,\n'
        '                      onBack: onBack,\n',
        1,
    )
    text = text.replace(
        '  final Widget? trailing;\n',
        '  final Widget? trailing;\n'
        '  final bool showBackButton;\n'
        '  final VoidCallback? onBack;\n',
        1,
    )
    text = text.replace(
        '    this.trailing,\n  });',
        '    this.trailing,\n'
        '    this.showBackButton = false,\n'
        '    this.onBack,\n'
        '  });',
        1,
    )
    text = text.replace(
        '      children: [\n        Expanded(',
        '      children: [\n'
        '        if (showBackButton) ...[\n'
        '          BackButton(\n'
        '            onPressed: onBack ?? () => Navigator.of(context).maybePop(),\n'
        '          ),\n'
        '          const SizedBox(width: 4),\n'
        '        ],\n'
        '        Expanded(',
        1,
    )
    text = text.replace(
        '? const [Color(0xFF15181C), Color(0xFF090B0E)]',
        '? const [\n'
        '                  AppAdaptivePalette.darkBackground,\n'
        '                  AppAdaptivePalette.darkSurface,\n'
        '                ]',
    )
    text = text.replace(
        'const Color(0xFF4D5661).withValues(alpha: 0.24)',
        'AppAdaptivePalette.telegramBlue.withValues(alpha: 0.12)',
    )
    path.write_text(text, encoding='utf-8')


def patch_pwa() -> None:
    path = LIB / 'screens/pwa_install_screen.dart'
    text = ensure_palette_import(path, path.read_text(encoding='utf-8'))
    text = text.replace(
        'color: const Color(0xFFF1F0EC),',
        'color: AppAdaptivePalette.surfaceSoft,',
    )
    text = text.replace(
        'color: Color(0xFF34373B),',
        'color: AppAdaptivePalette.textPrimary,',
    )
    text = text.replace(
        'color: Color(0xFF1F2328),',
        'color: AppAdaptivePalette.textPrimary,',
    )
    text = text.replace(
        'color: Color(0xFF6B7075),',
        'color: AppAdaptivePalette.textMuted,',
    )
    text = text.replace(
        'color: Color(0xFF5F646A),',
        'color: AppAdaptivePalette.textMuted,',
    )
    text = text.replace(
        'Icon(icon, size: 21, color: const Color(0xFF50555A))',
        'Icon(icon, size: 21, color: AppAdaptivePalette.textMuted)',
    )
    text = text.replace('const TextStyle(', 'TextStyle(')
    path.write_text(text, encoding='utf-8')


def patch_employee_details() -> None:
    parent = LIB / 'screens/employee_details_screen.dart'
    parent.write_text(
        ensure_palette_import(parent, parent.read_text(encoding='utf-8')),
        encoding='utf-8',
    )

    path = LIB / 'screens/employee_details/employee_details_sections.dart'
    text = path.read_text(encoding='utf-8')
    replacements = {
        'color: const Color(0xFFF7F8FA),': 'color: AppAdaptivePalette.surface,',
        'color: Colors.grey.shade100,': 'color: AppAdaptivePalette.surface,',
        'color: isFired ? Colors.grey.shade300 : Colors.green.shade100,':
            'color: isFired\n'
            '            ? AppAdaptivePalette.disabledSurface\n'
            '            : AppAdaptivePalette.success.withValues(alpha: 0.18),',
        'color: isFired ? Colors.grey.shade800 : Colors.green.shade800,':
            'color: isFired\n'
            '              ? AppAdaptivePalette.disabledText\n'
            '              : AppAdaptivePalette.success,',
        '? Colors.grey.shade300\n                  : const Color(0xFFF2F3F5),':
            '? AppAdaptivePalette.disabledSurface\n'
            '                  : AppAdaptivePalette.surfaceSoft,',
        '? Colors.grey.shade700\n                      : const Color(0xFF6B7075),':
            '? AppAdaptivePalette.disabledText\n'
            '                      : AppAdaptivePalette.textMuted,',
        'color: isFired ? Colors.grey.shade700 : Colors.black87,':
            'color: isFired\n'
            '                    ? AppAdaptivePalette.disabledText\n'
            '                    : AppAdaptivePalette.textPrimary,',
        'border: Border.all(color: Colors.grey.shade200),':
            'border: Border.all(color: AppAdaptivePalette.border),',
        'color: const Color(0xFFF2F3F5),':
            'color: AppAdaptivePalette.surfaceSoft,',
        'child: child ?? Icon(icon, color: const Color(0xFF8F9499)),':
            'child: child ?? Icon(icon, color: AppAdaptivePalette.textMuted),',
        'Icon(icon, size: 19, color: Colors.grey.shade700)':
            'Icon(icon, size: 19, color: AppAdaptivePalette.textMuted)',
        'color: Colors.grey.shade700,': 'color: AppAdaptivePalette.textMuted,',
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    for name in [
        'TextStyle',
        'Icon',
        'BoxDecoration',
        'Border',
        'BorderSide',
        'CircleAvatar',
        'Material',
        'ListTile',
        'Text',
    ]:
        text = text.replace(f'const {name}(', f'{name}(')
    path.write_text(text, encoding='utf-8')

    path = LIB / 'screens/employee_details/employee_details_copy.dart'
    text = path.read_text(encoding='utf-8')
    text = text.replace(
        'color: Colors.white,',
        'color: AppAdaptivePalette.surfaceElevated,',
    )
    text = text.replace(
        'border: Border.all(color: Colors.grey.shade200),',
        'border: Border.all(color: AppAdaptivePalette.border),',
    )
    text = text.replace(
        'color: const Color(0xFFF7F8FA),',
        'color: AppAdaptivePalette.surface,',
    )
    text = text.replace(
        'color: Colors.grey.shade700,',
        'color: AppAdaptivePalette.textMuted,',
    )
    for name in ['TextStyle', 'Icon', 'BoxDecoration', 'Border', 'BorderSide', 'Text']:
        text = text.replace(f'const {name}(', f'{name}(')
    path.write_text(text, encoding='utf-8')


def patch_specific_surfaces() -> None:
    path = LIB / 'screens/desktop_object_management_dialog.dart'
    text = path.read_text(encoding='utf-8').replace(
        'color: selected == objectName\n'
        '                                        ? _soft\n'
        '                                        : Colors.white,',
        'color: selected == objectName\n'
        '                                        ? AppAdaptivePalette.selectedSurface\n'
        '                                        : AppAdaptivePalette.surfaceElevated,',
    )
    path.write_text(text, encoding='utf-8')

    path = LIB / 'screens/desktop_timesheet_screen.dart'
    text = path.read_text(encoding='utf-8')
    text = text.replace(
        'color: Colors.white.withValues(alpha: 0.88),',
        'color: AppAdaptivePalette.surfaceElevated,',
    )
    text = text.replace(
        'color: selected ? Colors.white : _muted,',
        'color: selected ? AppAdaptivePalette.onAccent : _muted,',
    )
    path.write_text(text, encoding='utf-8')

    path = LIB / 'features/company/presentation/company_plans_screen.dart'
    text = path.read_text(encoding='utf-8').replace(
        'backgroundColor: const Color(0xFFFAF9F6),',
        'backgroundColor: AppAdaptivePalette.background,',
    )
    path.write_text(text, encoding='utf-8')

    path = LIB / 'features/archive/presentation/archive_management_screen_v3.dart'
    text = path.read_text(encoding='utf-8')
    text = text.replace(
        'backgroundColor: const Color(0xFFFAF9F6),',
        'backgroundColor: AppAdaptivePalette.background,',
    )
    text = text.replace(
        'color: const Color(0xFFF8F7F3),',
        'color: AppAdaptivePalette.surface,',
    )
    path.write_text(text, encoding='utf-8')

    path = LIB / 'features/recruitment/presentation/recruitment_dashboard_screen.dart'
    text = path.read_text(encoding='utf-8')
    text = text.replace(
        'color: Colors.white.withValues(alpha: 0.72),',
        'color: AppAdaptivePalette.surfaceElevated,',
    )
    text = text.replace(
        'border: Border.all(color: Colors.white),',
        'border: Border.all(color: AppAdaptivePalette.border),',
    )
    path.write_text(text, encoding='utf-8')

    path = LIB / 'features/recruitment/presentation/recruitment_applications_screen.dart'
    text = path.read_text(encoding='utf-8')
    text = text.replace(
        'color: const Color(0xFFF8F7F3),',
        'color: AppAdaptivePalette.surface,',
    )
    text = text.replace(
        'color: selected ? Colors.white : _text,',
        'color: selected ? AppAdaptivePalette.onAccent : _text,',
    )
    path.write_text(text, encoding='utf-8')


def add_explicit_appbar_back_buttons() -> None:
    for path in LIB.rglob('*.dart'):
        text = path.read_text(encoding='utf-8')
        if 'appBar: AppBar(' not in text:
            continue
        position = 0
        changed = False
        while True:
            index = text.find('appBar: AppBar(', position)
            if index < 0:
                break
            open_index = text.find('(', index)
            depth = 0
            end = None
            quote = None
            escaped = False
            for cursor in range(open_index, len(text)):
                char = text[cursor]
                if quote:
                    if escaped:
                        escaped = False
                    elif char == '\\':
                        escaped = True
                    elif char == quote:
                        quote = None
                    continue
                if char in "'\"":
                    quote = char
                    continue
                if char == '(':
                    depth += 1
                elif char == ')':
                    depth -= 1
                    if depth == 0:
                        end = cursor
                        break
            if end is None:
                break
            block = text[open_index:end]
            if 'leading:' not in block:
                text = (
                    text[:open_index + 1]
                    + '\n        leading: const BackButton(),'
                    + text[open_index + 1:]
                )
                changed = True
                position = end + 40
            else:
                position = end + 1
        if changed:
            path.write_text(text, encoding='utf-8')


def add_missing_page_back_flags() -> None:
    targets = {
        'features/dispatcher/presentation/dispatcher_settings_screen.dart':
            ["title: 'ИИ-диспетчер'"],
        'features/dispatcher/presentation/dispatcher_summary_details_screen.dart':
            ["title: 'Разбор сводки'"],
        'features/developer/presentation/developer_system_screen.dart':
            ["title: 'Система'"],
        'features/developer/presentation/developer_role_acceptance_screen.dart':
            ["title: 'Ролевая приёмка'"],
        'features/developer/presentation/developer_readiness_screen.dart':
            ["title: 'Готовность и диагностика'"],
        'features/developer/presentation/developer_demo_center_screen.dart':
            ["title: 'Демонстрационный центр'"],
        'features/developer/presentation/developer_constructor_screen.dart':
            ["title: 'Конструктор'"],
        'features/role_preview/role_preview_screen.dart':
            ["title: 'Режим платформы'"],
        'features/recruitment/presentation/recruitment_archive_screen.dart':
            ["title: 'Архив заявок'"],
        'features/recruitment/presentation/recruitment_application_detail_screen.dart':
            ["title: 'Кандидат'"],
        'features/recruitment/presentation/recruitment_onboarding_screen.dart':
            ["title: 'Кадровый комплект'"],
        'features/recruitment/presentation/recruitment_mobilization_screen.dart':
            ["title: 'Выход сотрудника'"],
        'features/ai/presentation/operational_audit_launcher_screen.dart':
            ["title: 'Контроль табеля и выплат'"],
        'features/compliance/presentation/company_compliance_screen.dart':
            ["title: 'Работодатель и персональные данные'"],
    }
    for relative, markers in targets.items():
        path = LIB / relative
        text = path.read_text(encoding='utf-8')
        for marker in markers:
            index = text.find(marker)
            if index < 0:
                raise RuntimeError(f'Missing marker: {relative}: {marker}')
            line_end = text.find('\n', index)
            nearby = text[index:line_end + 140]
            if 'showBackButton:' not in nearby:
                text = (
                    text[:line_end + 1]
                    + '      showBackButton: true,\n'
                    + text[line_end + 1:]
                )
        path.write_text(text, encoding='utf-8')


def add_object_management_appbar() -> None:
    path = LIB / 'screens/object_management_screen.dart'
    text = path.read_text(encoding='utf-8')
    old = (
        '    return Scaffold(\n'
        '      backgroundColor: _bg,\n'
        '      body: RefreshIndicator('
    )
    new = (
        '    return Scaffold(\n'
        '      backgroundColor: _bg,\n'
        '      appBar: AppBar(\n'
        '        leading: const BackButton(),\n'
        "        title: const Text('Управление объектами'),\n"
        '      ),\n'
        '      body: RefreshIndicator('
    )
    if old not in text:
        raise RuntimeError('Object management scaffold marker is missing')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def main() -> None:
    patch_app_page()
    for relative in PALETTE_FILES:
        patch_palette_file(relative)
    patch_pwa()
    patch_employee_details()
    patch_specific_surfaces()
    add_explicit_appbar_back_buttons()
    add_missing_page_back_flags()
    add_object_management_appbar()


if __name__ == '__main__':
    main()
