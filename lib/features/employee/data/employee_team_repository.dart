import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeTeamMember {
  final String employeeId;
  final String fullName;
  final String profession;
  final String phone;
  final String avatarUrl;
  final bool profileVerified;

  const EmployeeTeamMember({
    required this.employeeId,
    required this.fullName,
    required this.profession,
    required this.phone,
    required this.avatarUrl,
    required this.profileVerified,
  });

  factory EmployeeTeamMember.fromJson(Map<String, dynamic> json) {
    return EmployeeTeamMember(
      employeeId: _text(json['employee_id']),
      fullName: _text(json['full_name']),
      profession: _text(json['profession']),
      phone: _text(json['phone']),
      avatarUrl: _text(json['avatar_url']),
      profileVerified: json['profile_verified'] as bool? ?? false,
    );
  }
}

class EmployeeTeamData {
  final String currentObject;
  final List<EmployeeTeamMember> members;

  const EmployeeTeamData({
    required this.currentObject,
    required this.members,
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
    );
  }
}

class EmployeeTeamRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<EmployeeTeamData> fetch({String? employeeId}) async {
    final body = <String, dynamic>{'action': 'list'};
    final cleanEmployeeId = employeeId?.trim() ?? '';
    if (cleanEmployeeId.isNotEmpty) body['employee_id'] = cleanEmployeeId;

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
      return EmployeeTeamData.fromJson(data);
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(
        message.isEmpty ? 'Не удалось загрузить команду объекта' : message,
      );
    }
  }
}

String _text(dynamic value) => value?.toString().trim() ?? '';
