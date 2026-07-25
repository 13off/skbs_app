#!/usr/bin/env python3
"""One-time exact preservation of the proven nested back-navigation behavior."""

from __future__ import annotations

import re
from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    source = file.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    file.write_text(source.replace(old, new, 1), encoding="utf-8")


def replace_regex_once(
    path: str,
    pattern: str,
    replacement: str,
    label: str,
) -> None:
    file = Path(path)
    source = file.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.DOTALL)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    file.write_text(updated, encoding="utf-8")


def main() -> None:
    persistent = "lib/features/shell/presentation/persistent_tab_shell.dart"
    replace_once(
        persistent,
        "  bool _allowOuterPop = false;\n",
        "",
        "persistent outer-pop state",
    )
    replace_regex_once(
        persistent,
        r"    return PopScope<void>\(\n"
        r"      canPop: _allowOuterPop,\n"
        r"      onPopInvokedWithResult: \(didPop, _\) async \{\n"
        r".*?"
        r"      \},\n"
        r"      child: Scaffold\(",
        """    // Keep the established nested-navigation and root-route behavior.
    // Flutter 3.44 deprecates this API before the replacement is covered
    // by route-level integration tests in every target shell.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () => widget.controller.handleBack(
        returnToFirstTab: widget.returnToFirstTabOnBack,
      ),
      child: Scaffold(""",
        "persistent PopScope block",
    )

    premium = "lib/features/shell/presentation/premium_main_screen.dart"
    replace_once(
        premium,
        "  bool _allowOuterPop = false;\n",
        "",
        "premium outer-pop state",
    )
    replace_regex_once(
        premium,
        r"    return PopScope<void>\(\n"
        r"      canPop: _allowOuterPop,\n"
        r"      onPopInvokedWithResult: \(didPop, _\) async \{\n"
        r".*?"
        r"      \},\n"
        r"      child: Scaffold\(",
        """    // Keep the established nested-navigation and root-route behavior.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async => !(await handleBackRequest()),
      child: Scaffold(""",
        "premium PopScope block",
    )

    test = "test/specialist_role_preview_navigation_contract_test.dart"
    replace_regex_once(
        test,
        r"  expect\(shell, contains\('return PopScope<void>\('\)\);\n"
        r".*?"
        r"  expect\(shell, isNot\(contains\('WillPopScope\('\)\)\);",
        """  expect(shell, contains('return WillPopScope('));
  expect(shell, contains('widget.controller.handleBack('));
  expect(
    shell,
    contains('returnToFirstTab: widget.returnToFirstTabOnBack'),
  );
  expect(shell, isNot(contains('PopScope<void>(')));""",
        "navigation contract expectations",
    )

    Path(__file__).unlink()


if __name__ == "__main__":
    main()
