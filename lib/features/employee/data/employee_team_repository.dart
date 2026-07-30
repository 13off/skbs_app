import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeTeamMember {
  final String employeeId;
  final String fullName;
  final String profession;
  final String objectName;
  final double totalShifts;
  final int completedTasks;
  final DateTime? firstWorkDate;
  final bool extendedVisible;
  final String grade;
  final double experienceYears;
  final List<String> skills;
  final String about;
  final bool readyForRotation;

  const EmployeeTeamMember({
    required this.employeeId,
    required this.fullName,
    required this.profession,
    required this.objectName,
    required this.totalShifts,
    required this.completedTasks,
    required this.firstWorkDate,
    required this.extendedVisible,
    required this.grade,
    required this.experienceYears,
    required this.skills,
    required this.about,
    required this.readyForRotation,
  });

  factory EmployeeTeamMember.fromJson(Map<String, dynamic> json) {
    return EmployeeTeamMember(
      employeeId: _text(json['employee_id']),
      fullName: _text(json['full_name']),
      profession: _text(json['profession']),
      objectName: _text(json['object_name']),
      totalShifts: _number(json['total_shifts']),
      completedTasks: _integer(json['completed_tasks']),
      firstWorkDate: DateTime.tryParse(_text(json['first_work_date'])),
      extendedVisible: json['extended_visible'] as bool? ?? false,
      grade: _text(json['grade']),
      experienceYears: _number(json['experience_years']),
      skills: _textList(json['skills']),
      about: _text(json['about']),
      readyForRotation: json['ready_for_rotation'] as bool? ?? false,
    );
  }
}

class EmployeeTeamData {
  final String currentObject;
  final List<EmployeeTeamMember> members;
  final bool canManageVisibility;
  final String visibilityScope;

  const EmployeeTeamData({
    required this.currentObject,
    required this.members,
    required this.canManageVisibility,
    required this.visibilityScope,
  });

  factory EmployeeTeamData.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    return EmployeeTeamData(
      currentObject: _text(json['current_object']),
      members: rawMembers is List
          ? rawMembers
              .whereType<Map>()
              .map(
                (item) => EmployeeTeamMember.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <EmployeeTeamMember>[],
      canManageVisibility:
          json['can_manage_visibility'] as bool? ?? false,
      visibilityScope: normalizeTeamVisibility(json['visibility_scope']),
    );
  }

  EmployeeTeamData copyWith({String? visibilityScope}) {
    return EmployeeTeamData(
      currentObject: currentObject,
      members: members,
      canManageVisibility: canManageVisibility,
      visibilityScope: visibilityScope ?? this.visibilityScope,
    );
  }
}

class EmployeeTeamRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<EmployeeTeamData> fetch({String? employeeId}) async {
    final body = <String, dynamic>{'action': 'list'};
    final cleanEmployeeId = employeeId?.trim() ?? '';
    if (cleanEmployeeId.isNotEmpty) body['employee_id'] = cleanEmployeeId;
    return _invoke(body);
  }

  static Future<String> updateVisibility(String scope) async {
    final clean = normalizeTeamVisibility(scope);
    final response = await _invokeRaw(<String, dynamic>{
      'action': 'update_visibility',
      'visibility_scope': clean,
    });
    return normalizeTeamVisibility(response['visibility_scope']);
  }

  static Future<EmployeeTeamData> _invoke(Map<String, dynamic> body) async {
    final data = await _invokeRaw(body);
    return EmployeeTeamData.fromJson(data);
  }

  static Future<Map<String, dynamic>> _invokeRaw(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'employee-team',
        body: body,
      );
      final raw = response.data;
      if (raw is! Map) {
        throw Exception('Команда объекта вернула некорректный ответ');
      }
      final data = Map<String, dynamic>.from(raw);
      final error = _text(data['error']);
      if (error.isNotEmpty) throw Exception(error);
      if (data['ok'] != true) {
        throw Exception('Не удалось загрузить команду объекта');
      }
      return data;
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(
        message.isEmpty ? 'Не удалось загрузить команду объекта' : message,
      );
    }
  }
}

const Map<String, String> employeeTeamVisibilityTitles = <String, String>{
  'private': 'Только я',
  'object': 'Мой объект',
  'company': 'Моя компания',
  'employers': 'Работодатели',
};

const Map<String, String> employeeTeamVisibilityDescriptions =
    <String, String>{
  'private': 'Коллеги увидят только имя, профессию и подтверждённую работу.',
  'object': 'Расширенный профиль увидят коллеги текущего объекта.',
  'company': 'Профиль будет доступен сотрудникам вашей компании.',
  'employers': 'Профиль готов к будущему каталогу работодателей.',
};

String normalizeTeamVisibility(dynamic value) {
  final clean = _text(value);
  return employeeTeamVisibilityTitles.containsKey(clean) ? clean : 'object';
}

String _text(dynamic value) => value?.toString().trim() ?? '';

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _textList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
