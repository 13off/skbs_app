from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, *, path: Path) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one occurrence, found {count}: {old[:80]!r}")
    return text.replace(old, new, 1)


def remove_dynamic_const_expressions(text: str) -> str:
    names = (
        "TextStyle",
        "Icon",
        "Padding",
        "Expanded",
        "Row",
        "Column",
        "BoxDecoration",
        "Border",
        "BorderSide",
        "CircleAvatar",
        "DropdownMenuItem",
        "_Badge",
        "_MessageCard",
    )
    for name in names:
        text = text.replace(f"const {name}(", f"{name}(")
    return text


def patch_home_base() -> None:
    path = ROOT / "lib/screens/adaptive_home_base_screen.dart"
    text = path.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "import '../data/app_data_sync.dart';",
        "import '../app/app_adaptive_palette.dart';\nimport '../data/app_data_sync.dart';",
        path=path,
    )
    text = replace_once(
        text,
        "const Color _desktopText = Color(0xFF1F2328);\n"
        "const Color _desktopMuted = Color(0xFF6B7075);\n"
        "const Color _desktopSuccess = Color(0xFF22C55E);",
        "Color get _desktopText => AppAdaptivePalette.textPrimary;\n"
        "Color get _desktopMuted => AppAdaptivePalette.textMuted;\n"
        "Color get _desktopSuccess => AppAdaptivePalette.success;",
        path=path,
    )
    text = text.replace(
        "color: selected\n"
        "                                  ? const Color(0xFFF2F3F5)\n"
        "                                  : Colors.white,",
        "color: selected\n"
        "                                  ? AppAdaptivePalette.selectedSurface\n"
        "                                  : AppAdaptivePalette.surfaceElevated,",
    )
    text = text.replace(
        "color: selected\n"
        "                                    ? _desktopText\n"
        "                                    : const Color(0xFFE6E8EB),",
        "color: selected\n"
        "                                    ? AppAdaptivePalette.accent\n"
        "                                    : AppAdaptivePalette.border,",
    )
    text = text.replace(
        "backgroundColor: _desktopText,\n"
        "              foregroundColor: Colors.white,",
        "backgroundColor: AppAdaptivePalette.accentStrong,\n"
        "              foregroundColor: AppAdaptivePalette.onAccent,",
    )
    text = remove_dynamic_const_expressions(text)
    path.write_text(text, encoding="utf-8")


def patch_home_widgets() -> None:
    path = ROOT / "lib/screens/desktop_home_widgets.dart"
    text = path.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "import '../models/task_item_data.dart';",
        "import '../app/app_adaptive_palette.dart';\nimport '../models/task_item_data.dart';",
        path=path,
    )
    text = replace_once(
        text,
        "const Color _text = Color(0xFF1F2328);\n"
        "const Color _muted = Color(0xFF6B7075);\n"
        "const Color _line = Color(0xFFE6E8EB);\n"
        "const Color _soft = Color(0xFFF2F3F5);\n"
        "const Color _success = Color(0xFF22C55E);",
        "Color get _text => AppAdaptivePalette.textPrimary;\n"
        "Color get _muted => AppAdaptivePalette.textMuted;\n"
        "Color get _line => AppAdaptivePalette.border;\n"
        "Color get _soft => AppAdaptivePalette.surfaceSoft;\n"
        "Color get _surface => AppAdaptivePalette.surface;\n"
        "Color get _surfaceElevated => AppAdaptivePalette.surfaceElevated;\n"
        "Color get _input => AppAdaptivePalette.inputSurface;\n"
        "Color get _success => AppAdaptivePalette.success;",
        path=path,
    )
    text = text.replace("color: Colors.white,\n                    borderRadius: BorderRadius.circular(22)", "color: _surfaceElevated,\n                    borderRadius: BorderRadius.circular(22)")
    text = text.replace("color: selected ? _soft : Colors.white,", "color: selected ? AppAdaptivePalette.selectedSurface : _surfaceElevated,")
    text = text.replace("color: selected ? _text : Colors.transparent,", "color: selected ? AppAdaptivePalette.accent : Colors.transparent,")
    text = text.replace("if (selected) const Icon(Icons.check_circle_rounded, size: 21)", "if (selected) Icon(Icons.check_circle_rounded, size: 21, color: AppAdaptivePalette.accent)")
    text = text.replace("color: Colors.white,\n            borderRadius: BorderRadius.circular(18)", "color: _input,\n            borderRadius: BorderRadius.circular(18)")
    text = remove_dynamic_const_expressions(text)
    path.write_text(text, encoding="utf-8")


