import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../tasks/voice/task_voice_recognition.dart';
import '../actions/ai_action_execution_coordinator.dart';
import '../data/ai_assistant_repository.dart';
import '../models/ai_assistant_result.dart';

const _globalVoiceHints = <String>[
  'сотрудник',
  'сотрудники',
  'табель',
  'смена',
  'смены',
  'сегодня',
  'вчера',
  'завтра',
  'задача',
  'задачи',
  'выплата',
  'аванс',
  'зарплата',
  'штраф',
  'чек',
  'чеки',
  'документ',
  'договор',
  'акт',
  'кандидат',
  'кандидаты',
  'оформление',
  'объект',
  'объекты',
  'напомни',
  'напоминание',
  'проверь',
  'покажи',
  'найди',
  'создай',
  'добавь',
  'измени',
  'поставь',
  'назначь',
  'открой',
  'сколько',
  'кто',
  'кому',
  'должны',
  'долг',
  'остаток',
  'просрочено',
  'без чека',
  'не вышел',
  'сводка',
  'отчет',
  'аудит',
];

/// Единый голосовой вход поверх профессиональных платформ AppСтрой.
///
/// Слой не выполняет изменения напрямую. Текст уходит в существующий
/// AiAssistantRepository, а любые структурированные действия выполняются через
/// AiActionExecutionCoordinator, где уже есть обязательное подтверждение и
/// аудит. Благодаря этому голос не получает отдельный путь обхода бизнес-правил.
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
  Timer? _silenceTimer;
  bool _listening = false;
  bool _processing = false;
  String _transcript = '';
  String? _errorText;
  double? _left;
  double? _top;

  AppUserProfile get profile => widget.profile;

  String? get _objectName {
    final value = profile.objectName.trim();
    return value.isEmpty ? null : value;
  }

  bool get _disabledByPreview => profile.isRolePreview;

  @override
  void didUpdateWidget(covariant GlobalVoiceAssistantLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != profile.id ||
        oldWidget.profile.activeCompanyId != profile.activeCompanyId ||
        oldWidget.profile.role != profile.role ||
        oldWidget.profile.objectName != profile.objectName) {
      _silenceTimer?.cancel();
      if (_listening) unawaited(stopTaskVoiceRecognition());
      _listening = false;
      _processing = false;
      _transcript = '';
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    if (_listening) unawaited(stopTaskVoiceRecognition());
    super.dispose();
  }

  void _publishPartial(String value) {
    final clean = value.trim();
    if (!mounted || clean.isEmpty) return;
    setState(() {
      _transcript = clean;
      _errorText = null;
    });

    // Web Speech может продолжать continuous-сессию бесконечно. Для глобальной
    // команды естественнее завершать запись после короткой паузы в речи.
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 1350), () {
      if (_listening) unawaited(stopTaskVoiceRecognition());
    });
  }

  Future<void> _toggleMicrophone() async {
    if (_processing) return;
    if (_disabledByPreview) {
      _message(
        'Голосовые команды отключены в предпросмотре роли. Вернитесь в свою роль.',
      );
      return;
    }
    if (_listening) {
      _silenceTimer?.cancel();
      await stopTaskVoiceRecognition();
      return;
    }

    setState(() {
      _listening = true;
      _transcript = '';
      _errorText = null;
    });

    try {
      final transcript = await recognizeTaskVoice(
        hints: _globalVoiceHints,
        onPartial: _publishPartial,
      );
      if (!mounted) return;
      final clean = transcript.trim();
      setState(() {
        _listening = false;
        _transcript = clean;
      });
      await _process(clean);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _processing = false;
        _errorText = _cleanError(error);
      });
      _showErrorSheet(_errorText!);
    } finally {
      _silenceTimer?.cancel();
    }
  }

  Future<void> _process(String transcript) async {
    if (transcript.trim().isEmpty || _processing) return;
    setState(() {
      _processing = true;
      _errorText = null;
    });
    try {
      final result = await AiAssistantRepository.request(
        mode: 'chat',
        companyId: profile.activeCompanyId,
        objectName: _objectName,
        prompt: transcript,
      );
      if (!mounted) return;
      setState(() => _processing = false);
      await _showResultSheet(result, transcript);
    } catch (error) {
      if (!mounted) return;
      final message = _cleanError(error);
      setState(() {
        _processing = false;
        _errorText = message;
      });
      _showErrorSheet(message);
    }
  }

  Future<void> _showResultSheet(
    AiAssistantResult result,
    String transcript,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Material(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.graphic_eq_rounded,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.title,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.scopeLabel,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Услышал',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            transcript,
                            style: const TextStyle(
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (result.summary.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SelectableText(
                        result.summary,
                        style: const TextStyle(
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (result.highlights.isNotEmpty)
                      _VoiceResultList(
                        title: 'Главное',
                        icon: Icons.check_circle_outline_rounded,
                        items: result.highlights,
                      ),
                    if (result.warnings.isNotEmpty)
                      _VoiceResultList(
                        title: 'Требует внимания',
                        icon: Icons.warning_amber_rounded,
                        items: result.warnings,
                        warning: true,
                      ),
                    if (result.nextSteps.isNotEmpty)
                      _VoiceResultList(
                        title: 'Следующие шаги',
                        icon: Icons.arrow_forward_rounded,
                        items: result.nextSteps,
                      ),
                    if (result.action != null) ...[
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () async {
                          final action = result.action!;
                          Navigator.pop(sheetContext);
                          await _runAction(action);
                        },
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(result.action!.buttonLabel),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Изменения не выполняются голосом напрямую: перед записью AppСтрой ещё раз покажет точное действие для подтверждения.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.done_rounded),
                      label: const Text('Готово'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _runAction(AiAssistantAction action) async {
    try {
      final result = await AiActionExecutionCoordinator.execute(
        context: context,
        profile: profile,
        action: action,
      );
      if (!mounted) return;
      _message(result.message);
    } catch (error) {
      if (!mounted) return;
      _message('Действие не выполнено: ${_cleanError(error)}');
    }
  }

  void _showErrorSheet(String message) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Material(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: scheme.error),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Не удалось выполнить голосовую команду',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(message, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Понятно'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _cleanError(Object error) {
    final value = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
    return value.isEmpty ? 'Не удалось выполнить действие' : value;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const buttonSize = 58.0;
        final maxLeft = math.max(8.0, constraints.maxWidth - buttonSize - 8);
        final maxTop = math.max(72.0, constraints.maxHeight - buttonSize - 92);
        final left = (_left ?? maxLeft).clamp(8.0, maxLeft).toDouble();
        final top = (_top ?? maxTop).clamp(72.0, maxTop).toDouble();
        final scheme = Theme.of(context).colorScheme;

        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            Positioned(
              left: left,
              top: top,
              child: SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() {
                      _left = (left + details.delta.dx)
                          .clamp(8.0, maxLeft)
                          .toDouble();
                      _top = (top + details.delta.dy)
                          .clamp(72.0, maxTop)
                          .toDouble();
                    });
                  },
                  onTap: _toggleMicrophone,
                  child: Semantics(
                    button: true,
                    label: _listening
                        ? 'Остановить голосовую команду'
                        : 'Голосовой помощник AppСтрой',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _disabledByPreview
                            ? scheme.surfaceContainerHighest
                            : _listening
                            ? scheme.errorContainer
                            : scheme.primary,
                        border: Border.all(
                          color: scheme.surface.withValues(alpha: 0.9),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: _processing
                          ? Padding(
                              padding: const EdgeInsets.all(17),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: scheme.onPrimary,
                              ),
                            )
                          : Icon(
                              _disabledByPreview
                                  ? Icons.mic_off_rounded
                                  : _listening
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              color: _disabledByPreview
                                  ? scheme.onSurfaceVariant
                                  : _listening
                                  ? scheme.onErrorContainer
                                  : scheme.onPrimary,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            if ((_listening || _processing) && _transcript.isNotEmpty)
              Positioned(
                right: 18,
                bottom: 170,
                child: IgnorePointer(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.min(420, constraints.maxWidth - 36),
                    ),
                    child: Material(
                      color: scheme.surface,
                      elevation: 6,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _processing
                                  ? Icons.auto_awesome_rounded
                                  : Icons.graphic_eq_rounded,
                              size: 19,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _processing
                                    ? 'Понимаю: $_transcript'
                                    : 'Слышу: $_transcript',
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _VoiceResultList extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final bool warning;

  const _VoiceResultList({
    required this.title,
    required this.icon,
    required this.items,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.error : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
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
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
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
