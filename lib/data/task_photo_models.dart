import 'dart:typed_data';

class TaskPhotoData {
  final String id;
  final String taskId;
  final String storagePath;
  final String originalName;
  final String photoStage;
  final String mediaType;
  final String? contentType;
  final int? durationSeconds;
  final int? sizeBytes;
  final DateTime createdAt;

  const TaskPhotoData({
    required this.id,
    required this.taskId,
    required this.storagePath,
    required this.originalName,
    required this.photoStage,
    this.mediaType = 'photo',
    this.contentType,
    this.durationSeconds,
    this.sizeBytes,
    required this.createdAt,
  });

  bool get isBefore => photoStage == 'before';
  bool get isAfter => photoStage == 'after';
  bool get isVideo => mediaType == 'video';
  bool get isPhoto => !isVideo;

  factory TaskPhotoData.fromSupabase(Map<String, dynamic> json) {
    return TaskPhotoData(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      storagePath: json['storage_path']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? 'Фото',
      photoStage: json['photo_stage']?.toString() == 'after'
          ? 'after'
          : 'before',
      mediaType: json['media_type']?.toString() == 'video' ? 'video' : 'photo',
      contentType: json['content_type']?.toString(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
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
  final String mediaType;
  final int? durationSeconds;

  const TaskPhotoFile({
    required this.originalName,
    required this.contentType,
    required this.extension,
    required this.bytes,
    this.mediaType = 'photo',
    this.durationSeconds,
  });

  bool get isVideo => mediaType == 'video';
  bool get isPhoto => !isVideo;
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
