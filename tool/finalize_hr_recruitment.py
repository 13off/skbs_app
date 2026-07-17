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
    "if (status != 'all' && application.status != status) return false;",
    "if (status != 'all' && application.stage != status) return false;",
    "filter by simple stage",
)
replace_once(
    screen,
    """      case 'problems':
      case 'rejected':
        return const Color(0xFF9A403A);
      case 'ready':
      case 'completed':
        return const Color(0xFF2E7D52);
      case 'tickets':
        return const Color(0xFF9A6816);
      case 'documents':
        return const Color(0xFF4C6076);""",
    """      case 'review':
      case 'rejected':
        return const Color(0xFF9A403A);
      case 'approved':
      case 'arrived':
      case 'hired':
        return const Color(0xFF2E7D52);
      case 'ticket_request':
      case 'in_transit':
        return const Color(0xFF9A6816);
      case 'waiting_documents':
      case 'medical':
        return const Color(0xFF4C6076);""",
    "status colors",
)
replace_once(
    screen,
    """                    ...recruitmentStatuses.expand(
                      (item) => <Widget>[
                        filterChip(item, recruitmentStatusTitle(item)),""",
    """                    ...recruitmentStages.expand(
                      (item) => <Widget>[
                        filterChip(item, recruitmentStageTitle(item)),""",
    "simple stage chips",
)
replace_once(
    screen,
    """    if (fullNameController.text.trim().length < 2 ||
        vacancyController.text.trim().isEmpty) {
      setState(() => errorText = 'Укажите ФИО и вакансию');""",
    """    if (fullNameController.text.trim().length < 2 ||
        phoneController.text.trim().isEmpty ||
        vacancyController.text.trim().isEmpty ||
        objectController.text.trim().isEmpty) {
      setState(() => errorText = 'Укажите ФИО, телефон, вакансию и объект');""",
    "manual validation",
)
replace_once(
    screen,
    """        vacancy: vacancyController.text,
        objectName: objectController.text,""",
    """        vacancy: vacancyController.text,
        vacancyId: widget.application?.vacancyId ?? '',
        objectName: objectController.text,
        objectId: widget.application?.objectId ?? '',""",
    "preserve object and vacancy ids",
)

sync = "lib/data/app_data_sync.dart"
replace_once(
    sync,
    """      case 'recruitment_applications':
        return const <AppDataDomain>{AppDataDomain.recruitment};""",
    """      case 'recruitment_applications':
      case 'recruitment_documents':
      case 'recruitment_status_history':
      case 'recruitment_vacancies':
        return const <AppDataDomain>{AppDataDomain.recruitment};""",
    "all recruitment realtime tables",
)
