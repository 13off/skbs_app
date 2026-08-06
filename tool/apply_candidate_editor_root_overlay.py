from pathlib import Path

path = Path(
    'lib/features/recruitment/presentation/'
    'recruitment_applications_screen.dart'
)
text = path.read_text(encoding='utf-8')

old = """    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
"""
new = """    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
"""

if 'useRootNavigator: true' in text:
    print('Candidate editor already uses the root navigator')
    raise SystemExit(0)

count = text.count(old)
if count != 1:
    raise SystemExit(f'Expected one candidate editor modal block, found {count}')

path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Candidate editor moved to root navigator overlay')
