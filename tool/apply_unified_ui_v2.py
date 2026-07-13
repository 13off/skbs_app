from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

PRESSABLE = r'''import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';

class PremiumPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final double pressedScale;
  final double hoverScale;
  final bool enableHaptics;

  const PremiumPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.pressedScale = AppMotion.pressedScale,
    this.hoverScale = AppMotion.hoverScale,
    this.enableHaptics = true,
  });

  @override
  State<PremiumPressable> createState() => _PremiumPressableState();
}

class _PremiumPressableState extends State<PremiumPressable> {
  bool isPressed = false;
  bool isHovered = false;
  bool isFocused = false;

  bool get isEnabled => widget.onTap != null;

  bool get supportsHover {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void updatePressed(bool value) {
    if (!mounted || isPressed == value) return;
    setState(() => isPressed = value);
  }

  void handleTapDown(TapDownDetails details) {
    if (!isEnabled) return;
    updatePressed(true);

    if (widget.enableHaptics &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      HapticFeedback.selectionClick();
    }
  }

  void invokeAction() {
    if (!isEnabled) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final activeHover =
        supportsHover && isHovered && isEnabled && !isPressed;
    final showFocusRing = isFocused && isEnabled;
    final scale = isPressed
        ? widget.pressedScale
        : activeHover
        ? widget.hoverScale
        : 1.0;
    final duration = isPressed ? AppMotion.pressIn : AppMotion.hover;
    final curve = isPressed ? Curves.easeOut : AppMotion.interactionCurve;

    return Semantics(
      button: true,
      enabled: isEnabled,
      child: FocusableActionDetector(
        enabled: isEnabled,
        mouseCursor: isEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) {
          if (!mounted || isHovered == value) return;
          setState(() => isHovered = value);
        },
        onShowFocusHighlight: (value) {
          if (!mounted || isFocused == value) return;
          setState(() => isFocused = value);
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              invokeAction();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: isEnabled ? handleTapDown : null,
          onTapCancel: isEnabled ? () => updatePressed(false) : null,
          onTapUp: isEnabled ? (_) => updatePressed(false) : null,
          onTap: widget.onTap,
          child: AnimatedSlide(
            offset: activeHover ? const Offset(0, -0.012) : Offset.zero,
            duration: duration,
            curve: curve,
            child: AnimatedScale(
              scale: scale,
              duration: duration,
              curve: curve,
              child: AnimatedContainer(
                duration: AppMotion.regular,
                curve: AppMotion.interactionCurve,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: showFocusRing
                        ? AppColors.accent.withValues(alpha: 0.35)
                        : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: activeHover
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF17191C,
                            ).withValues(alpha: 0.10),
                            blurRadius: 24,
                            spreadRadius: -8,
                            offset: const Offset(0, 11),
                          ),
                        ]
                      : const [],
                ),
                child: AnimatedOpacity(
                  opacity: isEnabled ? (isPressed ? 0.95 : 1) : 0.46,
                  duration: AppMotion.fast,
                  child: ClipRRect(
                    borderRadius: widget.borderRadius,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'''

