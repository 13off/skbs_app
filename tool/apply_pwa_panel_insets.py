from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding='utf-8')


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f'{path}: expected exactly one match, got {count}: {old!r}'
        )
    write(path, text.replace(old, new, 1))


def add_import(path: str, anchor: str, import_line: str) -> None:
    text = read(path)
    if import_line in text:
        return
    if anchor not in text:
        raise SystemExit(f'{path}: missing import anchor: {anchor!r}')
    write(path, text.replace(anchor, anchor + import_line, 1))


main_path = 'lib/main.dart'
main = read(main_path)
main = main.replace("import 'widgets/pwa_desktop_page_frame.dart';\n", '')
old_builder = """          builder: (context, child) => PwaDesktopPageFrame(
            child: AppScaleViewport(
              scale: themeController.uiScale,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
"""
new_builder = """          builder: (context, child) => AppScaleViewport(
            scale: themeController.uiScale,
            child: child ?? const SizedBox.shrink(),
          ),
"""
if main.count(old_builder) != 1:
    raise SystemExit('lib/main.dart: global PWA page frame block not found')
write(main_path, main.replace(old_builder, new_builder, 1))

page_path = 'lib/widgets/app_page.dart'
page = read(page_path)
page = page.replace("import 'pwa_desktop_page_frame.dart';\n", '')
old_padding = """    final horizontalPadding = isDesktop
        ? PwaDesktopPageFrame.isApplied(context)
              ? 0.0
              : AppUi.pageDesktopHorizontalPadding
        : AppUi.pageMobileHorizontalPadding;
"""
new_padding = """    final horizontalPadding = isDesktop
        ? AppUi.pageDesktopHorizontalPadding
        : AppUi.pageMobileHorizontalPadding;
"""
if page.count(old_padding) != 2:
    raise SystemExit(
        'lib/widgets/app_page.dart: expected two framed padding blocks, '
        f'got {page.count(old_padding)}'
    )
write(page_path, page.replace(old_padding, new_padding))

tokens_path = 'lib/app/app_ui_tokens.dart'
tokens = read(tokens_path).replace(
    '// Shared PWA desktop outer margin: four times the previous 36 px value.',
    '// Shared wide-PWA inset for panels, cards, filters and page actions.',
)
write(tokens_path, tokens)

custom_desktop_files = {
    'lib/screens/adaptive_home_base_screen.dart': (
        "import '../app/app_adaptive_palette.dart';\n",
        "import '../app/app_ui_tokens.dart';\n",
        'padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),',
        """padding: const EdgeInsets.fromLTRB(
          AppUi.pageDesktopHorizontalPadding,
          AppUi.pageDesktopTopPadding,
          AppUi.pageDesktopHorizontalPadding,
          120,
        ),""",
    ),
    'lib/screens/desktop_employees_view.dart': (
        "import '../app/app_adaptive_palette.dart';\n",
        "import '../app/app_ui_tokens.dart';\n",
        'padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),',
        """padding: const EdgeInsets.fromLTRB(
                AppUi.pageDesktopHorizontalPadding,
                AppUi.pageDesktopTopPadding,
                AppUi.pageDesktopHorizontalPadding,
                120,
              ),""",
    ),
    'lib/screens/desktop_tasks_screen.dart': (
        "import '../app/app_adaptive_palette.dart';\n",
        "import '../app/app_ui_tokens.dart';\n",
        'padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),',
        """padding: const EdgeInsets.fromLTRB(
              AppUi.pageDesktopHorizontalPadding,
              AppUi.pageDesktopTopPadding,
              AppUi.pageDesktopHorizontalPadding,
              120,
            ),""",
    ),
}

for path, (anchor, import_line, old, new) in custom_desktop_files.items():
    add_import(path, anchor, import_line)
    replace_once(path, old, new)

replace_once(
    'lib/screens/desktop_timesheet_screen.dart',
    'padding: const EdgeInsets.fromLTRB(28, 24, 28, 230),',
    """padding: const EdgeInsets.fromLTRB(
                  AppUi.pageDesktopHorizontalPadding,
                  AppUi.pageDesktopTopPadding,
                  AppUi.pageDesktopHorizontalPadding,
                  230,
                ),""",
)

