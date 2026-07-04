import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_item_data.dart';
import 'fake_employees.dart';
import 'fake_tasks.dart';

class AppState {
  static const String _tasksKey = 'skbs_tasks';
  static const String _attendanceKey = 'skbs_attendance_by_date';

  static final List<TaskItemData> tasks = [];

  // Табель:
  // ключ — дата
  // значение — список имён сотрудников, которые вышли
  static final Map<String, Set<String>> attendanceByDate = {};

  static Future<void> load() async {
    final prefs = SharedPreferencesAsync();

    final savedTasksJson = await prefs.getString(_tasksKey);
    final savedAttendanceJson = await prefs.getString(_attendanceKey);

    _loadTasks(savedTasksJson);
    _loadAttendance(savedAttendanceJson);
  }

  static void _loadTasks(String? savedTasksJson) {
    tasks.clear();

    if (savedTasksJson == null) {
      tasks.addAll(fakeTasks);
      return;
    }

    try {
      final decoded = jsonDecode(savedTasksJson) as List<dynamic>;

      tasks.addAll(
        decoded
            .whereType<Map<String, dynamic>>()
            .map(TaskItemData.fromJson)
            .toList(),
      );
    } catch (_) {
      tasks.addAll(fakeTasks);
    }
  }

  static void _loadAttendance(String? savedAttendanceJson) {
    attendanceByDate.clear();

    if (savedAttendanceJson == null) return;

    try {
      final decoded = jsonDecode(savedAttendanceJson) as Map<String, dynamic>;

      attendanceByDate.addAll(
        decoded.map((date, employees) {
          final employeeNames = employees is List
              ? employees.whereType<String>().toSet()
              : <String>{};

          return MapEntry(date, employeeNames);
        }),
      );
    } catch (_) {
      attendanceByDate.clear();
    }
  }

  static Future<void> _saveTasks() async {
    final prefs = SharedPreferencesAsync();

    final encodedTasks = jsonEncode(
      tasks.map((task) => task.toJson()).toList(),
    );

    await prefs.setString(_tasksKey, encodedTasks);
  }

  static Future<void> _saveAttendance() async {
    final prefs = SharedPreferencesAsync();

    final encodedAttendance = jsonEncode(
      attendanceByDate.map((date, employees) {
        return MapEntry(date, employees.toList());
      }),
    );

    await prefs.setString(_attendanceKey, encodedAttendance);
  }

  static Future<void> addTask(TaskItemData task) async {
    tasks.add(task);
    await _saveTasks();
  }

  static Future<void> updateTask(int index, TaskItemData task) async {
    if (index < 0 || index >= tasks.length) return;

    tasks[index] = task;
    await _saveTasks();
  }

  static Future<void> deleteTask(int index) async {
    if (index < 0 || index >= tasks.length) return;

    tasks.removeAt(index);
    await _saveTasks();
  }

  static int totalTasksForDate(DateTime date) {
    return tasks.where((task) {
      return isSameDay(task.date, date);
    }).length;
  }

  static int get employeesCount {
    return fakeEmployees.length;
  }

  static DateTime get today {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  static String dateKey(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    final month = cleanDate.month.toString().padLeft(2, '0');
    final day = cleanDate.day.toString().padLeft(2, '0');

    return '${cleanDate.year}-$month-$day';
  }

  static int workersOnSiteForDate(DateTime date) {
    return attendanceByDate[dateKey(date)]?.length ?? 0;
  }

  static Set<String> workersForDate(DateTime date) {
    return attendanceByDate[dateKey(date)] ?? <String>{};
  }

  static Future<void> saveAttendanceForDate(
    DateTime date,
    Set<String> employeeNames,
  ) async {
    attendanceByDate[dateKey(date)] = employeeNames;
    await _saveAttendance();
  }

  static int plannedTasksForDate(DateTime date) {
    return tasks.where((task) {
      return isSameDay(task.date, date) && task.status == 'Запланировано';
    }).length;
  }

  static int doneTasksForDate(DateTime date) {
    return tasks.where((task) {
      return isSameDay(task.date, date) && task.status == 'Выполнено';
    }).length;
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
