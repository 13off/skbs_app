from __future__ import annotations

import re
from pathlib import Path

ROOTS = [Path('lib/screens'), Path('lib/features')]
PART_FILES = {
    Path('lib/features/legal/presentation/legal_document_details_part.dart'),
    Path('lib/features/legal/presentation/legal_matter_details_part.dart'),
}
PACKAGE_IMPORT = "import 'package:skbs_app/app/app_adaptive_palette.dart';"

NEUTRAL_REPLACEMENTS = {
    'Colors.grey.shade100': 'AppAdaptivePalette.surfaceElevated',
    'Colors.grey.shade200': 'AppAdaptivePalette.border',
    'Colors.grey.shade700': 'AppAdaptivePalette.textMuted',
    'const Color(0xFFF7F8FA)': 'AppAdaptivePalette.surfaceElevated',
    'Color(0xFFF7F8FA)': 'AppAdaptivePalette.surfaceElevated',
    'const Color(0xFFF0F1F3)': 'AppAdaptivePalette.surfaceSoft',
    'Color(0xFFF0F1F3)': 'AppAdaptivePalette.surfaceSoft',
    'const Color(0xFFF1F2F3)': 'AppAdaptivePalette.surfaceSoft',
    'Color(0xFFF1F2F3)': 'AppAdaptivePalette.surfaceSoft',
    'const Color(0xFFF1F2F4)': 'AppAdaptivePalette.surfaceSoft',
    'Color(0xFFF1F2F4)': 'AppAdaptivePalette.surfaceSoft',
    'const Color(0xFFF2F3F5)': 'AppAdaptivePalette.surfaceSoft',
    'Color(0xFFF2F3F5)': 'AppAdaptivePalette.surfaceSoft',
    'const Color(0xFF1F2328)': 'AppAdaptivePalette.textPrimary',
    'Color(0xFF1F2328)': 'AppAdaptivePalette.textPrimary',
    'const Color(0xFF34383D)': 'AppAdaptivePalette.textPrimary',
    'Color(0xFF34383D)': 'AppAdaptivePalette.textPrimary',
    'const Color(0xFF3D4146)': 'AppAdaptivePalette.textPrimary',
    'Color(0xFF3D4146)': 'AppAdaptivePalette.textPrimary',
    'const Color(0xFF5F646A)': 'AppAdaptivePalette.textMuted',
    'Color(0xFF5F646A)': 'AppAdaptivePalette.textMuted',
    'const Color(0xFF6B7075)': 'AppAdaptivePalette.textMuted',
    'Color(0xFF6B7075)': 'AppAdaptivePalette.textMuted',
    'const Color(0xFF6F747A)': 'AppAdaptivePalette.textMuted',
    'Color(0xFF6F747A)': 'AppAdaptivePalette.textMuted',
    'const Color(0xFF8A8F94)': 'AppAdaptivePalette.textFaint',
    'Color(0xFF8A8F94)': 'AppAdaptivePalette.textFaint',
    'const Color(0xFFD7D9DC)': 'AppAdaptivePalette.border',
    'Color(0xFFD7D9DC)': 'AppAdaptivePalette.border',
    'const Color(0xFFE1E2DF)': 'AppAdaptivePalette.border',
    'Color(0xFFE1E2DF)': 'AppAdaptivePalette.border',
    'const Color(0xFFE3E5E8)': 'AppAdaptivePalette.border',
    'Color(0xFFE3E5E8)': 'AppAdaptivePalette.border',
    'const Color(0xFFE5E7EA)': 'AppAdaptivePalette.border',
    'Color(0xFFE5E7EA)': 'AppAdaptivePalette.border',
}

