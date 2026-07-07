import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import 'image_compression_service.dart';

class EmployeeDocument {
  final String name;
  final String path;
  final DateTime? updatedAt;

  const EmployeeDocument({
    required this.name,
    required this.path,
    this.updatedAt,
  });
}

class EmployeeDocumentsRepository {
  static final _client = Supabase.instance.client;
  static const bucketName = 'employee-documents';

  static String extensionFromFileName(String name) {
    final cleanName = name.trim();
    final dotIndex = cleanName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == cleanName.length - 1) {
      return '';
    }

    final extension = cleanName.substring(dotIndex + 1).toLowerCase();

    final allowedExtensions = {
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'txt',
    };

    if (!allowedExtensions.contains(extension)) return '';

    return extension;
  }

  static String safeStorageFileName({
    required String originalName,
    required int index,
    String? forcedExtension,
  }) {
    final extension =
        (forcedExtension == null || forcedExtension.trim().isEmpty)
        ? extensionFromFileName(originalName)
        : forcedExtension.trim().toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (extension.isEmpty) {
      return '${timestamp}_$index';
    }

    return '${timestamp}_$index.$extension';
  }

  static Uint8List bytesFromReaderResult(Object? result) {
    if (result is Uint8List) return result;

    if (result is ByteBuffer) {
      return Uint8List.view(result);
    }

    throw Exception('Не удалось прочитать файл');
  }

  static Future<List<EmployeeDocument>> listDocuments(String employeeId) async {
    final files = await _client.storage.from(bucketName).list(path: employeeId);

    final documents = files.map<EmployeeDocument>((file) {
      final updatedAt = DateTime.tryParse(
        file.updatedAt ?? file.createdAt ?? '',
      );

      return EmployeeDocument(
        name: file.name,
        path: '$employeeId/${file.name}',
        updatedAt: updatedAt,
      );
    }).toList();

    documents.sort((a, b) {
      final aDate = a.updatedAt ?? DateTime(1970);
      final bDate = b.updatedAt ?? DateTime(1970);

      return bDate.compareTo(aDate);
    });

    return documents;
  }

  static Future<List<EmployeeDocument>> pickAndUploadDocuments(
    String employeeId,
  ) async {
    final input = html.FileUploadInputElement()
      ..multiple = true
      ..accept = '.pdf,.doc,.docx,.xls,.xlsx,.jpg,.jpeg,.png,.webp,.txt';

    input.click();

    await input.onChange.first;

    final files = input.files;

    if (files == null || files.isEmpty) return <EmployeeDocument>[];

    final uploadedDocuments = <EmployeeDocument>[];

    for (var i = 0; i < files.length; i++) {
      final file = files[i];

      final extension = extensionFromFileName(file.name);

      if (extension.isEmpty) {
        throw Exception('Неподдерживаемый формат файла: ${file.name}');
      }

      final reader = html.FileReader();

      reader.readAsArrayBuffer(file);

      await reader.onLoad.first;

      final originalBytes = bytesFromReaderResult(reader.result);
      var uploadBytes = originalBytes;
      var uploadExtension = extension;
      String? contentType = file.type.isEmpty ? null : file.type;

      if (ImageCompressionService.isSupportedImageExtension(extension)) {
        final compressedDocument =
            await ImageCompressionService.compressHtmlImageFile(
              file: file,
              originalBytes: originalBytes,
              originalName: file.name,
              maxDimension: 1600,
              jpegQuality: 0.82,
            );

        uploadBytes = compressedDocument.bytes;
        uploadExtension = compressedDocument.extension.isEmpty
            ? extension
            : compressedDocument.extension;
        contentType = compressedDocument.contentType;
      }

      final fileName = safeStorageFileName(
        originalName: file.name,
        index: i + 1,
        forcedExtension: uploadExtension,
      );
      final path = '$employeeId/$fileName';

      await _client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            uploadBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      uploadedDocuments.add(
        EmployeeDocument(name: fileName, path: path, updatedAt: DateTime.now()),
      );
    }

    return uploadedDocuments;
  }

  static Future<void> openDocument(EmployeeDocument document) async {
    final url = await _client.storage
        .from(bucketName)
        .createSignedUrl(document.path, 60 * 10);

    html.window.open(url, '_blank');
  }
}
