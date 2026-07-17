import 'package:flutter/material.dart';

import '../data/milestone_repository.dart';
import '../models/milestone_models.dart';

class TaskMilestoneSelection {
  final String? milestoneId;
  final String? checklistItemId;

  const TaskMilestoneSelection({
    required this.milestoneId,
    required this.checklistItemId,
  });

  bool get isLinked =>
      milestoneId != null &&
      milestoneId!.isNotEmpty &&
      checklistItemId != null &&
      checklistItemId!.isNotEmpty;
}

class TaskMilestonePicker extends StatefulWidget {
  final String objectName;
  final String? initialMilestoneId;
  final String? initialChecklistItemId;
  final bool canSelect;
  final bool canEditChecklist;
  final ValueChanged<TaskMilestoneSelection> onChanged;

  const TaskMilestonePicker({
    super.key,
    required this.objectName,
    required this.onChanged,
    this.initialMilestoneId,
    this.initialChecklistItemId,
    this.canSelect = true,
    this.canEditChecklist = true,
  });

  @override
  State<TaskMilestonePicker> createState() => _TaskMilestonePickerState();
}

class _TaskMilestonePickerState extends State<TaskMilestonePicker> {
  static const String _notLinkedValue = '__not_linked__';

  late Future<List<ProjectMilestone>> milestonesFuture;
  String? selectedMilestoneId;
  String? selectedChecklistItemId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    selectedMilestoneId = _clean(widget.initialMilestoneId);
    selectedChecklistItemId = _clean(widget.initialChecklistItemId);
    milestonesFuture = _loadMilestones();
  }

  @override
  void didUpdateWidget(covariant TaskMilestonePicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.objectName.trim() != widget.objectName.trim()) {
      selectedMilestoneId = _clean(widget.initialMilestoneId);
      selectedChecklistItemId = _clean(widget.initialChecklistItemId);
      milestonesFuture = _loadMilestones();
      return;
    }

    if (oldWidget.initialMilestoneId != widget.initialMilestoneId ||
        oldWidget.initialChecklistItemId != widget.initialChecklistItemId) {
      selectedMilestoneId = _clean(widget.initialMilestoneId);
      selectedChecklistItemId = _clean(widget.initialChecklistItemId);
    }
  }

  String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<List<ProjectMilestone>> _loadMilestones() async {
    final rows = await MilestoneRepository.fetchMilestones(
      objectName: widget.objectName,
      includePast: true,
    );

    final selectedMilestone = rows.where((milestone) {
      return milestone.id == selectedMilestoneId;
    }).firstOrNull;

    if (selectedMilestone == null) {
      selectedMilestoneId = null;
      selectedChecklistItemId = null;
      return rows;
    }

    final itemExists = selectedMilestone.items.any((item) {
      return item.id == selectedChecklistItemId;
    });
    if (!itemExists) {
      selectedChecklistItemId = selectedMilestone.items.isEmpty
          ? null
          : selectedMilestone.items.first.id;
    }

    return rows;
  }

  Future<void> _reload() async {
    final next = _loadMilestones();
    if (mounted) setState(() => milestonesFuture = next);
    await next;
  }

  void _notifySelection() {
    widget.onChanged(
      TaskMilestoneSelection(
        milestoneId: selectedMilestoneId,
        checklistItemId: selectedChecklistItemId,
      ),
    );
  }

  void _selectMilestone(
    String? value,
    List<ProjectMilestone> milestones,
  ) {
    if (!widget.canSelect || busy) return;

    if (value == null || value == _notLinkedValue) {
      setState(() {
        selectedMilestoneId = null;
        selectedChecklistItemId = null;
      });
      _notifySelection();
      return;
    }

    final milestone = milestones.firstWhere((item) => item.id == value);
    setState(() {
      selectedMilestoneId = milestone.id;
      selectedChecklistItemId = milestone.items.isEmpty
          ? null
          : milestone.items.first.id;
    });
    _notifySelection();
  }

  void _selectChecklistItem(String itemId) {
    if (!widget.canSelect || busy) return;
    setState(() => selectedChecklistItemId = itemId);
    _notifySelection();
  }

  Future<void> _setItemState(
    MilestoneChecklistItem item,
    String state,
  ) async {
    if (!widget.canEditChecklist || busy) return;
    setState(() => busy = true);
    try {
      await MilestoneRepository.updateChecklistState(
        itemId: item.id,
        state: state,
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить пункт: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openItemEditor(
    ProjectMilestone milestone, {
    MilestoneChecklistItem? item,
  }) async {
    if (!widget.canEditChecklist || busy) return;

    final titleController = TextEditingController(text: item?.title ?? '');
    var weight = (item?.weight ?? 10).toDouble().clamp(5, 50);
    var critical = item?.isCritical ?? false;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(item == null ? 'Новый пункт чек-листа' : 'Изменить пункт'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Что должно быть готово',
                        hintText: 'Например: армирование завершено',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text('Вес'),
                        Expanded(
                          child: Slider(
                            min: 5,
                            max: 50,
                            divisions: 9,
                            value: weight,
                            label: '${weight.round()}%',
                            onChanged: (value) {
                              setDialogState(() => weight = value);
                            },
                          ),
                        ),
                        Text('${weight.round()}%'),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: critical,
                      onChanged: (value) {
                        setDialogState(() => critical = value);
                      },
                      title: const Text('Критичный пункт'),
                      subtitle: const Text(
                        'Без него цель не считается полностью готовой',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(item == null ? 'Добавить' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    final title = titleController.text.trim();
    titleController.dispose();
    if (accepted != true || title.isEmpty) return;

    setState(() => busy = true);
    try {
      if (item == null) {
        await MilestoneRepository.addChecklistItem(
          milestoneId: milestone.id,
          title: title,
          weight: weight.round(),
          isCritical: critical,
          sortOrder: milestone.items.length,
        );
      } else {
        await MilestoneRepository.updateChecklistItem(
          itemId: item.id,
          title: title,
          weight: weight.round(),
          isCritical: critical,
        );
      }
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить пункт: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteItem(
    ProjectMilestone milestone,
    MilestoneChecklistItem item,
  ) async {
    if (!widget.canEditChecklist || busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить пункт чек-листа?'),
        content: Text(
          item.tasks.isEmpty
              ? item.title
              : 'К пункту привязано задач: ${item.tasks.length}. Связи будут удалены, сами задачи останутся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      if (selectedChecklistItemId == item.id) {
        selectedChecklistItemId = null;
      }
      await MilestoneRepository.deleteChecklistItem(item.id);
      await _reload();
      final updated = await milestonesFuture;
      final refreshedMilestone = updated.where((value) {
        return value.id == milestone.id;
      }).firstOrNull;
      if (refreshedMilestone != null && selectedChecklistItemId == null) {
        selectedChecklistItemId = refreshedMilestone.items.isEmpty
            ? null
            : refreshedMilestone.items.first.id;
      }
      _notifySelection();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить пункт: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Color _stateColor(MilestoneChecklistItem item) {
    if (item.isBlocked) return const Color(0xFF9A403A);
    if (item.isEffectivelyDone) return const Color(0xFF2E7D52);
    if (item.completionFraction > 0) return const Color(0xFF9A6816);
    return const Color(0xFF6B7075);
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _checklistCard(
    ProjectMilestone milestone,
    MilestoneChecklistItem item,
  ) {
    final selected = selectedChecklistItemId == item.id;
    final stateColor = _stateColor(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF3F4F5) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xFF1F2328) : const Color(0xFFE2E4E7),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.canSelect ? () => _selectChecklistItem(item.id) : null,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<String>(
                value: item.id,
                groupValue: selectedChecklistItemId,
                onChanged: widget.canSelect
                    ? (value) {
                        if (value != null) _selectChecklistItem(value);
                      }
                    : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _statusChip(item.stateTitle, stateColor),
                        _statusChip('Вес ${item.weight}%', const Color(0xFF6B7075)),
                        if (item.isCritical)
                          _statusChip('Критично', const Color(0xFF9A403A)),
                        if (item.tasks.isNotEmpty)
                          _statusChip(
                            'Задачи ${item.doneTaskCount}/${item.tasks.length}',
                            const Color(0xFF6B7075),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.canEditChecklist) ...[
                PopupMenuButton<String>(
                  enabled: !busy,
                  tooltip: 'Состояние пункта',
                  onSelected: (value) => _setItemState(item, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'not_started',
                      child: Text('Не начато'),
                    ),
                    PopupMenuItem(
                      value: 'in_progress',
                      child: Text('В работе'),
                    ),
                    PopupMenuItem(value: 'done', child: Text('Готово')),
                    PopupMenuItem(
                      value: 'blocked',
                      child: Text('Заблокировано'),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Изменить пункт',
                  onPressed: busy
                      ? null
                      : () => _openItemEditor(milestone, item: item),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Удалить пункт',
                  onPressed: busy ? null : () => _deleteItem(milestone, item),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedMilestone(ProjectMilestone milestone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E4E7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      milestone.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${milestone.progressPercent}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${_date(milestone.targetDate)} · '
                '${milestone.location.trim().isEmpty ? milestone.objectName : milestone.location}',
                style: const TextStyle(
                  color: Color(0xFF6B7075),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 11),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: milestone.progress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE0E2E5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Чек-лист цели',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            if (widget.canEditChecklist)
              TextButton.icon(
                onPressed: busy ? null : () => _openItemEditor(milestone),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить пункт'),
              ),
          ],
        ),
        const SizedBox(height: 7),
        if (milestone.items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E4E7)),
            ),
            child: const Text(
              'В этой цели пока нет пунктов. Добавьте первый пункт чек-листа.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ...milestone.items.map((item) => _checklistCard(milestone, item)),
        if (selectedMilestoneId != null && selectedChecklistItemId == null) ...[
          const SizedBox(height: 8),
          const Text(
            'Чтобы привязать задачу, выберите пункт чек-листа.',
            style: TextStyle(
              color: Color(0xFF9A403A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: FutureBuilder<List<ProjectMilestone>>(
        future: milestonesFuture,
        builder: (context, snapshot) {
          final milestones = snapshot.data ?? const <ProjectMilestone>[];
          final selectedMilestone = milestones.where((item) {
            return item.id == selectedMilestoneId;
          }).firstOrNull;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Цель',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Задачу можно оставить без привязки или отнести к ключевой цели объекта.',
                style: TextStyle(color: Color(0xFF6B7075)),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                Row(
                  children: [
                    Expanded(child: Text('Не удалось загрузить цели: ${snapshot.error}')),
                    IconButton(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: selectedMilestoneId ?? _notLinkedValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Привязать к цели',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _notLinkedValue,
                      child: Text('Не привязано'),
                    ),
                    ...milestones.map(
                      (milestone) => DropdownMenuItem(
                        value: milestone.id,
                        child: Text(
                          '${milestone.title} · ${_date(milestone.targetDate)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: widget.canSelect && !busy
                      ? (value) => _selectMilestone(value, milestones)
                      : null,
                ),
                if (milestones.isEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'На объекте пока нет ключевых целей. Создать цель можно на главной.',
                    style: TextStyle(color: Color(0xFF6B7075)),
                  ),
                ],
                if (selectedMilestone != null)
                  _selectedMilestone(selectedMilestone),
              ],
            ],
          );
        },
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
