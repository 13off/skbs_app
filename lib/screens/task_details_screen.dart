import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/employee_repository.dart';
import '../data/task_repository.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskItemData task;

  const TaskDetailsScreen({super.key, required this.task});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late final TextEditingController axesController;
  late final TextEditingController workController;
  late final TextEditingController notDoneCommentController;

  late DateTime selectedDate;
  late String selectedStatus;

  List<Employee> employees = [];
  final Set<String> selectedAssigneeIds = {};
  final Set<String> originalAssigneeIds = {};
  List<TaskPhotoData> photos = [];
  final Map<String, Future<String>> signedUrlFutures = {};
  int _loadToken = 0;

  bool isLoading = false;
  bool isSaving = false;
  bool isPickingPhotos = false;
  String? errorText;

  final statuses = const ['Запланировано', 'Выполнено'];

  @override
  void initState() {
    super.initState();

    axesController = TextEditingController(text: widget.task.axes);
    workController = TextEditingController(text: widget.task.work);
    notDoneCommentController = TextEditingController(
      text: widget.task.notDoneComment,
    );
    selectedDate = widget.task.date;
    selectedStatus = statuses.contains(widget.task.status)
        ? widget.task.status
        : 'Запланировано';

    loadTaskDetails();
  }

  @override
  void dispose() {
    axesController.dispose();
    workController.dispose();
    notDoneCommentController.dispose();
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

  Future<String> signedUrlFuture(TaskPhotoData photo) {
    return signedUrlFutures.putIfAbsent(
      photo.id,
      () => TaskRepository.createTaskPhotoSignedUrl(photo),
    );
  }

  Future<void> loadTaskDetails() async {
    final taskId = widget.task.id;

    if (taskId == null || taskId.isEmpty) {
      return;
    }

    final token = ++_loadToken;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await Future.wait([
        EmployeeRepository.fetchEmployees(objectName: widget.task.objectName),
        TaskRepository.fetchTaskAssigneeIds(taskId),
        TaskRepository.fetchTaskPhotos(taskId),
      ]);

      if (!mounted || token != _loadToken) return;

      final loadedEmployees = result[0] as List<Employee>;
      final loadedAssigneeIds = TaskRepository.cleanAssigneeIdSet(
        result[1] as List<String>,
      );
      final loadedPhotos = result[2] as List<TaskPhotoData>;

      setState(() {
        employees = loadedEmployees.where((employee) {
          return employee.id != null && employee.id!.isNotEmpty;
        }).toList();
        selectedAssigneeIds
          ..clear()
          ..addAll(loadedAssigneeIds);
        originalAssigneeIds
          ..clear()
          ..addAll(loadedAssigneeIds);
        photos = loadedPhotos;
        signedUrlFutures.clear();
        isLoading = false;
        errorText = null;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;

      setState(() {
        isLoading = false;
        errorText = 'Ошибка загрузки задачи: $e';
      });
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

  Future<void> addPhotos() async {
    final taskId = widget.task.id;

    if (taskId == null || taskId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сначала сохраните задачу')));
      return;
    }

    setState(() {
      isPickingPhotos = true;
      errorText = null;
    });

    try {
      final pickedPhotos = await TaskRepository.pickPhotoFiles();

      if (pickedPhotos.isEmpty) return;

      final uploadedPhotos = await TaskRepository.uploadPhotosForTask(
        taskId: taskId,
        photos: pickedPhotos,
      );

      if (!mounted) return;

      setState(() {
        photos = [...uploadedPhotos, ...photos];
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Фото добавлены')));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки фото: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isPickingPhotos = false;
        });
      }
    }
  }

  Future<void> openPhoto(TaskPhotoData photo) async {
    try {
      await TaskRepository.openTaskPhoto(photo);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка открытия фото: $e')));
    }
  }

  Future<void> saveChanges() async {
    final taskId = widget.task.id;
    final axes = axesController.text.trim();
    final work = workController.text.trim();
    final notDoneComment = notDoneCommentController.text.trim();

    if (taskId == null || taskId.isEmpty) {
      return;
    }

    if (axes.isEmpty || work.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполни оси и вид работ')));
      return;
    }

    final taskDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final isPastOrToday = !taskDate.isAfter(cleanToday);

    if (selectedStatus != 'Выполнено' &&
        isPastOrToday &&
        notDoneComment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажи причину, почему задача не выполнена'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      final updatedTask = widget.task.copyWith(
        axes: axes,
        work: work,
        status: selectedStatus,
        date: selectedDate,
        notDoneComment: selectedStatus == 'Выполнено' ? '' : notDoneComment,
      );

      await TaskRepository.saveTaskAssigneesIfChanged(
        taskId: taskId,
        previousAssigneeIds: originalAssigneeIds,
        nextAssigneeIds: selectedAssigneeIds,
      );

      if (!mounted) return;

      originalAssigneeIds
        ..clear()
        ..addAll(selectedAssigneeIds);

      Navigator.pop(context, updatedTask);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка сохранения задачи: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить задачу?'),
          content: const Text('Задача, исполнители и фото будут удалены.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    Navigator.pop(context, 'delete');
  }

  Widget buildAssigneesBlock() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isLoading ? null : openAssigneesPicker,
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
                    assigneeTitle(),
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

  Widget buildPhotoTile(TaskPhotoData photo) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        openPhoto(photo);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<String>(
              future: signedUrlFuture(photo),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_outlined),
                  );
                }

                return Image.network(snapshot.data!, fit: BoxFit.cover);
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(7),
                color: Colors.black54,
                child: Text(
                  photo.originalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
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
            'Фото',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isPickingPhotos ? null : addPhotos,
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
          if (photos.isEmpty) ...[
            const SizedBox(height: 12),
            const Text('Фото пока не прикреплены'),
          ] else ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                return buildPhotoTile(photos[index]);
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = selectedStatus == 'Выполнено';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Задача'),
        actions: [
          IconButton(
            tooltip: 'Удалить',
            onPressed: isSaving ? null : confirmDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.task.objectName,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Детали задачи',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: isSaving ? null : pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text('Дата задачи: ${formatDate(selectedDate)}'),
          ),

          const SizedBox(height: 14),

          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            value: done,
            onChanged: isSaving
                ? null
                : (value) {
                    setState(() {
                      selectedStatus = value ? 'Выполнено' : 'Запланировано';

                      if (value) {
                        notDoneCommentController.clear();
                      }
                    });
                  },
            title: const Text(
              'Задача выполнена',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              done ? 'Статус: Выполнено' : 'Статус: Запланировано',
            ),
          ),

          if (!done) ...[
            const SizedBox(height: 14),
            TextField(
              controller: notDoneCommentController,
              enabled: !isSaving,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Причина невыполнения',
                hintText:
                    'Например: не успели, не было материала, не вышли люди',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Оси',
                style: TextStyle(
                  color: Color(0xFF6B7075),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          TextField(
            controller: axesController,
            enabled: !isSaving,
            decoration: InputDecoration(
              hintText: 'Укажите оси',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Вид работ',
                style: TextStyle(
                  color: Color(0xFF6B7075),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          TextField(
            controller: workController,
            enabled: !isSaving,
            minLines: 3,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: 'Опишите выполненные работы',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            buildAssigneesBlock(),

          const SizedBox(height: 16),

          buildPhotosBlock(),

          if (errorText != null) ...[
            const SizedBox(height: 14),
            Text(errorText!, style: const TextStyle(color: Colors.red)),
          ],

          const SizedBox(height: 22),

          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: isSaving ? null : saveChanges,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}
