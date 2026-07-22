import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('developer platform exposes role matrix without profession directory', () {
    final mainScreen = File(
      'lib/features/developer/presentation/developer_main_screen.dart',
    ).readAsStringSync();
    final matrixScreen = File(
      'lib/features/developer/presentation/role_permission_matrix_screen.dart',
    ).readAsStringSync();

    expect(mainScreen, contains("label: 'Права'"));
    expect(mainScreen, contains('RolePermissionMatrixScreen'));
    expect(matrixScreen, contains("title: 'Матрица ролей'"));
    expect(matrixScreen, contains("subtitle: 'Права компании и отдельные исключения по объектам'"));
    expect(matrixScreen, isNot(contains('Справочник профессий')));
    expect(matrixScreen, isNot(contains('Создать профессию')));
  });
}
