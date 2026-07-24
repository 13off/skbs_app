import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_ui_tokens.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_repository.dart';
import '../models/recruitment_models.dart';
import 'recruitment_automation_settings_panel.dart';

class RecruitmentCrmSettingsScreen extends StatefulWidget {
  final AppUserProfile profile;

  const RecruitmentCrmSettingsScreen({super.key, required this.profile});

  @override
  State<RecruitmentCrmSettingsScreen> createState() =>
      _RecruitmentCrmSettingsScreenState();
}

class _RecruitmentCrmSettingsScreenState
    extends State<RecruitmentCrmSettingsScreen> {
  late Future<RecruitmentCrmConfiguration> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<RecruitmentCrmConfiguration> load() {
    return RecruitmentRepository.fetchConfiguration(
      companyId: widget.profile.activeCompanyId,
      includeInactive: true,
    );
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> editStage(
    RecruitmentCrmConfiguration configuration, [
    RecruitmentPipelineStage? stage,
  ]) async {
    final result = await showModalBottomSheet<_StageDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StageEditor(stage: stage),
    );
    if (result == null || !mounted) return;
    setState(() => busy = true);
    try {
      final saved = await RecruitmentRepository.savePipelineStage(
        id: stage?.id ?? '',
        companyId: widget.profile.activeCompanyId,
        title: result.title,
        description: result.description,
        colorHex: result.colorHex,
        legacyStatus: stage?.legacyStatus ?? 'new',
        isFinal: result.isFinal,
        sortOrder:
            stage?.sortOrder ??
            ((configuration.stages.isEmpty
                    ? 0
                    : configuration.stages
                          .map((item) => item.sortOrder)
                          .reduce((a, b) => a > b ? a : b)) +
                10),
      );
      if (stage == null) {
        final latest = await RecruitmentRepository.fetchConfiguration(
          companyId: widget.profile.activeCompanyId,
        );
        final orderedIds = latest.stages
            .where((item) => item.id != saved.id)
            .map((item) => item.id)
            .followedBy(<String>[saved.id])
            .toList(growable: false);
        await RecruitmentRepository.reorderPipelineStages(
          companyId: widget.profile.activeCompanyId,
          orderedIds: orderedIds,
        );
      }
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleStage(RecruitmentPipelineStage stage) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await RecruitmentRepository.setPipelineStageActive(
        companyId: widget.profile.activeCompanyId,
        stageId: stage.id,
        active: !stage.isActive,
      );
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reorderStages(
    RecruitmentCrmConfiguration configuration,
    int oldIndex,
    int newIndex,
  ) async {
    if (busy) return;
    final active = configuration.stages.where((item) => item.isActive).toList();
    if (oldIndex < 0 || oldIndex >= active.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= active.length || newIndex == oldIndex) {
      return;
    }
    final moved = List<RecruitmentPipelineStage>.from(active);
    final item = moved.removeAt(oldIndex);
    moved.insert(newIndex, item);
    setState(() => busy = true);
    try {
      await RecruitmentRepository.reorderPipelineStages(
        companyId: widget.profile.activeCompanyId,
        orderedIds: moved.map((item) => item.id).toList(),
      );
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
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
      showError(
        Exception(
          'Сначала создайте другую колонку, чтобы перенести туда кандидатов',
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
    RecruitmentCrmConfiguration configuration,
    RecruitmentPipelineStage stage,
  ) async {
    if (busy) return;
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

      setState(() => busy = true);
      final moved = await RecruitmentRepository.deletePipelineStage(
        companyId: widget.profile.activeCompanyId,
        stageId: stage.id,
        replacementStageId: replacementId,
      );
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
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editField(
    RecruitmentCrmConfiguration configuration, [
    RecruitmentCustomField? field,
  ]) async {
    final result = await showModalBottomSheet<_FieldDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FieldEditor(field: field),
    );
    if (result == null || !mounted) return;
    setState(() => busy = true);
    try {
      await RecruitmentRepository.saveCustomField(
        id: field?.id ?? '',
        companyId: widget.profile.activeCompanyId,
        title: result.title,
        description: result.description,
        fieldType: result.fieldType,
        options: result.options,
        isRequired: result.isRequired,
        showOnCard: result.showOnCard,
        sortOrder:
            field?.sortOrder ??
            ((configuration.fields.isEmpty
                    ? 0
                    : configuration.fields
                          .map((item) => item.sortOrder)
                          .reduce((a, b) => a > b ? a : b)) +
                10),
      );
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleField(RecruitmentCustomField field) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await RecruitmentRepository.setCustomFieldActive(
        companyId: widget.profile.activeCompanyId,
        fieldId: field.id,
        active: !field.isActive,
      );
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> moveField(
    RecruitmentCrmConfiguration configuration,
    RecruitmentCustomField field,
    int direction,
  ) async {
    final active = configuration.fields.where((item) => item.isActive).toList();
    final index = active.indexWhere((item) => item.id == field.id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= active.length || busy) return;
    final moved = List<RecruitmentCustomField>.from(active);
    final item = moved.removeAt(index);
    moved.insert(target, item);
    setState(() => busy = true);
    try {
      await RecruitmentRepository.reorderCustomFields(
        companyId: widget.profile.activeCompanyId,
        orderedIds: moved.map((item) => item.id).toList(),
      );
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Настройка CRM',
      subtitle: 'Колонки, поля карточки и автоматические действия',
      showBackButton: true,
      onRefresh: refresh,
      child: FutureBuilder<RecruitmentCrmConfiguration>(
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
            return _SettingsMessage(
              icon: Icons.error_outline_rounded,
              title: 'Не удалось загрузить настройки',
              text: snapshot.error.toString(),
              onPressed: refresh,
            );
          }
          final configuration =
              snapshot.data ?? RecruitmentCrmConfiguration.empty;
          return DefaultTabController(
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumWorkCard(
                  padding: const EdgeInsets.all(AppUi.gap8),
                  child: const TabBar(
                    tabs: [
                      Tab(
                        icon: Icon(Icons.view_kanban_outlined),
                        text: 'Колонки',
                      ),
                      Tab(
                        icon: Icon(Icons.tune_rounded),
                        text: 'Поля карточки',
                      ),
                      Tab(
                        icon: Icon(Icons.bolt_rounded),
                        text: 'Автоматизация',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppUi.gap16),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.68,
                  child: TabBarView(
                    children: [
                      _stagesTab(configuration),
                      _fieldsTab(configuration),
                      RecruitmentAutomationSettingsPanel(
                        profile: widget.profile,
                        configuration: configuration,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stagesTab(RecruitmentCrmConfiguration configuration) {
    final active = configuration.stages.where((item) => item.isActive).toList();
    final archived = configuration.stages
        .where((item) => !item.isActive)
        .toList();
    return ListView(
      children: [
        _intro(
          title: 'Воронка найма',
          text:
              'Новые колонки добавляются справа. Для изменения порядка '
              'зажмите значок с полосками и перетащите колонку.',
          button: FilledButton.icon(
            onPressed: busy ? null : () => editStage(configuration),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить колонку'),
          ),
        ),
        const SizedBox(height: AppUi.gap12),
        if (active.isEmpty)
          const _SettingsMessage(
            icon: Icons.view_column_outlined,
            title: 'Активных колонок пока нет',
            text: 'Добавьте первую колонку воронки.',
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: active.length,
            onReorder: (oldIndex, newIndex) =>
                reorderStages(configuration, oldIndex, newIndex),
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: 12,
              borderRadius: BorderRadius.circular(AppUi.cardRadius),
              child: child,
            ),
            itemBuilder: (context, index) => KeyedSubtree(
              key: ValueKey<String>('stage:${active[index].id}'),
              child: _stageCard(
                configuration,
                active[index],
                index: index,
              ),
            ),
          ),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: AppUi.gap16),
          _sectionLabel('Скрытые колонки'),
          ...archived.map(
            (stage) => _stageCard(
              configuration,
              stage,
              index: -1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _fieldsTab(RecruitmentCrmConfiguration configuration) {
    final active = configuration.fields.where((item) => item.isActive).toList();
    final archived = configuration.fields
        .where((item) => !item.isActive)
        .toList();
    return ListView(
      children: [
        _intro(
          title: 'Поля кандидата',
          text:
              'Добавляйте строки, числа, суммы, телефоны, даты, флаги и списки. Поле можно сделать обязательным и вывести прямо на карточку канбана.',
          button: FilledButton.icon(
            onPressed: busy ? null : () => editField(configuration),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить поле'),
          ),
        ),
        const SizedBox(height: AppUi.gap12),
        if (active.isEmpty)
          const _SettingsMessage(
            icon: Icons.tune_rounded,
            title: 'Дополнительных полей пока нет',
            text: 'Создайте первое поле для карточки кандидата.',
          )
        else
          ...active.asMap().entries.map(
            (entry) => _fieldCard(
              configuration,
              entry.value,
              canMoveUp: entry.key > 0,
              canMoveDown: entry.key < active.length - 1,
            ),
          ),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: AppUi.gap16),
          _sectionLabel('Скрытые поля'),
          ...archived.map(
            (field) => _fieldCard(
              configuration,
              field,
              canMoveUp: false,
              canMoveDown: false,
            ),
          ),
        ],
      ],
    );
  }

  Widget _intro({
    required String title,
    required String text,
    required Widget button,
  }) {
    return PremiumWorkCard(
      padding: const EdgeInsets.all(AppUi.cardPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppAdaptivePalette.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppUi.gap4),
              Text(
                text,
                style: TextStyle(
                  color: AppAdaptivePalette.textMuted,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: AppUi.gap12),
                button,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: AppUi.gap16),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _stageCard(
    RecruitmentCrmConfiguration configuration,
    RecruitmentPipelineStage stage, {
    required int index,
  }) {
    final color = _hexColor(stage.colorHex);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppUi.gap8),
      child: PremiumWorkCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stage.isActive)
              ReorderableDragStartListener(
                index: index,
                enabled: !busy,
                child: Tooltip(
                  message: 'Перетащить колонку',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 10, 10, 10),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppAdaptivePalette.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppUi.controlRadius),
              ),
              child: Icon(Icons.view_column_outlined, color: color),
            ),
            const SizedBox(width: AppUi.gap12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (stage.description.isNotEmpty) ...[
                    const SizedBox(height: AppUi.gap4),
                    Text(
                      stage.description,
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppUi.gap8),
                  Wrap(
                    spacing: AppUi.gap8,
                    runSpacing: AppUi.gap8,
                    children: [
                      if (stage.systemKey.isNotEmpty)
                        const _MiniLabel('Системная колонка'),
                      if (stage.isFinal) const _MiniLabel('Финальная'),
                      if (!stage.isActive) const _MiniLabel('Скрыта'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppUi.gap8),
            PopupMenuButton<String>(
              enabled: !busy,
              onSelected: (value) {
                if (value == 'edit') editStage(configuration, stage);
                if (value == 'toggle') toggleStage(stage);
                if (value == 'delete') deleteStage(configuration, stage);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(stage.isActive ? 'Скрыть' : 'Восстановить'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldCard(
    RecruitmentCrmConfiguration configuration,
    RecruitmentCustomField field, {
    required bool canMoveUp,
    required bool canMoveDown,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppUi.gap8),
      child: PremiumWorkCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppAdaptivePalette.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppUi.controlRadius),
              ),
              child: Icon(
                _fieldIcon(field.fieldType),
                color: AppAdaptivePalette.accent,
              ),
            ),
            const SizedBox(width: AppUi.gap12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.title,
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppUi.gap4),
                  Text(
                    field.typeTitle,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (field.description.isNotEmpty) ...[
                    const SizedBox(height: AppUi.gap4),
                    Text(
                      field.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (field.options.isNotEmpty) ...[
                    const SizedBox(height: AppUi.gap4),
                    Text(
                      field.options.join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppUi.gap8),
                  Wrap(
                    spacing: AppUi.gap8,
                    runSpacing: AppUi.gap8,
                    children: [
                      if (field.isRequired) const _MiniLabel('Обязательное'),
                      if (field.showOnCard) const _MiniLabel('На карточке'),
                      if (!field.isActive) const _MiniLabel('Скрыто'),
                    ],
                  ),
                ],
              ),
            ),
            if (field.isActive) ...[
              IconButton(
                tooltip: 'Выше',
                onPressed: busy || !canMoveUp
                    ? null
                    : () => moveField(configuration, field, -1),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: 'Ниже',
                onPressed: busy || !canMoveDown
                    ? null
                    : () => moveField(configuration, field, 1),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ],
            PopupMenuButton<String>(
              enabled: !busy,
              onSelected: (value) {
                if (value == 'edit') editField(configuration, field);
                if (value == 'toggle') toggleField(field);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(field.isActive ? 'Скрыть' : 'Восстановить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppUi.gap8),
    child: Text(
      text,
      style: TextStyle(
        color: AppAdaptivePalette.textMuted,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _StageEditor extends StatefulWidget {
  final RecruitmentPipelineStage? stage;

  const _StageEditor({this.stage});

  @override
  State<_StageEditor> createState() => _StageEditorState();
}

class _StageEditorState extends State<_StageEditor> {
  static const colors = <String>[
    '#2F80ED',
    '#4C6076',
    '#2E8B57',
    '#C48718',
    '#C04B45',
    '#6C5B7B',
    '#6B7280',
    '#111827',
  ];

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late String colorHex;
  late bool isFinal;
  String? error;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.stage?.title ?? '');
    descriptionController = TextEditingController(
      text: widget.stage?.description ?? '',
    );
    colorHex = widget.stage?.colorHex ?? colors.first;
    isFinal = widget.stage?.isFinal ?? false;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void submit() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() => error = 'Укажите название колонки');
      return;
    }
    Navigator.pop(
      context,
      _StageDraft(
        title: title,
        description: descriptionController.text.trim(),
        colorHex: colorHex,
        isFinal: isFinal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorShell(
      title: widget.stage == null ? 'Новая колонка' : 'Изменить колонку',
      onSave: submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleController,
            autofocus: widget.stage == null,
            decoration: const InputDecoration(
              labelText: 'Название',
              prefixIcon: Icon(Icons.view_column_outlined),
            ),
          ),
          const SizedBox(height: AppUi.gap12),
          TextField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Описание',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: AppUi.gap16),
          Text(
            'Цвет колонки',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppUi.gap8),
          Wrap(
            spacing: AppUi.gap8,
            runSpacing: AppUi.gap8,
            children: colors
                .map(
                  (value) => InkWell(
                    onTap: () => setState(() => colorHex = value),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _hexColor(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorHex == value
                              ? AppAdaptivePalette.textPrimary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: colorHex == value
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppUi.gap12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Финальная колонка'),
            subtitle: const Text('Например: оформлен, резерв или отказ'),
            value: isFinal,
            onChanged: (value) => setState(() => isFinal = value),
          ),
          if (error != null) _EditorError(error!),
        ],
      ),
    );
  }
}

class _FieldEditor extends StatefulWidget {
  final RecruitmentCustomField? field;

  const _FieldEditor({this.field});

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController optionsController;
  late String fieldType;
  late bool isRequired;
  late bool showOnCard;
  String? error;

  bool get supportsOptions =>
      fieldType == 'select' || fieldType == 'multiselect';

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.field?.title ?? '');
    descriptionController = TextEditingController(
      text: widget.field?.description ?? '',
    );
    optionsController = TextEditingController(
      text: widget.field?.options.join('\n') ?? '',
    );
    fieldType = widget.field?.fieldType ?? 'text';
    isRequired = widget.field?.isRequired ?? false;
    showOnCard = widget.field?.showOnCard ?? false;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    optionsController.dispose();
    super.dispose();
  }

  void submit() {
    final title = titleController.text.trim();
    final options = optionsController.text
        .split(RegExp(r'[\n,;]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (title.isEmpty) {
      setState(() => error = 'Укажите название поля');
      return;
    }
    if (supportsOptions && options.isEmpty) {
      setState(() => error = 'Добавьте хотя бы один вариант списка');
      return;
    }
    Navigator.pop(
      context,
      _FieldDraft(
        title: title,
        description: descriptionController.text.trim(),
        fieldType: fieldType,
        options: supportsOptions ? options : const <String>[],
        isRequired: isRequired,
        showOnCard: showOnCard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorShell(
      title: widget.field == null ? 'Новое поле' : 'Изменить поле',
      onSave: submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleController,
            autofocus: widget.field == null,
            decoration: const InputDecoration(
              labelText: 'Название поля',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
          ),
          const SizedBox(height: AppUi.gap12),
          TextField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Описание / подсказка',
              hintText: 'Что именно HR должен указать в этом поле',
              prefixIcon: Icon(Icons.info_outline_rounded),
            ),
          ),
          const SizedBox(height: AppUi.gap12),
          DropdownButtonFormField<String>(
            initialValue: fieldType,
            decoration: const InputDecoration(
              labelText: 'Тип поля',
              prefixIcon: Icon(Icons.data_object_rounded),
            ),
            items: recruitmentCustomFieldTypes
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(recruitmentCustomFieldTypeTitle(type)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => fieldType = value ?? 'text'),
          ),
          if (supportsOptions) ...[
            const SizedBox(height: AppUi.gap12),
            TextField(
              controller: optionsController,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Варианты списка',
                hintText: 'Каждый вариант с новой строки',
                prefixIcon: Icon(Icons.format_list_bulleted_rounded),
              ),
            ),
          ],
          const SizedBox(height: AppUi.gap8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Обязательное поле'),
            subtitle: const Text(
              'HR не сможет сохранить карточку без значения',
            ),
            value: isRequired,
            onChanged: (value) => setState(() => isRequired = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Показывать на карточке'),
            subtitle: const Text('Значение будет видно прямо в канбане'),
            value: showOnCard,
            onChanged: (value) => setState(() => showOnCard = value),
          ),
          if (error != null) _EditorError(error!),
        ],
      ),
    );
  }
}

class _EditorShell extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onSave;

  const _EditorShell({
    required this.title,
    required this.child,
    required this.onSave,
  });

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
                  title,
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppUi.gap8),
          Flexible(child: SingleChildScrollView(child: child)),
          const SizedBox(height: AppUi.gap16),
          SizedBox(
            width: double.infinity,
            height: AppUi.controlHeight,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Future<void> Function()? onPressed;

  const _SettingsMessage({
    required this.icon,
    required this.title,
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppAdaptivePalette.textMuted),
          const SizedBox(height: AppUi.gap8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppUi.gap4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppAdaptivePalette.textMuted, height: 1.35),
          ),
          if (onPressed != null) ...[
            const SizedBox(height: AppUi.gap12),
            FilledButton(onPressed: onPressed, child: const Text('Повторить')),
          ],
        ],
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String text;

  const _MiniLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppAdaptivePalette.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EditorError extends StatelessWidget {
  final String text;

  const _EditorError(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppUi.gap8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppAdaptivePalette.danger,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StageDraft {
  final String title;
  final String description;
  final String colorHex;
  final bool isFinal;

  const _StageDraft({
    required this.title,
    required this.description,
    required this.colorHex,
    required this.isFinal,
  });
}

class _FieldDraft {
  final String title;
  final String description;
  final String fieldType;
  final List<String> options;
  final bool isRequired;
  final bool showOnCard;

  const _FieldDraft({
    required this.title,
    required this.description,
    required this.fieldType,
    required this.options,
    required this.isRequired,
    required this.showOnCard,
  });
}

Color _hexColor(String value) {
  final clean = value.replaceFirst('#', '');
  final parsed = int.tryParse(clean, radix: 16) ?? 0x2F80ED;
  return Color(0xFF000000 | parsed);
}

IconData _fieldIcon(String type) {
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
    case 'date':
      return Icons.event_outlined;
    case 'boolean':
      return Icons.toggle_on_outlined;
    case 'select':
    case 'multiselect':
      return Icons.format_list_bulleted_rounded;
    default:
      return Icons.short_text_rounded;
  }
}
