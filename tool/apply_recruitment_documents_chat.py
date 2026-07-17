from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found: {label} in {path}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


screen = "lib/features/recruitment/presentation/recruitment_applications_screen.dart"
replace_once(
    screen,
    "import 'recruitment_archive_screen.dart';\n",
    "import 'recruitment_application_detail_screen.dart';\nimport 'recruitment_archive_screen.dart';\n",
    "detail import",
)
replace_once(
    screen,
    """  Future<void> openEditor([RecruitmentApplication? application]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecruitmentApplicationEditor(
        profile: widget.profile,
        application: application,
      ),
    );
    if (saved == true && mounted) await refresh();
  }
""",
    """  Future<void> openEditor([RecruitmentApplication? application]) async {
    if (application != null) {
      final action = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => RecruitmentApplicationDetailScreen(
            profile: widget.profile,
            application: application,
          ),
        ),
      );
      if (!mounted) return;
      if (action != 'edit') {
        await refresh();
        return;
      }
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecruitmentApplicationEditor(
        profile: widget.profile,
        application: application,
      ),
    );
    if (saved == true && mounted) await refresh();
  }
""",
    "open candidate detail",
)

sync = "lib/data/app_data_sync.dart"
replace_once(
    sync,
    """      case 'recruitment_documents':
      case 'recruitment_status_history':""",
    """      case 'recruitment_documents':
      case 'recruitment_messages':
      case 'recruitment_status_history':""",
    "recruitment messages realtime",
)

pubspec = "pubspec.yaml"
replace_once(
    pubspec,
    "  firebase_messaging: ^16.4.1\n",
    "  firebase_messaging: ^16.4.1\n  url_launcher: ^6.3.2\n",
    "url launcher dependency",
)
