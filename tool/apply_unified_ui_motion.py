from pathlib import Path

root = Path('.')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'Не найден фрагмент для изменения: {label}')
    return text.replace(old, new, 1)


theme_path = root / 'lib/app/app_theme.dart'
theme = theme_path.read_text(encoding='utf-8')

theme = replace_once(
    theme,
    """abstract final class AppMotion {
  static const fast = Duration(milliseconds: 110);
  static const regular = Duration(milliseconds: 190);
  static const page = Duration(milliseconds: 260);
  static const tab = Duration(milliseconds: 220);
  static const pressIn = Duration(milliseconds: 55);
  static const pressOut = Duration(milliseconds: 150);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;
  static const Curve springCurve = Curves.easeOutCubic;
}
""",
    """abstract final class AppMotion {
  static const fast = Duration(milliseconds: 110);
  static const regular = Duration(milliseconds: 180);
  static const hover = Duration(milliseconds: 180);
  static const page = Duration(milliseconds: 240);
  static const tab = Duration(milliseconds: 240);
  static const pressIn = Duration(milliseconds: 65);
  static const pressOut = Duration(milliseconds: 180);

  static const double hoverScale = 1.018;
  static const double pressedScale = 0.974;

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;
  static const Curve interactionCurve = Cubic(0.22, 1, 0.36, 1);
  static const Curve springCurve = Curves.easeOutCubic;
}
""",
    'AppMotion',
)

theme = replace_once(
    theme,
    """    WidgetStateProperty<Color?> subtleOverlay() {
      return WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withValues(alpha: 0.06);
        }
        return Colors.transparent;
      });
    }
""",
    """    ButtonLayerBuilder buttonSurface({
      required Color background,
      required Color hoveredBackground,
      required Color pressedBackground,
      required Color disabledBackground,
      Color? borderColor,
      Color? hoveredBorderColor,
      Color? pressedBorderColor,
      bool circular = false,
      bool elevated = false,
    }) {
      return (_, states, child) {
        final disabled = states.contains(WidgetState.disabled);
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        final focused = states.contains(WidgetState.focused);
        final activeHover = !disabled && !pressed && (hovered || focused);

        final color = disabled
            ? disabledBackground
            : pressed
            ? pressedBackground
            : activeHover
            ? hoveredBackground
            : background;
        final resolvedBorder = disabled
            ? borderColor?.withValues(alpha: 0.48)
            : pressed
            ? (pressedBorderColor ?? borderColor)
            : activeHover
            ? (hoveredBorderColor ?? borderColor)
            : borderColor;
        final scale = pressed
            ? AppMotion.pressedScale
            : activeHover
            ? AppMotion.hoverScale
            : 1.0;
        final radius = pressed
            ? 16.0
            : activeHover
            ? 20.0
            : 18.0;

        return AnimatedScale(
          scale: scale,
          duration: pressed ? AppMotion.pressIn : AppMotion.hover,
          curve: pressed ? Curves.easeOut : AppMotion.interactionCurve,
          child: AnimatedContainer(
            duration: pressed ? AppMotion.pressIn : AppMotion.regular,
            curve: AppMotion.interactionCurve,
            decoration: BoxDecoration(
              color: color,
              shape: circular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circular ? null : BorderRadius.circular(radius),
              border: resolvedBorder == null
                  ? null
                  : Border.all(color: resolvedBorder),
              boxShadow: !elevated || disabled
                  ? const <BoxShadow>[]
                  : [
                      BoxShadow(
                        color: AppColors.accent.withValues(
                          alpha: pressed
                              ? 0.07
                              : activeHover
                              ? 0.17
                              : 0.10,
                        ),
                        blurRadius: pressed
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
                        ),
                      ),
                    ],
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      };
    }

    final filledButtonStyle = ButtonStyle(
      animationDuration: AppMotion.regular,
      minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
      tapTargetSize: MaterialTapTargetSize.padded,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white.withValues(alpha: 0.68);
        }
        return Colors.white;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      backgroundBuilder: buttonSurface(
        background: AppColors.accent,
        hoveredBackground: const Color(0xFF30343A),
        pressedBackground: const Color(0xFF111316),
        disabledBackground: AppColors.accent.withValues(alpha: 0.38),
        elevated: true,
      ),
    );

    final outlinedButtonStyle = ButtonStyle(
      animationDuration: AppMotion.regular,
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      tapTargetSize: MaterialTapTargetSize.padded,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textMuted.withValues(alpha: 0.55);
        }
        return AppColors.textPrimary;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      backgroundBuilder: buttonSurface(
        background: Colors.white.withValues(alpha: 0.76),
        hoveredBackground: Colors.white,
        pressedBackground: AppColors.accentSoft,
        disabledBackground: Colors.white.withValues(alpha: 0.42),
        borderColor: AppColors.border,
        hoveredBorderColor: AppColors.accent.withValues(alpha: 0.28),
        pressedBorderColor: AppColors.accent.withValues(alpha: 0.44),
      ),
    );

    final textButtonStyle = ButtonStyle(
      animationDuration: AppMotion.regular,
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      tapTargetSize: MaterialTapTargetSize.padded,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textMuted.withValues(alpha: 0.50);
        }
        return AppColors.textPrimary;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      backgroundBuilder: buttonSurface(
        background: Colors.transparent,
        hoveredBackground: AppColors.accent.withValues(alpha: 0.055),
        pressedBackground: AppColors.accent.withValues(alpha: 0.085),
        disabledBackground: Colors.transparent,
      ),
    );

    final iconButtonStyle = ButtonStyle(
      animationDuration: AppMotion.regular,
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textMuted.withValues(alpha: 0.48);
        }
        return AppColors.textPrimary;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: const WidgetStatePropertyAll(CircleBorder()),
      backgroundBuilder: buttonSurface(
        background: Colors.transparent,
        hoveredBackground: Colors.white,
        pressedBackground: AppColors.accentSoft,
        disabledBackground: Colors.transparent,
        circular: true,
        elevated: true,
      ),
    );
""",
    'единая анимация кнопок',
)

