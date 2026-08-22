import 'dart:typed_data';

class TaskPhotoData {
  final String id;
  final String taskId;
  final String storagePath;
  final String thumbnailPath;
  final String originalName;
  final String photoStage;
  final DateTime createdAt;

  const TaskPhotoData({
    required this.id,
    required this.taskId,
    required this.storagePath,
    this.thumbnailPath = '',
    required this.originalName,
    required this.photoStage,
    required this.createdAt,
  });

  bool get isBefore => photoStage == 'before';
  bool get isAfter => photoStage == 'after';

  String get previewStoragePath {
    final cleanThumbnail = thumbnailPath.trim();
    return cleanThumbnail.isEmpty ? storagePath : cleanThumbnail;
  }

  factory TaskPhotoData.fromSupabase(Map<String, dynamic> json) {
    return TaskPhotoData(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      storagePath: json['storage_path']?.toString() ?? '',
      thumbnailPath: json['thumbnail_path']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? 'Фото',
      photoStage: json['photo_stage']?.toString() == 'after'
          ? 'after'
          : 'before',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class TaskPhotoFile {
  final String originalName;
  final String contentType;
  final String extension;
  final Uint8List bytes;
  final Uint8List? thumbnailBytes;
  final String thumbnailContentType;
  final String thumbnailExtension;

  const TaskPhotoFile({
    required this.originalName,
    required this.contentType,
    required this.extension,
    required this.bytes,
    this.thumbnailBytes,
    this.thumbnailContentType = 'image/jpeg',
    this.thumbnailExtension = 'jpg',
  });

  bool get hasThumbnail => thumbnailBytes?.isNotEmpty == true;
}

class TaskPhotoUploadProgress {
  final int loadedBytes;
  final int totalBytes;
  final int completedFiles;
  final int totalFiles;

  const TaskPhotoUploadProgress({
    required this.loadedBytes,
    required this.totalBytes,
    required this.completedFiles,
    required this.totalFiles,
  });

  double get fraction {
    if (totalBytes <= 0) return 0;
    return (loadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get percent => (fraction * 100).floor().clamp(0, 100);
}

typedef TaskPhotoUploadProgressCallback =
    void Function(TaskPhotoUploadProgress progress);
