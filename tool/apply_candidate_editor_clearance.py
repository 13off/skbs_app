from pathlib import Path

path = Path(
    'lib/features/recruitment/presentation/'
    'recruitment_applications_screen.dart'
)
text = path.read_text(encoding='utf-8')

marker = 'AppUi.navigationTotalHeight(context) + AppUi.gap12'
if marker in text:
    print('Candidate editor clearance is already applied')
    raise SystemExit(0)

old = """  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
"""

new = """  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomClearance = keyboardInset > 0
        ? AppUi.gap12
        : AppUi.navigationTotalHeight(context) + AppUi.gap12;
    final availableHeight =
        mediaSize.height - bottomClearance - (AppUi.gap12 * 2);

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppUi.gap12,
        AppUi.gap12,
        AppUi.gap12,
        bottomClearance,
      ),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + keyboardInset),
      constraints: BoxConstraints(maxHeight: availableHeight),
"""

count = text.count(old)
if count != 1:
    raise SystemExit(f'Expected one candidate editor block, found {count}')

path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Candidate editor clearance applied')
