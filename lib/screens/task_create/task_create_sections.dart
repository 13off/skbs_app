part of '../add_task_screen.dart';

extension _TaskCreateSections on _AddTaskScreenState {
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

  Widget buildMilestoneSection() {
    return TaskMilestonePicker(
      objectName: widget.objectName,
      initialMilestoneId: selectedMilestoneId,
      initialChecklistItemId: selectedChecklistItemId,
      canSelect: true,
      canEditChecklist: false,
      onChanged: changeMilestone,
    );
  }

  Widget buildTaskFields() {
    return Column(
      children: [
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
        if (!isGoalTask) ...[
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
        ],
      ],
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
          Text(
            policy.requireBeforePhoto
                ? 'Фото «До» — обязательно'
                : 'Фото «До» — по желанию',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            policy.requireBeforePhoto
                ? 'Нужно прикрепить минимум ${policy.minBeforePhotos}. Можно добавить несколько снимков.'
                : 'На этом объекте задачу можно создать без фотографии.',
          ),
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
              label: const Text('Добавить фото «До»'),
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
                        onTap: () => removePhoto(photo),
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
}
