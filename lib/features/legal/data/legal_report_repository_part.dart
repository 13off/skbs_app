part of 'legal_repository.dart';

abstract final class _LegalReports {
  static Future<LegalDashboardData> fetchDashboard() async {
    await refreshReminders();
    final values = await Future.wait<dynamic>([
      _LegalDocuments.fetchDocuments(),
      _LegalMatters.fetchMatters(),
      fetchLatestWeeklyReport(),
    ]);
    return LegalDashboardData(
      documents: values[0] as List<LegalDocument>,
      matters: values[1] as List<LegalMatter>,
      latestReport: values[2] as LegalWeeklyReport?,
    );
  }

  static Future<void> refreshReminders() async {
    try {
      final response = await _client.rpc('refresh_legal_reminders');
      final rows = _list(response);
      for (final value in rows) {
        final row = _map(value);
        final id = row['notification_id']?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          unawaited(PushNotificationService.dispatchNotification(id));
        }
      }
    } catch (_) {
      // Напоминания не должны блокировать открытие юридического раздела.
    }
  }

  static DateTime currentWeekStart([DateTime? value]) {
    final date = (value ?? DateTime.now()).toLocal();
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static Map<String, dynamic> buildWeeklyDraft({
    required List<LegalDocument> documents,
    required List<LegalMatter> matters,
    required DateTime weekStart,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    bool during(DateTime? value) {
      if (value == null) return false;
      return !value.isBefore(weekStart) && value.isBefore(weekEnd);
    }

    final prepared = documents
        .where(
          (item) => during(item.updatedAt) &&
              <String>{
                LegalDocumentStatus.prepared,
                LegalDocumentStatus.review,
                LegalDocumentStatus.awaitingSignature,
              }.contains(item.status),
        )
        .length;
    final signed = documents
        .where((item) => item.status == LegalDocumentStatus.signed && during(item.updatedAt))
        .length;
    final unresolved = documents
        .where((item) => item.status == LegalDocumentStatus.awaitingSignature)
        .length;
    final risks = matters.where((item) => item.isHighRisk).length;
    final resolved = matters
        .where(
          (item) =>
              <String>{LegalMatterStatus.resolved, LegalMatterStatus.closed}
                  .contains(item.status) &&
              during(item.updatedAt),
        )
        .length;
    final manager = matters.where((item) => item.needsManager).length;

    return <String, dynamic>{
      'prepared_documents': prepared,
      'signed_documents': signed,
      'unsigned_documents': unresolved,
      'approaching_deadlines': documents
          .where((item) => item.isExpired || item.isExpiringSoon)
          .length,
      'new_risks': risks,
      'resolved_matters': resolved,
      'manager_decisions': manager,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Future<LegalWeeklyReport?> fetchLatestWeeklyReport() async {
    final row = await _client
        .from('weekly_reports')
        .select(
          'id, week_start, week_end, status, auto_draft, author_comment, next_week_plan, manager_decisions, submitted_at',
        )
        .eq('department', 'legal')
        .order('week_start', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : LegalWeeklyReport.fromMap(row);
  }

  static Future<LegalWeeklyReport?> fetchCurrentWeeklyReport() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final weekStart = currentWeekStart();
    final row = await _client
        .from('weekly_reports')
        .select(
          'id, week_start, week_end, status, auto_draft, author_comment, next_week_plan, manager_decisions, submitted_at',
        )
        .eq('department', 'legal')
        .eq('author_user_id', userId)
        .eq('week_start', _dateOnly(weekStart))
        .maybeSingle();
    return row == null ? null : LegalWeeklyReport.fromMap(row);
  }

  static Future<LegalWeeklyReport> saveWeeklyReport({
    required Map<String, dynamic> autoDraft,
    required String authorComment,
    required String nextWeekPlan,
    required String managerDecisions,
    required bool submit,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Требуется вход в аккаунт');
    final weekStart = currentWeekStart();
    final weekEnd = weekStart.add(const Duration(days: 6));
    final row = await _client
        .from('weekly_reports')
        .upsert(
          <String, dynamic>{
            'department': 'legal',
            'author_user_id': userId,
            'week_start': _dateOnly(weekStart),
            'week_end': _dateOnly(weekEnd),
            'status': submit ? 'submitted' : 'draft',
            'auto_draft': autoDraft,
            'author_comment': authorComment.trim(),
            'next_week_plan': nextWeekPlan.trim(),
            'manager_decisions': managerDecisions.trim(),
            'submitted_at': submit
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          },
          onConflict: 'company_id,department,author_user_id,week_start',
        )
        .select(
          'id, week_start, week_end, status, auto_draft, author_comment, next_week_plan, manager_decisions, submitted_at',
        )
        .single();

    _notifyLegalChanged('weekly_reports', entityId: row['id']?.toString());
    if (submit) {
      unawaited(
        NotificationRepository.add(
          title: 'Юрист отправил недельный отчёт',
          body: 'Отчёт за неделю доступен в юридической сводке',
          entityType: 'legal_weekly_report',
          entityId: row['id']?.toString() ?? '',
          targetRole: 'admin',
          requiresAction: managerDecisions.trim().isNotEmpty,
        ),
      );
    }
    return LegalWeeklyReport.fromMap(row);
  }
}
