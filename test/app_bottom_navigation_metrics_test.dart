import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/app/app_ui_tokens.dart';

void main() {
  testWidgets('iPhone safe area is included in bottom navigation clearance', (
    tester,
  ) async {
    late double navigationHeight;
    late double actionBottom;
    late double contentBottom;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              navigationHeight = AppUi.bottomNavigationHeight(context);
              actionBottom = AppUi.bottomActionOffset(context);
              contentBottom = AppUi.bottomActionContentPadding(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(navigationHeight, 128);
    expect(actionBottom, 136);
    expect(contentBottom, 210);
  });

  testWidgets('Android inset changes the same shared calculation', (
    tester,
  ) async {
    late double navigationHeight;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(412, 915),
          viewPadding: EdgeInsets.only(bottom: 24),
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              navigationHeight = AppUi.bottomNavigationHeight(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(navigationHeight, 118);
  });
}
