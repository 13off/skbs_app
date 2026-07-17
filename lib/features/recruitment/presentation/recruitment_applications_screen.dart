import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_repository.dart';
import '../models/recruitment_models.dart';
import 'recruitment_archive_screen.dart';

const Color _text = Color(0xFF1F2328);
const Color _muted = Color(0xFF6B7075);
const Color _soft = Color(0xFFF1F2F4);

class RecruitmentApplicationsScreen extends StatefulWidget {
  final AppUserProfile profile;

  const RecruitmentApplicationsScreen({super.key, required this.profile});

  @override
  State<RecruitmentApplicationsScreen> createState() =>
      _RecruitmentApplicationsScreenState();
}

class _RecruitmentApplicationsScreenState
    extends State<RecruitmentApplicationsScreen> {
  final TextEditingController searchController = TextEditingController();
  late Future<List<RecruitmentApplication>> future;
  StreamSubscription<AppDataChange>? changesSubscription;
  final Set<String> archiveBusyIds = <String>{};
  String status = 'all';

  @override
  void initState() {
    super.initState();
    future = load();
    searchController.addListener(handleSearchChanged);
    changesSubscription = AppDataSync.changes.listen((change) {
      if (change.affects(AppDataDomain.recruitment) && mounted) refresh();
    });
  }

  @override
  void dispose() {
    changesSubscription?.cancel();
    searchController
      ..removeListener(handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<List<RecruitmentApplication>> load() {
    return RecruitmentRepository.fetchApplications(
      companyId: widget.profile.activeCompanyId,
    );
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  List<RecruitmentApplication> visible(
    List<RecruitmentApplication> applications,
  ) {
    final query = searchController.text.trim().toLowerCase();
    return applications.where((application) {
      if (status != 'all' && application.stage != status) return false;
      if (query.isEmpty) return true;
      final haystack = <String>[
        application.fullName,
        application.phone,
        application.vacancy,
        application.objectName,
        application.citizenship,
        application.experience,
        application.comment,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Color statusColor(String value) {
    switch (value) {
      case 'review':
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
        return const Color(0xFF4C6076);
      default:
        return _muted;
    }
  }

  String formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  Future<void> openEditor([RecruitmentApplication? application]) async {
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

  Future<void> openArchive() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RecruitmentArchiveScreen(profile: widget.profile),
      ),
    );
    if (mounted) await refresh();
  }

  Future<void> archiveApplication(RecruitmentApplication application) async {
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
    RecruitmentApplication application,
    String nextStatus,
  ) async {
    if (application.status == nextStatus) return;
    try {
      await RecruitmentRepository.updateStatus(
        companyId: widget.profile.activeCompanyId,
        applicationId: application.id,
        status: nextStatus,
      );
      if (mounted) await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить этап: $error')),
      );
    }
  }

  Widget filterChip(String value, String label) {
    final selected = status == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => status = value),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _text,
        fontWeight: FontWeight.w800,
      ),
      selectedColor: _text,
      backgroundColor: _soft,
      side: BorderSide.none,
      showCheckmark: false,
    );
  }

  Widget applicationCard(RecruitmentApplication application) {
    final accent = statusColor(application.status);
    final details = <String>[
      if (application.vacancy.isNotEmpty) application.vacancy,
      if (application.objectName.isNotEmpty) application.objectName,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openEditor(application),
        child: PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.person_search_rounded, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.fullName,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            details.join(' • '),
                            style: const TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.inventory_2_outlined),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    icon: Icons.send_outlined,
                    label: application.sourceTitle,
                  ),
                  if (application.phone.isNotEmpty)
                    _InfoPill(
                      icon: Icons.phone_outlined,
                      label: application.phone,
                    ),
                  if (application.citizenship.isNotEmpty)
                    _InfoPill(
                      icon: Icons.public_outlined,
                      label: application.citizenship,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: recruitmentStatuses.contains(application.status)
                    ? application.status
                    : 'new',
                decoration: InputDecoration(
                  labelText: 'Этап',
                  prefixIcon: Icon(Icons.flag_outlined, color: accent),
                  isDense: true,
                ),
                items: recruitmentStatuses
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(recruitmentStatusTitle(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) changeStatus(application, value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Заявки',
      subtitle: '',
      headerTrailing: Row(
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
      child: FutureBuilder<List<RecruitmentApplication>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 90),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _MessageCard(
              icon: Icons.error_outline_rounded,
              title: 'Не удалось загрузить заявки',
              text: snapshot.error.toString(),
              action: refresh,
            );
          }

          final applications =
              snapshot.data ?? const <RecruitmentApplication>[];
          final filtered = visible(applications);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'ФИО, телефон, вакансия или объект',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    filterChip('all', 'Все'),
                    const SizedBox(width: 8),
                    ...recruitmentStages.expand(
                      (item) => <Widget>[
                        filterChip(item, recruitmentStageTitle(item)),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _MessageCard(
                  icon: Icons.person_search_outlined,
                  title: applications.isEmpty
                      ? 'Заявок пока нет'
                      : 'Ничего не найдено',
                  text: applications.isEmpty
                      ? 'Добавьте кандидата вручную или дождитесь новой заявки из Telegram-бота.'
                      : 'Измените поиск или выбранный этап.',
                  action: applications.isEmpty ? openEditor : null,
                )
              else
                ...filtered.map(applicationCard),
            ],
          );
        },
      ),
    );
  }
}

