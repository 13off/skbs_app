import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/recruitment/models/recruitment_models.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('candidate detail exposes documents and Telegram conversation', () {
    final detail = source(
      'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart',
    );
    final applications = source(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    );

    expect(detail, contains("'Документы'"));
    expect(detail, contains("'Переписка'"));
    expect(detail, contains('Widget documentsSection()'));
    expect(detail, contains('Widget conversationSection()'));
    expect(detail, contains('sendCandidateMessage'));
    expect(detail, contains('createSignedFileUrl'));
    expect(detail, contains("label: const Text('Позвонить')"));
    expect(applications, contains('RecruitmentApplicationDetailScreen'));
  });

  test('document gallery previews images and downloads one or all files', () {
    final detail = source(
      'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart',
    );
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );
    final archiveFunction = source(
      'supabase/functions/recruitment-documents-archive/index.ts',
    );

    expect(
      detail,
      contains('Widget imagePreview(RecruitmentDocument document)'),
    );
    expect(detail, contains('InteractiveViewer('));
    expect(detail, contains("const Text('Скачать')"));
    expect(detail, contains("'Скачать все ZIP"));
    expect(repository, contains('createDownloadFileUrl'));
    expect(repository, contains('createDocumentsArchiveUrl'));
    expect(repository, contains("'recruitment-documents-archive'"));
    expect(archiveFunction, contains('import JSZip'));
    expect(archiveFunction, contains('application/zip'));
    expect(archiveFunction, contains('createSignedUrl'));
  });

  test('document and message models keep only protected storage paths', () {
    final document = RecruitmentDocument.fromMap(<String, dynamic>{
      'id': 'document-id',
      'application_id': 'application-id',
      'document_type': 'passport_main',
      'storage_bucket': 'recruitment-documents',
      'storage_path': 'company/application/passport_main/file.jpg',
      'mime_type': 'image/jpeg',
      'created_at': '2026-07-17T18:00:00Z',
    });
    final pending = RecruitmentDocument.fromMap(<String, dynamic>{
      'id': 'pending-id',
      'application_id': 'application-id',
      'document_type': 'snils',
      'storage_bucket': 'telegram-file-id-only',
      'storage_path': 'telegram://file-id',
      'created_at': '2026-07-17T18:00:00Z',
    });

    expect(document.isStored, isTrue);
    expect(document.isImage, isTrue);
    expect(document.title, 'Паспорт — разворот с фотографией');
    expect(pending.isStored, isFalse);
  });

  test('repository calls protected server actions', () {
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );
    final sync = source('lib/data/app_data_sync.dart');

    expect(repository, contains(".from('recruitment_documents')"));
    expect(repository, contains(".from('recruitment_messages')"));
    expect(repository, contains("'recruitment-candidate-action'"));
    expect(repository, contains("'action': 'send_message'"));
    expect(repository, contains("'action': 'delete_application'"));
    expect(sync, contains("case 'recruitment_messages':"));
  });
}
