from pathlib import Path

root = Path(__file__).resolve().parents[1]
script_path = root / 'tool/apply_unified_ui_v2.py'
text = script_path.read_text(encoding='utf-8')

text = text.replace(
    "final panelHeight = isDesktop ? 72.0 : 68.0;",
    "final panelHeight = isDesktop ? 72.0 : 72.0;",
)
text = text.replace(
    "vertical: 6,\n                            ),",
    "vertical: isDesktop ? 6 : 2,\n                            ),",
)
text = text.replace("expect(panelHeight, 68);", "expect(panelHeight, 72);")

script_path.write_text(text, encoding='utf-8')
