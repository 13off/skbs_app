import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/ai_assistant_repository.dart';
import '../models/ai_assistant_result.dart';

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

  Future<void> runPreset({
    required String mode,
    required String label,
    required String prompt,
  }) async {
    await submit(mode: mode, visiblePrompt: label, prompt: prompt);
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

  Widget buildIntro() {
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.textPrimary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Безопасный режим',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Помощник видит только данные активной компании и область «$scopeTitle». Сейчас он ничего не изменяет сам: сначала показывает предварительный результат, затем его проверяет человек.',
            style: const TextStyle(
              color: AppColors.textMuted,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildQuickActions() {
    const actions = <_AiQuickAction>[
      _AiQuickAction(
        mode: 'timesheet_check',
        title: 'Проверить табель',
        subtitle: 'Пропуски и необычные смены за сегодня',
        icon: Icons.fact_check_outlined,
        prompt: 'Проверь сегодняшний табель и покажи, что требует внимания.',
      ),
      _AiQuickAction(
        mode: 'site_summary',
        title: 'Сводка по объекту',
        subtitle: 'Люди, табель и задачи одним результатом',
        icon: Icons.analytics_outlined,
        prompt: 'Собери краткую рабочую сводку за сегодня.',
      ),
      _AiQuickAction(
        mode: 'document_draft',
        title: 'Подготовить документ',
        subtitle: 'Черновик служебного текста или акта',
        icon: Icons.description_outlined,
        prompt:
            'Подготовь нейтральный черновик служебной записки по текущей ситуации. Не придумывай отсутствующие факты и оставь места для уточнений.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Быстрые действия',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 680;
            final width = desktop
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actions.map((action) {
                return SizedBox(
                  width: width,
                  child: PremiumPressable(
                    onTap: isSending
                        ? null
                        : () => runPreset(
                            mode: action.mode,
                            label: action.title,
                            prompt: action.prompt,
                          ),
                    borderRadius: BorderRadius.circular(24),
                    child: PremiumWorkCard(
                      radius: 24,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            action.icon,
                            color: AppColors.textPrimary,
                            size: 28,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            action.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            action.subtitle,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            );
          },
        ),
      ],
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
          const SizedBox(height: 16),
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
    if (entries.isEmpty && !isSending) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Диалог',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('ИИ-помощник')),
      body: PremiumWorkBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
                children: [
                  AppPageHeader(
                    title: 'ИИ-помощник',
                    subtitle:
                        'Анализ работы, проверка данных и черновики документов',
                    trailing: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.textPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  buildIntro(),
                  const SizedBox(height: 24),
                  buildQuickActions(),
                  if (entries.isNotEmpty || isSending) ...[
                    const SizedBox(height: 24),
                    buildConversation(),
                  ],
                  const SizedBox(height: 12),
                  buildComposer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiQuickAction {
  final String mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final String prompt;

  const _AiQuickAction({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.prompt,
  });
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
          Icon(icon, size: 15, color: AppColors.textMuted),
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
    final foreground = warning
        ? const Color(0xFF874540)
        : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: foreground),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: foreground,
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
