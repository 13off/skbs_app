part of '../add_task_screen.dart';

extension _TaskCreateView on _AddTaskScreenState {
  Widget buildTaskCreateView() {
    final editingDraft = widget.sourceDraftId?.trim().isNotEmpty == true;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          widget.isRepeat
              ? 'Повторить задачу'
              : editingDraft
              ? 'Черновик задачи'
              : 'Новая задача',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.isRepeat
                ? 'Новая задача на основе существующей'
                : editingDraft
                ? 'Продолжите заполнение черновика'
                : 'Прораб добавляет задачу на объект',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
          if (widget.allowDraft) ...[
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: isLoadingPolicy ? null : saveDraft,
                icon: const Icon(Icons.drafts_outlined),
                label: Text(
                  editingDraft ? 'Обновить черновик' : 'Сохранить черновик',
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: isLoadingPolicy ? null : saveTask,
              icon: const Icon(Icons.save),
              label: Text(
                widget.isRepeat ? 'Создать копию задачи' : 'Сохранить задачу',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
