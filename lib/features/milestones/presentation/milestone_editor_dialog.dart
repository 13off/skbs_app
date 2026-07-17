import 'package:flutter/material.dart';

import '../../../data/object_repository.dart';
import '../../../models/app_user_profile.dart';
import '../data/milestone_repository.dart';
import '../models/milestone_models.dart';

class MilestoneCreateDraft {
  final String objectName;
  final String title;
  final String location;
  final DateTime targetDate;
  final String notes;
  final List<MilestoneChecklistDraft> checklist;

  const MilestoneCreateDraft({
    required this.objectName,
    required this.title,
    required this.location,
    required this.targetDate,
    required this.notes,
    required this.checklist,
  });
}

class MilestoneEditorDialog extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const MilestoneEditorDialog({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<MilestoneEditorDialog> createState() => _MilestoneEditorDialogState();
}

class _MilestoneEditorDialogState extends State<MilestoneEditorDialog> {
  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();
  DateTime targetDate = DateTime.now().add(const Duration(days: 7));
  String template = 'concrete';
  String? objectName;
  List<String> objectNames = const <String>[];
  bool loadingObjects = false;

  @override
  void initState() {
    super.initState();
    objectName = _clean(widget.selectedObjectName) ??
        (widget.profile.isForeman ? _clean(widget.profile.objectName) : null);
    if (widget.profile.isAdmin) loadObjects();
  }

  @override
  void dispose() {
    titleController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Future<void> loadObjects() async {
    setState(() => loadingObjects = true);
    try {
      final names = await ObjectRepository.fetchObjectNames();
      if (!mounted) return;
      setState(() {
        objectNames = names;
        if (objectName == null && names.length == 1) objectName = names.first;
      });
    } finally {
      if (mounted) setState(() => loadingObjects = false);
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: targetDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Дата ключевого этапа',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked != null) setState(() => targetDate = picked);
  }

  String dateText() {
    final day = targetDate.day.toString().padLeft(2, '0');
    final month = targetDate.month.toString().padLeft(2, '0');
    return '$day.$month.${targetDate.year}';
  }

  void submit() {
    final object = _clean(objectName);
    final title = titleController.text.trim();
    if (object == null || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите объект и название этапа')),
      );
      return;
    }

    final checklist = switch (template) {
      'general' => MilestoneRepository.generalChecklist,
      'empty' => const <MilestoneChecklistDraft>[],
      _ => MilestoneRepository.concreteChecklist,
    };

    Navigator.pop(
      context,
      MilestoneCreateDraft(
        objectName: object,
        title: title,
        location: locationController.text.trim(),
        targetDate: targetDate,
        notes: notesController.text.trim(),
        checklist: checklist,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Новый ключевой этап',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.profile.isAdmin)
              DropdownButtonFormField<String>(
                initialValue: objectNames.contains(objectName) ? objectName : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: loadingObjects ? 'Загрузка объектов...' : 'Объект',
                  prefixIcon: const Icon(Icons.apartment_outlined),
                ),
                items: objectNames
                    .map(
                      (name) => DropdownMenuItem<String>(
                        value: name,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: loadingObjects
                    ? null
                    : (value) => setState(() => objectName = value),
              )
            else
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Объект'),
                subtitle: Text(objectName ?? 'Не назначен'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Название этапа',
                hintText: 'Бетонирование фундаментной плиты',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Строительная привязка',
                hintText: 'Оси 1–1 / А–А · отметка +0.000',
                prefixIcon: Icon(Icons.grid_4x4_outlined),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Дата: ${dateText()}'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: template,
              decoration: const InputDecoration(
                labelText: 'Шаблон готовности',
                prefixIcon: Icon(Icons.checklist_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'concrete',
                  child: Text('Бетонирование — 8 пунктов'),
                ),
                DropdownMenuItem(
                  value: 'general',
                  child: Text('Общий строительный этап — 5 пунктов'),
                ),
                DropdownMenuItem(
                  value: 'empty',
                  child: Text('Пустой чек-лист'),
                ),
              ],
              onChanged: (value) => setState(() => template = value ?? 'concrete'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                hintText: 'Дополнительные условия или пояснения',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Создать этап'),
            ),
          ],
        ),
      ),
    );
  }
}
