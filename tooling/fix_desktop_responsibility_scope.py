from pathlib import Path

path = Path('lib/screens/desktop_timesheet_screen.dart')
text = path.read_text(encoding='utf-8')

needle = '''            employee: employee,\n            value: shiftValueFor(employee),'''
replacement = '''            employee: employee,\n            responsibility: employee.id == null\n                ? null\n                : attendanceResponsibility[employee.id!],\n            value: shiftValueFor(employee),'''
count = text.count(needle)
if count != 2:
    raise RuntimeError(f'expected two row callsites, got {count}')
text = text.replace(needle, replacement)

text = text.replace(
'''  final Employee employee;\n  final double value;''',
'''  final Employee employee;\n  final ResponsibilityActor? responsibility;\n  final double value;''',
1,
)
text = text.replace(
'''    required this.employee,\n    required this.value,''',
'''    required this.employee,\n    this.responsibility,\n    required this.value,''',
1,
)
text = text.replace(
'''                      if (employee.id != null &&\n                          attendanceResponsibility[employee.id!] != null) ...[\n                        const SizedBox(height: 5),\n                        ResponsibilityActorLine(\n                          label: 'Изменил',\n                          actor: attendanceResponsibility[employee.id!]!,\n                          compact: true,\n                        ),\n                      ],''',
'''                      if (responsibility != null) ...[\n                        const SizedBox(height: 5),\n                        ResponsibilityActorLine(\n                          label: 'Изменил',\n                          actor: responsibility!,\n                          compact: true,\n                        ),\n                      ],''',
1,
)
path.write_text(text, encoding='utf-8')
