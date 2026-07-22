from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_required(text: str, old: str, new: str, *, path: Path) -> str:
    if old not in text:
        raise RuntimeError(f"{path}: missing expected fragment: {old[:100]!r}")
    return text.replace(old, new, 1)


def patch_employees() -> None:
    path = ROOT / "lib/screens/desktop_employees_view.dart"
    text = path.read_text(encoding="utf-8")

    text = replace_required(
        text,
        "color: mutedRow\n"
        "              ? const Color(0xFFEDEEEF)\n"
        "              : shaded\n"
        "              ? const Color(0xFFFAFAFA)\n"
        "              : Colors.white,",
        "color: mutedRow\n"
        "              ? AppAdaptivePalette.disabledSurface\n"
        "              : shaded\n"
        "              ? _surfaceElevated\n"
        "              : _surface,",
        path=path,
    )
    text = replace_required(
        text,
        "backgroundColor: mutedRow ? const Color(0xFFD9DADC) : _soft,",
        "backgroundColor: mutedRow\n"
        "                        ? AppAdaptivePalette.disabledSurface\n"
        "                        : _soft,",
        path=path,
    )
    text = replace_required(
        text,
        "background: active ? const Color(0xFFE8F5ED) : const Color(0xFFF7E8E7),",
        "background: active\n"
        "          ? (AppAdaptivePalette.isDark\n"
        "                ? _success.withValues(alpha: 0.16)\n"
        "                : const Color(0xFFE8F5ED))\n"
        "          : (AppAdaptivePalette.isDark\n"
        "                ? _danger.withValues(alpha: 0.16)\n"
        "                : const Color(0xFFF7E8E7)),",
        path=path,
    )
    text = replace_required(
        text,
        "child: DropdownButtonFormField<String>(\n"
        "        initialValue: value,",
        "child: DropdownButtonFormField<String>(\n"
        "        dropdownColor: _surfaceElevated,\n"
        "        initialValue: value,",
        path=path,
    )
    text = text.replace("const SizedBox(", "SizedBox(")
    path.write_text(text, encoding="utf-8")


def patch_tasks() -> None:
    path = ROOT / "lib/screens/desktop_tasks_screen.dart"
    text = path.read_text(encoding="utf-8")
    text = replace_required(
        text,
        "this.accent = _text,",
        "this.accent = AppAdaptivePalette.telegramBlue,",
        path=path,
    )
    text = text.replace("const SizedBox(", "SizedBox(")
    path.write_text(text, encoding="utf-8")


def patch_other_dynamic_widgets() -> None:
    for relative in (
        "lib/screens/adaptive_home_base_screen.dart",
        "lib/screens/desktop_home_widgets.dart",
    ):
        path = ROOT / relative
        text = path.read_text(encoding="utf-8")
        text = text.replace("const SizedBox(", "SizedBox(")
        path.write_text(text, encoding="utf-8")


def main() -> None:
    patch_employees()
    patch_tasks()
    patch_other_dynamic_widgets()


if __name__ == "__main__":
    main()
