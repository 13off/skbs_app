import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeTaskCabinetProfile {
  final String employeeId;
  final String objectId;
  final String fullName;
  final String profession;
  final String phone;
  final String currentObject;

  const EmployeeTaskCabinetProfile({
    required this.employeeId,
    required this.objectId,
    required this.fullName,
    required this.profession,
    required this.phone,
    required this.currentObject,
  });

  factory EmployeeTaskCabinetProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeTaskCabinetProfile(
      employeeId: _text(json['employee_id']),
      objectId: _text(json['object_id']),
      fullName: _text(json['full_name']),
      profession: _text(json['profession']),
      phone: _text(json['phone']),
      currentObject: _text(json['current_object']),
    );
  }
}

class EmployeeTaskCabinetPhoto {
  final String id;
  final String originalName;
  final String stage;
  final String signedUrl;
  final DateTime? createdAt;

  const EmployeeTaskCabinetPhoto({
    required this.id,
    required this.originalName,
    required this.stage,
    required this.signedUrl,
    required this.createdAt,
  });

  bool get isBefore => stage == 'before';
  bool get isAfter => stage == 'after';

  factory EmployeeTaskCabinetPhoto.fromJson(Map<String, dynamic> json) {
    return EmployeeTaskCabinetPhoto(
      id: _text(json['id']),
      originalName: _text(json['original_name']),
      stage: _text(json['photo_stage']),
      signedUrl: _text(json['signed_url']),
      createdAt: DateTime.tryParse(_text(json['created_at']))?.toLocal(),
    );
  }
}

class EmployeeTaskCabinetTask {
  final String id;
  final DateTime? date;
  final String objectId;
  final String objectName;
  final String axes;
  final String work;
  final String status;
  final String notDoneComment;
  final bool photoRequirementsEnforced;
  final List<EmployeeTaskCabinetPhoto> photos;

  const EmployeeTaskCabinetTask({
    required this.id,
    required this.date,
    required this.objectId,
    required this.objectName,
    required this.axes,
    required this.work,
    required this.status,
    required this.notDoneComment,
    required this.photoRequirementsEnforced,
    required this.photos,
  });

  bool get isCompleted => status == 'Выполнено';
  bool get isInProgress => status == 'В работе';

  List<EmployeeTaskCabinetPhoto> get beforePhotos =>
      photos.where((photo) => photo.isBefore).toList(growable: false);

  List<EmployeeTaskCabinetPhoto> get afterPhotos =>
      photos.where((photo) => photo.isAfter).toList(growable: false);

  factory EmployeeTaskCabinetTask.fromJson(Map<String, dynamic> json) {
    return EmployeeTaskCabinetTask(
      id: _text(json['id']),
      date: DateTime.tryParse(_text(json['task_date'])),
      objectId: _text(json['object_id']),
      objectName: _text(json['object_name']),
      axes: _text(json['axes']),
      work: _text(json['work']),
      status: _text(json['status']),
      notDoneComment: _text(json['not_done_comment']),
      photoRequirementsEnforced:
          json['photo_requirements_enforced'] as bool? ?? true,
      photos: _list(json['photos'])
          .whereType<Map>()
          .map(
            (row) => EmployeeTaskCabinetPhoto.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false),
    );
  }
}

class EmployeeTaskCabinetData {
  final EmployeeTaskCabinetProfile profile;
  final List<EmployeeTaskCabinetTask> tasks;

  const EmployeeTaskCabinetData({
    required this.profile,
    required this.tasks,
  });

  factory EmployeeTaskCabinetData.fromJson(Map<String, dynamic> json) {
    return EmployeeTaskCabinetData(
      profile: EmployeeTaskCabinetProfile.fromJson(_map(json['profile'])),
      tasks: _list(json['tasks'])
          .whereType<Map>()
          .map(
            (row) => EmployeeTaskCabinetTask.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false),
    );
  }
}

class EmployeeTaskCabinetRepository {
  EmployeeTaskCabinetRepository._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<EmployeeTaskCabinetData> fetch({
    String employeeId = '',
  }) async {
    try {
      final response = await _client.functions.invoke(
        'employee-task-cabinet',
        body: <String, dynamic>{
          if (employeeId.trim().isNotEmpty)
            'employee_id': employeeId.trim(),
        },
      );
      final raw = response.data;
      if (raw is! Map) {
        throw Exception('Кабинет сотрудника вернул некорректный ответ');
      }
      final data = Map<String, dynamic>.from(raw);
      final error = _text(data['error']);
      if (error.isNotEmpty) throw Exception(error);
      final result = EmployeeTaskCabinetData.fromJson(data);
      if (result.profile.employeeId.isEmpty) {
        throw Exception('Не удалось определить сотрудника');
      }
      return result;
    } on FunctionException catch (error) {
      throw Exception(_functionError(error));
    } catch (error) {
      final text = error.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(text.isEmpty ? 'Не удалось загрузить задачи' : text);
    }
  }
}

String _functionError(FunctionException error) {
  final details = error.details;
  if (details is Map) {
    final message = _text(details['error']);
    if (message.isNotEmpty) return message;
  }
  if (details is String && details.trim().isNotEmpty) return details.trim();
  final reason = error.reasonPhrase?.trim() ?? '';
  if (reason.isNotEmpty) return reason;
  return 'Не удалось выполнить действие';
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

String _text(dynamic value) => value?.toString().trim() ?? '';
