// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member, unnecessary_brace_in_string_interps

part of '../add_task_screen.dart';

const _taskVoiceDomainHints = <String>[
  'оси', 'ось', 'по осям', 'один', 'два', 'три', 'четыре', 'пять', 'шесть',
  'семь', 'восемь', 'девять', 'десять', 'а', 'бэ', 'вэ', 'гэ', 'дэ',
  'армирование', 'арматура', 'опалубка', 'бетонирование', 'бетон', 'колонна',
  'колонны', 'стена', 'стены', 'перекрытие', 'плита', 'фундамент', 'ростверк',
  'ригель', 'балка', 'лестница', 'захватка', 'секция', 'этаж', 'монтаж',
  'демонтаж', 'закончить', 'выполнить', 'подготовить', 'вид работ',
  'исполнитель', 'исполнители',
];

final _voiceAssigneeMarker = RegExp(r'исполнител(?:ь|и|ей|ям|я)?', caseSensitive: false);

const _voiceNameStopWords = <String>{
  'сегодня', 'завтра', 'задача', 'задачи', 'работа', 'работы', 'армирование',
  'арматура', 'опалубка', 'бетонирование', 'бетон', 'колонна', 'колонны',
  'стена', 'стены', 'перекрытие', 'плита', 'фундамент', 'ростверк', 'ригель',
  'балка', 'лестница', 'захватка', 'секция', 'этаж', 'монтаж', 'демонтаж',
  'закончить', 'выполнить', 'подготовить', 'исполнитель', 'исполнители',
  'первый', 'первая', 'второй', 'вторая', 'третий', 'третья', 'четыре',
  'пять', 'шесть', 'семь', 'восемь', 'девять', 'десять',
};

List<String> _buildTaskVoiceHints(List<Employee> employees) {
  final surnames = <String>[];
  final fullNames = <String>[];
  final firstNames = <String>[];
  for (final employee in employees) {
    final name = employee.name.trim();
    if (name.isEmpty) continue;
    final parts = name.split(RegExp(r'\s+'));
    if (parts.isNotEmpty && parts.first.length >= 3) surnames.add(parts.first);
    fullNames.add(name);
    if (parts.length > 1 && parts[1].length >= 3) firstNames.add(parts[1]);
  }
  return <String>[...surnames, ...fullNames, ..._taskVoiceDomainHints, ...firstNames];
}

class _VoiceEmployeeCandidate {
  final Employee employee;
  final String surname;
  final String firstName;
  const _VoiceEmployeeCandidate({required this.employee, required this.surname, required this.firstName});
}

class _VoiceEmployeeScore {
  final _VoiceEmployeeCandidate candidate;
  final double score;
  const _VoiceEmployeeScore(this.candidate, this.score);
}

