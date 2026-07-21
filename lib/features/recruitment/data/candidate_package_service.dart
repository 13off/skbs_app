import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

import '../../ai/models/ai_assistant_result.dart';
import 'candidate_document_repository.dart';
import 'candidate_package_archive.dart';

class CandidatePackageService {
  CandidatePackageService._();

  static const int _webPackageBytes = 40 * 1024 * 1024;
  static const int _nativePackageBytes = 80 * 1024 * 1024;

  static int get maxPackageBytes =>
      kIsWeb ? _webPackageBytes : _nativePackageBytes;

  static int get maxPackageMegabytes => maxPackageBytes ~/ (1024 * 1024);

  static Future<CandidatePackageResult> build({
    required AiAssistantAction action,
    required String companyId,
  }) async {
    final applicationId = action.text('application_id');
    final fullName = action.text('full_name');
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty || applicationId.isEmpty || fullName.isEmpty) {
      throw StateError('Не хватает компании, кандидата или ID анкеты');
    }
    if (!action.boolean('consent_personal_data')) {
      throw StateError(
        'Пакет нельзя скачать без подтверждённого согласия кандидата '
        'на обработку персональных данных',
      );
    }

    final warnings = <String>[];
    final attachments = <CandidatePackageAttachment>[];
    var totalBytes = 0;
    final documents = await CandidateDocumentRepository.fetchForApplication(
      companyId: cleanCompanyId,
      applicationId: applicationId,
    );

    for (final document in documents) {
      final displayName = document.originalName.trim().isEmpty
          ? document.documentType
          : document.originalName;
      if (!document.canDownload) {
        warnings.add(
          'Не добавлен «$displayName»: файл ещё не перенесён в Storage.',
        );
        continue;
      }
      if (document.sizeBytes > 0 &&
          totalBytes + document.sizeBytes > maxPackageBytes) {
        warnings.add(
          'Не добавлен «$displayName»: пакет превысил бы '
          '$maxPackageMegabytes МБ.',
        );
        continue;
      }
      try {
        final bytes = await CandidateDocumentRepository.download(document);
        if (totalBytes + bytes.length > maxPackageBytes) {
          warnings.add(
            'Не добавлен «$displayName»: пакет превысил бы '
            '$maxPackageMegabytes МБ.',
          );
          continue;
        }
        attachments.add(
          CandidatePackageAttachment(
            documentType: document.documentType,
            fileName: document.originalName,
            bytes: bytes,
          ),
        );
        totalBytes += bytes.length;
      } catch (error) {
        warnings.add(
          'Не удалось добавить «$displayName»: '
          '${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }

    return CandidatePackageArchive.build(
      action: action,
      attachments: attachments,
      warnings: warnings,
      sourceBytes: totalBytes,
    );
  }

  static Future<void> download(CandidatePackageResult result) async {
    final baseName = result.fileName.replaceFirst(
      RegExp(r'\.zip$', caseSensitive: false),
      '',
    );
    await FileSaver.instance.saveFile(
      name: baseName,
      bytes: result.bytes,
      ext: 'zip',
      mimeType: MimeType.zip,
    );
  }
}