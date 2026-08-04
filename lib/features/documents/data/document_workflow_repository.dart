import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/document_onboarding.dart';

class DocumentWorkflowDashboardData {
  final DocumentWorkflowAccess access;
  final DocumentToolInstallation installation;
  final List<DocumentPackageRecord> packages;
  final List<EmployeeOnboardingRecord> onboardings;

  const DocumentWorkflowDashboardData({
    required this.access,
    required this.installation,
    required this.packages,
    required this.onboardings,
  });

  int get activeCount => onboardings
      .where((item) => !item.isCompleted && item.status != 'cancelled')
      .length;

  int get completedCount =>
      onboardings.where((item) => item.isCompleted).length;

  int get overdueCount {
    final now = DateTime.now();
    return onboardings.where((item) {
      final dueAt = item.dueAt;
      return !item.isCompleted && dueAt != null && dueAt.isBefore(now);
    }).length;
  }
}

class DocumentOnboardingStepRecord {
  final String id;
  final String onboardingId;
  final String stepCode;
  final String status;
  final bool isRequired;
  final String? assignedUserId;
  final DateTime? dueAt;
  final Map<String, dynamic> payload;
  final DateTime? completedAt;

  const DocumentOnboardingStepRecord({
    required this.id,
    required this.onboardingId,
    required this.stepCode,
    required this.status,
    required this.isRequired,
    required this.assignedUserId,
    required this.dueAt,
    required this.payload,
    required this.completedAt,
  });

  bool get isCompleted => status == 'completed';

  factory DocumentOnboardingStepRecord.fromMap(Map<String, dynamic> map) {
    return DocumentOnboardingStepRecord(
      id: map['id']?.toString() ?? '',
      onboardingId: map['onboarding_id']?.toString() ?? '',
      stepCode: map['step_code']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      isRequired: map['is_required'] != false,
      assignedUserId: nullableText(map['assigned_user_id']),
      dueAt: dateValue(map['due_at']),
      payload: jsonMap(map['payload']),
      completedAt: dateValue(map['completed_at']),
    );
  }
}

class EmployeeDocumentFileRecord {
  final String id;
  final String companyId;
  final String? onboardingId;
  final String? employeeId;
  final String fileKind;
  final String documentType;
  final String storageBucket;
  final String storagePath;
  final String originalFileName;
  final String mimeType;
  final int? fileSize;
  final int versionNo;
  final String? templateId;
  final String? templateVersionId;
  final String qualityStatus;
  final String verificationStatus;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const EmployeeDocumentFileRecord({
    required this.id,
    required this.companyId,
    required this.onboardingId,
    required this.employeeId,
    required this.fileKind,
    required this.documentType,
    required this.storageBucket,
    required this.storagePath,
    required this.originalFileName,
    required this.mimeType,
    required this.fileSize,
    required this.versionNo,
    required this.templateId,
    required this.templateVersionId,
    required this.qualityStatus,
    required this.verificationStatus,
    required this.metadata,
    required this.createdAt,
  });

  bool get isAccepted => verificationStatus == 'accepted';
  bool get isRejected => verificationStatus == 'rejected';

