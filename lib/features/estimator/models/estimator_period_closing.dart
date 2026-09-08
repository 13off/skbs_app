class EstimatorPeriodClosing {
  final String id;
  final String objectId;
  final String objectName;
  final int periodYear;
  final int periodMonth;
  final String status;
  final int submissionRound;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final String legalApprovedByName;
  final DateTime? legalApprovedAt;
  final String accountingApprovedByName;
  final DateTime? accountingApprovedAt;
  final String managerApprovedByName;
  final DateTime? managerApprovedAt;
  final String returnedByName;
  final String returnedByRole;
  final String returnComment;
  final DateTime? returnedAt;
  final String sentToClientByName;
  final DateTime? sentToClientAt;
  final String paidByName;
  final DateTime? paidAt;
  final int itemCount;
  final int taskItemCount;
  final int manualItemCount;
  final double earningsTotal;
  final int earningsCount;
  final int earningsIssueCount;

  const EstimatorPeriodClosing({
    required this.id,
    required this.objectId,
    required this.objectName,
    required this.periodYear,
    required this.periodMonth,
    required this.status,
    required this.submissionRound,
    required this.createdByName,
    required this.createdAt,
    required this.submittedAt,
    required this.legalApprovedByName,
    required this.legalApprovedAt,
    required this.accountingApprovedByName,
    required this.accountingApprovedAt,
    required this.managerApprovedByName,
    required this.managerApprovedAt,
    required this.returnedByName,
    required this.returnedByRole,
    required this.returnComment,
    required this.returnedAt,
    required this.sentToClientByName,
    required this.sentToClientAt,
    required this.paidByName,
    required this.paidAt,
    required this.itemCount,
    required this.taskItemCount,
    required this.manualItemCount,
    required this.earningsTotal,
    required this.earningsCount,
    required this.earningsIssueCount,
  });

  String get periodTitle => '${periodMonth.toString().padLeft(2, '0')}.$periodYear';
  bool get canEdit => status == 'draft' || status == 'returned';
  bool get isReturned => status == 'returned';

  String get statusTitle {
    switch (status) {
      case 'draft': return 'Черновик';
      case 'legal_review': return 'У юриста';
      case 'accounting_review': return 'У бухгалтера';
      case 'manager_review': return 'У руководителя';
      case 'ready_for_client': return 'Готово заказчику';
      case 'sent_to_client': return 'Передано заказчику';
      case 'paid': return 'Оплачено';
      case 'returned': return 'Возвращено';
      default: return status;
    }
  }

  static int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  static DateTime _date(dynamic value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
  static DateTime? _optionalDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
  }

  factory EstimatorPeriodClosing.fromMap(Map<String, dynamic> map) => EstimatorPeriodClosing(
    id: map['id']?.toString() ?? '',
    objectId: map['object_id']?.toString() ?? '',
    objectName: map['object_name']?.toString() ?? '',
    periodYear: _int(map['period_year']),
    periodMonth: _int(map['period_month']),
    status: map['status']?.toString() ?? 'draft',
    submissionRound: _int(map['submission_round']),
    createdByName: map['created_by_name']?.toString() ?? '',
    createdAt: _date(map['created_at']),
    submittedAt: _optionalDate(map['submitted_at']),
    legalApprovedByName: map['legal_approved_by_name']?.toString() ?? '',
    legalApprovedAt: _optionalDate(map['legal_approved_at']),
    accountingApprovedByName: map['accounting_approved_by_name']?.toString() ?? '',
    accountingApprovedAt: _optionalDate(map['accounting_approved_at']),
    managerApprovedByName: map['manager_approved_by_name']?.toString() ?? '',
    managerApprovedAt: _optionalDate(map['manager_approved_at']),
    returnedByName: map['returned_by_name']?.toString() ?? '',
    returnedByRole: map['returned_by_role']?.toString() ?? '',
    returnComment: map['return_comment']?.toString() ?? '',
    returnedAt: _optionalDate(map['returned_at']),
    sentToClientByName: map['sent_to_client_by_name']?.toString() ?? '',
    sentToClientAt: _optionalDate(map['sent_to_client_at']),
    paidByName: map['paid_by_name']?.toString() ?? '',
    paidAt: _optionalDate(map['paid_at']),
    itemCount: _int(map['item_count']),
    taskItemCount: _int(map['task_item_count']),
    manualItemCount: _int(map['manual_item_count']),
    earningsTotal: _double(map['earnings_total']),
    earningsCount: _int(map['earnings_count']),
    earningsIssueCount: _int(map['earnings_issue_count']),
  );
}