class RecruitmentApplicationEditor extends StatefulWidget {
  final AppUserProfile profile;
  final RecruitmentApplication? application;

  const RecruitmentApplicationEditor({
    super.key,
    required this.profile,
    this.application,
  });

  @override
  State<RecruitmentApplicationEditor> createState() =>
      _RecruitmentApplicationEditorState();
}

class _RecruitmentApplicationEditorState
    extends State<RecruitmentApplicationEditor> {
  late final TextEditingController fullNameController;
  late final TextEditingController phoneController;
  late final TextEditingController citizenshipController;
  late final TextEditingController vacancyController;
  late final TextEditingController objectController;
  late final TextEditingController experienceController;
  late final TextEditingController commentController;
  late String status;
  DateTime? departureDate;
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final application = widget.application;
    fullNameController = TextEditingController(
      text: application?.fullName ?? '',
    );
    phoneController = TextEditingController(text: application?.phone ?? '');
    citizenshipController = TextEditingController(
      text: application?.citizenship ?? '',
    );
    vacancyController = TextEditingController(text: application?.vacancy ?? '');
    objectController = TextEditingController(
      text: application?.objectName ?? '',
    );
    experienceController = TextEditingController(
      text: application?.experience ?? '',
    );
    commentController = TextEditingController(text: application?.comment ?? '');
    status = application?.status ?? 'new';
    departureDate = application?.departureDate;
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    citizenshipController.dispose();
    vacancyController.dispose();
    objectController.dispose();
    experienceController.dispose();
    commentController.dispose();
    super.dispose();
  }

  String dateText(DateTime? value) {
    if (value == null) return 'Не указана';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> chooseDepartureDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: departureDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (selected != null && mounted) setState(() => departureDate = selected);
  }

  Future<void> save() async {
    if (saving) return;
    if (fullNameController.text.trim().length < 2 ||
        phoneController.text.trim().isEmpty ||
        vacancyController.text.trim().isEmpty ||
        objectController.text.trim().isEmpty) {
      setState(() => errorText = 'Укажите ФИО, телефон, вакансию и объект');
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      await RecruitmentRepository.saveApplication(
        id: widget.application?.id,
        companyId: widget.profile.activeCompanyId,
        fullName: fullNameController.text,
        phone: phoneController.text,
        citizenship: citizenshipController.text,
        vacancy: vacancyController.text,
        vacancyId: widget.application?.vacancyId ?? '',
        objectName: objectController.text,
        objectId: widget.application?.objectId ?? '',
        experience: experienceController.text,
        departureDate: departureDate,
        status: status,
        comment: commentController.text,
        source: widget.application?.source ?? 'manual',
        sourceUserId: widget.application?.sourceUserId ?? '',
        sourceChatId: widget.application?.sourceChatId ?? '',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => errorText = error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.application == null
                      ? 'Новый кандидат'
                      : 'Карточка кандидата',
                  style: const TextStyle(
                    color: _text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: fullNameController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'ФИО',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  enabled: !saving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: citizenshipController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Гражданство',
                    prefixIcon: Icon(Icons.public_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vacancyController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Вакансия',
                    hintText: 'Например: бетонщик-арматурщик',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: objectController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Объект',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: experienceController,
                  enabled: !saving,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Опыт',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.flight_takeoff_outlined),
                  title: const Text('Дата выезда'),
                  subtitle: Text(dateText(departureDate)),
                  trailing: departureDate == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                          tooltip: 'Очистить дату',
                          onPressed: saving
                              ? null
                              : () => setState(() => departureDate = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onTap: saving ? null : chooseDepartureDate,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: recruitmentStatuses.contains(status)
                      ? status
                      : 'new',
                  decoration: const InputDecoration(
                    labelText: 'Этап',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: recruitmentStatuses
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(recruitmentStatusTitle(item)),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) => setState(() => status = value ?? 'new'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  enabled: !saving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9A403A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Сохраняем...' : 'Сохранить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final FutureOr<void> Function()? action;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: _muted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async => action!(),
              child: const Text('Продолжить'),
            ),
          ],
        ],
      ),
    );
  }
}
