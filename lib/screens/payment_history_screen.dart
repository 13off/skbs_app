import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/payment_repository.dart';
import '../models/employee.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final Employee employee;

  const PaymentHistoryScreen({super.key, required this.employee});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<PaymentRecord> payments = [];
  final Set<String> deletingPaymentIds = {};

  bool isLoading = false;
  String? errorText;
  int _loadSerial = 0;

  @override
  void initState() {
    super.initState();

    loadHistory();
  }

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String monthName(int month) {
    const monthNames = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    if (month < 1 || month > 12) return 'Месяц';

    return monthNames[month - 1];
  }

  String periodTitle(PaymentRecord payment) {
    return '${monthName(payment.periodMonth)} ${payment.periodYear}';
  }

  String formatMoney(num value) {
    final text = value.round().toString();

    final formatted = text.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    return '$formatted ₽';
  }

  String paymentTypeLabel(String value) {
    switch (value) {
      case 'advance':
        return 'Аванс';
      case 'salary':
        return 'Заработная плата';
      case 'fine':
        return 'Штраф';
      default:
        return 'Другое';
    }
  }

  Color paymentTypeColor(String value) {
    switch (value) {
      case 'fine':
        return Colors.red.shade700;
      case 'salary':
        return Colors.green.shade700;
      case 'advance':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  double get totalAmount {
    return payments.fold<double>(0, (sum, payment) => sum + payment.amount);
  }

  Future<void> loadHistory({bool forceRefresh = false}) async {
    final employeeId = widget.employee.id;

    if (employeeId == null || employeeId.trim().isEmpty) {
      setState(() {
        errorText = 'У сотрудника нет ID';
      });
      return;
    }

    final serial = ++_loadSerial;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await PaymentRepository.fetchPaymentsForEmployee(
        employeeId,
        forceRefresh: forceRefresh,
      );

      if (!mounted || serial != _loadSerial) return;

      setState(() {
        payments = result;
      });
    } catch (e) {
      if (!mounted || serial != _loadSerial) return;

      setState(() {
        errorText = 'Ошибка загрузки истории выплат: $e';
      });
    } finally {
      if (mounted && serial == _loadSerial) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> confirmDeletePayment(PaymentRecord payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить выплату?'),
          content: Text(
            '${paymentTypeLabel(payment.paymentType)} на сумму ${formatMoney(payment.amount)} от ${formatDate(payment.paymentDate)} будет удалена.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await deletePayment(payment);
  }

  Future<void> deletePayment(PaymentRecord payment) async {
    if (payment.id.isEmpty) {
      setState(() {
        errorText = 'Не удалось удалить выплату: нет ID записи';
      });
      return;
    }

    setState(() {
      deletingPaymentIds.add(payment.id);
      errorText = null;
    });

    try {
      await PaymentRepository.deletePayment(
        payment.id,
        employeeId: payment.employeeId,
      );

      if (!mounted) return;

      setState(() {
        payments.removeWhere((item) => item.id == payment.id);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выплата удалена')));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка удаления выплаты: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          deletingPaymentIds.remove(payment.id);
        });
      }
    }
  }

  Widget buildEmployeeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.employee.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.employee.position} • ${widget.employee.objectName}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Всего по истории: ${formatMoney(totalAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildPaymentCard(PaymentRecord payment) {
    final typeColor = paymentTypeColor(payment.paymentType);
    final comment = payment.comment.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  paymentTypeLabel(payment.paymentType),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                formatMoney(payment.amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              deletingPaymentIds.contains(payment.id)
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Удалить выплату',
                      onPressed: isLoading
                          ? null
                          : () {
                              confirmDeletePayment(payment);
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18),
              const SizedBox(width: 6),
              Text(
                formatDate(payment.paymentDate),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.event_note_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  periodTitle(payment),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История выплат')),
      body: RefreshIndicator(
        onRefresh: () => loadHistory(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            buildEmployeeHeader(),
            const SizedBox(height: 16),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LinearProgressIndicator(),
              ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (!isLoading && payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'История выплат пустая',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              ...payments.map(buildPaymentCard),
          ],
        ),
      ),
    );
  }
}
