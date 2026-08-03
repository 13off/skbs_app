import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/document_template.dart';
import 'document_template_repository.dart';

class DocumentTemplateEditableBlock {
  final String id;
  final String partPath;
  final int paragraphIndex;
  final String sectionTitle;
  final String text;
  final bool isProtected;
  final String protectionReason;

  const DocumentTemplateEditableBlock({
    required this.id,
    required this.partPath,
    required this.paragraphIndex,
    required this.sectionTitle,
    required this.text,
    required this.isProtected,
    required this.protectionReason,
  });
}

class DocumentTemplateOnlineDraft {
  final Uint8List sourceBytes;
  final List<DocumentTemplateEditableBlock> blocks;

  const DocumentTemplateOnlineDraft({
    required this.sourceBytes,
    required this.blocks,
  });

  int get editableCount => blocks.where((block) => !block.isProtected).length;
  int get protectedCount => blocks.where((block) => block.isProtected).length;
}

abstract final class DocumentTemplateOnlineEditor {
  static final SupabaseClient _client = Supabase.instance.client;

  static final RegExp _paragraphPattern = RegExp(
    r'<w:p\b[^>]*>[\s\S]*?</w:p>',
    caseSensitive: false,
  );
  static final RegExp _textPattern = RegExp(
    r'(<w:t\b[^>]*>)([\s\S]*?)(</w:t>)',
    caseSensitive: false,
  );
  static final RegExp _placeholderPattern = RegExp(
    r'(\{\{[^}]+\}\}|\[\[[^\]]+\]\]|\$\{[^}]+\}|<<[^>]+>>)',
  );

  static Future<DocumentTemplateOnlineDraft> load(
    DocumentTemplateVersion version,
  ) async {
    if (!_isDocx(version)) {
      throw StateError('Онлайн-редактор поддерживает только DOCX');
    }
    final bytes = await _loadVersionBytes(version);
    return open(bytes, protectedTags: version.contentControls);
  }

