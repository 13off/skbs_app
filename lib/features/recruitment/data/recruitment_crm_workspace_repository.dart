import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../models/recruitment_crm_workspace_models.dart';
import '../models/recruitment_models.dart';

abstract final class RecruitmentCrmWorkspaceRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static void _notify(
    String applicationId, {
    String table = 'recruitment_crm',
  }) {
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.recruitment},
      context: <String, dynamic>{'table': table, 'entity_id': applicationId},
    );
  }

  static Future<List<RecruitmentResponsibleOption>> fetchResponsibles() async {
    final dynamic response = await _client.rpc('get_recruitment_responsibles');
    final rows = response is List ? response : const <dynamic>[];
    return rows
        .map((row) => RecruitmentResponsibleOption.fromMap(_map(row)))
        .where((item) => item.userId.isNotEmpty)
        .toList();
  }

  static Future<Map<String, String>> _fetchUserNames(
    Iterable<String> userIds,
  ) async {
    final ids = userIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const <String, String>{};

    final rows = await _client
        .from('user_profiles')
        .select('id, full_name, email')
        .inFilter('id', ids);
    return <String, String>{
      for (final row in rows)
        if ((row['id']?.toString() ?? '').isNotEmpty)
          row['id'].toString(): () {
            final name = row['full_name']?.toString().trim() ?? '';
            final email = row['email']?.toString().trim() ?? '';
            return name.isNotEmpty
                ? name
                : email.isNotEmpty
                ? email
                : 'Пользователь AppСтрой';
          }(),
    };
  }

  static Future<RecruitmentCandidateWorkspaceData> fetchCandidateWorkspace({
    required String companyId,
    required String applicationId,
  }) async {
    final cleanCompanyId = companyId.trim();
    final cleanApplicationId = applicationId.trim();
    if (cleanCompanyId.isEmpty || cleanApplicationId.isEmpty) {
      return RecruitmentCandidateWorkspaceData.empty;
    }

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _client
          .from('recruitment_crm_comments')
          .select()
          .eq('company_id', cleanCompanyId)
          .eq('application_id', cleanApplicationId)
          .order('created_at', ascending: false),
      _client
          .from('recruitment_crm_tasks')
          .select()
          .eq('company_id', cleanCompanyId)
          .eq('application_id', cleanApplicationId)
          .order('created_at', ascending: false),
      _client
          .from('recruitment_crm_activities')
          .select()
          .eq('company_id', cleanCompanyId)
          .eq('application_id', cleanApplicationId)
          .order('created_at', ascending: false)
          .limit(500),
      fetchResponsibles(),
    ]);

    final commentRows = results[0] as List<dynamic>;
    final taskRows = results[1] as List<dynamic>;
    final activityRows = results[2] as List<dynamic>;
    final responsibles = results[3] as List<RecruitmentResponsibleOption>;

    final userIds = <String>{};
    for (final raw in commentRows) {
      final row = _map(raw);
      userIds.add(row['created_by']?.toString() ?? '');
    }
    for (final raw in taskRows) {
      final row = _map(raw);
      userIds
        ..add(row['created_by']?.toString() ?? '')
        ..add(row['assigned_to']?.toString() ?? '')
        ..add(row['completed_by']?.toString() ?? '');
    }
    final names = await _fetchUserNames(userIds);

    final comments = commentRows.map((raw) {
      final row = _map(raw);
      final userId = row['created_by']?.toString() ?? '';
      return RecruitmentCrmComment.fromMap(
        row,
        authorName: names[userId] ?? 'Пользователь AppСтрой',
      );
    }).toList();

    final tasks = taskRows.map((raw) {
      final row = _map(raw);
      final assignedTo = row['assigned_to']?.toString() ?? '';
      final createdBy = row['created_by']?.toString() ?? '';
      return RecruitmentCrmTask.fromMap(
        row,
        assigneeName: names[assignedTo] ?? '',
        creatorName: names[createdBy] ?? 'Пользователь AppСтрой',
      );
    }).toList();

    return RecruitmentCandidateWorkspaceData(
      comments: comments,
      tasks: tasks,
      activities: activityRows
          .map((raw) => RecruitmentCrmActivity.fromMap(_map(raw)))
          .toList(),
      responsibles: responsibles,
    );
  }

  static Future<RecruitmentBoardSupportData> fetchBoardSupport({
    required String companyId,
    required List<RecruitmentApplication> applications,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return RecruitmentBoardSupportData.empty;

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      fetchResponsibles(),
      fetchSavedViews(companyId: cleanCompanyId),
      _client
          .from('recruitment_crm_tasks')
          .select('application_id, title, due_at, assigned_to, status')
          .eq('company_id', cleanCompanyId)
          .eq('status', 'pending')
          .order('due_at'),
    ]);
    final responsibles = results[0] as List<RecruitmentResponsibleOption>;
    final savedViews = results[1] as List<RecruitmentCrmSavedView>;
    final taskRows = results[2] as List<dynamic>;
    final names = <String, String>{
      for (final item in responsibles) item.userId: item.fullName,
    };

    final tasksByApplication = <String, List<Map<String, dynamic>>>{};
    for (final raw in taskRows) {
      final row = _map(raw);
      final applicationId = row['application_id']?.toString() ?? '';
      if (applicationId.isEmpty) continue;
      tasksByApplication
          .putIfAbsent(applicationId, () => <Map<String, dynamic>>[])
          .add(row);
    }

    final indicators = <String, RecruitmentCandidateIndicator>{};
    for (final application in applications) {
      final tasks =
          tasksByApplication[application.id] ?? const <Map<String, dynamic>>[];
      DateTime? nextDue;
      String nextTitle = '';
      var overdue = 0;
      for (final task in tasks) {
        final due = DateTime.tryParse(
          task['due_at']?.toString() ?? '',
        )?.toLocal();
        if (due != null && due.isBefore(DateTime.now())) overdue++;
        if (due != null && (nextDue == null || due.isBefore(nextDue))) {
          nextDue = due;
          nextTitle = task['title']?.toString() ?? '';
        }
      }
      indicators[application.id] = RecruitmentCandidateIndicator(
        responsibleUserId: application.responsibleUserId,
        responsibleName: names[application.responsibleUserId] ?? '',
        openTasks: tasks.length,
        overdueTasks: overdue,
        nextTaskDueAt: nextDue,
        nextTaskTitle: nextTitle,
      );
    }

    return RecruitmentBoardSupportData(
      responsibles: responsibles,
      indicators: indicators,
      savedViews: savedViews,
    );
  }

  static Future<RecruitmentCrmComment> addComment({
    required String companyId,
    required String applicationId,
    required String body,
  }) async {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) throw Exception('Введите комментарий');
    final dynamic row = await _client
        .from('recruitment_crm_comments')
        .insert(<String, dynamic>{
          'company_id': companyId.trim(),
          'application_id': applicationId.trim(),
          'body': cleanBody,
          'created_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    final currentUser = _client.auth.currentUser;
    final metadata = currentUser?.userMetadata ?? const <String, dynamic>{};
    final metadataName = metadata['full_name']?.toString().trim() ?? '';
    final result = RecruitmentCrmComment.fromMap(
      _map(row),
      authorName: metadataName.isNotEmpty
          ? metadataName
          : (currentUser?.email ?? 'Пользователь AppСтрой'),
    );
    _notify(applicationId, table: 'recruitment_crm_comments');
    return result;
  }

  static Future<void> deleteComment({
    required String companyId,
    required String commentId,
    required String applicationId,
  }) async {
    await _client
        .from('recruitment_crm_comments')
        .delete()
        .eq('company_id', companyId.trim())
        .eq('id', commentId.trim());
    _notify(applicationId, table: 'recruitment_crm_comments');
  }

  static Future<RecruitmentCrmTask> saveTask({
    String id = '',
    required String companyId,
    required String applicationId,
    required String title,
    String description = '',
    String taskType = 'other',
    String priority = 'normal',
    DateTime? dueAt,
    String assignedTo = '',
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw Exception('Введите название дела');
    final payload = <String, dynamic>{
      'company_id': companyId.trim(),
      'application_id': applicationId.trim(),
      'title': cleanTitle,
      'description': description.trim(),
      'task_type': recruitmentCrmTaskTypes.contains(taskType)
          ? taskType
          : 'other',
      'priority': recruitmentCrmPriorities.contains(priority)
          ? priority
          : 'normal',
      'due_at': dueAt?.toUtc().toIso8601String(),
      'assigned_to': assignedTo.trim().isEmpty ? null : assignedTo.trim(),
      'created_by': _client.auth.currentUser?.id,
    };
    final dynamic row;
    if (id.trim().isEmpty) {
      row = await _client
          .from('recruitment_crm_tasks')
          .insert(payload)
          .select()
          .single();
    } else {
      payload
        ..remove('company_id')
        ..remove('application_id')
        ..remove('created_by');
      row = await _client
          .from('recruitment_crm_tasks')
          .update(payload)
          .eq('company_id', companyId.trim())
          .eq('id', id.trim())
          .select()
          .single();
    }
    _notify(applicationId, table: 'recruitment_crm_tasks');
    return RecruitmentCrmTask.fromMap(_map(row));
  }

  static Future<void> setTaskStatus({
    required String companyId,
    required String applicationId,
    required String taskId,
    required String status,
  }) async {
    if (!const <String>{'pending', 'completed', 'cancelled'}.contains(status)) {
      return;
    }
    await _client
        .from('recruitment_crm_tasks')
        .update(<String, dynamic>{
          'status': status,
          'completed_at': status == 'completed'
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'completed_by': status == 'completed'
              ? _client.auth.currentUser?.id
              : null,
        })
        .eq('company_id', companyId.trim())
        .eq('id', taskId.trim());
    _notify(applicationId, table: 'recruitment_crm_tasks');
  }

  static Future<void> assignResponsible({
    required String applicationId,
    required String responsibleUserId,
  }) async {
    await _client.rpc(
      'assign_recruitment_responsible',
      params: <String, dynamic>{
        'p_application_id': applicationId.trim(),
        'p_responsible_user_id': responsibleUserId.trim().isEmpty
            ? null
            : responsibleUserId.trim(),
      },
    );
    _notify(applicationId, table: 'recruitment_applications');
  }

  static Future<int> bulkMove({
    required List<String> applicationIds,
    required String stageId,
  }) async {
    final ids = applicationIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return 0;
    final dynamic result = await _client.rpc(
      'bulk_move_recruitment_applications',
      params: <String, dynamic>{
        'p_application_ids': ids,
        'p_stage_id': stageId.trim(),
      },
    );
    for (final id in ids) {
      _notify(id, table: 'recruitment_applications');
    }
    return switch (result) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(result?.toString() ?? '') ?? 0,
    };
  }

  static Future<List<RecruitmentCrmSavedView>> fetchSavedViews({
    required String companyId,
  }) async {
    final rows = await _client
        .from('recruitment_crm_saved_views')
        .select()
        .eq('company_id', companyId.trim())
        .order('is_default', ascending: false)
        .order('updated_at', ascending: false);
    return rows
        .map((row) => RecruitmentCrmSavedView.fromMap(_map(row)))
        .toList();
  }

  static Future<RecruitmentCrmSavedView> saveView({
    String id = '',
    required String companyId,
    required String title,
    required Map<String, dynamic> filters,
    bool isDefault = false,
  }) async {
    final userId = _client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) throw Exception('Требуется повторный вход');
    if (isDefault) {
      await _client
          .from('recruitment_crm_saved_views')
          .update(<String, dynamic>{'is_default': false})
          .eq('company_id', companyId.trim())
          .eq('user_id', userId);
    }
    final payload = <String, dynamic>{
      'company_id': companyId.trim(),
      'user_id': userId,
      'title': title.trim(),
      'filters': Map<String, dynamic>.from(filters),
      'is_default': isDefault,
    };
    final dynamic row;
    if (id.trim().isEmpty) {
      row = await _client
          .from('recruitment_crm_saved_views')
          .insert(payload)
          .select()
          .single();
    } else {
      payload
        ..remove('company_id')
        ..remove('user_id');
      row = await _client
          .from('recruitment_crm_saved_views')
          .update(payload)
          .eq('company_id', companyId.trim())
          .eq('user_id', userId)
          .eq('id', id.trim())
          .select()
          .single();
    }
    _notify(
      _map(row)['id']?.toString() ?? '',
      table: 'recruitment_crm_saved_views',
    );
    return RecruitmentCrmSavedView.fromMap(_map(row));
  }

  static Future<void> deleteView({
    required String companyId,
    required String id,
  }) async {
    await _client
        .from('recruitment_crm_saved_views')
        .delete()
        .eq('company_id', companyId.trim())
        .eq('id', id.trim());
    _notify(id, table: 'recruitment_crm_saved_views');
  }

  static Future<List<RecruitmentCrmAutomationRule>> fetchAutomationRules({
    required String companyId,
  }) async {
    final rows = await _client
        .from('recruitment_crm_automation_rules')
        .select()
        .eq('company_id', companyId.trim())
        .order('sort_order')
        .order('created_at');
    return rows
        .map((row) => RecruitmentCrmAutomationRule.fromMap(_map(row)))
        .toList();
  }

  static Future<RecruitmentCrmAutomationRule> saveAutomationRule({
    String id = '',
    required String companyId,
    required String triggerStageId,
    required String title,
    required String actionType,
    String taskTitle = '',
    String taskType = 'other',
    String taskPriority = 'normal',
    int dueOffsetHours = 24,
    String messageText = '',
    String assignedTo = '',
    bool isActive = true,
    int sortOrder = 100,
  }) async {
    final payload = <String, dynamic>{
      'company_id': companyId.trim(),
      'trigger_stage_id': triggerStageId.trim(),
      'title': title.trim(),
      'action_type': recruitmentAutomationActionTypes.contains(actionType)
          ? actionType
          : 'create_task',
      'task_title': taskTitle.trim(),
      'task_type': recruitmentCrmTaskTypes.contains(taskType)
          ? taskType
          : 'other',
      'task_priority': recruitmentCrmPriorities.contains(taskPriority)
          ? taskPriority
          : 'normal',
      'due_offset_hours': dueOffsetHours.clamp(0, 8760).toInt(),
      'message_text': messageText.trim(),
      'assigned_to': assignedTo.trim().isEmpty ? null : assignedTo.trim(),
      'is_active': isActive,
      'sort_order': sortOrder,
      'created_by': _client.auth.currentUser?.id,
    };
    final dynamic row;
    if (id.trim().isEmpty) {
      row = await _client
          .from('recruitment_crm_automation_rules')
          .insert(payload)
          .select()
          .single();
    } else {
      payload
        ..remove('company_id')
        ..remove('created_by');
      row = await _client
          .from('recruitment_crm_automation_rules')
          .update(payload)
          .eq('company_id', companyId.trim())
          .eq('id', id.trim())
          .select()
          .single();
    }
    _notify(
      _map(row)['id']?.toString() ?? '',
      table: 'recruitment_crm_automation_rules',
    );
    return RecruitmentCrmAutomationRule.fromMap(_map(row));
  }

  static Future<void> deleteAutomationRule({
    required String companyId,
    required String id,
  }) async {
    await _client
        .from('recruitment_crm_automation_rules')
        .delete()
        .eq('company_id', companyId.trim())
        .eq('id', id.trim());
    _notify(id, table: 'recruitment_crm_automation_rules');
  }

  static Future<Map<String, dynamic>> runAutomations({
    required List<String> applicationIds,
  }) async {
    final ids = applicationIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const <String, dynamic>{};
    final response = await _client.functions.invoke(
      'run-recruitment-crm-automations',
      body: <String, dynamic>{'application_ids': ids},
    );
    final data = _map(response.data);
    final error = data['error']?.toString().trim() ?? '';
    if (response.status < 200 || response.status >= 300 || error.isNotEmpty) {
      throw Exception(
        error.isEmpty ? 'Не удалось выполнить автоматизации' : error,
      );
    }
    return data;
  }
}