NAVIGATION = r'''import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import 'premium_pressable_v3.dart';

class ProfessionalBottomNavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const ProfessionalBottomNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class ProfessionalBottomNavigation extends StatelessWidget {
  final List<ProfessionalBottomNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const ProfessionalBottomNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  Widget buildIcon(
    ProfessionalBottomNavigationItem item,
    bool selected,
    bool isDesktop,
  ) {
    return AnimatedContainer(
      duration: AppMotion.regular,
      curve: AppMotion.interactionCurve,
      width: isDesktop ? 36 : 34,
      height: isDesktop ? 36 : 34,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  blurRadius: 15,
                  spreadRadius: -5,
                  offset: const Offset(0, 7),
                ),
              ]
            : const [],
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.regular,
        switchInCurve: AppMotion.enterCurve,
        switchOutCurve: AppMotion.exitCurve,
        child: Icon(
          selected ? item.selectedIcon : item.icon,
          key: ValueKey('${item.label}-$selected'),
          size: isDesktop ? 20 : 19,
          color: selected ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget buildLabel(
    BuildContext context,
    ProfessionalBottomNavigationItem item,
    bool selected,
    bool isDesktop,
  ) {
    return AnimatedDefaultTextStyle(
      duration: AppMotion.regular,
      curve: AppMotion.interactionCurve,
      style:
          Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: isDesktop ? 13 : 10.5,
            letterSpacing: isDesktop ? -0.1 : -0.2,
          ) ??
          const TextStyle(),
      child: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = animationsDisabled ? Duration.zero : AppMotion.regular;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final isDesktop = screenWidth >= 880;
    final panelHeight = isDesktop ? 72.0 : 68.0;
    final topSpacing = isDesktop ? 8.0 : 4.0;
    final bottomSpacing = isDesktop ? 14.0 : 10.0;
    final totalHeight = panelHeight + topSpacing + bottomSpacing + bottomInset;

    return SizedBox(
      key: const ValueKey('professional-bottom-navigation'),
      height: totalHeight,
      child: Material(
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 28 : 12,
            topSpacing,
            isDesktop ? 28 : 12,
            bottomSpacing + bottomInset,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 820 : double.infinity,
              ),
              child: Container(
                key: const ValueKey('professional-bottom-navigation-panel'),
                height: panelHeight,
                padding: EdgeInsets.all(isDesktop ? 8 : 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(isDesktop ? 23 : 26),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.96),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF17191C,
                      ).withValues(alpha: 0.10),
                      blurRadius: isDesktop ? 30 : 24,
                      spreadRadius: -9,
                      offset: Offset(0, isDesktop ? 14 : 11),
                    ),
                  ],
                ),
                child: Row(
                  children: List<Widget>.generate(items.length, (index) {
                    final item = items[index];
                    final selected = index == selectedIndex;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 3 : 2,
                        ),
                        child: PremiumPressable(
                          onTap: () => onSelected(index),
                          pressedScale: 0.97,
                          hoverScale: isDesktop ? AppMotion.hoverScale : 1,
                          borderRadius: BorderRadius.circular(17),
                          child: AnimatedContainer(
                            duration: duration,
                            curve: AppMotion.interactionCurve,
                            height: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 13 : 4,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.surfaceSoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(17),
                              border: selected
                                  ? Border.all(
                                      color: AppColors.border.withValues(
                                        alpha: 0.92,
                                      ),
                                    )
                                  : null,
                            ),
                            child: isDesktop
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      buildIcon(item, selected, true),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: buildLabel(
                                          context,
                                          item,
                                          selected,
                                          true,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      buildIcon(item, selected, false),
                                      const SizedBox(height: 2),
                                      buildLabel(
                                        context,
                                        item,
                                        selected,
                                        false,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'''

LEGACY_CLASS = PRESSABLE.split("class PremiumPressable", 1)[1]
LEGACY_CLASS = "class PremiumPressable" + LEGACY_CLASS

legacy_path = ROOT / 'lib/widgets/premium_ui_v2.dart'
legacy = legacy_path.read_text(encoding='utf-8')
start = legacy.index('class PremiumPressable extends StatefulWidget {')
end = legacy.index('class PremiumActionButton extends StatelessWidget {', start)
legacy_path.write_text(
    legacy[:start] + LEGACY_CLASS + '\n' + legacy[end:],
    encoding='utf-8',
)

(ROOT / 'lib/widgets/premium_pressable_v3.dart').write_text(
    PRESSABLE,
    encoding='utf-8',
)
(ROOT / 'lib/widgets/professional_bottom_navigation.dart').write_text(
    NAVIGATION,
    encoding='utf-8',
)

exports_path = ROOT / 'lib/widgets/premium_ui.dart'
exports = exports_path.read_text(encoding='utf-8')
export_line = "export 'professional_bottom_navigation.dart';\n"
if export_line not in exports:
    exports = export_line + exports
exports_path.write_text(exports, encoding='utf-8')

shell_path = ROOT / 'lib/features/shell/presentation/premium_main_screen.dart'
shell = shell_path.read_text(encoding='utf-8')
bar_start = shell.index('class _PremiumBottomBar extends StatelessWidget {')
tab_item_start = shell.index('class _TabItem {', bar_start)
stable_prefix = shell[:bar_start]
stable_suffix = shell[tab_item_start:]

wrapper = r'''class _PremiumBottomBar extends StatelessWidget {
  final List<_TabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PremiumBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ProfessionalBottomNavigation(
      items: items
          .map(
            (item) => ProfessionalBottomNavigationItem(
              label: item.label,
              icon: item.icon,
              selectedIcon: item.selectedIcon,
            ),
          )
          .toList(growable: false),
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    );
  }
}

'''
updated_shell = stable_prefix + wrapper + stable_suffix
if updated_shell[:bar_start] != stable_prefix:
    raise RuntimeError('Рабочая часть оболочки до нижней панели изменилась')
shell_path.write_text(updated_shell, encoding='utf-8')

