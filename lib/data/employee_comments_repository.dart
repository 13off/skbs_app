import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeComment {
  final String id;
  final String employeeId;
  final String text;
  final String createdBy;
  final DateTime createdAt;

  const EmployeeComment({
    required this.id,
    required this.employeeId,
    required this.text,
    required this.createdBy,
    required this.createdAt,
  });

  factory EmployeeComment.fromSupabase(Map<String, dynamic> json) {
    return EmployeeComment(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      text: json['comment_text']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class EmployeeCommentsRepository {
  static final _client = Supabase.instance.client;

  static Future<List<EmployeeComment>> fetchComments(String employeeId) async {
    final rows = await _client
        .from('employee_comments')
        .select('id, employee_id, comment_text, created_by, created_at')
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false);

    return rows.map<EmployeeComment>((row) {
      return EmployeeComment.fromSupabase(row);
    }).toList();
  }

  static Future<EmployeeComment> addComment({
    required String employeeId,
    required String text,
  }) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      throw Exception('Комментарий пустой');
    }

    final row = await _client
        .from('employee_comments')
        .insert({
          'employee_id': employeeId,
          'comment_text': cleanText,
          'created_by': 'Илья',
        })
        .select('id, employee_id, comment_text, created_by, created_at')
        .single();

    return EmployeeComment.fromSupabase(row);
  }
}
