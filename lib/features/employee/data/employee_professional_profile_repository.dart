import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/app_user_profile.dart';

class EmployeeProfessionalProfile {
  final String grade;
  final double experienceYears;
  final List<String> skills;
  final String about;
  final List<String> preferredCities;
  final bool readyForRotation;
  final bool openToOffers;
  final int? desiredDailyRate;
  final DateTime? updatedAt;

  const EmployeeProfessionalProfile({
    required this.grade,
    required this.experienceYears,
    required this.skills,
    required this.about,
    required this.preferredCities,
    required this.readyForRotation,
    required this.openToOffers,
    required this.desiredDailyRate,
    required this.updatedAt,
  });

  const EmployeeProfessionalProfile.empty()
    : grade = '',
      experienceYears = 0,
      skills = const <String>[],
      about = '',
      preferredCities = const <String>[],
      readyForRotation = false,
      openToOffers = false,
      desiredDailyRate = null,
      updatedAt = null;

  factory EmployeeProfessionalProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfessionalProfile(
      grade: _text(json['grade']),
      experienceYears: _number(json['experience_years']),
      skills: _textList(json['skills']),
      about: _text(json['about']),
      preferredCities: _textList(json['preferred_cities']),
      readyForRotation: json['ready_for_rotation'] as bool? ?? false,
      openToOffers: json['open_to_offers'] as bool? ?? false,
      desiredDailyRate: json['desired_daily_rate'] == null
          ? null
          : _integer(json['desired_daily_rate']),
      updatedAt: DateTime.tryParse(_text(json['updated_at'])),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'grade': grade,
      'experience_years': experienceYears,
      'skills': skills,
      'about': about,
      'preferred_cities': preferredCities,
      'ready_for_rotation': readyForRotation,
      'open_to_offers': openToOffers,
      'desired_daily_rate': desiredDailyRate,
    };
  }
}

class EmployeeProfessionalVerified {
  final String fullName;
  final String profession;
  final String currentObject;
  final int currentDailyRate;
  final List<String> objectNames;
  final double totalShifts;
  final double totalHours;
  final int completedTasks;
  final int documents;
  final DateTime? firstWorkDate;

  const EmployeeProfessionalVerified({
    required this.fullName,
    required this.profession,
    required this.currentObject,
    required this.currentDailyRate,
    required this.objectNames,
    required this.totalShifts,
    required this.totalHours,
    required this.completedTasks,
    required this.documents,
    required this.firstWorkDate,
  });

  factory EmployeeProfessionalVerified.fromJson(Map<String, dynamic> json) {
    return EmployeeProfessionalVerified(
      fullName: _text(json['full_name']),
      profession: _text(json['profession']),
      currentObject: _text(json['current_object']),
      currentDailyRate: _integer(json['current_daily_rate']),
      objectNames: _textList(json['object_names']),
      totalShifts: _number(json['total_shifts']),
      totalHours: _number(json['total_hours']),
      completedTasks: _integer(json['completed_tasks']),
      documents: _integer(json['documents']),
      firstWorkDate: DateTime.tryParse(_text(json['first_work_date'])),
    );
  }
}

class EmployeeProfessionalPassportData {
  final EmployeeProfessionalProfile professional;
  final EmployeeProfessionalVerified verified;

  const EmployeeProfessionalPassportData({
    required this.professional,
    required this.verified,
  });

  factory EmployeeProfessionalPassportData.fromJson(Map<String, dynamic> json) {
    return EmployeeProfessionalPassportData(
      professional: EmployeeProfessionalProfile.fromJson(
        _map(json['professional']),
      ),
      verified: EmployeeProfessionalVerified.fromJson(_map(json['verified'])),
    );
  }

  factory EmployeeProfessionalPassportData.preview(AppUserProfile profile) {
    final objectName = profile.objectName.trim();
    final profession = profile.profession.trim().isEmpty
        ? 'Бетонщик-арматурщик'
        : profile.profession.trim();
    return EmployeeProfessionalPassportData(
      professional: const EmployeeProfessionalProfile(
        grade: '5 разряд',
        experienceYears: 4.5,
        skills: <String>[
          'Армирование',
          'Опалубка',
          'Бетонирование',
          'Чтение чертежей',
        ],
        about:
            'Работаю на монолитных объектах, соблюдаю технологию и отвечаю за результат своей зоны.',
        preferredCities: <String>['Мурманск', 'Москва', 'Норильск'],
        readyForRotation: true,
        openToOffers: false,
        desiredDailyRate: 6000,
        updatedAt: null,
      ),
      verified: EmployeeProfessionalVerified(
        fullName: profile.fullName.trim().isEmpty
            ? 'Сотрудник AppСтрой'
            : profile.fullName.trim(),
        profession: profession,
        currentObject: objectName,
        currentDailyRate: 6000,
        objectNames: objectName.isEmpty
            ? const <String>['Демонстрационный объект']
            : <String>[objectName],
        totalShifts: 86,
        totalHours: 946,
        completedTasks: 34,
        documents: 7,
        firstWorkDate: DateTime(2025, 9, 12),
      ),
    );
  }
}

class EmployeeProfessionalProfileRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<EmployeeProfessionalPassportData> fetch() async {
    return _invoke('employee-professional-profile', <String, dynamic>{
      'action': 'fetch',
    });
  }

  static Future<EmployeeProfessionalPassportData> fetchForEmployee({
    required String employeeId,
  }) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) {
      throw Exception('У сотрудника нет рабочей карточки');
    }
    return _invoke('employee-professional-profile-view', <String, dynamic>{
      'employee_id': cleanEmployeeId,
    });
  }

  static Future<EmployeeProfessionalPassportData> save(
    EmployeeProfessionalProfile professional,
  ) async {
    return _invoke('employee-professional-profile', <String, dynamic>{
      'action': 'update',
      'professional': professional.toJson(),
    });
  }

  static Future<EmployeeProfessionalPassportData> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body);
      final raw = response.data;
      if (raw is! Map) {
        throw Exception('Паспорт специалиста вернул некорректный ответ');
      }
      final data = Map<String, dynamic>.from(raw);
      final error = _text(data['error']);
      if (error.isNotEmpty) throw Exception(error);
      if (data['ok'] != true) {
        throw Exception('Не удалось загрузить паспорт специалиста');
      }
      return EmployeeProfessionalPassportData.fromJson(data);
    } catch (error) {
      final text = error.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(
        text.isEmpty ? 'Не удалось загрузить паспорт специалиста' : text,
      );
    }
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
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
