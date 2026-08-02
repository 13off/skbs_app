import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/document_onboarding.dart';

class DocumentWorkflowDashboardData {
  final DocumentToolInstallation installation;
  final List<DocumentPackageRecord> packages;
  final List<EmployeeOnboardingRecord> onboardings;
  final Map<String, int> counters;

  const DocumentWorkflowDashboardData({
    required this.installation,
    required this.packages,
    required this.onboardings,
    required this.counters,
  });
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
  bool get isBlocked => status == 'blocked';

  factory DocumentOnboardingStepRecord.fromMap(Map<String, dynamic> map) {
    return DocumentOnboardingStepRecord(
      id: map['id']?.toString() ?? '',
      onboardingId: map['onboarding_id']?.toString() ?? '',
      stepCode: map['step_code']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      isRequired: map['is_required'] != false,
      assignedUserId: _nullableText(map['assigned_user_id']),
      dueAt: _date(map['due_at']),
      payload: _map(map['payload']),
      completedAt: _date(map['completed_at']),
    );
  }
}

class EmployeeDocumentFileRecord {
  final String id;
  final String? onboardingId;
  final String? employeeId;
  final String fileKind;
  final String documentType;
  final String storageBucket;
  final String storagePath;
  final String originalFileName;
  final String mimeType;
  final int versionNo;
  final String qualityStatus;
  final String verificationStatus;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const EmployeeDocumentFileRecord({
    required this.id,
    required this.onboardingId,
    required this.employeeId,
    required this.fileKind,
    required this.documentType,
    required this.storageBucket,
    required this.storagePath,
    required this.originalFileName,
    required this.mimeType,
    required this.versionNo,
    required this.qualityStatus,
    required this.verificationStatus,
    required this.metadata,
    required this.createdAt,
  });

