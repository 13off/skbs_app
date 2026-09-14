import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/attendance_repository.dart';
import '../../../data/payment_repository.dart';
import '../../../data/task_assignee_repository.dart';
import '../../../data/task_photo_models.dart';
import '../../../data/task_photo_repository.dart';

class ExecutiveTaskPhoto {
  final TaskPhotoData photo;
  final String signedUrl;

  const ExecutiveTaskPhoto({required this.photo, required this.signedUrl});
}

class ExecutiveTaskMessage {
  final String id;
  final DateTime date;
  final DateTime createdAt;
  final String objectName;
  final String creatorName;
  final String status;
  final String text;
  final List<ExecutiveTaskPhoto> photos;

  const ExecutiveTaskMessage({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.objectName,
    required this.creatorName,
    required this.status,
    required this.text,
    required this.photos,
  });
}

class ExecutivePaymentBalance {
  final String employeeName;
  final List<String> objectNames;
  final double accrued;
  final double paid;

  const ExecutivePaymentBalance({
    required this.employeeName,
    required this.objectNames,
    required this.accrued,
    required this.paid,
  });

  double get balance => accrued - paid;

  String get objectTitle {
    if (objectNames.isEmpty) return 'Все объекты';
    if (objectNames.length == 1) return objectNames.first;
    return objectNames.join(', ');
  }
}

class ExecutivePaymentSummary {
  final DateTime startDate;
  final DateTime endDate;
  final List<ExecutivePaymentBalance> rows;

  const ExecutivePaymentSummary({
    required this.startDate,
    required this.endDate,
    required this.rows,
  });

  double get totalDue => rows.fold<double>(
    0,
    (sum, row) => sum + (row.balance > 0 ? row.balance : 0),
  );
}

class ExecutivePanelRepository {
  ExecutivePanelRepository._();

  static final SupabaseClient _client = Supabase.instance.client;

  static String _dateKey(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static DateTime _cleanDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String? _cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static String _normalizedEmployeeKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<List<ExecutiveTaskMessage>> fetchTaskMessages({
    required DateTime startDate,
    required DateTime endDate,
    String? objectName,
  }) async {
    final start = _cleanDate(startDate);
    final end = _cleanDate(endDate);
    final first = start.isAfter(end) ? end : start;
    final last = start.isAfter(end) ? start : end;
    final cleanObject = _cleanObjectName(objectName);

    var query = _client
        .from('tasks')
        .select(
          'id, task_date, object_name, axes, work, status, not_done_comment, created_by, created_at',
        )
        .eq('is_draft', false)
        .gte('task_date', _dateKey(first))
        .lte('task_date', _dateKey(last));
    if (cleanObject != null) {
      query = query.eq('object_name', cleanObject);
    }

    final rawRows = await query
        .order('task_date', ascending: false)
        .order('created_at', ascending: false);
    final rows = rawRows
        .where((row) => row['id']?.toString().trim().isNotEmpty == true)
        .toList(growable: false);
    if (rows.isEmpty) return const <ExecutiveTaskMessage>[];

    final taskIds = rows
        .map((row) => row['id']!.toString())
        .toList(growable: false);
    final detailResults = await Future.wait<dynamic>([
      _client
          .from('task_assignees')
          .select('task_id, employee_id, employees(fio, position)')
          .inFilter('task_id', taskIds),
      _client
          .from('task_photos')
          .select(
            'id, task_id, storage_path, original_name, photo_stage, created_at',
          )
          .inFilter('task_id', taskIds)
          .order('created_at', ascending: true),
    ]);

    final assigneesByTask = <String, List<TaskAssigneeData>>{};
    for (final raw in detailResults[0] as List<dynamic>) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final taskId = row['task_id']?.toString().trim() ?? '';
      if (taskId.isEmpty) continue;
      assigneesByTask
          .putIfAbsent(taskId, () => <TaskAssigneeData>[])
          .add(TaskAssigneeData.fromSupabase(row));
    }

    final photosByTask = <String, List<TaskPhotoData>>{};
    for (final raw in detailResults[1] as List<dynamic>) {
      if (raw is! Map) continue;
      final photo = TaskPhotoData.fromSupabase(Map<String, dynamic>.from(raw));
      if (photo.taskId.trim().isEmpty || photo.storagePath.trim().isEmpty) {
        continue;
      }
      photosByTask
          .putIfAbsent(photo.taskId, () => <TaskPhotoData>[])
          .add(photo);
    }

    final signedPhotosByTask = <String, List<ExecutiveTaskPhoto>>{};
    await Future.wait(
      photosByTask.entries.map((entry) async {
        final signed = await Future.wait<ExecutiveTaskPhoto?>(
          entry.value.map((photo) async {
            try {
              final url = await TaskPhotoRepository.createSignedUrl(photo);
              if (url.trim().isEmpty) return null;
              return ExecutiveTaskPhoto(photo: photo, signedUrl: url);
            } catch (_) {
              return null;
            }
          }),
        );
        signedPhotosByTask[entry.key] = signed
            .whereType<ExecutiveTaskPhoto>()
            .toList(growable: false);
      }),
    );

    return rows.map((row) {
      final id = row['id']!.toString();
      final date =
          DateTime.tryParse(row['task_date']?.toString() ?? '') ?? first;
      final createdAt =
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
          date;
      final assignees = assigneesByTask[id] ?? const <TaskAssigneeData>[];
      final sections = <String>[];
      final axes = row['axes']?.toString().trim() ?? '';
      final work = row['work']?.toString().trim() ?? '';
      final comment = row['not_done_comment']?.toString().trim() ?? '';
      if (axes.isNotEmpty) sections.add(axes);
      if (work.isNotEmpty) sections.add(work);
      if (assignees.isNotEmpty) {
        sections.add(
          assignees
              .map((item) => item.employeeName.trim())
              .where((name) => name.isNotEmpty)
              .join('\n'),
        );
      }
      if (comment.isNotEmpty) sections.add(comment);

      final creatorName = row['created_by']?.toString().trim() ?? '';
      return ExecutiveTaskMessage(
        id: id,
        date: _cleanDate(date),
        createdAt: createdAt,
        objectName: row['object_name']?.toString().trim() ?? '',
        creatorName: creatorName.isEmpty ? 'Мастер' : creatorName,
        status: row['status']?.toString().trim() ?? '',
        text: sections.where((section) => section.isNotEmpty).join('\n\n'),
        photos:
            signedPhotosByTask[id] ?? const <ExecutiveTaskPhoto>[],
      );
    }).toList(growable: false);
  }

