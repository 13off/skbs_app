import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skbs_app/app/app_scale_viewport.dart';
import 'package:skbs_app/features/whats_new/presentation/role_aware_whats_new_gate.dart';
import 'package:skbs_app/models/app_user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop-scaled whats new receives pointer taps', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const profile = AppUserProfile(
      id: 'desktop-admin',
      email: 'admin@appstroy.test',
      fullName: 'Администратор',
      role: 'admin',
      objectName: '',
      activeCompanyId: 'company-test',
      isActive: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AppScaleViewport(
          scale: 1,
          child: WhatsNewGate(
            profile: profile,
            child: Scaffold(body: Text('Рабочий экран')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Что нового в AppСтрой'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);

    await tester.tap(find.text('Готово'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Что нового в AppСтрой'), findsNothing);
    expect(find.text('Рабочий экран'), findsOneWidget);
  });
}
