from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'lib'


def replace_once(path: Path, old: str, new: str):
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'Pattern not found in {path}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')

# Task repository: fetch attribution in parallel with task rows, so visible latency
# stays one network round-trip instead of N profile/audit lookups.
path = LIB / 'data/task_repository.dart'
text = path.read_text(encoding='utf-8')
text = text.replace("import '../models/task_item_data.dart';", "import '../models/responsibility_actor.dart';\nimport '../models/task_item_data.dart';", 1)
old = '''    final response = await _client.rpc<dynamic>(\n      'get_task_rows_fast',\n      params: <String, dynamic>{\n        'p_task_date': _dateKey(date),\n        'p_object_name': cleanObject,\n      },\n    );\n    if (response is! List) return <TaskItemData>[];\n\n    final tasks = response\n        .whereType<Map>()\n        .map<TaskItemData>(\n          (row) => TaskItemData.fromSupabase(Map<String, dynamic>.from(row)),\n        )\n        .toList(growable: false);'''
new = '''    final params = <String, dynamic>{\n      'p_task_date': _dateKey(date),\n      'p_object_name': cleanObject,\n    };\n    final responses = await Future.wait<dynamic>([\n      _client.rpc<dynamic>('get_task_rows_fast', params: params),\n      _client.rpc<dynamic>('get_task_responsibility_fast', params: params),\n    ]);\n    final response = responses[0];\n    if (response is! List) return <TaskItemData>[];\n\n    final responsibilityByTaskId = <String, Map<String, dynamic>>{};\n    final responsibilityResponse = responses[1];\n    if (responsibilityResponse is List) {\n      for (final raw in responsibilityResponse.whereType<Map>()) {\n        final row = Map<String, dynamic>.from(raw);\n        final taskId = row['task_id']?.toString();\n        if (taskId != null && taskId.isNotEmpty) {\n          responsibilityByTaskId[taskId] = row;\n        }\n      }\n    }\n\n    final tasks = response.whereType<Map>().map<TaskItemData>((raw) {\n      final row = Map<String, dynamic>.from(raw);\n      final task = TaskItemData.fromSupabase(row);\n      final responsibility = responsibilityByTaskId[task.id];\n      if (responsibility == null) return task;\n\n      final creator = ResponsibilityActor.fromMap(\n        responsibility,\n        userIdKey: 'creator_user_id',\n        fullNameKey: 'creator_full_name',\n        avatarPathKey: 'creator_avatar_path',\n        actedAtKey: 'created_at',\n      );\n      final lastEditorUserId = ResponsibilityActor.cleanText(\n        responsibility['last_editor_user_id'],\n      );\n      final lastEditor = lastEditorUserId == null\n          ? null\n          : ResponsibilityActor.fromMap(\n              responsibility,\n              userIdKey: 'last_editor_user_id',\n              fullNameKey: 'last_editor_full_name',\n              avatarPathKey: 'last_editor_avatar_path',\n              actedAtKey: 'last_edited_at',\n            );\n      return task.copyWith(creator: creator, lastEditor: lastEditor);\n    }).toList(growable: false);'''
if old not in text:
    raise RuntimeError('TaskRepository fetch block not found')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')

