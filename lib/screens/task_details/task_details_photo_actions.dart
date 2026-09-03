// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of 'task_details_editor_screen.dart';

extension _TaskDetailsPhotoActions on _TaskDetailsScreenState {
  Future<void> addPhotosFast(String photoStage) async {
    if (!canEdit || pickingPhotoStage != null) return;
    if (photoStage != 'before' && photoStage != 'after') {
      throw ArgumentError.value(photoStage, 'photoStage');
    }

    final taskId = widget.task.id;
    if (taskId == null || taskId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сначала сохраните задачу')));
      return;
    }

    setState(() {
      pickingPhotoStage = photoStage;
      preparingPhotoCompleted = 0;
      preparingPhotoTotal = 0;
      photoUploadProgress = null;
      lastRenderedUploadPercent = -1;
      errorText = null;
    });

    try {
      final pickedPhotos = await TaskPhotoBrowserService.pickPhotoFiles(
        onPrepareProgress: (completed, total) {
          if (!mounted || pickingPhotoStage != photoStage) return;
          setState(() {
            preparingPhotoCompleted = completed;
            preparingPhotoTotal = total;
          });
        },
      );
      if (pickedPhotos.isEmpty) return;

      List<TaskPhotoData> uploadedPhotos;
      try {
        uploadedPhotos = await TaskPhotoRepository.uploadPhotos(
          taskId: taskId,
          photos: pickedPhotos,
          photoStage: photoStage,
          onProgress: (progress) {
            if (!mounted || pickingPhotoStage != photoStage) return;
            final previous = photoUploadProgress;
            final percentChanged = progress.percent != lastRenderedUploadPercent;
            final completedChanged =
                previous == null ||
                previous.completedFiles != progress.completedFiles;
            if (!percentChanged && !completedChanged) return;

            setState(() {
              photoUploadProgress = progress;
              lastRenderedUploadPercent = progress.percent;
            });
          },
        );
      } catch (_) {
        // Если Storage недоступен, TaskRepository сохранит байты в локальной
        // очереди и отправит их после восстановления соединения.
        uploadedPhotos = await TaskRepository.uploadPhotosForTask(
          taskId: taskId,
          photos: pickedPhotos,
          photoStage: photoStage,
        );
      }
      if (!mounted) return;

      setState(() => photos = <TaskPhotoData>[...uploadedPhotos, ...photos]);
      final queuedOffline = uploadedPhotos.any(
        (photo) => photo.storagePath.trim().isEmpty,
      );
      final count = uploadedPhotos.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queuedOffline
                ? 'Фото сохранены на устройстве и отправятся на сервер при появлении связи'
                : count == 1
                ? 'Фотография добавлена'
                : 'Добавлено фотографий: $count',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Ошибка загрузки фото: $error');
    } finally {
      if (mounted && pickingPhotoStage == photoStage) {
        setState(() {
          pickingPhotoStage = null;
          preparingPhotoCompleted = 0;
          preparingPhotoTotal = 0;
          photoUploadProgress = null;
          lastRenderedUploadPercent = -1;
        });
      }
    }
  }

  Widget buildFastPhotosBlock({
    required String photoStage,
    required String title,
    required String emptyText,
  }) {
    final stagePhotos = photos
        .where((photo) => photo.photoStage == photoStage)
        .toList();
    final isThisStagePicking = pickingPhotoStage == photoStage;
    final progress = isThisStagePicking ? photoUploadProgress : null;
    final isPreparing =
        isThisStagePicking && progress == null && preparingPhotoTotal > 0;
    final minimum = photoStage == 'before'
        ? (policy.requireBeforePhoto ? policy.minBeforePhotos : 0)
        : (policy.requireAfterPhotoOnComplete ? policy.minAfterPhotos : 0);

    String buttonLabel() {
      if (progress != null) {
        if (progress.percent >= 100) {
          return 'Загружено 100% · сохраняем';
        }
        return 'Загрузка ${progress.percent}% · '
            '${progress.completedFiles}/${progress.totalFiles}';
      }
      if (isPreparing) {
        return 'Подготовка $preparingPhotoCompleted/$preparingPhotoTotal';
      }
      return stagePhotos.isEmpty
          ? 'Добавить фотографии'
          : 'Добавить ещё фотографии';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (stagePhotos.isNotEmpty)
                Text(
                  '${stagePhotos.length}',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (minimum > 0) ...[
            const SizedBox(height: 5),
            Text(
              'Минимум: $minimum',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: pickingPhotoStage != null || !canEdit
                  ? null
                  : () => addPhotosFast(photoStage),
              icon: isPreparing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : progress != null
                  ? const Icon(Icons.cloud_upload_outlined)
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(buttonLabel()),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 6,
              ),
            ),
          ],
          if (stagePhotos.isEmpty) ...[
            const SizedBox(height: 12),
            Text(emptyText),
          ] else ...[
            const SizedBox(height: 14),
            TaskPhotoGrid<TaskPhotoData>(
              items: stagePhotos,
              itemBuilder: (context, photo) => buildPhotoTile(photo),
            ),
          ],
        ],
      ),
    );
  }
}
