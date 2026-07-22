import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/act_context_repository.dart';
import '../data/act_generator.dart';
import '../models/task_act_context.dart';
import '../models/task_item_data.dart';

class ActPreviewScreen extends StatefulWidget {
  final List<TaskItemData> tasks;
  final DateTime date;

  const ActPreviewScreen({super.key, required this.tasks, required this.date});

  @override
  State<ActPreviewScreen> createState() => _ActPreviewScreenState();
}

class _ActPreviewScreenState extends State<ActPreviewScreen> {
  late final List<TaskItemData> completedTasks;
  late final String formattedDate;

  Map<String, TaskActContext> contextByTaskId =
      const <String, TaskActContext>{};
  bool isLoadingContext = true;
  bool isDownloading = false;
  String? errorText;

  @override
  void initState() {
    super.initState();

    completedTasks = widget.tasks
        .where((task) => task.status == 'Выполнено')
        .toList(growable: false);
    formattedDate = DateFormat('dd.MM.yyyy').format(widget.date);
    loadActContext();
  }

  Future<void> loadActContext() async {
    if (completedTasks.isEmpty) {
      if (mounted) setState(() => isLoadingContext = false);
      return;
    }

    setState(() {
      isLoadingContext = true;
      errorText = null;
    });

    try {
      final result = await ActContextRepository.fetchForTasks(completedTasks);
      if (!mounted) return;
      setState(() {
        contextByTaskId = result;
        isLoadingContext = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoadingContext = false;
        errorText = 'Не удалось загрузить прогресс целей: $error';
      });
    }
  }

  Future<void> downloadAct() async {
    if (isDownloading || isLoadingContext) return;

    if (completedTasks.isEmpty) {
      setState(() => errorText = 'Нет выполненных задач для акта');
      return;
    }

    setState(() {
      isDownloading = true;
      errorText = null;
    });

    try {
      await ActGenerator.downloadAct(
        tasks: completedTasks,
        date: widget.date,
        contextByTaskId: contextByTaskId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Акт скачан')));
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Ошибка: $error');
    } finally {
      if (mounted) setState(() => isDownloading = false);
    }
  }

  Widget buildTaskCard(TaskItemData task) {
    final taskId = task.id?.trim() ?? '';
    final goalContext = contextByTaskId[taskId];

    return Card(
      elevation: 0,
      color: const Color(0xFFF7F8FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.axes,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text('Выполнены работы: ${task.work}.'),
            if (goalContext != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Выполнение за день: +${goalContext.taskProgressPercent}%',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Цель: ${goalContext.milestoneTitle} — '
                '${goalContext.milestoneProgressPercent}%',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              if (goalContext.milestoneLocation.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(goalContext.milestoneLocation),
              ],
              const SizedBox(height: 7),
              Text(
                'Пункт чек-листа: ${goalContext.checklistTitle} — '
                '${goalContext.checklistProgressPercent}% '
                '(${goalContext.checklistStateTitle.toLowerCase()})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),title: const Text('Черновик акта')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Акт выполненных работ',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            formattedDate,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Text(
            'В акт попадают выполненные задачи. Для связанных задач '
            'добавляется дневной вклад, готовность цели и пункта чек-листа.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          if (isLoadingContext)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (completedTasks.isEmpty)
            const Text(
              'Нет выполненных задач для акта',
              style: TextStyle(fontSize: 16),
            )
          else
            ...completedTasks.map(buildTaskCard),
          if (errorText != null) ...[
            const SizedBox(height: 16),
            Text(
              errorText!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed:
                  isDownloading || isLoadingContext || completedTasks.isEmpty
                      ? null
                      : downloadAct,
              icon: isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(isDownloading ? 'Скачиваем...' : 'Скачать акт'),
            ),
          ),
        ],
      ),
    );
  }
}
