import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// Масштабирует весь Flutter-интерфейс, а не только текст.
///
/// Обратный логический размер позволяет при масштабе меньше 100% показать
/// больше рабочего пространства, сохранив корректные hit-test, диалоги и
/// системные отступы внутри приложения.
class AppScaleViewport extends StatelessWidget {
  final double scale;
  final Widget child;

  const AppScaleViewport({
    super.key,
    required this.scale,
    required this.child,
  });

  EdgeInsets _scaledInsets(EdgeInsets value, double effectiveScale) {
    return EdgeInsets.fromLTRB(
      value.left / effectiveScale,
      value.top / effectiveScale,
      value.right / effectiveScale,
      value.bottom / effectiveScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final effectiveScale = scale.clamp(0.80, 1.20).toDouble();
    final logicalSize = Size(
      mediaQuery.size.width / effectiveScale,
      mediaQuery.size.height / effectiveScale,
    );

    final scaledChild = (effectiveScale - 1).abs() < 0.001
        ? child
        : ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.scale(
                scale: effectiveScale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: logicalSize.width,
                  height: logicalSize.height,
                  child: MediaQuery(
                    data: mediaQuery.copyWith(
                      size: logicalSize,
                      padding: _scaledInsets(
                        mediaQuery.padding,
                        effectiveScale,
                      ),
                      viewPadding: _scaledInsets(
                        mediaQuery.viewPadding,
                        effectiveScale,
                      ),
                      viewInsets: _scaledInsets(
                        mediaQuery.viewInsets,
                        effectiveScale,
                      ),
                      systemGestureInsets: _scaledInsets(
                        mediaQuery.systemGestureInsets,
                        effectiveScale,
                      ),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        scaledChild,
        Positioned(
          left: 14,
          bottom:
              mediaQuery.padding.bottom +
              (mediaQuery.size.width < 700 ? 82 : 14),
          child: const _AppScaleControls(),
        ),
      ],
    );
  }
}

class _AppScaleControls extends StatelessWidget {
  const _AppScaleControls();

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final options = AppThemeController.uiScaleOptions;
    final currentIndex = options.indexWhere(
      (option) => (option - controller.uiScale).abs() < 0.001,
    );
    final atMinimum = currentIndex <= 0;
    final atMaximum = currentIndex == options.length - 1;
    final colors = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      color: colors.surface.withValues(alpha: 0.96),
      shadowColor: Colors.black.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Уменьшить масштаб',
              onPressed: atMinimum
                  ? null
                  : () => controller.decreaseUiScale(),
              constraints: const BoxConstraints.tightFor(
                width: 38,
                height: 38,
              ),
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: const Icon(Icons.remove_rounded),
            ),
            Tooltip(
              message: 'Сбросить масштаб до 90%',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => controller.resetUiScale(),
                child: SizedBox(
                  width: 50,
                  height: 38,
                  child: Center(
                    child: Text(
                      '${controller.uiScalePercent}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Увеличить масштаб',
              onPressed: atMaximum
                  ? null
                  : () => controller.increaseUiScale(),
              constraints: const BoxConstraints.tightFor(
                width: 38,
                height: 38,
              ),
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
