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

class ExecutivePaymentRequisites {
  final String transferPhone;
  final String bankName;
  final String recipientName;
  final String bankCard;

  const ExecutivePaymentRequisites({
    this.transferPhone = '',
    this.bankName = '',
    this.recipientName = '',
    this.bankCard = '',
  });

  bool get hasAny =>
      transferPhone.trim().isNotEmpty ||
      bankName.trim().isNotEmpty ||
      recipientName.trim().isNotEmpty ||
      bankCard.trim().isNotEmpty;

  ExecutivePaymentRequisites merge(ExecutivePaymentRequisites other) {
    return ExecutivePaymentRequisites(
      transferPhone: transferPhone.trim().isNotEmpty
          ? transferPhone
          : other.transferPhone,
      bankName: bankName.trim().isNotEmpty ? bankName : other.bankName,
      recipientName: recipientName.trim().isNotEmpty
          ? recipientName
          : other.recipientName,
      bankCard: bankCard.trim().isNotEmpty ? bankCard : other.bankCard,
    );
  }
}

class ExecutivePaymentBalance {
  final String employeeName;
  final String personId;
  final List<String> employeeIds;
  final List<String> objectNames;
  final bool isActive;
  final double shifts;
  final double accrued;
  final double paid;

  const ExecutivePaymentBalance({
    required this.employeeName,
    this.personId = '',
    required this.employeeIds,
    required this.objectNames,
    required this.isActive,
    required this.shifts,
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

class ExecutiveEmployeeShift {
  final DateTime date;
  final double shifts;

  const ExecutiveEmployeeShift({required this.date, required this.shifts});
}

class ExecutiveEmployeePaymentDetails {
  final String employeeName;
  final DateTime? firstShiftDate;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> objectNames;
  final bool isActive;
  final double shifts;
  final double accrued;
  final double paid;
  final List<ExecutiveEmployeeShift> attendance;
  final List<PaymentRecord> payments;

  const ExecutiveEmployeePaymentDetails({
    required this.employeeName,
    required this.firstShiftDate,
    required this.startDate,
    required this.endDate,
    required this.objectNames,
    required this.isActive,
    required this.shifts,
    required this.accrued,
    required this.paid,
    required this.attendance,
    required this.payments,
  });

  double get balance => accrued - paid;
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

  static String _formatTaskQuantity(num value) {
    final fixed = value.toDouble().toStringAsFixed(3);
    var normalized = fixed;
    while (normalized.contains('.') && normalized.endsWith('0')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith('.')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    final parts = normalized.split('.');
    final integerPart = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    if (parts.length == 1) return integerPart;
    return '$integerPart,${parts[1]}';
  }

  static double? _taskCompletionPercent(double? planned, double actual) {
    if (planned == null ||
        !planned.isFinite ||
        planned <= 0 ||
        !actual.isFinite ||
        actual < 0) {
      return null;
    }
    return (actual / planned * 1000).round() / 10;
  }

  static Future<List<ExecutiveTaskMessage>> fetchTaskMessages({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
    String? objectName,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <ExecutiveTaskMessage>[];

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
        .eq('company_id', cleanCompanyId)
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
      _client
          .from('task_work_plans')
          .select('task_id, planned_quantity, unit, without_volume')
          .inFilter('task_id', taskIds),
      _client
          .from('task_work_days')
          .select('task_id, quantity, unit')
          .inFilter('task_id', taskIds),
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

    final workPlanByTask = <String, Map<String, dynamic>>{};
    for (final raw in detailResults[2] as List<dynamic>) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final taskId = row['task_id']?.toString().trim() ?? '';
      if (taskId.isEmpty) continue;
      workPlanByTask[taskId] = row;
    }

    final actualVolumeByTask = <String, double>{};
    final actualUnitByTask = <String, String>{};
    for (final raw in detailResults[3] as List<dynamic>) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final taskId = row['task_id']?.toString().trim() ?? '';
      if (taskId.isEmpty) continue;
      final quantity = (row['quantity'] as num?)?.toDouble();
      if (quantity != null && quantity.isFinite) {
        actualVolumeByTask.update(
          taskId,
          (value) => value + quantity,
          ifAbsent: () => quantity,
        );
      }
      final unit = row['unit']?.toString().trim() ?? '';
      if (unit.isNotEmpty) actualUnitByTask.putIfAbsent(taskId, () => unit);
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
      final status = row['status']?.toString().trim() ?? '';
      final comment = row['not_done_comment']?.toString().trim() ?? '';
      final assigneeNames = assignees
          .map((item) => item.employeeName.trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false);

      if (axes.isNotEmpty) sections.add('Оси / участок\n$axes');
      if (work.isNotEmpty) sections.add('Работа\n$work');
      if (assigneeNames.isNotEmpty) {
        sections.add("Исполнители\n${assigneeNames.join('\n')}");
      }

      final plan = workPlanByTask[id];
      final withoutVolume = plan?['without_volume'] == true;
      final planned = (plan?['planned_quantity'] as num?)?.toDouble();
      final actual = actualVolumeByTask[id];
      final unit = (plan?['unit']?.toString().trim().isNotEmpty ?? false)
          ? plan!['unit'].toString().trim()
          : (actualUnitByTask[id] ?? '');
      if (withoutVolume) {
        sections.add('Объём\nБез объёма');
      } else {
        if (planned != null && planned.isFinite) {
          sections.add(
            'Плановый объём\n'
            '${_formatTaskQuantity(planned)}'
            '${unit.isEmpty ? '' : ' $unit'}',
          );
        }
        if (actual != null && actual.isFinite) {
          sections.add(
            'Фактический объём\n'
            '${_formatTaskQuantity(actual)}'
            '${unit.isEmpty ? '' : ' $unit'}',
          );
        }
        if (actual != null) {
          final completion = _taskCompletionPercent(planned, actual);
          if (completion != null) {
            sections.add(
              'Выполнение плана\n'
              '${_formatTaskQuantity(completion)}%',
            );
          }
        }
      }

      if (status.isNotEmpty) sections.add('Статус\n$status');
      if (comment.isNotEmpty) sections.add('Комментарий\n$comment');

      final creatorName = row['created_by']?.toString().trim() ?? '';
      return ExecutiveTaskMessage(
        id: id,
        date: _cleanDate(date),
        createdAt: createdAt,
        objectName: row['object_name']?.toString().trim() ?? '',
        creatorName: creatorName.isEmpty ? 'Мастер' : creatorName,
        status: status,
        text: sections.where((section) => section.isNotEmpty).join('\n\n'),
        photos:
            signedPhotosByTask[id] ?? const <ExecutiveTaskPhoto>[],
      );
    }).toList(growable: false);
  }

  static Future<Map<String, ExecutivePaymentRequisites>>
  fetchPaymentRequisites(
    List<String> employeeIds,
  ) async {
    final ids = employeeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <String, ExecutivePaymentRequisites>{};

    final dynamic response = await _client.rpc<dynamic>(
      'get_executive_payment_requisites',
      params: <String, dynamic>{'p_employee_ids': ids},
    );
    if (response is! List) {
      return const <String, ExecutivePaymentRequisites>{};
    }

    final result = <String, ExecutivePaymentRequisites>{};
    for (final raw in response) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final employeeId = row['employee_id']?.toString().trim() ?? '';
      if (employeeId.isEmpty) continue;
      result[employeeId] = ExecutivePaymentRequisites(
        transferPhone:
            row['bank_transfer_phone']?.toString().trim() ?? '',
        bankName: row['bank_name']?.toString().trim() ?? '',
        recipientName:
            row['bank_recipient_name']?.toString().trim() ?? '',
        bankCard: row['bank_card']?.toString().trim() ?? '',
      );
    }
    return result;
  }

  static ExecutivePaymentRequisites requisitesForBalance(
    ExecutivePaymentBalance balance,
    Map<String, ExecutivePaymentRequisites> byEmployeeId,
  ) {
    var result = const ExecutivePaymentRequisites();
    for (final employeeId in balance.employeeIds) {
      final requisites = byEmployeeId[employeeId];
      if (requisites == null) continue;
      result = result.merge(requisites);
    }
    return result;
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
    final draftByEmployeeId = <String, _ExecutivePaymentDraft>{};
    final employeeIds = <String>{};
    for (final row in periodRows) {
      final name = row.employee.name.trim();
      if (name.isEmpty) continue;
      final personId = row.employee.personId?.trim() ?? '';
      final key = personId.isNotEmpty
          ? 'person:$personId'
          : 'name:${_normalizedEmployeeKey(name)}';
      final draft = drafts.putIfAbsent(
        key,
        () => _ExecutivePaymentDraft(name, personId: personId),
      );
      final employeeId = row.employee.id?.trim() ?? '';
      if (employeeId.isNotEmpty) {
        employeeIds.add(employeeId);
        draft.employeeIds.add(employeeId);
        draftByEmployeeId[employeeId] = draft;
      }
      final employeeObject = row.employee.objectName.trim();
      if (employeeObject.isNotEmpty) draft.objectNames.add(employeeObject);
      draft.isActive = draft.isActive || row.employee.isActive;
      draft.shifts += row.totalShifts;
      draft.accrued += row.accrued;
    }

    if (employeeIds.isNotEmpty) {
      final payments = await PaymentRepository.fetchPaymentsForEmployees(
        employeeIds.toList(growable: false),
        forceRefresh: forceRefresh,
      );
      for (final payment in payments) {
        if (!_paymentBelongsToPeriod(payment, first, last)) continue;
        final draft = draftByEmployeeId[payment.employeeId];
        if (draft != null) draft.paid += payment.amount;
      }
    }

    final balances = drafts.values
        .map((draft) => draft.toBalance())
        .where((row) => row.balance.abs() > 0.005)
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

  static Future<ExecutiveEmployeePaymentDetails> fetchEmployeePaymentDetails({
    required ExecutivePaymentBalance balance,
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
  }) async {
    final start = _cleanDate(startDate);
    final end = _cleanDate(endDate);
    final first = start.isAfter(end) ? end : start;
    final last = start.isAfter(end) ? start : end;
    final employeeIds = balance.employeeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (employeeIds.isEmpty) {
      return ExecutiveEmployeePaymentDetails(
        employeeName: balance.employeeName,
        firstShiftDate: null,
        startDate: first,
        endDate: last,
        objectNames: balance.objectNames,
        isActive: balance.isActive,
        shifts: balance.shifts,
        accrued: balance.accrued,
        paid: balance.paid,
        attendance: const <ExecutiveEmployeeShift>[],
        payments: const <PaymentRecord>[],
      );
    }

    final firstShiftEmployeeIds = <String>{...employeeIds};
    final personId = balance.personId.trim();
    if (personId.isNotEmpty) {
      final personEmployeeRows = await _client
          .from('employees')
          .select('id')
          .eq('person_id', personId);
      for (final raw in personEmployeeRows) {
        final id = raw['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) firstShiftEmployeeIds.add(id);
      }
    }

    final results = await Future.wait<dynamic>([
      _client
          .from('attendance')
          .select('work_date, shifts')
          .inFilter('employee_id', employeeIds)
          .gte('work_date', _dateKey(first))
          .lte('work_date', _dateKey(last))
          .order('work_date', ascending: true),
      _client
          .from('attendance')
          .select('work_date, shifts')
          .inFilter(
            'employee_id',
            firstShiftEmployeeIds.toList(growable: false),
          )
          .gt('shifts', 0)
          .order('work_date', ascending: true)
          .limit(1),
      PaymentRepository.fetchPaymentsForEmployees(
        employeeIds,
        forceRefresh: forceRefresh,
      ),
    ]);

    final shiftsByDate = <String, double>{};
    for (final raw in results[0] as List<dynamic>) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final dateText = row['work_date']?.toString().trim() ?? '';
      if (dateText.isEmpty) continue;
      final value = row['shifts'];
      final shifts = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '') ?? 0;
      shiftsByDate[dateText] = (shiftsByDate[dateText] ?? 0) + shifts;
    }
    final attendance = shiftsByDate.entries
        .map((entry) {
          final date = DateTime.tryParse(entry.key);
          if (date == null) return null;
          return ExecutiveEmployeeShift(
            date: _cleanDate(date),
            shifts: entry.value,
          );
        })
        .whereType<ExecutiveEmployeeShift>()
        .toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));

