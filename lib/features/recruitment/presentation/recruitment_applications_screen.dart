import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_ui_tokens.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_crm_workspace_repository.dart';
import '../data/recruitment_repository.dart';
import '../models/recruitment_crm_workspace_models.dart';
import '../models/recruitment_models.dart';
import 'recruitment_application_detail_screen.dart';
import 'recruitment_archive_screen.dart';
import 'recruitment_crm_settings_screen.dart';
import 'recruitment_import_screen.dart';

Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _soft => AppAdaptivePalette.surfaceSoft;

enum RecruitmentViewMode { board, list }

enum RecruitmentSortMode { updatedDesc, updatedAsc, name, nextTask }

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
  Future<RecruitmentBoardSupportData> supportFuture =
      Future<RecruitmentBoardSupportData>.value(
        RecruitmentBoardSupportData.empty,
      );
  StreamSubscription<AppDataChange>? changesSubscription;
  final Set<String> archiveBusyIds = <String>{};
  final Set<String> movingIds = <String>{};
  final Map<String, String> pendingStageIds = <String, String>{};
  final Set<String> selectedIds = <String>{};
  String? draggingApplicationId;
  String? draggingStageId;
  List<String>? pendingStageOrder;
  bool stageMutationBusy = false;
  RecruitmentViewMode viewMode = RecruitmentViewMode.board;
  RecruitmentSortMode sortMode = RecruitmentSortMode.updatedDesc;
  String listStage = 'all';
  String objectFilter = 'all';
  String vacancyFilter = 'all';
  String responsibleFilter = 'all';
  bool hideEmptyColumns = false;
  bool selectionMode = false;

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
      if (change.affects(AppDataDomain.recruitment) &&
mounted &&
!stageMutationBusy) {
        refresh();
      }
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

  Future<RecruitmentWorkspaceData> load() async {
    final workspace = await RecruitmentRepository.fetchWorkspace(
      companyId: widget.profile.activeCompanyId,
    );
    supportFuture = RecruitmentCrmWorkspaceRepository.fetchBoardSupport(
      companyId: widget.profile.activeCompanyId,
      applications: workspace.applications,
    );
    return workspace;
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
        (first, second) => first.toLowerCase().compareTo(second.toLowerCase()),
      );
  }

  List<RecruitmentApplication> visible(
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration, {
    Map<String, RecruitmentCandidateIndicator> indicators =
        const <String, RecruitmentCandidateIndicator>{},
    bool applyListStage = false,
  }) {
    final query = searchController.text.trim().toLowerCase();
    final result = applications.where((application) {
      final stage = effectiveStageFor(application, configuration);
      if (applyListStage && listStage != 'all' && stage?.id != listStage) {
        return false;
      }
      if (objectFilter != 'all' && application.objectName != objectFilter) {
        return false;
      }
      if (vacancyFilter != 'all' && application.vacancy != vacancyFilter) {
        return false;
      }
      if (responsibleFilter != 'all') {
        final responsible = application.responsibleUserId.trim();
        if (responsibleFilter == 'none') {
          if (responsible.isNotEmpty) return false;
        } else if (responsible != responsibleFilter) {
          return false;
        }
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
    result.sort((first, second) {
      switch (sortMode) {
        case RecruitmentSortMode.updatedAsc:
          return first.updatedAt.compareTo(second.updatedAt);
        case RecruitmentSortMode.name:
          return first.fullName.toLowerCase().compareTo(
            second.fullName.toLowerCase(),
          );
        case RecruitmentSortMode.nextTask:
          final firstDue =
              indicators[first.id]?.nextTaskDueAt ?? DateTime(9999);
          final secondDue =
              indicators[second.id]?.nextTaskDueAt ?? DateTime(9999);
          return firstDue.compareTo(secondDue);
        case RecruitmentSortMode.updatedDesc:
          return second.updatedAt.compareTo(first.updatedAt);
      }
    });
    return result;
  }

  Color stageColor(RecruitmentPipelineStage stage) {
    final clean = stage.colorHex.replaceFirst('#', '');
    final parsed = int.tryParse(clean, radix: 16) ?? 0x2F80ED;
    return Color(0xFF000000 | parsed);
  }

  List<RecruitmentPipelineStage> orderedStages(
    RecruitmentCrmConfiguration configuration,
  ) {
    final order = pendingStageOrder;
    if (order == null ||
        order.length != configuration.stages.length ||
        order.toSet().length != configuration.stages.length) {
      return configuration.stages;
    }
    final byId = <String, RecruitmentPipelineStage>{
      for (final stage in configuration.stages) stage.id: stage,
    };
    if (order.any((id) => !byId.containsKey(id))) return configuration.stages;
    return order.map((id) => byId[id]!).toList(growable: false);
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

  Future<void> openImport(RecruitmentWorkspaceData workspace) async {
    final imported = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => RecruitmentImportScreen(
          profile: widget.profile,
          workspace: workspace,
        ),
      ),
    );
    if (imported != null && imported > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортировано кандидатов: $imported')),
      );
      await refresh();
    }
  }

  Future<void> runAutomations(Iterable<String> applicationIds) async {
    try {
      await RecruitmentCrmWorkspaceRepository.runAutomations(
        applicationIds: applicationIds.toList(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Кандидаты сохранены, но автоматизация не выполнилась: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Map<String, dynamic> currentViewFilters() => <String, dynamic>{
    'query': searchController.text.trim(),
    'object': objectFilter,
    'vacancy': vacancyFilter,
    'responsible': responsibleFilter,
    'stage': listStage,
    'view_mode': viewMode.name,
    'sort_mode': sortMode.name,
    'hide_empty_columns': hideEmptyColumns,
  };

  void applySavedView(RecruitmentCrmSavedView view) {
    final filters = view.filters;
    searchController.text = filters['query']?.toString() ?? '';
    setState(() {
      objectFilter = filters['object']?.toString() ?? 'all';
      vacancyFilter = filters['vacancy']?.toString() ?? 'all';
      responsibleFilter = filters['responsible']?.toString() ?? 'all';
      listStage = filters['stage']?.toString() ?? 'all';
      final savedViewMode = filters['view_mode']?.toString() ?? '';
      viewMode =
          RecruitmentViewMode.values.any((value) => value.name == savedViewMode)
          ? RecruitmentViewMode.values.firstWhere(
              (value) => value.name == savedViewMode,
            )
          : RecruitmentViewMode.board;
      final savedSortMode = filters['sort_mode']?.toString() ?? '';
      sortMode =
          RecruitmentSortMode.values.any((value) => value.name == savedSortMode)
          ? RecruitmentSortMode.values.firstWhere(
              (value) => value.name == savedSortMode,
            )
          : RecruitmentSortMode.updatedDesc;
      hideEmptyColumns = filters['hide_empty_columns'] == true;
    });
  }

  Future<void> saveCurrentView() async {
    final controller = TextEditingController();
    var makeDefault = false;
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Сохранить представление'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: Просроченные по Мурманску',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: makeDefault,
                onChanged: (value) =>
                    setDialogState(() => makeDefault = value == true),
                title: const Text('Открывать по умолчанию'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, <String, dynamic>{
                'title': controller.text,
                'is_default': makeDefault,
              }),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    final title = draft?['title']?.toString().trim() ?? '';
    if (title.isEmpty) return;
    try {
      await RecruitmentCrmWorkspaceRepository.saveView(
        companyId: widget.profile.activeCompanyId,
        title: title,
        filters: currentViewFilters(),
        isDefault: draft?['is_default'] == true,
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить представление: $error')),
      );
    }
  }

  Future<void> bulkMove(RecruitmentCrmConfiguration configuration) async {
    if (selectedIds.isEmpty) return;
    final stageId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Переместить кандидатов: ${selectedIds.length}'),
        children: configuration.stages
            .map(
              (stage) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, stage.id),
                child: Text(stage.title),
              ),
            )
            .toList(),
      ),
    );
    if (stageId == null) return;
    try {
      final ids = selectedIds.toList();
      final count = await RecruitmentCrmWorkspaceRepository.bulkMove(
        applicationIds: ids,
        stageId: stageId,
      );
      await runAutomations(ids);
      if (!mounted) return;
      setState(() {
        selectedIds.clear();
        selectionMode = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Перемещено кандидатов: $count')));
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось переместить кандидатов: $error')),
      );
    }
  }

  Future<void> assignSelected(RecruitmentBoardSupportData support) async {
    if (selectedIds.isEmpty) return;
    final userId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Назначить ответственного: ${selectedIds.length}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Снять ответственного'),
          ),
          ...support.responsibles.map(
            (item) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item.userId),
              child: Text(item.fullName),
            ),
          ),
        ],
      ),
    );
    if (userId == null) return;
    try {
      for (final id in selectedIds) {
        await RecruitmentCrmWorkspaceRepository.assignResponsible(
          applicationId: id,
          responsibleUserId: userId,
        );
      }
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось назначить ответственного: $error')),
      );
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

  RecruitmentPipelineStage? effectiveStageFor(
    RecruitmentApplication application,
    RecruitmentCrmConfiguration configuration,
  ) {
    final pendingStageId = pendingStageIds[application.id];
    if (pendingStageId != null) {
      return configuration.stageById(pendingStageId) ??
          configuration.stageForApplication(application);
    }
    return configuration.stageForApplication(application);
  }

  Future<String?> requestStageTitle({
    required String dialogTitle,
    required String actionLabel,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(dialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Название колонки',
              prefixIcon: const Icon(Icons.view_column_outlined),
              errorText: error,
            ),
            onSubmitted: (_) {
              final title = controller.text.trim();
              if (title.isEmpty) {
                setDialogState(() => error = 'Введите название');
                return;
              }
              Navigator.pop(dialogContext, title);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final title = controller.text.trim();
                if (title.isEmpty) {
                  setDialogState(() => error = 'Введите название');
                  return;
                }
                Navigator.pop(dialogContext, title);
              },
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  String defaultStageColor(int index) {
    const colors = <String>[
      '#2F80ED',
      '#8B5CF6',
      '#0EA5A4',
      '#F59E0B',
      '#E45757',
      '#4C6076',
    ];
    return colors[index % colors.length];
  }

  Future<void> createStage(RecruitmentCrmConfiguration configuration) async {
    if (stageMutationBusy) return;
    final title = await requestStageTitle(
      dialogTitle: 'Новая колонка',
      actionLabel: 'Добавить',
    );
    if (title == null || !mounted) return;
    setState(() => stageMutationBusy = true);
    try {
      await RecruitmentRepository.createPipelineStageAtEnd(
        companyId: widget.profile.activeCompanyId,
        title: title,
        description: '',
        colorHex: defaultStageColor(configuration.stages.length),
        legacyStatus: 'new',
        isFinal: false,
      );
      await refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Колонка «$title» добавлена справа')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось добавить колонку: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
stageMutationBusy = false;
pendingStageOrder = null;
        });
      }
    }
  }

  Future<void> renameStage(RecruitmentPipelineStage stage) async {
    if (stageMutationBusy) return;
    final title = await requestStageTitle(
      dialogTitle: 'Переименовать колонку',
      actionLabel: 'Сохранить',
      initialValue: stage.title,
    );
    if (title == null || title == stage.title || !mounted) return;
    setState(() => stageMutationBusy = true);
    try {
      await RecruitmentRepository.savePipelineStage(
        id: stage.id,
        companyId: widget.profile.activeCompanyId,
        title: title,
        description: stage.description,
        colorHex: stage.colorHex,
        legacyStatus: stage.legacyStatus,
        isFinal: stage.isFinal,
        sortOrder: stage.sortOrder,
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось переименовать колонку: $error')),
      );
    } finally {
      if (mounted) setState(() => stageMutationBusy = false);
    }
  }

  Future<String?> confirmStageDeletion({
    required RecruitmentPipelineStage stage,
    required RecruitmentCrmConfiguration configuration,
    required int candidateCount,
  }) async {
    final alternatives = configuration.stages
        .where((item) => item.id != stage.id && item.isActive)
        .toList(growable: false);
    if (candidateCount > 0 && alternatives.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сначала создайте другую колонку, чтобы перенести туда кандидатов',
          ),
        ),
      );
      return null;
    }

    var replacementId = candidateCount > 0 ? alternatives.first.id : '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Удалить колонку «${stage.title}»?'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (candidateCount > 0) ...[
                  Text(
                    'В колонке кандидатов: $candidateCount. '
                    'Перед удалением они будут перенесены.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppUi.gap12),
                  DropdownButtonFormField<String>(
                    initialValue: replacementId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Перенести кандидатов в',
                      prefixIcon: Icon(Icons.drive_file_move_outline),
                    ),
                    items: alternatives
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(
                              item.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setDialogState(
                      () => replacementId = value ?? replacementId,
                    ),
                  ),
                  const SizedBox(height: AppUi.gap12),
                ],
                if (stage.systemKey.isNotEmpty) ...[
                  const Text(
                    'Это системная колонка. После удаления её можно будет '
                    'создать заново как обычную.',
                  ),
                  const SizedBox(height: AppUi.gap8),
                ],
                const Text(
                  'Автоматизации, привязанные к этой колонке, тоже будут '
                  'удалены. Действие нельзя отменить.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppAdaptivePalette.danger,
              ),
              onPressed: () => Navigator.pop(dialogContext, replacementId),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Удалить колонку'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteStage(
    RecruitmentPipelineStage stage,
    RecruitmentCrmConfiguration configuration,
  ) async {
    if (stageMutationBusy) return;
    try {
      final values = await Future.wait<List<RecruitmentApplication>>([
        RecruitmentRepository.fetchApplications(
          companyId: widget.profile.activeCompanyId,
        ),
        RecruitmentRepository.fetchApplications(
          companyId: widget.profile.activeCompanyId,
          archived: true,
        ),
      ]);
      if (!mounted) return;
      final candidateCount = values
          .expand((items) => items)
          .where((application) => application.stageId == stage.id)
          .length;
      final replacementId = await confirmStageDeletion(
        stage: stage,
        configuration: configuration,
        candidateCount: candidateCount,
      );
      if (replacementId == null || !mounted) return;

      setState(() => stageMutationBusy = true);
      final moved = await RecruitmentRepository.deletePipelineStage(
        companyId: widget.profile.activeCompanyId,
        stageId: stage.id,
        replacementStageId: replacementId,
      );
      if (listStage == stage.id) listStage = 'all';
      pendingStageOrder = null;
      await refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            moved > 0
                ? 'Колонка удалена. Перенесено кандидатов: $moved'
                : 'Колонка «${stage.title}» удалена',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить колонку: $error')),
      );
    } finally {
      if (mounted) setState(() => stageMutationBusy = false);
    }
  }

  Future<void> reorderStageOnBoard(
    RecruitmentCrmConfiguration configuration,
    RecruitmentPipelineStage dragged,
    RecruitmentPipelineStage target,
  ) async {
    if (stageMutationBusy || dragged.id == target.id) return;
    final current = orderedStages(configuration);
    final fromIndex = current.indexWhere((stage) => stage.id == dragged.id);
    final targetIndex = current.indexWhere((stage) => stage.id == target.id);
    if (fromIndex < 0 || targetIndex < 0) return;

    final ids = current.map((stage) => stage.id).toList();
    final movedId = ids.removeAt(fromIndex);
    final insertionIndex = fromIndex < targetIndex ? targetIndex : targetIndex;
    ids.insert(insertionIndex, movedId);
    if (ids.join('|') == current.map((stage) => stage.id).join('|')) return;

    setState(() {
      stageMutationBusy = true;
      pendingStageOrder = ids;
      draggingStageId = null;
    });
    try {
      final confirmedIds = await RecruitmentRepository.reorderPipelineStages(
        companyId: widget.profile.activeCompanyId,
        orderedIds: ids,
      );
      if (confirmedIds.join('|') != ids.join('|')) {
        throw Exception('Сервер сохранил другой порядок колонок');
      }
      pendingStageOrder = confirmedIds;
      await refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => pendingStageOrder = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить порядок колонок: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
stageMutationBusy = false;
pendingStageOrder = null;
draggingStageId = null;
        });
      }
    }
  }

  Future<void> moveToStage(
    RecruitmentApplication application,
    RecruitmentPipelineStage stage,
  ) async {
    final currentStageId =
        pendingStageIds[application.id] ?? application.stageId;
    if (currentStageId == stage.id || movingIds.contains(application.id)) {
      return;
    }
    setState(() {
      movingIds.add(application.id);
      pendingStageIds[application.id] = stage.id;
      draggingApplicationId = null;
    });
    try {
      await RecruitmentRepository.moveApplicationStage(
        applicationId: application.id,
        stageId: stage.id,
      );
      if (mounted) await refresh();
      await runAutomations(<String>[application.id]);
    } catch (error) {
      if (!mounted) return;
      setState(() => pendingStageIds.remove(application.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить этап: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          movingIds.remove(application.id);
          pendingStageIds.remove(application.id);
        });
      }
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
    RecruitmentBoardSupportData support,
  ) {
    final objects = filterValues(applications, (item) => item.objectName);
    final vacancies = filterValues(applications, (item) => item.vacancy);

    return PremiumWorkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
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
          ),
          const SizedBox(height: AppUi.gap12),
          Wrap(
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
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      <String>{
                        'all',
                        'none',
                        ...support.responsibles.map((item) => item.userId),
                      }.contains(responsibleFilter)
                      ? responsibleFilter
                      : 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ответственный',
                    prefixIcon: Icon(Icons.support_agent_rounded),
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem(value: 'all', child: Text('Все')),
                    const DropdownMenuItem(
                      value: 'none',
                      child: Text('Не назначен'),
                    ),
                    ...support.responsibles.map(
                      (item) => DropdownMenuItem(
                        value: item.userId,
                        child: Text(
                          item.fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => responsibleFilter = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<RecruitmentSortMode>(
                  initialValue: sortMode,
                  decoration: const InputDecoration(
                    labelText: 'Сортировка',
                    prefixIcon: Icon(Icons.sort_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RecruitmentSortMode.updatedDesc,
                      child: Text('Сначала новые'),
                    ),
                    DropdownMenuItem(
                      value: RecruitmentSortMode.updatedAsc,
                      child: Text('Сначала старые'),
                    ),
                    DropdownMenuItem(
                      value: RecruitmentSortMode.name,
                      child: Text('По ФИО'),
                    ),
                    DropdownMenuItem(
                      value: RecruitmentSortMode.nextTask,
                      child: Text('По ближайшему делу'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => sortMode = value ?? sortMode),
                ),
              ),
              SegmentedButton<RecruitmentViewMode>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<RecruitmentViewMode>>[
                  ButtonSegment(
                    value: RecruitmentViewMode.board,
                    icon: Icon(Icons.view_kanban_outlined),
                    label: Text('Канбан'),
                  ),
                  ButtonSegment(
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
              FilterChip(
                selected: hideEmptyColumns,
                onSelected: (value) => setState(() => hideEmptyColumns = value),
                avatar: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('Скрыть пустые колонки'),
              ),
              FilterChip(
                selected: selectionMode,
                onSelected: (value) => setState(() {
                  selectionMode = value;
                  if (!value) selectedIds.clear();
                }),
                avatar: const Icon(Icons.library_add_check_outlined, size: 18),
                label: const Text('Массовые действия'),
              ),
              PopupMenuButton<String>(
                tooltip: 'Сохранённые представления',
                onSelected: (value) {
                  if (value == 'save') {
                    saveCurrentView();
                    return;
                  }
                  final selected = support.savedViews.where(
                    (item) => item.id == value,
                  );
                  if (selected.isNotEmpty) applySavedView(selected.first);
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  const PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(Icons.bookmark_add_outlined),
                        SizedBox(width: AppUi.gap8),
                        Text('Сохранить текущий вид'),
                      ],
                    ),
                  ),
                  if (support.savedViews.isNotEmpty) const PopupMenuDivider(),
                  ...support.savedViews.map(
                    (item) => PopupMenuItem(
                      value: item.id,
                      child: Row(
                        children: [
                          Icon(
                            item.isDefault
                                ? Icons.star_rounded
                                : Icons.bookmark_outline_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: AppUi.gap8),
                          Expanded(child: Text(item.title)),
                        ],
                      ),
                    ),
                  ),
                ],
                child: const Chip(
                  avatar: Icon(Icons.bookmarks_outlined, size: 18),
                  label: Text('Представления'),
                ),
              ),
            ],
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
    RecruitmentCandidateIndicator indicator =
        const RecruitmentCandidateIndicator(),
    bool feedback = false,
  }) {
    final stage = effectiveStageFor(application, configuration);
    final color = stage == null ? AppAdaptivePalette.accent : stageColor(stage);
    final busy =
        movingIds.contains(application.id) ||
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
                child: Icon(
                  Icons.person_search_rounded,
                  color: color,
                  size: 20,
                ),
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
              if (!feedback && selectionMode)
                Checkbox(
                  value: selectedIds.contains(application.id),
                  onChanged: (value) => setState(() {
                    value == true
                        ? selectedIds.add(application.id)
                        : selectedIds.remove(application.id);
                  }),
                ),
              if (!feedback && !selectionMode)
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
              _InfoPill(
                icon: Icons.send_outlined,
                label: application.sourceTitle,
              ),
              if (application.phone.isNotEmpty)
                _InfoPill(icon: Icons.phone_outlined, label: application.phone),
              if (application.departureDate != null)
                _InfoPill(
                  icon: Icons.flight_takeoff_outlined,
                  label: 'Выезд ${shortDate(application.departureDate)}',
                ),
            ],
          ),
          if (indicator.responsibleName.isNotEmpty ||
              indicator.openTasks > 0) ...[
            const SizedBox(height: AppUi.gap8),
            Wrap(
              spacing: AppUi.gap8,
              runSpacing: AppUi.gap8,
              children: [
                if (indicator.responsibleName.isNotEmpty)
                  _InfoPill(
                    icon: Icons.support_agent_rounded,
                    label: indicator.responsibleName,
                  ),
                if (indicator.openTasks > 0)
                  _InfoPill(
                    icon: indicator.overdueTasks > 0
                        ? Icons.warning_amber_rounded
                        : Icons.task_alt_rounded,
                    label: indicator.overdueTasks > 0
                        ? 'Просрочено: ${indicator.overdueTasks}'
                        : 'Дел: ${indicator.openTasks}',
                  ),
                if (indicator.nextTaskDueAt != null)
                  _InfoPill(
                    icon: Icons.event_outlined,
                    label: 'Следующее ${shortDate(indicator.nextTaskDueAt)}',
                  ),
              ],
            ),
          ],
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
      onTap: busy
          ? null
          : selectionMode
          ? () => setState(() {
              selectedIds.contains(application.id)
                  ? selectedIds.remove(application.id)
                  : selectedIds.add(application.id);
            })
          : () => openEditor(configuration, application),
      borderRadius: BorderRadius.circular(AppUi.cardRadius),
      child: card,
    );
    final feedbackCard = Material(
      color: AppAdaptivePalette.surface,
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(AppUi.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 292,
        child: candidateCard(
          application,
          configuration,
          indicator: indicator,
          feedback: true,
        ),
      ),
    );
    final draggingPlaceholder = AnimatedOpacity(
      opacity: 0.20,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Transform.scale(scale: 0.985, child: card),
    );

    void handleDragStarted() {
      if (mounted) setState(() => draggingApplicationId = application.id);
    }

    void handleDragFinished() {
      if (mounted && draggingApplicationId == application.id) {
        setState(() => draggingApplicationId = null);
      }
    }

    if (kIsWeb) {
      return Draggable<RecruitmentApplication>(
        data: application,
        maxSimultaneousDrags: busy ? 0 : 1,
        rootOverlay: true,
        feedback: Transform.scale(scale: 1.015, child: feedbackCard),
        childWhenDragging: draggingPlaceholder,
        onDragStarted: handleDragStarted,
        onDragEnd: (_) => handleDragFinished(),
        onDraggableCanceled: (_, _) => handleDragFinished(),
        child: interactiveCard,
      );
    }
    return LongPressDraggable<RecruitmentApplication>(
      data: application,
      maxSimultaneousDrags: busy ? 0 : 1,
      rootOverlay: true,
      feedback: Transform.scale(scale: 1.015, child: feedbackCard),
      childWhenDragging: draggingPlaceholder,
      onDragStarted: handleDragStarted,
      onDragEnd: (_) => handleDragFinished(),
      onDraggableCanceled: (_, _) => handleDragFinished(),
      child: interactiveCard,
    );
  }

  Widget stageDragHandle(RecruitmentPipelineStage stage) {
    final handle = Tooltip(
      message: kIsWeb
          ? 'Перетащить колонку'
          : 'Удерживай и перетащи колонку',
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.drag_indicator_rounded,
            size: 20,
            color: _muted,
          ),
        ),
      ),
    );
    final feedback = Material(
      color: AppAdaptivePalette.surfaceElevated,
      elevation: 18,
      borderRadius: BorderRadius.circular(AppUi.controlRadius),
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUi.controlRadius),
          border: Border.all(color: stageColor(stage).withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.drag_indicator_rounded, color: stageColor(stage)),
            const SizedBox(width: AppUi.gap8),
            Expanded(
              child: Text(
                stage.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );

    void started() {
      if (mounted) setState(() => draggingStageId = stage.id);
    }

    void finished() {
      if (mounted && draggingStageId == stage.id) {
        setState(() => draggingStageId = null);
      }
    }

    if (kIsWeb) {
      return Draggable<RecruitmentPipelineStage>(
        data: stage,
        rootOverlay: true,
        maxSimultaneousDrags: stageMutationBusy ? 0 : 1,
        feedback: feedback,
        onDragStarted: started,
        onDragEnd: (_) => finished(),
        onDraggableCanceled: (_, _) => finished(),
        childWhenDragging: Opacity(opacity: 0.35, child: handle),
        child: handle,
      );
    }
    return LongPressDraggable<RecruitmentPipelineStage>(
      data: stage,
      rootOverlay: true,
      maxSimultaneousDrags: stageMutationBusy ? 0 : 1,
      feedback: feedback,
      onDragStarted: started,
      onDragEnd: (_) => finished(),
      onDraggableCanceled: (_, _) => finished(),
      childWhenDragging: Opacity(opacity: 0.35, child: handle),
      child: handle,
    );
  }

  Widget kanbanColumn(
    RecruitmentPipelineStage stage,
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration,
    RecruitmentBoardSupportData support,
  ) {
    final color = stageColor(stage);
    return DragTarget<RecruitmentPipelineStage>(
      onWillAcceptWithDetails: (details) =>
canConfigureCrm &&
!stageMutationBusy &&
details.data.id != stage.id,
      onAcceptWithDetails: (details) =>
reorderStageOnBoard(configuration, details.data, stage),
      builder: (context, stageCandidates, rejectedStages) {
        final stageHighlighted = stageCandidates.isNotEmpty;
        return AnimatedScale(
          scale: stageHighlighted ? 1.018 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: stageHighlighted
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(AppUi.cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: AppAdaptivePalette.accent.withValues(alpha: 0.22),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: DragTarget<RecruitmentApplication>(
              onWillAcceptWithDetails: (details) =>
                  !movingIds.contains(details.data.id) &&
                  effectiveStageFor(details.data, configuration)?.id != stage.id,
              onAcceptWithDetails: (details) =>
                  moveToStage(details.data, stage),
              builder: (context, candidates, rejected) {
                final highlighted = candidates.isNotEmpty;
                return AnimatedScale(
                  scale: highlighted ? 1.012 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 310,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: stageHighlighted
                          ? AppAdaptivePalette.accent.withValues(alpha: 0.09)
                          : highlighted
                          ? color.withValues(alpha: 0.12)
                          : AppAdaptivePalette.surfaceSoft.withValues(
                              alpha: 0.62,
                            ),
                      borderRadius: BorderRadius.circular(AppUi.cardRadius),
                      border: Border.all(
                        color: stageHighlighted
                            ? AppAdaptivePalette.accent.withValues(alpha: 0.70)
                            : highlighted
                            ? color.withValues(alpha: 0.62)
                            : AppAdaptivePalette.border,
                        width: stageHighlighted || highlighted ? 2 : 1,
                      ),
                      boxShadow: highlighted
                          ? <BoxShadow>[
                              BoxShadow(
                                color: color.withValues(alpha: 0.16),
                                blurRadius: 22,
                                spreadRadius: 1,
                              ),
                            ]
                          : const <BoxShadow>[],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            if (canConfigureCrm) stageDragHandle(stage),
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
                            if (canConfigureCrm)
                              PopupMenuButton<String>(
                                tooltip: 'Переименовать колонку',
                                enabled: !stageMutationBusy,
                                onSelected: (value) {
                                  if (value == 'rename') renameStage(stage);
                                  if (value == 'delete') {
                                    deleteStage(stage, configuration);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem<String>(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined),
                                        SizedBox(width: AppUi.gap8),
                                        Text('Переименовать'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded),
                                        SizedBox(width: AppUi.gap8),
                                        Text('Удалить колонку'),
                                      ],
                                    ),
                                  ),
                                ],
                                icon: const Icon(Icons.more_horiz_rounded),
                              ),
                            const SizedBox(width: AppUi.gap4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${applications.length}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                ),
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
                              borderRadius: BorderRadius.circular(
                                AppUi.controlRadius,
                              ),
                              border: Border.all(
                                color: highlighted
                                    ? color.withValues(alpha: 0.40)
                                    : AppAdaptivePalette.border,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                highlighted
                                    ? 'Отпусти кандидата здесь'
                                    : stageHighlighted
                                    ? 'Отпусти колонку здесь'
                                    : 'Нет кандидатов',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: highlighted
                                      ? color
                                      : stageHighlighted
                                      ? AppAdaptivePalette.accent
                                      : _muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                        else
                          ...applications.expand(
                            (application) => <Widget>[
                              candidateCard(
                                application,
                                configuration,
                                indicator:
                                    support.indicators[application.id] ??
                                    const RecruitmentCandidateIndicator(),
                              ),
                              const SizedBox(height: AppUi.gap12),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget addColumnTile(RecruitmentCrmConfiguration configuration) {
    return SizedBox(
      width: 250,
      child: PremiumPressable(
        onTap: stageMutationBusy ? null : () => createStage(configuration),
        borderRadius: BorderRadius.circular(AppUi.cardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 132,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppAdaptivePalette.surfaceSoft.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(AppUi.cardRadius),
            border: Border.all(
              color: AppAdaptivePalette.accent.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: stageMutationBusy
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppAdaptivePalette.accent.withValues(
                          alpha: 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: AppAdaptivePalette.accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: AppUi.gap12),
                    Text(
                      'Добавить колонку',
                      style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget board(
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration,
    RecruitmentBoardSupportData support,
  ) {
    final children = <Widget>[];
    for (final stage in orderedStages(configuration)) {
      final items = applications.where((application) {
        return effectiveStageFor(application, configuration)?.id == stage.id;
      }).toList();
      if (hideEmptyColumns && items.isEmpty) continue;
      children
        ..add(kanbanColumn(stage, items, configuration, support))
        ..add(const SizedBox(width: AppUi.gap12));
    }
    if (canConfigureCrm) {
      children.add(addColumnTile(configuration));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: AppUi.gap8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget list(
    List<RecruitmentApplication> applications,
    RecruitmentCrmConfiguration configuration,
    RecruitmentBoardSupportData support,
  ) {
    if (applications.isEmpty) {
      return const _MessageCard(
        icon: Icons.person_search_outlined,
        title: 'Ничего не найдено',
        text: 'Измените поиск, фильтр объекта, вакансии или этапа.',
      );
    }
    return Column(
      children: applications
          .expand(
            (application) => <Widget>[
              candidateCard(
                application,
                configuration,
                indicator:
                    support.indicators[application.id] ??
                    const RecruitmentCandidateIndicator(),
              ),
              const SizedBox(height: AppUi.gap12),
            ],
          )
          .toList(),
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
            builder: (context, snapshot) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Импорт из Excel',
                  onPressed: snapshot.hasData
                      ? () => openImport(snapshot.data!)
                      : null,
                  icon: const Icon(Icons.upload_file_rounded),
                ),
                const SizedBox(width: AppUi.gap8),
                IconButton.filled(
                  tooltip: 'Добавить кандидата',
                  onPressed: snapshot.hasData
                      ? () => openEditor(snapshot.data!.configuration)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
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

          final workspace =
              snapshot.data ??
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
              action: canConfigureCrm ? () => createStage(configuration) : null,
            );
          }
          return FutureBuilder<RecruitmentBoardSupportData>(
            future: supportFuture,
            builder: (context, supportSnapshot) {
              final support =
                  supportSnapshot.data ?? RecruitmentBoardSupportData.empty;
              final filtered = visible(
                applications,
                configuration,
                indicators: support.indicators,
                applyListStage: viewMode == RecruitmentViewMode.list,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary(applications, configuration),
                  const SizedBox(height: AppUi.gap16),
                  toolbar(applications, configuration, support),
                  if (selectionMode && selectedIds.isNotEmpty) ...[
                    const SizedBox(height: AppUi.gap12),
                    PremiumWorkCard(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: AppUi.gap8,
                        runSpacing: AppUi.gap8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Выбрано: ${selectedIds.length}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => bulkMove(configuration),
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: const Text('Переместить'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => assignSelected(support),
                            icon: const Icon(Icons.support_agent_rounded),
                            label: const Text('Ответственный'),
                          ),
                          TextButton(
                            onPressed: () => setState(selectedIds.clear),
                            child: const Text('Снять выбор'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppUi.gap16),
                  if (filtered.isEmpty && applications.isNotEmpty)
                    const _MessageCard(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'По фильтрам ничего нет',
                      text:
                          'Измените поиск, объект, вакансию или выбранный этап.',
                    )
                  else if (viewMode == RecruitmentViewMode.board)
                    board(filtered, configuration, support)
                  else
                    list(filtered, configuration, support),
                ],
              );
            },
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
    departureDate = application?.departureDate;
    customValues = Map<String, dynamic>.from(
      application?.customValues ?? const <String, dynamic>{},
    );
    final applicationStage = application == null
        ? null
        : widget.configuration.stageForApplication(application);
    stageId =
        applicationStage?.id ??
        (widget.configuration.stages.isEmpty
            ? ''
            : widget.configuration.stages.first.id);

    for (final field in widget.configuration.fields) {
      if (_usesTextController(field.fieldType)) {
        final value = field.formatValue(customValues[field.id]);
        customControllers[field.id] = TextEditingController(
          text: field.fieldType == 'money' ? value.replaceAll(' ₽', '') : value,
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
      final savedApplication = await RecruitmentRepository.saveApplication(
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
      try {
        await RecruitmentCrmWorkspaceRepository.runAutomations(
          applicationIds: <String>[savedApplication.id],
        );
      } catch (_) {
        // Candidate saving must not fail because a follow-up automation failed.
      }
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
          subtitle: field.description.isEmpty ? null : Text(field.description),
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
            helperText: field.description.isEmpty ? null : field.description,
          ),
          items: field.options
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
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
            helperText: field.description.isEmpty ? null : field.description,
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
          subtitle: Text(
            field.description.isEmpty
                ? dateText(value)
                : '${dateText(value)}\n${field.description}',
          ),
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
            helperText: field.description.isNotEmpty
                ? field.description
                : (numeric ? 'Только числовое значение' : null),
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
