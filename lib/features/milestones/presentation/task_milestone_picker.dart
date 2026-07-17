import 'package:flutter/material.dart';

import '../data/milestone_repository.dart';
import '../models/milestone_models.dart';

class TaskMilestoneSelection {
  final String? milestoneId;
  final String? checklistItemId;
  final String? checklistTitle;

  const TaskMilestoneSelection({
    required this.milestoneId,
    required this.checklistItemId,
    this.checklistTitle,
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
  static const String _ordinaryValue = 'ordinary';
  static const String _goalValue = 'goal';

  late Future<List<ProjectMilestone>> milestonesFuture;
  late bool linkedToGoal;
  String? selectedMilestoneId;
  String? selectedChecklistItemId;

  @override
  void initState() {
    super.initState();
    selectedMilestoneId = _clean(widget.initialMilestoneId);
    selectedChecklistItemId = _clean(widget.initialChecklistItemId);
    linkedToGoal = selectedMilestoneId != null;
    milestonesFuture = _loadMilestones();
  }

  @override
  void didUpdateWidget(covariant TaskMilestonePicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.objectName.trim() != widget.objectName.trim()) {
      selectedMilestoneId = _clean(widget.initialMilestoneId);
      selectedChecklistItemId = _clean(widget.initialChecklistItemId);
      linkedToGoal = selectedMilestoneId != null;
      milestonesFuture = _loadMilestones();
      return;
    }

    if (oldWidget.initialMilestoneId != widget.initialMilestoneId ||
        oldWidget.initialChecklistItemId != widget.initialChecklistItemId) {
      selectedMilestoneId = _clean(widget.initialMilestoneId);
      selectedChecklistItemId = _clean(widget.initialChecklistItemId);
      linkedToGoal = selectedMilestoneId != null;
    }
  }

  String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Future<List<ProjectMilestone>> _loadMilestones() async {
    final rows = await MilestoneRepository.fetchMilestones(
      objectName: widget.objectName,
      includePast: true,
    );

    if (!linkedToGoal || selectedMilestoneId == null) {
      _notifyAfterBuild(rows);
      return rows;
    }

    final selectedMilestone = rows.where((milestone) {
      return milestone.id == selectedMilestoneId;
    }).firstOrNull;

    if (selectedMilestone == null) {
      selectedMilestoneId = null;
      selectedChecklistItemId = null;
      linkedToGoal = false;
      _notifyAfterBuild(rows);
      return rows;
    }

    final itemExists = selectedMilestone.items.any((item) {
      return item.id == selectedChecklistItemId;
    });
    if (!itemExists) selectedChecklistItemId = null;

    _notifyAfterBuild(rows);
    return rows;
  }

  void _notifyAfterBuild(List<ProjectMilestone> milestones) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifySelection(milestones);
    });
  }

  void _notifySelection(List<ProjectMilestone> milestones) {
    MilestoneChecklistItem? selectedItem;
    final milestone = milestones.where((item) {
      return item.id == selectedMilestoneId;
    }).firstOrNull;
    if (milestone != null) {
      selectedItem = milestone.items.where((item) {
        return item.id == selectedChecklistItemId;
      }).firstOrNull;
    }

    widget.onChanged(
      TaskMilestoneSelection(
        milestoneId: linkedToGoal ? selectedMilestoneId : null,
        checklistItemId: linkedToGoal ? selectedChecklistItemId : null,
        checklistTitle: selectedItem?.title,
      ),
    );
  }

  void _selectMode(String? value, List<ProjectMilestone> milestones) {
    if (!widget.canSelect) return;
    final nextLinked = value == _goalValue;
    setState(() {
      linkedToGoal = nextLinked;
      if (!nextLinked) {
        selectedMilestoneId = null;
        selectedChecklistItemId = null;
      }
    });
    _notifySelection(milestones);
  }

  void _selectMilestone(String? value, List<ProjectMilestone> milestones) {
    if (!widget.canSelect) return;
    setState(() {
      selectedMilestoneId = _clean(value);
      selectedChecklistItemId = null;
    });
    _notifySelection(milestones);
  }

  void _selectChecklistItem(String? value, List<ProjectMilestone> milestones) {
    if (!widget.canSelect) return;
    setState(() => selectedChecklistItemId = _clean(value));
    _notifySelection(milestones);
  }

  Future<void> _reload() async {
    final next = _loadMilestones();
    if (mounted) setState(() => milestonesFuture = next);
    await next;
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
                'Тип задачи',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('task-mode-$linkedToGoal'),
                initialValue: linkedToGoal ? _goalValue : _ordinaryValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Задача',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: _ordinaryValue,
                    child: Text('Обычная задача'),
                  ),
                  DropdownMenuItem(value: _goalValue, child: Text('По цели')),
                ],
                onChanged: widget.canSelect
                    ? (value) => _selectMode(value, milestones)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                linkedToGoal
                    ? 'Выбери цель и одну конкретную работу.'
                    : 'Без привязки к цели.',
                style: const TextStyle(color: Color(0xFF6B7075)),
              ),
              if (linkedToGoal) ...[
                const SizedBox(height: 14),
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
                      Expanded(
                        child: Text(
                          'Не удалось загрузить цели: ${snapshot.error}',
                        ),
                      ),
                      IconButton(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  )
                else if (milestones.isEmpty)
                  const Text(
                    'На объекте пока нет целей. Создать цель можно на главной.',
                    style: TextStyle(color: Color(0xFF6B7075)),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('goal-$selectedMilestoneId'),
                    initialValue: selectedMilestoneId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Цель',
                      hintText: 'Выберите цель',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: milestones.map((milestone) {
                      return DropdownMenuItem(
                        value: milestone.id,
                        child: Text(
                          milestone.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: widget.canSelect
                        ? (value) => _selectMilestone(value, milestones)
                        : null,
                  ),
                  if (selectedMilestone != null) ...[
                    const SizedBox(height: 12),
                    if (selectedMilestone.items.isEmpty)
                      const Text(
                        'В этой цели пока нет работ.',
                        style: TextStyle(color: Color(0xFF6B7075)),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'goal-work-${selectedMilestone.id}-$selectedChecklistItemId',
                        ),
                        initialValue: selectedChecklistItemId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Работа по цели',
                          hintText: 'Выберите одну работу',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.construction_outlined),
                        ),
                        items: selectedMilestone.items.map((item) {
                          return DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: widget.canSelect
                            ? (value) => _selectChecklistItem(value, milestones)
                            : null,
                      ),
                  ],
                ],
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
