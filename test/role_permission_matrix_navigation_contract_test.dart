import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'developer constructor exposes role matrix without profession directory',
    () {
      final mainScreen = File(
        'lib/features/developer/presentation/developer_main_screen.dart',
      ).readAsStringSync();
      final systemScreen = File(
        'lib/features/developer/presentation/developer_system_screen.dart',
      ).readAsStringSync();
      final matrixScreen = File(
        'lib/features/developer/presentation/role_permission_matrix_screen.dart',
      ).readAsStringSync();

      expect(mainScreen, contains("label: 'Конструктор'"));
      expect(mainScreen, isNot(contains("label: 'Права'")));
      expect(systemScreen, contains("title: 'Роли и права'"));
      expect(systemScreen, contains('RolePermissionMatrixScreen'));
      expect(matrixScreen, contains("title: 'Матрица ролей'"));
      expect(
        matrixScreen,
        contains(
          "subtitle: 'Права компании и отдельные исключения по объектам'",
        ),
      );
      expect(matrixScreen, isNot(contains('Справочник профессий')));
      expect(matrixScreen, isNot(contains('Создать профессию')));
    },
  );
}
