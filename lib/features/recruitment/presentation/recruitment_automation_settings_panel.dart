import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_ui_tokens.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_crm_workspace_repository.dart';
import '../data/recruitment_repository.dart';
import '../models/recruitment_crm_workspace_models.dart';
import '../models/recruitment_models.dart';

class RecruitmentAutomationSettingsPanel extends StatefulWidget {
  final AppUserProfile profile;
  final RecruitmentCrmConfiguration configuration;

  const RecruitmentAutomationSettingsPanel({
    super.key,
    required this.profile,
    required this.configuration,
  });

  @override
  State<RecruitmentAutomationSettingsPanel> createState() =>
      _RecruitmentAutomationSettingsPanelState();
}

class _RecruitmentAutomationSettingsPanelState
    extends State<RecruitmentAutomationSettingsPanel> {
  late Future<_AutomationData> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_AutomationData> load() async {
    final results = await Future.wait<dynamic>([
      RecruitmentCrmWorkspaceRepository.fetchAutomationRules(
        companyId: widget.profile.activeCompanyId,
      ),
      RecruitmentCrmWorkspaceRepository.fetchResponsibles(),
      RecruitmentRepository.fetchConfiguration(
        companyId: widget.profile.activeCompanyId,
        includeInactive: false,
      ),
    ]);
    return _AutomationData(
      rules: results[0] as List<RecruitmentCrmAutomationRule>,
      responsibles: results[1] as List<RecruitmentResponsibleOption>,
      configuration: results[2] as RecruitmentCrmConfiguration,
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

  Future<void> editRule(
    _AutomationData data, [
    RecruitmentCrmAutomationRule? rule,
  ]) async {
    if (busy) return;
    setState(() => busy = true);
    late final RecruitmentCrmConfiguration liveConfiguration;
    try {
      liveConfiguration = await RecruitmentRepository.fetchConfiguration(
        companyId: widget.profile.activeCompanyId,
        includeInactive: false,
      );
    } catch (error) {
      showError(error);
      if (mounted) setState(() => busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => busy = false);
    final stages = liveConfiguration.stages
        .where((stage) => stage.isActive)
        .toList(growable: false);
    if (stages.isEmpty) {
      showError(Exception('Сначала добавьте колонку на канбан-доске'));
      return;
    }
    final draft = await showModalBottomSheet<_AutomationDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AutomationEditor(
        rule: rule,
        stages: stages,
        responsibles: data.responsibles,
      ),
    );
    if (draft == null) return;
    setState(() => busy = true);
    try {
      await RecruitmentCrmWorkspaceRepository.saveAutomationRule(
        id: rule?.id ?? '',
        companyId: widget.profile.activeCompanyId,
        triggerStageId: draft.stageId,
        title: draft.title,
        actionType: draft.actionType,
        taskTitle: draft.taskTitle,
        taskType: draft.taskType,
        taskPriority: draft.priority,
        dueOffsetHours: draft.dueOffsetHours,
        messageText: draft.messageText,
        assignedTo: draft.assignedTo,
        isActive: draft.isActive,
        sortOrder: rule?.sortOrder ?? (data.rules.length + 1) * 10,
      );
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleRule(
    _AutomationData data,
    RecruitmentCrmAutomationRule rule,
  ) async {
    setState(() => busy = true);
    try {
      await RecruitmentCrmWorkspaceRepository.saveAutomationRule(
        id: rule.id,
        companyId: widget.profile.activeCompanyId,
        triggerStageId: rule.triggerStageId,
        title: rule.title,
        actionType: rule.actionType,
        taskTitle: rule.taskTitle,
        taskType: rule.taskType,
        taskPriority: rule.taskPriority,
        dueOffsetHours: rule.dueOffsetHours,
        messageText: rule.messageText,
        assignedTo: rule.assignedTo,
        isActive: !rule.isActive,
        sortOrder: rule.sortOrder,
      );
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteRule(RecruitmentCrmAutomationRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить автоматизацию?'),
        content: Text(rule.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RecruitmentCrmWorkspaceRepository.deleteAutomationRule(
        companyId: widget.profile.activeCompanyId,
        id: rule.id,
      );
      await refresh();
    } catch (error) {
      showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AutomationData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Не удалось загрузить автоматизации: ${snapshot.error}',
            ),
          );
        }
        final data = snapshot.data ?? const _AutomationData();
        return ListView(
          children: [
            PremiumWorkCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Автоматические действия',
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppUi.gap8),
                  Text(
                    'При попадании кандидата в выбранную колонку AppСтрой может создать дело, отправить сообщение в Telegram или выполнить оба действия.',
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppUi.gap12),
                  FilledButton.icon(
                    onPressed: busy || data.configuration.stages.isEmpty
                        ? null
                        : () => editRule(data),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить автоматизацию'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUi.gap12),
            if (data.rules.isEmpty)
              PremiumWorkCard(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Автоматизаций пока нет. Начните, например, с создания дела «Запросить документы» при переходе в соответствующую колонку.',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ...data.rules.map(
                (rule) => Padding(
                  padding: const EdgeInsets.only(bottom: AppUi.gap8),
                  child: PremiumWorkCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          rule.isActive
                              ? Icons.bolt_rounded
                              : Icons.pause_circle_outline_rounded,
                          color: rule.isActive
                              ? AppAdaptivePalette.accent
                              : AppAdaptivePalette.textMuted,
                        ),
                        const SizedBox(width: AppUi.gap12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rule.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: AppUi.gap4),
                              Text(
                                'Колонка: ${data.configuration.stageById(rule.triggerStageId)?.title ?? 'Удалена'} · ${rule.actionTitle}',
                                style: TextStyle(
                                  color: AppAdaptivePalette.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (rule.taskTitle.isNotEmpty) ...[
                                const SizedBox(height: AppUi.gap4),
                                Text(
                                  'Дело: ${rule.taskTitle} · через ${rule.dueOffsetHours} ч.',
                                ),
                              ],
                              if (rule.messageText.isNotEmpty) ...[
                                const SizedBox(height: AppUi.gap4),
                                Text(
                                  'Сообщение: ${rule.messageText}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          enabled: !busy,
                          onSelected: (value) {
                            if (value == 'edit') editRule(data, rule);
                            if (value == 'toggle') toggleRule(data, rule);
                            if (value == 'delete') deleteRule(rule);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Изменить'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                rule.isActive ? 'Отключить' : 'Включить',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Удалить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AutomationData {
  final List<RecruitmentCrmAutomationRule> rules;
  final List<RecruitmentResponsibleOption> responsibles;
  final RecruitmentCrmConfiguration configuration;

  const _AutomationData({
    this.rules = const [],
    this.responsibles = const [],
    this.configuration = RecruitmentCrmConfiguration.empty,
  });
}

class _AutomationDraft {
  final String title;
  final String stageId;
  final String actionType;
  final String taskTitle;
  final String taskType;
  final String priority;
  final int dueOffsetHours;
  final String messageText;
  final String assignedTo;
  final bool isActive;

  const _AutomationDraft({
    required this.title,
    required this.stageId,
    required this.actionType,
    required this.taskTitle,
    required this.taskType,
    required this.priority,
    required this.dueOffsetHours,
    required this.messageText,
    required this.assignedTo,
    required this.isActive,
  });
}

class _AutomationEditor extends StatefulWidget {
  final RecruitmentCrmAutomationRule? rule;
  final List<RecruitmentPipelineStage> stages;
  final List<RecruitmentResponsibleOption> responsibles;

  const _AutomationEditor({
    this.rule,
    required this.stages,
    required this.responsibles,
  });

  @override
  State<_AutomationEditor> createState() => _AutomationEditorState();
}

class _AutomationEditorState extends State<_AutomationEditor> {
  late final TextEditingController titleController;
  late final TextEditingController taskTitleController;
  late final TextEditingController hoursController;
  late final TextEditingController messageController;
  late String stageId;
  late String actionType;
  late String taskType;
  late String priority;
  late String assignedTo;
  late bool isActive;
  String? error;

  bool get includesTask => actionType != 'send_message';
  bool get includesMessage => actionType != 'create_task';

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    titleController = TextEditingController(text: rule?.title ?? '');
    taskTitleController = TextEditingController(text: rule?.taskTitle ?? '');
    hoursController = TextEditingController(
      text: '${rule?.dueOffsetHours ?? 24}',
    );
    messageController = TextEditingController(text: rule?.messageText ?? '');
    final requestedStageId = rule?.triggerStageId ?? '';
    stageId = widget.stages.any((stage) => stage.id == requestedStageId)
        ? requestedStageId
        : (widget.stages.isEmpty ? '' : widget.stages.first.id);
    actionType = rule?.actionType ?? 'create_task';
    taskType = rule?.taskType ?? 'other';
    priority = rule?.taskPriority ?? 'normal';
    assignedTo = rule?.assignedTo ?? '';
    isActive = rule?.isActive ?? true;
  }

  @override
  void dispose() {
    titleController.dispose();
    taskTitleController.dispose();
    hoursController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void submit() {
    final title = titleController.text.trim();
    final hours = int.tryParse(hoursController.text.trim()) ?? -1;
    if (title.isEmpty || stageId.isEmpty) {
      setState(() => error = 'Укажите название и колонку');
      return;
    }
    if (includesTask && taskTitleController.text.trim().isEmpty) {
      setState(() => error = 'Укажите название создаваемого дела');
      return;
    }
    if (includesMessage && messageController.text.trim().isEmpty) {
      setState(() => error = 'Введите текст сообщения');
      return;
    }
    if (hours < 0 || hours > 8760) {
      setState(() => error = 'Срок должен быть от 0 до 8760 часов');
      return;
    }
    Navigator.pop(
      context,
      _AutomationDraft(
        title: title,
        stageId: stageId,
        actionType: actionType,
        taskTitle: taskTitleController.text.trim(),
        taskType: taskType,
        priority: priority,
        dueOffsetHours: hours,
        messageText: messageController.text.trim(),
        assignedTo: assignedTo,
        isActive: isActive,
      ),
    );
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.rule == null
                        ? 'Новая автоматизация'
                        : 'Изменить автоматизацию',
                    style: const TextStyle(
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
            const SizedBox(height: AppUi.gap12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Название правила',
                prefixIcon: Icon(Icons.bolt_rounded),
              ),
            ),
            const SizedBox(height: AppUi.gap12),
            DropdownButtonFormField<String>(
              initialValue: stageId,
              decoration: const InputDecoration(
                labelText: 'Когда кандидат попал в колонку',
                prefixIcon: Icon(Icons.view_column_outlined),
              ),
              items: widget.stages
                  .map(
                    (stage) => DropdownMenuItem(
                      value: stage.id,
                      child: Text(stage.title),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => stageId = value ?? stageId),
            ),
            const SizedBox(height: AppUi.gap12),
            DropdownButtonFormField<String>(
              initialValue: actionType,
              decoration: const InputDecoration(
                labelText: 'Действие',
                prefixIcon: Icon(Icons.playlist_add_check_rounded),
              ),
              items: recruitmentAutomationActionTypes
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(recruitmentAutomationActionTitle(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => actionType = value ?? actionType),
            ),
            if (includesTask) ...[
              const SizedBox(height: AppUi.gap12),
              TextField(
                controller: taskTitleController,
                decoration: const InputDecoration(
                  labelText: 'Название дела',
                  prefixIcon: Icon(Icons.task_alt_rounded),
                ),
              ),
              const SizedBox(height: AppUi.gap12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: taskType,
                      decoration: const InputDecoration(labelText: 'Тип дела'),
                      items: recruitmentCrmTaskTypes
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(recruitmentCrmTaskTypeTitle(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => taskType = value ?? taskType),
                    ),
                  ),
                  const SizedBox(width: AppUi.gap12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Приоритет'),
                      items: recruitmentCrmPriorities
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(recruitmentCrmPriorityTitle(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => priority = value ?? priority),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppUi.gap12),
              TextField(
                controller: hoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Срок через, часов',
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
              ),
              const SizedBox(height: AppUi.gap12),
              DropdownButtonFormField<String>(
                initialValue:
                    widget.responsibles.any((item) => item.userId == assignedTo)
                    ? assignedTo
                    : '',
                decoration: const InputDecoration(
                  labelText: 'Исполнитель',
                  prefixIcon: Icon(Icons.support_agent_rounded),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Ответственный кандидата / любой HR'),
                  ),
                  ...widget.responsibles.map(
                    (item) => DropdownMenuItem(
                      value: item.userId,
                      child: Text(item.fullName),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => assignedTo = value ?? ''),
              ),
            ],
            if (includesMessage) ...[
              const SizedBox(height: AppUi.gap12),
              TextField(
                controller: messageController,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Сообщение кандидату',
                  helperText:
                      'Доступные подстановки: {name}, {vacancy}, {object}',
                  prefixIcon: Icon(Icons.telegram),
                ),
              ),
            ],
            const SizedBox(height: AppUi.gap8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: isActive,
              onChanged: (value) => setState(() => isActive = value),
              title: const Text('Правило включено'),
            ),
            if (error != null)
              Text(error!, style: TextStyle(color: AppAdaptivePalette.danger)),
            const SizedBox(height: AppUi.gap16),
            FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить автоматизацию'),
            ),
          ],
        ),
      ),
    );
  }
}
