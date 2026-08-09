import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/employee_repository.dart';
import '../../../data/object_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../navigation/web_back_navigation.dart';
import '../../ai/actions/ai_action_execution_coordinator.dart';
import '../../ai/data/ai_assistant_repository.dart';
import '../../ai/models/ai_assistant_result.dart';
import '../app_voice_dictionary.dart';
import '../app_voice_recognition.dart';

class GlobalVoiceAssistantLayer extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const GlobalVoiceAssistantLayer({
    super.key,
    required this.profile,
    required this.child,
  });

  @override
  State<GlobalVoiceAssistantLayer> createState() =>
      _GlobalVoiceAssistantLayerState();
}

class _GlobalVoiceAssistantLayerState extends State<GlobalVoiceAssistantLayer> {
  bool isPreparing = false;
  bool isListening = false;
  bool isProcessing = false;
  bool isResultOpen = false;
  String liveTranscript = '';

  bool get canExecuteActions =>
      !widget.profile.isRolePreview && !widget.profile.isEmployee;

  String? get effectiveObjectName {
    final value = widget.profile.objectName.trim();
    return value.isEmpty ? null : value;
  }

  BuildContext? get navigationContext =>
      appNavigatorKey.currentState?.overlay?.context;

  @override
  void dispose() {
    if (isListening) unawaited(stopAppVoiceRecognition());
    super.dispose();
  }

  Future<void> toggleVoice() async {
    if (isProcessing || isPreparing || isResultOpen) return;
    if (isListening) {
      await stopAppVoiceRecognition();
      return;
    }
    await startVoice();
  }

  Future<List<String>> loadHints() async {
    final employeeNames = <String>[];
    final objectNames = <String>[];

    if (!widget.profile.isEmployee) {
      try {
        final employees = await EmployeeRepository.fetchEmployees(
          objectName: widget.profile.isForeman ? effectiveObjectName : null,
          includeFired: false,
        );
        employeeNames.addAll(
          employees
              .map((employee) => employee.name.trim())
              .where((name) => name.isNotEmpty),
        );
      } catch (_) {
        // Живые ФИО улучшают распознавание, но их отсутствие не должно
        // блокировать голосового помощника.
      }

      try {
        objectNames.addAll(await ObjectRepository.fetchObjectNames());
      } catch (_) {
        // То же правило для названий объектов.
      }
    }

    return buildAppVoiceHints(
      profile: widget.profile,
      employeeNames: employeeNames,
      objectNames: objectNames,
    );
  }

