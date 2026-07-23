from pathlib import Path
import re

path = Path('lib/data/employee_repository.dart')
text = path.read_text(encoding='utf-8')

pattern = re.compile(
    r"  static Future<List<Employee>> _loadEmployees\(\{.*?\n"
    r"  static List<Employee> _employeesFromRows",
    re.DOTALL,
)

replacement = """  static Future<List<Employee>> _loadEmployees({
    required String? objectName,
    required bool includeFired,
  }) async {
    final response = await _client.rpc<dynamic>(
      'get_employee_rows_fast',
      params: <String, dynamic>{
        'p_object_name': objectName,
        'p_include_fired': includeFired,
      },
    );
    if (response is! List) return <Employee>[];

    return _employeesFromRows(response);
  }

  static List<Employee> _employeesFromRows"""

updated, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('employee loader anchor not found')

path.write_text(updated, encoding='utf-8')