List<String> _resolveVoiceEmployeeIds({
  required String transcript,
  required List<Employee> employees,
  required List<String> fallbackIds,
}) {
  final markers = _voiceAssigneeMarker.allMatches(transcript).toList();
  final explicitAssignees = markers.isNotEmpty;
  final scope = explicitAssignees ? transcript.substring(markers.last.end) : transcript;
  final resolved = <String>{if (!explicitAssignees) ...fallbackIds};
  final surnameCounts = <String, int>{};
  final firstNameCounts = <String, int>{};
  final candidates = <_VoiceEmployeeCandidate>[];

  for (final employee in employees) {
    final id = employee.id?.trim() ?? '';
    final parts = _normalizeVoiceName(employee.name).split(' ');
    if (id.isEmpty || parts.isEmpty || parts.first.length < 3) continue;
    final surname = parts.first;
    final firstName = parts.length > 1 ? parts[1] : '';
    surnameCounts[surname] = (surnameCounts[surname] ?? 0) + 1;
    if (firstName.isNotEmpty) firstNameCounts[firstName] = (firstNameCounts[firstName] ?? 0) + 1;
    candidates.add(_VoiceEmployeeCandidate(employee: employee, surname: surname, firstName: firstName));
  }

  final rawTokens = RegExp(r'[А-Яа-яЁё]{3,}').allMatches(scope)
      .map((match) => match.group(0) ?? '').where((token) => token.isNotEmpty).toList();
  final tokens = <String>[];
  for (var index = 0; index < rawTokens.length; index += 1) {
    final current = _normalizeVoiceName(rawTokens[index]);
    if (current.length >= 3 && !_voiceNameStopWords.contains(current)) tokens.add(current);
    if (index + 1 < rawTokens.length) {
      final next = _normalizeVoiceName(rawTokens[index + 1]);
      final joined = '$current$next';
      if (current.length >= 3 && next.length >= 2 && joined.length <= 18) tokens.add(joined);
    }
  }

  for (final token in tokens) {
    _VoiceEmployeeScore? best;
    var secondScore = 0.0;
    for (final candidate in candidates) {
      final id = candidate.employee.id?.trim() ?? '';
      if (id.isEmpty || resolved.contains(id)) continue;
      var score = 0.0;
      if (surnameCounts[candidate.surname] == 1) score = _voiceNameMatchScore(token, candidate.surname);
      if (candidate.firstName.isNotEmpty && firstNameCounts[candidate.firstName] == 1) {
        final firstScore = _voiceNameMatchScore(token, candidate.firstName) - 0.05;
        if (firstScore > score) score = firstScore;
      }
      if (best == null || score > best.score) {
        if (best != null) secondScore = best.score;
        best = _VoiceEmployeeScore(candidate, score);
      } else if (score > secondScore) {
        secondScore = score;
      }
    }
    if (best == null) continue;
    final threshold = token.length <= 4 ? 0.88 : 0.76;
    final requiredMargin = best.score >= 0.94 ? 0.025 : 0.07;
    if (best.score < threshold || best.score - secondScore < requiredMargin) continue;
    final id = best.candidate.employee.id?.trim() ?? '';
    if (id.isNotEmpty) resolved.add(id);
  }
  return resolved.toList(growable: false);
}

double _voiceNameMatchScore(String heard, String expected) {
  var best = 0.0;
  for (final form in _voiceNameForms(expected)) {
    final longest = heard.length > form.length ? heard.length : form.length;
    if (longest == 0) continue;
    final rawDistance = _voiceEditDistance(heard, form);
    final rawSimilarity = 1 - rawDistance / longest;
    if (rawSimilarity > best) best = rawSimilarity;
    final heardKey = _voicePhoneticKey(heard);
    final formKey = _voicePhoneticKey(form);
    if (heardKey.length >= 3 && formKey.length >= 3) {
      final phoneticLongest = heardKey.length > formKey.length ? heardKey.length : formKey.length;
      final phoneticSimilarity = 1 - _voiceEditDistance(heardKey, formKey) / phoneticLongest;
      final combined = rawSimilarity * 0.30 + phoneticSimilarity * 0.70;
      if (combined > best) best = combined;
      if (heardKey == formKey && rawSimilarity >= 0.55 && best < 0.91) best = 0.91;
    }
    final prefix = _voiceCommonPrefix(heard, form);
    if (prefix >= 5 && rawSimilarity >= 0.65) {
      final boosted = rawSimilarity + 0.04;
      if (boosted > best) best = boosted;
    }
  }
  if (best < 0) return 0;
  return best > 1 ? 1 : best;
}

Set<String> _voiceNameForms(String value) {
  final clean = _normalizeVoiceName(value);
  final forms = <String>{clean};
  if (clean.length < 3) return forms;
  if (clean.endsWith('а')) {
    final stem = clean.substring(0, clean.length - 1);
    forms..add('${stem}у')..add('${stem}ой');
  } else if (clean.endsWith('я')) {
    final stem = clean.substring(0, clean.length - 1);
    forms..add('${stem}ю')..add('${stem}ей');
  } else if (clean.endsWith('ий')) {
    final stem = clean.substring(0, clean.length - 2);
    forms..add('${stem}ия')..add('${stem}ию')..add('${stem}им');
  } else {
    forms..add('${clean}а')..add('${clean}у')..add('${clean}ом')..add('${clean}ым');
  }
  return forms;
}

