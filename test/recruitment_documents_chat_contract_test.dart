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

  test('document list opens and downloads one or all files', () {
    final detail = source(
      'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart',
    );
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );
    final server = source(
      'supabase/functions/recruitment-documents-archive/index.ts',
    );

    expect(detail, isNot(contains('Widget imagePreview(')));
    expect(detail, isNot(contains('Image.network(')));
    expect(detail, contains('class _RecruitmentImageViewer'));
    expect(detail, contains('InteractiveViewer('));
    expect(detail, contains('Image.memory('));
    expect(detail, contains('downloadStoredFile'));
    expect(detail, contains("label: const Text('Открыть')"));
    expect(detail, contains("label: const Text('Скачать')"));
    expect(detail, contains("'Скачать все ZIP"));
    expect(detail, contains("return 'Паспорт';"));
    expect(detail, contains(r"return '${prefix}_$suffix"));
    expect(repository, contains('createDownloadFileUrl'));
    expect(repository, contains('downloadStoredFile'));
    expect(detail, contains('ArchiveFile(downloadName(document)'));
    expect(detail, contains('pw.Document('));
    expect(detail, contains('pw.MemoryImage(bytes)'));
    expect(detail, contains('PdfPageFormat.a4'));
    expect(detail, contains(r"'Документы_$suffix.pdf'"));
    expect(detail, contains('ZipEncoder().encode(archive)'));
    expect(detail, contains('FileSaver.instance.saveFile'));
    expect(server, contains('documentFilePrefix'));
    expect(server, contains('Паспорт'));
    expect(server, contains('Документы_'));
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
    expect(
      repository,
      contains("'activate_recruitment_telegram_conversation'"),
    );
    expect(repository, contains("'p_application_id': cleanApplicationId"));
    expect(repository, contains("'action': 'delete_application'"));
    final candidateAction = source(
      'supabase/functions/recruitment-candidate-action/index.ts',
    );
    expect(candidateAction, contains('.from("recruitment_bot_sessions")'));
    expect(candidateAction, contains('application_id: application.id'));
    expect(candidateAction, contains('step: "submitted"'));
    expect(sync, contains("case 'recruitment_messages':"));
  });
}
