import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _dossierMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : const <String, dynamic>{};

List<dynamic> _dossierList(dynamic value) =>
    value is List ? value : const <dynamic>[];

DateTime? _dossierDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

class LegalEmployeeDossier {
  final Map<String, dynamic> values;

  const LegalEmployeeDossier(this.values);

  String text(String key) => values[key]?.toString().trim() ?? '';

  bool? boolean(String key) {
    final value = values[key];
    if (value is bool) return value;
    if (value == null) return null;
    final raw = value.toString().toLowerCase();
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    return null;
  }

  double? number(String key) => double.tryParse(text(key));

  DateTime? dateTime(String key) => _dossierDate(values[key]);

  String get employeeId => text('employee_id');
  String get fio => text('fio');
  String get position => text('position');
  String get phone => text('phone');
  String get objectId => text('object_id');
  String get objectName => text('object_name');
  bool get isActive => boolean('is_active') ?? false;
  DateTime? get archivedAt => dateTime('archived_at');
  bool get isArchived => archivedAt != null;
}

class LegalEmployeeDossierDocument {
  final String sourceType;
  final String sourceId;
  final String title;
  final String group;
  final String documentType;
  final String status;
  final String documentNumber;
  final String fileName;
  final String bucketName;
  final String storagePath;
  final DateTime? documentDate;
  final DateTime? validFrom;
  final DateTime? expiresOn;
  final String legalDocumentId;
  final String sourceLabel;

  const LegalEmployeeDossierDocument({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.group,
    required this.documentType,
    required this.status,
    required this.documentNumber,
    required this.fileName,
    required this.bucketName,
    required this.storagePath,
    required this.documentDate,
    required this.validFrom,
    required this.expiresOn,
    required this.legalDocumentId,
    required this.sourceLabel,
  });

  factory LegalEmployeeDossierDocument.fromMap(Map<String, dynamic> map) {
    return LegalEmployeeDossierDocument(
      sourceType: map['source_type']?.toString() ?? '',
      sourceId: map['source_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Документ',
      group: map['document_group']?.toString() ?? 'other',
      documentType: map['document_type']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      documentNumber: map['document_number']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? '',
      bucketName: map['bucket_name']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      documentDate: _dossierDate(map['document_date']),
      validFrom: _dossierDate(map['valid_from']),
      expiresOn: _dossierDate(map['expires_on']),
      legalDocumentId: map['legal_document_id']?.toString() ?? '',
      sourceLabel: map['source_label']?.toString() ?? '',
    );
  }

  bool get hasStoredFile => bucketName.isNotEmpty && storagePath.isNotEmpty;
  bool get isExpired => expiresOn != null && expiresOn!.isBefore(DateTime.now());
}

abstract final class LegalEmployeeDossierRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<LegalEmployeeDossier> fetchDossier(String employeeId) async {
    final response = await _client.rpc(
      'legal_employee_dossier',
      params: <String, dynamic>{'p_employee_id': employeeId},
    );
    final map = _dossierMap(response);
    if (map.isEmpty) throw StateError('Досье сотрудника не найдено');
    return LegalEmployeeDossier(map);
  }

  static Future<List<LegalEmployeeDossierDocument>> fetchDocuments(
    String employeeId,
  ) async {
    final response = await _client.rpc(
      'legal_employee_dossier_documents',
      params: <String, dynamic>{'p_employee_id': employeeId},
    );
    return _dossierList(response)
        .map(
          (value) => LegalEmployeeDossierDocument.fromMap(
            _dossierMap(value),
          ),
        )
        .where((item) => item.sourceId.isNotEmpty)
        .toList(growable: false);
  }
}
