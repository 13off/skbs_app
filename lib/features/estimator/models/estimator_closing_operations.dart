class EstimatorClosingPackageEntry {
  final String id;
  final String closingId;
  final String kind;
  final String title;
  final String documentNumber;
  final DateTime? documentDate;
  final String note;
  final String status;
  final String createdByName;
  final DateTime createdAt;
  final String verifiedByName;
  final DateTime? verifiedAt;

  const EstimatorClosingPackageEntry({
    required this.id,
    required this.closingId,
    required this.kind,
    required this.title,
    required this.documentNumber,
    required this.documentDate,
    required this.note,
    required this.status,
    required this.createdByName,
    required this.createdAt,
    required this.verifiedByName,
    required this.verifiedAt,
  });

  String get kindTitle => switch (kind) {
    'volume_register' => 'Ведомость объёмов',
    'supporting_document' => 'Подтверждающий документ',
    'client_template' => 'Шаблон заказчика',
    _ => 'Другое',
  };

  String get statusTitle => switch (status) {
    'verified' => 'Проверено',
    'not_required' => 'Не требуется',
    _ => 'Приложено',
  };

  factory EstimatorClosingPackageEntry.fromMap(Map<String, dynamic> map) {
    return EstimatorClosingPackageEntry(
      id: map['id']?.toString() ?? '',
      closingId: map['closing_id']?.toString() ?? '',
      kind: map['kind']?.toString() ?? 'other',
      title: map['title']?.toString() ?? '',
      documentNumber: map['document_number']?.toString() ?? '',
      documentDate: DateTime.tryParse(map['document_date']?.toString() ?? '')?.toLocal(),
      note: map['note']?.toString() ?? '',
      status: map['status']?.toString() ?? 'attached',
      createdByName: map['created_by_name']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      verifiedByName: map['verified_by_name']?.toString() ?? '',
      verifiedAt: DateTime.tryParse(map['verified_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

class EstimatorClosingPayoutLine {
  final String id;
  final String closingId;
  final String employeeId;
  final String employeeName;
  final int periodYear;
  final int periodMonth;
  final double amount;
  final int earningRows;
  final int blockerCount;
  final String blockerNote;
  final String status;
  final String paymentId;
  final String linkedByName;
  final DateTime? linkedAt;

  const EstimatorClosingPayoutLine({
    required this.id,
    required this.closingId,
    required this.employeeId,
    required this.employeeName,
    required this.periodYear,
    required this.periodMonth,
    required this.amount,
    required this.earningRows,
    required this.blockerCount,
    required this.blockerNote,
    required this.status,
    required this.paymentId,
    required this.linkedByName,
    required this.linkedAt,
  });

  bool get isBlocked => status == 'blocked';
  bool get isPaid => status == 'paid' && paymentId.isNotEmpty;
  String get statusTitle => switch (status) {
    'blocked' => 'Заблокировано',
    'paid' => 'Связано с выплатой',
    _ => 'Готово к выплате',
  };

  factory EstimatorClosingPayoutLine.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
    int toInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
    return EstimatorClosingPayoutLine(
      id: map['id']?.toString() ?? '',
      closingId: map['closing_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      employeeName: map['employee_name']?.toString() ?? '',
      periodYear: toInt(map['period_year']),
      periodMonth: toInt(map['period_month']),
      amount: toDouble(map['amount']),
      earningRows: toInt(map['earning_rows']),
      blockerCount: toInt(map['blocker_count']),
      blockerNote: map['blocker_note']?.toString() ?? '',
      status: map['status']?.toString() ?? 'ready',
      paymentId: map['payment_id']?.toString() ?? '',
      linkedByName: map['linked_by_name']?.toString() ?? '',
      linkedAt: DateTime.tryParse(map['linked_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

class EstimatorClosingDashboard {
  final int year;
  final int month;
  final int closings;
  final int items;
  final int manualItems;
  final int earningIssues;
  final double internalEarnings;
  final int inReview;
  final int waitingClient;
  final int waitingPayment;
  final int paid;
  final int returned;
  final Map<String, int> statusCounts;

  const EstimatorClosingDashboard({
    required this.year,
    required this.month,
    required this.closings,
    required this.items,
    required this.manualItems,
    required this.earningIssues,
    required this.internalEarnings,
    required this.inReview,
    required this.waitingClient,
    required this.waitingPayment,
    required this.paid,
    required this.returned,
    required this.statusCounts,
  });

  factory EstimatorClosingDashboard.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
    double toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
    final rawCounts = map['status_counts'];
    final counts = <String, int>{};
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        counts[entry.key.toString()] = toInt(entry.value);
      }
    }
    return EstimatorClosingDashboard(
      year: toInt(map['year']),
      month: toInt(map['month']),
      closings: toInt(map['closings']),
      items: toInt(map['items']),
      manualItems: toInt(map['manual_items']),
      earningIssues: toInt(map['earning_issues']),
      internalEarnings: toDouble(map['internal_earnings']),
      inReview: toInt(map['in_review']),
      waitingClient: toInt(map['waiting_client']),
      waitingPayment: toInt(map['waiting_payment']),
      paid: toInt(map['paid']),
      returned: toInt(map['returned']),
      statusCounts: counts,
    );
  }
}