String _voicePhoneticKey(String value) {
  final source = _normalizeVoiceName(value).replaceAll(' ', '');
  final buffer = StringBuffer();
  String previous = '';
  for (final rune in source.runes) {
    final char = String.fromCharCode(rune);
    if ('аеёиоуыэюяйьъ'.contains(char)) continue;
    final mapped = switch (char) {
      'б' || 'п' => 'п', 'в' || 'ф' => 'ф', 'г' || 'к' || 'х' => 'к',
      'д' || 'т' => 'т', 'ж' || 'ш' || 'щ' => 'ш', 'з' || 'с' || 'ц' => 'с', _ => char,
    };
    if (mapped == previous) continue;
    buffer.write(mapped);
    previous = mapped;
  }
  return buffer.toString();
}

int _voiceEditDistance(String left, String right) {
  if (left == right) return 0;
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var i = 0; i < left.length; i += 1) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = i + 1;
    for (var j = 0; j < right.length; j += 1) {
      final substitution = previous[j] + (left[i] == right[j] ? 0 : 1);
      final insertion = current[j] + 1;
      final deletion = previous[j + 1] + 1;
      current[j + 1] = substitution < insertion
          ? (substitution < deletion ? substitution : deletion)
          : (insertion < deletion ? insertion : deletion);
    }
    previous = current;
  }
  return previous.last;
}

int _voiceCommonPrefix(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  var count = 0;
  while (count < length && left[count] == right[count]) count += 1;
  return count;
}