STATUS_REPLACEMENTS = {
    'const Color(0xFF28704E)': 'AppAdaptivePalette.success',
    'Color(0xFF28704E)': 'AppAdaptivePalette.success',
    'const Color(0xFF2E7D52)': 'AppAdaptivePalette.success',
    'Color(0xFF2E7D52)': 'AppAdaptivePalette.success',
    'const Color(0xFF3A8B61)': 'AppAdaptivePalette.success',
    'Color(0xFF3A8B61)': 'AppAdaptivePalette.success',
    'const Color(0xFF8A5A12)': 'AppAdaptivePalette.warning',
    'Color(0xFF8A5A12)': 'AppAdaptivePalette.warning',
    'const Color(0xFF8A6120)': 'AppAdaptivePalette.warning',
    'Color(0xFF8A6120)': 'AppAdaptivePalette.warning',
    'const Color(0xFF8A6418)': 'AppAdaptivePalette.warning',
    'Color(0xFF8A6418)': 'AppAdaptivePalette.warning',
    'const Color(0xFF9A6816)': 'AppAdaptivePalette.warning',
    'Color(0xFF9A6816)': 'AppAdaptivePalette.warning',
    'const Color(0xFF874540)': 'AppAdaptivePalette.danger',
    'Color(0xFF874540)': 'AppAdaptivePalette.danger',
    'const Color(0xFF9A403A)': 'AppAdaptivePalette.danger',
    'Color(0xFF9A403A)': 'AppAdaptivePalette.danger',
    'const Color(0xFF9D3E38)': 'AppAdaptivePalette.danger',
    'Color(0xFF9D3E38)': 'AppAdaptivePalette.danger',
    'const Color(0xFFA64F49)': 'AppAdaptivePalette.danger',
    'Color(0xFFA64F49)': 'AppAdaptivePalette.danger',
    'const Color(0xFFE7F4EC)': 'AppAdaptivePalette.success.withValues(alpha: 0.12)',
    'Color(0xFFE7F4EC)': 'AppAdaptivePalette.success.withValues(alpha: 0.12)',
    'const Color(0xFFE8F5ED)': 'AppAdaptivePalette.success.withValues(alpha: 0.12)',
    'Color(0xFFE8F5ED)': 'AppAdaptivePalette.success.withValues(alpha: 0.12)',
    'const Color(0xFFFFF3DE)': 'AppAdaptivePalette.warning.withValues(alpha: 0.12)',
    'Color(0xFFFFF3DE)': 'AppAdaptivePalette.warning.withValues(alpha: 0.12)',
    'const Color(0xFFFFF4DC)': 'AppAdaptivePalette.warning.withValues(alpha: 0.12)',
    'Color(0xFFFFF4DC)': 'AppAdaptivePalette.warning.withValues(alpha: 0.12)',
    'const Color(0xFFF4E9E7)': 'AppAdaptivePalette.danger.withValues(alpha: 0.12)',
    'Color(0xFFF4E9E7)': 'AppAdaptivePalette.danger.withValues(alpha: 0.12)',
    'const Color(0xFFF7E8E7)': 'AppAdaptivePalette.danger.withValues(alpha: 0.12)',
    'Color(0xFFF7E8E7)': 'AppAdaptivePalette.danger.withValues(alpha: 0.12)',
}

STATUS_PATH_MARKERS = (
    '/archive/',
    '/compliance/',
    '/developer/',
    '/milestones/',
    '/recruitment/',
    'desktop_employees_view.dart',
    'mobile_tasks_screen.dart',
    'template_documents_screen.dart',
    'ai_assistant_action_screen.dart',
    'ai_operational_audit_screen.dart',
)


def insert_import(text: str) -> str:
    if PACKAGE_IMPORT in text or "part of '" in text or 'part of "' in text:
        return text
    material_import = "import 'package:flutter/material.dart';"
    if material_import in text:
        return text.replace(material_import, f'{material_import}\n{PACKAGE_IMPORT}', 1)
    first_import = re.search(r"^import .+?;\n", text, flags=re.MULTILINE)
    if first_import:
        position = first_import.end()
        return text[:position] + PACKAGE_IMPORT + '\n' + text[position:]
    raise RuntimeError('Cannot insert adaptive palette import')


