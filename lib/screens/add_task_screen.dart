import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/employee_repository.dart';
import '../data/task_repository.dart';
import '../features/milestones/presentation/task_milestone_picker.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';

class TaskCreateDraft {
  final TaskItemData task;
  final List<String> assigneeIds;
  final List<TaskPhotoFile> photos;

  const TaskCreateDraft({
    required this.task,
    required this.assigneeIds,
    required this.photos,
  });
}

class AddTaskScreen extends StatefulWidget {
  final DateTime initialDate;
  final String objectName;
  final String? initialMilestoneId;
  final String? initialChecklistItemId;

  const AddTaskScreen({
    super.key,
    required this.initialDate,
    required this.objectName,
    this.initialMilestoneId,
    this.initialChecklistItemId,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final axesController = TextEditingController();
  final workController = TextEditingController();

  late DateTime selectedDate;

  List<Employee> employees = [];
  final Set<String> selectedAssigneeIds = {};
  final List<TaskPhotoFile> selectedPhotos = [];
  String? selectedMilestoneId;
  String? selectedChecklistItemId;

  bool isLoadingEmployees = false;
  bool isPickingPhotos = false;
  String? errorText;

  @override
  void initState() {
    super.initState();

    selectedDate = widget.initialDate;
    selectedMilestoneId = widget.initialMilestoneId;
    selectedChecklistItemId = widget.initialChecklistItemId;
    loadEmployees();
  }

  @override
  void dispose() {
    axesController.dispose();
    workController.dispose();
    super.dispose();
  }

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String assigneeTitle() {
    if (selectedAssigneeIds.isEmpty) {
      return 'Исполнители не выбраны';
    }

    return 'Выбрано: ${selectedAssigneeIds.length}';
  }

  String selectedEmployeeNames() {
    final selectedEmployees = employees.where((employee) {
      return employee.id != null && selectedAssigneeIds.contains(employee.id);
    }).toList();

    if (selectedEmployees.isEmpty) {
      return 'Нажмите, чтобы выбрать сотрудников';
    }

    return selectedEmployees.map((employee) => employee.name).join(', ');
  }

  Future<void> loadEmployees() async {
    setState(() {
      isLoadingEmployees = true;
      errorText = null;
    });

    try {
      final result = await EmployeeRepository.fetchEmployees(
        objectName: widget.objectName,
      );

      if (!mounted) return;

      setState(() {
        employees = result.where((employee) {
          return employee.id != null && employee.id!.isNotEmpty;
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки сотрудников: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingEmployees = false;
        });
      }
    }
  }

  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Выберите дату задачи',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = pickedDate;
    });
  }

  Future<void> openAssigneesPicker() async {
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('На объекте нет сотрудников')),
      );
      return;
    }

    final tempSelectedIds = Set<String>.from(selectedAssigneeIds);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(18),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Исполнители',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: employees.map((employee) {
                          final employeeId = employee.id!;
                          final selected = tempSelectedIds.contains(employeeId);

                          return CheckboxListTile(
                            value: selected,
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempSelectedIds.add(employeeId);
                                } else {
                                  tempSelectedIds.remove(employeeId);
                                }
                              });
                            },
                            title: Text(
                              employee.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(employee.position),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedIds.clear();
                              });
                            },
                            child: const Text('Очистить'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(context, tempSelectedIds);
                            },
                            child: const Text('Готово'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() {
      selectedAssigneeIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> pickPhotos() async {
    setState(() {
      isPickingPhotos = true;
      errorText = null;
    });

    try {
      final photos = await TaskRepository.pickPhotoFiles();

      if (!mounted || photos.isEmpty) return;

      setState(() {
        selectedPhotos.addAll(photos);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка выбора фото: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isPickingPhotos = false;
        });
      }
    }
  }

  void removePhoto(TaskPhotoFile photo) {
    setState(() {
      selectedPhotos.remove(photo);
    });
  }

  void saveTask() {
    final axes = axesController.text.trim();
    final work = workController.text.trim();

    if (axes.isEmpty || work.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполни оси и вид работ')));
      return;
    }

    if (selectedMilestoneId != null && selectedChecklistItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выбери пункт чек-листа выбранной цели'),
        ),
      );
      return;
    }

    final newTask = TaskItemData(
      axes,
      work,
      'Запланировано',
      selectedDate,
      objectName: widget.objectName,
      milestoneId: selectedMilestoneId ?? '',
      checklistItemId: selectedChecklistItemId ?? '',
    );

    Navigator.pop(
      context,
      TaskCreateDraft(
        task: newTask,
        assigneeIds: selectedAssigneeIds.toList(),
        photos: List<TaskPhotoFile>.from(selectedPhotos),
      ),
    );
  }

  Widget buildObjectCard() {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: ListTile(
        leading: const Icon(Icons.apartment_outlined),
        title: const Text('Объект'),
        subtitle: Text(
          widget.objectName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget buildAssigneesBlock() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isLoadingEmployees ? null : openAssigneesPicker,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.groups_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoadingEmployees
                        ? 'Загружаем сотрудников...'
                        : assigneeTitle(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedEmployeeNames(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }

  Widget buildPhotosBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Фото к задаче',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text('Можно прикрепить несколько фото: JPG, PNG, WEBP.'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isPickingPhotos ? null : pickPhotos,
              icon: isPickingPhotos
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Добавить фото'),
            ),
          ),
          if (selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedPhotos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final photo = selectedPhotos[index];

                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(photo.bytes, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () {
                          removePhoto(photo);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая задача')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Прораб добавляет задачу на объект',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 14),

          buildObjectCard(),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text('Дата задачи: ${formatDate(selectedDate)}'),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: axesController,
            decoration: InputDecoration(
              labelText: 'Оси',
              hintText: 'Например: Оси 1-4 / А-Б',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: workController,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Вид работ',
              hintText: 'Например: Армирование плиты',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TaskMilestonePicker(
            objectName: widget.objectName,
            initialMilestoneId: selectedMilestoneId,
            initialChecklistItemId: selectedChecklistItemId,
            canSelect: true,
            canEditChecklist: true,
            onChanged: (selection) {
              selectedMilestoneId = selection.milestoneId;
              selectedChecklistItemId = selection.checklistItemId;
            },
          ),

          const SizedBox(height: 16),

          buildAssigneesBlock(),

          const SizedBox(height: 16),

          buildPhotosBlock(),

          if (errorText != null) ...[
            const SizedBox(height: 14),
            Text(errorText!, style: const TextStyle(color: Colors.red)),
          ],

          const SizedBox(height: 24),

          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: saveTask,
              icon: const Icon(Icons.save),
              label: const Text('Сохранить задачу'),
            ),
          ),
        ],
      ),
    );
  }
}
