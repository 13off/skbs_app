from pathlib import Path

path = Path('lib/features/recruitment/presentation/recruitment_applications_screen.dart')
text = path.read_text(encoding='utf-8')

old = """    return Transform.translate(
      offset: Offset(0, -lift),
      child: Container(
"""
new = """    return Padding(
      padding: EdgeInsets.only(bottom: lift),
      child: Container(
"""

if old not in text:
    raise SystemExit('Candidate editor Transform.translate block was not found')

text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('Candidate editor now uses layout padding instead of a visual transform')
