import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/app_user_profile.dart';

class EmployeeCabinetSummary {
  final double shifts;
  final double hours;
  final double estimatedAccrued;
  final double paidCurrentMonth;
  final int plannedTasks;
  final int completedTasks;
  final int documents;

  const EmployeeCabinetSummary({
    required this.shifts,
    required this.hours,
    required this.estimatedAccrued,
    required this.paidCurrentMonth,
    required this.plannedTasks,
    required this.completedTasks,
    required this.documents,
  });

  factory EmployeeCabinetSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeCabinetSummary(
      shifts: _number(json['shifts']),
      hours: _number(json['hours']),
      estimatedAccrued: _number(json['estimated_accrued']),
      paidCurrentMonth: _number(json['paid_current_month']),
      plannedTasks: _integer(json['planned_tasks']),
      completedTasks: _integer(json['completed_tasks']),
      documents: _integer(json['documents']),
    );
  }
}

class EmployeeCabinetAttendance {
  final String id;
  final String employeeId;
  final DateTime? date;
  final String status;
  final double shifts;
  final double hours;
  final String objectName;
  final double dailyRate;
  final double estimatedAmount;

  const EmployeeCabinetAttendance({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.status,
    required this.shifts,
    required this.hours,
    required this.objectName,
    required this.dailyRate,
    required this.estimatedAmount,
  });

  bool get isWorked => status == 'worked' || shifts > 0 || hours > 0;
  bool get isNoShow => status == 'no_show';

  factory EmployeeCabinetAttendance.fromJson(Map<String, dynamic> json) {
    return EmployeeCabinetAttendance(
      id: _text(json['id']),
      employeeId: _text(json['employee_id']),
      date: DateTime.tryParse(_text(json['work_date'])),
      status: _text(json['status']),
      shifts: _number(json['shifts']),
      hours: _number(json['hours']),
      objectName: _text(json['object_name']),
      dailyRate: _number(json['daily_rate']),
      estimatedAmount: _number(json['estimated_amount']),
    );
  }
}

class EmployeeCabinetTask {
  final String id;
  final DateTime? date;
  final String objectName;
  final String axes;
  final String work;
  final String status;
  final String notDoneComment;
  final bool photoRequirementsEnforced;

  const EmployeeCabinetTask({
    required this.id,
    required this.date,
    required this.objectName,
    required this.axes,
    required this.work,
    required this.status,
    required this.notDoneComment,
    required this.photoRequirementsEnforced,
  });

  bool get isCompleted => status == 'Выполнено';

  factory EmployeeCabinetTask.fromJson(Map<String, dynamic> json) {
    return EmployeeCabinetTask(
      id: _text(json['id']),
      date: DateTime.tryParse(_text(json['task_date'])),
      objectName: _text(json['object_name']),
      axes: _text(json['axes']),
      work: _text(json['work']),
      status: _text(json['status']),
      notDoneComment: _text(json['not_done_comment']),
      photoRequirementsEnforced:
          json['photo_requirements_enforced'] as bool? ?? true,
    );
  }
}

class EmployeeCabinetPayment {
  final String id;
  final DateTime? date;
  final double amount;
  final String type;
  final String comment;
  final int periodYear;
  final int periodMonth;

  const EmployeeCabinetPayment({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.comment,
    required this.periodYear,
    required this.periodMonth,
  });

  bool get isFine => type == 'fine';

  factory EmployeeCabinetPayment.fromJson(Map<String, dynamic> json) {
    return EmployeeCabinetPayment(
      id: _text(json['id']),
      date: DateTime.tryParse(_text(json['payment_date'])),
      amount: _number(json['amount']),
      type: _text(json['payment_type']),
      comment: _text(json['comment']),
      periodYear: _integer(json['period_year']),
      periodMonth: _integer(json['period_month']),
    );
  }
}

class EmployeeCabinetDocument {
  final String id;
  final String source;
  final String title;
  final String type;
  final String status;

  const EmployeeCabinetDocument({
    required this.id,
    required this.source,
    required this.title,
    required this.type,
    required this.status,
  });

  factory EmployeeCabinetDocument.fromJson(Map<String, dynamic> json) {
    return EmployeeCabinetDocument(
      id: _text(json['id']),
      source: _text(json['source']),
      title: _text(json['title']),
      type: _text(json['type']),
      status: _text(json['status']),
    );
  }
}

