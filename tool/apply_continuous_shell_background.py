from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found in {path}: {old[:180]!r}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


# AppSurfaceBackdrop now paints once at the shell level. Nested AppPage and
# AppLazyPage instances detect the inherited scope and reuse that same layer.
app_page_path = Path("lib/widgets/app_page.dart")
app_page = app_page_path.read_text(encoding="utf-8")
app_page = app_page.replace(
    "\nclass AppSurfaceBackdrop extends StatelessWidget {\n",
    """
class _AppSurfaceBackdropScope extends InheritedWidget {
  const _AppSurfaceBackdropScope({required super.child});

  static bool maybeOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_AppSurfaceBackdropScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(_AppSurfaceBackdropScope oldWidget) => false;
}

class AppSurfaceBackdrop extends StatelessWidget {
""",
    1,
)
old_build = """  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
"""
new_build = """  @override
  Widget build(BuildContext context) {
    if (_AppSurfaceBackdropScope.maybeOf(context)) return child;

    final dark = Theme.of(context).brightness == Brightness.dark;
    return _AppSurfaceBackdropScope(
      child: DecoratedBox(
        key: const ValueKey('app-surface-backdrop-layer'),
        decoration: BoxDecoration(
"""
if old_build not in app_page:
    raise SystemExit("AppSurfaceBackdrop build marker not found")
app_page = app_page.replace(old_build, new_build, 1)
old_tail = """          child,
        ],
      ),
    );
  }
}
"""
new_tail = """          child,
        ],
      ),
      ),
    );
  }
}
"""
if old_tail not in app_page:
    raise SystemExit("AppSurfaceBackdrop tail marker not found")
app_page = app_page.replace(old_tail, new_tail, 1)
app_page_path.write_text(app_page, encoding="utf-8")


# Both application shells paint the shared backdrop across body and the real
# bottomNavigationBar slot. The navigation still owns a separate layout area.
replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    "import '../../../widgets/premium_ui.dart';\n",
    "import '../../../widgets/app_page.dart';\nimport '../../../widgets/premium_ui.dart';\n",
)
replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    """      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
""",
    """      child: AppSurfaceBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
""",
)
replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    """        bottomNavigationBar: ProfessionalBottomNavigation(
          items: widget.items,
          selectedIndex: activeIndex,
          storageKey: widget.navigationStorageKey,
          onSelected: widget.controller.select,
        ),
      ),
    );
""",
    """          bottomNavigationBar: ProfessionalBottomNavigation(
            items: widget.items,
            selectedIndex: activeIndex,
            storageKey: widget.navigationStorageKey,
            onSelected: widget.controller.select,
          ),
        ),
      ),
    );
""",
)

replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    "import '../../../widgets/premium_ui.dart';\n",
    "import '../../../widgets/app_page.dart';\nimport '../../../widgets/premium_ui.dart';\n",
)
replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    """      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Listener(
""",
    """      child: AppSurfaceBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Listener(
""",
)
replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    """        bottomNavigationBar: _PremiumBottomBar(
          items: tabItems,
          selectedIndex: activeIndex,
          storageKey: widget.profile.isAdmin
              ? 'admin'
              : widget.profile.isForeman
              ? 'foreman'
              : 'worker',
          onSelected: selectTab,
        ),
      ),
    );
""",
    """          bottomNavigationBar: _PremiumBottomBar(
            items: tabItems,
            selectedIndex: activeIndex,
            storageKey: widget.profile.isAdmin
                ? 'admin'
                : widget.profile.isForeman
                ? 'foreman'
                : 'worker',
            onSelected: selectTab,
          ),
        ),
      ),
    );
""",
)

# Update earlier contracts: the shells are transparent again, but only because
# the exact AppSurfaceBackdrop artwork now sits behind the whole Scaffold.
for path in [
    "test/navigation_overlay_and_task_fab_contract_test.dart",
    "test/bottom_controls_safety_test.dart",
    "test/timesheet_floating_controls_contract_test.dart",
    "test/global_bottom_navigation_clearance_contract_test.dart",
]:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    text = text.replace(
        "backgroundColor: Theme.of(context).scaffoldBackgroundColor",
        "backgroundColor: Colors.transparent",
    )
    file_path.write_text(text, encoding="utf-8")

# Strengthen the shared contracts so future refactors cannot recreate a strip.
replace_once(
    "test/navigation_overlay_and_task_fab_contract_test.dart",
    """    expect(
      mainShell,
      contains('backgroundColor: Colors.transparent'),
    );
""",
    """    expect(mainShell, contains('child: AppSurfaceBackdrop('));
    expect(
      mainShell,
      contains('backgroundColor: Colors.transparent'),
    );
""",
)
replace_once(
    "test/navigation_overlay_and_task_fab_contract_test.dart",
    """    expect(
      persistentShell,
      contains('backgroundColor: Colors.transparent'),
    );
""",
    """    expect(persistentShell, contains('child: AppSurfaceBackdrop('));
    expect(
      persistentShell,
      contains('backgroundColor: Colors.transparent'),
    );
""",
)

Path("test/global_shell_background_continuity_test.dart").write_text(
    """import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/widgets/app_page.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all tab shells share one continuous AppSurfaceBackdrop', () {
    final persistent = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );
    final legacy = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );
    final backdrop = source('lib/widgets/app_page.dart');

    for (final shell in <String>[persistent, legacy]) {
      expect(shell, contains('child: AppSurfaceBackdrop('));
      expect(shell, contains('backgroundColor: Colors.transparent'));
      expect(shell, contains('bottomNavigationBar:'));
      expect(shell, isNot(contains('extendBody: true')));
    }

    expect(backdrop, contains('class _AppSurfaceBackdropScope'));
    expect(backdrop, contains("ValueKey('app-surface-backdrop-layer')"));
    expect(
      backdrop,
      contains('if (_AppSurfaceBackdropScope.maybeOf(context)) return child;'),
    );
  });

  testWidgets('nested page backdrops reuse the same painted layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppSurfaceBackdrop(
          child: AppSurfaceBackdrop(child: SizedBox.expand()),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('app-surface-backdrop-layer')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
""",
    encoding="utf-8",
)
