// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of 'task_details_editor_screen.dart';

extension _TaskDetailsPhotoViewer on _TaskDetailsScreenState {
  Future<void> openPhotoInApp(TaskPhotoData photo) async {
    if (photo.storagePath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Фото сохранено на устройстве и станет доступно после отправки на сервер',
          ),
        ),
      );
      return;
    }

    try {
      final url = await TaskPhotoSignedUrlCache.getSignedUrl(photo);
      if (!mounted) return;

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Закрыть фотографию',
        barrierColor: Colors.black.withValues(alpha: 0.94),
        transitionDuration: const Duration(milliseconds: 220),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
              child: child,
            ),
          );
        },
        pageBuilder: (context, animation, secondaryAnimation) {
          return SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      boundaryMargin: const EdgeInsets.all(40),
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) {
                            return const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 46,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Не удалось показать фотографию',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            photo.originalName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              shadows: <Shadow>[
                                Shadow(color: Colors.black, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: Colors.black.withValues(alpha: 0.54),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Закрыть',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка открытия фото: $error')),
      );
    }
  }

  Future<void> deletePhotoFromTile(TaskPhotoData photo) async {
    await deletePhoto(photo);
    if (!mounted) return;
    final stillExists = photos.any((item) => item.id == photo.id);
    if (!stillExists) {
      TaskPhotoSignedUrlCache.evict(photo);
      final taskId = widget.task.id?.trim() ?? '';
      if (taskId.isNotEmpty) {
        await OfflineSyncService.saveSnapshot(
          'task_photos::$taskId',
          photos
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'task_id': item.taskId,
                  'storage_path': item.storagePath,
                  'original_name': item.originalName,
                  'photo_stage': item.photoStage,
                  'created_at': item.createdAt.toUtc().toIso8601String(),
                },
              )
              .toList(growable: false),
        );
      }
    }
  }
}
