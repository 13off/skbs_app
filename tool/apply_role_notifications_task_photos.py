from pathlib import Path
import re


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Pattern not found: {label} in {path}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


def regex_once(path: str, pattern: str, replacement: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'Regex pattern not found: {label} in {path}')
    file.write_text(updated, encoding='utf-8')


migration = 'supabase/migrations/20260718120000_role_notifications_and_task_photo_stages.sql'
replace_once(
    migration,
    """alter table public.tasks
  add column if not exists is_draft boolean not null default false,
  add column if not exists photo_requirements_enforced boolean not null default false,
  add column if not exists created_by_user_id uuid references auth.users(id) on delete set null;
""",
    """alter table public.tasks
  add column if not exists is_draft boolean not null default false,
  add column if not exists photo_requirements_enforced boolean not null default false,
  add column if not exists created_by_user_id uuid references auth.users(id) on delete set null;

alter table public.tasks
  alter column photo_requirements_enforced set default true;
""",
    'new tasks enforce photos by default',
)
replace_once(
    migration,
    "coalesce(new.entity_id, '') ~ '^[0-9a-fA-F-]{36}$'",
    "coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'",
    'strict task uuid filter',
)
replace_once(
    migration,
    """  if new.entity_type = 'tasks'
     and coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
     and exists (
       select 1 from public.tasks t
       where t.id = new.entity_id::uuid and t.is_draft
     ) then
    return null;
  end if;
""",
    """  if new.entity_type = 'tasks'
     and coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
     and exists (
       select 1 from public.tasks t
       where t.id = new.entity_id::uuid and t.is_draft
     ) then
    return null;
  end if;

  if new.entity_type in ('task_assignees','task_photos')
     and coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
     and exists (
       select 1
       from public.tasks t
       where t.is_draft
         and t.id = case
           when new.entity_type = 'task_assignees' then (
             select a.task_id from public.task_assignees a where a.id = new.entity_id::uuid
           )
           else (
             select p.task_id from public.task_photos p where p.id = new.entity_id::uuid
           )
         end
     ) then
    return null;
  end if;
""",
    'filter child draft notifications',
)
replace_once(
    migration,
    """drop policy if exists tasks_select_company_object on public.tasks;
create policy tasks_select_company_object
""",
    """drop policy if exists tasks_insert_company_object on public.tasks;
create policy tasks_insert_company_object
on public.tasks for insert to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
  and is_draft
  and photo_requirements_enforced
  and created_by_user_id = auth.uid()
  and (
    public.is_admin()
    or (public.is_foreman() and task_date = public.current_operational_date())
  )
);

drop policy if exists tasks_select_company_object on public.tasks;
create policy tasks_select_company_object
""",
    'require staged task inserts',
)