def patch_employees() -> None:
    path = ROOT / "lib/screens/desktop_employees_view.dart"
    text = path.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "import '../models/app_user_profile.dart';",
        "import '../app/app_adaptive_palette.dart';\nimport '../models/app_user_profile.dart';",
        path=path,
    )
    text = replace_once(
        text,
        "const Color _text = Color(0xFF1F2328);\n"
        "const Color _muted = Color(0xFF6B7075);\n"
        "const Color _line = Color(0xFFE6E8EB);\n"
        "const Color _soft = Color(0xFFF2F3F5);\n"
        "const Color _success = Color(0xFF238A52);\n"
        "const Color _warning = Color(0xFF9A6A16);\n"
        "const Color _danger = Color(0xFF9D3E38);",
        "Color get _text => AppAdaptivePalette.textPrimary;\n"
        "Color get _muted => AppAdaptivePalette.textMuted;\n"
        "Color get _line => AppAdaptivePalette.border;\n"
        "Color get _soft => AppAdaptivePalette.surfaceSoft;\n"
        "Color get _surface => AppAdaptivePalette.surface;\n"
        "Color get _surfaceElevated => AppAdaptivePalette.surfaceElevated;\n"
        "Color get _input => AppAdaptivePalette.inputSurface;\n"
        "Color get _success => AppAdaptivePalette.success;\n"
        "Color get _warning => AppAdaptivePalette.warning;\n"
        "Color get _danger => AppAdaptivePalette.danger;",
        path=path,
    )
    text = text.replace("fillColor: _soft,", "fillColor: _input,")
    text = text.replace("fillColor: Colors.white,", "fillColor: _input,")
    text = text.replace(
        "color: mutedRow\n"
        "               ? const Color(0xFFEDEEEF)\n"
        "               : shaded\n"
        "                   ? const Color(0xFFFAFAFA)\n"
        "                   : Colors.white,",
        "color: mutedRow\n"
        "               ? AppAdaptivePalette.disabledSurface\n"
        "               : shaded\n"
        "                   ? _surfaceElevated\n"
        "                   : _surface,",
    )
    text = text.replace(
        "backgroundColor: mutedRow\n"
        "                         ? const Color(0xFFD9DADC)\n"
        "                         : _soft,",
        "backgroundColor: mutedRow\n"
        "                         ? AppAdaptivePalette.disabledSurface\n"
        "                         : _soft,",
    )
    text = text.replace("background: Color(0xFFE8F5ED),", "background: AppAdaptivePalette.isDark\n              ? _success.withValues(alpha: 0.16)\n              : const Color(0xFFE8F5ED),")
    text = text.replace("background: Color(0xFFFFF4DC),", "background: AppAdaptivePalette.isDark\n              ? _warning.withValues(alpha: 0.16)\n              : const Color(0xFFFFF4DC),")
    text = text.replace(
        "background: active\n"
        "           ? const Color(0xFFE8F5ED)\n"
        "           : const Color(0xFFF7E8E7),",
        "background: active\n"
        "           ? (AppAdaptivePalette.isDark\n"
        "                 ? _success.withValues(alpha: 0.16)\n"
        "                 : const Color(0xFFE8F5ED))\n"
        "           : (AppAdaptivePalette.isDark\n"
        "                 ? _danger.withValues(alpha: 0.16)\n"
        "                 : const Color(0xFFF7E8E7)),",
    )
    text = remove_dynamic_const_expressions(text)
    path.write_text(text, encoding="utf-8")


def patch_tasks() -> None:
    path = ROOT / "lib/screens/desktop_tasks_screen.dart"
    text = path.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "import '../data/app_data_sync.dart';",
        "import '../app/app_adaptive_palette.dart';\nimport '../data/app_data_sync.dart';",
        path=path,
    )
    text = replace_once(
        text,
        "const Color _text = Color(0xFF1F2328);\n"
        "const Color _muted = Color(0xFF6B7075);\n"
        "const Color _line = Color(0xFFE6E8EB);\n"
        "const Color _soft = Color(0xFFF2F3F5);\n"
        "const Color _success = Color(0xFF66766A);\n"
        "const Color _planned = Color(0xFF66717C);\n"
        "const Color _problem = Color(0xFF8A6259);",
        "Color get _text => AppAdaptivePalette.textPrimary;\n"
        "Color get _muted => AppAdaptivePalette.textMuted;\n"
        "Color get _line => AppAdaptivePalette.border;\n"
        "Color get _soft => AppAdaptivePalette.surfaceSoft;\n"
        "Color get _surface => AppAdaptivePalette.surface;\n"
        "Color get _surfaceElevated => AppAdaptivePalette.surfaceElevated;\n"
        "Color get _input => AppAdaptivePalette.inputSurface;\n"
        "Color get _success => AppAdaptivePalette.success;\n"
        "Color get _planned => AppAdaptivePalette.accent;\n"
        "Color get _problem => AppAdaptivePalette.warning;",
        path=path,
    )
    text = text.replace("fillColor: _soft,", "fillColor: _input,")
    text = text.replace(
        "child: DropdownButton<String?>(\n"
        "          value: selectedValue,",
        "child: DropdownButton<String?>(\n"
        "          dropdownColor: _surfaceElevated,\n"
        "          value: selectedValue,",
    )
    text = text.replace(
        "decoration: const BoxDecoration(\n"
        "          color: Colors.white,\n"
        "          border: Border(bottom: BorderSide(color: _line)),\n"
        "        ),",
        "decoration: BoxDecoration(\n"
        "          color: _surface,\n"
        "          border: Border(bottom: BorderSide(color: _line)),\n"
        "        ),",
    )
    text = remove_dynamic_const_expressions(text)
    path.write_text(text, encoding="utf-8")


def patch_palette() -> None:
    path = ROOT / "lib/app/app_adaptive_palette.dart"
    text = path.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "static const darkDisabledSurface = Color(0xFF1C2733);\n"
        "  static const darkDisabledText = Color(0xFF657383);",
        "static const darkDisabledSurface = Color(0xFF22303D);\n"
        "  static const darkDisabledText = Color(0xFF8DA1B4);",
        path=path,
    )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    patch_home_base()
    patch_home_widgets()
    patch_employees()
    patch_tasks()
    patch_palette()


if __name__ == "__main__":
    main()
