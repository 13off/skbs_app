class EstimatorPaymentCandidate {
  final String id;
  final DateTime paymentDate;
  final double amount;
  final String paymentType;
  final String comment;

  const EstimatorPaymentCandidate({
    required this.id,
    required this.paymentDate,
    required this.amount,
    required this.paymentType,
    required this.comment,
  });

  factory EstimatorPaymentCandidate.fromMap(Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    return EstimatorPaymentCandidate(
      id: map['id']?.toString() ?? '',
      paymentDate: DateTime.tryParse(map['payment_date']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      amount: rawAmount is num ? rawAmount.toDouble() : double.tryParse(rawAmount?.toString() ?? '') ?? 0,
      paymentType: map['payment_type']?.toString() ?? '',
      comment: map['comment']?.toString() ?? '',
    );
  }
}
