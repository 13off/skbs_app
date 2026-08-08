// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of '../add_task_screen.dart';

const _taskVoiceDomainHints = <String>[
  'дата',
  'дату',
  'сегодня',
  'завтра',
  'послезавтра',
  'оси',
  'ось',
  'по осям',
  'один',
  'два',
  'три',
  'четыре',
  'пять',
  'шесть',
  'семь',
  'восемь',
  'девять',
  'десять',
  'а',
  'бэ',
  'вэ',
  'гэ',
  'дэ',
  'армирование',
  'арматура',
  'опалубка',
  'бетонирование',
  'бетон',
  'колонна',
  'колонны',
  'стена',
  'стены',
  'перекрытие',
  'плита',
  'фундамент',
  'ростверк',
  'ригель',
  'балка',
  'лестница',
  'захватка',
  'секция',
  'этаж',
  'монтаж',
  'демонтаж',
  'доармировать',
  'добить опалубку',
  'залить плиту',
  'закончить',
  'выполнить',
  'подготовить',
  'вид работ',
  'исполнитель',
  'исполнители',
  'добавь ещё',
  'убери',
  'замени',
  'поменяй',
  'исправь',
  'оставь',
  'очисти',
  'начнём заново',
  'всё готово',
  'готово',
  'стоп',
];