repo = 'lib/data/task_repository.dart'
replace_once(
    repo,
    """  final String originalName;
  final DateTime createdAt;

  const TaskPhotoData({
    required this.id,
    required this.taskId,
    required this.storagePath,
    required this.originalName,
    required this.createdAt,
  });
""",
    """  final String originalName;
  final String photoStage;
  final DateTime createdAt;

  const TaskPhotoData({
    required this.id,
    required this.taskId,
    required this.storagePath,
    required this.originalName,
    required this.photoStage,
    required this.createdAt,
  });

  bool get isBefore => photoStage == 'before';
  bool get isAfter => photoStage == 'after';
""",
    'task photo stage model',
)
replace_once(
    repo,
    """      originalName: json['original_name']?.toString() ?? 'Фото',
      createdAt:
""",
    """      originalName: json['original_name']?.toString() ?? 'Фото',
      photoStage: json['photo_stage']?.toString() == 'after'
          ? 'after'
          : 'before',
      createdAt:
""",
    'parse task photo stage',
)
replace_once(
    repo,
    """  static String safePhotoStoragePath({
    required String taskId,
    required TaskPhotoFile photo,
    required int index,
  }) {
""",
    """  static String safePhotoStoragePath({
    required String taskId,
    required String photoStage,
    required TaskPhotoFile photo,
    required int index,
  }) {
""",
    'photo path stage argument',
)
replace_once(
    repo,
    "return '$taskId/${timestamp}_$index.$extension';",
    "return '$taskId/$photoStage/${timestamp}_$index.$extension';",
    'photo path stage folder',
)
replace_once(
    repo,
    """          'not_done_comment': task.notDoneComment,
          'created_by': 'Илья',
""",
    """          'not_done_comment': task.notDoneComment,
          'created_by': 'Илья',
          'created_by_user_id': _client.auth.currentUser?.id,
          'is_draft': true,
          'photo_requirements_enforced': true,
""",
    'create staged task draft',
)
regex_once(
    repo,
    r"  static Future<TaskItemData> addTaskWithDetails\(.*?\n  static Future<void> updateTask",
    """  static Future<TaskItemData> addTaskWithDetails(
    TaskItemData task, {
    required String objectName,
    required List<String> assigneeIds,
    required List<TaskPhotoFile> photos,
  }) async {
    if (photos.isEmpty) {
      throw Exception('Добавьте хотя бы одно фото «До»');
    }

    final createdTask = await addTask(task, objectName: objectName);
    final taskId = createdTask.id;
    if (taskId == null || taskId.isEmpty) return createdTask;

    try {
      await saveTaskAssignees(taskId: taskId, assigneeIds: assigneeIds);
      await uploadPhotosForTask(
        taskId: taskId,
        photos: photos,
        photoStage: 'before',
      );

      final finalized = await _client
          .from('tasks')
          .update({
            'is_draft': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', taskId)
          .select(
            'id, task_date, object_name, axes, work, status, not_done_comment',
          )
          .single();

      final createdWithLink = task.copyWith(id: taskId);
      await saveTaskMilestoneLink(createdWithLink);
      clearTaskListCache();
      final result = TaskItemData.fromSupabase(finalized).copyWith(
        milestoneId: task.milestoneId,
        checklistItemId: task.checklistItemId,
      );
      _notifyTasksChanged(result);
      return result;
    } catch (_) {
      try {
        await _client.from('tasks').delete().eq('id', taskId);
      } catch (_) {
        // Черновик будет скрыт и может быть удалён служебной очисткой.
      }
      rethrow;
    }
  }

  static Future<void> updateTask""",
    'atomic task creation with before photo',
)
replace_once(
    repo,
    """        .select('id, task_id, storage_path, original_name, created_at')
""",
    """        .select(
          'id, task_id, storage_path, original_name, photo_stage, created_at',
        )
""",
    'fetch task photo stage',
)
replace_once(
    repo,
    """  static Future<List<TaskPhotoData>> uploadPhotosForTask({
    required String taskId,
    required List<TaskPhotoFile> photos,
  }) async {
    if (photos.isEmpty) return <TaskPhotoData>[];

    final rowsToInsert = <Map<String, String>>[];

    for (var i = 0; i < photos.length; i++) {
""",
    """  static Future<List<TaskPhotoData>> uploadPhotosForTask({
    required String taskId,
    required List<TaskPhotoFile> photos,
    required String photoStage,
  }) async {
    if (photos.isEmpty) return <TaskPhotoData>[];
    if (photoStage != 'before' && photoStage != 'after') {
      throw ArgumentError.value(photoStage, 'photoStage');
    }

    final rowsToInsert = <Map<String, String>>[];
    final uploadedPaths = <String>[];

    try {
      for (var i = 0; i < photos.length; i++) {
""",
    'upload task photo stage signature',
)
replace_once(
    repo,
    """      final path = safePhotoStoragePath(
        taskId: taskId,
        photo: photo,
        index: i + 1,
      );
""",
    """        final path = safePhotoStoragePath(
          taskId: taskId,
          photoStage: photoStage,
          photo: photo,
          index: i + 1,
        );
""",
    'stage storage path call',
)
replace_once(
    repo,
    """      rowsToInsert.add({
        'task_id': taskId,
        'storage_path': path,
        'original_name': photo.originalName,
      });
    }

    final rows = await _client
        .from('task_photos')
        .insert(rowsToInsert)
        .select('id, task_id, storage_path, original_name, created_at');

    return rows.map<TaskPhotoData>((row) {
      return TaskPhotoData.fromSupabase(row);
    }).toList();
  }
""",
    """        uploadedPaths.add(path);
        rowsToInsert.add({
          'task_id': taskId,
          'storage_path': path,
          'original_name': photo.originalName,
          'photo_stage': photoStage,
        });
      }

      final rows = await _client
          .from('task_photos')
          .insert(rowsToInsert)
          .select(
            'id, task_id, storage_path, original_name, photo_stage, created_at',
          );

      return rows.map<TaskPhotoData>((row) {
        return TaskPhotoData.fromSupabase(row);
      }).toList();
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _client.storage.from(taskPhotosBucket).remove(uploadedPaths);
        } catch (_) {
          // Служебная очистка удалит оставшиеся файлы.
        }
      }
      rethrow;
    }
  }
""",
    'persist stage and cleanup uploads',
)

