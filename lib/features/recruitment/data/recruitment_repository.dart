import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../models/recruitment_models.dart';

abstract final class RecruitmentRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Future<List<RecruitmentApplication>> fetchApplications({
    required String companyId,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <RecruitmentApplication>[];

    final rows = await _client
        .from('recruitment_applications')
        .select()
        .eq('company_id', cleanCompanyId)
        .order('created_at', ascending: false)
        .limit(500);

    return rows
        .map<RecruitmentApplication>(
          (value) => RecruitmentApplication.fromMap(_map(value)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<RecruitmentDashboardData> fetchDashboard({
    required String companyId,
  }) async {
    final applications = await fetchApplications(companyId: companyId);
    final counts = <String, int>{
      for (final status in recruitmentStatuses) status: 0,
    };
    for (final application in applications) {
      counts[application.status] = (counts[application.status] ?? 0) + 1;
    }
    return RecruitmentDashboardData(applications: applications, counts: counts);
  }

  static Future<RecruitmentApplication> saveApplication({
    String? id,
    required String companyId,
    required String fullName,
    required String phone,
    required String citizenship,
    required String vacancy,
    required String objectName,
    required String experience,
    DateTime? departureDate,
    required String status,
    required String comment,
    String source = 'manual',
    String sourceUserId = '',
    String sourceChatId = '',
  }) async {
    final cleanId = id?.trim() ?? '';
    final payload = <String, dynamic>{
      'company_id': companyId.trim(),
      'source': source.trim().isEmpty ? 'manual' : source.trim(),
      'source_user_id': sourceUserId.trim(),
      'source_chat_id': sourceChatId.trim(),
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'citizenship': citizenship.trim(),
      'vacancy': vacancy.trim(),
      'object_name': objectName.trim(),
      'experience': experience.trim(),
      'departure_date': departureDate == null ? null : _dateOnly(departureDate),
      'status': recruitmentStatuses.contains(status) ? status : 'new',
      'comment': comment.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final dynamic row;
    if (cleanId.isEmpty) {
      payload['created_by'] = _client.auth.currentUser?.id;
      row = await _client
          .from('recruitment_applications')
          .insert(payload)
          .select()
          .single();
    } else {
      row = await _client
          .from('recruitment_applications')
          .update(payload)
          .eq('company_id', companyId.trim())
          .eq('id', cleanId)
          .select()
          .single();
    }

    final result = RecruitmentApplication.fromMap(_map(row));
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.recruitment},
      context: <String, dynamic>{
        'table': 'recruitment_applications',
        'entity_id': result.id,
      },
    );
    return result;
  }

  static Future<void> updateStatus({
    required String companyId,
    required String applicationId,
    required String status,
  }) async {
    if (!recruitmentStatuses.contains(status)) return;
    await _client
        .from('recruitment_applications')
        .update(<String, dynamic>{
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('company_id', companyId.trim())
        .eq('id', applicationId.trim());

    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.recruitment},
      context: <String, dynamic>{
        'table': 'recruitment_applications',
        'entity_id': applicationId,
      },
    );
  }
}