extension _TaskCreateVoice on _AddTaskScreenState {
  Widget buildVoiceAssistantCard() {
    final canUseVoice = !isLoadingEmployees;
    final activeTitle = voiceActiveField == null
        ? null
        : taskVoiceFieldTitle(voiceActiveField!);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isListeningVoice
                      ? AppAdaptivePalette.accent.withValues(alpha: 0.20)
                      : AppAdaptivePalette.accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppAdaptivePalette.accent.withValues(alpha: 0.32),
                  ),
                ),
                child: Icon(
                  isListeningVoice
                      ? Icons.graphic_eq_rounded
                      : Icons.mic_rounded,
                  color: AppAdaptivePalette.accent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Голосовой помощник',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Дата • оси • вид работ • исполнитель',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isListeningVoice
                ? 'Назовите поле отдельно — например «оси». После этого все следующие фразы будут вводиться только в него, пока вы не назовёте другое поле.'
                : 'Сценарий простой: «оси» → «пять-восемь, Б–Г» → «вид работ» → «армирование стены» → «исполнитель» → «Иванов».',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isListeningVoice) ...[
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppAdaptivePalette.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppAdaptivePalette.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    activeTitle == null
                        ? Icons.touch_app_rounded
                        : Icons.mic_rounded,
                    size: 18,
                    color: AppAdaptivePalette.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeTitle == null
                          ? 'Жду выбор поля: дата, оси, вид работ или исполнитель'
                          : 'Активное поле: $activeTitle',
                      style: TextStyle(
                        color: AppAdaptivePalette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: !canUseVoice
                  ? null
                  : isListeningVoice
                  ? stopVoiceTask
                  : captureVoiceTask,
              icon: Icon(
                isListeningVoice ? Icons.stop_rounded : Icons.mic_rounded,
              ),
              label: Text(
                isListeningVoice
                    ? 'Стоп'
                    : isLoadingEmployees
                    ? 'Загружаем сотрудников…'
                    : 'Сказать задачу',
              ),
            ),
          ),
          if (voiceTranscript?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              isListeningVoice
                  ? 'Слышу сейчас: ${voiceTranscript!.trim()}'
                  : 'Распознано: ${voiceTranscript!.trim()}',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (voiceBatchDrafts.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppAdaptivePalette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppAdaptivePalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Распознано задач: ${voiceBatchDrafts.length}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0;
                      index < voiceBatchDrafts.length;
                      index += 1) ...[
                    Text(
                      '${index + 1}. ${voiceBatchDrafts[index].work} · ${voiceBatchDrafts[index].axes.isEmpty ? 'оси не указаны' : voiceBatchDrafts[index].axes} · ${_voiceBatchAssigneeTitle(voiceBatchDrafts[index])}',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (index + 1 < voiceBatchDrafts.length)
                      const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ],
          if (voiceMessage?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              voiceMessage!.trim(),
              style: TextStyle(
                color: voiceHasWarning
                    ? AppAdaptivePalette.warning
                    : AppAdaptivePalette.accent,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool isVoiceFieldActive(TaskVoiceField field) =>
      isListeningVoice && voiceActiveField == field;

  String _voiceBatchAssigneeTitle(TaskVoiceDraft draft) {
    if (draft.assigneeNames.isNotEmpty) return draft.assigneeNames.join(', ');
    final names = employees
        .where((employee) => draft.assigneeIds.contains(employee.id))
        .map((employee) => employee.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    return names.isEmpty ? 'исполнитель не указан' : names.join(', ');
  }

  void _snapshotVoiceSession() {
    voiceSessionInitialDate = selectedDate;
    voiceSessionInitialAxes = axesController.text.trim();
    voiceSessionInitialWork = workController.text.trim();
    voiceSessionInitialAssigneeIds = selectedAssigneeIds.toList();
  }

  TaskVoiceSessionResult _parseVoiceSession(String transcript) {
    final routed = routeTaskVoiceTranscript(
      transcript: transcript,
      activeField: voiceActiveField,
    );
    return applyForemanVoiceSession(
      transcript: routed,
      now: DateTime.now(),
      employees: employees,
      initialDate: voiceSessionInitialDate ?? selectedDate,
      initialAxes: voiceSessionInitialAxes,
      initialWork: voiceSessionInitialWork,
      initialAssigneeIds: voiceSessionInitialAssigneeIds,
      allowDateChange: widget.allowAnyDate,
      goalTask: isGoalTask,
    );
  }

  void _applyVoiceSessionResult(TaskVoiceSessionResult result) {
    selectedDate = result.date;
    axesController.text = result.axes;
    if (!isGoalTask) workController.text = result.work;
    selectedAssigneeIds
      ..clear()
      ..addAll(result.assigneeIds);
  }

  String _voiceStatusMessage(
    TaskVoiceSessionResult result, {
    TaskVoiceField? activeField,
    int batchCount = 0,
  }) {
    if (result.warning?.trim().isNotEmpty == true) return result.warning!.trim();
    if (batchCount > 1) {
      return 'Разобрал речь на $batchCount задачи. Проверьте список ниже. Ничего не сохранится, пока вы не нажмёте кнопку сохранения.';
    }
    if (result.resetRequested && result.missingFields.isNotEmpty) {
      return 'Начали заново. Сначала выберите поле голосом.';
    }
    if (activeField != null && result.changedFields.isEmpty) {
      return 'Выбрано поле «${taskVoiceFieldTitle(activeField)}». Теперь говорите только значение.';
    }
    if (activeField != null && result.changedFields.isNotEmpty) {
      final title = taskVoiceFieldTitle(activeField);
      if (result.missingFields.isEmpty) {
        return 'Значение поля «$title» обновлено. Все нужные поля заполнены. Можно назвать другое поле или сказать «готово».';
      }
      return 'Значение поля «$title» обновлено. Оно остаётся активным; можно продолжить или назвать другое поле.';
    }
    if (result.missingFields.isEmpty) {
      return 'Все четыре поля распознаны. Можно сказать «готово» или нажать «Стоп». Сохранение останется ручным.';
    }
    final first = result.missingFields.first;
    final hint = switch (first) {
      'оси' => 'Скажите «оси», затем отдельной фразой значение',
      'задача' => 'Скажите «вид работ», затем отдельной фразой значение',
      'исполнители' => 'Скажите «исполнитель», затем фамилию',
      _ => 'Назовите недостающее поле',
    };
    return 'Готово частично. Ещё нужно: ${result.missingFields.join(' • ')}. $hint.';
  }

  Future<void> captureVoiceTask() async {
    if (isListeningVoice) return;
    _snapshotVoiceSession();
    setState(() {
      isListeningVoice = true;
      voiceTranscript = null;
      voiceMessage = voiceActiveField == null
          ? 'Слушаю. Сначала скажите название поля: «оси», «вид работ», «исполнитель» или «дата».'
          : 'Слушаю. Активное поле: «${taskVoiceFieldTitle(voiceActiveField!)}». Говорите значение или назовите другое поле.';
      voiceHasWarning = false;
      voiceBatchDrafts = const <TaskVoiceDraft>[];
      errorText = null;
    });
    try {
      final transcript = await recognizeTaskVoice(
        hints: buildTaskVoiceHints(
          employees,
          domainHints: _taskVoiceDomainHints,
        ),
        onPartial: applyVoicePartial,
      );
      final nextActiveField = resolveTaskVoiceActiveField(
        transcript: transcript,
        currentField: voiceActiveField,
      );
      final session = _parseVoiceSession(transcript);
      final batch = isGoalTask
          ? const <TaskVoiceDraft>[]
          : parseForemanTaskVoiceBatch(
              transcript: transcript,
              now: DateTime.now(),
              employees: employees,
            );
      if (!mounted) return;

      setState(() {
        voiceActiveField = nextActiveField;
        _applyVoiceSessionResult(session);
        voiceTranscript = transcript;
        voiceBatchDrafts = batch.length > 1 ? batch : const <TaskVoiceDraft>[];
        final surnameMissing = nextActiveField == TaskVoiceField.assignees &&
            taskVoiceAssigneeMarker.hasMatch(transcript) &&
            session.assigneeIds.isEmpty;
        voiceHasWarning = session.warning != null || surnameMissing;
        voiceMessage = surnameMissing
            ? 'Фамилию пока не понял. Поле «Исполнитель» остаётся активным — повторите фамилию.'
            : _voiceStatusMessage(
                session,
                activeField: nextActiveField,
                batchCount: batch.length,
              );
      });

      final duplicate = await _findVoiceDuplicate();
      if (!mounted || duplicate == null) return;
      setState(() {
        voiceHasWarning = true;
        voiceMessage = '${voiceMessage ?? ''} $duplicate'.trim();
      });
    } catch (error) {
      if (!mounted) return;
      final clean = error
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('PlatformException: ', '')
          .trim();
      setState(() {
        voiceHasWarning = true;
        voiceMessage = clean.isEmpty
            ? 'Не удалось распознать голос. Попробуйте ещё раз.'
            : clean;
      });
    } finally {
      if (mounted) setState(() => isListeningVoice = false);
    }
  }

  void applyVoicePartial(String transcript) {
    if (!mounted || !isListeningVoice || transcript.trim().isEmpty) return;
    final nextActiveField = resolveTaskVoiceActiveField(
      transcript: transcript,
      currentField: voiceActiveField,
    );
    final session = _parseVoiceSession(transcript);
    setState(() {
      voiceActiveField = nextActiveField;
      _applyVoiceSessionResult(session);
      voiceTranscript = transcript;
      voiceHasWarning = session.warning != null;
      voiceMessage = _voiceStatusMessage(
        session,
        activeField: nextActiveField,
      );
    });
    if (session.shouldStop) {
      Future<void>.microtask(stopVoiceTask);
    }
  }

  Future<String?> _findVoiceDuplicate() async {
    final axes = axesController.text.trim();
    final work = workController.text.trim();
    if (axes.isEmpty || work.isEmpty) return null;
    try {
      final rows = await TaskRepository.fetchTasksForDate(
        selectedDate,
        objectName: widget.objectName,
      );
      final axesKey = _voiceDuplicateKey(axes);
      final workKey = _voiceDuplicateKey(work);
      final duplicate = rows.any(
        (task) =>
            _voiceDuplicateKey(task.axes) == axesKey &&
            _voiceDuplicateKey(task.work) == workKey,
      );
      return duplicate
          ? 'Похожая задача с такими же осями и видом работ уже есть на эту дату — проверьте перед сохранением.'
          : null;
    } catch (_) {
      return null;
    }
  }

  String _voiceDuplicateKey(String value) => value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> stopVoiceTask() async {
    if (!isListeningVoice) return;
    setState(() {
      voiceMessage = 'Останавливаю запись. Проверьте поля перед сохранением.';
      voiceHasWarning = false;
    });
    await stopTaskVoiceRecognition();
  }
}
