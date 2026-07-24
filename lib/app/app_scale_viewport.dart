import 'package:flutter/material.dart';

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
    if ((effectiveScale - 1).abs() < 0.001) return child;

    final logicalSize = Size(
      mediaQuery.size.width / effectiveScale,
      mediaQuery.size.height / effectiveScale,
    );

    return ClipRect(
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
                padding: _scaledInsets(mediaQuery.padding, effectiveScale),
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
  }
}
