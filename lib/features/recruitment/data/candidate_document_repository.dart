import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class CandidateDocumentFile {
  final String id;
  final String documentType;
  final String bucket;
  final String storagePath;
  final String originalName;
  final String mimeType;
  final int sizeBytes;

  const CandidateDocumentFile({
    required this.id,
    required this.documentType,
    required this.bucket,
    required this.storagePath,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory CandidateDocumentFile.fromMap(Map<String, dynamic> map) {
    return CandidateDocumentFile(
      id: map['id']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? '',
      bucket: map['storage_bucket']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      originalName: map['original_name']?.toString() ?? '',
      mimeType: map['mime_type']?.toString() ?? '',
      sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  bool get canDownload => bucket.trim().isNotEmpty && storagePath.trim().isNotEmpty;
}

class CandidateDocumentRepository {
  CandidateDocumentRepository._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const int maxSingleFileBytes = 25 * 1024 * 1024;

  static Future<List<CandidateDocumentFile>> fetchForApplication({
    required String companyId,
    required String applicationId,
  }) async {
    final cleanCompanyId = companyId.trim();
    final cleanApplicationId = applicationId.trim();
    if (cleanCompanyId.isEmpty || cleanApplicationId.isEmpty) {
      return const <CandidateDocumentFile>[];
    }

    final rows = await _client
        .from('recruitment_documents')
        .select(
          'id, document_type, storage_bucket, storage_path, original_name, '
          'mime_type, size_bytes',
        )
        .eq('company_id', cleanCompanyId)
        .eq('application_id', cleanApplicationId)
        .eq('is_test_copy', false)
        .order('created_at', ascending: true);

    return rows
        .whereType<Map>()
        .map((row) => CandidateDocumentFile.fromMap(
              Map<String, dynamic>.from(row),
            ))
        .toList(growable: false);
  }

  static Future<Uint8List> download(CandidateDocumentFile file) async {
    if (!file.canDownload) {
      throw StateError('Для файла «${file.originalName}» нет пути в хранилище');
    }
    if (file.sizeBytes > maxSingleFileBytes) {
      throw StateError(
        'Файл «${file.originalName}» больше 25 МБ и не добавлен в пакет',
      );
    }

    return _client.storage.from(file.bucket).download(file.storagePath);
  }
}
