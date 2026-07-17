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
    """import '../models/recruitment_models.dart';
""",
    """import '../models/recruitment_models.dart';
import 'recruitment_archive_screen.dart';
""",
    "archive screen import",
)
replace_once(
    screen,
    """  StreamSubscription<AppDataChange>? changesSubscription;
  String status = 'all';
""",
    """  StreamSubscription<AppDataChange>? changesSubscription;
  final Set<String> archiveBusyIds = <String>{};
  String status = 'all';
""",
    "archive busy state",
)
replace_once(
    screen,
    """  Future<void> changeStatus(
""",
    """  Future<void> openArchive() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RecruitmentArchiveScreen(profile: widget.profile),
      ),
    );
    if (mounted) await refresh();
  }

  Future<void> archiveApplication(
    RecruitmentApplication application,
  ) async {
    if (archiveBusyIds.contains(application.id)) return;
    setState(() => archiveBusyIds.add(application.id));
    try {
      await RecruitmentRepository.archiveApplication(
        companyId: widget.profile.activeCompanyId,
        applicationId: application.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${application.fullName} перемещён в архив'),
          action: SnackBarAction(
            label: 'Открыть архив',
            onPressed: openArchive,
          ),
        ),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось архивировать заявку: $error')),
      );
    } finally {
      if (mounted) setState(() => archiveBusyIds.remove(application.id));
    }
  }

  Future<void> changeStatus(
""",
    "archive methods",
)
replace_once(
    screen,
    """                  Text(
                    formatDate(application.createdAt),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
""",
    """                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDate(application.createdAt),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      IconButton(
                        tooltip: 'В архив',
                        visualDensity: VisualDensity.compact,
                        onPressed: archiveBusyIds.contains(application.id)
                            ? null
                            : () => archiveApplication(application),
                        icon: archiveBusyIds.contains(application.id)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.inventory_2_outlined),
                      ),
                    ],
                  ),
""",
    "archive card action",
)
replace_once(
    screen,
    """      headerTrailing: IconButton.filledTonal(
        tooltip: 'Добавить кандидата',
        onPressed: openEditor,
        icon: const Icon(Icons.add_rounded),
      ),
""",
    """      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: 'Архив заявок',
            onPressed: openArchive,
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Добавить кандидата',
            onPressed: openEditor,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
""",
    "archive header action",
)
replace_once(
    screen,
    """                      ? 'Добавьте кандидата вручную. Следующим этапом сюда подключится Telegram-бот.'
""",
    """                      ? 'Добавьте кандидата вручную или дождитесь новой заявки из Telegram-бота.'
""",
    "archive empty text",
)

repository = "lib/features/recruitment/data/recruitment_repository.dart"
replace_once(
    repository,
    """        .eq('company_id', companyId.trim())
        .eq('id', cleanApplicationId)
        .not('archived_at', 'is', null);
""",
    """        .eq('company_id', companyId.trim())
        .eq('id', cleanApplicationId);
""",
    "database-enforced archive deletion",
)