  static Future<DocumentTemplateRecord?> saveVersion({
    required DocumentTemplateRecord template,
    required DocumentTemplateVersion sourceVersion,
    required String companyId,
    required DocumentTemplateOnlineDraft draft,
    required Map<String, String> values,
    required bool approve,
    required String notes,
  }) async {
    final changedCount = draft.blocks.where((block) {
      if (block.isProtected) return false;
      return (values[block.id]?.trim() ?? block.text) != block.text;
    }).length;
    if (changedCount == 0) {
      throw StateError('Изменений нет');
    }

    final bytes = save(draft, values);
    final workingTemplateId = await _companyTemplateId(
      template: template,
      companyId: companyId,
    );
    final versionRows = await _client
        .from('document_template_versions')
        .select('version_no')
        .eq('template_id', workingTemplateId)
        .order('version_no', ascending: false)
        .limit(1);
    final nextVersion = versionRows.isEmpty
        ? 1
        : (int.tryParse(versionRows.first['version_no'].toString()) ?? 0) + 1;
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final fileName = _editedFileName(sourceVersion.fileName, nextVersion);
    final storagePath = '$companyId/$workingTemplateId/${timestamp}_$fileName';
    final controls = DocumentTemplateRepository.inspectDocxContentControls(bytes);
    final fieldSchema = <String, dynamic>{
      ...sourceVersion.fieldSchema,
      'content_controls': controls,
      'online_editor': <String, dynamic>{
        'engine': 'docx_text_blocks_v1',
        'source_version_id': sourceVersion.id,
        'changed_blocks': changedCount,
        'protected_blocks': draft.protectedCount,
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      },
    };

    await _client.storage
        .from(DocumentTemplateRepository.bucketName)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: DocumentTemplateRepository.docxMime,
            cacheControl: '3600',
            upsert: false,
          ),
        );

    try {
      final versionRow = await _client
          .from('document_template_versions')
          .insert(<String, dynamic>{
            'template_id': workingTemplateId,
            'company_id': companyId,
            'version_no': nextVersion,
            'file_name': fileName,
            'mime_type': DocumentTemplateRepository.docxMime,
            'source_kind': 'storage',
            'storage_path': storagePath,
            'field_schema': fieldSchema,
            'notes': notes.trim().isEmpty
                ? 'Изменено в онлайн-редакторе AppСтрой'
                : notes.trim(),
            'is_approved': approve,
          })
          .select('id')
          .single();
      await _client
          .from('document_templates')
          .update(<String, dynamic>{
            'current_version_id': versionRow['id'],
            'status': approve ? 'active' : 'review',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', workingTemplateId);
    } catch (_) {
      await _client.storage
          .from(DocumentTemplateRepository.bucketName)
          .remove(<String>[storagePath]);
      rethrow;
    }

    final refreshed = await DocumentTemplateRepository.fetchTemplates(
      companyId: companyId,
    );
    for (final item in refreshed) {
      if (item.code == template.code) return item;
    }
    return null;
  }

  static DocumentTemplateOnlineDraft open(
    Uint8List bytes, {
    List<String> protectedTags = const <String>[],
  }) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final blocks = <DocumentTemplateEditableBlock>[];
    final normalizedTags = protectedTags
        .map(_normalize)
        .where((value) => value.isNotEmpty)
        .toSet();

    for (final file in archive.files) {
      final path = file.name.toLowerCase();
      if (!_isEditablePart(path)) continue;
      final content = file.content;
      if (content is! List<int>) continue;
      final xml = utf8.decode(content, allowMalformed: true);
      final paragraphs = _paragraphPattern.allMatches(xml).toList();
      for (var index = 0; index < paragraphs.length; index++) {
        final paragraph = paragraphs[index].group(0) ?? '';
        final text = _paragraphText(paragraph).trim();
        if (text.isEmpty) continue;
        final reason = _protectionReason(paragraph, text, normalizedTags);
        blocks.add(
          DocumentTemplateEditableBlock(
            id: '${file.name}#$index',
            partPath: file.name,
            paragraphIndex: index,
            sectionTitle: _sectionTitle(file.name),
            text: text,
            isProtected: reason.isNotEmpty,
            protectionReason: reason,
          ),
        );
      }
    }

    if (blocks.isEmpty) {
      throw StateError(
        'В DOCX не найден текст, который можно показать в онлайн-редакторе',
      );
    }
    return DocumentTemplateOnlineDraft(sourceBytes: bytes, blocks: blocks);
  }

  static Uint8List save(
    DocumentTemplateOnlineDraft draft,
    Map<String, String> values,
  ) {
    final archive = ZipDecoder().decodeBytes(draft.sourceBytes, verify: true);
    final blocksByPart = <String, Map<int, DocumentTemplateEditableBlock>>{};
    for (final block in draft.blocks) {
      if (block.isProtected) continue;
      blocksByPart
          .putIfAbsent(block.partPath, () => <int, DocumentTemplateEditableBlock>{})
          [block.paragraphIndex] = block;
    }

    for (final file in archive.files) {
      final partBlocks = blocksByPart[file.name];
      if (partBlocks == null || partBlocks.isEmpty) continue;
      final content = file.content;
      if (content is! List<int>) continue;
      var xml = utf8.decode(content, allowMalformed: true);
      final paragraphs = _paragraphPattern.allMatches(xml).toList();
      final indexes = partBlocks.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final paragraphIndex in indexes) {
        if (paragraphIndex < 0 || paragraphIndex >= paragraphs.length) continue;
        final block = partBlocks[paragraphIndex]!;
        final nextText = values[block.id]?.trim() ?? block.text;
        if (nextText == block.text) continue;
        final match = paragraphs[paragraphIndex];
        final paragraph = match.group(0) ?? '';
        final updated = _replaceParagraphText(paragraph, nextText);
        xml = xml.replaceRange(match.start, match.end, updated);
      }
      final encoded = Uint8List.fromList(utf8.encode(xml));
      file.content = encoded;
      file.size = encoded.length;
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Не удалось собрать новую DOCX-версию');
    }
    return Uint8List.fromList(encoded);
  }

  static Future<Uint8List> _loadVersionBytes(
    DocumentTemplateVersion version,
  ) async {
    if (version.isAsset) {
      if (version.assetPath.trim().isEmpty) {
        throw StateError('У версии отсутствует встроенный DOCX-файл');
      }
      final data = await rootBundle.load(version.assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    if (version.isStorage) {
      if (version.storagePath.trim().isEmpty) {
        throw StateError('У версии отсутствует файл в хранилище');
      }
      return _client.storage
          .from(DocumentTemplateRepository.bucketName)
          .download(version.storagePath);
    }
    throw StateError(
      'Этот исходник подключён внешней ссылкой. Сначала нажмите «Новая версия» '
      'и загрузите DOCX в AppСтрой — после этого его можно редактировать онлайн.',
    );
  }

  static Future<String> _companyTemplateId({
    required DocumentTemplateRecord template,
    required String companyId,
  }) async {
    if (!template.isGlobal) return template.id;
    final existing = await _client
        .from('document_templates')
        .select('id')
        .eq('company_id', companyId)
        .eq('code', template.code)
        .maybeSingle();
    if (existing != null) return existing['id'].toString();
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
        .select('id')
        .single();
    return inserted['id'].toString();
  }

  static bool _isDocx(DocumentTemplateVersion version) {
    return version.mimeType == DocumentTemplateRepository.docxMime ||
        version.fileName.toLowerCase().endsWith('.docx');
  }

  static String _editedFileName(String sourceName, int versionNo) {
    final dot = sourceName.toLowerCase().lastIndexOf('.docx');
    final base = (dot > 0 ? sourceName.substring(0, dot) : sourceName)
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Zа-яА-Я0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return '${base.isEmpty ? 'template' : base}_online_v$versionNo.docx';
  }

  static bool _isEditablePart(String path) {
    if (!path.startsWith('word/') || !path.endsWith('.xml')) return false;
    return path == 'word/document.xml' ||
        path.startsWith('word/header') ||
        path.startsWith('word/footer');
  }

  static String _sectionTitle(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('/header')) return 'Верхний колонтитул';
    if (lower.contains('/footer')) return 'Нижний колонтитул';
    return 'Текст документа';
  }

  static String _paragraphText(String paragraph) {
    return _textPattern
        .allMatches(paragraph)
        .map((match) => _decodeXml(match.group(2) ?? ''))
        .join();
  }

  static String _protectionReason(
    String paragraph,
    String text,
    Set<String> protectedTags,
  ) {
    final lower = paragraph.toLowerCase();
    if (lower.contains('<w:sdt') || lower.contains('<w:tag')) {
      return 'Системное поле автозаполнения защищено';
    }
    if (lower.contains('<w:fldchar') || lower.contains('<w:instrtext')) {
      return 'Служебное поле Word защищено';
    }
    if (_placeholderPattern.hasMatch(text)) {
      return 'Маркер автозаполнения защищён';
    }
    final normalizedText = _normalize(text);
    if (protectedTags.any(
      (tag) => tag.length >= 3 && normalizedText.contains(tag),
    )) {
      return 'Системное поле AppСтрой защищено';
    }
    return '';
  }

  static String _replaceParagraphText(String paragraph, String value) {
    var index = 0;
    return paragraph.replaceAllMapped(_textPattern, (match) {
      var opening = match.group(1) ?? '<w:t>';
      final closing = match.group(3) ?? '</w:t>';
      final replacement = index == 0 ? _encodeXml(value) : '';
      if (index == 0 &&
          (value.startsWith(' ') || value.endsWith(' ')) &&
          !opening.contains('xml:space=')) {
        opening = opening.replaceFirst('>', ' xml:space="preserve">');
      }
      index++;
      return '$opening$replacement$closing';
    });
  }

  static String _decodeXml(String value) {
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }

  static String _encodeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}