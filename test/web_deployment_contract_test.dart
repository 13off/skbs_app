import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every main push publishes only a clean web snapshot', () {
    final deployWorkflow =
        File('.github/workflows/deploy-web.yml').readAsStringSync();

    expect(deployWorkflow, contains('push:'));
    expect(deployWorkflow, contains('- main'));
    expect(deployWorkflow, isNot(contains('paths:')));
    expect(deployWorkflow, contains('workflow_dispatch:'));
    expect(deployWorkflow, contains('repository: 13off/appstroy-web-deploy'));
    expect(deployWorkflow, contains('--base-href /appstroy-web-deploy/'));
    expect(deployWorkflow, contains('cp -R ../skbs_app/build/web/. ./'));
    expect(deployWorkflow, contains('git checkout --orphan deploy-snapshot'));
    expect(deployWorkflow, contains('git push --force-with-lease='));
    expect(deployWorkflow, contains("-name '*.dart'"));
    expect(deployWorkflow, contains("-name '*.map'"));
    expect(deployWorkflow, contains("-name '*.sql'"));
    expect(deployWorkflow, contains('test ! -e downloads'));
    expect(deployWorkflow, isNot(contains('downloads/web-source-commit.txt')));
    expect(deployWorkflow, isNot(contains('downloads/web-build.log')));
  });

  test('manual and release requests use the same checked deployment', () {
    for (final path in [
      '.github/workflows/ensure-web-current.yml',
      '.github/workflows/build-pwa-release.yml',
    ]) {
      final workflow = File(path).readAsStringSync();
      expect(workflow, contains('workflow_dispatch:'));
      expect(workflow, contains('github.rest.actions.createWorkflowDispatch'));
      expect(workflow, contains("workflow_id: 'deploy-web.yml'"));
      expect(workflow, contains("ref: 'main'"));
      expect(workflow, isNot(contains('git push')));
    }
  });
}
