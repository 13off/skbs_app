from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    if new in text:
        return
    if old not in text:
        raise RuntimeError(f'Не найден маркер в {path}: {old[:100]!r}')
    file_path.write_text(text.replace(old, new, 1), encoding='utf-8')


def replace_all(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    if old not in text:
        return
    file_path.write_text(text.replace(old, new), encoding='utf-8')


replace_once(
    'lib/app/app_theme.dart',
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';",
)
replace_once(
    'lib/app/app_theme.dart',
    '''abstract final class AppMotion {
  static const fast = Duration(milliseconds: 110);
  static const regular = Duration(milliseconds: 180);
  static const hover = Duration(milliseconds: 180);
  static const page = Duration(milliseconds: 240);
  static const tab = Duration(milliseconds: 240);
  static const pressIn = Duration(milliseconds: 65);
  static const pressOut = Duration(milliseconds: 180);

  static const double hoverScale = 1.018;
  static const double pressedScale = 0.974;''',
    '''abstract final class AppMotion {
  // Короткие системные интервалы сохраняют характер интерфейса, но не
  // заставляют пользователя ждать завершения декоративной анимации.
  static const fast = Duration(milliseconds: 55);
  static const regular = Duration(milliseconds: 95);
  static const hover = Duration(milliseconds: 70);
  static const page = Duration(milliseconds: 130);
  static const tab = Duration(milliseconds: 105);
  static const pressIn = Duration(milliseconds: 28);
  static const pressOut = Duration(milliseconds: 65);

  static const double hoverScale = 1.004;
  static const double pressedScale = 0.988;''',
)
replace_once(
    'lib/app/app_theme.dart',
    '''    if (animationsDisabled || route.isFirst) {
      return child;
    }''',
    '''    final desktopPlatform =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    // Полноэкранный slide на CanvasKit задерживал первый интерактивный кадр.
    // На Web/PWA и desktop переход выполняется сразу; мобильная навигация
    // сохраняет привычное движение.
    if (animationsDisabled || route.isFirst || kIsWeb || desktopPlatform) {
      return child;
    }''',
)
replace_once(
    'lib/app/app_theme.dart',
    '''                        blurRadius: pressed
                            ? 8
                            : activeHover
                            ? 22
                            : 12,
                        spreadRadius: activeHover ? -4 : -6,
                        offset: Offset(
                          0,
                          pressed
                              ? 2
                              : activeHover
                              ? 10
                              : 5,
                        ),''',
    '''                        blurRadius: pressed
                            ? 3
                            : activeHover
                            ? 8
                            : 5,
                        spreadRadius: activeHover ? -5 : -4,
                        offset: Offset(
                          0,
                          pressed
                              ? 1
                              : activeHover
                              ? 3
                              : 2,
                        ),''',
)

replace_once(
    'lib/app/premium_scroll_behavior.dart',
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';",
)
replace_once(
    'lib/app/premium_scroll_behavior.dart',
    '''  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }''',
    '''  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final desktopPlatform =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    // Пружинящая мобильная физика делает колесо мыши и trackpad вязкими.
    if (kIsWeb || desktopPlatform) {
      return const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }''',
)

old_pressable = '''    final duration = isPressed ? AppMotion.pressIn : AppMotion.hover;
    final curve = isPressed ? Curves.easeOut : AppMotion.interactionCurve;'''
new_pressable = '''    final duration = isPressed
        ? AppMotion.pressIn
        : activeHover
        ? AppMotion.hover
        : AppMotion.pressOut;
    final curve = isPressed ? Curves.easeOut : AppMotion.interactionCurve;'''

old_pressable_tree = '''        child: AnimatedSlide(
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
        ),'''
new_pressable_tree = '''        child: AnimatedScale(
          scale: scale,
          duration: duration,
          curve: curve,
          child: AnimatedOpacity(
            opacity: isEnabled ? (isPressed ? 0.96 : 1) : 0.46,
            duration: AppMotion.fast,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: showFocusRing
                      ? AppColors.accent.withValues(alpha: 0.35)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),'''
for pressable_path in (
    'lib/widgets/premium_pressable_v3.dart',
    'lib/widgets/premium_ui_v2_legacy.dart',
):
    replace_once(pressable_path, old_pressable, new_pressable)
    replace_once(pressable_path, old_pressable_tree, new_pressable_tree)

replace_once(
    'lib/widgets/premium_ui_v2.dart',
    '''    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? (tint ?? theme.colorScheme.surface) : tint,
        gradient: !dark && tint == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.91),
                  Colors.white.withValues(alpha: 0.72),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? theme.colorScheme.outlineVariant
              : Colors.white.withValues(alpha: 0.94),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.20 : 0.075),
            blurRadius: dark ? 18 : 28,
            spreadRadius: dark ? -10 : -12,
            offset: Offset(0, dark ? 9 : 16),
          ),
          if (!dark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.78),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: child,
    );''',
    '''    return RepaintBoundary(
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: dark ? (tint ?? theme.colorScheme.surface) : tint,
          gradient: !dark && tint == null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.91),
                    Colors.white.withValues(alpha: 0.72),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: dark
                ? theme.colorScheme.outlineVariant
                : Colors.white.withValues(alpha: 0.94),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.15 : 0.055),
              blurRadius: dark ? 9 : 13,
              spreadRadius: dark ? -5 : -7,
              offset: Offset(0, dark ? 4 : 6),
            ),
            if (!dark)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.72),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: child,
      ),
    );''',
)
replace_once(
    'lib/widgets/premium_ui_v2.dart',
    '              blurRadius: dark ? 18 : 24,\n              spreadRadius: dark ? -10 : 0,\n              offset: Offset(0, dark ? 8 : 12),',
    '              blurRadius: dark ? 9 : 11,\n              spreadRadius: dark ? -6 : -4,\n              offset: Offset(0, dark ? 4 : 5),',
)

replace_once(
    'lib/widgets/app_page.dart',
    '''class AppSurfaceBackdrop extends StatelessWidget {
  final Widget child;

  const AppSurfaceBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? AppAdaptivePalette.darkBackground
            : AppAdaptivePalette.background,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -140,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 330,
                height: 330,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: dark
                        ? [
                            AppAdaptivePalette.telegramBlue.withValues(
                              alpha: 0.12,
                            ),
                            Colors.transparent,
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.68),
                            Colors.white.withValues(alpha: 0),
                          ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}''',
    '''class AppSurfaceBackdrop extends StatelessWidget {
  final Widget child;

  const AppSurfaceBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark
                    ? AppAdaptivePalette.darkBackground
                    : AppAdaptivePalette.background,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: -140,
                    right: -100,
                    child: IgnorePointer(
                      child: Container(
                        width: 330,
                        height: 330,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: dark
                                ? [
                                    AppAdaptivePalette.telegramBlue.withValues(
                                      alpha: 0.12,
                                    ),
                                    Colors.transparent,
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.68),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}''',
)

replace_once(
    'lib/app/app_scale_viewport.dart',
    '''        child: Transform.scale(
          scale: effectiveScale,
          alignment: Alignment.topLeft,''',
    '''        child: Transform.scale(
          scale: effectiveScale,
          alignment: Alignment.topLeft,
          filterQuality: FilterQuality.none,''',
)
replace_once(
    'lib/main.dart',
    '          themeAnimationDuration: const Duration(milliseconds: 220),',
    '          themeAnimationDuration: const Duration(milliseconds: 110),',
)
replace_once(
    'lib/widgets/professional_bottom_navigation.dart',
    '''                      blurRadius: isDesktop ? 20 : 18,
                      spreadRadius: -10,
                      offset: Offset(0, isDesktop ? 10 : 8),''',
    '''                      blurRadius: isDesktop ? 10 : 8,
                      spreadRadius: -6,
                      offset: Offset(0, isDesktop ? 4 : 3),''',
)
replace_once(
    'lib/app/premium_depth_theme.dart',
    '''            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 3;
            return 1.5;''',
    '''            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 1;
            return 0.5;''',
)
replace_once(
    'lib/app/premium_depth_theme.dart',
    '''            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 2;
            return 0.5;''',
    '''            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 0.5;
            return 0;''',
)
replace_once(
    'lib/app/premium_depth_theme.dart',
    '''            if (states.contains(WidgetState.hovered)) return 2;
            return 0;''',
    '''            if (states.contains(WidgetState.hovered)) return 0.5;
            return 0;''',
)

Path('test/web_performance_contract_test.dart').write_text(
    '''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web PWA uses the fast interaction and scrolling contract', () {
    final theme = File('lib/app/app_theme.dart').readAsStringSync();
    final scroll = File(
      'lib/app/premium_scroll_behavior.dart',
    ).readAsStringSync();
    final pressable = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();
    final legacyPressable = File(
      'lib/widgets/premium_ui_v2_legacy.dart',
    ).readAsStringSync();
    final surfaces = File(
      'lib/widgets/premium_ui_v2.dart',
    ).readAsStringSync();
    final page = File('lib/widgets/app_page.dart').readAsStringSync();
    final scale = File(
      'lib/app/app_scale_viewport.dart',
    ).readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(theme, contains('static const hover = Duration(milliseconds: 70)'));
    expect(theme, contains('static const regular = Duration(milliseconds: 95)'));
    expect(theme, contains('route.isFirst || kIsWeb || desktopPlatform'));
    expect(scroll, contains('ClampingScrollPhysics'));
    expect(scroll, contains('if (kIsWeb || desktopPlatform)'));

    for (final source in <String>[pressable, legacyPressable]) {
      final interaction = source.split('class PremiumActionButton').first;
      expect(interaction, isNot(contains('AnimatedSlide(')));
      expect(interaction, isNot(contains('ClipRRect(')));
      expect(interaction, isNot(contains('boxShadow: activeHover')));
      expect(interaction, contains('DecorationPosition.foreground'));
    }

    expect(surfaces, contains('return RepaintBoundary('));
    expect(page, contains('Positioned.fill(\n          child: RepaintBoundary('));
    expect(scale, contains('filterQuality: FilterQuality.none'));
    expect(
      mainSource,
      contains('themeAnimationDuration: const Duration(milliseconds: 110)'),
    );
  });
}
''',
    encoding='utf-8',
)
