import 'package:flutter/material.dart';

import '../models/task_item_data.dart';

class TaskTile extends StatelessWidget {
  final TaskItemData task;
  final VoidCallback onTap;

  const TaskTile({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.orange;

    if (task.status == 'Выполнено') {
      color = Colors.green;
    }

    if (task.status == 'Запланировано') {
      color = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text(
          task.axes,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(task.work),
        trailing: Text(
          task.status,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