# Attendance repository: one cached responsibility map per date/object.
path = LIB / 'data/attendance_repository.dart'
text = path.read_text(encoding='utf-8')
text = text.replace("import '../models/period_timesheet_row.dart';", "import '../models/period_timesheet_row.dart';\nimport '../models/responsibility_actor.dart';", 1)
text = text.replace(
'''  static final Map<String, Future<Map<String, double>>> _shiftValueRequests =\n      {};''',
'''  static final Map<String, Future<Map<String, double>>> _shiftValueRequests =\n      {};\n  static final Map<String, _ResponsibilityCacheEntry> _responsibilityCache = {};\n  static final Map<String, Future<Map<String, ResponsibilityActor>>>\n  _responsibilityRequests = {};''', 1)
text = text.replace(
'''    _shiftValuesCache.clear();\n    _monthlyTimesheetCache.clear();''',
'''    _shiftValuesCache.clear();\n    _responsibilityCache.clear();\n    _monthlyTimesheetCache.clear();''', 1)
text = text.replace(
'''    _shiftValueRequests.clear();\n    _attendanceReportRequests.clear();''',
'''    _shiftValueRequests.clear();\n    _responsibilityRequests.clear();\n    _attendanceReportRequests.clear();''', 1)
anchor = '''  static Future<Set<String>> fetchWorkedEmployeeIds(\n    DateTime date, {'''
method = '''  static Future<Map<String, ResponsibilityActor>>\n  fetchResponsibilityForDate(\n    DateTime date, {\n    String? objectName,\n    bool forceRefresh = false,\n  }) async {\n    final key = _dayCacheKey(date: date, objectName: objectName);\n    final running = _responsibilityRequests[key];\n    if (running != null) return Map<String, ResponsibilityActor>.from(await running);\n\n    final cached = _responsibilityCache[key];\n    if (!forceRefresh &&\n        cached != null &&\n        _isFresh(cached.createdAt, _shortCacheTtl)) {\n      return Map<String, ResponsibilityActor>.from(cached.values);\n    }\n\n    final request = _fetchResponsibilityForDate(\n      date,\n      objectName: objectName,\n    );\n    _responsibilityRequests[key] = request;\n    try {\n      final result = await request;\n      _responsibilityCache[key] = _ResponsibilityCacheEntry(\n        values: Map<String, ResponsibilityActor>.from(result),\n        createdAt: DateTime.now(),\n      );\n      return Map<String, ResponsibilityActor>.from(result);\n    } finally {\n      if (identical(_responsibilityRequests[key], request)) {\n        _responsibilityRequests.remove(key);\n      }\n    }\n  }\n\n  static Future<Map<String, ResponsibilityActor>> _fetchResponsibilityForDate(\n    DateTime date, {\n    String? objectName,\n  }) async {\n    final response = await _client.rpc<dynamic>(\n      'get_attendance_responsibility_fast',\n      params: <String, dynamic>{\n        'p_work_date': dateKey(date),\n        'p_object_name': cleanObjectName(objectName),\n      },\n    );\n    final result = <String, ResponsibilityActor>{};\n    if (response is! List) return result;\n    for (final raw in response.whereType<Map>()) {\n      final row = Map<String, dynamic>.from(raw);\n      final employeeId = row['employee_id']?.toString();\n      if (employeeId == null || employeeId.isEmpty) continue;\n      result[employeeId] = ResponsibilityActor.fromMap(\n        row,\n        userIdKey: 'actor_user_id',\n        fullNameKey: 'actor_full_name',\n        avatarPathKey: 'actor_avatar_path',\n        actedAtKey: 'acted_at',\n      );\n    }\n    return result;\n  }\n\n'''
if anchor not in text:
    raise RuntimeError('Attendance responsibility anchor missing')
text = text.replace(anchor, method + anchor, 1)
# append cache class before final existing helper class marker or EOF safely
text += '''\n\nclass _ResponsibilityCacheEntry {\n  final Map<String, ResponsibilityActor> values;\n  final DateTime createdAt;\n\n  const _ResponsibilityCacheEntry({\n    required this.values,\n    required this.createdAt,\n  });\n}\n'''
path.write_text(text, encoding='utf-8')

