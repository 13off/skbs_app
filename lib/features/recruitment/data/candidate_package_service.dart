import 'package:universal_html/html.dart' as html;

import '../../ai/models/ai_assistant_result.dart';
import 'candidate_document_repository.dart';
import 'candidate_package_archive.dart';

class CandidatePackageService {
  CandidatePackageService._();

  static const int maxPackageBytes = 80 * 1024 * 1024;

  static Future<CandidatePackageResult> build({
    required AiAssistantAction action,
    required String companyId,
  }) async {
    final applicationId = action.text('application_id');
    final fullName = action.text('full_name');
    if (applicationId.isEmpty || fullName.isEmpty) {
      throw StateError('Не хватает кандидата или ID анкеты');
    }

    final warnings = <String>[];
    final attachments = <CandidatePackageAttachment>[];
    var totalBytes = 0;
    final documents = await CandidateDocumentRepository.fetchForApplication(
      companyId: companyId,
      applicationId: applicationId,
    );

    for (final document in documents) {
      if (!document.canDownload) {
        warnings.add(
          'Не добавлен «${document.originalName}»: файл ещё не перенесён в Storage.',
        );
        continue;
      }
      try {
        final bytes = await CandidateDocumentRepository.download(document);
        if (totalBytes + bytes.length > maxPackageBytes) {
          warnings.add(
            'Не добавлен «${document.originalName}»: пакет превысил бы 80 МБ.',
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
          'Не удалось добавить «${document.originalName}»: '
          '${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }

    return CandidatePackageArchive.build(
      action: action,
      attachments: attachments,
      warnings: warnings,
    );
  }

  static void download(CandidatePackageResult result) {
    final blob = html.Blob(<Object>[result.bytes], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      html.AnchorElement(href: url)
        ..download = result.fileName
        ..click();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}
