from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"{path}: expected one occurrence, found {count}: {old!r}"
        )
    file.write_text(text.replace(old, new, 1))


nav = Path('lib/widgets/professional_bottom_navigation.dart')
text = nav.read_text()
for old, new in {
    'const _darkNavigationPanelTint = Color(0x66232C35);':
        'const _darkNavigationPanelTint = Color(0x8047525D);',
    'Color(0xB3353B42),': 'Color(0xCC5B646E),',
    'Color(0x992C3640),': 'Color(0xB34A5662),',
    'Color(0x8011171E),': 'Color(0x99404B56),',
}.items():
    if text.count(old) != 1:
        raise SystemExit(f'Navigation marker mismatch: {old}')
    text = text.replace(old, new, 1)
nav.write_text(text)

replace_once(
    'lib/features/shell/presentation/premium_main_screen.dart',
    "        body: Listener(\n"
    "          behavior: HitTestBehavior.translucent,\n"
    "          onPointerDown: handlePointerDown,\n"
    "          onPointerUp: handlePointerUp,\n"
    "          onPointerCancel: (_) => topTapStart = null,\n"
    "          child: PageView.builder(\n"
    "            controller: pageController,\n"
    "            itemCount: pageCount,\n"
    "            allowImplicitScrolling: false,\n"
    "            physics: supportsAppSwipes\n"
    "                ? _ConditionalPagePhysics(canSwipe: canSwipeBetweenTabs)\n"
    "                : const NeverScrollableScrollPhysics(),\n"
    "            onPageChanged: handlePageChanged,\n"
    "            itemBuilder: (context, index) {\n"
    "              return buildTabNavigator(index);\n"
    "            },\n"
    "          ),\n"
    "        ),\n"
    "        bottomNavigationBar: _PremiumBottomBar(\n"
    "          items: tabItems,\n"
    "          selectedIndex: activeIndex,\n"
    "          storageKey: widget.profile.isAdmin\n"
    "              ? 'admin'\n"
    "              : widget.profile.isForeman\n"
    "              ? 'foreman'\n"
    "              : 'worker',\n"
    "          onSelected: selectTab,\n"
    "        ),",
    "        body: Stack(\n"
    "          fit: StackFit.expand,\n"
    "          children: [\n"
    "            Listener(\n"
    "              behavior: HitTestBehavior.translucent,\n"
    "              onPointerDown: handlePointerDown,\n"
    "              onPointerUp: handlePointerUp,\n"
    "              onPointerCancel: (_) => topTapStart = null,\n"
    "              child: PageView.builder(\n"
    "                controller: pageController,\n"
    "                itemCount: pageCount,\n"
    "                allowImplicitScrolling: false,\n"
    "                physics: supportsAppSwipes\n"
    "                    ? _ConditionalPagePhysics(canSwipe: canSwipeBetweenTabs)\n"
    "                    : const NeverScrollableScrollPhysics(),\n"
    "                onPageChanged: handlePageChanged,\n"
    "                itemBuilder: (context, index) {\n"
    "                  return buildTabNavigator(index);\n"
    "                },\n"
    "              ),\n"
    "            ),\n"
    "            Positioned(\n"
    "              left: 0,\n"
    "              right: 0,\n"
    "              bottom: 0,\n"
    "              child: _PremiumBottomBar(\n"
    "                items: tabItems,\n"
    "                selectedIndex: activeIndex,\n"
    "                storageKey: widget.profile.isAdmin\n"
    "                    ? 'admin'\n"
    "                    : widget.profile.isForeman\n"
    "                    ? 'foreman'\n"
    "                    : 'worker',\n"
    "                onSelected: selectTab,\n"
    "              ),\n"
    "            ),\n"
    "          ],\n"
    "        ),",
)

replace_once(
    'lib/features/shell/presentation/persistent_tab_shell.dart',
    "      child: Scaffold(\n"
    "        body: IndexedStack(\n"
    "          index: activeIndex,\n"
    "          children: List<Widget>.generate(widget.controller.pageCount, (index) {\n"
    "            final child = _tabNavigators[index];\n"
    "            if (child == null) return const SizedBox.shrink();\n"
    "            return TickerMode(enabled: index == activeIndex, child: child);\n"
    "          }),\n"
    "        ),\n"
    "        bottomNavigationBar: ProfessionalBottomNavigation(\n"
    "          items: widget.items,\n"
    "          selectedIndex: activeIndex,\n"
    "          storageKey: widget.navigationStorageKey,\n"
    "          onSelected: widget.controller.select,\n"
    "        ),\n"
    "      ),",
    "      child: Scaffold(\n"
    "        extendBody: true,\n"
    "        backgroundColor: Colors.transparent,\n"
    "        body: Stack(\n"
    "          fit: StackFit.expand,\n"
    "          children: [\n"
    "            IndexedStack(\n"
    "              index: activeIndex,\n"
    "              children: List<Widget>.generate(\n"
    "                widget.controller.pageCount,\n"
    "                (index) {\n"
    "                  final child = _tabNavigators[index];\n"
    "                  if (child == null) return const SizedBox.shrink();\n"
    "                  return TickerMode(\n"
    "                    enabled: index == activeIndex,\n"
    "                    child: child,\n"
    "                  );\n"
    "                },\n"
    "              ),\n"
    "            ),\n"
    "            Positioned(\n"
    "              left: 0,\n"
    "              right: 0,\n"
    "              bottom: 0,\n"
    "              child: ProfessionalBottomNavigation(\n"
    "                items: widget.items,\n"
    "                selectedIndex: activeIndex,\n"
    "                storageKey: widget.navigationStorageKey,\n"
    "                onSelected: widget.controller.select,\n"
    "              ),\n"
    "            ),\n"
    "          ],\n"
    "        ),\n"
    "      ),",
)