button_start = theme.index('      filledButtonTheme: FilledButtonThemeData(')
button_end = theme.index('      inputDecorationTheme:', button_start)
theme = (
    theme[:button_start]
    + """      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
      textButtonTheme: TextButtonThemeData(style: textButtonStyle),
      iconButtonTheme: IconButtonThemeData(style: iconButtonStyle),
"""
    + theme[button_end:]
)
theme_path.write_text(theme, encoding='utf-8')

pressable_path = root / 'lib/widgets/premium_pressable_v3.dart'
pressable_path.write_text(
    """import 'package:flutter/foundation.dart';
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

  void activate() {
    if (!isEnabled) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final activeHover =
        supportsHover &&
        (isHovered || isFocused) &&
        isEnabled &&
        !isPressed;
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
              activate();
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
            offset: activeHover ? const Offset(0, -0.018) : Offset.zero,
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
                    color: activeHover || isFocused
                        ? Colors.white.withValues(alpha: 0.88)
                        : Colors.transparent,
                    width: 0.8,
                  ),
                  boxShadow: activeHover
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF111317,
                            ).withValues(alpha: 0.075),
                            blurRadius: 30,
                            spreadRadius: -9,
                            offset: const Offset(0, 15),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.76),
                            blurRadius: 12,
                            spreadRadius: -6,
                            offset: const Offset(0, -3),
                          ),
                        ]
                      : const [],
                ),
                child: AnimatedOpacity(
                  opacity: isEnabled ? (isPressed ? 0.96 : 1) : 0.46,
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
""",
    encoding='utf-8',
)

shell_path = root / 'lib/features/shell/presentation/premium_main_screen.dart'
shell = shell_path.read_text(encoding='utf-8')
shell = replace_once(
    shell,
    "import 'package:flutter/cupertino.dart' show CupertinoPageRoute;\n",
    '',
    'CupertinoPageRoute import',
)
shell = replace_once(
    shell,
    '          return CupertinoPageRoute<void>(\n',
    '          return MaterialPageRoute<void>(\n',
    'единый переход внутренних страниц',
)
shell = replace_once(
    shell,
    """      duration: AppMotion.tab,
      curve: AppMotion.enterCurve,
""",
    """      duration: AppMotion.page,
      curve: AppMotion.emphasizedCurve,
""",
    'анимация переключения вкладок',
)

