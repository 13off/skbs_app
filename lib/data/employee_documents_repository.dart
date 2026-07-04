import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

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
  }) {
    final extension = extensionFromFileName(originalName);
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

  static Future<void> pickAndUploadDocuments(String employeeId) async {
    final input = html.FileUploadInputElement()
      ..multiple = true
      ..accept = '.pdf,.doc,.docx,.xls,.xlsx,.jpg,.jpeg,.png,.webp,.txt';

    input.click();

    await input.onChange.first;

    final files = input.files;

    if (files == null || files.isEmpty) return;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];

      final extension = extensionFromFileName(file.name);

      if (extension.isEmpty) {
        throw Exception('Неподдерживаемый формат файла: ${file.name}');
      }

      final reader = html.FileReader();

      reader.readAsArrayBuffer(file);

      await reader.onLoad.first;

      final bytes = bytesFromReaderResult(reader.result);
      final fileName = safeStorageFileName(
        originalName: file.name,
        index: i + 1,
      );
      final path = '$employeeId/$fileName';

      await _client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: file.type.isEmpty ? null : file.type,
              upsert: false,
            ),
          );
    }
  }

  static Future<void> openDocument(EmployeeDocument document) async {
    final url = await _client.storage
        .from(bucketName)
        .createSignedUrl(document.path, 60 * 10);

    html.window.open(url, '_blank');
  }
}
