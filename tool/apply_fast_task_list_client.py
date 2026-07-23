from pathlib import Path
import re

path = Path('lib/data/task_repository.dart')
text = path.read_text(encoding='utf-8')

pattern = re.compile(
    r"    final rows = cleanObject == null.*?"
    r"    final tasks = rows\n"
    r"        \.map<TaskItemData>\(\(row\) => TaskItemData\.fromSupabase\(row\)\)\n"
    r"        \.toList\(\);",
    re.DOTALL,
)

replacement = """    final response = await _client.rpc<dynamic>(
      'get_task_rows_fast',
      params: <String, dynamic>{
        'p_task_date': _dateKey(date),
        'p_object_name': cleanObject,
      },
    );
    if (response is! List) return <TaskItemData>[];

    final tasks = response
        .whereType<Map>()
        .map<TaskItemData>(
          (row) => TaskItemData.fromSupabase(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);"""

updated, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('task list loader anchor not found')

path.write_text(updated, encoding='utf-8')
