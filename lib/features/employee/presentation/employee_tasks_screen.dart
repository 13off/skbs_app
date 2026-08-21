import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_shift_runtime.dart';
import '../data/employee_task_cabinet_repository.dart';
import 'employee_simple_work_screen.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeTasksScreen extends StatefulWidget {
  final AppUserProfile profile;
  final ValueNotifier<String> selectedEmployeeId;

  const EmployeeTasksScreen({
    super.key,
    required this.profile,
    required this.selectedEmployeeId,
  });

  @override
  State<EmployeeTasksScreen> createState() => _EmployeeTasksScreenState();
}

class _EmployeeTasksScreenState extends State<EmployeeTasksScreen> {
  late Future<EmployeeTaskCabinetData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<EmployeeTaskCabinetData> load({bool forceRefresh = false}) async {
    final data = await EmployeeTaskCabinetRepository.fetch(
      employeeId: widget.selectedEmployeeId.value,
      forceRefresh: forceRefresh,
    );
    final employeeId = data.profile.employeeId;
    if (widget.selectedEmployeeId.value != employeeId) {
      widget.selectedEmployeeId.value = employeeId;
    }
    await EmployeeShiftRuntime.instance.bind(employeeId);
    return data;
  }

  Future<void> refresh() async {
    final next = load(forceRefresh: true);
    setState(() => future = next);
    await next;
  }

  Future<void> openTask(String employeeId, EmployeeTaskCabinetTask task) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => EmployeeWorkTaskDetailsScreen(
          employeeId: employeeId,
          task: task,
          onChanged: refresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeTaskCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            title: 'Задачи',
            child: SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return AppPage(
            title: 'Задачи',
            subtitle: 'Не удалось загрузить данные',
            onRefresh: refresh,
            child: _MessageCard(
              title: 'Ошибка загрузки',
              text: cleanError(snapshot.error),
            ),
          );
        }

        final data = snapshot.data!;
        final tasks = data.tasks
            .where((task) => !task.isCompleted)
            .toList(growable: false);

        return AppPage(
          title: 'Задачи',
          subtitle: data.profile.currentObject.trim().isEmpty
              ? null
              : 'Объект: ${data.profile.currentObject.trim()}',
          onRefresh: refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tasks.isEmpty)
                const _MessageCard(
                  title: 'Активных задач пока нет',
                  text:
                      'Назначенная мастером задача появится здесь автоматически.',
                )
              else
                for (var index = 0; index < tasks.length; index++) ...[
                  PremiumWorkCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      onTap: () =>
                          openTask(data.profile.employeeId, tasks[index]),
                      leading: const _IconBox(Icons.assignment_outlined),
                      title: Text(
                        tasks[index].work.trim().isEmpty
                            ? 'Рабочая задача'
                            : tasks[index].work,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(taskMeta(tasks[index])),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                  if (index != tasks.length - 1) const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String title;
  final String text;

  const _MessageCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    );
  }
}

String taskMeta(EmployeeTaskCabinetTask task) {
  return <String>[
    if (task.axes.trim().isNotEmpty) task.axes.trim(),
    if (task.objectName.trim().isNotEmpty) task.objectName.trim(),
    if (task.date != null) formatDate(task.date!),
  ].join(' · ');
}

String formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String cleanError(Object? value) {
  final text = value?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Не удалось выполнить действие' : text;
}
