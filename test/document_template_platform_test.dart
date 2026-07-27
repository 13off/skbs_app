import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/documents/data/document_template_repository.dart';
import 'package:skbs_app/features/documents/models/document_template.dart';

void main() {
  test('модель выбирает текущую версию и поля автозаполнения', () {
    final version = DocumentTemplateVersion.fromMap(<String, dynamic>{
      'id': 'version-2',
      'template_id': 'template-1',
      'version_no': 2,
      'file_name': 'form.docx',
      'mime_type': DocumentTemplateRepository.docxMime,
      'source_kind': 'storage',
      'storage_path': 'company/template/form.docx',
      'field_schema': <String, dynamic>{
        'content_controls': <String>['employee_name', 'position'],
      },
      'is_approved': true,
      'created_at': '2026-07-21T00:00:00Z',
    });
    final template = DocumentTemplateRecord.fromMap(<String, dynamic>{
      'id': 'template-1',
      'company_id': 'company-1',
      'code': 'employment_application',
      'title': 'Заявление на работу',
      'category': 'hr',
      'status': 'active',
      'current_version_id': 'version-2',
      'updated_at': '2026-07-21T00:00:00Z',
    }, versions: <DocumentTemplateVersion>[version]);

    expect(template.currentVersion, same(version));
    expect(version.supportsAutoFill, isTrue);
    expect(version.contentControls, <String>['employee_name', 'position']);
  });

  test('анализатор находит content-control теги в DOCX', () {
    final xmlBytes = utf8.encode(
      '<w:document><w:sdtPr><w:tag w:val="employee_name"/>'
      '</w:sdtPr><w:sdtPr><w:tag w:val="position"/></w:sdtPr>'
      '</w:document>',
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    expect(
      DocumentTemplateRepository.inspectDocxContentControls(bytes),
      <String>['employee_name', 'position'],
    );
  });

  test('каталог заменяет заглушку и сохраняет исходную форму', () {
    final screen = File(
      'lib/screens/template_documents_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/documents/data/document_template_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260721050000_versioned_document_templates.sql',
    ).readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();

    expect(screen, contains("'Шаблоны документов'"));
    expect(screen, contains("'Скачать исходник'"));
    expect(screen, contains("'Новая версия'"));
    expect(screen, contains("'Версии'"));
    expect(screen, isNot(contains('Шаблон будет добавлен позже')));
    expect(profile, contains('TemplateDocumentsScreen(profile: profile)'));

    expect(repository, contains("bucketName = 'document-templates'"));
    expect(repository, contains("extensions: <String>['docx', 'odt']"));
    expect(repository, contains('inspectDocxContentControls'));
    expect(repository, contains('createSignedUrl'));
    expect(repository, contains('version.externalUrl'));

    expect(
      migration,
      contains('create table if not exists public.document_templates'),
    );
    expect(
      migration,
      contains('create table if not exists public.document_template_versions'),
    );
    expect(migration, contains("'document-templates'"));
    expect(migration, contains('document_templates_select'));
    expect(migration, contains('document_template_versions_insert'));
    expect(migration, contains("'employment_application'"));
    expect(migration, contains("'salary_transfer_application'"));
    expect(migration, contains('Чужие формы не используются'));
    expect(migration, isNot(contains('Праймлайн')));
  });
}