add = 'lib/screens/add_task_screen.dart'
replace_once(
    add,
    """    if (linkedToGoal && (selectedChecklistItemId == null || goalWork.isEmpty)) {
""",
    """    if (selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно фото «До»')),
      );
      return;
    }

    if (linkedToGoal && (selectedChecklistItemId == null || goalWork.isEmpty)) {
""",
    'require before photo in create form',
)
replace_once(add, "'Фото к задаче'", "'Фото «До» — обязательно'", 'before photo title')
replace_once(
    add,
    "'Можно прикрепить несколько фото: JPG, PNG, WEBP.'",
    "'Без фото «До» задача не будет создана. Можно прикрепить несколько снимков.'",
    'before photo help',
)
replace_once(add, "const Text('Добавить фото')", "const Text('Добавить фото «До»')", 'before photo button')

legacy = 'lib/screens/task_details_legacy_screen.dart'
replace_once(
    legacy,
    """  Future<void> addPhotos() async {
""",
    """  Future<void> addPhotos(String photoStage) async {
""",
    'details add photo stage argument',
)
replace_once(
    legacy,
    """      final uploadedPhotos = await TaskRepository.uploadPhotosForTask(
        taskId: taskId,
        photos: pickedPhotos,
      );
""",
    """      final uploadedPhotos = await TaskRepository.uploadPhotosForTask(
        taskId: taskId,
        photos: pickedPhotos,
        photoStage: photoStage,
      );
""",
    'details upload stage',
)
replace_once(
    legacy,
    """      ).showSnackBar(const SnackBar(content: Text('Фото добавлены')));
""",
    """      ).showSnackBar(
        SnackBar(
          content: Text(
            photoStage == 'before'
                ? 'Фото «До» добавлены'
                : 'Фото «После» добавлены',
          ),
        ),
      );
""",
    'details stage success',
)
replace_once(
    legacy,
    """    if (selectedStatus != 'Выполнено' &&
""",
    """    if (selectedStatus == 'Выполнено' &&
        !photos.any((photo) => photo.isAfter)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одно фото «После»'),
        ),
      );
      return;
    }

    if (selectedStatus != 'Выполнено' &&
""",
    'details require after photo',
)
regex_once(
    legacy,
    r"  Widget buildPhotosBlock\(\) \{.*?\n  \}\n\n  @override\n  Widget build",
    """  Widget buildPhotosBlock({
    required String photoStage,
    required String title,
    required String emptyText,
  }) {
    final stagePhotos = photos
        .where((photo) => photo.photoStage == photoStage)
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            photoStage == 'before'
                ? 'Обязательное состояние участка перед началом работ.'
                : 'Обязательный результат после завершения работ.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isPickingPhotos || !canEdit
                  ? null
                  : () => addPhotos(photoStage),
              icon: isPickingPhotos
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text('Добавить $title'),
            ),
          ),
          if (stagePhotos.isEmpty) ...[
            const SizedBox(height: 12),
            Text(emptyText),
          ] else ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stagePhotos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                return buildPhotoTile(stagePhotos[index]);
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build""",
    'split before and after photo blocks',
)
replace_once(
    legacy,
    """                : (value) {
                    setState(() {
                      selectedStatus = value ? 'Выполнено' : 'Запланировано';

                      if (value) {
                        notDoneCommentController.clear();
                      }
                    });
                  },
""",
    """                : (value) {
                    if (value && !photos.any((photo) => photo.isAfter)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Сначала добавьте хотя бы одно фото «После»',
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      selectedStatus = value ? 'Выполнено' : 'Запланировано';

                      if (value) {
                        notDoneCommentController.clear();
                      }
                    });
                  },
""",
    'block completion switch without after photo',
)
replace_once(
    legacy,
    """          buildPhotosBlock(),
""",
    """          buildPhotosBlock(
            photoStage: 'before',
            title: 'Фото «До»',
            emptyText: 'Обязательное фото «До» пока не прикреплено',
          ),
          const SizedBox(height: 14),
          buildPhotosBlock(
            photoStage: 'after',
            title: 'Фото «После»',
            emptyText: 'Без фото «После» задачу нельзя выполнить',
          ),
""",
    'render before and after blocks',
)