(ROOT / 'test/ui_motion_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard buttons use one motion system', () {
    final source = File('lib/app/app_theme.dart').readAsStringSync();

    expect(source, contains('AppMotion.hoverScale'));
    expect(source, contains('backgroundBuilder: buttonSurface('));
    expect(source, contains('filledButtonStyle'));
    expect(source, contains('outlinedButtonStyle'));
    expect(source, contains('textButtonStyle'));
    expect(source, contains('iconButtonStyle'));
  });

  test('both premium pressables use identical motion constants', () {
    final legacy = File('lib/widgets/premium_ui_v2.dart').readAsStringSync();
    final current = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();

    for (final source in <String>[legacy, current]) {
      expect(source, contains('this.pressedScale = AppMotion.pressedScale'));
      expect(source, contains('this.hoverScale = AppMotion.hoverScale'));
      expect(source, contains('AppMotion.interactionCurve'));
      expect(source, contains('FocusableActionDetector'));
      expect(source, contains('void invokeAction()'));
      expect(source, isNot(contains('void activate()')));
    }
  });

  test('shell body remains unchanged before bottom navigation', () {
    final source = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();
    final barStart = source.indexOf(
      'class _PremiumBottomBar extends StatelessWidget',
    );
    final stableShell = source.substring(0, barStart);

    expect(stableShell, contains('CupertinoPageRoute<void>'));
    expect(stableShell, contains('PageView.builder'));
    expect(
      stableShell,
      contains('return buildRootPage(index, selectedObjectName);'),
    );
    expect(source, contains('return ProfessionalBottomNavigation('));
  });
}
''', encoding='utf-8')

(ROOT / 'test/professional_bottom_navigation_test.dart').write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/app/app_theme.dart';
import 'package:skbs_app/widgets/professional_bottom_navigation.dart';

const items = <ProfessionalBottomNavigationItem>[
  ProfessionalBottomNavigationItem(
    label: 'Главная',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Люди',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Табель',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_month_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Задачи',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Профиль',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

Future<void> pumpNavigation(
  WidgetTester tester,
  Size size, {
  required ValueChanged<int> onSelected,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: const ColoredBox(
          key: ValueKey('screen-body'),
          color: Colors.white,
        ),
        bottomNavigationBar: ProfessionalBottomNavigation(
          items: items,
          selectedIndex: 0,
          onSelected: onSelected,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop navigation never consumes the screen body', (
    tester,
  ) async {
    var selected = -1;
    await pumpNavigation(
      tester,
      const Size(1440, 900),
      onSelected: (value) => selected = value,
    );

    final bodyHeight = tester.getSize(find.byKey(const ValueKey('screen-body'))).height;
    final navigationHeight = tester
        .getSize(find.byKey(const ValueKey('professional-bottom-navigation')))
        .height;

    expect(bodyHeight, greaterThan(780));
    expect(navigationHeight, lessThan(110));
    for (final item in items) {
      expect(find.text(item.label), findsOneWidget);
    }

    await tester.tap(find.text('Задачи'));
    await tester.pumpAndSettle();
    expect(selected, 3);
  });

  testWidgets('mobile navigation stays compact and keeps all tabs visible', (
    tester,
  ) async {
    await pumpNavigation(
      tester,
      const Size(390, 844),
      onSelected: (_) {},
    );

    final bodyHeight = tester.getSize(find.byKey(const ValueKey('screen-body'))).height;
    final panelHeight = tester
        .getSize(
          find.byKey(const ValueKey('professional-bottom-navigation-panel')),
        )
        .height;

    expect(bodyHeight, greaterThan(750));
    expect(panelHeight, 68);
    for (final item in items) {
      expect(find.text(item.label), findsOneWidget);
    }
  });
}
''', encoding='utf-8')

preview_workflow = ROOT / '.github/workflows/ui-v2-preview-check.yml'
preview_workflow.write_text(r'''name: UI v2 preview check

on:
  push:
    branches:
      - ui/unified-motion-nav-v2
  pull_request:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ui-v2-preview-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test-and-build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version-file: .fvmrc
          cache: true

      - name: Install locked dependencies
        run: flutter pub get --enforce-lockfile

      - name: Run all tests
        run: flutter test

      - name: Analyze
        run: flutter analyze --no-fatal-infos --no-fatal-warnings

      - name: Build web preview
        run: flutter build web --release --base-href /appstroy-web/

      - name: Upload preview artifact
        uses: actions/upload-artifact@v4
        with:
          name: appstroy-ui-v2-web-${{ github.sha }}
          path: build/web
          retention-days: 7
''', encoding='utf-8')