String _normalizeVoiceName(String value) => value.toLowerCase().replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^а-я]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 240), width: 46, height: 46,
            decoration: BoxDecoration(
              color: isListeningVoice ? AppAdaptivePalette.accent.withValues(alpha: 0.20)
                  : AppAdaptivePalette.accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: AppAdaptivePalette.accent.withValues(alpha: 0.32)),
            ),
            child: Icon(isListeningVoice ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                color: AppAdaptivePalette.accent),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Заполнить голосом', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            SizedBox(height: 3),
            Text('Дата • оси • задача • исполнители', style: TextStyle(fontWeight: FontWeight.w700)),
          ])),
        ]),
        const SizedBox(height: 12),
        Text(
          isListeningVoice
              ? 'Поля заполняются сразу. Если фамилия неверна, скажите «исполнитель Фамилия» ещё раз — последний вариант заменит предыдущий.'
              : 'Например: «На завтра, оси 5–8 А–Г, закончить армирование стены, исполнитель Ахмедов».',
          style: TextStyle(color: AppAdaptivePalette.textMuted, height: 1.35, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
          onPressed: !canUseVoice ? null : isListeningVoice ? stopVoiceTask : captureVoiceTask,
          icon: Icon(isListeningVoice ? Icons.stop_rounded : Icons.mic_rounded),
          label: Text(isListeningVoice ? 'Стоп' : isLoadingEmployees ? 'Загружаем сотрудников…' : 'Сказать задачу'),
        )),
        if (voiceTranscript?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(isListeningVoice ? 'Слышу сейчас: ${voiceTranscript!.trim()}' : 'Распознано: ${voiceTranscript!.trim()}',
              style: TextStyle(color: AppAdaptivePalette.textMuted, fontSize: 12, height: 1.35, fontWeight: FontWeight.w600)),
        ],
        if (voiceMessage?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(voiceMessage!.trim(), style: TextStyle(
            color: voiceHasWarning ? AppAdaptivePalette.warning : AppAdaptivePalette.accent,
            fontSize: 12, height: 1.35, fontWeight: FontWeight.w800,
          )),
        ],
      ]),
    );
  }

  Future<void> captureVoiceTask() async {
    if (isListeningVoice) return;
    setState(() {
      isListeningVoice = true;
      voiceTranscript = null;
      voiceMessage = 'Слушаю и заполняю поля по мере речи.';
      voiceHasWarning = false;
      errorText = null;
    });
    try {
      final transcript = await recognizeTaskVoice(hints: _buildTaskVoiceHints(employees), onPartial: applyVoicePartial);
      final parsed = parseForemanTaskVoice(transcript: transcript, now: DateTime.now(), employees: employees);
      final assigneeIds = _resolveVoiceEmployeeIds(transcript: transcript, employees: employees, fallbackIds: parsed.assigneeIds);
      if (!mounted) return;
      final warnings = <String>[];
      final parsedDate = parsed.date;
      var nextDate = selectedDate;
      if (parsedDate != null) {
        final sameDate = _sameVoiceDate(parsedDate, selectedDate);
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
      if (assigneeIds.isEmpty) warnings.add('исполнители не найдены среди сотрудников объекта');
      if (isGoalTask && parsed.work.isNotEmpty) warnings.add('вид работ не изменён: задача привязана к цели');
      setState(() {
        selectedDate = nextDate;
        voiceTranscript = transcript;
        if (parsed.axes.isNotEmpty) axesController.text = parsed.axes;
        if (parsed.work.isNotEmpty && !isGoalTask) workController.text = parsed.work;
        _applyVoiceAssignees(transcript, assigneeIds);
        voiceHasWarning = warnings.isNotEmpty;
        voiceMessage = warnings.isEmpty
            ? 'Готово. Проверьте четыре поля и сохраните задачу.'
            : 'Заполнил всё, что распознал: ${warnings.join(' • ')}.';
      });
    } catch (error) {
      if (!mounted) return;
      final clean = error.toString().replaceFirst('Exception: ', '').replaceFirst('PlatformException: ', '').trim();
      setState(() {
        voiceHasWarning = true;
        voiceMessage = clean.isEmpty ? 'Не удалось распознать голос. Попробуйте ещё раз.' : clean;
      });
    } finally {
      if (mounted) setState(() => isListeningVoice = false);
    }
  }

  void applyVoicePartial(String transcript) {
    if (!mounted || !isListeningVoice || transcript.trim().isEmpty) return;
    final parsed = parseForemanTaskVoice(transcript: transcript, now: DateTime.now(), employees: employees);
    final assigneeIds = _resolveVoiceEmployeeIds(transcript: transcript, employees: employees, fallbackIds: parsed.assigneeIds);
    final found = <String>[];
    final missing = <String>[];
    setState(() {
      voiceTranscript = transcript;
      voiceHasWarning = false;
      final parsedDate = parsed.date;
      if (parsedDate != null) {
        final sameDate = _sameVoiceDate(parsedDate, selectedDate);
        if (widget.allowAnyDate || sameDate) {
          selectedDate = parsedDate;
          found.add('дата');
        } else {
          missing.add('дата');
        }
      } else {
        missing.add('дата');
      }
      if (parsed.axes.isNotEmpty) {
        axesController.text = parsed.axes;
        found.add('оси');
      } else {
        missing.add('оси');
      }
      if (parsed.work.isNotEmpty && !isGoalTask) {
        workController.text = parsed.work;
        found.add('задача');
      } else if (!isGoalTask) {
        missing.add('задача');
      } else {
        found.add('задача');
      }
      _applyVoiceAssignees(transcript, assigneeIds);
      if (assigneeIds.isNotEmpty) {
        found.add('исполнители');
      } else {
        missing.add('исполнители');
      }
      final askedForAssignee = _voiceAssigneeMarker.hasMatch(transcript);
      if (askedForAssignee && assigneeIds.isEmpty) {
        voiceHasWarning = true;
        voiceMessage = 'Фамилию пока не понял. Повторите: «исполнитель Фамилия». Остальные поля уже сохраняются.';
      } else if (missing.isEmpty) {
        voiceMessage = 'Все четыре поля распознаны. Если всё верно — нажмите «Стоп».';
      } else if (found.isEmpty) {
        voiceMessage = 'Пока разбираю фразу…';
      } else {
        voiceMessage = 'Готово: ${found.join(' • ')}. Ещё нужно: ${missing.join(' • ')}.';
      }
    });
  }

  void _applyVoiceAssignees(String transcript, List<String> ids) {
    final mentionsAssignees = _voiceAssigneeMarker.hasMatch(transcript);
    if (mentionsAssignees || ids.isNotEmpty) {
      selectedAssigneeIds..clear()..addAll(ids);
    }
  }

  bool _sameVoiceDate(DateTime left, DateTime right) =>
      left.year == right.year && left.month == right.month && left.day == right.day;

  Future<void> stopVoiceTask() async {
    if (!isListeningVoice) return;
    setState(() {
      voiceMessage = 'Останавливаю запись и фиксирую распознанные поля…';
      voiceHasWarning = false;
    });
    await stopTaskVoiceRecognition();
  }
}
