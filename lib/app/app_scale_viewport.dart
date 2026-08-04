import 'package:flutter/material.dart';

/// Масштабирует весь Flutter-интерфейс, а не только текст.
///
/// Значение 100% соответствует новому базовому размеру интерфейса. Визуально
/// это тот же размер, который до перекалибровки показывался на 80%.
/// Остальные значения остаются относительными: 80% действительно уменьшает
/// интерфейс ещё на 20%, а 120% увеличивает новую базу на 20%.
class AppScaleViewport extends StatelessWidget {
  final double scale;
  final Widget child;

  const AppScaleViewport({super.key, required this.scale, required this.child});

  static const double _designCalibration = 0.80;

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
    final selectedScale = scale.clamp(0.80, 1.20).toDouble();
    final effectiveScale = selectedScale * _designCalibration;

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
            width: mediaQuery.size.width / effectiveScale,
            height: mediaQuery.size.height / effectiveScale,
            child: MediaQuery(
              data: mediaQuery.copyWith(
                size: Size(
                  mediaQuery.size.width / effectiveScale,
                  mediaQuery.size.height / effectiveScale,
                ),
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
