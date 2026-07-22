import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../actions/ai_action_execution_coordinator.dart';
import '../data/ai_assistant_repository.dart';
import '../models/ai_assistant_result.dart';
import 'widgets/ai_operational_prompt_chips.dart';

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
  final List<_ConversationEntry> entries = <_ConversationEntry>[];
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

    setState(() {
      isSending = true;
      entries.add(_ConversationEntry.user(prompt));
    });
    scrollToBottom();

    try {
      final result = await AiAssistantRepository.request(
        mode: 'chat',
        companyId: widget.profile.activeCompanyId,
        objectName: effectiveObjectName,
        prompt: prompt,
      );
      if (!mounted) return;
      setState(() => entries.add(_ConversationEntry.result(result)));
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        entries.add(
          _ConversationEntry.error(
            text.isEmpty ? 'Не удалось получить результат' : text,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => isSending = false);
      scrollToBottom();
    }
  }

  Future<void> runAction(int index, AiAssistantAction action) async {
    if (runningActionIds.contains(action.id) ||
        completedActionIds.contains(action.id)) {
      return;
    }

    setState(() => runningActionIds.add(action.id));
    try {
      final result = await AiActionExecutionCoordinator.execute(
        context: context,
        profile: widget.profile,
        action: action,
      );
      if (!mounted) return;
      if (result.completed) {
        setState(() {
          completedActionIds.add(action.id);
          if (index >= 0 && index < entries.length) {
            entries[index].reviewed = true;
          }
        });
      }
      showMessage(result.message);
    } catch (error) {
      if (!mounted) return;
      showMessage(
        'Действие не выполнено: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => runningActionIds.remove(action.id));
    }
  }

  void markReviewed(int index) {
    if (index < 0 || index >= entries.length) return;
    setState(() => entries[index].reviewed = true);
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  String completedLabel(AiAssistantAction action) {
    return switch (action.type) {
      'create_task_draft' => 'Задача создана',
      'prepare_document' => 'Документ скачан',
      'prepare_timesheet_correction' => 'Табель обновлён',
      'prepare_employee_update' => 'Сотрудник обновлён',
      'create_reminder' => 'Напоминание создано',
      _ => 'Действие завершено',
    };
  }

  Widget buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
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
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colorScheme.onSurface,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Чем помочь?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Напиши вопрос по объекту, табелю, сотрудникам, задачам или документам. Область доступа: $scopeTitle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            AiOperationalPromptChips(
              enabled: !isSending,
              onSelected: (prompt) {
                promptController.text = prompt;
                sendPrompt();
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Помощник ничего не изменяет без твоего участия.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colorScheme.onPrimary,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget buildErrorMessage(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colorScheme.error,
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
          : Icon(
              completed ? Icons.verified_rounded : Icons.fact_check_outlined,
            ),
      label: Text(completed ? completedLabel(action) : action.buttonLabel),
    );
  }

  Widget buildResult(int index, _ConversationEntry entry) {
    final result = entry.result!;
    final colorScheme = Theme.of(context).colorScheme;
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
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            result.scopeLabel,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (result.summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            SelectableText(
              result.summary,
              style: TextStyle(
                color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
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
          PremiumWorkCard(
            radius: 22,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Помощник анализирует данные…',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
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
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter): () {
                  if (!isSending) sendPrompt();
                },
                const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
                  if (!isSending) sendPrompt();
                },
              },
              child: TextField(
                controller: promptController,
                enabled: !isSending,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Спроси о работе или попроси подготовить действие…',
                  helperText: 'Enter — отправить · Shift+Enter — новая строка',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
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
        leading: const BackButton(),
        title: const Text('ИИ-помощник'),
      ),
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

class _ConversationEntry {
  final String? userText;
  final AiAssistantResult? result;
  final String? errorText;
  bool reviewed;

  _ConversationEntry._({
    this.userText,
    this.result,
    this.errorText,
    this.reviewed = false,
  });

  factory _ConversationEntry.user(String text) =>
      _ConversationEntry._(userText: text);

  factory _ConversationEntry.result(AiAssistantResult result) =>
      _ConversationEntry._(result: result);

  factory _ConversationEntry.error(String text) =>
      _ConversationEntry._(errorText: text);
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    final color = warning ? colorScheme.error : colorScheme.onSurface;
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
