import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/widgets/app_stroy_brand.dart';

void main() {
  testWidgets('заставка показывает утверждённое название и слоган', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppStroyBrandStage())),
    );
    await tester.pump(const Duration(milliseconds: 2450));

    expect(find.text('AppСтрой'), findsOneWidget);
    expect(find.text('планируй • строй • управляй'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('логотип работает в тёмной теме без квадратной картинки', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(child: AppStroyBrandIcon(size: 120)),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Image), findsNothing);
  });

  test('запуск использует одну заставку с ростом трёх зданий', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final loadingSource = File(
      'lib/widgets/premium_surfaces_v3.dart',
    ).readAsStringSync();
    final brandSource = File(
      'lib/widgets/app_stroy_brand.dart',
    ).readAsStringSync();
    final webSource = File('web/index.html').readAsStringSync();

    expect(mainSource, contains('AppStroyLaunchGate(child: AuthGate())'));
    expect(loadingSource, contains('AppStroyBrandStage('));
    expect(brandSource, contains("'планируй • строй • управляй'"));
    expect(brandSource, contains('widthFactor: textProgress'));
    expect(brandSource, contains('leftTower'));
    expect(brandSource, contains('centerTower'));
    expect(brandSource, contains('rightTower'));
    expect(brandSource, contains('canvas.scale(1, progress)'));
    expect(webSource, isNot(contains('id="app-loader"')));
    expect(webSource, isNot(contains('logo-shell')));
  });
}