notifications = 'lib/data/notification_repository.dart'
replace_once(
    notifications,
    """  final String targetRole;
  final bool requiresAction;
""",
    """  final String targetRole;
  final String sourceRole;
  final bool requiresAction;
""",
    'notification source role field',
)
replace_once(
    notifications,
    """    this.targetRole = '',
    this.requiresAction = false,
""",
    """    this.targetRole = '',
    this.sourceRole = 'admin',
    this.requiresAction = false,
""",
    'notification source role constructor',
)
replace_once(
    notifications,
    """      targetRole: json['target_role']?.toString() ?? '',
      requiresAction: json['requires_action'] == true,
""",
    """      targetRole: json['target_role']?.toString() ?? '',
      sourceRole: json['source_role']?.toString() ?? 'admin',
      requiresAction: json['requires_action'] == true,
""",
    'parse notification source role',
)
replace_once(
    notifications,
    """    'legal_matter',
  ];
""",
    """    'legal_matter',
    'foreman_reminder',
    'brigade_photo',
  ];

  static const List<String> allNotificationRoles = <String>[
    'admin',
    'foreman',
    'hr',
    'accountant',
    'lawyer',
  ];

  static const Map<String, String> notificationRoleTitles = <String, String>{
    'admin': 'Руководитель',
    'foreman': 'Прораб',
    'hr': 'HR-менеджер',
    'accountant': 'Бухгалтер',
    'lawyer': 'Юрист',
  };
""",
    'notification role catalog',
)
replace_once(
    notifications,
    """  static DateTime? _parseDate(dynamic value) {
""",
    """  static Future<Set<String>> fetchSelectedNotificationRoles() async {
    final data = await _client.rpc('get_my_notification_role_preferences');
    if (data is List) {
      return data
          .map((value) => value.toString())
          .where(allNotificationRoles.contains)
          .toSet();
    }
    return allNotificationRoles.toSet();
  }

  static Future<Set<String>> saveSelectedNotificationRoles(
    Iterable<String> roles,
  ) async {
    final clean = roles
        .map((role) => role.trim())
        .where(allNotificationRoles.contains)
        .toSet()
        .toList();
    final data = await _client.rpc(
      'set_my_notification_role_preferences',
      params: <String, dynamic>{'p_roles': clean},
    );
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.notifications},
      context: const <String, dynamic>{
        'table': 'notification_role_preferences',
      },
    );
    if (data is List) {
      return data
          .map((value) => value.toString())
          .where(allNotificationRoles.contains)
          .toSet();
    }
    return clean.toSet();
  }

  static DateTime? _parseDate(dynamic value) {
""",
    'notification role preferences repository',
)
replace_once(
    notifications,
    "id, title, body, actor_user_id, actor_name, actor_email, object_name, entity_type, entity_id, target_user_id, target_role, requires_action, due_at, priority, created_at",
    "id, title, body, actor_user_id, actor_name, actor_email, object_name, entity_type, entity_id, target_user_id, target_role, source_role, requires_action, due_at, priority, created_at",
    'select notification source role',
)

