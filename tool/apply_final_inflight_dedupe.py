from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 occurrence, found {count}')
    file_path.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/data/task_repository.dart',
    '''    if (!forceRefresh) {
      final running = _taskRequests[cacheKey];
      if (running != null) return _copyTasks(await running);
    }
''',
    '''    final running = _taskRequests[cacheKey];
    if (running != null) return _copyTasks(await running);
''',
    'task in-flight dedupe',
)

replace_once(
    'lib/data/notification_repository.dart',
    '''    if (!forceRefresh) {
      final pending = _unreadInFlight[key];
      if (pending != null) return pending;
    }
''',
    '''    final pending = _unreadInFlight[key];
    if (pending != null) return pending;
''',
    'unread in-flight dedupe',
)
