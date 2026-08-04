from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta
import json
from pathlib import Path
import re
import shutil
import subprocess
from urllib.parse import unquote, urlparse


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def fix_edge_functions() -> None:
    candidate = Path("supabase/functions/recruitment-candidate-action/index.ts")
    text = candidate.read_text(encoding="utf-8")
    text = text.replace(
        'import { createClient } from "npm:@supabase/supabase-js@2.110.5";',
        'import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.110.5";',
        1,
    )
    marker = "type JsonMap = Record<string, unknown>;\n"
    types = """type JsonMap = Record<string, unknown>;

type AdminClient = SupabaseClient<any>;

type StoredFileRow = {
  storage_bucket: string | null;
  storage_path: string | null;
};
"""
    if "type AdminClient = SupabaseClient<any>;" not in text:
        if marker not in text:
            raise RuntimeError("candidate-action JsonMap marker missing")
        text = text.replace(marker, types, 1)
    text = text.replace(
        "admin: ReturnType<typeof createClient>,",
        "admin: AdminClient,",
    )
    old_loop = """  const grouped = new Map<string, Set<string>>();
  for (const row of [...(documents ?? []), ...(messages ?? [])]) {
"""
    new_loop = """  const grouped = new Map<string, Set<string>>();
  const storedFiles: StoredFileRow[] = [
    ...((documents ?? []) as StoredFileRow[]),
    ...((messages ?? []) as StoredFileRow[]),
  ];
  for (const row of storedFiles) {
"""
    if old_loop in text:
        text = text.replace(old_loop, new_loop, 1)
    elif new_loop not in text:
        raise RuntimeError("candidate-action stored-file loop missing")
    candidate.write_text(text, encoding="utf-8")

    ingest = Path("supabase/functions/recruitment-ingest-telegram-file/index.ts")
    text = ingest.read_text(encoding="utf-8")
    row_type = """type JsonMap = Record<string, unknown>;

type TelegramFileRow = {
  id: string;
  company_id: string;
  application_id: string;
  telegram_file_id: string | null;
  storage_bucket: string | null;
  storage_path: string | null;
  original_name: string | null;
  mime_type: string | null;
  size_bytes: number | null;
  document_type?: string | null;
};
"""
    if "type TelegramFileRow = {" not in text:
        if marker not in text:
            raise RuntimeError("telegram-ingest JsonMap marker missing")
        text = text.replace(marker, row_type, 1)
    guard = '    if (!data) return json({ error: "row not found" }, 404);\n'
    typed_guard = guard + "    const row = data as unknown as TelegramFileRow;\n"
    if "const row = data as unknown as TelegramFileRow;" not in text:
        if guard not in text:
            raise RuntimeError("telegram-ingest data guard missing")
        text = text.replace(guard, typed_guard, 1)
    head, separator, tail = text.partition(
        "    const row = data as unknown as TelegramFileRow;\n"
    )
    if not separator:
        raise RuntimeError("telegram-ingest typed row missing")
    ingest.write_text(head + separator + tail.replace("data.", "row."), encoding="utf-8")


def normalize_migrations() -> None:
    migration_dir = Path("supabase/migrations")
    groups: dict[str, list[Path]] = defaultdict(list)
    used: set[str] = set()
    for path in sorted(migration_dir.glob("*.sql")):
        match = re.match(r"^(\d{14})_(.+)$", path.name)
        if not match:
            continue
        groups[match.group(1)].append(path)
        used.add(match.group(1))

    renames: list[tuple[str, str]] = []
    for version, paths in sorted(groups.items()):
        if len(paths) < 2:
            continue
        current = datetime.strptime(version, "%Y%m%d%H%M%S")
        for path in sorted(paths)[1:]:
            while True:
                current += timedelta(seconds=1)
                candidate_version = current.strftime("%Y%m%d%H%M%S")
                if candidate_version not in used:
                    break
            used.add(candidate_version)
            target = path.with_name(candidate_version + path.name[14:])
            path.rename(target)
            renames.append((path.name, target.name))

    report = Path("docs/full-acceptance-test-runs/2026-08-04-migration-renames.md")
    lines = [
        "# Нормализация версий SQL-миграций",
        "",
        "Повторяющиеся версии заменены ближайшими свободными секундами.",
        "Содержимое SQL не изменялось.",
        "",
        "Перед production deploy нужно сверить `supabase_migrations.schema_migrations`",
        "и при необходимости выполнить штатный `supabase migration repair`.",
        "",
        "## Переименования",
        "",
        *[f"- `{old}` → `{new}`" for old, new in renames],
    ]
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")


