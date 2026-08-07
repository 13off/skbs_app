// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of '../add_task_screen.dart';

extension _TaskCreateVoice on _AddTaskScreenState {
  Widget buildVoiceAssistantCard() {
    final canListen = !isListeningVoice && !isLoadingEmployees;
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
                  isListeningVoice ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  color: AppAdaptivePalette.accent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Заполнить голосом',
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
            'Например: «На завтра, оси 5–8 А–Г, закончить армирование стены, Иванов и Ахмедов».',
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
              onPressed: canListen ? captureVoiceTask : null,
              icon: isListeningVoice
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mic_rounded),
              label: Text(
                isListeningVoice
                    ? 'Слушаю…'
                    : isLoadingEmployees
                    ? 'Загружаем сотрудников…'
                    : 'Сказать задачу',
              ),
            ),
          ),
          if (voiceTranscript?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              'Распознано: ${voiceTranscript!.trim()}',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
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

  Future<void> captureVoiceTask() async {
    if (isListeningVoice) return;
    setState(() {
      isListeningVoice = true;
      voiceMessage = null;
      voiceHasWarning = false;
      errorText = null;
    });

    try {
      final transcript = await recognizeTaskVoice();
      final parsed = parseTaskVoice(
        transcript: transcript,
        now: DateTime.now(),
        employees: employees,
      );
      if (!mounted) return;

      final warnings = <String>[];
      final parsedDate = parsed.date;
      var nextDate = selectedDate;
      if (parsedDate != null) {
        final sameDate =
            parsedDate.year == selectedDate.year &&
            parsedDate.month == selectedDate.month &&
            parsedDate.day == selectedDate.day;
        if (widget.allowAnyDate || sameDate) {
          nextDate = parsedDate;
        } else {
          warnings.add('дату менять нельзя по правилам объекта');
        }
      } else {
        warnings.add('дата не распознана');
      }

      if (parsed.axes.isEmpty) warnings.add('оси не распознаны');
      if (parsed.work.isEmpty) warnings.add('задача не распознана');
      if (parsed.assigneeIds.isEmpty) {
        warnings.add('исполнители не найдены среди сотрудников объекта');
      }
      if (isGoalTask && parsed.work.isNotEmpty) {
        warnings.add('вид работ не изменён: задача привязана к цели');
      }

      setState(() {
        selectedDate = nextDate;
        voiceTranscript = transcript;
        if (parsed.axes.isNotEmpty) axesController.text = parsed.axes;
        if (parsed.work.isNotEmpty && !isGoalTask) {
          workController.text = parsed.work;
        }
        if (parsed.assigneeIds.isNotEmpty) {
          selectedAssigneeIds
            ..clear()
            ..addAll(parsed.assigneeIds);
        }
        voiceHasWarning = warnings.isNotEmpty;
        voiceMessage = warnings.isEmpty
            ? 'Готово. Проверьте четыре поля и сохраните задачу.'
            : 'Заполнил всё, что распознал: ${warnings.join(' • ')}.';
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
      if (mounted) {
        setState(() {
          isListeningVoice = false;
        });
      }
    }
  }
}
