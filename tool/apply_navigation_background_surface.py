from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found in {path}: {old[:180]!r}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    """      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
""",
    """      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
""",
)

replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    """      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Listener(
""",
    """      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Listener(
""",
)

replace_once(
    "test/navigation_overlay_and_task_fab_contract_test.dart",
    """    expect(persistentShell, contains('backgroundColor: Colors.transparent'));
""",
    """    expect(
      mainShell,
      contains('backgroundColor: Theme.of(context).scaffoldBackgroundColor'),
    );
    expect(
      persistentShell,
      contains('backgroundColor: Theme.of(context).scaffoldBackgroundColor'),
    );
""",
)

replace_once(
    "test/bottom_controls_safety_test.dart",
    """      expect(persistentShell, contains('backgroundColor: Colors.transparent'));
""",
    """      expect(
        persistentShell,
        contains('backgroundColor: Theme.of(context).scaffoldBackgroundColor'),
      );
""",
)

replace_once(
    "test/timesheet_floating_controls_contract_test.dart",
    """    expect(shell, contains('backgroundColor: Colors.transparent'));
""",
    """    expect(
      shell,
      contains('backgroundColor: Theme.of(context).scaffoldBackgroundColor'),
    );
""",
)

replace_once(
    "test/global_bottom_navigation_clearance_contract_test.dart",
    """      expect(shell, isNot(contains('content-clearance')));
""",
    """      expect(shell, isNot(contains('content-clearance')));
      expect(
        shell,
        contains('backgroundColor: Theme.of(context).scaffoldBackgroundColor'),
      );
""",
)
