from pathlib import Path

path = Path('lib/features/recruitment/presentation/recruitment_applications_screen.dart')
text = path.read_text(encoding='utf-8')

old = """  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isWideScreen = mediaSize.width >= AppUi.specialistDesktopBreakpoint;
    final bottomClearance = keyboardInset > 0
        ? AppUi.gap12
        : AppUi.navigationTotalHeight(context) +
              (isWideScreen ? 120 : AppUi.gap12);
    final availableHeight =
        mediaSize.height - bottomClearance - (AppUi.gap12 * 2);

    return Container(
"""

new = """  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final lift = keyboardInset > 0 ? 0.0 : 112.0;
    final bottomClearance = keyboardInset > 0
        ? AppUi.gap12
        : AppUi.navigationTotalHeight(context) + AppUi.gap12;
    final availableHeight =
        mediaSize.height - bottomClearance - lift - (AppUi.gap12 * 2);

    return Transform.translate(
      offset: Offset(0, -lift),
      child: Container(
"""

if old not in text:
    raise SystemExit('Candidate editor build block not found')
text = text.replace(old, new, 1)

old_tail = """        ],
      ),
    );
  }
}

IconData _customFieldIcon"""
new_tail = """        ],
      ),
      ),
    );
  }
}

IconData _customFieldIcon"""

if old_tail not in text:
    raise SystemExit('Candidate editor closing block not found')
text = text.replace(old_tail, new_tail, 1)
path.write_text(text, encoding='utf-8')
print('Candidate editor hard lift applied')
