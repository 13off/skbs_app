import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../data/task_repository.dart';
import '../../../features/developer/data/developer_policy_repository.dart';
import '../../../features/tasks/task_edit_policy.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/add_task_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../data/ai_assistant_repository.dart';
import '../models/ai_assistant_result.dart';
import 'ai_document_draft_screen.dart';

class AiAssistantScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const AiAssistantScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController promptController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final List<_AiConversationEntry> entries = <_AiConversationEntry>[];
  final Set<String> runningActionIds = <String>{};
  final Set<String> completedActionIds = <String>{};

  bool isSending = false;

  String? get effectiveObjectName {
    final selected = widget.selectedObjectName?.trim() ?? '';
    if (selected.isNotEmpty) return selected;
    final assigned = widget.profile.objectName.trim();
    return assigned.isEmpty ? null : assigned;
  }

  String get scopeTitle => effectiveObjectName ?? 'Все доступные объекты';

  @override
  void dispose() {
    promptController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> sendPrompt() async {
    final prompt = promptController.text.trim();
    if (prompt.isEmpty || isSending) return;
    promptController.clear();
    await submit(mode: 'chat', visiblePrompt: prompt, prompt: prompt);
  }

  Future<void> submit({
    required String mode,
    required String visiblePrompt,
    required String prompt,
  }) async {
    if (isSending) return;

    setState(() {
      isSending = true;
      entries.add(_AiConversationEntry.user(visiblePrompt));
    });
    scrollToBottom();

    try {
      final result = await AiAssistantRepository.request(
        mode: mode,
        companyId: widget.profile.activeCompanyId,
        objectName: effectiveObjectName,
        prompt: prompt,
      );
      if (!mounted) return;
      setState(() => entries.add(_AiConversationEntry.result(result)));
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        entries.add(
          _AiConversationEntry.error(
            text.isEmpty ? 'Не удалось получить результат' : text,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => isSending = false);
      scrollToBottom();
    }
  }

  void markReviewed(int index) {
    if (index < 0 || index >= entries.length) return;
    setState(() => entries[index].reviewed = true);
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> runAction(int index, AiAssistantAction action) async {
    switch (action.type) {
      case 'create_task_draft':
        await openTaskDraft(index, action);
        return;
      case 'prepare_document':
        await openDocumentDraft(index, action);
        return;
      default:
        showMessage(
          'Это действие пока доступно только для предварительного просмотра',
        );
    }
  }

  Future<void> openDocumentDraft(
    int index,
    AiAssistantAction action,
  ) async {
    if (runningActionIds.contains(action.id) ||
        completedActionIds.contains(action.id)) {
      return;
    }

    setState(() => runningActionIds.add(action.id));
    try {
      final completed = await Navigator.of(context).push<bool>(
        CupertinoPageRoute<bool>(
          builder: (_) => AiDocumentDraftScreen(
            profile: widget.profile,
            action: action,
          ),
        ),
      );
      if (!mounted || completed != true) return;
      setState(() {
        completedActionIds.add(action.id);
        if (index >= 0 && index < entries.length) {
          entries[index].reviewed = true;
        }
      });
      showMessage('Документ проверен и скачан');
    } finally {
      if (mounted) setState(() => runningActionIds.remove(action.id));
    }
  }

  Future<void> openTaskDraft(int index, AiAssistantAction action) async {
    if (runningActionIds.contains(action.id) ||
        completedActionIds.contains(action.id)) {
      return;
    }

    final objectName = action.text('object_name');
    if (objectName.isEmpty) {
      showMessage('Для задачи нужно выбрать конкретный объект');
      return;
    }
    final taskDate = action.date('date') ?? DateTime.now();

    setState(() => runningActionIds.add(action.id));
    try {
      await DeveloperPolicyRepository.ensurePolicy(objectName);
      if (!TaskEditPolicy.canCreateForDate(
        widget.profile,
        taskDate,
        objectName: objectName,
      )) {
        showMessage('Для этой даты у текущей роли нет права создавать задачу');
        return;
      }

      final draft = await Navigator.of(context).push<TaskCreateDraft>(
        CupertinoPageRoute<TaskCreateDraft>(
          builder: (_) => AddTaskScreen(
            initialDate: taskDate,
            objectName: objectName,
            initialAxes: action.text('axes'),
            initialWork: action.text('work'),
            initialAssigneeIds: action.stringList('assignee_ids'),
            initialRequireBeforePhoto: action.boolean(
              'require_before_photo',
            ),
            allowAnyDate:
                widget.profile.isAdmin ||
                TaskEditPolicy.forObject(objectName).foremanCanCreateAnyDate,
          ),
        ),
      );
      if (draft == null) return;

      final createdTask = await TaskRepository.addTaskWithDetails(
        draft.task,
        objectName: objectName,
        assigneeIds: draft.assigneeIds,
        photos: draft.photos,
      );
      if (!mounted) return;

      setState(() {
        completedActionIds.add(action.id);
        if (index >= 0 && index < entries.length) {
          entries[index].reviewed = true;
        }
      });
      showMessage('Задача «${createdTask.work}» создана');
    } catch (error) {
      if (!mounted) return;
      showMessage(
        'Не удалось создать задачу: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => runningActionIds.remove(action.id));
    }
  }

  String completedActionLabel(AiAssistantAction action) {
    return switch (action.type) {
      'create_task_draft' => 'Задача создана',
      'prepare_document' => 'Документ скачан',
      _ => 'Действие завершено',
    };
  }

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.textPrimary,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Чем помочь?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Напиши вопрос по объекту, табелю, сотрудникам, задачам или документам. Область доступа: $scopeTitle.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Помощник ничего не изменяет без твоего участия.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildUserMessage(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget buildErrorMessage(String text) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFF874540)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF874540),
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActionButton(int index, AiAssistantAction action) {
    final running = runningActionIds.contains(action.id);
    final completed = completedActionIds.contains(action.id);
    return FilledButton.icon(
      onPressed: running || completed ? null : () => runAction(index, action),
      icon: running
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(completed ? Icons.verified_rounded : Icons.edit_note_rounded),
      label: Text(
        completed ? completedActionLabel(action) : action.buttonLabel,
      ),
    );
  }

  Widget buildResult(int index, _AiConversationEntry entry) {
    final result = entry.result!;

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: result.aiUsed
                    ? Icons.auto_awesome_outlined
                    : Icons.rule_outlined,
                label: result.aiUsed ? 'Ответ ИИ' : 'Серверная проверка',
              ),
              if (result.preliminary)
                const _StatusPill(
                  icon: Icons.visibility_outlined,
                  label: 'Предварительный результат',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            result.scopeLabel,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (result.summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            SelectableText(
              result.summary,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (result.highlights.isNotEmpty)
            _ResultSection(
              title: 'Главное',
              icon: Icons.check_circle_outline,
              items: result.highlights,
            ),
          if (result.warnings.isNotEmpty)
            _ResultSection(
              title: 'Требует внимания',
              icon: Icons.warning_amber_rounded,
              items: result.warnings,
              warning: true,
            ),
          if (result.nextSteps.isNotEmpty)
            _ResultSection(
              title: 'Следующие шаги',
              icon: Icons.arrow_forward_rounded,
              items: result.nextSteps,
            ),
          if (result.action != null) ...[
            const SizedBox(height: 16),
            buildActionButton(index, result.action!),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: entry.reviewed ? null : () => markReviewed(index),
            icon: Icon(
              entry.reviewed
                  ? Icons.verified_rounded
                  : Icons.fact_check_outlined,
            ),
            label: Text(
              entry.reviewed
                  ? 'Проверено человеком'
                  : 'Отметить как проверенное',
            ),
          ),
        ],
      ),
    );
  }

  Widget buildConversation() {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (entries[index].userText != null)
            buildUserMessage(entries[index].userText!)
          else if (entries[index].result != null)
            buildResult(index, entries[index])
          else
            buildErrorMessage(entries[index].errorText!),
          const SizedBox(height: 12),
        ],
        if (isSending)
          const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Помощник анализирует данные…',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget buildComposer() {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: promptController,
              enabled: !isSending,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Спроси о работе или попроси подготовить черновик…',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isSending ? null : sendPrompt,
            tooltip: 'Отправить',
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasConversation = entries.isNotEmpty || isSending;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),title: const Text('ИИ-помощник')),
      body: PremiumWorkBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  Expanded(
                    child: hasConversation
                        ? buildConversation()
                        : buildEmptyState(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    child: buildComposer(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiConversationEntry {
  final String? userText;
  final AiAssistantResult? result;
  final String? errorText;
  bool reviewed;

  _AiConversationEntry._({
    this.userText,
    this.result,
    this.errorText,
    this.reviewed = false,
  });

  factory _AiConversationEntry.user(String text) {
    return _AiConversationEntry._(userText: text);
  }

  factory _AiConversationEntry.result(AiAssistantResult result) {
    return _AiConversationEntry._(result: result);
  }

  factory _AiConversationEntry.error(String text) {
    return _AiConversationEntry._(errorText: text);
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final bool warning;

  const _ResultSection({
    required this.title,
    required this.icon,
    required this.items,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFF874540) : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: color,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
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
