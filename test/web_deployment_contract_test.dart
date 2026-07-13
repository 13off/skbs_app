import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web deployment runs on source changes and repairs missed bot pushes', () {
    final deployWorkflow = File(
      '.github/workflows/deploy-web.yml',
    ).readAsStringSync();
    final watchdogWorkflow = File(
      '.github/workflows/ensure-web-current.yml',
    ).readAsStringSync();

    expect(deployWorkflow, contains('push:'));
    expect(deployWorkflow, contains('- lib/**'));
    expect(deployWorkflow, contains('- test/**'));
    expect(deployWorkflow, contains('workflow_dispatch:'));
    expect(deployWorkflow, contains('downloads/web-source-commit.txt'));

    expect(watchdogWorkflow, contains("cron: '*/5 * * * *'"));
    expect(watchdogWorkflow, contains('fetch-depth: 0'));
    expect(watchdogWorkflow, contains('web-source-commit.txt'));
    expect(watchdogWorkflow, contains('git -C skbs_app diff --quiet'));
    expect(
      watchdogWorkflow,
      contains('actions/workflows/deploy-web.yml/dispatches'),
    );
  });
}
