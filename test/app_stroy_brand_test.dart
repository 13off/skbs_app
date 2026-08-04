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
    await tester.pump(const Duration(milliseconds: 2400));

    expect(find.text('AppСтрой'), findsOneWidget);
    expect(find.text('планируй. строй. управляй.'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('логотип работает в тёмной теме', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(child: AppStroyBrandIcon(size: 96)),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });

  test('запуск и загрузка используют единый фирменный экран', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final loadingSource = File(
      'lib/widgets/premium_surfaces_v3.dart',
    ).readAsStringSync();
    final brandSource = File(
      'lib/widgets/app_stroy_brand.dart',
    ).readAsStringSync();

    expect(mainSource, contains('AppStroyLaunchGate(child: AuthGate())'));
    expect(loadingSource, contains('AppStroyBrandStage('));
    expect(brandSource, contains("'планируй. строй. управляй.'"));
    expect(brandSource, contains('widthFactor: textProgress'));
    expect(brandSource, contains('scale: 0.12 + (0.88 * logoProgress)'));
  });
}
