import 'package:supabase_flutter/supabase_flutter.dart';

class LegalMatterWorkspaceEvent {
  final String id;
  final String eventType;
  final String title;
  final String body;
  final String actorUserId;
  final DateTime createdAt;

  const LegalMatterWorkspaceEvent({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.actorUserId,
    required this.createdAt,
  });

  factory LegalMatterWorkspaceEvent.fromMap(Map<String, dynamic> map) {
    return LegalMatterWorkspaceEvent(
      id: map['id']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? 'note',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      actorUserId: map['actor_user_id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class LegalMatterWorkspaceData {
  final String basis;
  final List<LegalMatterWorkspaceEvent> events;
  final Map<String, String> actorNames;

  const LegalMatterWorkspaceData({
    required this.basis,
    required this.events,
    required this.actorNames,
  });

  String actorName(String userId) {
    if (userId.isEmpty) return '';
    return actorNames[userId] ?? '';
  }
}

abstract final class LegalMatterWorkspaceRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<LegalMatterWorkspaceData> fetch(String matterId) async {
    final values = await Future.wait<dynamic>([
      _client.from('legal_matters').select('basis').eq('id', matterId).single(),
      _client
          .from('legal_matter_events')
          .select('id, event_type, title, body, actor_user_id, created_at')
          .eq('matter_id', matterId)
          .order('created_at', ascending: false),
      _client.rpc('legal_responsible_directory'),
    ]);

    final matter = Map<String, dynamic>.from(values[0] as Map);
    final events = (values[1] as List<dynamic>)
        .map(
          (value) => LegalMatterWorkspaceEvent.fromMap(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    final actorNames = <String, String>{};
    for (final value in values[2] as List<dynamic>) {
      final row = Map<String, dynamic>.from(value as Map);
      final id = row['id']?.toString() ?? '';
      final name = row['full_name']?.toString() ?? '';
      if (id.isNotEmpty && name.isNotEmpty) actorNames[id] = name;
    }

    return LegalMatterWorkspaceData(
      basis: matter['basis']?.toString() ?? '',
      events: events,
      actorNames: actorNames,
    );
  }

  static Future<void> saveBasis({
    required String matterId,
    required String basis,
  }) async {
    await _client
        .from('legal_matters')
        .update(<String, dynamic>{
          'basis': basis.trim(),
          'updated_by': _client.auth.currentUser?.id,
        })
        .eq('id', matterId);
  }

  static Future<void> addNote({
    required String matterId,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final matter = await _client
        .from('legal_matters')
        .select('company_id')
        .eq('id', matterId)
        .single();

    await _client.from('legal_matter_events').insert(<String, dynamic>{
      'company_id': matter['company_id'],
      'matter_id': matterId,
      'event_type': 'note',
      'title': 'Комментарий',
      'body': text,
      'actor_user_id': userId,
    });
  }
}
