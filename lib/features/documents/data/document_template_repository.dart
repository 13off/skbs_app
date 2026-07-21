import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../models/document_template.dart';

class DocumentTemplateRepository {
  DocumentTemplateRepository._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String bucketName = 'document-templates';
  static const String docxMime =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  static const String odtMime = 'application/vnd.oasis.opendocument.text';

  static Future<List<DocumentTemplateRecord>> fetchTemplates({
    required String companyId,
  }) async {
    final templateRows = await _client
        .from('document_templates')
        .select(
          'id, company_id, code, title, category, description, status, '
          'current_version_id, updated_at',
        )
        .order('category')
        .order('title');

    final rawTemplates = templateRows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final templateIds = rawTemplates
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final versionsByTemplate = <String, List<DocumentTemplateVersion>>{};

    if (templateIds.isNotEmpty) {
      final versionRows = await _client
          .from('document_template_versions')
          .select(
            'id, template_id, company_id, version_no, file_name, mime_type, '
            'source_kind, asset_path, storage_path, field_schema, notes, '
            'is_approved, created_at',
          )
          .inFilter('template_id', templateIds)
          .order('version_no', ascending: false);
      for (final raw in versionRows.whereType<Map>()) {
        final version = DocumentTemplateVersion.fromMap(
          Map<String, dynamic>.from(raw),
        );
        versionsByTemplate
            .putIfAbsent(version.templateId, () => <DocumentTemplateVersion>[])
            .add(version);
      }
    }

    final parsed = rawTemplates.map((row) {
      final id = row['id']?.toString() ?? '';
      return DocumentTemplateRecord.fromMap(
        row,
        versions: versionsByTemplate[id] ?? const <DocumentTemplateVersion>[],
      );
    }).toList(growable: false);

    final byCode = <String, DocumentTemplateRecord>{};
    for (final template in parsed) {
      final existing = byCode[template.code];
      if (existing == null || (!template.isGlobal && existing.isGlobal)) {
        byCode[template.code] = template;
      }
    }
    final result = byCode.values.toList()
      ..sort((first, second) {
        final categoryCompare = first.category.compareTo(second.category);
        if (categoryCompare != 0) return categoryCompare;
        return first.title.compareTo(second.title);
      });
    return result;
  }

