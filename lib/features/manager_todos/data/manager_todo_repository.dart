import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerTodoItem {
  final String id;
  final String title;
  final String body;
  final String status;
  final DateTime? dueAt;
  final DateTime? reminderAt;
  final String priority;
  final String sourceType;
  final DateTime? sourceDate;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ManagerTodoItem({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.dueAt,
    required this.reminderAt,
    required this.priority,
    required this.sourceType,
    required this.sourceDate,
    required this.metadata,
    required this.createdAt,
    required this.completedAt,
  });

  bool get isDone => status == 'done';
  bool get isAutomatic => sourceType != 'manual';

  factory ManagerTodoItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final parsed = DateTime.tryParse(value.toString());
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    final rawMetadata = json['metadata'];

    return ManagerTodoItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString().trim() ?? '',
      body: json['body']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? 'open',
      dueAt: parseDateTime(json['due_at']),
      reminderAt: parseDateTime(json['reminder_at']),
      priority: json['priority']?.toString().trim() ?? 'normal',
      sourceType: json['source_type']?.toString().trim() ?? 'manual',
      sourceDate: parseDate(json['source_date']),
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
      createdAt:
          parseDateTime(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: parseDateTime(json['completed_at']),
    );
  }
}

class ManagerTodoRepository {
  static final _client = Supabase.instance.client;

  static Future<List<ManagerTodoItem>> fetchTodos({
    bool includeDone = false,
    int limit = 80,
  }) async {
    final response = await _client.rpc<dynamic>(
      'get_my_manager_todos',
      params: <String, dynamic>{
        'p_include_done': includeDone,
        'p_limit': limit,
      },
    );

    if (response is! List) return const <ManagerTodoItem>[];

    return response
        .whereType<Map>()
        .map(
          (row) => ManagerTodoItem.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);
  }

  static Future<String> createTodo({
    required String title,
    String body = '',
    DateTime? reminderAt,
  }) async {
    final response = await _client.rpc<dynamic>(
      'create_manager_todo',
      params: <String, dynamic>{
        'p_title': title.trim(),
        'p_body': body.trim(),
        'p_reminder_at': reminderAt?.toUtc().toIso8601String(),
      },
    );

    return response?.toString() ?? '';
  }

  static Future<bool> setDone(String todoId, {required bool done}) async {
    final response = await _client.rpc<dynamic>(
      'set_manager_todo_done',
      params: <String, dynamic>{
        'p_todo_id': todoId,
        'p_done': done,
      },
    );

    return response == true;
  }
}