def update_file_saver_calls() -> None:
    pubspec = Path("pubspec.yaml")
    text = pubspec.read_text(encoding="utf-8")
    text = text.replace("file_saver: ^0.2.14", "file_saver: ^0.4.0")
    pubspec.write_text(text, encoding="utf-8")

    saver_files = [
        "lib/features/ai/presentation/ai_exact_document_screen.dart",
        "lib/features/recruitment/data/candidate_onboarding_package_service.dart",
        "lib/features/recruitment/data/candidate_package_service.dart",
        "lib/features/recruitment/presentation/recruitment_application_detail_screen.dart",
        "lib/features/recruitment/presentation/recruitment_import_screen.dart",
    ]
    changed = 0
    for name in saver_files:
        path = Path(name)
        source = path.read_text(encoding="utf-8")
        updated, count = re.subn(r"(?m)^(\s*)ext:", r"\1fileExtension:", source)
        path.write_text(updated, encoding="utf-8")
        changed += count
    if changed != 6:
        raise RuntimeError(f"Expected 6 file_saver ext arguments, changed {changed}")


def locate_package_root(root_uri: str) -> Path:
    uri = urlparse(root_uri)
    if uri.scheme != "file":
        raise RuntimeError(f"Unexpected package URI: {root_uri}")
    source = Path(unquote(uri.path)).resolve()
    while source != source.parent and not (source / "pubspec.yaml").is_file():
        source = source.parent
    if not (source / "pubspec.yaml").is_file():
        raise RuntimeError(f"Could not locate package root from {root_uri}")
    pubspec = (source / "pubspec.yaml").read_text(encoding="utf-8")
    if not re.search(r"(?m)^name:\s*file_saver\s*$", pubspec):
        raise RuntimeError(f"Located package is not file_saver: {source}")
    return source


def vendor_file_saver() -> None:
    run("flutter", "pub", "get")
    config = json.loads(
        Path(".dart_tool/package_config.json").read_text(encoding="utf-8")
    )
    package = next(item for item in config["packages"] if item["name"] == "file_saver")
    source = locate_package_root(package["rootUri"])
    target = Path("third_party/file_saver")
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(
        source,
        target,
        ignore=shutil.ignore_patterns(
            ".dart_tool", "build", ".git", "example", "test", "pubspec.lock"
        ),
    )

    matches = list(target.rglob("file_saver_web.dart"))
    if len(matches) != 1:
        raise RuntimeError(
            f"Expected one file_saver_web.dart, found {len(matches)}: {matches}"
        )
    web_file = matches[0]
    text = web_file.read_text(encoding="utf-8")
    text = text.replace("web.Url.", "web.URL.")
    text = text.replace(".revokeObjectUrl(", ".revokeObjectURL(")
    text = text.replace(".createObjectUrlFromBlob(", ".createObjectURL(")
    legacy_tokens = ("web.Url.", "revokeObjectUrl", "createObjectUrlFromBlob")
    if any(token in text for token in legacy_tokens):
        raise RuntimeError("Legacy package:web URL calls remain after patch")
    if "URL.createObjectURL(" not in text or "URL.revokeObjectURL(" not in text:
        relevant = "\n".join(
            line for line in text.splitlines() if "Object" in line or "URL" in line
        )
        raise RuntimeError("Modern URL calls were not confirmed:\n" + relevant)
    web_file.write_text(text, encoding="utf-8")

    if not (target / "LICENSE").is_file():
        raise RuntimeError("Vendored package license is missing")
    (target / "APPSTROY_PATCH.md").write_text(
        "# AppСтрой compatibility patch\n\n"
        "Vendored from `file_saver` 0.4.0 under its BSD-3-Clause license.\n\n"
        "The Web implementation uses the current `package:web` "
        "`URL.createObjectURL` and `URL.revokeObjectURL` APIs. "
        "No plugin business behavior was changed.\n",
        encoding="utf-8",
    )

    pubspec = Path("pubspec.yaml")
    text = pubspec.read_text(encoding="utf-8")
    text, count = re.subn(
        r"(?m)^  file_saver: \^0\.4\.0$",
        "  file_saver:\n    path: third_party/file_saver",
        text,
    )
    if count != 1:
        raise RuntimeError(f"Expected one file_saver dependency, changed {count}")
    pubspec.write_text(text, encoding="utf-8")
    run("flutter", "pub", "get")


def main() -> None:
    fix_edge_functions()
    normalize_migrations()
    update_file_saver_calls()
    vendor_file_saver()


if __name__ == "__main__":
    main()