def matching_delimiter(text: str, start: int, opening: str, closing: str) -> int | None:
    depth = 0
    quote: str | None = None
    escaped = False
    index = start
    while index < len(text):
        char = text[index]
        if quote is not None:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == quote:
                quote = None
            index += 1
            continue
        if char in ("'", '"'):
            quote = char
            index += 1
            continue
        if char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return None


def remove_dynamic_const(text: str) -> str:
    constructor = re.compile(r'\bconst\s+[A-Za-z_][A-Za-z0-9_<>?,. ]*\(')
    const_list = re.compile(r'\bconst\s+(?:<[^>]+>\s*)?\[')
    changed = True
    while changed:
        changed = False
        for pattern, opening, closing in (
            (constructor, '(', ')'),
            (const_list, '[', ']'),
        ):
            matches = list(pattern.finditer(text))
            for match in reversed(matches):
                open_pos = text.find(opening, match.start(), match.end())
                if open_pos < 0:
                    continue
                end = matching_delimiter(text, open_pos, opening, closing)
                if end is None:
                    continue
                if 'AppAdaptivePalette.' not in text[match.start(): end + 1]:
                    continue
                const_start = match.start()
                const_end = const_start + len('const ')
                text = text[:const_start] + text[const_end:]
                changed = True
    return text


def special_fixes(path: Path, text: str) -> str:
    if path == Path('lib/screens/monthly_timesheet_screen.dart'):
        text = text.replace(
            'color: shift > 0 ? Colors.black : Colors.grey,',
            'color: shift > 0\n'
            '                    ? AppAdaptivePalette.textPrimary\n'
            '                    : AppAdaptivePalette.textMuted,',
        )
        text = text.replace(
            'color: row.balance > 0 ? Colors.red : Colors.green,',
            'color: row.balance > 0\n'
            '                  ? AppAdaptivePalette.danger\n'
            '                  : AppAdaptivePalette.success,',
        )
        text = text.replace(
            'style: const TextStyle(color: Colors.red),',
            'style: TextStyle(color: AppAdaptivePalette.danger),',
        )
    if path == Path('lib/screens/attendance_report_screen.dart'):
        text = text.replace(
            'style: const TextStyle(color: Colors.red),',
            'style: TextStyle(color: AppAdaptivePalette.danger),',
        )
    if path == Path('lib/features/employees/presentation/screens/add_employee_screen.dart'):
        text = text.replace(
            'style: TextStyle(color: Colors.red)',
            'style: TextStyle(color: AppAdaptivePalette.danger)',
        )
        text = text.replace(
            'Text(errorText!, style: const TextStyle(color: Colors.red))',
            'Text(errorText!, style: TextStyle(color: AppAdaptivePalette.danger))',
        )
    if path == Path('lib/screens/act_preview_screen.dart'):
        text = text.replace(
            'color: Colors.red,',
            'color: AppAdaptivePalette.danger,',
        )
    if path == Path('lib/features/shared/presentation/specialist_desktop_ui.dart'):
        text = text.replace("import '../../../app/theme_controller.dart';\n", '')
        start = text.index('Color get specialistText')
        end = text.index('\n\nclass SpecialistDesktopPage')
        replacement = '''Color get specialistText => AppAdaptivePalette.textPrimary;
Color get specialistMuted => AppAdaptivePalette.textMuted;
Color get specialistLine => AppAdaptivePalette.border;
Color get specialistSoft => AppAdaptivePalette.surfaceSoft;
Color get specialistSuccess => AppAdaptivePalette.success;
Color get specialistWarning => AppAdaptivePalette.warning;
Color get specialistDanger => AppAdaptivePalette.danger;'''
        text = text[:start] + replacement + text[end:]
    if path == Path('lib/features/milestones/presentation/milestone_detail_screen.dart'):
        old = '''class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    this.color = AppAdaptivePalette.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container('''
        new = '''class _StatusPill extends StatelessWidget {
  final String label;
  final Color? color;

  const _StatusPill({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppAdaptivePalette.textMuted;
    return Container('''
        text = text.replace(old, new)
        text = text.replace(
            'color: color.withValues(alpha: 0.10),',
            'color: effectiveColor.withValues(alpha: 0.10),',
        )
        text = text.replace(
            'border: Border.all(color: color.withValues(alpha: 0.22)),',
            'border: Border.all(color: effectiveColor.withValues(alpha: 0.22)),',
        )
        text = text.replace('color: color,', 'color: effectiveColor,')
    return text