# Task card attribution.
path = LIB / 'widgets/task_tile.dart'
text = path.read_text(encoding='utf-8')
text = text.replace("import 'premium_ui_v2.dart';", "import 'premium_ui_v2.dart';\nimport 'responsibility_actor_line.dart';", 1)
needle = '''                    Container(\n                      padding: const EdgeInsets.symmetric(\n                        horizontal: 10,\n                        vertical: 7,\n                      ),'''
# Insert attribution immediately before status pill.
insert = '''                    if (task.creator != null) ...[\n                      ResponsibilityActorLine(\n                        label: 'Создал',\n                        actor: task.creator!,\n                        compact: true,\n                      ),\n                      const SizedBox(height: 7),\n                    ],\n                    if (task.lastEditor != null) ...[\n                      ResponsibilityActorLine(\n                        label: 'Изменил',\n                        actor: task.lastEditor!,\n                        compact: true,\n                      ),\n                      const SizedBox(height: 9),\n                    ],\n'''
if needle not in text:
    raise RuntimeError('TaskTile status anchor not found')
text = text.replace(needle, insert + needle, 1)
path.write_text(text, encoding='utf-8')

# Mobile timesheet state/imports/loading/UI.
path = LIB / 'screens/timesheet_screen.dart'
text = path.read_text(encoding='utf-8')
text = text.replace("import '../models/employee.dart';", "import '../models/employee.dart';\nimport '../models/responsibility_actor.dart';", 1)
text = text.replace("import '../widgets/premium_ui.dart';", "import '../widgets/premium_ui.dart';\nimport '../widgets/responsibility_actor_line.dart';", 1)
text = text.replace(
'''  TimesheetDraft timesheetDraft = TimesheetDraft.empty();\n  List<TimesheetGroup> timesheetGroups = const <TimesheetGroup>[];''',
'''  TimesheetDraft timesheetDraft = TimesheetDraft.empty();\n  Map<String, ResponsibilityActor> attendanceResponsibility =\n      const <String, ResponsibilityActor>{};\n  List<TimesheetGroup> timesheetGroups = const <TimesheetGroup>[];''', 1)
path.write_text(text, encoding='utf-8')

path = LIB / 'screens/timesheet/timesheet_loading.dart'
text = path.read_text(encoding='utf-8')
old = '''      final values = await AttendanceRepository.fetchShiftValuesForDate(\n        requestedDate,\n        objectName: requestedObject,\n        forceRefresh: forceRefresh,\n      );\n\n      if (!mounted || generation != attendanceLoadGeneration) return;\n      setState(() {\n        timesheetDraft = TimesheetDraft.fromValues(values);\n      });'''
new = '''      final results = await Future.wait<dynamic>([\n        AttendanceRepository.fetchShiftValuesForDate(\n          requestedDate,\n          objectName: requestedObject,\n          forceRefresh: forceRefresh,\n        ),\n        AttendanceRepository.fetchResponsibilityForDate(\n          requestedDate,\n          objectName: requestedObject,\n          forceRefresh: forceRefresh,\n        ),\n      ]);\n      final values = results[0] as Map<String, double>;\n      final responsibility =\n          results[1] as Map<String, ResponsibilityActor>;\n\n      if (!mounted || generation != attendanceLoadGeneration) return;\n      setState(() {\n        timesheetDraft = TimesheetDraft.fromValues(values);\n        attendanceResponsibility = responsibility;\n      });'''
if old not in text:
    raise RuntimeError('mobile attendance load block missing')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')

path = LIB / 'screens/timesheet/timesheet_sections.dart'
text = path.read_text(encoding='utf-8')
old = '''                    Text(\n                      employee.position,\n                      style: TextStyle(\n                        color: AppAdaptivePalette.textMuted,\n                        fontSize: 13,\n                        fontWeight: FontWeight.w600,\n                      ),\n                    ),'''
new = '''                    Text(\n                      employee.position,\n                      style: TextStyle(\n                        color: AppAdaptivePalette.textMuted,\n                        fontSize: 13,\n                        fontWeight: FontWeight.w600,\n                      ),\n                    ),\n                    if (employee.id != null &&\n                        attendanceResponsibility[employee.id!] != null) ...[\n                      const SizedBox(height: 7),\n                      ResponsibilityActorLine(\n                        label: 'Последнее изменение',\n                        actor: attendanceResponsibility[employee.id!]!,\n                        compact: true,\n                      ),\n                    ],'''
if old not in text:
    raise RuntimeError('mobile employee position block missing')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')

