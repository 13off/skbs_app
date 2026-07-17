from pathlib import Path
import re


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found: {label} in {path}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def regex_once(path: str, pattern: str, replacement: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"Regex count {count}: {label} in {path}")
    file.write_text(updated, encoding="utf-8")


screen = "lib/features/recruitment/presentation/recruitment_application_detail_screen.dart"
replace_once(
    screen,
    "import 'dart:async';\n",
    "import 'dart:async';\nimport 'dart:typed_data';\n",
    "typed data import",
)
replace_once(
    screen,
    "import 'package:flutter/material.dart';\n",
    "import 'package:archive/archive.dart';\nimport 'package:file_saver/file_saver.dart';\nimport 'package:flutter/material.dart';\n",
    "zip imports",
)
regex_once(
    screen,
    r"  Future<void> downloadAllDocuments\(\) async \{.*?\n  \}\n\n  Future<void> sendMessage\(\) async \{",
    """  Future<void> downloadAllDocuments(
    List<RecruitmentDocument> documents,
  ) async {
    if (downloadingArchive) return;
    final stored = documents.where((item) => item.isStored).toList();
    if (stored.isEmpty) {
      showError('У кандидата пока нет загруженных документов');
      return;
    }

    setState(() => downloadingArchive = true);
    try {
      final archive = Archive();
      for (final document in stored) {
        final bytes = await RecruitmentRepository.downloadStoredFile(
          bucket: document.storageBucket,
          path: document.storagePath,
        );
        archive.addFile(
          ArchiveFile(downloadName(document), bytes.length, bytes),
        );
      }

      final encoded = ZipEncoder().encode(archive);
      if (encoded == null || encoded.isEmpty) {
        throw Exception('Не удалось собрать ZIP');
      }
      final candidate = safeFilePart(widget.application.fullName);
      final suffix = candidate.isEmpty ? 'Кандидат' : candidate;
      await FileSaver.instance.saveFile(
        name: 'Документы_$suffix',
        bytes: Uint8List.fromList(encoded),
        ext: 'zip',
        mimeType: MimeType.zip,
      );
    } catch (error) {
      showError('Не удалось скачать архив: $error');
    } finally {
      if (mounted) setState(() => downloadingArchive = false);
    }
  }

  Future<void> sendMessage() async {""",
    "local zip method",
)
replace_once(
    screen,
    "onPressed: downloadingArchive ? null : downloadAllDocuments,",
    "onPressed: downloadingArchive\n                      ? null\n                      : () => downloadAllDocuments(documents),",
    "local zip button",
)

repository = "lib/features/recruitment/data/recruitment_repository.dart"
replace_once(
    repository,
    "import 'package:supabase_flutter/supabase_flutter.dart';\n",
    "import 'dart:typed_data';\n\nimport 'package:supabase_flutter/supabase_flutter.dart';\n",
    "repository typed data import",
)
regex_once(
    repository,
    r"  static Future<String> createDocumentsArchiveUrl\(\{.*?\n  \}\n\n  static Future<void> sendCandidateMessage",
    """  static Future<Uint8List> downloadStoredFile({
    required String bucket,
    required String path,
  }) async {
    final cleanBucket = bucket.trim();
    final cleanPath = path.trim();
    if (cleanBucket.isEmpty ||
        cleanPath.isEmpty ||
        cleanPath.startsWith('telegram://')) {
      throw Exception('Файл ещё не загружен в защищённое хранилище');
    }
    return _client.storage.from(cleanBucket).download(cleanPath);
  }

  static Future<void> sendCandidateMessage""",
    "repository protected download",
)

test = "test/recruitment_documents_chat_contract_test.dart"
replace_once(
    test,
    """    expect(repository, contains('createDownloadFileUrl'));
    expect(repository, contains('createDocumentsArchiveUrl'));
    expect(server, contains('documentFilePrefix'));
""",
    """    expect(repository, contains('createDownloadFileUrl'));
    expect(repository, contains('downloadStoredFile'));
    expect(detail, contains('ArchiveFile(downloadName(document)'));
    expect(detail, contains('ZipEncoder().encode(archive)'));
    expect(detail, contains('FileSaver.instance.saveFile'));
    expect(server, contains('documentFilePrefix'));
""",
    "local zip contract",
)
