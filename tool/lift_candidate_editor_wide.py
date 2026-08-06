from pathlib import Path

path = Path('lib/features/recruitment/presentation/recruitment_applications_screen.dart')
text = path.read_text(encoding='utf-8')
old = """    final bottomClearance = keyboardInset > 0
        ? AppUi.gap12
        : AppUi.navigationTotalHeight(context) + AppUi.gap12;
"""
new = """    final isWideScreen =
        mediaSize.width >= AppUi.specialistDesktopBreakpoint;
    final bottomClearance = keyboardInset > 0
        ? AppUi.gap12
        : AppUi.navigationTotalHeight(context) +
              (isWideScreen ? 120 : AppUi.gap12);
"""
if new in text:
    raise SystemExit('Candidate editor is already lifted on wide screens')
count = text.count(old)
if count != 1:
    raise SystemExit(f'Expected one bottom clearance block, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Lifted candidate editor on wide screens')