bottom_start = shell.index('class _PremiumBottomBar extends StatelessWidget {')
bottom_end = shell.index('class _TabItem {', bottom_start)
new_bottom = """class _PremiumBottomBar extends StatelessWidget {
  final List<_TabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PremiumBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  Widget buildIcon(_TabItem item, bool selected, bool isDesktop) {
    return AnimatedContainer(
      duration: AppMotion.regular,
      curve: AppMotion.interactionCurve,
      width: isDesktop ? 34 : 32,
      height: isDesktop ? 34 : 32,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(isDesktop ? 11 : 10),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  blurRadius: 14,
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
    _TabItem item,
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
            fontSize: isDesktop ? 12.5 : 10.5,
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
    final isDesktop = screenWidth >= 760;
    final maxWidth = items.length >= 5 ? 760.0 : 640.0;
    final horizontalMargin = isDesktop ? 28.0 : 12.0;
    final bottomMargin = isDesktop ? 16.0 : 10.0;

    return Material(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(
          horizontalMargin,
          4,
          horizontalMargin,
          bottomMargin,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              height: isDesktop ? 72 : 68,
              padding: EdgeInsets.all(isDesktop ? 8 : 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.965),
                borderRadius: BorderRadius.circular(isDesktop ? 24 : 26),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.90),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF17191C,
                    ).withValues(alpha: 0.105),
                    blurRadius: isDesktop ? 30 : 24,
                    spreadRadius: -8,
                    offset: Offset(0, isDesktop ? 14 : 11),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.88),
                    blurRadius: 12,
                    spreadRadius: -6,
                    offset: const Offset(0, -3),
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
                        pressedScale: 0.965,
                        hoverScale: selected ? 1.012 : 1.026,
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: duration,
                          curve: AppMotion.interactionCurve,
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 12 : 4,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFF1F0EC)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            border: selected
                                ? Border.all(
                                    color: AppColors.border.withValues(
                                      alpha: 0.82,
                                    ),
                                  )
                                : null,
                          ),
                          child: isDesktop
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    buildIcon(item, selected, true),
                                    const SizedBox(width: 9),
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
    );
  }
}
"""
shell = shell[:bottom_start] + new_bottom + '\n\n' + shell[bottom_end:]
shell_path.write_text(shell, encoding='utf-8')

test_path = root / 'test/ui_motion_contract_test.dart'
test_path.write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard buttons use one motion surface', () {
    final source = File('lib/app/app_theme.dart').readAsStringSync();

    expect(source, contains('AppMotion.hoverScale'));
    expect(source, contains('backgroundBuilder: buttonSurface('));
    expect(source, contains('filledButtonStyle'));
    expect(source, contains('outlinedButtonStyle'));
    expect(source, contains('textButtonStyle'));
    expect(source, contains('iconButtonStyle'));
  });

  test('premium pressables use the same hover and press motion', () {
    final source = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();

    expect(source, contains('this.hoverScale = AppMotion.hoverScale'));
    expect(source, contains('AppMotion.interactionCurve'));
    expect(source, contains('FocusableActionDetector'));
  });

  test('shell uses unified routes and adaptive professional bar', () {
    final source = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();

    expect(source, contains('MaterialPageRoute<void>'));
    expect(source, isNot(contains('CupertinoPageRoute')));
    expect(source, contains('final isDesktop = screenWidth >= 760'));
    expect(source, contains('constraints: BoxConstraints(maxWidth: maxWidth)'));
    expect(source, contains('hoverScale: selected ? 1.012 : 1.026'));
  });
}
""",
    encoding='utf-8',
)

for temporary_path in [
    root / '.github/workflows/apply-unified-ui-motion.yml',
    root / '.github/workflows/apply-unified-ui-motion-pr.yml',
    root / 'tool/apply_unified_ui_motion.marker',
    root / 'tool/apply_unified_ui_motion.py',
]:
    if temporary_path.exists():
        temporary_path.unlink()
