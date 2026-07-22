from pathlib import Path

path = Path('lib/features/developer/presentation/role_permission_matrix_screen.dart')
text = path.read_text(encoding='utf-8')
old = """      actions: [
        IconButton(
          tooltip: 'Обновить',
          onPressed: loading || busyKey != null ? null : load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
"""
new = """      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading || busyKey != null ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
"""
if old not in text:
    raise SystemExit('expected AppPage actions block not found')
path.write_text(text.replace(old, new), encoding='utf-8')