settings = Path('lib/screens/push_notification_settings_screen.dart')
settings.write_text(r'''import 'package:flutter/material.dart';

import '../data/notification_repository.dart';
import '../data/user_repository.dart';
import '../services/push_notification_service.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';

class PushNotificationSettingsScreen extends StatefulWidget {
  const PushNotificationSettingsScreen({super.key});

  @override
  State<PushNotificationSettingsScreen> createState() =>
      _PushNotificationSettingsScreenState();
}

class _PushNotificationSettingsScreenState
    extends State<PushNotificationSettingsScreen> {
  bool loadingRoles = true;
  bool savingRoles = false;
  bool isManager = false;
  Set<String> selectedRoles = NotificationRepository.allNotificationRoles.toSet();
  String? roleError;

  @override
  void initState() {
    super.initState();
    loadRolePreferences();
  }

  Future<void> loadRolePreferences() async {
    try {
      final profile = await UserRepository.fetchCurrentProfile();
      final manager = profile?.isAdmin == true || profile?.actualRole == 'admin';
      final roles = manager
          ? await NotificationRepository.fetchSelectedNotificationRoles()
          : <String>{profile?.role ?? ''};
      if (!mounted) return;
      setState(() {
        isManager = manager;
        selectedRoles = roles;
        loadingRoles = false;
        roleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingRoles = false;
        roleError = 'Не удалось загрузить роли уведомлений: $error';
      });
    }
  }

  Future<void> saveRolePreferences() async {
    if (!isManager || savingRoles) return;
    setState(() {
      savingRoles = true;
      roleError = null;
    });
    try {
      final saved = await NotificationRepository.saveSelectedNotificationRoles(
        selectedRoles,
      );
      if (!mounted) return;
      setState(() => selectedRoles = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Роли для колокольчика и push сохранены'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => roleError = 'Не удалось сохранить роли: $error');
    } finally {
      if (mounted) setState(() => savingRoles = false);
    }
  }

  String permissionLabel(PushPermissionState permission) {
    switch (permission) {
      case PushPermissionState.authorized:
        return 'Разрешены';
      case PushPermissionState.provisional:
        return 'Разрешены предварительно';
      case PushPermissionState.denied:
        return 'Запрещены в системе';
      case PushPermissionState.notDetermined:
        return 'Разрешение ещё не запрошено';
      case PushPermissionState.unknown:
        return 'Статус пока неизвестен';
    }
  }

  Widget rolePreferencesCard() {
    if (loadingRoles) {
      return const PremiumWorkCard(
        radius: 26,
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!isManager) {
      return const PremiumWorkCard(
        radius: 26,
        padding: EdgeInsets.all(20),
        child: Text(
          'Уведомления автоматически ограничены вашей ролью и доступными объектами.',
          style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
        ),
      );
    }

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Какие роли учитывать',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Руководителю по умолчанию доступны все направления. Выбор одинаково действует на внутренний колокольчик и системные push.',
            style: TextStyle(color: Color(0xFF5F646A), height: 1.4),
          ),
          const SizedBox(height: 12),
          ...NotificationRepository.allNotificationRoles.map((role) {
            final title = NotificationRepository.notificationRoleTitles[role] ?? role;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selectedRoles.contains(role),
              onChanged: savingRoles
                  ? null
                  : (value) {
                      setState(() {
                        if (value == true) {
                          selectedRoles.add(role);
                        } else {
                          selectedRoles.remove(role);
                        }
                      });
                    },
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: savingRoles ? null : saveRolePreferences,
            icon: savingRoles
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Сохранить роли'),
          ),
          if (roleError != null) ...[
            const SizedBox(height: 10),
            Text(roleError!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Push-уведомления'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppPage(
        title: 'Уведомления',
        subtitle:
            'Настройки системных push и ролевой ленты внутреннего колокольчика.',
        child: ValueListenableBuilder<PushNotificationSnapshot>(
          valueListenable: PushNotificationService.state,
          builder: (context, snapshot, _) {
            return Column(
              children: [
                PremiumWorkCard(
                  radius: 26,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: snapshot.enabled,
                        onChanged: snapshot.busy
                            ? null
                            : PushNotificationService.setEnabled,
                        title: const Text(
                          'Получать push на этом устройстве',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: const Text(
                          'Настройка относится только к текущему браузеру или телефону.',
                        ),
                      ),
                      const Divider(height: 28),
                      _StatusRow(
                        label: 'Канал',
                        value: snapshot.configured
                            ? 'Системная доставка доступна'
                            : 'Нужна установка приложения или поддерживаемый браузер',
                      ),
                      const SizedBox(height: 10),
                      _StatusRow(
                        label: 'Разрешение',
                        value: permissionLabel(snapshot.permission),
                      ),
                      const SizedBox(height: 10),
                      _StatusRow(
                        label: 'Устройство',
                        value: snapshot.registered
                            ? 'Подписка зарегистрирована'
                            : 'Подписка не зарегистрирована',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                rolePreferencesCard(),
                const SizedBox(height: 12),
                PremiumWorkCard(
                  radius: 26,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        snapshot.message,
                        style: const TextStyle(
                          color: Color(0xFF5F646A),
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: snapshot.busy || !snapshot.enabled
                            ? null
                            : () {
                                PushNotificationService.syncForCurrentSession(
                                  requestPermission: true,
                                );
                              },
                        icon: snapshot.busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.notifications_active_rounded),
                        label: Text(
                          snapshot.registered
                              ? 'Обновить регистрацию'
                              : 'Разрешить и подключить',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const PremiumWorkCard(
                  radius: 26,
                  padding: EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'На iPhone AppСтрой должен быть добавлен на экран «Домой» и открыт с иконки. Подписка привязывается к вашему пользователю и активной компании. При выходе устройство отключается.',
                          style: TextStyle(
                            color: Color(0xFF5F646A),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A8F94),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
''', encoding='utf-8')

