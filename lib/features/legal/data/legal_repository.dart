import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../../data/app_data_sync.dart';
import '../../../data/notification_repository.dart';
import '../../../services/push_notification_service.dart';
import '../models/legal_models.dart';

part 'legal_directory_repository_part.dart';
part 'legal_document_repository_part.dart';
part 'legal_matter_repository_part.dart';
part 'legal_report_repository_part.dart';

final SupabaseClient _client = Supabase.instance.client;
const String legalBucket = 'legal-files';

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

String _dateOnly(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _optionalDate(DateTime? value) {
  return value == null ? null : _dateOnly(value);
}

String? _optionalDateTime(DateTime? value) {
  return value?.toUtc().toIso8601String();
}

String _clean(String? value) => value?.trim() ?? '';

abstract final class LegalRepository {
  static Future<List<LegalDirectoryItem>> fetchEmployeeDirectory() =>
      _LegalDirectories.fetchEmployeeDirectory();
  static Future<List<LegalDirectoryItem>> fetchObjectDirectory() =>
      _LegalDirectories.fetchObjectDirectory();
  static Future<List<LegalDirectoryItem>> fetchResponsibleDirectory() =>
      _LegalDirectories.fetchResponsibleDirectory();
  static Future<List<LegalCounterparty>> fetchCounterparties() =>
      _LegalDirectories.fetchCounterparties();
  static Future<LegalCounterparty> addCounterparty({
    required String name,
    required String category,
    String inn = '',
    String kpp = '',
    String ogrn = '',
    String contactName = '',
    String phone = '',
    String email = '',
    String comment = '',
  }) => _LegalDirectories.addCounterparty(
    name: name,
    category: category,
    inn: inn,
    kpp: kpp,
    ogrn: ogrn,
    contactName: contactName,
    phone: phone,
    email: email,
    comment: comment,
  );

  static Future<List<LegalDocument>> fetchDocuments({
    String search = '',
    String? status,
    bool attentionOnly = false,
  }) => _LegalDocuments.fetchDocuments(
    search: search,
    status: status,
    attentionOnly: attentionOnly,
  );
  static Future<LegalDocument> fetchDocument(String id) =>
      _LegalDocuments.fetchDocument(id);
  static Future<LegalDocument> saveDocument({
    String? id,
    required String title,
    required String documentType,
    required String documentNumber,
    required String status,
    required DateTime createdOn,
    DateTime? signedOn,
    DateTime? validFrom,
    DateTime? expiresOn,
    String? responsibleUserId,
    String? employeeId,
    String? objectId,
    String? counterpartyId,
    String? taskId,
    String? legalMatterId,
    required String comment,
    required String nextAction,
    DateTime? nextActionDueAt,
    required bool requiresForemanAction,
    required bool requiresManagerApproval,
    required String approvalStatus,
  }) => _LegalDocuments.saveDocument(
    id: id,
    title: title,
    documentType: documentType,
    documentNumber: documentNumber,
    status: status,
    createdOn: createdOn,
    signedOn: signedOn,
    validFrom: validFrom,
    expiresOn: expiresOn,
    responsibleUserId: responsibleUserId,
    employeeId: employeeId,
    objectId: objectId,
    counterpartyId: counterpartyId,
    taskId: taskId,
    legalMatterId: legalMatterId,
    comment: comment,
    nextAction: nextAction,
    nextActionDueAt: nextActionDueAt,
    requiresForemanAction: requiresForemanAction,
    requiresManagerApproval: requiresManagerApproval,
    approvalStatus: approvalStatus,
  );
  static Future<void> approveDocument({
    required String documentId,
    required bool approved,
  }) => _LegalDocuments.approveDocument(
    documentId: documentId,
    approved: approved,
  );
  static Future<List<LegalFile>> fetchDocumentFiles(String documentId) =>
      _LegalDocuments.fetchDocumentFiles(documentId);
  static Future<List<LegalFile>> pickAndUploadFiles({
    required String companyId,
    required String documentId,
  }) => _LegalDocuments.pickAndUploadFiles(
    companyId: companyId,
    documentId: documentId,
  );
  static Future<void> openFile(LegalFile file) =>
      _LegalDocuments.openFile(file);

  static Future<List<LegalMatter>> fetchMatters({
    String search = '',
    bool attentionOnly = false,
  }) => _LegalMatters.fetchMatters(
    search: search,
    attentionOnly: attentionOnly,
  );
  static Future<LegalMatter> fetchMatter(String id) =>
      _LegalMatters.fetchMatter(id);
  static Future<LegalMatter> saveMatter({
    String? id,
    required String matterType,
    required String title,
    required String description,
    required String riskLevel,
    required String status,
    DateTime? dueAt,
    String? responsibleUserId,
    String? employeeId,
    String? objectId,
    String? counterpartyId,
    String? documentId,
    required String requiredActions,
    required String result,
    required bool requiresForemanAction,
    required bool requiresManagerDecision,
    required String managerQuestion,
    required String decisionStatus,
    required String decisionComment,
  }) => _LegalMatters.saveMatter(
    id: id,
    matterType: matterType,
    title: title,
    description: description,
    riskLevel: riskLevel,
    status: status,
    dueAt: dueAt,
    responsibleUserId: responsibleUserId,
    employeeId: employeeId,
    objectId: objectId,
    counterpartyId: counterpartyId,
    documentId: documentId,
    requiredActions: requiredActions,
    result: result,
    requiresForemanAction: requiresForemanAction,
    requiresManagerDecision: requiresManagerDecision,
    managerQuestion: managerQuestion,
    decisionStatus: decisionStatus,
    decisionComment: decisionComment,
  );
  static Future<void> decideMatter({
    required String matterId,
    required bool approved,
    required String comment,
  }) => _LegalMatters.decideMatter(
    matterId: matterId,
    approved: approved,
    comment: comment,
  );

  static Future<LegalDashboardData> fetchDashboard() =>
      _LegalReports.fetchDashboard();
  static Future<void> refreshReminders() =>
      _LegalReports.refreshReminders();
  static DateTime currentWeekStart([DateTime? value]) =>
      _LegalReports.currentWeekStart(value);
  static Map<String, dynamic> buildWeeklyDraft({
    required List<LegalDocument> documents,
    required List<LegalMatter> matters,
    required DateTime weekStart,
  }) => _LegalReports.buildWeeklyDraft(
    documents: documents,
    matters: matters,
    weekStart: weekStart,
  );
  static Future<LegalWeeklyReport?> fetchLatestWeeklyReport() =>
      _LegalReports.fetchLatestWeeklyReport();
  static Future<LegalWeeklyReport?> fetchCurrentWeeklyReport() =>
      _LegalReports.fetchCurrentWeeklyReport();
  static Future<LegalWeeklyReport> saveWeeklyReport({
    required Map<String, dynamic> autoDraft,
    required String authorComment,
    required String nextWeekPlan,
    required String managerDecisions,
    required bool submit,
  }) => _LegalReports.saveWeeklyReport(
    autoDraft: autoDraft,
    authorComment: authorComment,
    nextWeekPlan: nextWeekPlan,
    managerDecisions: managerDecisions,
    submit: submit,
  );
}

void _notifyLegalChanged(String table, {String? entityId}) {
  AppDataSync.notifyLocal(
    const <AppDataDomain>{AppDataDomain.legal},
    context: <String, dynamic>{
      'table': table,
      'entity_id': entityId,
    },
  );
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
