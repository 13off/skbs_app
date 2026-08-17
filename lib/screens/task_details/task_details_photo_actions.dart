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

      final uploadedPhotos = await TaskPhotoRepository.uploadPhotos(
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
      if (!mounted) return;

      setState(() => photos = <TaskPhotoData>[...uploadedPhotos, ...photos]);
      final count = uploadedPhotos.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
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
}
