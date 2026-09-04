import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../features/auth/data/user_repository.dart';
import '../features/developer/data/developer_policy_repository.dart';
import '../models/task_item_data.dart';
import 'app_data_sync.dart';
import 'offline_sync_service.dart';
import 'task_photo_models.dart';
import 'task_repository.dart';

/// Fast path for task creation when the browser already knows that it is
/// offline. It avoids waiting for a doomed HTTP request before showing the
/// freshly-created task in the foreman list.
class OfflineTaskCreateService {
  const OfflineTaskCreateService._();

  static bool get shouldQueueImmediately =>
      kIsWeb && html.window.navigator.onLine != true;

  static String _dateKey(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    final month = clean.month.toString().padLeft(2, '0');
    final day = clean.day.toString().padLeft(2, '0');
    return '${clean.year}-$month-$day';
  }

  static String _tasksSnapshotKey(DateTime date, String objectName) {
    return 'tasks::${_dateKey(date)}::${objectName.trim()}';
  }

  static String _draftSnapshotKey(String objectName) {
    return 'task_drafts::${objectName.trim()}';
  }

  static String _actorName() {
    final profileName = UserRepository.cachedProfile?.fullName.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;
    final email = UserRepository.currentUser?.email?.trim() ?? '';
    return email.isEmpty ? 'Пользователь' : email;
  }

  static Future<TaskItemData> queueTask(
    TaskItemData task, {
    required String objectName,
    required List<String> assigneeIds,
    required List<TaskPhotoFile> photos,
    bool isDraft = false,
    String? preferredId,
  }) async {
    final cleanObject = objectName.trim();
    final cleanPreferredId = preferredId?.trim() ?? '';
    final taskId = cleanPreferredId.isNotEmpty
        ? cleanPreferredId
        : OfflineSyncService.createLocalId();
    final policy = DeveloperPolicyRepository.policyForObjectSync(cleanObject);
    final localTask = task.copyWith(
      id: taskId,
      objectName: cleanObject,
      status: isDraft ? 'Запланировано' : task.status,
    );
    final cleanAssigneeIds = assigneeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final queuedPhotos = photos
        .map(
          (photo) => OfflineSyncService.serializePhoto(
            originalName: photo.originalName,
            contentType: photo.contentType,
            extension: photo.extension,
            bytes: photo.bytes,
            photoStage: 'before',
          ),
        )
        .toList(growable: false);

    // `is_draft` deliberately preserves the user's intended final state in
    // the payload. The database INSERT guard converts a final offline task to
    // a safe draft first; OfflineSyncService then publishes it only after
    // assignees, links and photos have been persisted.
    final row = <String, dynamic>{
      'id': taskId,
      'task_date': _dateKey(localTask.date),
      'object_name': cleanObject,
      'axes': localTask.axes,
      'work': localTask.work,
      'status': localTask.status,
      'not_done_comment': localTask.notDoneComment,
      'created_by': _actorName(),
      'created_by_user_id': Supabase.instance.client.auth.currentUser?.id,
      'is_draft': isDraft,
      'photo_requirements_enforced': policy.requireBeforePhoto,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await OfflineSyncService.enqueue(
      kind: 'task.create',
      dedupeKey: taskId,
      payload: <String, dynamic>{
        'id': taskId,
        'row': row,
        'assignee_ids': cleanAssigneeIds,
        'milestone_id': localTask.milestoneId,
        'checklist_item_id': localTask.checklistItemId,
        'photos': queuedPhotos,
      },
    );

    if (isDraft) {
      await _upsertTaskSnapshot(
        _draftSnapshotKey(cleanObject),
        localTask,
      );
    } else {
      await _upsertTaskSnapshot(
        _tasksSnapshotKey(localTask.date, cleanObject),
        localTask,
      );
    }

    // Task details must not lose local selections while the task is still in
    // the queue. These are the same snapshot keys used by TaskRepository.
    await OfflineSyncService.saveSnapshot(
      'task_assignee_ids::$taskId',
      cleanAssigneeIds,
    );
    await OfflineSyncService.saveSnapshot(
      'task_photos::$taskId',
      queuedPhotos
          .map(
            (photo) => <String, dynamic>{
              'id': photo['offline_id']?.toString() ?? '',
              'task_id': taskId,
              'storage_path': '',
              'original_name': photo['original_name']?.toString() ?? 'Фото',
              'photo_stage': 'before',
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
          )
          .toList(growable: false),
    );

    TaskRepository.clearTaskListCache();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.tasks},
      context: <String, dynamic>{
        'table': 'tasks',
        'task_id': taskId,
        'task_date': _dateKey(localTask.date),
        'object_name': cleanObject,
        'source': 'offline_task_create',
      },
    );
    return localTask;
  }

  static Future<void> _upsertTaskSnapshot(
    String snapshotKey,
    TaskItemData task,
  ) async {
    final raw = await OfflineSyncService.readSnapshot(snapshotKey);
    final rows = raw is List
        ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final taskId = task.id?.trim() ?? '';
    rows.removeWhere((row) => row['id']?.toString().trim() == taskId);
    rows.add(<String, dynamic>{
      ...task.toJson(),
      'creator': null,
      'last_editor': null,
    });
    await OfflineSyncService.saveSnapshot(snapshotKey, rows);
  }
}