class EmployeeCabinetData {
  final String fullName;
  final String phone;
  final String profession;
  final String currentObject;
  final List<String> objectNames;
  final int dailyRate;
  final String avatarPath;
  final int month;
  final int year;
  final EmployeeCabinetSummary summary;
  final List<EmployeeCabinetAttendance> attendance;
  final List<EmployeeCabinetTask> tasks;
  final List<EmployeeCabinetPayment> payments;
  final List<EmployeeCabinetDocument> documents;

  const EmployeeCabinetData({
    required this.fullName,
    required this.phone,
    required this.profession,
    required this.currentObject,
    required this.objectNames,
    required this.dailyRate,
    required this.avatarPath,
    required this.month,
    required this.year,
    required this.summary,
    required this.attendance,
    required this.tasks,
    required this.payments,
    required this.documents,
  });

  EmployeeCabinetTask? get currentTask {
    for (final task in tasks) {
      if (!task.isCompleted) return task;
    }
    return null;
  }

  List<EmployeeCabinetAttendance> attendanceForDay(int day) {
    return attendance
        .where((record) =>
            record.date?.year == year &&
            record.date?.month == month &&
            record.date?.day == day)
        .toList(growable: false);
  }

  List<EmployeeCabinetPayment> get paymentsForMonth {
    return payments
        .where((payment) =>
            payment.periodYear == year && payment.periodMonth == month)
        .toList(growable: false);
  }

  factory EmployeeCabinetData.fromJson(Map<String, dynamic> json) {
    final profile = _map(json['profile']);
    final month = _map(json['month']);
    return EmployeeCabinetData(
      fullName: _text(profile['full_name']),
      phone: _text(profile['phone']),
      profession: _text(profile['profession']),
      currentObject: _text(profile['current_object']),
      objectNames: _list(profile['object_names'])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      dailyRate: _integer(profile['daily_rate']),
      avatarPath: _text(profile['avatar_path']),
      month: _integer(month['month']),
      year: _integer(month['year']),
      summary: EmployeeCabinetSummary.fromJson(_map(json['summary'])),
      attendance: _list(json['attendance'])
          .whereType<Map>()
          .map((row) => EmployeeCabinetAttendance.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList(growable: false),
      tasks: _list(json['tasks'])
          .whereType<Map>()
          .map((row) => EmployeeCabinetTask.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList(growable: false),
      payments: _list(json['payments'])
          .whereType<Map>()
          .map((row) => EmployeeCabinetPayment.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList(growable: false),
      documents: _list(json['documents'])
          .whereType<Map>()
          .map((row) => EmployeeCabinetDocument.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList(growable: false),
    );
  }

  factory EmployeeCabinetData.preview(
    AppUserProfile profile, {
    int? year,
    int? month,
  }) {
    final now = DateTime.now();
    return EmployeeCabinetData(
      fullName: profile.fullName,
      phone: profile.phone,
      profession: profile.profession,
      currentObject: profile.objectName,
      objectNames: profile.objectName.trim().isEmpty
          ? const <String>[]
          : <String>[profile.objectName.trim()],
      dailyRate: 0,
      avatarPath: profile.avatarPath,
      month: month ?? now.month,
      year: year ?? now.year,
      summary: const EmployeeCabinetSummary(
        shifts: 0,
        hours: 0,
        estimatedAccrued: 0,
        paidCurrentMonth: 0,
        plannedTasks: 0,
        completedTasks: 0,
        documents: 0,
      ),
      attendance: const <EmployeeCabinetAttendance>[],
      tasks: const <EmployeeCabinetTask>[],
      payments: const <EmployeeCabinetPayment>[],
      documents: const <EmployeeCabinetDocument>[],
    );
  }
}

class EmployeeCabinetRepository {
  static final _client = Supabase.instance.client;

  static Future<EmployeeCabinetData> fetch({
    int? year,
    int? month,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'employee-cabinet',
        body: <String, dynamic>{
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
      );
      final raw = response.data;
      if (raw is! Map) {
        throw Exception('Личный кабинет вернул некорректный ответ');
      }
      final data = Map<String, dynamic>.from(raw);
      final error = _text(data['error']);
      if (error.isNotEmpty) throw Exception(error);
      return EmployeeCabinetData.fromJson(data);
    } catch (error) {
      final text = error.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(text.isEmpty ? 'Не удалось загрузить кабинет' : text);
    }
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  return value is List ? value : const <dynamic>[];
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
