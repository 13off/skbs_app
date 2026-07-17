from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found: {label} in {path}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


pubspec = "pubspec.yaml"
replace_once(
    pubspec,
    "  archive: ^3.6.1\n",
    "  archive: ^3.6.1\n  pdf: ^3.13.0\n",
    "pdf dependency",
)

screen = "lib/features/recruitment/presentation/recruitment_application_detail_screen.dart"
replace_once(
    screen,
    """import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
""",
    """import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
""",
    "pdf imports",
)
replace_once(
    screen,
    """  String downloadName(RecruitmentDocument document) {
    final candidate = safeFilePart(widget.application.fullName);
    final prefix = documentFilePrefix(document.documentType);
    final suffix = candidate.isEmpty ? 'Кандидат' : candidate;
    return '${prefix}_$suffix.${documentExtension(document)}';
  }
""",
    """  String downloadName(RecruitmentDocument document) {
    final candidate = safeFilePart(widget.application.fullName);
    final prefix = documentFilePrefix(document.documentType);
    final suffix = candidate.isEmpty ? 'Кандидат' : candidate;
    return '${prefix}_$suffix.${documentExtension(document)}';
  }

  int documentOrder(String documentType) {
    switch (documentType) {
      case 'passport_main':
        return 0;
      case 'registration':
        return 1;
      case 'snils':
        return 2;
      case 'inn':
        return 3;
      case 'policy':
        return 4;
      default:
        return 100;
    }
  }
""",
    "document ordering",
)
replace_once(
    screen,
    """  Future<void> downloadAllDocuments(List<RecruitmentDocument> documents) async {
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
""",
    """  Future<void> downloadAllDocuments(List<RecruitmentDocument> documents) async {
    if (downloadingArchive) return;
    final stored = documents.where((item) => item.isStored).toList()
      ..sort((first, second) {
        final order = documentOrder(
          first.documentType,
        ).compareTo(documentOrder(second.documentType));
        if (order != 0) return order;
        return first.createdAt.compareTo(second.createdAt);
      });
    if (stored.isEmpty) {
      showError('У кандидата пока нет загруженных документов');
      return;
    }

    setState(() => downloadingArchive = true);
    try {
      final archive = Archive();
      final pdfImages = <Uint8List>[];
      for (final document in stored) {
        final bytes = await RecruitmentRepository.downloadStoredFile(
          bucket: document.storageBucket,
          path: document.storagePath,
        );
        archive.addFile(
          ArchiveFile(downloadName(document), bytes.length, bytes),
        );
        if (document.isImage) pdfImages.add(bytes);
      }

      final candidate = safeFilePart(widget.application.fullName);
      final suffix = candidate.isEmpty ? 'Кандидат' : candidate;
      if (pdfImages.isNotEmpty) {
        final pdf = pw.Document(
          title: 'Документы ${widget.application.fullName}',
          author: 'AppСтрой',
        );
        for (final bytes in pdfImages) {
          final image = pw.MemoryImage(bytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(24),
              build: (_) => pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          );
        }
        final pdfBytes = await pdf.save();
        archive.addFile(
          ArchiveFile(
            'Документы_$suffix.pdf',
            pdfBytes.length,
            pdfBytes,
          ),
        );
      }

      final encoded = ZipEncoder().encode(archive);
      if (encoded == null || encoded.isEmpty) {
        throw Exception('Не удалось собрать ZIP');
      }
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
""",
    "combined PDF in ZIP",
)

test = "test/recruitment_documents_chat_contract_test.dart"
replace_once(
    test,
    """    expect(detail, contains('ArchiveFile(downloadName(document)'));
    expect(detail, contains('ZipEncoder().encode(archive)'));
    expect(detail, contains('FileSaver.instance.saveFile'));
""",
    """    expect(detail, contains('ArchiveFile(downloadName(document)'));
    expect(detail, contains('pw.Document('));
    expect(detail, contains('pw.MemoryImage(bytes)'));
    expect(detail, contains('PdfPageFormat.a4'));
    expect(detail, contains("'Документы_$suffix.pdf'"));
    expect(detail, contains('ZipEncoder().encode(archive)'));
    expect(detail, contains('FileSaver.instance.saveFile'));
""",
    "combined PDF contract",
)
