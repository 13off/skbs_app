import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/act_generator.dart';
import '../models/task_item_data.dart';

class ActPreviewScreen extends StatefulWidget {
  final List<TaskItemData> tasks;
  final DateTime date;

  const ActPreviewScreen({super.key, required this.tasks, required this.date});

  @override
  State<ActPreviewScreen> createState() => _ActPreviewScreenState();
}

class _ActPreviewScreenState extends State<ActPreviewScreen> {
  bool isDownloading = false;
  String? errorText;

  List<TaskItemData> get completedTasks {
    return List<TaskItemData>.from(
      widget.tasks.where((task) => task.status == 'Выполнено'),
    );
  }

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  Future<void> downloadAct() async {
    final tasksForAct = List<TaskItemData>.from(completedTasks);

    if (tasksForAct.isEmpty) {
      setState(() {
        errorText = 'Нет выполненных задач для акта';
      });
      return;
    }

    setState(() {
      isDownloading = true;
      errorText = null;
    });

    try {
      await ActGenerator.downloadAct(tasks: tasksForAct, date: widget.date);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Акт скачан')));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
        });
      }
    }
  }

  Widget buildTaskCard(TaskItemData task) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFEEE7),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = completedTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('Черновик акта')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Акт выполненных работ',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            formatDate(widget.date),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Text(
            'В акт попадают только задачи со статусом “Выполнено”.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 22),

          if (tasks.isEmpty)
            const Text(
              'Нет выполненных задач для акта',
              style: TextStyle(fontSize: 16),
            )
          else
            ...tasks.map(buildTaskCard),

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
              onPressed: isDownloading || tasks.isEmpty ? null : downloadAct,
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
