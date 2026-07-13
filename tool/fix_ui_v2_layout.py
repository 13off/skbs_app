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
text = text.replace("width: isDesktop ? 36 : 34,", "width: isDesktop ? 36 : 31,")
text = text.replace("height: isDesktop ? 36 : 34,", "height: isDesktop ? 36 : 30,")
text = text.replace("size: isDesktop ? 20 : 19,", "size: isDesktop ? 20 : 18,")
text = text.replace(
    "fontSize: isDesktop ? 13 : 10.5,",
    "fontSize: isDesktop ? 13 : 10.0,",
)
text = text.replace("const SizedBox(height: 2),", "const SizedBox(height: 1),")
text = text.replace("expect(panelHeight, 68);", "expect(panelHeight, 72);")
text = text.replace(
    "body: const ColoredBox(\n"
    "          key: ValueKey('screen-body'),\n"
    "          color: Colors.white,\n"
    "        ),",
    "body: const ColoredBox(\n"
    "          key: ValueKey('screen-body'),\n"
    "          color: Colors.white,\n"
    "          child: SizedBox.expand(),\n"
    "        ),",
)

script_path.write_text(text, encoding='utf-8')