  static Future<ExecutivePaymentSummary> fetchPaymentSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final start = _cleanDate(startDate);
    final end = _cleanDate(endDate);
    final first = start.isAfter(end) ? end : start;
    final last = start.isAfter(end) ? start : end;
    final cleanObject = _cleanObjectName(objectName);

    final periodRows = await AttendanceRepository.fetchPeriodTimesheet(
      startDate: first,
      endDate: last,
      objectName: cleanObject,
      includeFired: true,
      forceRefresh: forceRefresh,
    );

    final drafts = <String, _ExecutivePaymentDraft>{};
    final employeeIds = <String>{};
    for (final row in periodRows) {
      final name = row.employee.name.trim();
      if (name.isEmpty) continue;
      final key = _normalizedEmployeeKey(name);
      final draft = drafts.putIfAbsent(
        key,
        () => _ExecutivePaymentDraft(name),
      );
      final employeeId = row.employee.id?.trim() ?? '';
      if (employeeId.isNotEmpty) {
        employeeIds.add(employeeId);
        draft.employeeIds.add(employeeId);
      }
      final employeeObject = row.employee.objectName.trim();
      if (employeeObject.isNotEmpty) draft.objectNames.add(employeeObject);
      draft.accrued += row.accrued;
    }

    if (employeeIds.isNotEmpty) {
      final payments = await PaymentRepository.fetchPaymentsForEmployees(
        employeeIds.toList(growable: false),
        forceRefresh: forceRefresh,
      );
      for (final payment in payments) {
        if (!_paymentBelongsToPeriod(payment, first, last)) continue;
        final draft = drafts.values.cast<_ExecutivePaymentDraft?>().firstWhere(
          (item) => item!.employeeIds.contains(payment.employeeId),
          orElse: () => null,
        );
        if (draft != null) draft.paid += payment.amount;
      }
    }

    final balances = drafts.values
        .map((draft) => draft.toBalance())
        .where((row) => row.balance > 0.005)
        .toList(growable: false)
      ..sort(
        (firstRow, secondRow) =>
            firstRow.employeeName.compareTo(secondRow.employeeName),
      );

    return ExecutivePaymentSummary(
      startDate: first,
      endDate: last,
      rows: balances,
    );
  }

  static bool _paymentBelongsToPeriod(
    PaymentRecord payment,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (payment.periodYear <= 0 ||
        payment.periodMonth < 1 ||
        payment.periodMonth > 12) {
      return false;
    }
    final paymentPeriodStart = DateTime(
      payment.periodYear,
      payment.periodMonth,
      1,
    );
    final paymentPeriodEnd = DateTime(
      payment.periodYear,
      payment.periodMonth + 1,
      0,
    );
    return !paymentPeriodEnd.isBefore(startDate) &&
        !paymentPeriodStart.isAfter(endDate);
  }
}

class _ExecutivePaymentDraft {
  final String employeeName;
  final Set<String> employeeIds = <String>{};
  final Set<String> objectNames = <String>{};
  double accrued = 0;
  double paid = 0;

  _ExecutivePaymentDraft(this.employeeName);

  ExecutivePaymentBalance toBalance() {
    final objects = objectNames.toList()..sort();
    return ExecutivePaymentBalance(
      employeeName: employeeName,
      objectNames: objects,
      accrued: accrued,
      paid: paid,
    );
  }
}