push = 'supabase/functions/dispatch-push-job/index.ts'
replace_once(
    push,
    '  target_role: string | null;\n}',
    '  target_role: string | null;\n  source_role: string;\n}',
    'push notification source role interface',
)
replace_once(
    push,
    '  "legal_matter",\n]);',
    '  "legal_matter",\n  "foreman_reminder",\n  "brigade_photo",\n]);',
    'push foreman reminder types',
)
replace_once(
    push,
    """function normalize(value: unknown) {
  return String(value ?? '').trim().toLocaleLowerCase('ru');
}
""".replace("'", '"'),
    """function normalize(value: unknown) {
  return String(value ?? '').trim().toLocaleLowerCase('ru');
}

function normalizeRole(value: unknown) {
  const role = normalize(value);
  if (role === 'owner') return 'admin';
  if (role === 'accounting') return 'accountant';
  return ['admin', 'foreman', 'hr', 'accountant', 'lawyer'].includes(role)
    ? role
    : 'admin';
}
""".replace("'", '"'),
    'push normalize role',
)
replace_once(
    push,
    '"id,company_id,title,body,actor_user_id,object_name,entity_type,entity_id,target_user_id,target_role",',
    '"id,company_id,title,body,actor_user_id,object_name,entity_type,entity_id,target_user_id,target_role,source_role",',
    'push select source role',
)
regex_once(
    push,
    r"    let membershipsQuery = admin.*?\n    if \(recipientIds.size === 0\) \{",
    """    let membershipsQuery = admin
      .from("company_memberships")
      .select("user_id,role")
      .eq("company_id", notification.company_id)
      .eq("is_active", true);
    if (notification.actor_user_id) {
      membershipsQuery = membershipsQuery.neq(
        "user_id",
        notification.actor_user_id,
      );
    }
    const { data: memberships, error: membershipsError } =
      await membershipsQuery;
    if (membershipsError) throw membershipsError;

    const { data: preferenceRows, error: preferenceError } = await admin
      .from("notification_role_preferences")
      .select("user_id,selected_roles")
      .eq("company_id", notification.company_id);
    if (preferenceError) throw preferenceError;
    const adminPreferences = new Map<string, Set<string>>();
    for (const row of preferenceRows ?? []) {
      const selected = Array.isArray(row.selected_roles)
        ? row.selected_roles.map(normalizeRole)
        : ["admin", "foreman", "hr", "accountant", "lawyer"];
      adminPreferences.set(String(row.user_id), new Set(selected));
    }

    const sourceRole = normalizeRole(
      notification.source_role || notification.target_role || "admin",
    );
    const targetRole = notification.target_role
      ? normalizeRole(notification.target_role)
      : "";
    const recipientIds = new Set<string>();
    const foremanIds: string[] = [];
    for (const membership of memberships ?? []) {
      const userId = String(membership.user_id);
      const role = normalizeRole(membership.role);
      if (role === "foreman") foremanIds.push(userId);

      if (notification.target_user_id) {
        if (notification.target_user_id === userId) recipientIds.add(userId);
        continue;
      }

      if (role === "admin") {
        const selected = adminPreferences.get(userId) ??
          new Set(["admin", "foreman", "hr", "accountant", "lawyer"]);
        if (selected.has(sourceRole)) recipientIds.add(userId);
        continue;
      }

      if (targetRole) {
        if (role === targetRole && role !== "foreman") recipientIds.add(userId);
        continue;
      }

      if (role === sourceRole && role !== "foreman") recipientIds.add(userId);
    }

    const targetForemen = sourceRole === "foreman" || targetRole === "foreman";
    if (targetForemen && foremanIds.length > 0) {
      const objectName = notification.object_name.trim();
      if (!objectName) {
        for (const userId of foremanIds) recipientIds.add(userId);
      } else if (foremanAllowedEntityTypes.has(notification.entity_type)) {
        const { data: objects, error: objectsError } = await admin
          .from("objects")
          .select("id,name")
          .eq("company_id", notification.company_id)
          .eq("is_active", true);
        if (objectsError) throw objectsError;
        const objectIds = (objects ?? [])
          .filter((row) => normalize(row.name) === normalize(objectName))
          .map((row) => String(row.id));

        if (objectIds.length > 0) {
          const { data: assignments, error: assignmentsError } = await admin
            .from("object_memberships")
            .select("user_id")
            .eq("company_id", notification.company_id)
            .in("object_id", objectIds)
            .in("user_id", foremanIds);
          if (assignmentsError) throw assignmentsError;
          for (const assignment of assignments ?? []) {
            recipientIds.add(String(assignment.user_id));
          }
        }

        const { data: profiles, error: profilesError } = await admin
          .from("user_profiles")
          .select("id,object_name,is_active")
          .in("id", foremanIds)
          .eq("is_active", true);
        if (profilesError) throw profilesError;
        for (const profile of profiles ?? []) {
          if (normalize(profile.object_name) === normalize(objectName)) {
            recipientIds.add(String(profile.id));
          }
        }
      }
    }

    if (recipientIds.size === 0) {""",
    'push role recipient routing',
)

