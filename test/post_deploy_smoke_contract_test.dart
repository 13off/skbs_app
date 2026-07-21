import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web publication is followed by production smoke checks', () {
    final workflow = File(
      '.github/workflows/post-deploy-smoke.yml',
    ).readAsStringSync();

    expect(workflow, contains('workflow_run:'));
    expect(workflow, contains('Build and publish web'));
    expect(workflow, contains('downloads/web-source-commit.txt'));
    expect(workflow, contains('flutter_bootstrap.js?v='));
    expect(workflow, contains('manifest.json'));
    expect(workflow, contains('flutter_service_worker.js'));
    expect(workflow, contains('https://api.appstroy-web.ru'));
    expect(workflow, contains('/auth/v1/health'));
    expect(workflow, contains('/functions/v1/ai-operational-draft'));
    expect(workflow, contains('401|403'));
    expect(workflow, contains('actions/upload-artifact@v4'));
  });

  test('smoke workflow never receives production credentials', () {
    final workflow = File(
      '.github/workflows/post-deploy-smoke.yml',
    ).readAsStringSync();

    expect(workflow, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(workflow, isNot(contains('SUPABASE_ANON_KEY')));
    expect(workflow, isNot(contains('WEB_DEPLOY_TOKEN')));
    expect(workflow, contains('permissions:\n  contents: read'));
  });
}