  static Future<void> downloadVersion(DocumentTemplateVersion version) async {
    if (version.isAsset) {
      final data = await rootBundle.load(version.assetPath);
      _downloadBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        fileName: version.fileName,
        mimeType: version.mimeType,
      );
      return;
    }
    if (version.storagePath.isEmpty) {
      throw StateError('У версии отсутствует файл');
    }
    final url = await _client.storage
        .from(bucketName)
        .createSignedUrl(version.storagePath, 60 * 10);
    html.window.open(url, '_blank');
  }

  static Future<DocumentTemplateRecord?> uploadNewVersion({
    required DocumentTemplateRecord template,
    required String companyId,
    required bool approve,
    String notes = '',
  }) async {
    const typeGroup = XTypeGroup(
      label: 'Шаблоны документов',
      extensions: <String>['docx', 'odt'],
    );
    final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[typeGroup]);
    if (file == null) return null;

    final extension = _extension(file.name);
    if (extension != 'docx' && extension != 'odt') {
      throw StateError('Поддерживаются только DOCX и ODT');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('Выбранный файл пустой');
    if (bytes.length > 15 * 1024 * 1024) {
      throw StateError('Максимальный размер шаблона — 15 МБ');
    }

    var workingTemplate = template;
    if (template.isGlobal) {
      final inserted = await _client
          .from('document_templates')
          .insert(<String, dynamic>{
            'company_id': companyId,
            'code': template.code,
            'title': template.title,
            'category': template.category,
            'description': template.description,
            'status': 'review',
          })
          .select(
            'id, company_id, code, title, category, description, status, '
            'current_version_id, updated_at',
          )
          .single();
      workingTemplate = DocumentTemplateRecord.fromMap(
        inserted,
        versions: const <DocumentTemplateVersion>[],
      );
    }

    final nextVersion = workingTemplate.versions.isEmpty
        ? 1
        : workingTemplate.versions
                  .map((version) => version.versionNo)
                  .reduce((first, second) => first > second ? first : second) +
              1;
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final safeName = _safeFileName(file.name, fallbackExtension: extension);
    final storagePath =
        '$companyId/${workingTemplate.id}/${timestamp}_$safeName';
    final mimeType = extension == 'odt' ? odtMime : docxMime;
    final controls = extension == 'docx'
        ? inspectDocxContentControls(bytes)
        : const <String>[];

    await _client.storage.from(bucketName).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            cacheControl: '3600',
            upsert: false,
          ),
        );

    try {
      final versionRow = await _client
          .from('document_template_versions')
          .insert(<String, dynamic>{
            'template_id': workingTemplate.id,
            'company_id': companyId,
            'version_no': nextVersion,
            'file_name': file.name,
            'mime_type': mimeType,
            'source_kind': 'storage',
            'storage_path': storagePath,
            'field_schema': <String, dynamic>{
              'content_controls': controls,
            },
            'notes': notes.trim(),
            'is_approved': approve,
          })
          .select(
            'id, template_id, company_id, version_no, file_name, mime_type, '
            'source_kind, asset_path, storage_path, field_schema, notes, '
            'is_approved, created_at',
          )
          .single();
      final version = DocumentTemplateVersion.fromMap(versionRow);

      await _client.from('document_templates').update(<String, dynamic>{
        'current_version_id': version.id,
        'status': approve ? 'active' : 'review',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', workingTemplate.id);
    } catch (_) {
      await _client.storage.from(bucketName).remove(<String>[storagePath]);
      rethrow;
    }

    final refreshed = await fetchTemplates(companyId: companyId);
    for (final item in refreshed) {
      if (item.code == template.code) return item;
    }
    return null;
  }

  static Future<void> setCurrentVersion({
    required DocumentTemplateRecord template,
    required DocumentTemplateVersion version,
    required bool approve,
  }) async {
    if (template.isGlobal) {
      throw StateError('Встроенный шаблон нельзя изменить');
    }
    if (version.templateId != template.id) {
      throw StateError('Версия не относится к выбранному шаблону');
    }
    await _client.from('document_template_versions').update(<String, dynamic>{
      'is_approved': approve,
    }).eq('id', version.id);
    await _client.from('document_templates').update(<String, dynamic>{
      'current_version_id': version.id,
      'status': approve ? 'active' : 'review',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', template.id);
  }

  static List<String> inspectDocxContentControls(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final controls = <String>{};
      final tagPattern = RegExp(
        r'<w:tag\b[^>]*\bw:val="([^"]+)"[^>]*/?>',
        caseSensitive: false,
      );
      for (final file in archive.files) {
        final name = file.name.toLowerCase();
        if (!name.startsWith('word/') || !name.endsWith('.xml')) continue;
        final content = file.content;
        if (content is! List<int>) continue;
        final xml = utf8.decode(content, allowMalformed: true);
        for (final match in tagPattern.allMatches(xml)) {
          final value = match.group(1)?.trim() ?? '';
          if (value.isNotEmpty) controls.add(value);
        }
      }
      final result = controls.toList()..sort();
      return result;
    } catch (_) {
      return const <String>[];
    }
  }

  static void _downloadBytes(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) {
    final blob = html.Blob(<Object>[bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      html.AnchorElement(href: url)
        ..download = fileName
        ..click();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  static String _extension(String name) {
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) return '';
    return name.substring(index + 1).toLowerCase();
  }

  static String _safeFileName(
    String name, {
    required String fallbackExtension,
  }) {
    final normalized = name
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (normalized.isEmpty || normalized == '.$fallbackExtension') {
      return 'template.$fallbackExtension';
    }
    return normalized;
  }
}
