import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../../data/app_data_sync.dart';
import '../../../data/user_repository.dart';

DateTime? _docOpsDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  return raw.isEmpty ? null : DateTime.tryParse(raw)?.toLocal();
}

Map<String, dynamic> _docOpsMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : const <String, dynamic>{};

class LegalDocumentVersion {
  final String fileId;
  final String originalName;
  final String bucketName;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final int versionNo;
  final String versionLabel;
  final bool isPrimary;
  final DateTime? createdAt;

  const LegalDocumentVersion({
    required this.fileId,
    required this.originalName,
    required this.bucketName,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.versionNo,
    required this.versionLabel,
    required this.isPrimary,
    required this.createdAt,
  });

  factory LegalDocumentVersion.fromMap(Map<String, dynamic> map) {
    final file = _docOpsMap(map['app_files']);
    return LegalDocumentVersion(
      fileId: file['id']?.toString() ?? '',
      originalName: file['original_name']?.toString() ?? 'Файл',
      bucketName: file['bucket_name']?.toString() ?? '',
      storagePath: file['storage_path']?.toString() ?? '',
      mimeType: file['mime_type']?.toString() ?? '',
      sizeBytes: int.tryParse(file['size_bytes']?.toString() ?? '') ?? 0,
      versionNo: int.tryParse(map['version_no']?.toString() ?? '') ?? 1,
      versionLabel: map['version_label']?.toString() ?? '',
      isPrimary: map['is_primary'] == true,
      createdAt: _docOpsDate(map['created_at']),
    );
  }
}

class LegalDocumentEvent {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;

  const LegalDocumentEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory LegalDocumentEvent.fromMap(Map<String, dynamic> map) {
    return LegalDocumentEvent(
      id: map['id']?.toString() ?? '',
      type: map['event_type']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdAt: _docOpsDate(map['created_at']),
    );
  }
}

abstract final class LegalDocumentOperationsRepository {
  static SupabaseClient get _client => Supabase.instance.client;
  static const String bucket = 'legal-files';

  static String get _companyId =>
      UserRepository.cachedProfile?.activeCompanyId.trim() ?? '';

  static Future<List<LegalDocumentVersion>> fetchVersions(
    String documentId,
  ) async {
    final rows = await _client
        .from('legal_document_files')
        .select(
          'version_no, version_label, is_primary, created_at, app_files(id, original_name, bucket_name, storage_path, mime_type, size_bytes, created_at)',
        )
        .eq('document_id', documentId)
        .isFilter('archived_at', null)
        .order('version_no', ascending: false);
    return rows
        .map(
          (value) => LegalDocumentVersion.fromMap(
            Map<String, dynamic>.from(value),
          ),
        )
        .where((item) => item.fileId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<LegalDocumentEvent>> fetchEvents(String documentId) async {
    final rows = await _client
        .from('legal_document_events')
        .select('id, event_type, title, body, created_at')
        .eq('document_id', documentId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (value) => LegalDocumentEvent.fromMap(
            Map<String, dynamic>.from(value),
          ),
        )
        .toList(growable: false);
  }

  static Future<XFile?> pickDocumentFile() {
    return openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Документы',
          extensions: <String>[
            'pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png',
            'webp', 'txt',
          ],
        ),
      ],
    );
  }

  static Future<List<XFile>> pickDocumentFiles() {
    return openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Документы',
          extensions: <String>[
            'pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png',
            'webp', 'txt',
          ],
        ),
      ],
    );
  }

  static Future<void> uploadVersion({
    required String documentId,
    required XFile file,
    String versionLabel = '',
  }) async {
    final companyId = _companyId;
    if (companyId.isEmpty) throw StateError('Компания не выбрана');
    final bytes = await file.readAsBytes();
    final originalName = file.name.trim().isEmpty ? 'document' : file.name.trim();
    final dot = originalName.lastIndexOf('.');
    final extension = dot >= 0 ? originalName.substring(dot).toLowerCase() : '';
    final safeName = '${DateTime.now().microsecondsSinceEpoch}$extension';
    final path = '$companyId/$documentId/$safeName';

    await _client.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: file.mimeType, upsert: false),
    );
    try {
      final fileRow = await _client
          .from('app_files')
          .insert(<String, dynamic>{
            'company_id': companyId,
            'bucket_name': bucket,
            'storage_path': path,
            'original_name': originalName,
            'mime_type': file.mimeType ?? '',
            'size_bytes': bytes.length,
            'uploaded_by': _client.auth.currentUser?.id,
          })
          .select('id')
          .single();
      final fileId = fileRow['id']?.toString() ?? '';
      await _client.from('legal_document_files').insert(<String, dynamic>{
        'company_id': companyId,
        'document_id': documentId,
        'file_id': fileId,
        'is_primary': true,
        'version_label': versionLabel.trim(),
      });
      AppDataSync.notifyLocal(
        const <AppDataDomain>{AppDataDomain.legal},
        context: <String, dynamic>{
          'table': 'legal_document_files',
          'entity_id': documentId,
        },
      );
    } catch (_) {
      await _client.storage.from(bucket).remove(<String>[path]);
      rethrow;
    }
  }

  static Future<void> openVersion(LegalDocumentVersion version) async {
    if (version.bucketName.isEmpty || version.storagePath.isEmpty) return;
    final url = await _client.storage
        .from(version.bucketName)
        .createSignedUrl(version.storagePath, 60 * 10);
    html.window.open(url, '_blank');
  }

  static Future<void> setStatus({
    required String documentId,
    required String status,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      'updated_by': _client.auth.currentUser?.id,
    };
    if (status == 'signed') {
      payload['signed_on'] = DateTime.now().toIso8601String().split('T').first;
    }
    if (status == 'expired' || status == 'archive') {
      payload['next_action'] = '';
      payload['next_action_due_at'] = null;
    }
    if (status == 'archive') payload['archived_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from('legal_documents').update(payload).eq('id', documentId);
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.legal},
      context: <String, dynamic>{'table': 'legal_documents', 'entity_id': documentId},
    );
  }
}