  factory EmployeeDocumentFileRecord.fromMap(Map<String, dynamic> map) {
    return EmployeeDocumentFileRecord(
      id: map['id']?.toString() ?? '',
      onboardingId: _nullableText(map['onboarding_id']),
      employeeId: _nullableText(map['employee_id']),
      fileKind: map['file_kind']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? '',
      storageBucket: map['storage_bucket']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      originalFileName: map['original_file_name']?.toString() ?? '',
      mimeType: map['mime_type']?.toString() ?? 'application/octet-stream',
      versionNo: (map['version_no'] as num?)?.toInt() ?? 1,
      qualityStatus: map['quality_status']?.toString() ?? 'not_checked',
      verificationStatus: map['verification_status']?.toString() ?? 'pending',
      metadata: _map(map['metadata']),
      createdAt: _date(map['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DocumentAuditRecord {
  final int id;
  final String entityType;
  final String entityId;
  final String action;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const DocumentAuditRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.details,
    required this.createdAt,
  });

  factory DocumentAuditRecord.fromMap(Map<String, dynamic> map) {
    return DocumentAuditRecord(
      id: (map['id'] as num?)?.toInt() ?? 0,
      entityType: map['entity_type']?.toString() ?? '',
      entityId: map['entity_id']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      details: _map(map['details']),
      createdAt: _date(map['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DocumentWorkflowRepository {
  DocumentWorkflowRepository._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String employeeBucket = 'employee-documents';

  static Future<DocumentToolInstallation> fetchInstallation(String companyId) async {
    final rows = await _client
        .from('document_tool_installations')
        .select('company_id, is_enabled, settings')
        .eq('company_id', companyId)
        .limit(1);
    if (rows is List && rows.isNotEmpty) {
      return DocumentToolInstallation.fromMap(Map<String, dynamic>.from(rows.first as Map));
    }
    return DocumentToolInstallation(
      companyId: companyId,
      isEnabled: false,
      settings: const <String, dynamic>{},
    );
  }

  static Future<void> setInstallation({
    required String companyId,
    required bool enabled,
    Map<String, dynamic>? settings,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('document_tool_installations').upsert(<String, dynamic>{
      'company_id': companyId,
      'is_enabled': enabled,
      'settings': settings ?? const <String, dynamic>{},
      'enabled_at': enabled ? DateTime.now().toUtc().toIso8601String() : null,
      'enabled_by': enabled ? userId : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await audit(
      companyId: companyId,
      entityType: 'document_tool_installation',
      entityId: companyId,
      action: enabled ? 'enabled' : 'disabled',
    );
  }

  static Future<List<DocumentPackageRecord>> fetchPackages(String companyId) async {
    final rows = await _client
        .from('document_packages')
        .select('id, company_id, code, title, description, onboarding_type, is_active')
        .eq('company_id', companyId)
        .order('title');
    return rows
        .whereType<Map>()
        .map((row) => DocumentPackageRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static Future<DocumentPackageRecord> savePackage({
    String? id,
    required String companyId,
    required String title,
    required String onboardingType,
    String description = '',
    bool isActive = true,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw StateError('Введите название пакета');
    final code = id == null ? _slug(cleanTitle) : null;
    final values = <String, dynamic>{
      'company_id': companyId,
      'title': cleanTitle,
      'description': description.trim(),
      'onboarding_type': onboardingType,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    Map<String, dynamic> row;
    if (id == null) {
      values['code'] = '${code}_${DateTime.now().millisecondsSinceEpoch}';
      values['created_by'] = _client.auth.currentUser?.id;
      row = Map<String, dynamic>.from(await _client
          .from('document_packages')
          .insert(values)
          .select('id, company_id, code, title, description, onboarding_type, is_active')
          .single());
    } else {
      row = Map<String, dynamic>.from(await _client
          .from('document_packages')
          .update(values)
          .eq('id', id)
          .select('id, company_id, code, title, description, onboarding_type, is_active')
          .single());
    }
    final result = DocumentPackageRecord.fromMap(row);
    await audit(
      companyId: companyId,
      entityType: 'document_package',
      entityId: result.id,
      action: id == null ? 'created' : 'updated',
    );
    return result;
  }

  static Future<void> replacePackageTemplates({
    required String companyId,
    required String packageId,
    required List<({String templateId, bool required})> templates,
  }) async {
    await _client.from('document_package_templates').delete().eq('package_id', packageId);
    if (templates.isNotEmpty) {
      await _client.from('document_package_templates').insert([
        for (var index = 0; index < templates.length; index++)
          <String, dynamic>{
            'company_id': companyId,
            'package_id': packageId,
            'template_id': templates[index].templateId,
            'sort_order': index,
            'is_required': templates[index].required,
          },
      ]);
    }
    await audit(
      companyId: companyId,
      entityType: 'document_package',
      entityId: packageId,
      action: 'templates_replaced',
      details: <String, dynamic>{'count': templates.length},
    );
  }

  static Future<List<EmployeeOnboardingRecord>> fetchOnboardings({
    required String companyId,
    String? employeeId,
    String? status,
  }) async {
    var query = _client
        .from('employee_onboardings')
        .select('id, company_id, employee_id, package_id, status, current_step, onboarding_type, assigned_user_id, due_at, created_at, updated_at')
        .eq('company_id', companyId);
    if (employeeId != null && employeeId.trim().isNotEmpty) {
      query = query.eq('employee_id', employeeId.trim());
    }
    if (status != null && status.trim().isNotEmpty) {
      query = query.eq('status', status.trim());
    }
    final rows = await query.order('updated_at', ascending: false);
    return rows
        .whereType<Map>()
        .map((row) => EmployeeOnboardingRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static Future<EmployeeOnboardingRecord> createOnboarding({
    required String companyId,
    String? employeeId,
    String? packageId,
    String onboardingType = 'custom',
    String? assignedUserId,
    DateTime? dueAt,
    Map<String, dynamic>? conditions,
  }) async {
    final row = Map<String, dynamic>.from(await _client
        .from('employee_onboardings')
        .insert(<String, dynamic>{
          'company_id': companyId,
          'employee_id': _emptyToNull(employeeId),
          'package_id': _emptyToNull(packageId),
          'status': 'in_progress',
          'current_step': DocumentOnboardingSteps.sourceFiles,
          'onboarding_type': onboardingType,
          'assigned_user_id': _emptyToNull(assignedUserId),
          'due_at': dueAt?.toUtc().toIso8601String(),
          'conditions': conditions ?? const <String, dynamic>{},
          'created_by': _client.auth.currentUser?.id,
        })
        .select('id, company_id, employee_id, package_id, status, current_step, onboarding_type, assigned_user_id, due_at, created_at, updated_at')
        .single());
    final onboarding = EmployeeOnboardingRecord.fromMap(row);
    await _client.from('employee_onboarding_steps').insert([
      for (final code in DocumentOnboardingSteps.ordered)
        <String, dynamic>{
          'company_id': companyId,
          'onboarding_id': onboarding.id,
          'step_code': code,
          'status': code == DocumentOnboardingSteps.sourceFiles ? 'in_progress' : 'pending',
          'assigned_user_id': _emptyToNull(assignedUserId),
          'is_required': true,
        },
    ]);
    await audit(
      companyId: companyId,
      onboardingId: onboarding.id,
      employeeId: employeeId,
      entityType: 'employee_onboarding',
      entityId: onboarding.id,
      action: 'created',
    );
    return onboarding;
  }

  static Future<List<DocumentOnboardingStepRecord>> fetchSteps(String onboardingId) async {
    final rows = await _client
        .from('employee_onboarding_steps')
        .select('id, onboarding_id, step_code, status, is_required, assigned_user_id, due_at, payload, completed_at')
        .eq('onboarding_id', onboardingId);
    final result = rows
        .whereType<Map>()
        .map((row) => DocumentOnboardingStepRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList();
    result.sort((a, b) => DocumentOnboardingSteps.ordered.indexOf(a.stepCode).compareTo(DocumentOnboardingSteps.ordered.indexOf(b.stepCode)));
    return result;
  }

  static Future<void> saveStep({
    required String companyId,
    required String onboardingId,
    required String stepCode,
    required String status,
    Map<String, dynamic>? payload,
    String? assignedUserId,
  }) async {
    final completed = status == 'completed';
    await _client.from('employee_onboarding_steps').update(<String, dynamic>{
      'status': status,
      'payload': payload ?? const <String, dynamic>{},
      'assigned_user_id': _emptyToNull(assignedUserId),
      'completed_at': completed ? DateTime.now().toUtc().toIso8601String() : null,
      'completed_by': completed ? _client.auth.currentUser?.id : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('onboarding_id', onboardingId).eq('step_code', stepCode);
    await audit(
      companyId: companyId,
      onboardingId: onboardingId,
      entityType: 'employee_onboarding_step',
      entityId: '$onboardingId:$stepCode',
      action: status,
      details: payload,
    );
  }

  static Future<void> advanceOnboarding({
    required String companyId,
    required String onboardingId,
    required String currentStep,
    Map<String, dynamic>? payload,
  }) async {
    await saveStep(
      companyId: companyId,
      onboardingId: onboardingId,
      stepCode: currentStep,
      status: 'completed',
      payload: payload,
    );
    final currentIndex = DocumentOnboardingSteps.ordered.indexOf(currentStep);
    if (currentIndex < 0) throw StateError('Неизвестный этап оформления');
    if (currentIndex == DocumentOnboardingSteps.ordered.length - 1) {
      await completeOnboarding(companyId: companyId, onboardingId: onboardingId);
      return;
    }
    final next = DocumentOnboardingSteps.ordered[currentIndex + 1];
    await _client.from('employee_onboarding_steps').update(<String, dynamic>{
      'status': 'in_progress',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('onboarding_id', onboardingId).eq('step_code', next);
    await _client.from('employee_onboardings').update(<String, dynamic>{
      'current_step': next,
      'status': 'in_progress',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', onboardingId);
  }

  static Future<void> completeOnboarding({
    required String companyId,
    required String onboardingId,
  }) async {
    final blockers = await _client.rpc('document_onboarding_blockers', params: <String, dynamic>{
      'p_onboarding_id': onboardingId,
    });
    if (blockers is List && blockers.isNotEmpty) {
      final titles = blockers.whereType<Map>().map((row) => row['message']?.toString() ?? '').where((value) => value.isNotEmpty).join('\n');
      throw StateError(titles.isEmpty ? 'Оформление не прошло проверку комплектности' : titles);
    }
    await _client.from('employee_onboardings').update(<String, dynamic>{
      'status': 'completed',
      'current_step': DocumentOnboardingSteps.completion,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'completed_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', onboardingId);
    await audit(
      companyId: companyId,
      onboardingId: onboardingId,
      entityType: 'employee_onboarding',
      entityId: onboardingId,
      action: 'completed',
    );
  }

  static Future<List<EmployeeDocumentFileRecord>> fetchFiles({
    required String companyId,
    String? onboardingId,
    String? employeeId,
  }) async {
    var query = _client
        .from('employee_document_files')
        .select('id, onboarding_id, employee_id, file_kind, document_type, storage_bucket, storage_path, original_file_name, mime_type, version_no, quality_status, verification_status, metadata, created_at')
        .eq('company_id', companyId);
    if (onboardingId != null && onboardingId.isNotEmpty) query = query.eq('onboarding_id', onboardingId);
    if (employeeId != null && employeeId.isNotEmpty) query = query.eq('employee_id', employeeId);
    final rows = await query.order('created_at', ascending: false);
    return rows
        .whereType<Map>()
        .map((row) => EmployeeDocumentFileRecord.fromMap(Map<String, dynamic>.from(row)))
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
    Map<String, dynamic>? metadata,
  }) async {
    if (bytes.isEmpty) throw StateError('Файл пустой');
    if (bytes.length > 30 * 1024 * 1024) throw StateError('Максимальный размер файла — 30 МБ');
    final previous = await _client
        .from('employee_document_files')
        .select('version_no')
        .eq('company_id', companyId)
        .eq('onboarding_id', onboardingId)
        .eq('file_kind', fileKind)
        .eq('document_type', documentType)
        .order('version_no', ascending: false)
        .limit(1);
    final version = previous is List && previous.isNotEmpty
        ? ((previous.first as Map)['version_no'] as num? ?? 0).toInt() + 1
        : 1;
    final safeName = _safeFileName(fileName);
    final storagePath = '$companyId/$onboardingId/$fileKind/$documentType/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _client.storage.from(employeeBucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );
    try {
      final row = Map<String, dynamic>.from(await _client
          .from('employee_document_files')
          .insert(<String, dynamic>{
            'company_id': companyId,
            'onboarding_id': onboardingId,
            'employee_id': _emptyToNull(employeeId),
            'file_kind': fileKind,
            'document_type': documentType,
            'storage_bucket': employeeBucket,
            'storage_path': storagePath,
            'original_file_name': fileName,
            'mime_type': mimeType,
            'file_size': bytes.length,
            'version_no': version,
            'template_id': _emptyToNull(templateId),
            'template_version_id': _emptyToNull(templateVersionId),
            'metadata': metadata ?? const <String, dynamic>{},
            'uploaded_by': _client.auth.currentUser?.id,
          })
          .select('id, onboarding_id, employee_id, file_kind, document_type, storage_bucket, storage_path, original_file_name, mime_type, version_no, quality_status, verification_status, metadata, created_at')
          .single());
      final file = EmployeeDocumentFileRecord.fromMap(row);
      await audit(
        companyId: companyId,
        onboardingId: onboardingId,
        employeeId: employeeId,
        entityType: 'employee_document_file',
        entityId: file.id,
        action: 'uploaded',
        details: <String, dynamic>{
          'file_kind': fileKind,
          'document_type': documentType,
          'version_no': version,
        },
      );
      return file;
    } catch (_) {
      await _client.storage.from(employeeBucket).remove(<String>[storagePath]);
      rethrow;
    }
  }

  static Future<String> createSignedFileUrl(EmployeeDocumentFileRecord file) {
    return _client.storage.from(file.storageBucket).createSignedUrl(file.storagePath, 600);
  }

  static Future<void> verifyFile({
    required String companyId,
    required String fileId,
    required String onboardingId,
    required bool accepted,
    String qualityStatus = 'accepted',
  }) async {
    await _client.from('employee_document_files').update(<String, dynamic>{
      'verification_status': accepted ? 'accepted' : 'rejected',
      'quality_status': accepted ? qualityStatus : 'rejected',
    }).eq('id', fileId);
    await audit(
      companyId: companyId,
      onboardingId: onboardingId,
      entityType: 'employee_document_file',
      entityId: fileId,
      action: accepted ? 'accepted' : 'rejected',
    );
  }

  static Future<List<DocumentAuditRecord>> fetchAudit({
    required String companyId,
    String? onboardingId,
    int limit = 100,
  }) async {
    var query = _client
        .from('document_audit_log')
        .select('id, entity_type, entity_id, action, details, created_at')
        .eq('company_id', companyId);
    if (onboardingId != null && onboardingId.isNotEmpty) query = query.eq('onboarding_id', onboardingId);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows
        .whereType<Map>()
        .map((row) => DocumentAuditRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static Future<DocumentWorkflowDashboardData> fetchDashboard(String companyId) async {
    final values = await Future.wait<dynamic>([
      fetchInstallation(companyId),
      fetchPackages(companyId),
      fetchOnboardings(companyId: companyId),
    ]);
    final onboardings = values[2] as List<EmployeeOnboardingRecord>;
    return DocumentWorkflowDashboardData(
      installation: values[0] as DocumentToolInstallation,
      packages: values[1] as List<DocumentPackageRecord>,
      onboardings: onboardings,
      counters: <String, int>{
        'active': onboardings.where((item) => !item.isCompleted).length,
        'completed': onboardings.where((item) => item.isCompleted).length,
        'overdue': onboardings.where((item) => item.dueAt != null && item.dueAt!.isBefore(DateTime.now()) && !item.isCompleted).length,
      },
    );
  }

  static Future<void> audit({
    required String companyId,
    String? onboardingId,
    String? employeeId,
    required String entityType,
    required String entityId,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    await _client.from('document_audit_log').insert(<String, dynamic>{
      'company_id': companyId,
      'onboarding_id': _emptyToNull(onboardingId),
      'employee_id': _emptyToNull(employeeId),
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'actor_user_id': _client.auth.currentUser?.id,
      'details': details ?? const <String, dynamic>{},
    });
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

String? _emptyToNull(String? value) {
  final clean = value?.trim() ?? '';
  return clean.isEmpty ? null : clean;
}

String _safeFileName(String value) {
  final clean = value.trim().replaceAll(RegExp(r'[^a-zA-Zа-яА-Я0-9._-]+'), '_');
  return clean.isEmpty ? 'document.bin' : clean;
}

String _slug(String value) {
  final clean = value.toLowerCase().trim().replaceAll(RegExp(r'[^a-zа-я0-9]+'), '_');
  return clean.replaceAll(RegExp(r'^_+|_+$'), '');
}
