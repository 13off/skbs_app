import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GitHub Actions используют неизменяемые SHA', () {
    final workflows = Directory(
      '.github/workflows',
    ).listSync().whereType<File>().where((file) => file.path.endsWith('.yml'));
    final floatingRef = RegExp(
      r'uses:\s+[^\s#]+@(v\d+(?:\.\d+)*|main|master|latest)\b',
    );

    for (final workflow in workflows) {
      expect(
        workflow.readAsStringSync(),
        isNot(matches(floatingRef)),
        reason: workflow.path,
      );
    }
  });

  test('одноразовые workflows и триггер-файлы удалены', () {
    const removed = <String>[
      '.github/workflows/apply-pwa-layout-now.yml',
      '.github/workflows/diagnose-invite-route.yml',
      '.github/workflows/patch-flight-calendar-branch.yml',
      '.github/workflows/patch-payments-scope.yml',
      'tool/build_android_apk.trigger',
      'tool/build_ios_ipa.trigger',
      'tool/trigger_ios_navigation_build.txt',
      'release/candidate-editor-layout-lift-trigger-2.txt',
      'release/patch-flight-calendar-branch.txt',
    ];

    for (final path in removed) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });

  test('web shell не скрывает загрузчик до первого кадра', () {
    final index = File('web/index.html').readAsStringSync();

    expect(index, contains("window.addEventListener('flutter-first-frame'"));
    expect(index, isNot(contains('window.setTimeout(hideLoader, 4400)')));
    expect(index, contains("loader.dataset.timeout = 'true'"));
    expect(index, contains('Повторить запуск'));
  });

  test('web push принимает переходы только внутри приложения', () {
    final worker = File('web/appstroy-push-sw.js').readAsStringSync();

    expect(worker, contains('safeNotificationTarget'));
    expect(worker, contains('target.origin === root.origin'));
    expect(worker, contains('target.pathname.startsWith(rootPath)'));
  });

  test('правила hosting находятся в корне web', () {
    final headers = File('web/_headers').readAsStringSync();

    expect(File('web/_headers').existsSync(), isTrue);
    expect(File('web/_redirects').existsSync(), isTrue);
    expect(File('web/icons/_headers').existsSync(), isFalse);
    expect(File('web/icons/_redirects').existsSync(), isFalse);
    expect(headers, isNot(contains('max-age=31536000, immutable')));
    expect(headers, contains('max-age=3600, must-revalidate'));
  });

  test('production deploy автоматически запускается только из main', () {
    final workflow = File(
      '.github/workflows/deploy-supabase-proxy.yml',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(workflow, contains('workflow_dispatch:'));
    expect(
      workflow,
      contains('push:\n    branches:\n      - main\n    paths:'),
    );
  });
}