class EstimatorClosingItem {
  final String id;
  final String closingId;
  final String sourceType;
  final String sourceId;
  final String taskId;
  final String work;
  final String unit;
  final double quantity;
  final DateTime workDate;
  final String workLocation;
  final String sourceAuthorName;
  final String sourceComment;

  const EstimatorClosingItem({required this.id, required this.closingId, required this.sourceType, required this.sourceId, required this.taskId, required this.work, required this.unit, required this.quantity, required this.workDate, required this.workLocation, required this.sourceAuthorName, required this.sourceComment});
  bool get isManual => sourceType == 'manual';
  factory EstimatorClosingItem.fromMap(Map<String, dynamic> map) => EstimatorClosingItem(
    id: map['id']?.toString() ?? '', closingId: map['closing_id']?.toString() ?? '', sourceType: map['source_type']?.toString() ?? '', sourceId: map['source_id']?.toString() ?? '', taskId: map['task_id']?.toString() ?? '', work: map['work']?.toString() ?? '', unit: map['unit']?.toString() ?? '', quantity: (map['quantity'] as num?)?.toDouble() ?? double.tryParse(map['quantity']?.toString() ?? '') ?? 0, workDate: DateTime.tryParse(map['work_date']?.toString() ?? '')?.toLocal() ?? DateTime.now(), workLocation: map['work_location']?.toString() ?? '', sourceAuthorName: map['source_author_name']?.toString() ?? '', sourceComment: map['source_comment']?.toString() ?? '');
}

class EstimatorClosingReview {
  final String stage;
  final String decision;
  final String comment;
  final String reviewedByName;
  final String reviewedByRole;
  final DateTime reviewedAt;
  final int submissionRound;
  const EstimatorClosingReview({required this.stage, required this.decision, required this.comment, required this.reviewedByName, required this.reviewedByRole, required this.reviewedAt, required this.submissionRound});
  factory EstimatorClosingReview.fromMap(Map<String, dynamic> map) => EstimatorClosingReview(stage: map['stage']?.toString() ?? '', decision: map['decision']?.toString() ?? '', comment: map['comment']?.toString() ?? '', reviewedByName: map['reviewed_by_name']?.toString() ?? '', reviewedByRole: map['reviewed_by_role']?.toString() ?? '', reviewedAt: DateTime.tryParse(map['reviewed_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(), submissionRound: (map['submission_round'] as num?)?.toInt() ?? 0);
}

class EstimatorPieceRate {
  final String id;
  final String objectId;
  final String work;
  final String unit;
  final double rateAmount;
  final DateTime validFrom;
  final DateTime? validTo;
  final bool isActive;
  const EstimatorPieceRate({required this.id, required this.objectId, required this.work, required this.unit, required this.rateAmount, required this.validFrom, required this.validTo, required this.isActive});
  factory EstimatorPieceRate.fromMap(Map<String, dynamic> map) => EstimatorPieceRate(id: map['id']?.toString() ?? '', objectId: map['object_id']?.toString() ?? '', work: map['work']?.toString() ?? '', unit: map['unit']?.toString() ?? '', rateAmount: (map['rate_amount'] as num?)?.toDouble() ?? double.tryParse(map['rate_amount']?.toString() ?? '') ?? 0, validFrom: DateTime.tryParse(map['valid_from']?.toString() ?? '')?.toLocal() ?? DateTime.now(), validTo: DateTime.tryParse(map['valid_to']?.toString() ?? '')?.toLocal(), isActive: map['is_active'] == true);
}

class EstimatorClosingEarning {
  final String employeeName;
  final String work;
  final String unit;
  final double allocatedQuantity;
  final double rateAmount;
  final double amount;
  final int contributionPercent;
  const EstimatorClosingEarning({required this.employeeName, required this.work, required this.unit, required this.allocatedQuantity, required this.rateAmount, required this.amount, required this.contributionPercent});
  factory EstimatorClosingEarning.fromMap(Map<String, dynamic> map) => EstimatorClosingEarning(employeeName: map['employee_name']?.toString() ?? '', work: map['work']?.toString() ?? '', unit: map['unit']?.toString() ?? '', allocatedQuantity: (map['allocated_quantity'] as num?)?.toDouble() ?? 0, rateAmount: (map['rate_amount'] as num?)?.toDouble() ?? 0, amount: (map['amount'] as num?)?.toDouble() ?? 0, contributionPercent: (map['contribution_percent'] as num?)?.toInt() ?? 0);
}

class EstimatorClosingEarningIssue {
  final String issueCode;
  final String message;
  const EstimatorClosingEarningIssue({required this.issueCode, required this.message});
  factory EstimatorClosingEarningIssue.fromMap(Map<String, dynamic> map) => EstimatorClosingEarningIssue(issueCode: map['issue_code']?.toString() ?? '', message: map['message']?.toString() ?? '');
}