test = Path('test/role_notifications_task_photos_contract_test.dart')
test.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void expectContains(String path, Iterable<String> values) {
  final text = source(path);
  for (final value in values) {
    expect(text, contains(value), reason: '$path должен содержать $value');
  }
}

void main() {
  test('уведомления разделены по ролям и руководитель выбирает направления', () {
    expectContains(
      'supabase/migrations/20260718120000_role_notifications_and_task_photo_stages.sql',
      const [
        'notification_role_preferences',
        'source_role',
        'current_admin_notification_roles',
        'notification_visible_for_current_user',
        'set_my_notification_role_preferences',
        'populate_role_operational_reminders',
        "time '07:30'",
        "time '08:00'",
      ],
    );
    expectContains('lib/data/notification_repository.dart', const [
      'allNotificationRoles',
      'fetchSelectedNotificationRoles',
      'saveSelectedNotificationRoles',
      'source_role',
    ]);
    expectContains('lib/screens/push_notification_settings_screen.dart', const [
      'Какие роли учитывать',
      'Руководителю по умолчанию доступны все направления',
      'Сохранить роли',
    ]);
    expectContains('supabase/functions/dispatch-push-job/index.ts', const [
      'notification_role_preferences',
      'source_role',
      'adminPreferences',
      'sourceRole',
    ]);
  });

  test('новая задача требует фото До, а выполнение требует фото После', () {
    expectContains(
      'supabase/migrations/20260718120000_role_notifications_and_task_photo_stages.sql',
      const [
        'photo_stage',
        'photo_requirements_enforced',
        'Добавьте хотя бы одно фото «До»',
        'Добавьте хотя бы одно фото «После»',
        'tasks_validate_photo_requirements',
      ],
    );
    expectContains('lib/data/task_repository.dart', const [
      "'is_draft': true",
      "'photo_requirements_enforced': true",
      "photoStage: 'before'",
      "'photo_stage': photoStage",
    ]);
    expectContains('lib/screens/add_task_screen.dart', const [
      'Фото «До» — обязательно',
      'Добавьте хотя бы одно фото «До»',
    ]);
    expectContains('lib/screens/task_details_legacy_screen.dart', const [
      "photoStage: 'before'",
      "photoStage: 'after'",
      'Без фото «После» задачу нельзя выполнить',
      'Сначала добавьте хотя бы одно фото «После»',
    ]);
  });
}
''', encoding='utf-8')