tasks = Path('lib/screens/mobile_tasks_screen.dart')
text = tasks.read_text()
import_marker = "import '../app/app_adaptive_palette.dart';\n"
if text.count(import_marker) != 1:
    raise SystemExit('Missing AppAdaptivePalette import marker')
text = text.replace(
    import_marker,
    import_marker + "import '../app/app_ui_tokens.dart';\n",
    1,
)
old_return = """    return AppLazyPage(
      title: 'Задачи',
      subtitle: 'Работы по осям, исполнители и готовность за выбранную дату',
      leading: leading,
      itemCount: loadError == null ? tasks.length : 0,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskTile(task: task, onTap: () => openTaskDetails(task));
      },
      trailing: <Widget>[
        const SizedBox(height: 14),
        if (widget.profile.isForeman) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: taskDrafts.isEmpty ? null : openDrafts,
              icon: const Icon(Icons.drafts_outlined),
              label: Text('Черновики (${taskDrafts.length})'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        PremiumActionButton(
          label: 'Добавить задачу',
          icon: Icons.add_rounded,
          onPressed:
              TaskEditPolicy.canCreateForDate(widget.profile, selectedDate)
              ? () => openAddTaskScreen()
              : null,
        ),
        buildActButton(tasks),
      ],
    );
"""
new_return = """    final canCreateTask = TaskEditPolicy.canCreateForDate(
      widget.profile,
      selectedDate,
    );
    final floatingBottom = AppUi.floatingActionBottom(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        AppLazyPage(
          title: 'Задачи',
          subtitle: 'Работы по осям, исполнители и готовность за выбранную дату',
          leading: leading,
          itemCount: loadError == null ? tasks.length : 0,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return TaskTile(task: task, onTap: () => openTaskDetails(task));
          },
          trailing: <Widget>[
            const SizedBox(height: 14),
            if (widget.profile.isForeman) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: taskDrafts.isEmpty ? null : openDrafts,
                  icon: const Icon(Icons.drafts_outlined),
                  label: Text('Черновики (${taskDrafts.length})'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            buildActButton(tasks),
            const SizedBox(height: 78),
          ],
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: floatingBottom,
          child: Center(
            child: SizedBox(
              key: const ValueKey('tasks-floating-add'),
              width: 340,
              child: PremiumActionButton(
                label: 'Добавить задачу',
                icon: Icons.add_rounded,
                onPressed: canCreateTask ? () => openAddTaskScreen() : null,
              ),
            ),
          ),
        ),
      ],
    );
"""
if text.count(old_return) != 1:
    raise SystemExit('Tasks return block changed unexpectedly')
tasks.write_text(text.replace(old_return, new_return, 1))

Path('test/navigation_overlay_and_task_fab_contract_test.dart').write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all main shells float navigation above page content', () {
    final mainShell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );
    final persistentShell = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );

    expect(mainShell, contains('body: Stack('));
    expect(mainShell, contains('child: _PremiumBottomBar('));
    expect(mainShell, isNot(contains('bottomNavigationBar: _PremiumBottomBar(')));
    expect(persistentShell, contains('extendBody: true'));
    expect(persistentShell, contains('backgroundColor: Colors.transparent'));
    expect(persistentShell, contains('child: ProfessionalBottomNavigation('));
    expect(
      persistentShell,
      isNot(contains('bottomNavigationBar: ProfessionalBottomNavigation(')),
    );
  });

  test('dark navigation glass stays graphite instead of black', () {
    final navigation = source(
      'lib/widgets/professional_bottom_navigation.dart',
    );

    expect(navigation, contains('Color(0x8047525D)'));
    expect(navigation, contains('Color(0xCC5B646E)'));
    expect(navigation, contains('Color(0xB34A5662)'));
    expect(navigation, contains('Color(0x99404B56)'));
    expect(navigation, isNot(contains('Color(0x66232C35)')));
  });

  test('mobile add task action is fixed above navigation', () {
    final tasks = source('lib/screens/mobile_tasks_screen.dart');

    expect(tasks, contains("ValueKey('tasks-floating-add')"));
    expect(tasks, contains('bottom: floatingBottom'));
    expect(tasks, contains('AppUi.floatingActionBottom(context)'));
    expect(tasks, contains("label: 'Добавить задачу'"));
    expect(tasks, contains('const SizedBox(height: 78)'));
  });
}
""")
