from __future__ import annotations

import json
from pathlib import Path


def _replace_once(text: str, old: str, new: str, path: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"{path}: expected one occurrence of {old!r}, found {count}"
        )
    return text.replace(old, new, 1)


def write_desktop_patch_artifact(artifacts_dir: Path) -> None:
    replacements = {
        "lib/screens/adaptive_home_base_screen.dart": (
            "constraints: const BoxConstraints(maxWidth: 1240),",
            "constraints: const BoxConstraints(maxWidth: double.infinity),",
        ),
        "lib/screens/desktop_employees_view.dart": (
            "constraints: const BoxConstraints(maxWidth: 1400),",
            "constraints: const BoxConstraints(maxWidth: double.infinity),",
        ),
        "lib/screens/desktop_tasks_screen.dart": (
            "constraints: const BoxConstraints(maxWidth: 1400),",
            "constraints: const BoxConstraints(maxWidth: double.infinity),",
        ),
        "lib/screens/desktop_timesheet_screen.dart": (
            "constraints: const BoxConstraints(maxWidth: 1320),",
            "constraints: const BoxConstraints(maxWidth: double.infinity),",
        ),
        "lib/features/payments/presentation/screens/payments_screen.dart": (
            "constraints: const BoxConstraints(maxWidth: 1360),",
            "constraints: const BoxConstraints(maxWidth: double.infinity),",
        ),
        "lib/features/milestones/presentation/milestones_screen.dart": (
            "constraints: const BoxConstraints(maxWidth: 1060),",
            "constraints: const BoxConstraints(maxWidth: double.infinity),",
        ),
        "lib/features/milestones/presentation/milestone_detail_screen.dart": (
            "constraints: const BoxConstraints(maxWidth: 980),",
            "constraints: const BoxConstraints(maxWidth: double.infinity),",
        ),
    }

    root = Path.cwd()
    target_root = artifacts_dir / "desktop-patch"
    manifest: list[dict[str, str]] = []

    for relative_path, (old, new) in replacements.items():
        source = root / relative_path
        text = source.read_text(encoding="utf-8")
        patched = _replace_once(text, old, new, relative_path)
        target = target_root / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(patched, encoding="utf-8")
        manifest.append({"path": relative_path, "old": old, "new": new})

    (target_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