path = LIB / 'screens/timesheet/timesheet_actions.dart'
text = path.read_text(encoding='utf-8')
old = '''      if (!mounted) return;\n      setState(() => timesheetDraft = timesheetDraft.markSaved());\n\n      final workedCount = workedCountFor(allEmployees);'''
new = '''      if (!mounted) return;\n      setState(() => timesheetDraft = timesheetDraft.markSaved());\n      final responsibility =\n          await AttendanceRepository.fetchResponsibilityForDate(\n            selectedDate,\n            objectName: widget.selectedObjectName,\n            forceRefresh: true,\n          );\n      if (!mounted) return;\n      setState(() => attendanceResponsibility = responsibility);\n\n      final workedCount = workedCountFor(allEmployees);'''
if old not in text:
    raise RuntimeError('mobile save block missing')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')

# Desktop timesheet attribution, loaded in parallel.
path = LIB / 'screens/desktop_timesheet_screen.dart'
text = path.read_text(encoding='utf-8')
text = text.replace("import '../models/employee.dart';", "import '../models/employee.dart';\nimport '../models/responsibility_actor.dart';", 1)
text = text.replace("import '../widgets/premium_ui.dart';", "import '../widgets/premium_ui.dart';\nimport '../widgets/responsibility_actor_line.dart';", 1)
text = text.replace(
'''  Map<String, double> shiftValuesByEmployeeId = <String, double>{};\n  Map<String, double> originalShiftValuesByEmployeeId = <String, double>{};''',
'''  Map<String, double> shiftValuesByEmployeeId = <String, double>{};\n  Map<String, double> originalShiftValuesByEmployeeId = <String, double>{};\n  Map<String, ResponsibilityActor> attendanceResponsibility =\n      const <String, ResponsibilityActor>{};''', 1)
old = '''        AttendanceRepository.fetchShiftValuesForDate(\n          requestedDate,\n          objectName: requestedObject,\n          forceRefresh: forceRefresh,\n        ),\n        groupFuture,\n      ]);'''
new = '''        AttendanceRepository.fetchShiftValuesForDate(\n          requestedDate,\n          objectName: requestedObject,\n          forceRefresh: forceRefresh,\n        ),\n        groupFuture,\n        AttendanceRepository.fetchResponsibilityForDate(\n          requestedDate,\n          objectName: requestedObject,\n          forceRefresh: forceRefresh,\n        ),\n      ]);'''
if old not in text:
    raise RuntimeError('desktop Future.wait block missing')
text = text.replace(old, new, 1)
text = text.replace(
'''      final loadedGroups = results[2] as List<TimesheetGroup>;''',
'''      final loadedGroups = results[2] as List<TimesheetGroup>;\n      final loadedResponsibility =\n          results[3] as Map<String, ResponsibilityActor>;''', 1)
text = text.replace(
'''        originalShiftValuesByEmployeeId = Map<String, double>.from(\n          loadedValues,\n        );\n        hasUnsavedChanges = false;''',
'''        originalShiftValuesByEmployeeId = Map<String, double>.from(\n          loadedValues,\n        );\n        attendanceResponsibility = loadedResponsibility;\n        hasUnsavedChanges = false;''', 1)
old = '''                Expanded(\n                  child: Text(\n                    employee.name,\n                    maxLines: 2,\n                    overflow: TextOverflow.ellipsis,\n                    style: TextStyle(color: _text, fontWeight: FontWeight.w900),\n                  ),\n                ),'''
new = '''                Expanded(\n                  child: Column(\n                    crossAxisAlignment: CrossAxisAlignment.start,\n                    children: [\n                      Text(\n                        employee.name,\n                        maxLines: 2,\n                        overflow: TextOverflow.ellipsis,\n                        style: TextStyle(\n                          color: _text,\n                          fontWeight: FontWeight.w900,\n                        ),\n                      ),\n                      if (employee.id != null &&\n                          attendanceResponsibility[employee.id!] != null) ...[\n                        const SizedBox(height: 5),\n                        ResponsibilityActorLine(\n                          label: 'Изменил',\n                          actor: attendanceResponsibility[employee.id!]!,\n                          compact: true,\n                        ),\n                      ],\n                    ],\n                  ),\n                ),'''
if old not in text:
    raise RuntimeError('desktop employee name cell missing')
