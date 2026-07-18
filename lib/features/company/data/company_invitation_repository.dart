import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyInvitation {
  final String id;
  final String companyId;
  final String email;
  final String fullName;
  final String role;
  final String profession;
  final String objectId;
  final String objectName;
  final String status;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  const CompanyInvitation({
    required this.id,
    required this.companyId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.profession,
    required this.objectId,
    required this.objectName,
    required this.status,
    required this.expiresAt,
    required this.acceptedAt,
    required this.createdAt,
  });

  String get effectiveStatus {
    if (status == 'pending' && expiresAt.isBefore(DateTime.now())) {
      return 'expired';
    }
    return status;
  }

  bool get isPending => effectiveStatus == 'pending';

  String get roleTitle {
    switch (role) {
      case 'admin':
        return 'Администратор';
      case 'developer':
        return 'Разработчик';
      case 'foreman':
        return 'Прораб';
      case 'lawyer':
        return 'Юрист';
      case 'accountant':
        return 'Бухгалтер';
      case 'hr':
        return 'HR-менеджер';
      default:
        return role;
    }
  }

  String get statusTitle {
    switch (effectiveStatus) {
      case 'accepted':
        return 'Принято';
      case 'revoked':
        return 'Отменено';
      case 'expired':
        return 'Истекло';
      default:
        return 'Ожидает входа';
    }
  }
}

class CompanyInvitationRepository {
  static final _client = Supabase.instance.client;

  static DateTime date(dynamic value, {DateTime? fallback}) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
        fallback ??
        DateTime.now();
  }

  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static Future<List<CompanyInvitation>> fetchInvitations(
    String companyId,
  ) async {
    final rows = await _client
        .from('company_invitations')
        .select(
          'id, company_id, email, role, profession, object_id, invited_user_id, status, expires_at, accepted_at, created_at',
        )
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(250);

    final userIds = rows
        .map<String>((row) => row['invited_user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final objectIds = rows
        .map<String>((row) => row['object_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final results = await Future.wait<dynamic>([
      userIds.isEmpty
          ? Future<List<dynamic>>.value(const <dynamic>[])
          : _client
                .from('user_profiles')
                .select('id, full_name, profession')
                .inFilter('id', userIds),
      objectIds.isEmpty
          ? Future<List<dynamic>>.value(const <dynamic>[])
          : _client
                .from('objects')
                .select('id, name')
                .eq('company_id', companyId)
                .inFilter('id', objectIds),
    ]);

    final profiles = <String, Map<String, dynamic>>{};
    for (final value in results[0] as List<dynamic>) {
      final row = map(value);
      final id = row['id']?.toString() ?? '';
      if (id.isNotEmpty) profiles[id] = row;
    }
    final objects = <String, Map<String, dynamic>>{};
    for (final value in results[1] as List<dynamic>) {
      final row = map(value);
      final id = row['id']?.toString() ?? '';
      if (id.isNotEmpty) objects[id] = row;
    }

    return rows
        .map<CompanyInvitation>((row) {
          final userId = row['invited_user_id']?.toString() ?? '';
          final objectId = row['object_id']?.toString() ?? '';
          final profile = profiles[userId] ?? const <String, dynamic>{};
          final object = objects[objectId] ?? const <String, dynamic>{};
          final email = row['email']?.toString() ?? '';
          final fallbackName = email.contains('@')
              ? email.split('@').first
              : email;

          return CompanyInvitation(
            id: row['id']?.toString() ?? '',
            companyId: row['company_id']?.toString() ?? companyId,
            email: email,
            fullName: profile['full_name']?.toString().trim().isNotEmpty == true
                ? profile['full_name'].toString().trim()
                : fallbackName,
            role: row['role']?.toString() ?? 'foreman',
            profession: row['profession']?.toString().trim().isNotEmpty == true
                ? row['profession'].toString().trim()
                : profile['profession']?.toString() ?? '',
            objectId: objectId,
            objectName: object['name']?.toString() ?? '',
            status: row['status']?.toString() ?? 'pending',
            expiresAt: date(
              row['expires_at'],
              fallback: DateTime.now().add(const Duration(days: 7)),
            ),
            acceptedAt: row['accepted_at'] == null
                ? null
                : date(row['accepted_at']),
            createdAt: date(row['created_at']),
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<void> revokeInvitation({
    required String companyId,
    required String invitationId,
  }) async {
    await _client
        .from('company_invitations')
        .update(<String, dynamic>{
          'status': 'revoked',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('company_id', companyId)
        .eq('id', invitationId)
        .eq('status', 'pending');
  }
}