    DateTime? firstShiftDate;
    final firstShiftRows = results[1] as List<dynamic>;
    if (firstShiftRows.isNotEmpty && firstShiftRows.first is Map) {
      final row = Map<String, dynamic>.from(firstShiftRows.first as Map);
      firstShiftDate = DateTime.tryParse(
        row['work_date']?.toString().trim() ?? '',
      );
      if (firstShiftDate != null) firstShiftDate = _cleanDate(firstShiftDate);
    }

    final payments = (results[2] as List<PaymentRecord>)
        .where((payment) => _paymentBelongsToPeriod(payment, first, last))
        .toList(growable: false)
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    return ExecutiveEmployeePaymentDetails(
      employeeName: balance.employeeName,
      firstShiftDate: firstShiftDate,
      startDate: first,
      endDate: last,
      objectNames: balance.objectNames,
      isActive: balance.isActive,
      shifts: attendance.fold<double>(0, (sum, row) => sum + row.shifts),
      accrued: balance.accrued,
      paid: payments.fold<double>(0, (sum, row) => sum + row.amount),
      attendance: attendance,
      payments: payments,
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
  final String personId;
  final Set<String> employeeIds = <String>{};
  final Set<String> objectNames = <String>{};
  bool isActive = false;
  double shifts = 0;
  double accrued = 0;
  double paid = 0;

  _ExecutivePaymentDraft(this.employeeName, {this.personId = ''});

  ExecutivePaymentBalance toBalance() {
    final objects = objectNames.toList()..sort();
    final ids = employeeIds.toList()..sort();
    return ExecutivePaymentBalance(
      employeeName: employeeName,
      personId: personId,
      employeeIds: ids,
      objectNames: objects,
      isActive: isActive,
      shifts: shifts,
      accrued: accrued,
      paid: paid,
    );
  }
}
