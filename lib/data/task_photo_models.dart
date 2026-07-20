import 'dart:typed_data';

class TaskPhotoData {
  final String id;
  final String taskId;
  final String storagePath;
  final String originalName;
  final String photoStage;
  final DateTime createdAt;

  const TaskPhotoData({
    required this.id,
    required this.taskId,
    required this.storagePath,
    required this.originalName,
    required this.photoStage,
    required this.createdAt,
  });

  bool get isBefore => photoStage == 'before';
  bool get isAfter => photoStage == 'after';

  factory TaskPhotoData.fromSupabase(Map<String, dynamic> json) {
    return TaskPhotoData(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      storagePath: json['storage_path']?.toString() ?? '',
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

  const TaskPhotoFile({
    required this.originalName,
    required this.contentType,
    required this.extension,
    required this.bytes,
  });
}
