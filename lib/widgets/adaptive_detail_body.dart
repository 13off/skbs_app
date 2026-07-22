import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Единая компоновка для вторичных рабочих экранов.
/// На web/PWA использует нормальную ширину рабочего стола, на телефоне
/// сохраняет компактную вертикальную компоновку.
class AdaptiveDetailBody extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double desktopMaxWidth;
  final double mobileMaxWidth;
  final EdgeInsets? desktopPadding;
  final EdgeInsets? mobilePadding;

  const AdaptiveDetailBody({
    super.key,
    required this.children,
    this.onRefresh,
    this.desktopMaxWidth = 1180,
    this.mobileMaxWidth = 720,
    this.desktopPadding,
    this.mobilePadding,
  });

  static bool isDesktop(BuildContext context, {double breakpoint = 820}) {
    return kIsWeb && MediaQuery.sizeOf(context).width >= breakpoint;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = kIsWeb && constraints.maxWidth >= 820;
        final content = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: desktop
              ? (desktopPadding ?? const EdgeInsets.fromLTRB(28, 22, 28, 120))
              : (mobilePadding ?? const EdgeInsets.fromLTRB(16, 16, 16, 120)),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: desktop ? desktopMaxWidth : mobileMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        );

        final refresh = onRefresh;
        if (refresh == null) return content;
        return RefreshIndicator(onRefresh: refresh, child: content);
      },
    );
  }
}
