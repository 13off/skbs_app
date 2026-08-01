import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('procurement role opens its dedicated five-tab platform', () {
    final profile = File(
      'lib/features/auth/models/app_user_profile.dart',
    ).readAsStringSync();
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final shell = File(
      'lib/features/procurement/presentation/procurement_main_screen.dart',
    ).readAsStringSync();

    expect(profile, contains("role == 'procurement'"));
    expect(profile, contains("return 'Снабженец'"));
    expect(main, contains('ProcurementMainScreen(profile: profile)'));
    expect(shell, contains('static const int pageCount = 5'));
    for (final label in <String>[
      "label: 'Сегодня'",
      "label: 'Заявки'",
      "label: 'Поставщики'",
      "label: 'Доставки'",
      "label: 'Профиль'",
    ]) {
      expect(shell, contains(label));
    }
  });

  test('procurement data has tenant RLS and guarded workflow RPCs', () {
    final schema = File(
      'supabase/migrations/20260801111702_procurement_workflow_schema.sql',
    ).readAsStringSync();
    final operations = File(
      'supabase/migrations/20260801111742_procurement_workflow_operations.sql',
    ).readAsStringSync();

    expect(
      schema,
      contains('create table if not exists public.procurement_requests'),
    );
    expect(
      schema,
      contains('create table if not exists public.procurement_suppliers'),
    );
    expect(schema, contains('enable row level security'));
    expect(
      schema,
      contains("current_user_has_permission('procurement.requests.view')"),
    );
    expect(operations, contains('public.save_procurement_request'));
    expect(operations, contains('public.set_procurement_request_status'));
    expect(
      operations,
      contains("v_request.status='in_delivery' and v_next='delivered'"),
    );
  });

  test('procurement screens use the shared app data channel', () {
    final sync = File('lib/data/app_data_sync.dart').readAsStringSync();
    final repository = File(
      'lib/features/procurement/data/procurement_repository.dart',
    ).readAsStringSync();

    expect(sync, contains('procurement,'));
    expect(sync, contains("case 'procurement_requests':"));
    expect(repository, contains('AppDataDomain.procurement'));
  });

  test('role preview exposes procurement without changing server identity', () {
    final controller = File(
      'lib/features/role_preview/role_preview_controller.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/role_preview/role_preview_screen.dart',
    ).readAsStringSync();

    expect(controller, contains("RolePreviewState(role: 'procurement')"));
    expect(screen, contains("title: 'Снабженец'"));
    expect(screen, contains('RolePreviewController.showProcurement'));
  });

  test('procurement users can be invited from mobile and desktop', () {
    final mobile = File(
      'lib/features/company/presentation/mobile_company_management_screen.dart',
    ).readAsStringSync();
    final desktop = File(
      'lib/features/company/presentation/desktop_company_user_dialogs.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/invite-company-member-core/index.ts',
    ).readAsStringSync();
    final companyRepository = File(
      'lib/features/company/data/company_repository.dart',
    ).readAsStringSync();

    for (final source in <String>[mobile, desktop, edge]) {
      expect(source, contains('procurement'));
    }
    expect(mobile, contains("child: Text('Снабженец')"));
    expect(desktop, contains("child: Text('Снабженец')"));
    expect(companyRepository, contains("case 'procurement':"));
  });
}
