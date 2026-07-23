import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../models/recruitment_models.dart';

abstract final class RecruitmentRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static void _notify(String applicationId) {
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.recruitment},
      context: <String, dynamic>{
        'table': 'recruitment_applications',
        'entity_id': applicationId,
      },
    );
  }

  static void _notifyConfiguration(String table, String entityId) {
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.recruitment},
      context: <String, dynamic>{'table': table, 'entity_id': entityId},
    );
  }

  static Future<List<RecruitmentApplication>> fetchApplications({
    required String companyId,
    bool archived = false,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <RecruitmentApplication>[];

    final rows = await _client
        .from('recruitment_applications')
        .select('*, objects(name), recruitment_vacancies(title)')
        .eq('company_id', cleanCompanyId)
        .order('created_at', ascending: false)
        .limit(1000);

    return rows
        .map<RecruitmentApplication>(
          (value) => RecruitmentApplication.fromMap(_map(value)),
        )
        .where((item) => item.id.isNotEmpty && item.isArchived == archived)
        .toList();
  }

  static Future<RecruitmentCrmConfiguration> fetchConfiguration({
    required String companyId,
    bool includeInactive = false,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return RecruitmentCrmConfiguration.empty;

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _client
          .from('recruitment_pipeline_stages')
          .select()
          .eq('company_id', cleanCompanyId)
          .order('sort_order')
          .order('created_at'),
      _client
          .from('recruitment_custom_fields')
          .select()
          .eq('company_id', cleanCompanyId)
          .order('sort_order')
          .order('created_at'),
    ]);

    final stages = (results[0] as List<dynamic>)
        .map((value) => RecruitmentPipelineStage.fromMap(_map(value)))
        .where((item) => item.id.isNotEmpty)
        .where((item) => includeInactive || item.isActive)
        .toList();
    final fields = (results[1] as List<dynamic>)
        .map((value) => RecruitmentCustomField.fromMap(_map(value)))
        .where((item) => item.id.isNotEmpty)
        .where((item) => includeInactive || item.isActive)
        .toList();
    return RecruitmentCrmConfiguration(stages: stages, fields: fields);
  }

  static Future<RecruitmentWorkspaceData> fetchWorkspace({
    required String companyId,
    bool archived = false,
  }) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      fetchApplications(companyId: companyId, archived: archived),
      fetchConfiguration(companyId: companyId),
    ]);
    return RecruitmentWorkspaceData(
      applications: results[0] as List<RecruitmentApplication>,
      configuration: results[1] as RecruitmentCrmConfiguration,
    );
  }

  static Future<List<RecruitmentDocument>> fetchDocuments({
    required String companyId,
    required String applicationId,
  }) async {
    final rows = await _client
        .from('recruitment_documents')
        .select()
        .eq('company_id', companyId.trim())
        .eq('application_id', applicationId.trim())
        .order('created_at');
    return rows
        .map<RecruitmentDocument>(
          (value) => RecruitmentDocument.fromMap(_map(value)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<List<RecruitmentMessage>> fetchMessages({
    required String companyId,
    required String applicationId,
  }) async {
    final rows = await _client
        .from('recruitment_messages')
        .select()
        .eq('company_id', companyId.trim())
        .eq('application_id', applicationId.trim())
        .order('created_at', ascending: true)
        .order('id', ascending: true);
    final messages =
        rows
            .map<RecruitmentMessage>(
              (value) => RecruitmentMessage.fromMap(_map(value)),
            )
            .where((item) => item.id.isNotEmpty)
            .toList()
          ..sort((first, second) {
            final byTime = first.createdAt.compareTo(second.createdAt);
            if (byTime != 0) return byTime;
            return first.id.compareTo(second.id);
          });
    return messages;
  }

  static Future<String> createSignedFileUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 300,
  }) async {
    final cleanBucket = bucket.trim();
    final cleanPath = path.trim();
    if (cleanBucket.isEmpty ||
        cleanPath.isEmpty ||
        cleanPath.startsWith('telegram://')) {
      throw Exception('Файл ещё не загружен в защищённое хранилище');
    }
    return _client.storage
        .from(cleanBucket)
        .createSignedUrl(cleanPath, expiresInSeconds);
  }

  static Future<String> createDownloadFileUrl({
    required String bucket,
    required String path,
    required String fileName,
    int expiresInSeconds = 300,
  }) async {
    final signedUrl = await createSignedFileUrl(
      bucket: bucket,
      path: path,
      expiresInSeconds: expiresInSeconds,
    );
    final uri = Uri.parse(signedUrl);
    return uri
        .replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            'download': fileName.trim().isEmpty ? 'document' : fileName.trim(),
          },
        )
        .toString();
  }

  static Future<Uint8List> downloadStoredFile({
    required String bucket,
    required String path,
  }) async {
    final cleanBucket = bucket.trim();
    final cleanPath = path.trim();
    if (cleanBucket.isEmpty ||
        cleanPath.isEmpty ||
        cleanPath.startsWith('telegram://')) {
      throw Exception('Файл ещё не загружен в защищённое хранилище');
    }
    return _client.storage.from(cleanBucket).download(cleanPath);
  }

  static Future<void> sendCandidateMessage({
    required String applicationId,
    required String message,
  }) async {
    final cleanApplicationId = applicationId.trim();
    await _client.rpc(
      'activate_recruitment_telegram_conversation',
      params: <String, dynamic>{'p_application_id': cleanApplicationId},
    );

    final response = await _client.functions.invoke(
      'recruitment-candidate-action',
      body: <String, dynamic>{
        'action': 'send_message',
        'application_id': cleanApplicationId,
        'message': message.trim(),
      },
    );
    final data = _map(response.data);
    final error = data['error']?.toString().trim() ?? '';
    if (response.status < 200 || response.status >= 300 || error.isNotEmpty) {
      throw Exception(error.isEmpty ? 'Не удалось отправить сообщение' : error);
    }
    _notify(cleanApplicationId);
  }

  static Future<List<RecruitmentObjectOption>> fetchObjects({
    required String companyId,
  }) async {
    final rows = await _client
        .from('objects')
        .select('id, name')
        .eq('company_id', companyId.trim())
        .eq('is_active', true)
        .order('name');
    return rows
        .map<RecruitmentObjectOption>(
          (row) => RecruitmentObjectOption(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
          ),
        )
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
        .toList();
  }

  static Future<List<RecruitmentVacancyOption>> fetchVacancies({
    required String companyId,
  }) async {
    final rows = await _client
        .from('recruitment_vacancies')
        .select('id, object_id, title')
        .eq('company_id', companyId.trim())
        .eq('is_active', true)
        .order('sort_order')
        .order('title');
    return rows
        .map<RecruitmentVacancyOption>(
          (row) => RecruitmentVacancyOption(
            id: row['id']?.toString() ?? '',
            objectId: row['object_id']?.toString() ?? '',
            title: row['title']?.toString() ?? '',
          ),
        )
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList();
  }

  static Future<RecruitmentDashboardData> fetchDashboard({
    required String companyId,
  }) async {
    final workspace = await fetchWorkspace(companyId: companyId);
    final counts = <String, int>{
      for (final stage in workspace.configuration.stages) stage.id: 0,
    };
    for (final application in workspace.applications) {
      final stage = workspace.configuration.stageForApplication(application);
      if (stage != null) counts[stage.id] = (counts[stage.id] ?? 0) + 1;
    }
    return RecruitmentDashboardData(
      applications: workspace.applications,
      stages: workspace.configuration.stages,
      counts: counts,
    );
  }

  static Future<String> _resolveObjectId({
    required String companyId,
    required String objectId,
    required String objectName,
  }) async {
    final cleanId = objectId.trim();
    if (cleanId.isNotEmpty) return cleanId;
    final cleanName = objectName.trim();
    if (cleanName.isEmpty) throw Exception('Выберите объект');

    final rows = await _client
        .from('objects')
        .select('id, name')
        .eq('company_id', companyId.trim())
        .eq('is_active', true);
    for (final row in rows) {
      final name = row['name']?.toString().trim() ?? '';
      if (name.toLowerCase() == cleanName.toLowerCase()) {
        return row['id']?.toString() ?? '';
      }
    }
    throw Exception('Объект не найден');
  }

  static Future<RecruitmentApplication> saveApplication({
    String? id,
    required String companyId,
    required String fullName,
    required String phone,
    required String citizenship,
    required String vacancy,
    String vacancyId = '',
    required String objectName,
    String objectId = '',
    required String experience,
    DateTime? departureDate,
    required String status,
    String stageId = '',
    required String comment,
    Map<String, dynamic> customValues = const <String, dynamic>{},
    String source = 'manual',
    String sourceUserId = '',
    String sourceChatId = '',
  }) async {
    final cleanId = id?.trim() ?? '';
    final cleanCompanyId = companyId.trim();
    final cleanName = fullName.trim();
    final cleanPhone = phone.trim();
    final cleanVacancy = vacancy.trim();
    if (cleanName.length < 2 || cleanPhone.isEmpty || cleanVacancy.isEmpty) {
      throw Exception('Укажите ФИО, телефон и вакансию');
    }
    final resolvedObjectId = await _resolveObjectId(
      companyId: cleanCompanyId,
      objectId: objectId,
      objectName: objectName,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'company_id': cleanCompanyId,
      'source': source.trim().isEmpty ? 'manual' : source.trim(),
      'external_user_id': sourceUserId.trim(),
      'external_chat_id': sourceChatId.trim(),
      'full_name': cleanName,
      'phone': cleanPhone,
      'citizenship': citizenship.trim(),
      'object_id': resolvedObjectId,
      'vacancy_id': vacancyId.trim().isEmpty ? null : vacancyId.trim(),
      'position_title': cleanVacancy,
      'experience_text': experience.trim(),
      'ready_date': departureDate == null ? null : _dateOnly(departureDate),
      'status': recruitmentStatuses.contains(status) ? status : 'new',
      if (stageId.trim().isNotEmpty) 'stage_id': stageId.trim(),
      'hr_comment': comment.trim(),
      'custom_values': Map<String, dynamic>.from(customValues),
      'updated_at': now,
    };

    final dynamic row;
    if (cleanId.isEmpty) {
      payload['submitted_at'] = now;
      row = await _client
          .from('recruitment_applications')
          .insert(payload)
          .select('*, objects(name), recruitment_vacancies(title)')
          .single();
    } else {
      row = await _client
          .from('recruitment_applications')
          .update(payload)
          .eq('company_id', cleanCompanyId)
          .eq('id', cleanId)
          .select('*, objects(name), recruitment_vacancies(title)')
          .single();
    }

    final result = RecruitmentApplication.fromMap(_map(row));
    _notify(result.id);
    return result;
  }

  static Future<RecruitmentPipelineStage> savePipelineStage({
    String id = '',
    required String companyId,
    required String title,
    String description = '',
    String colorHex = '#2F80ED',
    String legacyStatus = 'new',
    bool isFinal = false,
    int sortOrder = 100,
  }) async {
    final payload = <String, dynamic>{
      'company_id': companyId.trim(),
      'title': title.trim(),
      'description': description.trim(),
      'color_hex': colorHex.trim().toUpperCase(),
      'legacy_status': recruitmentStatuses.contains(legacyStatus)
          ? legacyStatus
          : 'new',
      'is_final': isFinal,
      'sort_order': sortOrder,
      'is_active': true,
      'created_by': _client.auth.currentUser?.id,
    };
    final dynamic row;
    if (id.trim().isEmpty) {
      row = await _client
          .from('recruitment_pipeline_stages')
          .insert(payload)
          .select()
          .single();
    } else {
      payload.remove('company_id');
      payload.remove('created_by');
      row = await _client
          .from('recruitment_pipeline_stages')
          .update(payload)
          .eq('company_id', companyId.trim())
          .eq('id', id.trim())
          .select()
          .single();
    }
    final result = RecruitmentPipelineStage.fromMap(_map(row));
    _notifyConfiguration('recruitment_pipeline_stages', result.id);
    return result;
  }

  static Future<void> reorderPipelineStages({
    required String companyId,
    required List<String> orderedIds,
  }) async {
    await Future.wait<void>(<Future<void>>[
      for (var index = 0; index < orderedIds.length; index++)
        _client
            .from('recruitment_pipeline_stages')
            .update(<String, dynamic>{'sort_order': (index + 1) * 10})
            .eq('company_id', companyId.trim())
            .eq('id', orderedIds[index])
            .then((_) {}),
    ]);
    _notifyConfiguration('recruitment_pipeline_stages', 'order');
  }

  static Future<void> setPipelineStageActive({
    required String companyId,
    required String stageId,
    required bool active,
  }) async {
    await _client
        .from('recruitment_pipeline_stages')
        .update(<String, dynamic>{'is_active': active})
        .eq('company_id', companyId.trim())
        .eq('id', stageId.trim());
    _notifyConfiguration('recruitment_pipeline_stages', stageId.trim());
  }

  static Future<RecruitmentCustomField> saveCustomField({
    String id = '',
    required String companyId,
    required String title,
    required String fieldType,
    List<String> options = const <String>[],
    bool isRequired = false,
    bool showOnCard = false,
    int sortOrder = 100,
  }) async {
    final cleanOptions = options
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final payload = <String, dynamic>{
      'company_id': companyId.trim(),
      'title': title.trim(),
      'field_type': recruitmentCustomFieldTypes.contains(fieldType)
          ? fieldType
          : 'text',
      'options': cleanOptions,
      'is_required': isRequired,
      'show_on_card': showOnCard,
      'sort_order': sortOrder,
      'is_active': true,
      'created_by': _client.auth.currentUser?.id,
    };
    final dynamic row;
    if (id.trim().isEmpty) {
      row = await _client
          .from('recruitment_custom_fields')
          .insert(payload)
          .select()
          .single();
    } else {
      payload.remove('company_id');
      payload.remove('created_by');
      row = await _client
          .from('recruitment_custom_fields')
          .update(payload)
          .eq('company_id', companyId.trim())
          .eq('id', id.trim())
          .select()
          .single();
    }
    final result = RecruitmentCustomField.fromMap(_map(row));
    _notifyConfiguration('recruitment_custom_fields', result.id);
    return result;
  }

  static Future<void> reorderCustomFields({
    required String companyId,
    required List<String> orderedIds,
  }) async {
    await Future.wait<void>(<Future<void>>[
      for (var index = 0; index < orderedIds.length; index++)
        _client
            .from('recruitment_custom_fields')
            .update(<String, dynamic>{'sort_order': (index + 1) * 10})
            .eq('company_id', companyId.trim())
            .eq('id', orderedIds[index])
            .then((_) {}),
    ]);
    _notifyConfiguration('recruitment_custom_fields', 'order');
  }

  static Future<void> setCustomFieldActive({
    required String companyId,
    required String fieldId,
    required bool active,
  }) async {
    await _client
        .from('recruitment_custom_fields')
        .update(<String, dynamic>{'is_active': active})
        .eq('company_id', companyId.trim())
        .eq('id', fieldId.trim());
    _notifyConfiguration('recruitment_custom_fields', fieldId.trim());
  }

  static Future<void> moveApplicationStage({
    required String applicationId,
    required String stageId,
  }) async {
    await _client.rpc(
      'move_recruitment_application_stage',
      params: <String, dynamic>{
        'p_application_id': applicationId.trim(),
        'p_stage_id': stageId.trim(),
      },
    );
    _notify(applicationId.trim());
  }

  static Future<void> updateStatus({
    required String companyId,
    required String applicationId,
    required String status,
  }) async {
    if (!recruitmentStatuses.contains(status)) return;
    final cleanCompanyId = companyId.trim();
    final cleanApplicationId = applicationId.trim();
    final dynamic row = await _client
        .from('recruitment_applications')
        .update(<String, dynamic>{
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('company_id', cleanCompanyId)
        .eq('id', cleanApplicationId)
        .select('status, stage_id')
        .single();
    final applicationRow = _map(row);
    final stageId = applicationRow['stage_id']?.toString() ?? '';
    String stageTitle = '';
    if (stageId.isNotEmpty) {
      final dynamic stageRow = await _client
          .from('recruitment_pipeline_stages')
          .select('title')
          .eq('company_id', cleanCompanyId)
          .eq('id', stageId)
          .maybeSingle();
      stageTitle = _map(stageRow)['title']?.toString() ?? '';
    }

    await _client.from('recruitment_status_history').insert(<String, dynamic>{
      'company_id': cleanCompanyId,
      'application_id': cleanApplicationId,
      'status': applicationRow['status']?.toString() ?? status,
      'stage_id': stageId.isEmpty ? null : stageId,
      'stage_title': stageTitle,
      'source': 'appstroy_hr',
      'created_by': _client.auth.currentUser?.id,
    });

    _notify(cleanApplicationId);
  }

  static Future<void> archiveApplication({
    required String companyId,
    required String applicationId,
  }) async {
    final cleanApplicationId = applicationId.trim();
    await _client
        .from('recruitment_applications')
        .update(<String, dynamic>{
          'archived_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('company_id', companyId.trim())
        .eq('id', cleanApplicationId);
    _notify(cleanApplicationId);
  }

  static Future<void> restoreApplication({
    required String companyId,
    required String applicationId,
  }) async {
    final cleanApplicationId = applicationId.trim();
    await _client
        .from('recruitment_applications')
        .update(<String, dynamic>{'archived_at': null})
        .eq('company_id', companyId.trim())
        .eq('id', cleanApplicationId);
    _notify(cleanApplicationId);
  }

  static Future<void> deleteApplication({
    required String companyId,
    required String applicationId,
  }) async {
    final response = await _client.functions.invoke(
      'recruitment-candidate-action',
      body: <String, dynamic>{
        'action': 'delete_application',
        'application_id': applicationId.trim(),
      },
    );
    final data = _map(response.data);
    final error = data['error']?.toString().trim() ?? '';
    if (response.status < 200 || response.status >= 300 || error.isNotEmpty) {
      throw Exception(error.isEmpty ? 'Не удалось удалить заявку' : error);
    }
    _notify(applicationId.trim());
  }
}
