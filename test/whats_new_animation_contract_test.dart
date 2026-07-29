import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('what is new covers the full update with animated slides', () {
    final source = File(
      'lib/features/whats_new/presentation/whats_new_gate.dart',
    ).readAsStringSync();

    expect(source, contains('PageView.builder'));
    expect(source, contains('Icons.arrow_back_rounded'));
    expect(source, contains('Icons.arrow_forward_rounded'));
    expect(source, contains('после Android 1.1.0+2'));
    expect(source, contains('_RolePlatformsDemo'));
    expect(source, contains('_DispatcherDemo'));
    expect(source, contains('_ReportCenterDemo'));
    expect(source, contains('_AiActionsDemo'));
    expect(source, contains('_DocumentsDemo'));
    expect(source, contains('_PipelineDemo'));
    expect(source, contains('_ChecklistDemo'));
    expect(source, contains('_DeveloperControlsDemo'));
    expect(source, contains('_ContributionDemo'));
    expect(source, contains('_NotificationsDemo'));
    expect(source, contains('_ThemeToggleDemo'));
    expect(source, contains('_EmployeeCabinetDemo'));
    expect(source, contains('disableAnimations'));
    expect(
      source,
      contains('mobile-2026-07-29-full-since-1.1.0+2-v1'),
    );
  });
}
