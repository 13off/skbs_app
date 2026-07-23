import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_ui_tokens.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_repository.dart';
import '../models/recruitment_models.dart';
import 'recruitment_application_detail_screen.dart';
import 'recruitment_archive_screen.dart';
import 'recruitment_crm_settings_screen.dart';

Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _soft => AppAdaptivePalette.surfaceSoft;

enum RecruitmentViewMode { board, list }

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
  late Future<RecruitmentWorkspaceData> future;
  StreamSubscription<AppDataChange>? changesSubscription;
  final Set<String> archiveBusyIds = <String>{};
  final Set<String> movingIds = <String>{};
  RecruitmentViewMode viewMode = RecruitmentViewMode.board;
  String listStage = 'all';
  String objectFilter = 'all';
  String vacancyFilter = 'all';

  bool get canConfigureCrm => const <String>{
        'owner',
        'admin',
        'developer',
        'hr',
      }.contains(widget.profile.actualRole);

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

  Future<RecruitmentWorkspaceData> load() {
    return RecruitmentRepository.fetchWorkspace(
      companyId: widget.profile.activeCompanyId,
    );
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  List<String> filterValues(
    List<RecruitmentApplication> applications,
    String Function(RecruitmentApplication application) selector,
  ) {
    return applications
        .map(selector)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort(
        (first, second) =>
            first.toLowerCase().compareTo(second.toLowerCase()),
      );
  }

  List<RecruitmentApplication> visible(
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration, {
    bool applyListStage = false,
  }) {
    final query = searchController.text.trim().toLowerCase();
    final result = applications.where((application) {
      final stage = configuration.stageForApplication(application);
      if (applyListStage &&
          listStage != 'all' &&
          stage?.id != listStage) {
        return false;
      }
      if (objectFilter != 'all' && application.objectName != objectFilter) {
        return false;
      }
      if (vacancyFilter != 'all' && application.vacancy != vacancyFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = <String>[
        application.fullName,
        application.phone,
        application.vacancy,
        application.objectName,
        application.citizenship,
        application.experience,
        application.comment,
        application.statusTitle,
        stage?.title ?? '',
        configuration.customSearchText(application),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    result.sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    return result;
  }

  Color stageColor(RecruitmentPipelineStage stage) {
    final clean = stage.colorHex.replaceFirst('#', '');
    final parsed = int.tryParse(clean, radix: 16) ?? 0x2F80ED;
    return Color(0xFF000000 | parsed);
  }

  String formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  String shortDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
  }

  Future<void> openEditor(
    RecruitmentCrmConfiguration configuration, [
    RecruitmentApplication? application,
  ]) async {
    if (application != null) {
      final action = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => RecruitmentApplicationDetailScreen(
            profile: widget.profile,
            application: application,
            configuration: configuration,
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
        configuration: configuration,
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

  Future<void> openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RecruitmentCrmSettingsScreen(profile: widget.profile),
      ),
    );
    if (mounted) {
      setState(() => listStage = 'all');
      await refresh();
    }
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
          action: SnackBarAction(label: 'Открыть архив', onPressed: openArchive),
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

  Future<void> moveToStage(
    RecruitmentApplication application,
    RecruitmentPipelineStage stage,
  ) async {
    if (application.stageId == stage.id ||
        movingIds.contains(application.id)) {
      return;
    }
    setState(() => movingIds.add(application.id));
    try {
      await RecruitmentRepository.moveApplicationStage(
        applicationId: application.id,
        stageId: stage.id,
      );
      if (mounted) await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить этап: $error')),
      );
    } finally {
      if (mounted) setState(() => movingIds.remove(application.id));
    }
  }

  Widget filterChip(String value, String label) {
    final selected = listStage == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => listStage = value),
      labelStyle: TextStyle(
        color: selected ? AppAdaptivePalette.onAccent : _text,
        fontWeight: FontWeight.w800,
      ),
      selectedColor: AppAdaptivePalette.accentStrong,
      backgroundColor: _soft,
      side: BorderSide.none,
      showCheckmark: false,
    );
  }

  Widget metricCard({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 178,
      child: PremiumWorkCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppUi.controlRadius),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppUi.gap12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      color: _text,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppUi.gap4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget summary(
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration,
  ) {
    int countWhere(bool Function(RecruitmentPipelineStage stage) predicate) {
      return applications.where((application) {
        final stage = configuration.stageForApplication(application);
        return stage != null && predicate(stage);
      }).length;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          metricCard(
            label: 'Всего кандидатов',
            value: applications.length,
            icon: Icons.groups_2_outlined,
            color: AppAdaptivePalette.accent,
          ),
          const SizedBox(width: AppUi.gap12),
          metricCard(
            label: 'В активной работе',
            value: countWhere((stage) => !stage.isFinal),
            icon: Icons.work_history_outlined,
            color: const Color(0xFF4C6076),
          ),
          const SizedBox(width: AppUi.gap12),
          metricCard(
            label: 'На финальных этапах',
            value: countWhere((stage) => stage.isFinal),
            icon: Icons.flag_outlined,
            color: AppAdaptivePalette.success,
          ),
          const SizedBox(width: AppUi.gap12),
          metricCard(
            label: 'Колонок в воронке',
            value: configuration.stages.length,
            icon: Icons.view_column_outlined,
            color: AppAdaptivePalette.warning,
          ),
        ],
      ),
    );
  }

  Widget dropdownFilter({
    required String value,
    required String label,
    required IconData icon,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: values.contains(value) ? value : 'all',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          isDense: true,
        ),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(value: 'all', child: Text('Все')),
          ...values.map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget toolbar(
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration,
  ) {
    final objects = filterValues(applications, (item) => item.objectName);
    final vacancies = filterValues(applications, (item) => item.vacancy);

    return PremiumWorkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final search = TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'ФИО, телефон, вакансия, объект или любое поле',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить поиск',
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              );
              final controls = Wrap(
                spacing: AppUi.gap12,
                runSpacing: AppUi.gap12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  dropdownFilter(
                    value: objectFilter,
                    label: 'Объект',
                    icon: Icons.apartment_outlined,
                    values: objects,
                    onChanged: (value) =>
                        setState(() => objectFilter = value ?? 'all'),
                  ),
                  dropdownFilter(
                    value: vacancyFilter,
                    label: 'Вакансия',
                    icon: Icons.work_outline_rounded,
                    values: vacancies,
                    onChanged: (value) =>
                        setState(() => vacancyFilter = value ?? 'all'),
                  ),
                  SegmentedButton<RecruitmentViewMode>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<RecruitmentViewMode>>[
                      ButtonSegment<RecruitmentViewMode>(
                        value: RecruitmentViewMode.board,
                        icon: Icon(Icons.view_kanban_outlined),
                        label: Text('Канбан'),
                      ),
                      ButtonSegment<RecruitmentViewMode>(
                        value: RecruitmentViewMode.list,
                        icon: Icon(Icons.view_list_outlined),
                        label: Text('Список'),
                      ),
                    ],
                    selected: <RecruitmentViewMode>{viewMode},
                    onSelectionChanged: (selection) {
                      setState(() => viewMode = selection.first);
                    },
                  ),
                ],
              );

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: AppUi.gap12),
                    controls,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: search),
                  const SizedBox(width: AppUi.gap12),
                  Flexible(flex: 2, child: controls),
                ],
              );
            },
          ),
          if (viewMode == RecruitmentViewMode.list) ...[
            const SizedBox(height: AppUi.gap12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  filterChip('all', 'Все этапы'),
                  const SizedBox(width: AppUi.gap8),
                  ...configuration.stages.expand(
                    (stage) => <Widget>[
                      filterChip(stage.id, stage.title),
                      const SizedBox(width: AppUi.gap8),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> candidateMenu(
    RecruitmentApplication application,
    RecruitmentCrmConfiguration configuration,
  ) {
    final currentStage = configuration.stageForApplication(application);
    return <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(
        enabled: false,
        child: Text(
          'Переместить в колонку',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      ...configuration.stages.map(
        (stage) => PopupMenuItem<String>(
          value: 'stage:${stage.id}',
          enabled: currentStage?.id != stage.id,
          child: Row(
            children: [
              Icon(Icons.circle, size: 10, color: stageColor(stage)),
              const SizedBox(width: AppUi.gap8),
              Expanded(child: Text(stage.title)),
            ],
          ),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'archive',
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined),
            SizedBox(width: AppUi.gap8),
            Text('В архив'),
          ],
        ),
      ),
    ];
  }

  Future<void> handleCandidateMenu(
    RecruitmentApplication application,
    RecruitmentCrmConfiguration configuration,
    String value,
  ) async {
    if (value == 'archive') {
      await archiveApplication(application);
      return;
    }
    if (value.startsWith('stage:')) {
      final id = value.substring('stage:'.length);
      final stage = configuration.stageById(id);
      if (stage != null) await moveToStage(application, stage);
    }
  }

  Widget candidateCard(
    RecruitmentApplication application,
    RecruitmentCrmConfiguration configuration, {
    bool feedback = false,
  }) {
    final stage = configuration.stageForApplication(application);
    final color = stage == null ? AppAdaptivePalette.accent : stageColor(stage);
    final busy = movingIds.contains(application.id) ||
        archiveBusyIds.contains(application.id);
    final details = <String>[
      if (application.vacancy.isNotEmpty) application.vacancy,
      if (application.objectName.isNotEmpty) application.objectName,
    ];
    final visibleFields = configuration.fields
        .where((field) => field.showOnCard)
        .map(
          (field) => MapEntry(
            field,
            field.formatValue(application.customValue(field.id)),
          ),
        )
        .where((entry) => entry.value.isNotEmpty)
        .take(4)
        .toList();

    final card = PremiumWorkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppUi.controlRadius),
                ),
                child: Icon(Icons.person_search_rounded, color: color, size: 20),
              ),
              const SizedBox(width: AppUi.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: 15,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: AppUi.gap4),
                      Text(
                        details.join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!feedback)
                PopupMenuButton<String>(
                  tooltip: 'Действия',
                  enabled: !busy,
                  itemBuilder: (_) => candidateMenu(application, configuration),
                  onSelected: (value) =>
                      handleCandidateMenu(application, configuration, value),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_horiz_rounded),
                ),
            ],
          ),
          const SizedBox(height: AppUi.gap12),
          Wrap(
            spacing: AppUi.gap8,
            runSpacing: AppUi.gap8,
            children: [
              _InfoPill(
                icon: Icons.flag_outlined,
                label: stage?.title ?? application.statusTitle,
              ),
              _InfoPill(icon: Icons.send_outlined, label: application.sourceTitle),
              if (application.phone.isNotEmpty)
                _InfoPill(icon: Icons.phone_outlined, label: application.phone),
              if (application.departureDate != null)
                _InfoPill(
                  icon: Icons.flight_takeoff_outlined,
                  label: 'Выезд ${shortDate(application.departureDate)}',
                ),
            ],
          ),
          if (visibleFields.isNotEmpty) ...[
            const SizedBox(height: AppUi.gap12),
            ...visibleFields.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppUi.gap4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${entry.key.title}: ',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: entry.value,
                        style: TextStyle(
                          color: _text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          if (application.comment.trim().isNotEmpty) ...[
            const SizedBox(height: AppUi.gap12),
            Text(
              application.comment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _muted,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppUi.gap12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: _muted),
              const SizedBox(width: AppUi.gap4),
              Expanded(
                child: Text(
                  'Обновлено ${formatDate(application.updatedAt)}',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!feedback) ...[
                Icon(Icons.drag_indicator_rounded, size: 18, color: _muted),
                const SizedBox(width: AppUi.gap4),
                Text(
                  kIsWeb ? 'Перетащи' : 'Удерживай',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (feedback) return card;
    final interactiveCard = PremiumPressable(
      onTap: busy ? null : () => openEditor(configuration, application),
      borderRadius: BorderRadius.circular(AppUi.cardRadius),
      child: card,
    );
    final feedbackCard = Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 292,
        child: candidateCard(application, configuration, feedback: true),
      ),
    );

    if (kIsWeb) {
      return Draggable<RecruitmentApplication>(
        data: application,
        maxSimultaneousDrags: busy ? 0 : 1,
        feedback: feedbackCard,
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: interactiveCard,
      );
    }
    return LongPressDraggable<RecruitmentApplication>(
      data: application,
      maxSimultaneousDrags: busy ? 0 : 1,
      feedback: feedbackCard,
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: interactiveCard,
    );
  }

  Widget kanbanColumn(
    RecruitmentPipelineStage stage,
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration,
  ) {
    final color = stageColor(stage);
    return DragTarget<RecruitmentApplication>(
      onWillAcceptWithDetails: (details) =>
          !movingIds.contains(details.data.id) &&
          details.data.stageId != stage.id,
      onAcceptWithDetails: (details) => moveToStage(details.data, stage),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 310,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: highlighted
                ? color.withValues(alpha: 0.10)
                : AppAdaptivePalette.surfaceSoft.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(AppUi.cardRadius),
            border: Border.all(
              color: highlighted
                  ? color.withValues(alpha: 0.50)
                  : AppAdaptivePalette.border,
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppUi.gap8),
                  Expanded(
                    child: Text(
                      stage.title,
                      style: TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${applications.length}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              if (stage.description.isNotEmpty) ...[
                const SizedBox(height: AppUi.gap4),
                Text(
                  stage.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppUi.gap12),
              if (applications.isEmpty)
                Container(
                  height: 118,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.surfaceElevated
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppUi.controlRadius),
                    border: Border.all(
                      color: highlighted
                          ? color.withValues(alpha: 0.40)
                          : AppAdaptivePalette.border,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      highlighted ? 'Отпусти кандидата здесь' : 'Нет кандидатов',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: highlighted ? color : _muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              else
                ...applications.expand(
                  (application) => <Widget>[
                    candidateCard(application, configuration),
                    const SizedBox(height: AppUi.gap12),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget board(
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: AppUi.gap8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: configuration.stages.expand((stage) {
          final items = applications.where((application) {
            return configuration.stageForApplication(application)?.id == stage.id;
          }).toList();
          return <Widget>[
            kanbanColumn(stage, items, configuration),
            const SizedBox(width: AppUi.gap12),
          ];
        }).toList(),
      ),
    );
  }

  Widget list(
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration,
  ) {
    if (applications.isEmpty) {
      return const _MessageCard(
        icon: Icons.person_search_outlined,
        title: 'Ничего не найдено',
        text: 'Измените поиск, фильтр объекта, вакансии или этапа.',
      );
    }
    return Column(
      children: applications.expand(
        (application) => <Widget>[
          candidateCard(application, configuration),
          const SizedBox(height: AppUi.gap12),
        ],
      ).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Кандидаты',
      subtitle: 'Настраиваемая CRM, документы и отправка на объект',
      onRefresh: refresh,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canConfigureCrm) ...[
            IconButton.filledTonal(
              tooltip: 'Настроить CRM',
              onPressed: openSettings,
              icon: const Icon(Icons.settings_suggest_outlined),
            ),
            const SizedBox(width: AppUi.gap8),
          ],
          IconButton.filledTonal(
            tooltip: 'Архив кандидатов',
            onPressed: openArchive,
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          const SizedBox(width: AppUi.gap8),
          FutureBuilder<RecruitmentWorkspaceData>(
            future: future,
            builder: (context, snapshot) => IconButton.filled(
              tooltip: 'Добавить кандидата',
              onPressed: snapshot.hasData
                  ? () => openEditor(snapshot.data!.configuration)
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
      child: FutureBuilder<RecruitmentWorkspaceData>(
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
              title: 'Не удалось загрузить кандидатов',
              text: snapshot.error.toString(),
              action: refresh,
            );
          }

          final workspace = snapshot.data ??
              const RecruitmentWorkspaceData(
                applications: <RecruitmentApplication>[],
                configuration: RecruitmentCrmConfiguration.empty,
              );
          final applications = workspace.applications;
          final configuration = workspace.configuration;
          if (configuration.stages.isEmpty) {
            return _MessageCard(
              icon: Icons.view_column_outlined,
              title: 'В CRM нет активных колонок',
              text: 'Откройте настройки и добавьте колонку воронки.',
              action: canConfigureCrm ? openSettings : null,
            );
          }
          if (applications.isEmpty) {
            return _MessageCard(
              icon: Icons.person_add_alt_1_outlined,
              title: 'Кандидатов пока нет',
              text:
                  'Добавьте кандидата вручную или дождитесь новой заявки из Telegram-бота.',
              action: () => openEditor(configuration),
            );
          }

          final filtered = visible(
            applications,
            configuration,
            applyListStage: viewMode == RecruitmentViewMode.list,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary(applications, configuration),
              const SizedBox(height: AppUi.gap16),
              toolbar(applications, configuration),
              const SizedBox(height: AppUi.gap16),
              if (filtered.isEmpty)
                const _MessageCard(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'По фильтрам ничего нет',
                  text: 'Измените поиск, объект, вакансию или выбранный этап.',
                )
              else if (viewMode == RecruitmentViewMode.board)
                board(filtered, configuration)
              else
                list(filtered, configuration),
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
  final RecruitmentCrmConfiguration configuration;

  const RecruitmentApplicationEditor({
    super.key,
    required this.profile,
    required this.configuration,
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
  final Map<String, TextEditingController> customControllers =
      <String, TextEditingController>{};
  late final Map<String, dynamic> customValues;
  late String stageId;
  DateTime? departureDate;
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final application = widget.application;
    fullNameController = TextEditingController(text: application?.fullName ?? '');
    phoneController = TextEditingController(text: application?.phone ?? '');
    citizenshipController =
        TextEditingController(text: application?.citizenship ?? '');
    vacancyController = TextEditingController(text: application?.vacancy ?? '');
    objectController = TextEditingController(text: application?.objectName ?? '');
    experienceController =
        TextEditingController(text: application?.experience ?? '');
    commentController = TextEditingController(text: application?.comment ?? '');
    departureDate = application?.departureDate;
    customValues = Map<String, dynamic>.from(
      application?.customValues ?? const <String, dynamic>{},
    );
    final applicationStage = application == null
        ? null
        : widget.configuration.stageForApplication(application);
    stageId = applicationStage?.id ??
        (widget.configuration.stages.isEmpty
            ? ''
            : widget.configuration.stages.first.id);

    for (final field in widget.configuration.fields) {
      if (_usesTextController(field.fieldType)) {
        final value = field.formatValue(customValues[field.id]);
        customControllers[field.id] = TextEditingController(
          text: field.fieldType == 'money'
              ? value.replaceAll(' ₽', '')
              : value,
        );
      }
    }
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
    for (final controller in customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _usesTextController(String type) => const <String>{
        'text',
        'multiline',
        'number',
        'money',
        'phone',
        'email',
      }.contains(type);

  String dateText(DateTime? value) {
    if (value == null) return 'Не указана';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  DateTime? customDate(RecruitmentCustomField field) {
    return DateTime.tryParse(customValues[field.id]?.toString() ?? '');
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

  Future<void> chooseCustomDate(RecruitmentCustomField field) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: customDate(field) ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );
    if (selected != null && mounted) {
      setState(() {
        customValues[field.id] =
            '${selected.year.toString().padLeft(4, '0')}-'
            '${selected.month.toString().padLeft(2, '0')}-'
            '${selected.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Map<String, dynamic> collectCustomValues() {
    final result = Map<String, dynamic>.from(customValues);
    for (final field in widget.configuration.fields) {
      if (!_usesTextController(field.fieldType)) continue;
      final text = customControllers[field.id]?.text.trim() ?? '';
      if (text.isEmpty) {
        result.remove(field.id);
        continue;
      }
      if (field.fieldType == 'number' || field.fieldType == 'money') {
        final normalized = text.replaceAll(' ', '').replaceAll(',', '.');
        final number = num.tryParse(normalized);
        result[field.id] = number ?? text;
      } else {
        result[field.id] = text;
      }
    }
    result.removeWhere((key, value) {
      if (value == null) return true;
      if (value is String) return value.trim().isEmpty;
      if (value is Iterable) return value.isEmpty;
      return false;
    });
    return result;
  }

  String? validateCustomValues(Map<String, dynamic> values) {
    for (final field in widget.configuration.fields) {
      final value = values[field.id];
      if (field.isRequired && field.isEmptyValue(value)) {
        return 'Заполните обязательное поле «${field.title}»';
      }
      if ((field.fieldType == 'number' || field.fieldType == 'money') &&
          !field.isEmptyValue(value) &&
          value is! num) {
        return 'В поле «${field.title}» укажите число';
      }
    }
    return null;
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
    if (stageId.isEmpty) {
      setState(() => errorText = 'Выберите колонку CRM');
      return;
    }
    final values = collectCustomValues();
    final validationError = validateCustomValues(values);
    if (validationError != null) {
      setState(() => errorText = validationError);
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      final stage = widget.configuration.stageById(stageId);
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
        status: stage?.legacyStatus ?? widget.application?.status ?? 'new',
        stageId: stageId,
        comment: commentController.text,
        customValues: values,
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

  Widget customFieldWidget(RecruitmentCustomField field) {
    final requiredSuffix = field.isRequired ? ' *' : '';
    switch (field.fieldType) {
      case 'boolean':
        return SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text('${field.title}$requiredSuffix'),
          value: customValues[field.id] == true,
          onChanged: saving
              ? null
              : (value) => setState(() => customValues[field.id] = value),
        );
      case 'select':
        final current = customValues[field.id]?.toString() ?? '';
        return DropdownButtonFormField<String>(
          initialValue: field.options.contains(current) ? current : null,
          decoration: InputDecoration(
            labelText: '${field.title}$requiredSuffix',
            prefixIcon: const Icon(Icons.format_list_bulleted_rounded),
          ),
          items: field.options
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: saving
              ? null
              : (value) => setState(() {
                    if (value == null) {
                      customValues.remove(field.id);
                    } else {
                      customValues[field.id] = value;
                    }
                  }),
        );
      case 'multiselect':
        final selected = switch (customValues[field.id]) {
          List value => value.map((item) => item.toString()).toSet(),
          _ => <String>{},
        };
        return InputDecorator(
          decoration: InputDecoration(
            labelText: '${field.title}$requiredSuffix',
            prefixIcon: const Icon(Icons.checklist_rounded),
          ),
          child: Wrap(
            spacing: AppUi.gap8,
            runSpacing: AppUi.gap8,
            children: field.options.map((option) {
              return FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: saving
                    ? null
                    : (enabled) => setState(() {
                          final next = Set<String>.from(selected);
                          enabled ? next.add(option) : next.remove(option);
                          if (next.isEmpty) {
                            customValues.remove(field.id);
                          } else {
                            customValues[field.id] = next.toList();
                          }
                        }),
              );
            }).toList(),
          ),
        );
      case 'date':
        final value = customDate(field);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.event_outlined),
          title: Text('${field.title}$requiredSuffix'),
          subtitle: Text(dateText(value)),
          trailing: value == null
              ? const Icon(Icons.chevron_right_rounded)
              : IconButton(
                  tooltip: 'Очистить дату',
                  onPressed: saving
                      ? null
                      : () => setState(() => customValues.remove(field.id)),
                  icon: const Icon(Icons.close_rounded),
                ),
          onTap: saving ? null : () => chooseCustomDate(field),
        );
      default:
        final multiline = field.fieldType == 'multiline';
        final numeric =
            field.fieldType == 'number' || field.fieldType == 'money';
        final keyboardType = switch (field.fieldType) {
          'phone' => TextInputType.phone,
          'email' => TextInputType.emailAddress,
          'number' || 'money' => const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          _ => TextInputType.text,
        };
        return TextField(
          controller: customControllers[field.id],
          enabled: !saving,
          keyboardType: keyboardType,
          minLines: multiline ? 2 : 1,
          maxLines: multiline ? 5 : 1,
          decoration: InputDecoration(
            labelText: '${field.title}$requiredSuffix',
            prefixIcon: Icon(_customFieldIcon(field.fieldType)),
            suffixText: field.fieldType == 'money' ? '₽' : null,
            helperText: numeric ? 'Только числовое значение' : null,
          ),
        );
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
        color: AppAdaptivePalette.surface,
        borderRadius: BorderRadius.circular(AppUi.modalRadius),
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
                  style: TextStyle(
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
          const SizedBox(height: AppUi.gap8),
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
                const SizedBox(height: AppUi.gap12),
                TextField(
                  controller: phoneController,
                  enabled: !saving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: AppUi.gap12),
                TextField(
                  controller: citizenshipController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Гражданство',
                    prefixIcon: Icon(Icons.public_outlined),
                  ),
                ),
                const SizedBox(height: AppUi.gap12),
                TextField(
                  controller: vacancyController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Вакансия',
                    hintText: 'Например: бетонщик-арматурщик',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppUi.gap12),
                TextField(
                  controller: objectController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Объект',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                ),
                const SizedBox(height: AppUi.gap12),
                TextField(
                  controller: experienceController,
                  enabled: !saving,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Опыт',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: AppUi.gap12),
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
                const SizedBox(height: AppUi.gap8),
                DropdownButtonFormField<String>(
                  initialValue: widget.configuration.stageById(stageId) == null
                      ? null
                      : stageId,
                  decoration: const InputDecoration(
                    labelText: 'Колонка CRM',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: widget.configuration.stages
                      .map(
                        (stage) => DropdownMenuItem<String>(
                          value: stage.id,
                          child: Text(stage.title),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) => setState(() => stageId = value ?? ''),
                ),
                if (widget.configuration.fields.isNotEmpty) ...[
                  const SizedBox(height: AppUi.gap20),
                  Text(
                    'Дополнительные поля',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppUi.gap12),
                  ...widget.configuration.fields.expand(
                    (field) => <Widget>[
                      customFieldWidget(field),
                      const SizedBox(height: AppUi.gap12),
                    ],
                  ),
                ],
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
                  const SizedBox(height: AppUi.gap12),
                  Text(
                    errorText!.replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppAdaptivePalette.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: AppUi.gap16),
                SizedBox(
                  height: AppUi.controlHeight,
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

IconData _customFieldIcon(String type) {
  switch (type) {
    case 'multiline':
      return Icons.notes_rounded;
    case 'number':
      return Icons.numbers_rounded;
    case 'money':
      return Icons.payments_outlined;
    case 'phone':
      return Icons.phone_outlined;
    case 'email':
      return Icons.email_outlined;
    default:
      return Icons.short_text_rounded;
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
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
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
          SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (action != null) ...[
            SizedBox(height: 14),
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