payments_path = 'lib/features/payments/presentation/screens/payments_screen.dart'
add_import(
    payments_path,
    "import '../../../../app/app_adaptive_palette.dart';\n",
    "import '../../../../app/app_ui_tokens.dart';\n",
)
replace_once(
    payments_path,
    'padding: const EdgeInsets.fromLTRB(28, 22, 0, 132),',
    """padding: const EdgeInsets.fromLTRB(
                    AppUi.pageDesktopHorizontalPadding,
                    22,
                    0,
                    132,
                  ),""",
)
replace_once(
    payments_path,
    'padding: const EdgeInsets.fromLTRB(0, 22, 28, 132),',
    """padding: const EdgeInsets.fromLTRB(
                  0,
                  22,
                  AppUi.pageDesktopHorizontalPadding,
                  132,
                ),""",
)

milestones_path = 'lib/features/milestones/presentation/milestones_screen.dart'
add_import(
    milestones_path,
    "import 'package:skbs_app/app/app_adaptive_palette.dart';\n",
    "import 'package:skbs_app/app/app_ui_tokens.dart';\n",
)
replace_once(
    milestones_path,
    '  Widget build(BuildContext context) {\n    return Scaffold(',
    """  Widget build(BuildContext context) {
    final horizontalPadding =
        MediaQuery.sizeOf(context).width >= AppUi.desktopBreakpoint
        ? AppUi.pageDesktopHorizontalPadding
        : 18.0;

    return Scaffold(""",
)
replace_once(
    milestones_path,
    'padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),',
    """padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      120,
                    ),""",
)

milestone_detail_path = (
    'lib/features/milestones/presentation/milestone_detail_screen.dart'
)
add_import(
    milestone_detail_path,
    "import 'package:skbs_app/app/app_adaptive_palette.dart';\n",
    "import 'package:skbs_app/app/app_ui_tokens.dart';\n",
)
replace_once(
    milestone_detail_path,
    """  Widget build(BuildContext context) {
    return FutureBuilder<ProjectMilestone>(""",
    """  Widget build(BuildContext context) {
    final horizontalPadding =
        MediaQuery.sizeOf(context).width >= AppUi.desktopBreakpoint
        ? AppUi.pageDesktopHorizontalPadding
        : 18.0;

    return FutureBuilder<ProjectMilestone>(""",
)
replace_once(
    milestone_detail_path,
    'padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),',
    """padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      120,
                    ),""",
)

test_path = 'test/global_ui_scale_contract_test.dart'
replace_once(
    test_path,
    "    expect(main, contains('builder: (context, child) => PwaDesktopPageFrame('));",
    """    expect(main, contains('builder: (context, child) => AppScaleViewport('));
    expect(main, isNot(contains('PwaDesktopPageFrame(')));""",
)

contract = Path('test/pwa_panel_insets_contract_test.dart')
contract.write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('wide PWA keeps the page background full width and insets panels', () {
    final main = source('lib/main.dart');
    final page = source('lib/widgets/app_page.dart');
    final tokens = source('lib/app/app_ui_tokens.dart');

    expect(main, contains('builder: (context, child) => AppScaleViewport('));
    expect(main, isNot(contains('PwaDesktopPageFrame(')));
    expect(page, isNot(contains('PwaDesktopPageFrame.isApplied')));
    expect(page, contains('? AppUi.pageDesktopHorizontalPadding'));
    expect(tokens, contains('pageDesktopHorizontalPadding = 144'));
    expect(tokens, contains('desktopNavigationMaxWidth = 945'));
  });

  test('custom desktop workspaces use the same panel inset', () {
    for (final path in <String>[
      'lib/screens/adaptive_home_base_screen.dart',
      'lib/screens/desktop_employees_view.dart',
      'lib/screens/desktop_tasks_screen.dart',
      'lib/screens/desktop_timesheet_screen.dart',
      'lib/features/payments/presentation/screens/payments_screen.dart',
      'lib/features/milestones/presentation/milestones_screen.dart',
      'lib/features/milestones/presentation/milestone_detail_screen.dart',
    ]) {
      expect(
        source(path),
        contains('AppUi.pageDesktopHorizontalPadding'),
        reason: path,
      );
    }
  });
}
""",
    encoding='utf-8',
)
