import 'package:flutter/material.dart';

class AiOperationalPromptChips extends StatelessWidget {
  final ValueChanged<String> onSelected;
  final bool enabled;

  const AiOperationalPromptChips({
    super.key,
    required this.onSelected,
    this.enabled = true,
  });

  static const examples = <({String label, String prompt, IconData icon})>[
    (
      label: 'Кто не вышел',
      prompt: 'Кто сегодня не вышел на работу?',
      icon: Icons.person_off_outlined,
    ),
    (
      label: 'Кому должны',
      prompt: 'Кому ещё не выплатили зарплату и какой остаток?',
      icon: Icons.payments_outlined,
    ),
    (
      label: 'Сроки документов',
      prompt: 'Какие документы просрочены или скоро заканчиваются?',
      icon: Icons.event_busy_outlined,
    ),
    (
      label: 'Сводка за неделю',
      prompt: 'Сделай недельную сводку по объекту',
      icon: Icons.summarize_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: examples
          .map(
            (example) => ActionChip(
              avatar: Icon(example.icon, size: 17),
              label: Text(example.label),
              onPressed: enabled ? () => onSelected(example.prompt) : null,
            ),
          )
          .toList(),
    );
  }
}
