import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/task_photo_models.dart';

class EmployeeWorkSelection {
  final String employeeId;
  final String objectName;

  const EmployeeWorkSelection({
    required this.employeeId,
    required this.objectName,
  });
}

class EmployeeWorkActionRepository {
  EmployeeWorkActionRepository._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<Map<String, dynamic>> _invoke(
    String action, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final response = await _client.functions.invoke(
      'employee-work-actions',
      body: <String, dynamic>{'action': action, ...body},
    );
    final raw = response.data;
    if (raw is! Map) {
      throw Exception('Рабочее действие вернуло некорректный ответ');
    }
    final data = Map<String, dynamic>.from(raw);
    final error = data['error']?.toString().trim() ?? '';
    if (error.isNotEmpty) throw Exception(error);
    return data;
  }

  static Future<EmployeeWorkSelection> resolveSelection() async {
    final data = await _invoke('resolve_selection');
    final employeeId = data['employee_id']?.toString().trim() ?? '';
    if (employeeId.isEmpty) {
      throw Exception('Не удалось определить выбранного сотрудника');
    }
    return EmployeeWorkSelection(
      employeeId: employeeId,
      objectName: data['object_name']?.toString().trim() ?? '',
    );
  }

  static Future<void> startTask(String taskId) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) throw Exception('Задача не определена');
    await _invoke('start_task', body: <String, dynamic>{'task_id': cleanTaskId});
  }

  static Future<void> uploadTaskPhotos({
    required String taskId,
    required String stage,
    required List<TaskPhotoFile> photos,
  }) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) throw Exception('Задача не определена');
    if (stage != 'before' && stage != 'after') {
      throw Exception('Неизвестный тип фотографии');
    }

    for (final photo in photos) {
      await _invoke(
        'upload_task_photo',
        body: <String, dynamic>{
          'task_id': cleanTaskId,
          'photo_stage': stage,
          'original_name': photo.originalName,
          'content_type': photo.contentType,
          'extension': photo.extension,
          'base64': base64Encode(photo.bytes),
        },
      );
    }
  }
}
