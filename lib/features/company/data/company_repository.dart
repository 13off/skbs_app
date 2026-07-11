import 'package:supabase_flutter/supabase_flutter.dart';

class CompanySummary {
  final String id;
  final String name;
  final String role;
  final String planCode;
  final String billingStatus;
  final DateTime? trialEndsAt;

  const CompanySummary({
    required this.id,
    required this.name,
    required this.role,
    required this.planCode,
    required this.billingStatus,
    required this.trialEndsAt,
  });

  bool get isAdmin => role == 'owner' || role == 'admin';

  String get roleTitle {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'foreman':
        return 'Прораб';
      default:
        return role;
    }
  }
}

class CompanyObject {
  final String id;
  final String name;

  const CompanyObject({required this.id, required this.name});
}

class CompanyMember {
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final String objectId;
  final String objectName;

  const CompanyMember({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.objectId,
    required this.objectName,
  });

  bool get isOwner => role == 'owner';

  String get roleTitle {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'foreman':
        return 'Прораб';
      default:
        return role;
    }
  }
}

class CompanyDashboard {
  final CompanySummary company;
  final List<CompanyObject> objects;
  final List<CompanyMember> members;

  const CompanyDashboard({
    required this.company,
    required this.objects,
    required this.members,
  });
}

class CompanyInviteResult {
  final bool existingUser;

  const CompanyInviteResult({required this.existingUser});
}

class CompanyRepository {
  static final _client = Supabase.instance.client;

  static DateTime? _date(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static Future<List<CompanySummary>> fetchMyCompanies() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const <CompanySummary>[];

    final rows = await _client
        .from('company_memberships')
        .select(
          'company_id, role, is_active, companies!inner(id, name, plan_code, billing_status, trial_ends_at)',
        )
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at');

    return rows.map<CompanySummary>((row) {
      final company = _map(row['companies']);
      return CompanySummary(
        id: company['id']?.toString() ?? row['company_id']?.toString() ?? '',
        name: company['name']?.toString() ?? 'Компания',
        role: row['role']?.toString() ?? 'foreman',
        planCode: company['plan_code']?.toString() ?? 'trial',
        billingStatus: company['billing_status']?.toString() ?? 'trialing',
        trialEndsAt: _date(company['trial_ends_at']),
      );
    }).where((company) => company.id.isNotEmpty).toList();
  }

  static Future<CompanySummary> fetchCompany(String companyId) async {
    final memberships = await fetchMyCompanies();
    return memberships.firstWhere(
      (company) => company.id == companyId,
      orElse: () => throw Exception('Компания не найдена'),
    );
  }

  static Future<List<CompanyObject>> fetchObjects(String companyId) async {
    final rows = await _client
        .from('objects')
        .select('id, name')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('name');

    return rows
        .map<CompanyObject>(
          (row) => CompanyObject(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
          ),
        )
        .where((object) => object.id.isNotEmpty && object.name.isNotEmpty)
        .toList();
  }

  static Future<List<CompanyMember>> fetchMembers(String companyId) async {
    final membershipRows = await _client
        .from('company_memberships')
        .select('user_id, role, is_active, created_at')
        .eq('company_id', companyId)
        .order('created_at');

    final userIds = membershipRows
        .map<String>((row) => row['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (userIds.isEmpty) return const <CompanyMember>[];

    final results = await Future.wait<dynamic>([
      _client
          .from('user_profiles')
          .select('id, full_name, email')
          .inFilter('id', userIds),
      _client
          .from('object_memberships')
          .select('user_id, object_id, objects!inner(name)')
          .eq('company_id', companyId),
    ]);

    final profileRows = results[0] as List<dynamic>;
    final assignmentRows = results[1] as List<dynamic>;
    final profiles = <String, Map<String, dynamic>>{
      for (final dynamic value in profileRows)
        if (_map(value)['id']?.toString().isNotEmpty == true)
          _map(value)['id'].toString(): _map(value),
    };
    final assignments = <String, Map<String, dynamic>>{};
    for (final dynamic value in assignmentRows) {
      final row = _map(value);
      final userId = row['user_id']?.toString() ?? '';
      if (userId.isNotEmpty) assignments.putIfAbsent(userId, () => row);
    }

    return membershipRows.map<CompanyMember>((row) {
      final userId = row['user_id']?.toString() ?? '';
      final profile = profiles[userId] ?? const <String, dynamic>{};
      final assignment = assignments[userId] ?? const <String, dynamic>{};
      final object = _map(assignment['objects']);

      return CompanyMember(
        userId: userId,
        fullName: profile['full_name']?.toString() ?? '',
        email: profile['email']?.toString() ?? '',
        role: row['role']?.toString() ?? 'foreman',
        isActive: row['is_active'] == true,
        objectId: assignment['object_id']?.toString() ?? '',
        objectName: object['name']?.toString() ?? '',
      );
    }).where((member) => member.userId.isNotEmpty).toList();
  }

  static Future<CompanyDashboard> fetchDashboard(String companyId) async {
    final values = await Future.wait<dynamic>([
      fetchCompany(companyId),
      fetchObjects(companyId),
      fetchMembers(companyId),
    ]);

    return CompanyDashboard(
      company: values[0] as CompanySummary,
      objects: values[1] as List<CompanyObject>,
      members: values[2] as List<CompanyMember>,
    );
  }

  static Future<CompanyInviteResult> inviteMember({
    required String companyId,
    required String fullName,
    required String email,
    required String role,
    String? objectId,
  }) async {
    final response = await _client.functions.invoke(
      'invite-company-member',
      body: <String, dynamic>{
        'company_id': companyId,
        'full_name': fullName.trim(),
        'email': email.trim(),
        'role': role,
        'object_id': objectId,
      },
    );
    final data = _map(response.data);
    final error = data['error']?.toString().trim() ?? '';
    if (response.status < 200 || response.status >= 300 || error.isNotEmpty) {
      throw Exception(error.isEmpty ? 'Не удалось отправить приглашение' : error);
    }

    return CompanyInviteResult(existingUser: data['existing_user'] == true);
  }

  static Future<void> updateMemberAccess({
    required String companyId,
    required CompanyMember member,
    required String role,
    String? objectId,
  }) async {
    await _client
        .from('company_memberships')
        .update(<String, dynamic>{
          'role': role,
          'is_active': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('company_id', companyId)
        .eq('user_id', member.userId);

    await _client
        .from('object_memberships')
        .delete()
        .eq('company_id', companyId)
        .eq('user_id', member.userId);

    String? objectName;
    if (role == 'foreman' && objectId != null && objectId.isNotEmpty) {
      final object = await _client
          .from('objects')
          .select('name')
          .eq('company_id', companyId)
          .eq('id', objectId)
          .single();
      objectName = object['name']?.toString();

      await _client.from('object_memberships').insert(<String, dynamic>{
        'company_id': companyId,
        'object_id': objectId,
        'user_id': member.userId,
        'created_by': _client.auth.currentUser?.id,
      });
    }

    final targetProfile = await _client
        .from('user_profiles')
        .select('active_company_id')
        .eq('id', member.userId)
        .maybeSingle();
    if (targetProfile?['active_company_id']?.toString() == companyId) {
      await _client
          .from('user_profiles')
          .update(<String, dynamic>{
            'role': role,
            'object_name': objectName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', member.userId);
    }
  }
}

