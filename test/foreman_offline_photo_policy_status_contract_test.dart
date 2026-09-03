import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void containsAll(String path, Iterable<String> fragments) {
  final contents = source(path);
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный offline-фрагмент "$fragment" отсутствует в $path',
    );
  }
}

void main() {
  test('правила объекта переживают offline restart', () {
    containsAll(
      'lib/features/developer/data/developer_policy_repository.dart',
      const [
        "import '../../../data/offline_sync_service.dart';",
        "'task_policy::",
        'OfflineSyncService.saveSnapshot(',
        'OfflineSyncService.readSnapshot(',
        'TaskPolicy.fromJson(Map<String, dynamic>.from(raw))',
        '_persistCenterPolicies(center)',
      ],
    );
  });

  test('iPhone PWA picker остаётся рабочим без сети', () {
    containsAll('lib/data/task_photo_browser_service.dart', const [
      'html.document.body?.append(input)',
      'html.window.onBlur.listen',
      'html.window.onFocus.listen',
      'filePickerTimeout',
      'input.remove()',
    ]);
  });

  test('фото до и после попадают в offline queue', () {
    containsAll(
      'lib/screens/task_details/task_details_photo_actions.dart',
      const [
        "kind: 'task.photos.add'",
        "dedupeKey: '${taskId.trim()}::\$photoStage'",
        'photoStage: photoStage',
        "text.contains('сеть')",
        "'Фото сохранено на устройстве и отправится при появлении сети'",
      ],
    );
    containsAll('lib/data/offline_sync_service.dart', const [
      "case 'task.photos.add':",
      "final stage = photo['photo_stage']?.toString() == 'after'",
      "client.storage.from('task-photos').uploadBinary(",
    ]);
    containsAll('lib/screens/task_details/task_details_sections.dart', const [
      "photo.storagePath.trim().isEmpty",
      "'Ожидает отправки'",
      'Icons.schedule_send_rounded',
    ]);
  });

  test('голосовая панель и скрытый автозапуск отключены', () {
    final view = source('lib/screens/task_create/task_create_view.dart');
    final loading = source('lib/screens/task_create/task_create_loading.dart');
    expect(view, isNot(contains('buildVoiceAssistantCard()')));
    expect(view, isNot(contains('Icons.mic_rounded')));
    expect(loading, isNot(contains('captureVoiceTask()')));
    expect(loading, isNot(contains('startVoiceImmediately')));
  });

  test('индикатор сети компактный и исчезает при нормальной работе', () {
    final status = source('lib/widgets/offline_sync_banner.dart');
    for (final fragment in const [
      'html.window.navigator.onLine',
      'html.window.onOnline.listen',
      'html.window.onOffline.listen',
      'final showIndicator =',
      '!_isOnline || state.isSyncing || state.pendingCount > 0',
      'Icons.signal_wifi_connected_no_internet_4_rounded',
      'CircularProgressIndicator(',
      'Данные отправляются на сервер',
      'будут автоматически отправлены на сервер после восстановления связи',
    ]) {
      expect(status, contains(fragment));
    }
    expect(status, isNot(contains('_OfflinePendingBanner')));
  });
}
