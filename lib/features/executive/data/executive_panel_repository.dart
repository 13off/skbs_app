import 'package:supabase_flutter/supabase_flutter.dart';

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
  final int mediaCount;
  final List<ExecutiveTaskPhoto> photos;

  const ExecutiveTaskMessage({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.objectName,
    required this.creatorName,
    required this.status,
    required this.text,
    this.mediaCount = 0,
    this.photos = const <ExecutiveTaskPhoto>[],
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
  final bool automaticSalary;
  final double shifts;
  final double accrued;
  final double paid;

  const ExecutivePaymentBalance({
    required this.employeeName,
    this.personId = '',
    required this.employeeIds,
    required this.objectNames,
    required this.isActive,
    this.automaticSalary = false,
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
  final bool automaticSalary;
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
    this.automaticSalary = false,
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

    // The executive chat reads one server-maintained, preformatted feed row
    // per task. Assignees, work volumes and media counts are folded into that
    // feed by database triggers when task data changes, so opening the chat no
    // longer waits for several joins and signed Storage URLs.
    final dynamic response = await _client.rpc<dynamic>(
      'get_executive_task_feed',
      params: <String, dynamic>{
        'p_start_date': _dateKey(first),
        'p_end_date': _dateKey(last),
        'p_object_name': cleanObject,
      },
    );

    if (response is! List) return const <ExecutiveTaskMessage>[];

    return response
        .whereType<Map>()
        .map((raw) {
          final row = Map<String, dynamic>.from(raw);
          final id = row['task_id']?.toString().trim() ?? '';
          if (id.isEmpty) return null;

          final date =
              DateTime.tryParse(row['task_date']?.toString() ?? '') ?? first;
          final createdAt =
              DateTime.tryParse(
                row['task_created_at']?.toString() ?? '',
              )?.toLocal() ??
              date;
          final creator = row['creator_name']?.toString().trim() ?? '';
          return ExecutiveTaskMessage(
            id: id,
            date: _cleanDate(date),
            createdAt: createdAt,
            objectName: row['object_name']?.toString().trim() ?? '',
            creatorName: creator.isEmpty ? 'Мастер' : creator,
            status: row['status']?.toString().trim() ?? '',
            text: row['message_text']?.toString() ?? '',
            mediaCount: (row['media_count'] as num?)?.toInt() ?? 0,
          );
        })
        .whereType<ExecutiveTaskMessage>()
        .toList(growable: false);
  }

  static Future<List<ExecutiveTaskPhoto>> fetchTaskMedia(String taskId) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) return const <ExecutiveTaskPhoto>[];

    final rows = await _client
        .from('task_photos')
        .select(
          'id, task_id, storage_path, original_name, photo_stage, created_at',
        )
        .eq('task_id', cleanTaskId)
        .order('created_at', ascending: true);

    final photos = rows
        .map<TaskPhotoData>((row) => TaskPhotoData.fromSupabase(row))
        .where((photo) => photo.storagePath.trim().isNotEmpty)
        .toList(growable: false);
    if (photos.isEmpty) return const <ExecutiveTaskPhoto>[];

    final result = await Future.wait<ExecutiveTaskPhoto?>(
      photos.map((photo) async {
        try {
          final url = await TaskPhotoRepository.createSignedUrl(photo);
          if (url.trim().isEmpty) return null;
          return ExecutiveTaskPhoto(photo: photo, signedUrl: url);
        } catch (_) {
          return null;
        }
      }),
    );
    return result.whereType<ExecutiveTaskPhoto>().toList(growable: false);
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

    // The executive summary must be one authoritative server-side snapshot.
    // Keeping employee, attendance and payment reads inside one RPC prevents
    // independent client caches from producing a partial payout list.
    final dynamic response = await _client.rpc<dynamic>(
      'get_executive_payment_summary',
      params: <String, dynamic>{
        'p_start_date': _dateKey(first),
        'p_end_date': _dateKey(last),
        'p_object_name': cleanObject,
      },
    );

    final balances = <ExecutivePaymentBalance>[];
    if (response is List) {
      for (final raw in response.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final employeeName = row['employee_name']?.toString().trim() ?? '';
        if (employeeName.isEmpty) continue;

        double number(dynamic value) {
          if (value is num) return value.toDouble();
          return double.tryParse(value?.toString() ?? '') ?? 0.0;
        }

        List<String> strings(dynamic value) {
          if (value is! List) return const <String>[];
          return value
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
        }

        final balance = ExecutivePaymentBalance(
          employeeName: employeeName,
          personId: row['person_id']?.toString().trim() ?? '',
          employeeIds: strings(row['employee_ids']),
          objectNames: strings(row['object_names']),
          isActive: row['is_active'] as bool? ?? false,
          automaticSalary: row['automatic_salary'] as bool? ?? false,
          shifts: number(row['shifts']),
          accrued: number(row['accrued']),
          paid: number(row['paid']),
        );
        if (balance.balance.abs() > 0.005) balances.add(balance);
      }
    }

    balances.sort(
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
        automaticSalary: balance.automaticSalary,
        shifts: balance.automaticSalary ? 0 : balance.shifts,
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
      firstShiftDate: balance.automaticSalary ? null : firstShiftDate,
      startDate: first,
      endDate: last,
      objectNames: balance.objectNames,
      isActive: balance.isActive,
      automaticSalary: balance.automaticSalary,
      shifts: balance.automaticSalary
          ? 0
          : attendance.fold<double>(0, (sum, row) => sum + row.shifts),
      accrued: balance.accrued,
      paid: payments.fold<double>(0, (sum, row) => sum + row.amount),
      attendance: balance.automaticSalary
          ? const <ExecutiveEmployeeShift>[]
          : attendance,
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
