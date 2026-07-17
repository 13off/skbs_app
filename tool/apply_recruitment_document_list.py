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
    """  final Set<String> downloadingIds = <String>{};
  final Map<String, Future<String>> previewUrlFutures =
      <String, Future<String>>{};
""",
    """  final Set<String> downloadingIds = <String>{};
""",
    "remove preview cache",
)
replace_once(
    screen,
    """      setState(() {
        previewUrlFutures.clear();
        documentsFuture = documents;
""",
    """      setState(() {
        documentsFuture = documents;
""",
    "remove preview refresh",
)
regex_once(
    screen,
    r"\n  Future<String> previewUrl\(RecruitmentDocument document\) \{.*?\n  \}\n\n  String downloadName\(RecruitmentDocument document\) \{.*?\n  \}\n",
    """
  String documentFilePrefix(String documentType) {
    switch (documentType) {
      case 'passport_main':
        return 'Паспорт';
      case 'registration':
        return 'Прописка';
      case 'snils':
        return 'СНИЛС';
      case 'inn':
        return 'ИНН';
      case 'policy':
        return 'Полис';
      default:
        return 'Документ';
    }
  }

  String safeFilePart(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String documentExtension(RecruitmentDocument document) {
    final original = document.originalName.trim().toLowerCase();
    final dot = original.lastIndexOf('.');
    if (dot >= 0 && dot < original.length - 1) {
      final extension = original.substring(dot + 1);
      if (<String>{'jpg', 'jpeg', 'png', 'webp', 'pdf'}.contains(extension)) {
        return extension == 'jpeg' ? 'jpg' : extension;
      }
    }
    switch (document.mimeType) {
      case 'application/pdf':
        return 'pdf';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }

  String downloadName(RecruitmentDocument document) {
    final candidate = safeFilePart(widget.application.fullName);
    final prefix = documentFilePrefix(document.documentType);
    final suffix = candidate.isEmpty ? 'Кандидат' : candidate;
    return '${prefix}_$suffix.${documentExtension(document)}';
  }
""",
    "replace download naming",
)
regex_once(
    screen,
    r"\n  Future<void> showImagePreview\(RecruitmentDocument document\) async \{.*?\n  Widget imagePreview\(RecruitmentDocument document\) \{.*?\n  \}\n\n  Future<void> sendMessage\(\) async \{",
    """
  Future<void> sendMessage() async {""",
    "remove inline and fullscreen previews",
)
replace_once(
    screen,
    """          children: [
            if (!waiting && document.isImage) imagePreview(document),
            Padding(
""",
    """          children: [
            Padding(
""",
    "remove document image preview",
)
replace_once(
    screen,
    """                              waiting
                                  ? 'Файл обрабатывается'
                                  : <String>[
                                      if (document.originalName.isNotEmpty)
                                        document.originalName,
                                      if (formatBytes(
                                        document.sizeBytes,
                                      ).isNotEmpty)
                                        formatBytes(document.sizeBytes),
                                    ].join(' · '),
""",
    """                              waiting
                                  ? 'Файл обрабатывается'
                                  : <String>[
                                      downloadName(document),
                                      if (formatBytes(document.sizeBytes).isNotEmpty)
                                        formatBytes(document.sizeBytes),
                                    ].join(' · '),
""",
    "show generated filename",
)
regex_once(
    screen,
    r"""onPressed: waiting \|\| openingId != null
\s+\? null
\s+: document\.isImage
\s+\? \(\) => showImagePreview\(document\)
\s+: \(\) => openStoredFile\(
\s+id: document\.id,
\s+bucket: document\.storageBucket,
\s+path: document\.storagePath,
\s+\),
\s+icon: Icon\(
\s+document\.isImage
\s+\? Icons\.visibility_outlined
\s+: Icons\.open_in_new_rounded,
\s+\),
\s+label: Text\(
\s+document\.isImage \? 'Открыть' : 'Просмотр',
\s+\),""",
    """onPressed: waiting || openingId != null
                              ? null
                              : () => openStoredFile(
                                  id: document.id,
                                  bucket: document.storageBucket,
                                  path: document.storagePath,
                                ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Открыть'),""",
    "simple open button",
)

server = "supabase/functions/recruitment-documents-archive/index.ts"
replace_once(
    server,
    """function safeName(value: string, fallback: string): string {
  const clean = value
    .trim()
    .replace(/[\\/:*?\"<>|]/g, "_")
    .replace(/\s+/g, " ")
    .replace(/^\.+|\.+$/g, "")
    .slice(0, 120);
  return clean || fallback;
}
""",
    """function safeFilePart(value: string, fallback: string): string {
  const clean = value
    .trim()
    .replace(/[^0-9A-Za-zА-Яа-яЁё]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 100);
  return clean || fallback;
}

function documentFilePrefix(type: string): string {
  switch (type) {
    case "passport_main":
      return "Паспорт";
    case "registration":
      return "Прописка";
    case "snils":
      return "СНИЛС";
    case "inn":
      return "ИНН";
    case "policy":
      return "Полис";
    default:
      return "Документ";
  }
}
""",
    "server safe filename helper",
)
regex_once(
    server,
    r"""      const ext = extension\(row\);
      const preferred = row\.original_name\.trim\(\)\.length > 0
        \? row\.original_name
        : `\$\{documentTitle\(row\.document_type\)\}\.\$\{ext\}`;
      let fileName = safeName\(preferred, `document_\$\{index \+ 1\}\.\$\{ext\}`\);""",
    """      const ext = extension(row);
      const candidateName = safeFilePart(
        String(application.full_name ?? ""),
        "Кандидат",
      );
      let fileName = `${documentFilePrefix(row.document_type)}_${candidateName}.${ext}`;""",
    "server archive member naming",
)
replace_once(
    server,
    """    const fileName = safeName(
      `${application.full_name} — документы.zip`,
      "documents.zip",
    );
""",
    """    const fileName = `Документы_${safeFilePart(
      String(application.full_name ?? ""),
      "Кандидат",
    )}.zip`;
""",
    "archive filename",
)

test = "test/recruitment_documents_chat_contract_test.dart"
regex_once(
    test,
    r"  test\('document gallery previews images and downloads one or all files', \(\) \{.*?\n  \}\);",
    """  test('document list opens and downloads one or all files', () {
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
    expect(detail, isNot(contains('InteractiveViewer(')));
    expect(detail, isNot(contains('Image.network(')));
    expect(detail, contains("label: const Text('Открыть')"));
    expect(detail, contains("label: const Text('Скачать')"));
    expect(detail, contains("'Скачать все ZIP"));
    expect(detail, contains("return 'Паспорт';"));
    expect(detail, contains("return '${prefix}_$suffix"));
    expect(repository, contains('createDownloadFileUrl'));
    expect(repository, contains('createDocumentsArchiveUrl'));
    expect(server, contains('documentFilePrefix'));
    expect(server, contains('Паспорт'));
    expect(server, contains('Документы_'));
  });""",
    "update document list contract",
)
