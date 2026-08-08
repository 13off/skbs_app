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
                      'Дата • оси • задача • исполнители',
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
                ? 'Поля заполняются сразу. Можно сказать: «дату послезавтра», «оси 7–10 Б–Д», «добавь ещё Иванова», «убери Дементьева», «вид работ бетонирование» или «начнём заново».'
                : 'Например: «На завтра, оси 5–8 А–Г, закончить армирование стены, исполнители Ахмедов и Иванов». Можно исправлять поля прямо в той же записи.',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
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
    return applyForemanVoiceSession(
      transcript: transcript,
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
    int batchCount = 0,
  }) {
    if (result.warning?.trim().isNotEmpty == true) return result.warning!.trim();
    if (batchCount > 1) {
      return 'Разобрал речь на $batchCount задачи. Проверьте список ниже. Ничего не сохранится, пока вы не нажмёте кнопку сохранения.';
    }
    if (result.resetRequested && result.missingFields.isNotEmpty) {
      return 'Начали заново. Ещё нужно: ${result.missingFields.join(' • ')}.';
    }
    if (result.missingFields.isEmpty) {
      return 'Все четыре поля распознаны. Можно сказать «готово» или нажать «Стоп». Сохранение останется ручным.';
    }
    final first = result.missingFields.first;
    final hint = switch (first) {
      'оси' => 'Скажите: «оси 5–8 А–Г»',
      'задача' => 'Скажите: «вид работ армирование стены»',
      'исполнители' => 'Скажите: «исполнитель Фамилия»',
      _ => 'Назовите недостающее поле',
    };
    return 'Готово частично. Ещё нужно: ${result.missingFields.join(' • ')}. $hint — запись продолжается.';
  }

  Future<void> captureVoiceTask() async {
    if (isListeningVoice) return;
    _snapshotVoiceSession();
    setState(() {
      isListeningVoice = true;
      voiceTranscript = null;
      voiceMessage = 'Слушаю. Можно говорить задачу и сразу исправлять себя.';
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
        _applyVoiceSessionResult(session);
        voiceTranscript = transcript;
        voiceBatchDrafts = batch.length > 1 ? batch : const <TaskVoiceDraft>[];
        final askedForAssignee = taskVoiceAssigneeMarker.hasMatch(transcript);
        final surnameMissing = askedForAssignee && session.assigneeIds.isEmpty;
        voiceHasWarning = session.warning != null || surnameMissing;
        voiceMessage = surnameMissing
            ? 'Фамилию пока не понял. Повторите «исполнитель Фамилия» или выберите сотрудника вручную.'
            : _voiceStatusMessage(session, batchCount: batch.length);
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
    final session = _parseVoiceSession(transcript);
    setState(() {
      _applyVoiceSessionResult(session);
      voiceTranscript = transcript;
      voiceHasWarning = session.warning != null;
      voiceMessage = _voiceStatusMessage(session);
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