def update_file(path: Path) -> bool:
    original = path.read_text(encoding='utf-8')
    text = original
    for old, new in NEUTRAL_REPLACEMENTS.items():
        text = text.replace(old, new)
    normalized = '/' + path.as_posix()
    if any(marker in normalized for marker in STATUS_PATH_MARKERS):
        for old, new in STATUS_REPLACEMENTS.items():
            text = text.replace(old, new)
    text = special_fixes(path, text)
    if text == original:
        return False
    if path not in PART_FILES:
        text = insert_import(text)
    text = remove_dynamic_const(text)
    path.write_text(text, encoding='utf-8')
    return True


def rewrite_contract() -> None:
    path = Path('test/theme_hardcoded_colors_audit_test.dart')
    path.write_text(
        '''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('рабочие экраны не возвращают старые неадаптивные нейтральные цвета', () {
    final roots = <Directory>[
      Directory('lib/screens'),
      Directory('lib/features'),
    ];
    const forbidden = <String>[
      'Colors.grey.shade100',
      'Colors.grey.shade200',
      'Colors.grey.shade700',
      'Color(0xFFF7F8FA)',
      'Color(0xFFF0F1F3)',
      'Color(0xFFF1F2F3)',
      'Color(0xFFF1F2F4)',
      'Color(0xFFF2F3F5)',
      'Color(0xFF1F2328)',
      'Color(0xFF34383D)',
      'Color(0xFF3D4146)',
      'Color(0xFF5F646A)',
      'Color(0xFF6B7075)',
      'Color(0xFF6F747A)',
      'Color(0xFF8A8F94)',
      'Color(0xFFD7D9DC)',
      'Color(0xFFE1E2DF)',
      'Color(0xFFE3E5E8)',
      'Color(0xFFE5E7EA)',
    ];
    final violations = <String>[];

    for (final root in roots) {
      for (final file in root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final token in forbidden) {
          if (source.contains(token)) {
            violations.add('${file.path}: $token');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\\n'));
  });

  test('ключевые формы используют адаптивную палитру без изменения данных', () {
    final addEmployee = File(
      'lib/features/employees/presentation/screens/add_employee_screen.dart',
    ).readAsStringSync();
    final editEmployee = File(
      'lib/screens/edit_employee_screen.dart',
    ).readAsStringSync();
    final monthly = File(
      'lib/screens/monthly_timesheet_screen.dart',
    ).readAsStringSync();

    expect(addEmployee, contains('AppAdaptivePalette.surfaceElevated'));
    expect(addEmployee, contains('EmployeeRepository.addEmployee'));
    expect(editEmployee, contains('AppAdaptivePalette.surfaceElevated'));
    expect(editEmployee, contains('EmployeeRepository.updateEmployee'));
    expect(monthly, contains('AppAdaptivePalette.textPrimary'));
    expect(monthly, contains('AttendanceRepository.fetchMonthlyTimesheet'));
  });
}
''',
        encoding='utf-8',
    )


def main() -> None:
    changed: list[str] = []
    for root in ROOTS:
        for path in sorted(root.rglob('*.dart')):
            if update_file(path):
                changed.append(path.as_posix())
    rewrite_contract()
    print(f'Updated {len(changed)} UI files:')
    for path in changed:
        print(path)


if __name__ == '__main__':
    main()
