import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../models/employee_mobilization_models.dart';

abstract final class EmployeeMobilizationRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static void _notify(String employeeId) {
    AppDataSync.notifyLocal(
      const <AppDataDomain>{
        AppDataDomain.recruitment,
        AppDataDomain.employees,
        AppDataDomain.attendance,
        AppDataDomain.notifications,
      },
      context: <String, dynamic>{
        'table': 'employee_mobilizations',
        'entity_id': employeeId,
      },
    );
  }

  static Future<List<EmployeeMobilizationEntry>> fetchEntries({
    required String companyId,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <EmployeeMobilizationEntry>[];

    final applicationRows = await _client
        .from('recruitment_applications')
        .select(
          'id, company_id, employee_id, full_name, position_title, '
          'object_id, status, objects(name)',
        )
        .eq('company_id', cleanCompanyId)
        .isFilter('archived_at', null)
        .inFilter('status', const <String>['arrived', 'hired'])
        .order('updated_at', ascending: false);

    final candidates = applicationRows
        .map<EmployeeMobilizationCandidate>(
          (row) => EmployeeMobilizationCandidate.fromMap(_map(row)),
        )
        .where(
          (item) =>
              item.employeeId.trim().isNotEmpty &&
              item.objectId.trim().isNotEmpty &&
              item.applicationId.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (candidates.isEmpty) return const <EmployeeMobilizationEntry>[];

    final employeeIds = candidates.map((item) => item.employeeId).toList();
    final mobilizationRows = await _client
        .from('employee_mobilizations')
        .select()
        .eq('company_id', cleanCompanyId)
        .inFilter('employee_id', employeeIds);
    final byEmployee = <String, EmployeeMobilization>{};
    for (final row in mobilizationRows) {
      final item = EmployeeMobilization.fromMap(_map(row));
      if (item.employeeId.isNotEmpty) byEmployee[item.employeeId] = item;
    }

    return candidates
        .map(
          (candidate) => EmployeeMobilizationEntry(
            candidate: candidate,
            mobilization: byEmployee[candidate.employeeId] ??
                EmployeeMobilization.empty(candidate),
          ),
        )
        .toList(growable: false);
  }

  static Future<EmployeeMobilization> save({
    required EmployeeMobilizationCandidate candidate,
    required EmployeeMobilization mobilization,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Нет активной Auth-сессии');
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'company_id': candidate.companyId,
      'application_id': candidate.applicationId,
      'employee_id': candidate.employeeId,
      'object_id': candidate.objectId,
      'planned_start_date': mobilization.plannedStartDate == null
          ? null
          : _dateOnly(mobilization.plannedStartDate!),
      'ticket_booked': mobilization.ticketBooked,
      'arrival_confirmed': mobilization.arrivalConfirmed,
      'accommodation_confirmed': mobilization.accommodationConfirmed,
      'medical_cleared': mobilization.medicalCleared,
      'clothing_issued': mobilization.clothingIssued,
      'safety_inducted': mobilization.safetyInducted,
      'object_assigned': mobilization.objectAssigned,
      'attendance_enabled': mobilization.attendanceEnabled,
      'notes': mobilization.notes.trim(),
      'created_by': userId,
      'updated_by': userId,
      'updated_at': now,
    };
    final row = await _client
        .from('employee_mobilizations')
        .upsert(payload, onConflict: 'company_id,employee_id')
        .select()
        .single();
    final result = EmployeeMobilization.fromMap(_map(row));
    _notify(candidate.employeeId);
    return result;
  }
}
