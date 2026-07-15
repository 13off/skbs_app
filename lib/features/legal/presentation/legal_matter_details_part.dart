part of 'legal_matters_screen.dart';

class LegalMatterDetailsScreen extends StatefulWidget {
  final LegalMatter matter;
  final bool canDecide;

  const LegalMatterDetailsScreen({super.key, required this.matter, this.canDecide = false});

  @override
  State<LegalMatterDetailsScreen> createState() => _LegalMatterDetailsScreenState();
}

class _LegalMatterDetailsScreenState extends State<LegalMatterDetailsScreen> {
  late LegalMatter matter;

  @override
  void initState() {
    super.initState();
    matter = widget.matter;
  }

  String date(DateTime? value) {
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Widget line(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 125, child: Text(label, style: const TextStyle(color: Color(0xFF6B7075), fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Future<void> edit() async {
    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute<bool>(builder: (_) => LegalMatterEditorScreen(matter: matter)),
    );
    if (saved == true) {
      final fresh = await LegalRepository.fetchMatter(matter.id);
      if (mounted) setState(() => matter = fresh);
    }
  }

  Future<void> decide(bool approved) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? 'Согласовать решение' : 'Отклонить решение'),
        content: TextField(controller: controller, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Комментарий руководителя')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Подтвердить')),
        ],
      ),
    );
    controller.dispose();
    if (comment == null) return;
    await LegalRepository.decideMatter(matterId: matter.id, approved: approved, comment: comment);
    final fresh = await LegalRepository.fetchMatter(matter.id);
    if (mounted) setState(() => matter = fresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Юридический вопрос'),
        actions: [if (!widget.canDecide) IconButton(onPressed: edit, icon: const Icon(Icons.edit_outlined))],
      ),
      body: AppPage(
        title: matter.title,
        subtitle: '${matter.riskTitle} риск • ${matter.statusTitle}',
        child: Column(
          children: [
            PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  line('Тип', matter.typeTitle),
                  line('Описание', matter.description),
                  line('Срок', date(matter.dueAt)),
                  line('Ответственный', matter.responsibleName),
                  line('Сотрудник', matter.employeeName),
                  line('Объект', matter.objectName),
                  line('Контрагент', matter.counterpartyName),
                  line('Действия', matter.requiredActions),
                  line('Результат', matter.result),
                  line('Вопрос руководителю', matter.managerQuestion),
                  line('Решение', matter.decisionComment),
                ],
              ),
            ),
            if (widget.canDecide && matter.needsManager) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => decide(false),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Отклонить'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => decide(true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Согласовать'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