  factory EmployeeDocumentFileRecord.fromMap(Map<String, dynamic> map) {
    final rawSize = map['file_size'];
    return EmployeeDocumentFileRecord(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      onboardingId: nullableText(map['onboarding_id']),
      employeeId: nullableText(map['employee_id']),
      fileKind: map['file_kind']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? '',
      storageBucket: map['storage_bucket']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      originalFileName: map['original_file_name']?.toString() ?? '',
      mimeType: map['mime_type']?.toString() ?? 'application/octet-stream',
      fileSize: rawSize is num
          ? rawSize.toInt()
          : int.tryParse(rawSize?.toString() ?? ''),
      versionNo: intValue(map['version_no']),
      templateId: nullableText(map['template_id']),
      templateVersionId: nullableText(map['template_version_id']),
      qualityStatus: map['quality_status']?.toString() ?? 'not_checked',
      verificationStatus: map['verification_status']?.toString() ?? 'pending',
      metadata: jsonMap(map['metadata']),
      createdAt:
          dateValue(map['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DocumentAuditRecord {
  final int id;
  final String entityType;
  final String entityId;
  final String action;
  final String? actorUserId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const DocumentAuditRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actorUserId,
    required this.details,
    required this.createdAt,
  });

  factory DocumentAuditRecord.fromMap(Map<String, dynamic> map) {
    return DocumentAuditRecord(
      id: intValue(map['id']),
      entityType: map['entity_type']?.toString() ?? '',
      entityId: map['entity_id']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      actorUserId: nullableText(map['actor_user_id']),
      details: jsonMap(map['details']),
      createdAt:
          dateValue(map['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

abstract final class DocumentWorkflowRepository {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String employeeDocumentsBucket = 'employee-documents';
  static const int maxUploadBytes = 20 * 1024 * 1024;

  static Future<DocumentWorkflowAccess> fetchAccess() async {
    final raw = await _client.rpc('document_workflow_permission_map');
    return DocumentWorkflowAccess.fromMap(_map(raw));
  }

  static Future<DocumentToolInstallation> fetchInstallation(
    String companyId,
  ) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) {
      return const DocumentToolInstallation(
        companyId: '',
        isEnabled: false,
        settings: <String, dynamic>{},
      );
    }
    final row = await _client
        .from('document_tool_installations')
        .select('company_id, is_enabled, settings')
        .eq('company_id', cleanCompanyId)
        .maybeSingle();
    if (row == null) {
      return DocumentToolInstallation(
        companyId: cleanCompanyId,
        isEnabled: false,
        settings: const <String, dynamic>{},
      );
    }
    return DocumentToolInstallation.fromMap(_map(row));
  }

  static Future<DocumentToolInstallation> setInstallation({
    required String companyId,
    required bool isEnabled,
    Map<String, dynamic> settings = const <String, dynamic>{},
  }) async {
    final cleanCompanyId = _required(companyId, 'Компания не выбрана');
    final row = await _client
        .from('document_tool_installations')
        .upsert(<String, dynamic>{
          'company_id': cleanCompanyId,
          'is_enabled': isEnabled,
          'settings': settings,
          'enabled_at': isEnabled
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'enabled_by': isEnabled ? _client.auth.currentUser?.id : null,
        }, onConflict: 'company_id')
        .select('company_id, is_enabled, settings')
        .single();
    await recordAudit(
      companyId: cleanCompanyId,
      entityType: 'document_tool_installation',
      entityId: cleanCompanyId,
      action: isEnabled ? 'enabled' : 'disabled',
      details: <String, dynamic>{'settings': settings},
    );
    return DocumentToolInstallation.fromMap(_map(row));
  }

  static Future<DocumentWorkflowDashboardData> fetchDashboard(
    String companyId,
  ) async {
    final access = await fetchAccess();
    if (!access.hasEntry) throw StateError('Нет доступа к документообороту');
    final values = await Future.wait<dynamic>(<Future<dynamic>>[
      fetchInstallation(companyId),
      access.canView
          ? fetchPackages(companyId)
          : Future<List<DocumentPackageRecord>>.value(
              const <DocumentPackageRecord>[],
            ),
      access.canView
          ? fetchOnboardings(companyId: companyId)
          : Future<List<EmployeeOnboardingRecord>>.value(
              const <EmployeeOnboardingRecord>[],
            ),
    ]);
    return DocumentWorkflowDashboardData(
      access: access,
      installation: values[0] as DocumentToolInstallation,
      packages: values[1] as List<DocumentPackageRecord>,
      onboardings: values[2] as List<EmployeeOnboardingRecord>,
    );
  }

  static Future<List<DocumentPackageRecord>> fetchPackages(
    String companyId,
  ) async {
    final rows = await _client
        .from('document_packages')
        .select(
          'id, company_id, code, title, description, onboarding_type, is_active',
        )
        .eq('company_id', companyId.trim())
        .eq('is_active', true)
        .order('title');
    return _rows(rows)
        .map(DocumentPackageRecord.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<DocumentPackageTemplateLink>> fetchPackageTemplateLinks({
    required String companyId,
    String? packageId,
  }) async {
    var query = _client
        .from('document_package_templates')
        .select('package_id, template_id, sort_order, is_required')
        .eq('company_id', companyId.trim());
    final cleanPackageId = packageId?.trim() ?? '';
    if (cleanPackageId.isNotEmpty) {
      query = query.eq('package_id', cleanPackageId);
    }
    final rows = await query.order('sort_order');
    return _rows(rows)
        .map(DocumentPackageTemplateLink.fromMap)
        .where(
          (item) => item.packageId.isNotEmpty && item.templateId.isNotEmpty,
        )
        .toList(growable: false);
  }

  static Future<DocumentPackageRecord> savePackage({
    String? id,
    required String companyId,
    required String title,
    required String description,
    required String onboardingType,
  }) async {
    final cleanCompanyId = _required(companyId, 'Компания не выбрана');
    final cleanTitle = _required(title, 'Введите название пакета');
    final data = <String, dynamic>{
      'company_id': cleanCompanyId,
      'title': cleanTitle,
      'description': description.trim(),
      'onboarding_type': onboardingType,
      'is_active': true,
    };
    Map<String, dynamic> row;
    final cleanId = id?.trim() ?? '';
    if (cleanId.isEmpty) {
      data['code'] =
          '${_slug(cleanTitle)}_${DateTime.now().toUtc().millisecondsSinceEpoch}';
      row = _map(
        await _client
            .from('document_packages')
            .insert(data)
            .select(
              'id, company_id, code, title, description, onboarding_type, is_active',
            )
            .single(),
      );
    } else {
      row = _map(
        await _client
            .from('document_packages')
            .update(data)
            .eq('id', cleanId)
            .eq('company_id', cleanCompanyId)
            .select(
              'id, company_id, code, title, description, onboarding_type, is_active',
            )
            .single(),
      );
    }
    final result = DocumentPackageRecord.fromMap(row);
    await recordAudit(
      companyId: cleanCompanyId,
      entityType: 'document_package',
      entityId: result.id,
      action: cleanId.isEmpty ? 'created' : 'updated',
      details: <String, dynamic>{'title': result.title},
    );
    return result;
  }

  static Future<void> replacePackageTemplates({
    required String companyId,
    required String packageId,
    required List<({String templateId, bool required})> templates,
  }) async {
    await _client.rpc(
      'replace_document_package_templates',
      params: <String, dynamic>{
        'p_company_id': companyId.trim(),
        'p_package_id': packageId.trim(),
        'p_templates': <Map<String, dynamic>>[
          for (final item in templates)
            <String, dynamic>{
              'template_id': item.templateId,
              'required': item.required,
            },
        ],
      },
    );
  }

  static Future<void> seedDefaultPackages(String companyId) async {
    await _client.rpc(
      'seed_default_document_packages',
      params: <String, dynamic>{'p_company_id': companyId.trim()},
    );
  }

  static Future<List<EmployeeOnboardingRecord>> fetchOnboardings({
    required String companyId,
    String? employeeId,
  }) async {
    var query = _client
        .from('employee_onboardings')
        .select(
          'id, company_id, recruitment_application_id, employee_id, package_id, '
          'object_id, status, current_step, onboarding_type, assigned_user_id, '
          'due_at, conditions, recognized_data, verification_data, '
          'completion_snapshot, created_at, updated_at, '
          'employees(fio), recruitment_applications(full_name), '
          'document_packages(title), objects(name)',
        )
        .eq('company_id', companyId.trim());
    final cleanEmployeeId = employeeId?.trim() ?? '';
    if (cleanEmployeeId.isNotEmpty) {
      query = query.eq('employee_id', cleanEmployeeId);
    }
    final rows = await query.order('updated_at', ascending: false).limit(500);
    return _rows(rows)
        .map(EmployeeOnboardingRecord.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<EmployeeOnboardingRecord> fetchOnboarding(
    String onboardingId,
  ) async {
    final row = await _client
        .from('employee_onboardings')
        .select(
          'id, company_id, recruitment_application_id, employee_id, package_id, '
          'object_id, status, current_step, onboarding_type, assigned_user_id, '
          'due_at, conditions, recognized_data, verification_data, '
          'completion_snapshot, created_at, updated_at, '
          'employees(fio), recruitment_applications(full_name), '
          'document_packages(title), objects(name)',
        )
        .eq('id', onboardingId.trim())
        .single();
    return EmployeeOnboardingRecord.fromMap(_map(row));
  }

  static Future<EmployeeOnboardingRecord> createOnboarding({
    required String companyId,
    String? recruitmentApplicationId,
    String? employeeId,
    String? packageId,
    String? objectId,
    String onboardingType = 'gph',
    String? assignedUserId,
    DateTime? dueAt,
    Map<String, dynamic> conditions = const <String, dynamic>{},
  }) async {
    final raw = await _client.rpc(
      'create_document_onboarding',
      params: <String, dynamic>{
        'p_company_id': companyId.trim(),
        'p_recruitment_application_id': _nullIfEmpty(recruitmentApplicationId),
        'p_employee_id': _nullIfEmpty(employeeId),
        'p_package_id': _nullIfEmpty(packageId),
        'p_object_id': _nullIfEmpty(objectId),
        'p_onboarding_type': onboardingType,
        'p_assigned_user_id': _nullIfEmpty(assignedUserId),
        'p_due_at': dueAt?.toUtc().toIso8601String(),
        'p_conditions': conditions,
      },
    );
    final id = raw?.toString().replaceAll('"', '').trim() ?? '';
    if (id.isEmpty) throw StateError('Сервер не вернул ID оформления');
    return fetchOnboarding(id);
  }

  static Future<void> setOnboardingContext({
    required String onboardingId,
    String? employeeId,
    String? packageId,
    String? objectId,
    String? onboardingType,
    Map<String, dynamic>? conditions,
    Map<String, dynamic>? recognizedData,
    Map<String, dynamic>? verificationData,
    String? assignedUserId,
    DateTime? dueAt,
  }) async {
    await _client.rpc(
      'set_document_onboarding_context',
      params: <String, dynamic>{
        'p_onboarding_id': onboardingId.trim(),
        'p_employee_id': _nullIfEmpty(employeeId),
        'p_package_id': _nullIfEmpty(packageId),
        'p_object_id': _nullIfEmpty(objectId),
        'p_onboarding_type': _nullIfEmpty(onboardingType),
        'p_conditions': conditions,
        'p_recognized_data': recognizedData,
        'p_verification_data': verificationData,
        'p_assigned_user_id': _nullIfEmpty(assignedUserId),
        'p_due_at': dueAt?.toUtc().toIso8601String(),
      },
    );
  }

  static Future<List<DocumentOnboardingStepRecord>> fetchSteps(
    String onboardingId,
  ) async {
    final rows = await _client
        .from('employee_onboarding_steps')
        .select(
          'id, onboarding_id, step_code, status, assigned_user_id, is_required, '
          'due_at, payload, completed_at',
        )
        .eq('onboarding_id', onboardingId.trim());
    final values = _rows(rows)
        .map(DocumentOnboardingStepRecord.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList();
    values.sort((first, second) {
      return DocumentOnboardingSteps.ordered
          .indexOf(first.stepCode)
          .compareTo(DocumentOnboardingSteps.ordered.indexOf(second.stepCode));
    });
    return values;
  }

  static Future<String> advanceOnboarding({
    required String onboardingId,
    required String currentStep,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final raw = await _client.rpc(
      'advance_document_onboarding',
      params: <String, dynamic>{
        'p_onboarding_id': onboardingId.trim(),
        'p_step_code': currentStep,
        'p_payload': payload,
      },
    );
    return raw?.toString().replaceAll('"', '') ?? '';
  }

  static Future<List<Map<String, dynamic>>> fetchBlockers(
    String onboardingId,
  ) async {
    final rows = await _client.rpc(
      'document_onboarding_blockers',
      params: <String, dynamic>{'p_onboarding_id': onboardingId.trim()},
    );
    return _rows(rows);
  }

  static Future<List<EmployeeDocumentFileRecord>> fetchFiles({
    required String companyId,
    String? onboardingId,
    String? employeeId,
  }) async {
    var query = _client
        .from('employee_document_files')
        .select(
          'id, company_id, onboarding_id, employee_id, file_kind, document_type, '
          'storage_bucket, storage_path, original_file_name, mime_type, '
          'file_size, version_no, template_id, template_version_id, metadata, '
          'quality_status, verification_status, created_at',
        )
        .eq('company_id', companyId.trim());
    final cleanOnboardingId = onboardingId?.trim() ?? '';
    final cleanEmployeeId = employeeId?.trim() ?? '';
    if (cleanOnboardingId.isNotEmpty) {
      query = query.eq('onboarding_id', cleanOnboardingId);
    }
    if (cleanEmployeeId.isNotEmpty) {
      query = query.eq('employee_id', cleanEmployeeId);
    }
    final rows = await query.order('created_at', ascending: false).limit(1000);
    return _rows(rows)
        .map(EmployeeDocumentFileRecord.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<EmployeeDocumentFileRecord> uploadFile({
    required String companyId,
    required String onboardingId,
    String? employeeId,
    required String fileKind,
    required String documentType,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? templateId,
    String? templateVersionId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    if (bytes.isEmpty) throw StateError('Выбранный файл пустой');
    if (bytes.length > maxUploadBytes) {
      throw StateError('Максимальный размер файла — 20 МБ');
    }
    final cleanCompanyId = _required(companyId, 'Компания не выбрана');
    final cleanOnboardingId = _required(
      onboardingId,
      'Процесс оформления не выбран',
    );
    final cleanName = _safeFileName(fileName);
    final version = await _nextFileVersion(
      companyId: cleanCompanyId,
      onboardingId: cleanOnboardingId,
      fileKind: fileKind,
      documentType: documentType,
    );
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final storagePath =
        '$cleanCompanyId/$cleanOnboardingId/$fileKind/${timestamp}_v$version-$cleanName';

    await _client.storage
        .from(employeeDocumentsBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            cacheControl: '3600',
            upsert: false,
          ),
        );

    try {
      final row = await _client
          .from('employee_document_files')
          .insert(<String, dynamic>{
            'company_id': cleanCompanyId,
            'onboarding_id': cleanOnboardingId,
            'employee_id': _nullIfEmpty(employeeId),
            'file_kind': fileKind,
            'document_type': documentType,
            'storage_bucket': employeeDocumentsBucket,
            'storage_path': storagePath,
            'original_file_name': fileName.trim().isEmpty
                ? cleanName
                : fileName,
            'mime_type': mimeType,
            'file_size': bytes.length,
            'version_no': version,
            'template_id': _nullIfEmpty(templateId),
            'template_version_id': _nullIfEmpty(templateVersionId),
            'metadata': <String, dynamic>{
              ...metadata,
              'uploaded_from': 'document_workflow_v3',
            },
          })
          .select()
          .single();
      final result = EmployeeDocumentFileRecord.fromMap(_map(row));
      await recordAudit(
        companyId: cleanCompanyId,
        onboardingId: cleanOnboardingId,
        employeeId: employeeId,
        entityType: 'employee_document_file',
        entityId: result.id,
        action: 'uploaded',
        details: <String, dynamic>{
          'file_kind': fileKind,
          'document_type': documentType,
          'version_no': version,
          'file_name': fileName,
        },
      );
      return result;
    } catch (_) {
      try {
        await _client.storage.from(employeeDocumentsBucket).remove(<String>[
          storagePath,
        ]);
      } catch (_) {
        // Orphan cleanup can be retried by a maintenance task.
      }
      rethrow;
    }
  }

  static Future<void> verifyFile({
    required String fileId,
    required bool accepted,
    String qualityStatus = 'accepted',
    String comment = '',
  }) async {
    await _client.rpc(
      'verify_employee_document_file',
      params: <String, dynamic>{
        'p_file_id': fileId.trim(),
        'p_accepted': accepted,
        'p_quality_status': qualityStatus,
        'p_comment': comment.trim(),
      },
    );
  }

  static Future<String> createSignedFileUrl(
    EmployeeDocumentFileRecord file, {
    int expiresInSeconds = 300,
  }) async {
    if (file.storageBucket.trim().isEmpty || file.storagePath.trim().isEmpty) {
      throw StateError('У файла отсутствует путь в хранилище');
    }
    return _client.storage
        .from(file.storageBucket)
        .createSignedUrl(file.storagePath, expiresInSeconds);
  }

  static Future<List<DocumentAuditRecord>> fetchAudit({
    required String companyId,
    String? onboardingId,
  }) async {
    var query = _client
        .from('document_audit_log')
        .select(
          'id, entity_type, entity_id, action, actor_user_id, details, created_at',
        )
        .eq('company_id', companyId.trim());
    final cleanOnboardingId = onboardingId?.trim() ?? '';
    if (cleanOnboardingId.isNotEmpty) {
      query = query.eq('onboarding_id', cleanOnboardingId);
    }
    final rows = await query.order('created_at', ascending: false).limit(500);
    return _rows(rows).map(DocumentAuditRecord.fromMap).toList(growable: false);
  }

  static Future<void> recordAudit({
    required String companyId,
    String? onboardingId,
    String? employeeId,
    required String entityType,
    required String entityId,
    required String action,
    Map<String, dynamic> details = const <String, dynamic>{},
  }) async {
    await _client.rpc(
      'record_document_workflow_audit',
      params: <String, dynamic>{
        'p_company_id': companyId.trim(),
        'p_onboarding_id': _nullIfEmpty(onboardingId),
        'p_employee_id': _nullIfEmpty(employeeId),
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_action': action,
        'p_details': details,
      },
    );
  }

  static Future<List<DocumentCandidateOption>> fetchCandidates(
    String companyId,
  ) async {
    final rows = await _client
        .from('recruitment_applications')
        .select(
          'id, full_name, phone, object_id, position_title, employee_id, objects(name)',
        )
        .eq('company_id', companyId.trim())
        .order('updated_at', ascending: false)
        .limit(500);
    return _rows(rows)
        .map(DocumentCandidateOption.fromMap)
        .where((item) => item.id.isNotEmpty && item.fullName.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<DocumentEmployeeOption>> fetchEmployees(
    String companyId,
  ) async {
    final rows = await _client
        .from('employees')
        .select('id, fio, phone, position, object_id, object_name')
        .eq('company_id', companyId.trim())
        .order('fio')
        .limit(1000);
    return _rows(rows)
        .map(DocumentEmployeeOption.fromMap)
        .where((item) => item.id.isNotEmpty && item.fullName.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<DocumentObjectOption>> fetchObjects(
    String companyId,
  ) async {
    final rows = await _client
        .from('objects')
        .select('id, name')
        .eq('company_id', companyId.trim())
        .eq('is_active', true)
        .order('name');
    return _rows(rows)
        .map(DocumentObjectOption.fromMap)
        .where((item) => item.id.isNotEmpty && item.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Future<int> _nextFileVersion({
    required String companyId,
    required String onboardingId,
    required String fileKind,
    required String documentType,
  }) async {
    final rows = await _client
        .from('employee_document_files')
        .select('version_no')
        .eq('company_id', companyId)
        .eq('onboarding_id', onboardingId)
        .eq('file_kind', fileKind)
        .eq('document_type', documentType)
        .order('version_no', ascending: false)
        .limit(1);
    final values = _rows(rows);
    if (values.isEmpty) return 1;
    return intValue(values.first['version_no']) + 1;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static String _required(String value, String message) {
    final clean = value.trim();
    if (clean.isEmpty) throw StateError(message);
    return clean;
  }

  static String? _nullIfEmpty(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }

  static String _safeFileName(String value) {
    final clean = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Zа-яА-Я0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return clean.isEmpty ? 'document' : clean;
  }

  static String _slug(String value) {
    final clean = value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return clean.isEmpty ? 'package' : clean;
  }
}