  Future<void> startVoice() async {
    if (isListening || isPreparing || isProcessing || isResultOpen) return;
    setState(() {
      isPreparing = true;
      liveTranscript = '';
    });

    try {
      final hints = await loadHints();
      if (!mounted) return;
      setState(() {
        isPreparing = false;
        isListening = true;
      });

      final transcript = await recognizeAppVoice(
        hints: hints,
        onPartial: (text) {
          if (!mounted) return;
          setState(() => liveTranscript = text.trim());
          if (_hasStopCommand(text)) {
            unawaited(stopAppVoiceRecognition());
          }
        },
      );
      if (!mounted) return;
      final clean = _cleanTranscript(transcript);
      setState(() {
        isListening = false;
        liveTranscript = clean;
      });
      if (clean.isNotEmpty) await processTranscript(clean);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isPreparing = false;
        isListening = false;
      });
      showMessage(_cleanError(error));
    } finally {
      if (mounted && isPreparing) setState(() => isPreparing = false);
    }
  }

  Future<void> processTranscript(String transcript) async {
    if (isProcessing || transcript.trim().isEmpty) return;
    setState(() => isProcessing = true);
    try {
      final result = await AiAssistantRepository.request(
        mode: 'chat',
        companyId: widget.profile.activeCompanyId,
        objectName: effectiveObjectName,
        prompt: transcript.trim(),
      );
      if (!mounted) return;
      await showResult(transcript.trim(), result);
    } catch (error) {
      if (!mounted) return;
      showMessage(_cleanError(error));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<void> runAction(AiAssistantAction action) async {
    if (!canExecuteActions) {
      showMessage(
        widget.profile.isRolePreview
            ? 'В режиме просмотра роли голосовые изменения отключены.'
            : 'Для сотрудника голосовые изменения пока доступны только в личных сценариях.',
      );
      return;
    }

    final targetContext = navigationContext;
    if (targetContext == null) {
      showMessage('Не удалось открыть проверку действия. Повторите команду.');
      return;
    }

    try {
      final result = await AiActionExecutionCoordinator.execute(
        context: targetContext,
        profile: widget.profile,
        action: action,
      );
      if (!mounted) return;
      showMessage(result.message);
    } catch (error) {
      if (!mounted) return;
      showMessage('Действие не выполнено: ${_cleanError(error)}');
    }
  }

  Future<void> showResult(String transcript, AiAssistantResult result) async {
    final targetContext = navigationContext;
    if (targetContext == null) {
      showMessage('Не удалось открыть результат голосового помощника.');
      return;
    }

    final action = result.action;
    setState(() => isResultOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: targetContext,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final colors = Theme.of(sheetContext).colorScheme;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.mic_rounded, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Голосовой помощник AppСтрой',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _VoiceSection(
                    title: 'Распознано',
                    child: SelectableText(
                      transcript,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    result.title,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    result.scopeLabel,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (result.summary.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SelectableText(
                      result.summary,
                      style: TextStyle(
                        color: colors.onSurface,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (result.highlights.isNotEmpty)
                    _VoiceListSection(
                      title: 'Главное',
                      items: result.highlights,
                    ),
                  if (result.warnings.isNotEmpty)
                    _VoiceListSection(
                      title: 'Требует внимания',
                      items: result.warnings,
                      warning: true,
                    ),
                  if (result.nextSteps.isNotEmpty)
                    _VoiceListSection(
                      title: 'Следующие шаги',
                      items: result.nextSteps,
                    ),
                  if (action != null) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: canExecuteActions
                          ? () {
                              Navigator.of(sheetContext).pop();
                              unawaited(runAction(action));
                            }
                          : null,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(action.buttonLabel),
                    ),
                    if (!canExecuteActions) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.profile.isRolePreview
                            ? 'Просмотр роли: изменение показано только для проверки.'
                            : 'Для сотрудника этот тип изменения пока недоступен голосом.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => isResultOpen = false);
    }
  }

  void showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;
    final targetContext = navigationContext ?? context;
    ScaffoldMessenger.maybeOf(targetContext)?.showSnackBar(
      SnackBar(content: Text(message.trim())),
    );
  }

  String _cleanError(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '').trim();
    return value.isEmpty ? 'Не удалось выполнить голосовую команду.' : value;
  }

  bool _hasStopCommand(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return RegExp(r'(?:^| )(?:готово|стоп)$').hasMatch(normalized);
  }

  String _cleanTranscript(String value) => value
      .trim()
      .replaceFirst(
        RegExp(r'(?:\s+|^)(?:готово|стоп)[.!?,\s]*$', caseSensitive: false),
        '',
      )
      .trim();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 74;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!isResultOpen)
          Positioned(
            right: 16,
            bottom: bottom,
            child: Material(
              color: Colors.transparent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isListening && liveTranscript.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppAdaptivePalette.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppAdaptivePalette.border),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            blurRadius: 18,
                            offset: Offset(0, 8),
                            color: Color(0x24000000),
                          ),
                        ],
                      ),
                      child: Text(
                        liveTranscript,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppAdaptivePalette.textPrimary,
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Tooltip(
                    message: isListening
                        ? 'Остановить и выполнить'
                        : 'Голосовой помощник AppСтрой',
                    child: InkWell(
                      onTap: isProcessing || isPreparing ? null : toggleVoice,
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isListening
                              ? AppAdaptivePalette.accent
                              : AppAdaptivePalette.surfaceElevated,
                          border: Border.all(
                            color: isListening
                                ? AppAdaptivePalette.accent
                                : AppAdaptivePalette.border,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              blurRadius: 22,
                              offset: Offset(0, 10),
                              color: Color(0x30000000),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isPreparing || isProcessing
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppAdaptivePalette.accent,
                                  ),
                                )
                              : Icon(
                                  isListening
                                      ? Icons.graphic_eq_rounded
                                      : Icons.mic_rounded,
                                  color: isListening
                                      ? Colors.white
                                      : AppAdaptivePalette.accent,
                                  size: 27,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _VoiceSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _VoiceSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _VoiceListSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final bool warning;

  const _VoiceListSection({
    required this.title,
    required this.items,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: warning ? colors.error : colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: warning ? colors.error : colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: warning ? colors.error : colors.onSurfaceVariant,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
