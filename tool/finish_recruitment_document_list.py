from pathlib import Path
import re


def regex_once(path: str, pattern: str, replacement: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"Regex count {count}: {label} in {path}")
    file.write_text(updated, encoding="utf-8")


server = "supabase/functions/recruitment-documents-archive/index.ts"
regex_once(
    server,
    r"function safeName\(value: string, fallback: string\): string \{.*?\n\}\n",
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
    "replace server filename helper",
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
    "archive member names",
)
regex_once(
    server,
    r"""    const fileName = safeName\(
      `\$\{application\.full_name\} — документы\.zip`,
      "documents\.zip",
    \);""",
    """    const fileName = `Документы_${safeFilePart(
      String(application.full_name ?? ""),
      "Кандидат",
    )}.zip`;""",
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
