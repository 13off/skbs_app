import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

int _workspaceInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
double _workspaceDouble(dynamic value) =>
    double.tryParse(value?.toString() ?? '') ?? 0;
DateTime? _workspaceDate(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();
Map<String, dynamic> _workspaceMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : const <String, dynamic>{};
List<dynamic> _workspaceList(dynamic value) =>
    value is List ? value : const <dynamic>[];

class LegalWorkspaceEmployee {
  final String id;
  final String fio;
  final String position;
  final String objectId;
  final String objectName;
  final bool isActive;
  final int documentsCount;
  final int contractsCount;
  final int actsCount;
  final int mattersCount;
  final int finesCount;
  final int pendingFinesCount;

  const LegalWorkspaceEmployee({
    required this.id,
    required this.fio,
    required this.position,
    required this.objectId,
    required this.objectName,
    required this.isActive,
    required this.documentsCount,
    required this.contractsCount,
    required this.actsCount,
    required this.mattersCount,
    required this.finesCount,
    required this.pendingFinesCount,
  });

  factory LegalWorkspaceEmployee.fromMap(Map<String, dynamic> map) {
    return LegalWorkspaceEmployee(
      id: map['id']?.toString() ?? '',
      fio: map['fio']?.toString() ?? '',
      position: map['position']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      isActive: map['is_active'] == true,
      documentsCount: _workspaceInt(map['documents_count']),
      contractsCount: _workspaceInt(map['contracts_count']),
      actsCount: _workspaceInt(map['acts_count']),
      mattersCount: _workspaceInt(map['matters_count']),
      finesCount: _workspaceInt(map['fines_count']),
      pendingFinesCount: _workspaceInt(map['pending_fines_count']),
    );
  }
}

class LegalWorkspaceObject {
  final String id;
  final String name;
  final String address;
  final bool isActive;
  final int employeesCount;
  final int contractsCount;
  final int actsCount;
  final int mattersCount;
  final int openMattersCount;

  const LegalWorkspaceObject({
    required this.id,
    required this.name,
    required this.address,
    required this.isActive,
    required this.employeesCount,
    required this.contractsCount,
    required this.actsCount,
    required this.mattersCount,
    required this.openMattersCount,
  });

  factory LegalWorkspaceObject.fromMap(Map<String, dynamic> map) {
    return LegalWorkspaceObject(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      isActive: map['is_active'] == true,
      employeesCount: _workspaceInt(map['employees_count']),
      contractsCount: _workspaceInt(map['contracts_count']),
      actsCount: _workspaceInt(map['acts_count']),
      mattersCount: _workspaceInt(map['matters_count']),
      openMattersCount: _workspaceInt(map['open_matters_count']),
    );
  }
}

class LegalWorkspaceDocument {
  final String sourceType;
  final String sourceId;
  final String employeeId;
  final String employeeName;
  final String objectId;
  final String objectName;
  final String title;
  final String category;
  final String documentType;
  final String status;
  final String fileName;
  final String bucketName;
  final String storagePath;
  final DateTime? documentDate;
  final String legalDocumentId;

  const LegalWorkspaceDocument({
    required this.sourceType,
    required this.sourceId,
    required this.employeeId,
    required this.employeeName,
    required this.objectId,
    required this.objectName,
    required this.title,
    required this.category,
    required this.documentType,
    required this.status,
    required this.fileName,
    required this.bucketName,
    required this.storagePath,
    required this.documentDate,
    required this.legalDocumentId,
  });

  factory LegalWorkspaceDocument.fromMap(Map<String, dynamic> map) {
    return LegalWorkspaceDocument(
      sourceType: map['source_type']?.toString() ?? '',
      sourceId: map['source_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      employeeName: map['employee_name']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Документ',
      category: map['category']?.toString() ?? 'document',
      documentType: map['document_type']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? '',
      bucketName: map['bucket_name']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      documentDate: _workspaceDate(map['document_date']),
      legalDocumentId: map['legal_document_id']?.toString() ?? '',
    );
  }

  bool get hasStoredFile => bucketName.isNotEmpty && storagePath.isNotEmpty;
}

class LegalWorkspaceRecovery {
  final String id;
  final String employeeId;
  final String employeeName;
  final String objectId;
  final String objectName;
  final DateTime absenceDate;
  final double amount;
  final String status;
  final String actFileName;
  final String actFilePath;
  final String explanationFileName;
  final String explanationFilePath;
  final DateTime? createdAt;
  final DateTime? confirmedAt;

  const LegalWorkspaceRecovery({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.objectId,
    required this.objectName,
    required this.absenceDate,
    required this.amount,
    required this.status,
    required this.actFileName,
    required this.actFilePath,
    required this.explanationFileName,
    required this.explanationFilePath,
    required this.createdAt,
    required this.confirmedAt,
  });

  factory LegalWorkspaceRecovery.fromMap(Map<String, dynamic> map) {
    return LegalWorkspaceRecovery(
      id: map['id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      employeeName: map['employee_name']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      absenceDate:
          DateTime.tryParse(map['absence_date']?.toString() ?? '') ??
          DateTime.now(),
      amount: _workspaceDouble(map['amount']),
      status: map['status']?.toString() ?? '',
      actFileName: map['act_file_name']?.toString() ?? '',
      actFilePath: map['act_file_path']?.toString() ?? '',
      explanationFileName: map['explanation_file_name']?.toString() ?? '',
      explanationFilePath: map['explanation_file_path']?.toString() ?? '',
      createdAt: _workspaceDate(map['created_at']),
      confirmedAt: _workspaceDate(map['confirmed_at']),
    );
  }
}

class LegalWorkspaceSnapshot {
  final List<LegalWorkspaceEmployee> employees;
  final List<LegalWorkspaceObject> objects;
  final List<LegalWorkspaceDocument> documents;
  final List<LegalWorkspaceRecovery> recoveries;

  const LegalWorkspaceSnapshot({
    required this.employees,
    required this.objects,
    required this.documents,
    required this.recoveries,
  });

  List<LegalWorkspaceDocument> get contracts =>
      documents.where((item) => item.category == 'contract').toList();
  List<LegalWorkspaceDocument> get acts =>
      documents.where((item) => item.category == 'act').toList();
}

abstract final class LegalWorkspaceRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<LegalWorkspaceEmployee>> fetchEmployees() async {
    final response = await _client.rpc('legal_workspace_employee_directory');
    return _workspaceList(response)
        .map((value) => LegalWorkspaceEmployee.fromMap(_workspaceMap(value)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<List<LegalWorkspaceObject>> fetchObjects() async {
    final response = await _client.rpc('legal_workspace_object_directory');
    return _workspaceList(response)
        .map((value) => LegalWorkspaceObject.fromMap(_workspaceMap(value)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<List<LegalWorkspaceDocument>> fetchDocuments({
    String? employeeId,
    String? objectId,
    String? category,
  }) async {
    final response = await _client.rpc(
      'legal_workspace_documents',
      params: <String, dynamic>{
        'p_employee_id': employeeId,
        'p_object_id': objectId,
        'p_category': category,
      },
    );
    return _workspaceList(response)
        .map((value) => LegalWorkspaceDocument.fromMap(_workspaceMap(value)))
        .where((item) => item.sourceId.isNotEmpty)
        .toList();
  }

  static Future<List<LegalWorkspaceRecovery>> fetchRecoveries() async {
    final response = await _client.rpc('legal_workspace_recoveries');
    return _workspaceList(response)
        .map((value) => LegalWorkspaceRecovery.fromMap(_workspaceMap(value)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<LegalWorkspaceSnapshot> fetchSnapshot() async {
    final result = await Future.wait<dynamic>([
      fetchEmployees(),
      fetchObjects(),
      fetchDocuments(),
      fetchRecoveries(),
    ]);
    return LegalWorkspaceSnapshot(
      employees: result[0] as List<LegalWorkspaceEmployee>,
      objects: result[1] as List<LegalWorkspaceObject>,
      documents: result[2] as List<LegalWorkspaceDocument>,
      recoveries: result[3] as List<LegalWorkspaceRecovery>,
    );
  }

  static Future<void> openStoredFile({
    required String bucketName,
    required String storagePath,
  }) async {
    if (bucketName.trim().isEmpty || storagePath.trim().isEmpty) return;
    final url = await _client.storage
        .from(bucketName)
        .createSignedUrl(storagePath, 60 * 10);
    html.window.open(url, '_blank');
  }
}
