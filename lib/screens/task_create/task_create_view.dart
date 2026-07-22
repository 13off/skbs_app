part of '../add_task_screen.dart';

extension _TaskCreateView on _AddTaskScreenState {
  Widget buildTaskCreateView() {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Новая задача'),
      ),
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
            onPressed: widget.allowAnyDate ? pickDate : null,
            icon: const Icon(Icons.calendar_month),
            label: Text('Дата задачи: ${formatDate(selectedDate)}'),
          ),
          const SizedBox(height: 16),
          buildMilestoneSection(),
          const SizedBox(height: 16),
          buildTaskFields(),
          const SizedBox(height: 16),
          buildAssigneesBlock(),
          const SizedBox(height: 16),
          buildPhotosBlock(),
          if (errorText != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppAdaptivePalette.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppAdaptivePalette.danger.withValues(alpha: 0.32),
                ),
              ),
              child: Text(
                errorText!,
                style: TextStyle(
                  color: AppAdaptivePalette.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: isLoadingPolicy ? null : saveTask,
              icon: const Icon(Icons.save),
              label: const Text('Сохранить задачу'),
            ),
          ),
        ],
      ),
    );
  }
}