text = text.replace(old, new, 1)
old = '''      setState(() {\n        originalShiftValuesByEmployeeId = Map<String, double>.from(\n          shiftValuesByEmployeeId,\n        );\n        hasUnsavedChanges = false;\n      });\n\n      final worked = employees.where((employee) => shiftValueFor(employee) > 0);'''
new = '''      setState(() {\n        originalShiftValuesByEmployeeId = Map<String, double>.from(\n          shiftValuesByEmployeeId,\n        );\n        hasUnsavedChanges = false;\n      });\n      final responsibility =\n          await AttendanceRepository.fetchResponsibilityForDate(\n            selectedDate,\n            objectName: widget.selectedObjectName,\n            forceRefresh: true,\n          );\n      if (!mounted) return;\n      setState(() => attendanceResponsibility = responsibility);\n\n      final worked = employees.where((employee) => shiftValueFor(employee) > 0);'''
if old not in text:
    raise RuntimeError('desktop save block missing')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')

# Fix SQL null semantics for tasks that have never been edited.
path = ROOT / 'supabase/migrations/20260822094500_task_timesheet_responsibility.sql'
text = path.read_text(encoding='utf-8')
text = text.replace(
"    coalesce(nullif(btrim(editor.full_name), ''), 'Неизвестно') as last_editor_full_name,",
"    case when latest.actor_user_id is null then null else coalesce(nullif(btrim(editor.full_name), ''), 'Неизвестно') end as last_editor_full_name,",
1,
)
path.write_text(text, encoding='utf-8')

# Regression contract for attribution visibility/data path.
test = ROOT / 'test/responsibility_attribution_test.dart'
test.write_text('''import 'dart:io';\n\nimport 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  test('task list loads responsibility in parallel', () {\n    final source = File('lib/data/task_repository.dart').readAsStringSync();\n    expect(source, contains('get_task_responsibility_fast'));\n    expect(source, contains('Future.wait<dynamic>'));\n    expect(source, contains('creator: creator'));\n    expect(source, contains('lastEditor: lastEditor'));\n  });\n\n  test('timesheet exposes latest editor on mobile and desktop', () {\n    final mobile = File('lib/screens/timesheet/timesheet_sections.dart').readAsStringSync();\n    final desktop = File('lib/screens/desktop_timesheet_screen.dart').readAsStringSync();\n    expect(mobile, contains("label: 'Последнее изменение'"));\n    expect(desktop, contains("label: 'Изменил'"));\n    expect(mobile, contains('ResponsibilityActorLine'));\n    expect(desktop, contains('ResponsibilityActorLine'));\n  });\n\n  test('responsibility RPCs are authenticated-only and reuse visibility RPCs', () {\n    final sql = File(\n      'supabase/migrations/20260822094500_task_timesheet_responsibility.sql',\n    ).readAsStringSync();\n    expect(sql, contains('get_task_responsibility_fast'));\n    expect(sql, contains('get_attendance_responsibility_fast'));\n    expect(sql, contains('from public.get_task_rows_fast'));\n    expect(sql, contains('from public.get_attendance_rows_fast'));\n    expect(sql, contains('grant execute'));\n    expect(sql, contains('to authenticated'));\n  });\n}\n''', encoding='utf-8')

print('Responsibility feature patched successfully')
